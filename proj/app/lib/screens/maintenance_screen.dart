import 'package:flutter/material.dart';
import '../db/local_db.dart';
import 'scan_screen.dart';

class MaintenanceScreen extends StatefulWidget {
  final String toolCode;

  const MaintenanceScreen({super.key, required this.toolCode});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  String selectedLevel = '一级保养';
  List<Map<String, dynamic>> accessories = [];
  String? selectedAccessoryBarcode;
  int qty = 1;

  List<Map<String, dynamic>> tempConsumables = []; // 本次添加的配件缓存
  bool isLoading = true;
  String operatorName = '维保人员';
  String operatorTeam = '未知大队';

  @override
  void initState() {
    super.initState();
    _loadAccessories();
  }

  Future<void> _loadAccessories() async {
    final accs = await LocalDatabase.instance.getAccessories();
    final opName = await LocalDatabase.instance.getSetting('operator_name') ?? '维保人员';
    final opTeam = await LocalDatabase.instance.getSetting('operator_team') ?? '未知大队';
    setState(() {
      accessories = accs;
      if (accs.isNotEmpty) {
        selectedAccessoryBarcode = accs.first['barcode'];
      }
      operatorName = opName;
      operatorTeam = opTeam;
      isLoading = false;
    });
  }

  // 添加消耗
  void _addConsumable() {
    if (selectedAccessoryBarcode == null) return;
    
    final target = accessories.firstWhere((element) => element['barcode'] == selectedAccessoryBarcode);
    if (target['current_stock'] < qty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('【本地存量不足】配件可用数量不足以扣减！')));
      return;
    }

    // 扣减本地列表中的显示存量
    setState(() {
      accessories = accessories.map((element) {
        if (element['barcode'] == selectedAccessoryBarcode) {
          return {
            ...element,
            'current_stock': element['current_stock'] - qty,
          };
        }
        return element;
      }).toList();

      final idx = tempConsumables.indexWhere((element) => element['barcode'] == selectedAccessoryBarcode);
      if (idx > -1) {
        tempConsumables[idx]['qty'] += qty;
      } else {
        tempConsumables.add({
          'barcode': selectedAccessoryBarcode!,
          'name': target['name'],
          'qty': qty,
        });
      }
    });
  }

  // 提交离线维保归库
  Future<void> _handleSubmit() async {
    final timestamp = DateTime.now().toString().split('.')[0];
    
    // 写入离线操作日志
    final log = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'timeStr': timestamp,
      'type': 'MAINTAIN',
      'toolCode': widget.toolCode,
      'operator': operatorName,
      'detail': {
        'level': selectedLevel,
        'team': operatorTeam,
        'consumables': tempConsumables
      }
    };

    final db = await LocalDatabase.instance.database;
    
    // 开启 SQLite 事务更新
    await db.transaction((txn) async {
      // 1. 扣减 SQLite 中的零配件库存
      for (var c in tempConsumables) {
        await txn.rawUpdate(
          'UPDATE accessories SET current_stock = current_stock - ? WHERE barcode = ?',
          [c['qty'], c['barcode']],
        );
      }

      // 2. 更新工具为在库且使用寿命+1
      final tool = await txn.query('tools', where: 'code = ?', whereArgs: [widget.toolCode]);
      if (tool.isNotEmpty) {
        final currentCount = tool.first['use_count'] as int;
        await txn.update(
          'tools',
          {
            'status': '在库',
            'use_count': currentCount + 1,
            'location': '基地总库',
            'last_update_time': timestamp,
            'checkout_time': null,
          },
          where: 'code = ?',
          whereArgs: [widget.toolCode],
        );
      }
    });

    await LocalDatabase.instance.insertLocalLog(log);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('维保保养登记并归库成功 (已离线暂存)')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('维保保养与配件核销')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔧 维保级别配置', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 8),
            Row(
              children: ['一级保养', '二级保养', '大修'].map((lvl) {
                final isSel = selectedLevel == lvl;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ElevatedButton(
                      onPressed: () => setState(() => selectedLevel = lvl),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSel ? const Color(0xFF102A43) : Colors.white.withValues(alpha: 0.02),
                        side: BorderSide(color: isSel ? const Color(0xFF0088CC) : Colors.white12),
                      ),
                      child: Text(lvl, style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 添加消耗配件
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('📦 联动配件消耗核销', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF0088CC), size: 20),
                          tooltip: '扫码定位配件',
                          onPressed: () async {
                            final scannedBarcode = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(builder: (context) => const ScanScreen()),
                            );
                            if (scannedBarcode != null && context.mounted) {
                              final found = accessories.any((a) => a['barcode'] == scannedBarcode);
                              if (found) {
                                setState(() {
                                  selectedAccessoryBarcode = scannedBarcode;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('已成功匹配并选中配件: $scannedBarcode')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('未在本地配件清单中检索到该条码')),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    DropdownButtonFormField<String>(
                      menuMaxHeight: 320,
                      initialValue: selectedAccessoryBarcode,
                      decoration: const InputDecoration(labelText: '选择配件目录'),
                      items: accessories.map<DropdownMenuItem<String>>((a) {
                        return DropdownMenuItem<String>(
                          value: a['barcode'],
                          child: Text('${a['name']} (${a['current_stock']} ${a['unit']})'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => selectedAccessoryBarcode = val),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: '1',
                            decoration: const InputDecoration(labelText: '消耗数量'),
                            keyboardType: TextInputType.number,
                            onChanged: (val) => qty = int.tryParse(val) ?? 1,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _addConsumable,
                          child: const Text('添加消耗'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            const Text('本次消耗核销明细：', style: TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 6),
            Expanded(
              child: tempConsumables.isEmpty
                ? const Center(child: Text('无配件消耗登记', style: TextStyle(fontSize: 12, color: Colors.white30)))
                : ListView.builder(
                    itemCount: tempConsumables.length,
                    itemBuilder: (context, index) {
                      final item = tempConsumables[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(item['name']),
                        trailing: Text('x ${item['qty']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
                      );
                    },
                  ),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('提交并确认归库', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
