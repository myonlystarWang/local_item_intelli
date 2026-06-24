import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../db/local_db.dart';

class SyncScreen extends StatefulWidget {
  final bool isOnline;

  const SyncScreen({super.key, required this.isOnline});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  List<Map<String, dynamic>> pendingLogs = [];
  bool isSyncing = false;
  List<dynamic> serverReport = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingLogs();
  }

  Future<void> _loadPendingLogs() async {
    final logs = await LocalDatabase.instance.getLocalLogs();
    setState(() {
      pendingLogs = logs;
      isLoading = false;
    });
  }

  // 局域网同步对齐握手接口通信 (RESTful API)
  Future<void> _performSync() async {
    if (!widget.isOnline) {
      _showErrorDialog('同步失败：未连入库房局域网 Wi-Fi，无法进行局域网握手。');
      return;
    }

    setState(() {
      isSyncing = true;
    });

    try {
      // 整理上报 JSON 数据包
      final List<Map<String, dynamic>> logsPayload = [];
      for (var l in pendingLogs) {
        logsPayload.add({
          'timestamp': l['timestamp'],
          'time_str': l['time_str'],
          'type': l['type'],
          'tool_code': l['tool_code'],
          'operator': l['operator'],
          'detail': jsonDecode(l['detail'])
        });
      }

      final currentUuid = await LocalDatabase.instance.getSetting('terminal_uuid') ?? 'terminal-handheld-001';
      final body = {
        'terminal_uuid': currentUuid,
        'app_version': ApiConfig.appVersion,
        'schema_version': ApiConfig.schemaVersion,
        'logs': logsPayload
      };

      final serverUrl = await LocalDatabase.instance.getSetting('sync_server_url') ?? ApiConfig.defaultApiBaseUrl;
      final url = ApiConfig.endpoint(serverUrl, '/sync');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final report = resData['report'] as List<dynamic>;
        
        // 转换最新工具数据
        final List<Map<String, dynamic>> tools = [];
        for (var t in resData['updated_tools']) {
          tools.add({
            'code': t['code'],
            'name': t['name'],
            'model': t['model'],
            'status': t['status'],
            'use_count': t['use_count'],
            'lifespan_limit': t['lifespan_limit'],
            'location': t['location'],
            'operator': t['operator'],
            'last_update_time': t['last_update_time'],
            'checkout_time': t['checkout_time'],
          });
        }

        // 转换最新配件数据
        final List<Map<String, dynamic>> accessories = [];
        for (var a in resData['updated_accessories']) {
          accessories.add({
            'barcode': a['barcode'],
            'name': a['name'],
            'spec': a['spec'],
            'unit': a['unit'],
            'safety_stock': a['safety_stock'],
            'current_stock': a['current_stock'],
          });
        }

        // 下发字典对齐
        final Map<String, List<String>> dicts = {
          'wellbore': List<String>.from(resData['updated_dicts']?['wellbores'] ?? ['川科1井', '深地塔科1井']),
          'operator': List<String>.from(resData['updated_dicts']?['operators'] ?? ['张建国', '李志刚']),
          'team': List<String>.from(resData['updated_dicts']?['teams'] ?? ['川庆一队']),
        };

        // 覆盖本地 SQLite 数据库状态，并清空同步成功的日志缓存
        await LocalDatabase.instance.performSyncAlignment(tools, accessories, dicts);

        setState(() {
          serverReport = report;
          pendingLogs = [];
          isSyncing = false;
        });

        _showSuccessDialog('同步合并完成！双端数据已对齐一致。');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isSyncing = false;
      });
      _showErrorDialog('同步失败：无法连接库房中枢或接口返回异常。待同步日志已保留，请检查服务器地址与局域网连接后重试。\n\n错误详情：$e');
    }
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ 局域网握手失败'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
        ],
      ),
    );
  }

  void _showSuccessDialog(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ 数据对齐对齐成功'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('数据同步控制台')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 同步大状态看板
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                      isSyncing ? Icons.sync : Icons.cloud_sync,
                      size: 48,
                      color: isSyncing ? theme.colorScheme.secondary : theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isSyncing ? '正在近场合并数据...' : '近场同步网关',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isOnline ? '局域网信道就绪 (已联网)' : '请先在首页开启网络开关以连接局域网',
                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 待同步记录区（仅在有待同步数据或报告为空时展示）
            if (pendingLogs.isNotEmpty || serverReport.isEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('待上报离线记录：', style: TextStyle(fontSize: 12, color: Colors.white54)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: pendingLogs.isEmpty
                        ? const Center(child: Text('无待同步的操作日志', style: TextStyle(fontSize: 12, color: Colors.white30)))
                        : ListView.builder(
                            itemCount: pendingLogs.length,
                            itemBuilder: (context, index) {
                              final item = pendingLogs[index];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.history_edu, size: 20),
                                title: Text('${item['tool_code']} [${item['type']}]'),
                                subtitle: Text('操作时间: ${item['time_str']} | 责任人: ${item['operator']}'),
                              );
                            },
                          ),
                    ),
                  ],
                ),
              ),

            // 对齐日志报告展示
            if (serverReport.isNotEmpty) ...[
              if (pendingLogs.isNotEmpty) const Divider(height: 20) else const SizedBox(height: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('中枢反馈对齐校验日志：', style: TextStyle(fontSize: 12, color: Colors.white54)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: serverReport.length,
                        itemBuilder: (context, index) {
                          final rep = serverReport[index];
                          return Card(
                            color: Colors.white.withValues(alpha: 0.01),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(rep['type'] == 'success' ? '✅ 校验通过' : '⚠️ 异常冲突', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      Text('${rep['time']}', style: const TextStyle(fontSize: 9, color: Colors.white30)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${rep['text']}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSyncing ? null : _performSync,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0088CC),
                ),
                child: Text(isSyncing ? '数据同步中...' : '⚡ 开始一键近场同步'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
