// ============================================================
// 文件：screens/main_screen.dart
// 作用：主页面框架，包含底部 4 个 Tab 导航
// Tab 结构（按文档要求）：
//   首页 → 自习室 → 知识小馆 → 我的
// 注意：记账、暖圈关怀、备忘录都收纳在「我的」里，不单独占Tab
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../services/behavior_tracker.dart';
import '../services/proactive_companion.dart';
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

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final AppController _appController = Get.find<AppController>();
  final BehaviorTracker _tracker = Get.find<BehaviorTracker>();

  /// Web 上 [IndexedStack] 偶发只绘制首屏；改用 [PageView] + [jumpToPage] 与底部 Tab 同步。
  late final PageController _pageController =
      PageController(initialPage: 0, keepPage: true);

  @override
  void initState() {
    super.initState();
    // 支持外部通过 Get.toNamed('/main', arguments: {'tab': N}) 指定打开哪个 tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = Get.arguments;
      if (args is Map && args['tab'] is int) {
        final idx = (args['tab'] as int).clamp(0, _pages.length - 1);
        if (idx != 0) _switchTab(idx);
      }
    });
  }

  /// 各 Tab 独立 [ValueKey]，避免 Element 在切换时被错误复用。
  static const List<Widget> _pages = [
    HomeScreen(key: ValueKey<String>('main_tab_home')),
    StudyRoomScreen(key: ValueKey<String>('main_tab_study')),
    KnowledgeScreen(key: ValueKey<String>('main_tab_knowledge')),
    MineScreen(key: ValueKey<String>('main_tab_mine')),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _tracker.setTab(index); // 通知行为感知服务（更新页面语义 + 重置空闲计时）
    // 布局阶段调用 jumpToPage 会触发 ScrollPosition 断言；延后到帧末（Web 上尤其明显）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_pageController.hasClients) return;
      if (_pageController.page?.round() != index) {
        _pageController.jumpToPage(index);
      }
    });
    // 小暖主动观察：根据切到哪个 Tab，决定要不要冒泡
    // 频次保护交给 ProactiveCompanion（每天每 Tab 至多 1 次，全天 4 次上限）
    _maybeFireCompanion(index);
  }

  // tab index → ProactiveCompanion 用的 key
  static const _tabKeys = ['home', 'study', 'knowledge', 'mine'];

  Future<void> _maybeFireCompanion(int index) async {
    if (_appController.aiButtonMode.value != 1) return; // 悬浮按钮关掉时不打扰
    if (index < 0 || index >= _tabKeys.length) return;
    // 稍微延迟，让用户先看到新页面再被小暖说话
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final text = await ProactiveCompanion.contextMessage(_tabKeys[index]);
    if (text == null || !mounted) return;
    _appController.tellCompanion(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 监听点击/触摸开始作为"用户活跃"信号（不监听 move，避免事件风暴）
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _tracker.noteInteraction(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  if (i != _currentIndex) setState(() => _currentIndex = i);
                  _tracker.setTab(i);
                },
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
