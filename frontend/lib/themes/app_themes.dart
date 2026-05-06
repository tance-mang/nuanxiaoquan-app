// ============================================================
// 文件：themes/app_themes.dart
// 作用：5种主题配置，一键全局换色
// 主题列表：简约灰 / 清新蓝 / 优雅紫 / 温柔粉 / 薄荷绿
// 使用方法：AppThemes.getTheme('blue') 获取蓝色主题
// ============================================================

import 'package:flutter/material.dart';

class AppThemes {
  // 主题名称常量（这些字符串存在SharedPreferences里）
  static const String defaultTheme = 'default'; // 简约灰
  static const String blueTheme = 'blue';       // 清新蓝
  static const String purpleTheme = 'purple';   // 优雅紫
  static const String pinkTheme = 'pink';       // 温柔粉
  static const String mintTheme = 'mint';       // 薄荷绿

  /// 根据主题名称获取对应的 ThemeData
  static ThemeData getTheme(String themeName) {
    switch (themeName) {
      case blueTheme:
        return _buildTheme(
          primary: const Color(0xFF5B9BD5),   // 主色：清新蓝
          accent: const Color(0xFF9DC3E6),    // 辅色：浅蓝
          name: '清新蓝',
        );
      case purpleTheme:
        return _buildTheme(
          primary: const Color(0xFF9B7EBD),
          accent: const Color(0xFFD4C5E2),
          name: '优雅紫',
        );
      case pinkTheme:
        return _buildTheme(
          primary: const Color(0xFFE89DAC),
          accent: const Color(0xFFF4D5DC),
          name: '温柔粉',
        );
      case mintTheme:
        return _buildTheme(
          primary: const Color(0xFF7CBEA7),
          accent: const Color(0xFFB8DDD0),
          name: '薄荷绿',
        );
      default: // 简约灰（默认）
        return _buildTheme(
          primary: const Color(0xFF8B8B8B),
          accent: const Color(0xFFD3D3D3),
          name: '简约灰',
        );
    }
  }

  /// 构建主题数据
  /// 一个函数构建所有主题，只有颜色不同，结构复用
  static ThemeData _buildTheme({
    required Color primary,
    required Color accent,
    required String name,
  }) {
    return ThemeData(
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        secondary: accent,
      ),
      // 页面背景色（浅灰，不是纯白，眼睛更舒服）
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),

      // AppBar（顶部导航栏）样式
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: Color(0xFF333333),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        // 底部细线，随主题色变化，区分标题栏和内容区域
        shape: Border(
          bottom: BorderSide(color: primary.withOpacity(0.18), width: 1.0),
        ),
      ),

      // 卡片样式（白色圆角，轻微阴影）
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.white,
      ),

      // 按钮样式
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      // 文字样式
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
        headlineMedium: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF666666)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF999999)),
      ),

      // 输入框样式
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // 底部导航栏样式
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,            // 选中Tab用主题色
        unselectedItemColor: const Color(0xFF999999), // 未选中灰色
        type: BottomNavigationBarType.fixed,   // 固定类型（不放大选中项）
        elevation: 8,
        selectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),

      // Tab栏样式
      tabBarTheme: TabBarTheme(
        labelColor: primary,
        unselectedLabelColor: const Color(0xFF999999),
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
    );
  }

  /// 主题列表（用于主题选择页面展示）
  static List<Map<String, dynamic>> get themeList => [
    {
      'name': defaultTheme,
      'title': '简约灰',
      'color': const Color(0xFF8B8B8B),
      'desc': '清爽简洁，专注学习',
    },
    {
      'name': blueTheme,
      'title': '清新蓝',
      'color': const Color(0xFF5B9BD5),
      'desc': '沉静专注，如海洋般辽阔',
    },
    {
      'name': purpleTheme,
      'title': '优雅紫',
      'color': const Color(0xFF9B7EBD),
      'desc': '优雅知性，气质独特',
    },
    {
      'name': pinkTheme,
      'title': '温柔粉',
      'color': const Color(0xFFE89DAC),
      'desc': '温暖甜蜜，给学习加点温柔',
    },
    {
      'name': mintTheme,
      'title': '薄荷绿',
      'color': const Color(0xFF7CBEA7),
      'desc': '清新自然，清凉一下',
    },
  ];
}
