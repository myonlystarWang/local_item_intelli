import 'package:flutter/material.dart';
import 'db/local_db.dart';
import 'screens/home_screen.dart';
import 'screens/identity_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ItemIntelliApp());
}

class ItemIntelliApp extends StatelessWidget {
  const ItemIntelliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '精密工具智能化管理系统',
      debugShowCheckedModeBanner: false,
      
      // 设置 Material 3 暗色调设计系统 (配合深海蓝 + 金色高亮)
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0C10),     // 背景暗黑色
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0088CC),        // 亮蓝色 (App高亮)
          secondary: Color(0xFFD4AF37),      // 金属金 (警示/次要)
          surface: Color(0xFF131722),        // 卡片底色
          error: Color(0xFFEF4444),          // 红色拦截
          onPrimary: Colors.white,
          onSecondary: Colors.black,
        ),
        
        // CJK 及 现代英文字形设置
        fontFamily: 'Roboto',
        
        // 按钮及卡片默认圆角风格定义
        cardTheme: CardThemeData(
          color: const Color(0xFF131722),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF102A43),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          ),
        ),
        
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF0088CC)),
          ),
        ),
      ),
      home: FutureBuilder<String?>(
        future: LocalDatabase.instance.getSetting('operator_name'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0A0C10),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data == null || snapshot.data!.isEmpty) {
            return const IdentityScreen();
          }
          return const HomeScreen();
        },
      ),
    );
  }
}
