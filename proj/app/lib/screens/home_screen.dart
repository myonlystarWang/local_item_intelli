import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../db/local_db.dart';
import 'detail_screen.dart';
import 'sync_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isOnline = false; // 初始假设为离线，通过心跳动态确认
  Timer? _heartbeatTimer;
  int pendingSyncCount = 0;
  List<Map<String, dynamic>> toolsList = [];
  String operatorName = '';
  String operatorTeam = '';

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    _startHeartbeat();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  // 局域网在线心跳定时轮询
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // 立即执行一次
    _checkConnectivity();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    final serverUrl = await LocalDatabase.instance.getSetting('sync_server_url') ?? ApiConfig.defaultApiBaseUrl;
    try {
      final response = await http.get(ApiConfig.endpoint(serverUrl, '/tools')).timeout(const Duration(seconds: 2));
      final newStatus = response.statusCode == 200;
      if (isOnline != newStatus) {
        setState(() {
          isOnline = newStatus;
        });
      }
    } catch (_) {
      if (isOnline != false) {
        setState(() {
          isOnline = false;
        });
      }
    }
  }

  Future<void> _loadLocalData() async {
    final logs = await LocalDatabase.instance.getLocalLogs();
    final tools = await LocalDatabase.instance.getTools();
    final opName = await LocalDatabase.instance.getSetting('operator_name') ?? '未确认';
    final opTeam = await LocalDatabase.instance.getSetting('operator_team') ?? '未知大队';
    setState(() {
      pendingSyncCount = logs.length;
      toolsList = tools;
      operatorName = opName;
      operatorTeam = opTeam;
    });
  }

  // 模拟扫码识别进入详情页 (可操作模式)
  void _onBarcodeScanned(String barcode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(
          barcode: barcode,
          isOnline: isOnline,
          isReadOnly: false,
        ),
      ),
    ).then((_) => _loadLocalData());
  }

  // 资产预览项点击进入详情页 (只读模式)
  void _onAssetItemClicked(String barcode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(
          barcode: barcode,
          isOnline: isOnline,
          isReadOnly: true,
        ),
      ),
    ).then((_) => _loadLocalData());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF102A43),
        title: GestureDetector(
          onLongPress: () {
            _showMockScannerSelector();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('已唤醒调试用模拟扫码器'),
              duration: Duration(seconds: 1),
            ));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('精密工具智能化管理', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('终端 (离线状态机) | 操作人: $operatorName ($operatorTeam)', style: const TextStyle(fontSize: 10, color: Colors.white70)),
            ],
          ),
        ),
        actions: [
          // 局域网网络状态静态指示器（不可点击，心跳自动切换）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Icon(
                  isOnline ? Icons.wifi : Icons.wifi_off,
                  color: isOnline ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? '局域网在线' : '离线状态',
                  style: TextStyle(
                    color: isOnline ? Colors.green : Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // 系统配置页面入口
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            tooltip: '系统配置',
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              if (updated == true) {
                _loadLocalData();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CustomScrollView(
          slivers: [
            // 1. 横向排布的小巧操作按钮 Row
            SliverToBoxAdapter(
              child: Row(
                children: [
                  // 扫描按钮
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final barcode = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(builder: (context) => const ScanScreen()),
                        );
                        if (barcode != null && mounted) {
                          _onBarcodeScanned(barcode);
                        }
                      },
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF102A43), Color(0xFF243B53)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_scanner, size: 18, color: Color(0xFF0088CC)),
                              SizedBox(width: 6),
                              Text('扫码识读', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 同步按钮
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SyncScreen(isOnline: isOnline),
                          ),
                        ).then((_) => _loadLocalData());
                      },
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFF131722),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(Icons.sync_alt, size: 18, color: Color(0xFFD4AF37)),
                                  if (pendingSyncCount > 0)
                                    Positioned(
                                      right: -6,
                                      top: -6,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                                        child: Text(
                                          '$pendingSyncCount',
                                          style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 6),
                              const Text('近场同步', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            
            // 2. 列表标题
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text(
                  '本地已下载同步资产预览',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54),
                ),
              ),
            ),
            
            // 3. Sliver 列表数据
            toolsList.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(
                        child: Text(
                          '无本地缓存资产数据，请进行一次局域网同步',
                          style: TextStyle(fontSize: 12, color: Colors.white30),
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = toolsList[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: const Icon(Icons.build, size: 20, color: Color(0xFF0088CC)),
                            title: Text(
                              '${item['code']} (${item['name']})',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '位置: ${item['location']} | 寿命: ${item['use_count']}/${item['lifespan_limit']}次',
                              style: const TextStyle(fontSize: 11, color: Colors.white54),
                            ),
                            onTap: () => _onAssetItemClicked('${item['code']}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: item['status'] == '在库'
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.amber.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item['status'],
                                style: TextStyle(
                                  color: item['status'] == '在库' ? Colors.green : Colors.amber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: toolsList.length,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // 模拟扫码选择器
  void _showMockScannerSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131722),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📷 摄像头扫码识别模拟器', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
              const SizedBox(height: 4),
              const Text('点击选项以模拟终端扫码成功解析：', style: TextStyle(fontSize: 11, color: Colors.white54)),
              const SizedBox(height: 15),
              ...toolsList.map((t) => ListTile(
                title: Text('模拟扫描刻码: ${t['code']}'),
                subtitle: Text('设备: ${t['name']} (${t['model']})'),
                onTap: () {
                  Navigator.pop(context);
                  _onBarcodeScanned(t['code']);
                },
              )),
              ListTile(
                title: const Text('模拟扫描未建档全新码: TL-MT-999-NEW'),
                subtitle: const Text('物理刻字磨损或库房未建档登记'),
                onTap: () {
                  Navigator.pop(context);
                  _onBarcodeScanned('TL-MT-999-NEW');
                },
              ),
              ListTile(
                title: const Text('模拟扫描零配件条码: ACC-RING-001'),
                subtitle: const Text('氟橡胶密封圈 O-Ring'),
                onTap: () {
                  Navigator.pop(context);
                  _onBarcodeScanned('ACC-RING-001');
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
