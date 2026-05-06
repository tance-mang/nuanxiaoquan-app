// ============================================================
// 文件：screens/main_screen.dart
// 作用：主页面框架，包含底部 4 个 Tab 导航
// Tab 结构（按文档要求）：
//   首页 → 自习室 → 知识小馆 → 我的
// 注意：记账、生理期、备忘录都收纳在「我的」里，不单独占Tab
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../widgets/ai_float_button.dart'; // AI 小暖悬浮按钮组件
import '../widgets/focus_progress_bar.dart'; // 全局专注光影进度条
import 'home_screen.dart';
import 'study_room_screen.dart';
import 'knowledge_screen.dart';
import 'mine_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final AppController _appController = Get.find<AppController>();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final List<Widget> _pages = const [
    HomeScreen(),
    StudyRoomScreen(),
    KnowledgeScreen(),
    MineScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.value = 1.0;
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _switchTab(int index) async {
    if (index == _currentIndex) return;
    await _fadeCtrl.reverse();
    setState(() => _currentIndex = index);
    _fadeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnim,
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
          Obx(() {
            if (_appController.aiButtonMode.value == 0 ||
                _appController.aiButtonMode.value == 2) {
              return const SizedBox.shrink();
            }
            return const AiFloatButton();
          }),
          // 全局光影专注进度条（最顶层，所有页面共享）
          const FocusProgressBar(),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _switchTab,
        // fixed 类型：图标始终显示文字，不随选中状态改变
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),  // 选中时换填充图标
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer_outlined),
            activeIcon: Icon(Icons.timer),
            label: '自习室',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books_outlined),
            activeIcon: Icon(Icons.library_books),
            label: '知识小馆',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
