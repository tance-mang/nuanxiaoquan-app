// ============================================================
// 文件：main.dart
// 作用：APP 的最最最入口，整个程序从这里启动
// 相当于房子的大门，所有功能都从这里进入
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // 屏幕尺寸适配库，让手机大小不同显示一样
import 'package:get/get.dart';                               // GetX：状态管理 + 路由跳转 + 依赖注入 三合一
import 'package:shared_preferences/shared_preferences.dart'; // 本地轻量存储，存主题/token等小数据
import 'themes/app_themes.dart';
import 'services/api_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/xiaonuan_screen.dart';
import 'screens/memo_screen.dart';
import 'screens/accounting_screen.dart';
import 'screens/room_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/level_detail_screen.dart';
import 'screens/simple_content_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/warmcare_screen.dart';
import 'controllers/app_controller.dart';
import 'screens/study_room_screen.dart';
import 'screens/interest_prefs_screen.dart';
import 'services/behavior_tracker.dart';

// ============================================================
// main函数：程序的起点，async 表示里面有需要等待的操作
// ============================================================
void main() async {
  // 必须先初始化 Flutter 绑定，才能在 main 里用 async
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 API 服务（设置服务器地址、网络配置等）
  await ApiService().init();

  Get.put(AppController());
  // 自习室计时器双实例：lobby（外页个人专注）+ room（房间内共同专注），互不同步
  Get.put(StudyRoomController(), tag: StudyRoomController.lobbyTag, permanent: true);
  Get.put(StudyRoomController(), tag: StudyRoomController.roomTag, permanent: true);
  // 行为感知 & 主动干预（idle 检测 + 微休息弹窗）
  Get.put(BehaviorTracker(), permanent: true);

  runApp(const WarmCircleApp());
}

// ============================================================
// WarmCircleApp：APP 根组件
// StatefulWidget = 有状态的组件（状态变化时会重新渲染界面）
// StatelessWidget = 无状态（内容固定不变）
// ============================================================
class WarmCircleApp extends StatefulWidget {
  const WarmCircleApp({Key? key}) : super(key: key);

  @override
  State<WarmCircleApp> createState() => _WarmCircleAppState();
}

class _WarmCircleAppState extends State<WarmCircleApp> {
  // 当前主题名称，默认是温柔粉
  String _currentTheme = AppThemes.pinkTheme;

  @override
  void initState() {
    super.initState();
    _loadSavedTheme(); // 启动时读取上次保存的主题
  }

  // 从本地存储读取上次用户选择的主题
  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme') ?? AppThemes.pinkTheme;
    setState(() {
      _currentTheme = savedTheme;
    });
  }

  // 切换主题，同时保存到本地（下次打开还是这个主题）
  void changeTheme(String themeName) async {
    setState(() {
      _currentTheme = themeName;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', themeName);
  }

  @override
  Widget build(BuildContext context) {
    // ScreenUtilInit：初始化屏幕适配
    // designSize = 设计稿的基准尺寸（根据 375x812 iPhone X 设计）
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true, // 最小字号适配
      builder: (context, child) {
        // GetMaterialApp 是 GetX 版本的 MaterialApp
        // 比普通 MaterialApp 多了路由管理、对话框等功能
        return GetMaterialApp(
          title: '暖小圈',
          debugShowCheckedModeBanner: false, // 去掉右上角 DEBUG 红色标签
          theme: AppThemes.getTheme(_currentTheme),
          home: const SplashScreen(), // 改为启动页
          locale: const Locale('zh', 'CN'),
          getPages: [
            GetPage(name: '/splash',         page: () => const SplashScreen()),
            GetPage(name: '/login',          page: () => const LoginScreen()),
            GetPage(name: '/main',           page: () => const MainScreen()),
            GetPage(name: '/profile',        page: () => const SimpleContentScreen(
              title: '个人资料',
              emptyIcon: Icons.person_outline,
              emptyText: '个人资料功能开发中',
            )),
            GetPage(name: '/ai-chat',        page: () => const XiaoNuanScreen()),
            GetPage(name: '/create-plan',    page: () => const XiaoNuanScreen()),
            GetPage(name: '/memo',           page: () => const MemoScreen()),
            GetPage(name: '/accounting',     page: () => const AccountingScreen()),
            GetPage(name: '/room-detail',    page: () => const RoomDetailScreen()),
            GetPage(name: '/settings',       page: () => const SettingsScreen()),
            GetPage(name: '/theme-settings', page: () => const SettingsScreen()),
            GetPage(name: '/ai-settings',    page: () => const SettingsScreen()),
            GetPage(name: '/privacy-settings', page: () => const SettingsScreen()),
            GetPage(name: '/level-detail',   page: () => const LevelDetailScreen()),
            GetPage(name: '/my-resources',   page: () => const SimpleContentScreen(
              title: '我的发布',
              emptyIcon: Icons.upload_file_outlined,
              emptyText: '还没有发布任何内容',
            )),
            GetPage(name: '/my-collects',    page: () => const SimpleContentScreen(
              title: '我的收藏',
              emptyIcon: Icons.bookmark_outline,
              emptyText: '还没有收藏内容',
            )),
            GetPage(name: '/my-likes',       page: () => const SimpleContentScreen(
              title: '我的点赞',
              emptyIcon: Icons.thumb_up_outlined,
              emptyText: '还没有点赞过内容',
            )),
            GetPage(name: '/recycle-bin',    page: () => const SimpleContentScreen(
              title: '回收站',
              emptyIcon: Icons.restore_from_trash_outlined,
              emptyText: '回收站为空',
            )),
            GetPage(name: '/feedback',       page: () => const FeedbackScreen()),
            GetPage(name: '/warmcare',       page: () => const WarmCareScreen()),
            GetPage(name: '/interest-prefs', page: () => const InterestPrefsScreen()),
          ],
          // 把 changeTheme 方法存到全局控制器，方便其他页面调用
          builder: (context, widget) {
            // 找到全局控制器，注册主题切换回调
            final controller = Get.find<AppController>();
            controller.onThemeChange = changeTheme;
            return widget!;
          },
        );
      },
    );
  }
}
