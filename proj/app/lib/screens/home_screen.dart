import 'package:flutter/material.dart';
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
  bool isOnline = true; // 模拟物理网络开关
  int pendingSyncCount = 0;
  List<Map<String, dynamic>> toolsList = [];
  String operatorName = '';
  String operatorTeam = '';

  @override
  void initState() {
    super.initState();
    _loadLocalData();
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

  // 模拟摄像头扫码成功事件，跳转到详情
  void _onBarcodeScanned(String barcode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailScreen(
          barcode: barcode,
          isOnline: isOnline,
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
          // 物理网络模拟开关
          IconButton(
            icon: Icon(
              isOnline ? Icons.wifi : Icons.wifi_off,
              color: isOnline ? Colors.green : Colors.red,
            ),
            tooltip: isOnline ? '已连接局域网 Wi-Fi' : '断网离线模式',
            onPressed: () {
              setState(() {
                isOnline = !isOnline;
              });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(isOnline ? '已接入库房局域网信道' : '已进入井口无网脱机状态'),
                duration: const Duration(seconds: 1),
              ));
            },
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
              if (updated == true && mounted) {
                _loadLocalData();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 智能离线扫描大卡片
            GestureDetector(
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
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF102A43), Color(0xFF243B53)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.qr_code_scanner, size: 48, color: Color(0xFF0088CC)),
                      SizedBox(height: 12),
                      Text('智能离线扫描识读', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 4),
                      Text('秒级解析物理刻码与配件三防标签', style: TextStyle(fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // 2. 近场数据同步卡片
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SyncScreen(isOnline: isOnline),
                  ),
                ).then((_) => _loadLocalData());
              },
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.sync_alt, size: 28, color: Color(0xFFD4AF37)),
                          ),
                          if (pendingSyncCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                child: Text(
                                  '$pendingSyncCount',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('局域网近场同步', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('回库一键对齐与冲突校验合并', style: TextStyle(fontSize: 11, color: Colors.white70)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white30),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            // 3. 本地在库字典列表清单 (预览)
            const Text(
              '本地已下载同步资产预览',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: toolsList.isEmpty
                ? const Center(child: Text('无本地缓存资产数据，请进行一次局域网同步', style: TextStyle(fontSize: 12, color: Colors.white30)))
                : ListView.builder(
                    itemCount: toolsList.length,
                    itemBuilder: (context, index) {
                      final item = toolsList[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.build, size: 20, color: Color(0xFF0088CC)),
                        title: Text('${item['code']} (${item['name']})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text('位置: ${item['location']} | 寿命: ${item['use_count']}/${item['lifespan_limit']}次', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                        onTap: () => _onBarcodeScanned('${item['code']}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: item['status'] == '在库' ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item['status'],
                            style: TextStyle(color: item['status'] == '在库' ? Colors.green : Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
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
