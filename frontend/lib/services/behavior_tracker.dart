// ============================================================
// 行为感知 & 主动干预服务（C 类落地核心）
//
// 设计原则（来自产品规约）：
//   - 不采集摄像头/麦克风等敏感数据，只用页面语义 + 用户主动交互
//   - 仅在【自习室页面】且【计时器在跑】才考虑干预
//   - 在【知识小馆 / 语录】等探索页不视为分心
//   - 触发干预后一次性提示，用户继续后重置（不重复打扰）
//   - 文案去评价化（不说"你分心了"，说"专注挺久了"）
//
// 触发条件：
//   IF 在自习室 surface AND 计时器在跑 AND 无交互 > 3 分钟
//      THEN 弹出微休息弹窗（带 4 个兴趣活动建议 + 继续专注按钮）
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../screens/study_room_screen.dart';
import '../screens/interest_prefs_screen.dart';

class BehaviorTracker extends GetxController with WidgetsBindingObserver {
  // 主屏 4 个 Tab 的索引
  static const int tabHome = 0;
  static const int tabStudy = 1;
  static const int tabKnowledge = 2;
  static const int tabMine = 3;

  /// 当前主屏 Tab（非主屏路由如房间详情时仍保留上一个值，但用 inRoomDetail 单独标记）
  final RxInt currentTab = RxInt(tabHome);

  /// 是否在房间详情页（用 Get 路由生命周期 hook 维护）
  final RxBool inRoomDetail = RxBool(false);

  DateTime _lastInteraction = DateTime.now();
  bool _popupShown = false;
  Timer? _check;

  // ── App 生命周期感知（切屏到别的 App 再切回来时使用）──
  DateTime? _backgroundedAt;
  /// 切回来后只要离开超过这个时长，才考虑提示"计时器还在跑哦"
  static const Duration _backgroundGraceForHint = Duration(seconds: 30);

  /// 空闲阈值（生产 3 分钟）。可由调用方调整以便调试。
  Duration idleThreshold = const Duration(minutes: 3);

  // 兴趣活动池从用户设置（SharedPreferences）读取，无设置时回退到内置默认。
  // 见 InterestPrefsScreen / loadInterestActivities()

  @override
  void onInit() {
    super.onInit();
    // 每 30 秒检查一次，足够灵敏又不耗电
    _check = Timer.periodic(const Duration(seconds: 30), (_) => _evaluate());
    // 监听 app 生命周期：切到后台 / 切回前台
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    _check?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  /// app 生命周期回调（Flutter 提供）
  /// paused = 切到后台 / inactive = 短暂失焦 / resumed = 回到前台
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  void _handleResume() {
    final bgAt = _backgroundedAt;
    _backgroundedAt = null;
    noteInteraction(); // 切回来本身就是一次活跃信号

    if (bgAt == null) return;
    final away = DateTime.now().difference(bgAt);
    if (away < _backgroundGraceForHint) return;
    if (!_anyTimerRunning) return;

    // 用户切走超过 30 秒且专注计时仍在跑 → 温柔提醒（不弹窗，用 snackbar）
    try {
      final ac = Get.find<AppController>();
      if (!ac.microRestEnabled.value) return;
    } catch (_) {}

    final minutes = (away.inSeconds / 60).toStringAsFixed(1);
    Get.snackbar(
      '欢迎回来 🌿',
      '你离开了 $minutes 分钟，专注计时还在跑哦',
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFFFFF7ED),
      colorText: const Color(0xFF7C2D12),
      margin: EdgeInsets.all(14.w),
      borderRadius: 12,
      duration: const Duration(seconds: 4),
      icon: const Icon(Icons.access_time_rounded,
          color: Color(0xFFC2410C)),
    );
  }

  // ── 外部调用接口 ───────────────────────────────────────────

  /// 用户有任何交互（tap、scroll、navigate 等）时调用
  void noteInteraction() {
    _lastInteraction = DateTime.now();
    _popupShown = false; // 重置：下一轮空闲又可以触发
  }

  /// MainScreen 切 Tab 时调用
  void setTab(int index) {
    currentTab.value = index;
    noteInteraction();
  }

  /// RoomDetailScreen 进入 / 离开时调用
  void setInRoom(bool v) {
    inRoomDetail.value = v;
    noteInteraction();
  }

  // ── 内部判定 ───────────────────────────────────────────────

  /// 当前是否处于"自习"语义页面
  /// 知识小馆 / 首页 / 我的 不算（即使在 Tab 之间切换也是有效活动）
  bool get _onStudySurface =>
      currentTab.value == tabStudy || inRoomDetail.value;

  /// 任一计时器在跑
  bool get _anyTimerRunning {
    try {
      final lobby = Get.find<StudyRoomController>(
          tag: StudyRoomController.lobbyTag);
      final room = Get.find<StudyRoomController>(
          tag: StudyRoomController.roomTag);
      return lobby.isRunning.value || room.isRunning.value;
    } catch (_) {
      return false;
    }
  }

  void _evaluate() {
    if (_popupShown) return;
    if (!_onStudySurface) return;
    if (!_anyTimerRunning) return;

    // 读用户设置：开关 + 自定义阈值
    Duration threshold = idleThreshold;
    try {
      final ac = Get.find<AppController>();
      if (!ac.microRestEnabled.value) return; // 用户关闭了微休息提示
      threshold = Duration(minutes: ac.microRestIdleMinutes.value);
    } catch (_) {
      // AppController 不可达就用默认 3 分钟
    }

    final idle = DateTime.now().difference(_lastInteraction);
    if (idle < threshold) return;

    _popupShown = true;
    _showMicroRest();
  }

  // ── 微休息弹窗 ────────────────────────────────────────────

  void _showMicroRest() async {
    if (Get.context == null) return;
    // 异步从设置中读取用户启用的活动池；为空兜底用内置默认
    final list = await loadInterestActivities();
    if (Get.context == null || !Get.isOverlaysOpen) {
      // 弹窗前再次确认仍处于自习 surface（避免用户已离开）
      if (!_onStudySurface || !_anyTimerRunning) {
        _popupShown = false;
        return;
      }
    }
    final rng = Random();
    final picks = List<InterestActivity>.from(list)..shuffle(rng);

    Get.dialog(
      _MicroRestDialog(activities: picks, onAny: noteInteraction),
      barrierDismissible: false,
    );
  }

  /// 公开：用户在设置页主动预览微休息弹窗（绕过 surface/idle 判定）
  Future<void> previewMicroRest() async {
    if (Get.context == null) return;
    final list = await loadInterestActivities();
    final rng = Random();
    final picks = List<InterestActivity>.from(list)..shuffle(rng);
    Get.dialog(
      _MicroRestDialog(activities: picks, onAny: noteInteraction),
      barrierDismissible: true,
    );
  }
}

// ============================================================
// 弹窗 UI ：去评价化、温和、可一键继续专注
// ============================================================
class _MicroRestDialog extends StatelessWidget {
  final List<InterestActivity> activities;
  final VoidCallback onAny;
  const _MicroRestDialog({required this.activities, required this.onAny});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '看起来你专注挺久了',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111827),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '状态好的时候间歇休息一下，反而能走得更远。\n试一个吧：',
              style: TextStyle(
                fontSize: 12.5.sp,
                color: Colors.grey[600],
                height: 1.55,
              ),
            ),
            SizedBox(height: 16.h),
            ...activities.map((a) => Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: _ActivityTile(
                    activity: a,
                    onTap: () {
                      onAny();
                      Get.back();
                      Get.snackbar(
                        '${a.emoji} 已选择：${a.title}',
                        '5 分钟后再回来继续专注',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: primary.withOpacity(0.92),
                        colorText: Colors.white,
                        margin: EdgeInsets.all(14.w),
                        borderRadius: 12,
                        duration: const Duration(seconds: 3),
                      );
                    },
                  ),
                )),
            SizedBox(height: 4.h),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () {
                  onAny();
                  Get.back();
                },
                child: Text(
                  '我先继续专注',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final InterestActivity activity;
  final VoidCallback onTap;
  const _ActivityTile({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Text(activity.emoji, style: TextStyle(fontSize: 20.sp)),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    activity.desc,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 13.sp, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
