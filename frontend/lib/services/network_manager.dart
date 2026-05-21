// ════════════════════════════════════════════════════════════
// 文件：services/network_manager.dart
// 作用：网络状态管理器（离线模式核心）
// 功能：
//   1. 自动检测网络连接状态（有网/断网）
//   2. 离线时拦截所有AI请求，不报错
//   3. 网络恢复自动切回在线模式
//   4. 全局监听，所有页面共享网络状态
// ════════════════════════════════════════════════════════════

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// 网络状态管理器（GetX控制器，全局单例）
class NetworkManager extends GetxController {
  // connectivity_plus 插件实例
  final Connectivity _connectivity = Connectivity();

  // 当前网络状态（响应式变量，自动通知UI更新）
  // true = 有网络，false = 离线
  final RxBool isOnline = true.obs;

  // 是否首次检测完成（避免启动时误判）
  final RxBool isInitialized = false.obs;

  @override
  void onInit() {
    super.onInit();
    _checkInitialConnection();  // 启动时检测一次
    _listenToConnectionChanges(); // 持续监听网络变化
  }

  // ════════════════════════════════════════════════════════════
  // 初次检测网络状态
  // ════════════════════════════════════════════════════════════
  Future<void> _checkInitialConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
      isInitialized.value = true;

      if (isOnline.value) {
        print('✅ 网络已连接，在线模式');
      } else {
        print('⚠️ 当前离线，仅可查看历史数据');
      }
    } catch (e) {
      print('❌ 网络检测失败: $e');
      isOnline.value = false;
      isInitialized.value = true;
    }
  }

  // ════════════════════════════════════════════════════════════
  // 监听网络变化（实时更新）
  // ════════════════════════════════════════════════════════════
  void _listenToConnectionChanges() {
    _connectivity.onConnectivityChanged.listen((results) {
      _updateConnectionStatus(results);

      if (isOnline.value) {
        Get.snackbar(
          '网络已连接',
          '已切换到在线模式，可使用AI功能',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
        );
      } else {
        Get.snackbar(
          '网络已断开',
          '当前离线模式，仅可查看历史数据',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
        );
      }
    });
  }

  // ════════════════════════════════════════════════════════════
  // 更新网络状态
  // ════════════════════════════════════════════════════════════
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasConnection = results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);

    isOnline.value = hasConnection;
  }

  Future<bool> checkConnection() async {
    final results = await _connectivity.checkConnectivity();
    _updateConnectionStatus(results);
    return isOnline.value;
  }

  // ════════════════════════════════════════════════════════════
  // 主动检查网络（手动刷新时调用）
  // ════════════════════════════════════════════════════════════

  // ════════════════════════════════════════════════════════════
  // 需要网络时的拦截器（在调用AI前调用）
  // 返回 false = 离线，不允许继续
  // 返回 true = 在线，允许继续
  // ════════════════════════════════════════════════════════════
  bool requireOnline({String? message}) {
    if (!isOnline.value) {
      Get.snackbar(
        '需要网络连接',
        message ?? '此功能需要联网，请连接网络后重试',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return false; // 拦截
    }
    return true; // 放行
  }
}
