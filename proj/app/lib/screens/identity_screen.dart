import 'package:flutter/material.dart';
import '../db/local_db.dart';
import 'home_screen.dart';

class IdentityScreen extends StatefulWidget {
  const IdentityScreen({super.key});

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  String? selectedName;
  String? selectedTeam;
  List<String> operators = [];
  List<String> teams = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDicts();
  }

  Future<void> _loadDicts() async {
    final ops = await LocalDatabase.instance.getDictionaryValues('operator');
    final tms = await LocalDatabase.instance.getDictionaryValues('team');
    setState(() {
      operators = ops.isNotEmpty ? ops : ['张建国', '李志刚', '王超', '赵强'];
      teams = tms.isNotEmpty ? tms : ['川庆钻探一队', '中原石油三队', '江汉作业五队'];
      
      // 默认选中第一个
      if (operators.isNotEmpty) selectedName = operators.first;
      if (teams.isNotEmpty) selectedTeam = teams.first;
      
      isLoading = false;
    });
  }

  Future<void> _confirm() async {
    if (selectedName == null || selectedTeam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择操作人及所属大队')),
      );
      return;
    }

    await LocalDatabase.instance.saveSetting('operator_name', selectedName!);
    await LocalDatabase.instance.saveSetting('operator_team', selectedTeam!);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF131722),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 顶部质感徽章图标
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF102A43),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0088CC), width: 1.5),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 48,
                      color: Color(0xFF0088CC),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '手持终端身份确认',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  '当前处于井口脱机模式，操作日志将自动与声明的身份信息进行追溯对齐',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // 磨砂质感玻璃容器卡片
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF102A43).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 姓名选择
                      DropdownButtonFormField<String>(
                        dropdownColor: const Color(0xFF131722),
                        initialValue: selectedName,
                        decoration: const InputDecoration(
                          labelText: '操作人姓名',
                          labelStyle: TextStyle(color: Colors.white70, fontSize: 13),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF0088CC)),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        items: operators
                            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                            .toList(),
                        onChanged: (val) => setState(() => selectedName = val),
                      ),
                      const SizedBox(height: 20),

                      // 所属大队选择
                      DropdownButtonFormField<String>(
                        dropdownColor: const Color(0xFF131722),
                        initialValue: selectedTeam,
                        decoration: const InputDecoration(
                          labelText: '所属大队/队组',
                          labelStyle: TextStyle(color: Colors.white70, fontSize: 13),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF0088CC)),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        items: teams
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (val) => setState(() => selectedTeam = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // 确认进入系统的按钮
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0088CC),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '确 认 身 份',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
