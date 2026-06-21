import 'package:flutter/material.dart';
import '../db/local_db.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _uuidController = TextEditingController();

  String? selectedName;
  String? selectedTeam;
  List<String> operators = [];
  List<String> teams = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _uuidController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    // 加载身份字典
    final ops = await LocalDatabase.instance.getDictionaryValues('operator');
    final tms = await LocalDatabase.instance.getDictionaryValues('team');

    // 加载当前设置
    final currentName = await LocalDatabase.instance.getSetting('operator_name');
    final currentTeam = await LocalDatabase.instance.getSetting('operator_team');
    final currentUrl = await LocalDatabase.instance.getSetting('sync_server_url') ?? 'http://192.168.1.100:8080';
    final currentUuid = await LocalDatabase.instance.getSetting('terminal_uuid') ?? 'terminal-handheld-001';

    // 进行去重处理，防止后端返回重复字典项导致 Dropdown 报 key 重复崩溃
    final distinctOps = ops.toSet().toList();
    final distinctTms = tms.toSet().toList();

    setState(() {
      operators = distinctOps.isNotEmpty ? distinctOps : ['张建国', '李志刚', '王超', '赵强'];
      teams = distinctTms.isNotEmpty ? distinctTms : ['川庆钻探一队', '中原石油三队', '江汉作业五队'];

      // 安全边界处理：确保初始选择的值在选项列表中，防止 zero 匹配红屏
      selectedName = currentName;
      if (selectedName == null || !operators.contains(selectedName)) {
        selectedName = operators.isNotEmpty ? operators.first : null;
      }

      selectedTeam = currentTeam;
      if (selectedTeam == null || !teams.contains(selectedTeam)) {
        selectedTeam = teams.isNotEmpty ? teams.first : null;
      }
      
      _urlController.text = currentUrl;
      _uuidController.text = currentUuid;
      isLoading = false;
    });
  }

  Future<void> _saveAll() async {
    if (selectedName == null || selectedTeam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作人或大队不可为空')),
      );
      return;
    }

    final url = _urlController.text.trim();
    final uuid = _uuidController.text.trim();

    if (url.isEmpty || uuid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('服务器地址或终端 UUID 不能为空')),
      );
      return;
    }

    await LocalDatabase.instance.saveSetting('operator_name', selectedName!);
    await LocalDatabase.instance.saveSetting('operator_team', selectedTeam!);
    await LocalDatabase.instance.saveSetting('sync_server_url', url);
    await LocalDatabase.instance.saveSetting('terminal_uuid', uuid);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置保存成功')),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0C10),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF102A43),
        title: const Text('系统手持配置', style: TextStyle(fontSize: 16, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 分组 1: 当前操作身份
            const Text(
              '👤 操作员身份切换',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF131722),
                      initialValue: selectedName,
                      decoration: const InputDecoration(labelText: '当前操作人'),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: operators.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                      onChanged: (val) => setState(() => selectedName = val),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF131722),
                      initialValue: selectedTeam,
                      decoration: const InputDecoration(labelText: '所属作业大队'),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: teams.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setState(() => selectedTeam = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 分组 2: 局域网同步网络配置
            const Text(
              '⚙️ 近场局域网同步配置',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _urlController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: '中枢服务器 API 地址',
                        hintText: 'http://192.168.1.100:8080',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _uuidController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: '手持终端 UUID',
                        hintText: 'terminal-handheld-001',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),

            // 保存按钮
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _saveAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0088CC),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('保 存 全 部 配 置', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
