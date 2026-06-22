import 'package:flutter/material.dart';
import '../db/local_db.dart';
import 'maintenance_screen.dart';

class DetailScreen extends StatefulWidget {
  final String barcode;
  final bool isOnline;

  const DetailScreen({super.key, required this.barcode, required this.isOnline});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  Map<String, dynamic>? toolData;
  Map<String, dynamic>? accessoryData;
  bool isLoading = true;
  bool isUnknown = false;

  // 字典缓存
  List<String> wellbores = [];

  // 表单状态
  String? selectedOperator;
  String? selectedTeam;
  String? selectedWellbore;
  int returnDays = 30;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    // 判定是否是配件
    if (widget.barcode.startsWith('ACC-')) {
      final acc = await LocalDatabase.instance.getAccessories();
      final target = acc.firstWhere((element) => element['barcode'] == widget.barcode, orElse: () => {});
      setState(() {
        accessoryData = target.isNotEmpty ? target : null;
        isUnknown = target.isEmpty;
        isLoading = false;
      });
      return;
    }

    final tool = await LocalDatabase.instance.getTool(widget.barcode);
    if (tool == null) {
      setState(() {
        isUnknown = true;
        isLoading = false;
      });
      return;
    }

    final wbs = await LocalDatabase.instance.getDictionaryValues('wellbore');
    final currentOp = await LocalDatabase.instance.getSetting('operator_name') ?? '当前操作人';
    final currentTm = await LocalDatabase.instance.getSetting('operator_team') ?? '未知大队';

    setState(() {
      toolData = tool;
      wellbores = wbs.isNotEmpty ? wbs : ['川科1井', '深地塔科1井', '威页23-4井', '大庆102井'];
      
      selectedOperator = currentOp;
      selectedTeam = currentTm;
      if (wellbores.isNotEmpty) selectedWellbore = wellbores.first;
      
      isLoading = false;
    });
  }

  // 1. 领用出库
  Future<void> _handleCheckOut() async {
    if (selectedOperator == null || selectedTeam == null || selectedWellbore == null) return;
    
    final timestamp = DateTime.now().toString().split('.')[0];
    final log = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'timeStr': timestamp,
      'type': 'CHECKOUT',
      'toolCode': widget.barcode,
      'operator': selectedOperator!,
      'detail': {
        'wellbore': selectedWellbore!,
        'team': selectedTeam!,
        'return_days': returnDays
      }
    };

    // 写入 SQLite
    final db = await LocalDatabase.instance.database;
    await db.update(
      'tools',
      {
        'status': '离库',
        'location': selectedWellbore!,
        'operator': selectedOperator!,
        'last_update_time': timestamp,
        'checkout_time': timestamp,
      },
      where: 'code = ?',
      whereArgs: [widget.barcode],
    );

    await LocalDatabase.instance.insertLocalLog(log);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('本地领用出库成功对齐')));
      Navigator.pop(context);
    }
  }

  // 2. 地点变更
  Future<void> _handleChangeLocation() async {
    if (selectedWellbore == null) return;
    
    final timestamp = DateTime.now().toString().split('.')[0];
    final log = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'timeStr': timestamp,
      'type': 'CHANGE_LOC',
      'toolCode': widget.barcode,
      'operator': selectedOperator ?? '当前责任人',
      'detail': {
        'wellbore': selectedWellbore!,
        'team': selectedTeam ?? '未知大队',
      }
    };

    final db = await LocalDatabase.instance.database;
    await db.update(
      'tools',
      {
        'status': '地点变更',
        'location': selectedWellbore!,
        'operator': selectedOperator ?? '当前责任人',
        'last_update_time': timestamp,
      },
      where: 'code = ?',
      whereArgs: [widget.barcode],
    );

    await LocalDatabase.instance.insertLocalLog(log);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('地点离线调拨成功')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // A. 拦截未登记新刻码 (PRD 规则一致性修改)
    if (isUnknown) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('扫描拦截')),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.gpp_bad, size: 72, color: theme.colorScheme.error),
              const SizedBox(height: 20),
              Text(
                '未登记精密资产！',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.error),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '物理条码 [${widget.barcode}] 尚未在库房中枢建档登记。\n\n为规避野外井下安全及账面资产数据混乱风险，本地状态机已实施硬性流转拦截。请联系库管员建档初始化后重新操作。',
                  style: const TextStyle(fontSize: 12, height: 1.6, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回重新扫描'),
              ),
            ],
          ),
        ),
      );
    }

    // 配件详情视图
    if (accessoryData != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('零配件档案')),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${accessoryData!['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('条码: ${accessoryData!['barcode']}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildRow('规格型号', '${accessoryData!['spec']}'),
                      const Divider(height: 20),
                      _buildRow('水位预警值', '${accessoryData!['safety_stock']} ${accessoryData!['unit']}'),
                      const Divider(height: 20),
                      _buildRow('手持端库存', '${accessoryData!['current_stock']} ${accessoryData!['unit']}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isMax = toolData!['use_count'] >= toolData!['lifespan_limit'];

    return Scaffold(
      appBar: AppBar(title: Text(toolData!['name'])),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF102A43), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.build, color: Color(0xFF0088CC)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.barcode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('型号: ${toolData!['model']}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: toolData!['status'] == '在库' ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      toolData!['status'],
                      style: TextStyle(color: toolData!['status'] == '在库' ? Colors.green : Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // 寿命上限拦截警告
              if (isMax)
                Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '⚠️ 状态机致命拦截：当前工具使用次数 (${toolData!['use_count']}) 已达到核准寿命极限 (${toolData!['lifespan_limit']})。本地离线控制器已锁定其出库动作！',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFFCA5A5), height: 1.5),
                  ),
                ),

              // 档案大卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildRow('累计使用寿命', '${toolData!['use_count']} / ${toolData!['lifespan_limit']} 次'),
                      const Divider(height: 20),
                      _buildRow('当前物理位置', '${toolData!['location']}'),
                      const Divider(height: 20),
                      _buildRow('最近操作责任人', '${toolData!['operator']}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 出库领用 / 维保归库表单域
              if (toolData!['status'] == '在库' && !isMax) ...[
                const Text('🚀 领用出库登记', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('责任领用人：$selectedOperator', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text('所属作业队：$selectedTeam', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  menuMaxHeight: 320,
                  initialValue: selectedWellbore,
                  decoration: const InputDecoration(labelText: '目标作业井号'),
                  items: wellbores.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                  onChanged: (val) => setState(() => selectedWellbore = val),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('预计归还期限：', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    Expanded(
                      child: Slider(
                        value: returnDays.toDouble(),
                        min: 7,
                        max: 90,
                        divisions: 83,
                        label: '$returnDays 天',
                        activeColor: const Color(0xFF0088CC),
                        inactiveColor: Colors.white12,
                        onChanged: (val) => setState(() => returnDays = val.toInt()),
                      ),
                    ),
                    Text('$returnDays 天', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD4AF37), fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleCheckOut,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('确认领用出库', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],

              if (toolData!['status'] == '离库' || toolData!['status'] == '地点变更') ...[
                // 地点变更
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📍 现场工况井号变更', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0088CC))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                menuMaxHeight: 320,
                                initialValue: selectedWellbore,
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                                items: wellbores.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                                onChanged: (val) => setState(() => selectedWellbore = val),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _handleChangeLocation,
                              child: const Text('变更'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                
                // 保养维保
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MaintenanceScreen(
                            toolCode: widget.barcode,
                          ),
                        ),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('进入归库保养与配件核销', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
