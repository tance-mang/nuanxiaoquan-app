// ============================================================
// 文件：screens/study_room_screen.dart
// 作用：自习室页面
// 核心功能：
//   - 暖圈钟（番茄专注计时）
//   - 跨页面后台保活计时（切Tab不中断）
//   - 退出房间时生成迷你挂件悬浮在其他页面
//   - 房间内用户点击头像弹出简易信息卡
//   - 全程无文字聊天，纯专注工具
// ============================================================

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/app_controller.dart';
import '../services/proactive_companion.dart';
import '../services/strength_engine.dart';
import '../widgets/judge_hint_bar.dart';

// ============================================================
// 自习室专属控制器（GetX控制器，跨页面保活）
// 为什么用控制器而不是 State？
// 因为 State 随页面销毁会消失，而 GetX 控制器注入后全局存活
// 切换到其他 Tab 计时不会中断
// ============================================================
class StudyRoomController extends GetxController {
  // 实例标签：lobby = 自习室外（个人番茄钟），room = 房间内（房间共同专注）
  // 两个实例独立运行，互不同步
  static const String lobbyTag = 'lobby';
  static const String roomTag = 'room';

  // 是否正在计时
  final RxBool isRunning = false.obs;

  // 本次专注设定总时长（秒），默认25分钟
  final RxInt focusTotalDuration = 1500.obs;

  // 剩余秒数
  final RxInt remainingSeconds = 1500.obs;

  // 累计专注秒数（跨多轮）
  final RxInt totalFocusSeconds = 0.obs;

  // 后台保活：记录最后更新时间戳
  int? _lastUpdateTime;

  // 全局光影条进度 0.0~1.0
  double get focusProgress {
    final total = focusTotalDuration.value;
    if (total <= 0) return 0.0;
    return (1.0 - remainingSeconds.value / total).clamp(0.0, 1.0);
  }

  // 设置专注时长（仅在非计时中时生效）
  void setDuration(int seconds) {
    if (isRunning.value) return;
    focusTotalDuration.value = seconds;
    remainingSeconds.value = seconds;
  }

  // 是否有活跃的房间（决定是否显示迷你挂件）
  final RxBool hasActiveRoom = false.obs;

  // 房间名称
  final RxString currentRoomName = ''.obs;

  // 定时器
  Timer? _timer;

  // 每日累计专注秒数（持久化）批量写入用的缓冲计数器
  int _focusBufferSec = 0;

  // 开始计时
  void startTimer() {
    if (isRunning.value) return; // 已经在计时了，不重复启动
    isRunning.value = true;
    _lastUpdateTime = DateTime.now().millisecondsSinceEpoch;

    // 每秒执行一次
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = ((now - (_lastUpdateTime ?? now)) / 1000).round();

      if (remainingSeconds.value > 0) {
        final used = elapsed.clamp(1, remainingSeconds.value);
        remainingSeconds.value -= used;
        totalFocusSeconds.value += elapsed;
        _focusBufferSec += elapsed;
        _lastUpdateTime = now;
        // 每 10 秒写一次 SharedPreferences（per-second 写太频繁）
        if (_focusBufferSec >= 10) {
          _persistFocus(_focusBufferSec);
          _focusBufferSec = 0;
        }
      } else {
        // 计时结束
        if (_focusBufferSec > 0) {
          _persistFocus(_focusBufferSec);
          _focusBufferSec = 0;
        }
        stopTimer();
        _onTimerComplete();
      }
    });
  }

  /// 持久化今日累计专注秒数
  /// key: focus_seconds_<YYYY-MM-DD>
  /// 顺便检查里程碑（25/50 分钟），首次跨越时一次性轻提示
  Future<void> _persistFocus(int seconds) async {
    if (seconds <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final key = 'focus_seconds_$today';
    final prev = prefs.getInt(key) ?? 0;
    final next = prev + seconds;
    await prefs.setInt(key, next);

    // 里程碑：25 / 50 分钟，今日首次跨越时弹 snackbar
    const milestones = [1500, 3000]; // 秒
    for (final m in milestones) {
      if (prev < m && next >= m) {
        _fireMilestoneToast(m);
      }
    }
  }

  /// 跨越里程碑的轻提示（非阻塞，3 秒消失）
  void _fireMilestoneToast(int seconds) {
    if (Get.context == null) return;
    final min = seconds ~/ 60;
    final isHalfHour = min == 25;
    Get.snackbar(
      isHalfHour ? '🌿 25 分钟，节奏到位' : '⭐ 50 分钟，状态稳了',
      isHalfHour
          ? '要不要顺手到「暖记」记一笔今天的重点？'
          : '深度专注半小时了，记一下卡点或心得，下次复盘更清晰',
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFFFFFBEB),
      colorText: const Color(0xFFB45309),
      margin: EdgeInsets.all(14.w),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      icon: const Icon(Icons.note_alt_outlined,
          color: Color(0xFFB45309)),
      mainButton: TextButton(
        onPressed: () {
          Get.toNamed('/memo');
        },
        child: const Text('去暖记',
            style: TextStyle(
                color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
      ),
    );
  }

  // 暂停计时
  void pauseTimer() {
    final wasRunning = isRunning.value;
    _timer?.cancel();
    isRunning.value = false;
    _lastUpdateTime = null;
    // 把缓冲的秒数 flush 到持久化，避免暂停丢失
    if (_focusBufferSec > 0) {
      _persistFocus(_focusBufferSec);
      _focusBufferSec = 0;
    }
    // 主动暂停 = 一次中断（用作行为系数）；非运行→暂停（按钮已禁用）不算
    if (wasRunning) {
      StrengthEngine.recordInterrupt();
      // 小暖观察：中断了说一句（频次保护交给 ProactiveCompanion）
      _maybeNotifyCompanion('pomodoro_interrupted');
    }
  }

  /// 通过悬浮球冒泡通道，让小暖针对自习室事件主动开口。
  /// ProactiveCompanion 内部按"每事件每日 1 次"+ 全天上限保护频率。
  Future<void> _maybeNotifyCompanion(String eventKey) async {
    final text = await ProactiveCompanion.eventMessage(eventKey);
    if (text == null) return;
    if (Get.isRegistered<AppController>()) {
      Get.find<AppController>().tellCompanion(text);
    }
  }

  // 停止并重置
  void stopTimer() {
    _timer?.cancel();
    isRunning.value = false;
    remainingSeconds.value = focusTotalDuration.value; // 重置为当前设定时长
    _lastUpdateTime = null;
  }

  // 计时完成回调
  void _onTimerComplete() {
    // 弹反馈对话框收集"轻松/一般/有点难"，用于下次系统调整
    _showEndOfStudyFeedback();
    // 小暖观察：完成一段，让悬浮球冒一句
    _maybeNotifyCompanion('pomodoro_done');
  }

  void _showEndOfStudyFeedback() {
    if (Get.context == null) return;
    Get.dialog(
      _EndOfStudyDialog(
        focusedSeconds: focusTotalDuration.value,
        onFeedback: (label) {
          StrengthEngine.recordFeedback(label);
        },
      ),
      barrierDismissible: false,
    );
  }

  // 退出房间（保留计时，生成迷你挂件）
  void exitRoomKeepTimer() {
    hasActiveRoom.value = true; // 告诉主界面显示迷你挂件
  }

  // 彻底关闭房间（停止计时）
  void closeRoom() {
    hasActiveRoom.value = false;
    stopTimer();
    currentRoomName.value = '';
  }

  // 格式化时间显示 MM:SS
  String get timeDisplay {
    final minutes = (remainingSeconds.value ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds.value % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void onClose() {
    _timer?.cancel(); // 控制器销毁时取消定时器
    super.onClose();
  }
}

// ============================================================
// 自习室主页面
// ============================================================
class StudyRoomScreen extends StatelessWidget {
  const StudyRoomScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 自习室外页面 —— 用 lobby 实例（个人番茄钟，与房间内计时器互不影响）
    final controller = Get.find<StudyRoomController>(tag: StudyRoomController.lobbyTag);
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 28.w,
            height: 28.w,
            decoration:
                BoxDecoration(color: primary, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '习',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Text('自习室',
              style:
                  TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
        ]),
        actions: [
          // 创建房间按钮
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showCreateRoomDialog(context, controller),
          ),
        ],
      ),
      // 1:2 布局 —— 计时器占 1/3，房间列表占 2/3
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Obx(() => _buildTimerSection(context, controller)),
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildRoomList(context, controller),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // 暖圈钟计时区域 - 全新美化设计
  // -------------------------------------------------------
  Widget _buildTimerSection(BuildContext context, StudyRoomController ctrl) {
    final primary = Theme.of(context).primaryColor;
    // 1:2 紧凑模式：圆盘直径限制在 78-110，确保标题+chips+圆+按钮全部能塞进 1/3 屏
    final mq = MediaQuery.sizeOf(context);
    final outer = min(110.w, mq.shortestSide * 0.30).clamp(78.0, 110.0);
    final mid = outer * (200.0 / 220.0);
    final inner = outer * (180.0 / 220.0);
    final timeFont = min(26.sp, outer * 0.30);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primary.withOpacity(0.08),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题（紧凑：与圆盘并排在视觉上不抢戏）
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, size: 16.sp, color: primary.withOpacity(0.7)),
              SizedBox(width: 6.w),
              Text(
                '暖圈钟',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: primary.withOpacity(0.8),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),

          // C 类综合判定提示（仅未启动时显示，避免分心）
          if (!ctrl.isRunning.value)
            JudgeHintBar(durationSec: ctrl.focusTotalDuration.value),

          // 时长选择（仅停止时显示）- 胶囊样式 + 自定义
          if (!ctrl.isRunning.value)
            DurationChipBar(ctrl: ctrl, primary: primary),

          SizedBox(height: 8.h),

          // 圆形计时器 - 带环形进度条
          Stack(
            alignment: Alignment.center,
            children: [
              // 持续扩散涟漪：点击开始后向外不断扩散，越接近结束越快
              _DiffusionRing(ctrl: ctrl, color: primary, baseSize: outer),

              // 外圈光晕
              Container(
                width: outer,
                height: outer,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.15),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),

              // 环形进度条背景
              SizedBox(
                width: mid,
                height: mid,
                child: CircularProgressIndicator(
                  value: ctrl.isRunning.value ? ctrl.focusProgress : 0,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    primary.withOpacity(0.3),
                  ),
                ),
              ),

              // 环形进度条前景
              if (ctrl.isRunning.value)
                SizedBox(
                  width: mid,
                  height: mid,
                  child: CircularProgressIndicator(
                    value: ctrl.focusProgress,
                    strokeWidth: 6,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                    strokeCap: StrokeCap.round,
                  ),
                ),

              // 中心内容
              Container(
                width: inner,
                height: inner,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(inner * 0.15),
                  // 整列用 FittedBox 自适应缩放，窄屏不再出现 RenderFlex 溢出黄黑警告条
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 大数字计时显示
                        Text(
                          ctrl.timeDisplay,
                          style: TextStyle(
                            fontSize: timeFont,
                            fontWeight: FontWeight.bold,
                            color: primary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 8.h),

                        // 状态文字
                        Text(
                          ctrl.isRunning.value ? '专注中' : '准备就绪',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        SizedBox(height: 6.h),

                        // 累计时长
                        Text(
                          '累计 ${(ctrl.totalFocusSeconds.value ~/ 60)} 分钟',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 8.h),

          // 控制按钮行 —— 紧凑版（垂直占用 ~46h）
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 重置按钮
              GestureDetector(
                onTap: ctrl.stopTimer,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 14.sp, color: Colors.grey[600]),
                      SizedBox(width: 4.w),
                      Text(
                        '重置',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.w),

              // 开始/暂停按钮 - 主按钮
              GestureDetector(
                onTap: ctrl.isRunning.value ? ctrl.pauseTimer : ctrl.startTimer,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 9.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: ctrl.isRunning.value
                          ? [Colors.orange, Colors.deepOrange]
                          : [primary, primary.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        ctrl.isRunning.value ? Icons.pause : Icons.play_arrow,
                        size: 18.sp,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        ctrl.isRunning.value ? '暂停' : '开始专注',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 注：原"切换页面不会中断计时"提示已移除，1:2 布局空间紧张，
          // 信息已迁移到顶部光带（FocusProgressBar）持续在跑就明示
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // 房间列表
  // -------------------------------------------------------
  Widget _buildRoomList(BuildContext context, StudyRoomController ctrl) {
    // 示例数据，实际从后端 API 拉取
    final rooms = [
      {'name': '考研备战间', 'members': 5, 'isStudying': true},
      {'name': '编程学习室', 'members': 3, 'isStudying': true},
      {'name': '高考冲刺营', 'members': 8, 'isStudying': false},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            '公开自习房间',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              return Card(
                margin: EdgeInsets.only(bottom: 8.h),
                child: ListTile(
                  title: Text(room['name'] as String),
                  subtitle: Text('${room['members']} 人正在自习'),
                  trailing: ElevatedButton(
                    onPressed: () => _joinRoom(context, ctrl, room),
                    child: const Text('加入'),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 显示创建房间弹窗
  void _showCreateRoomDialog(BuildContext context, StudyRoomController ctrl) {
    final nameController = TextEditingController();
    int selectedCapacity = 4; // 默认4人

    Get.dialog(
      StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add_circle_outline, color: Theme.of(context).primaryColor),
              SizedBox(width: 8.w),
              const Text('创建自习房间'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 房间名称
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    hintText: '给你的自习房间起个名字',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                  maxLength: 20,
                ),
                SizedBox(height: 16.h),

                // 房间人数选择（免费全开）
                Text(
                  '房间人数',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [2, 4, 6].map((num) {
                    final isSelected = selectedCapacity == num;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => selectedCapacity = num),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.only(right: 8.w),
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$num人',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: isSelected ? Colors.white : Colors.grey[700],
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 16.h),

              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  // 房间状态写到 room 实例上（与 lobby 实例独立）
                  final roomCtrl = Get.find<StudyRoomController>(tag: StudyRoomController.roomTag);
                  roomCtrl.currentRoomName.value = nameController.text.trim();
                  roomCtrl.hasActiveRoom.value = true;
                  Get.back();
                  Get.toNamed('/room-detail'); // 跳转房间详情页
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  // 加入房间：房间状态写到 room 实例（与 lobby 实例独立，不影响外面计时器）
  void _joinRoom(BuildContext context, StudyRoomController ctrl, Map room) {
    final roomCtrl = Get.find<StudyRoomController>(tag: StudyRoomController.roomTag);
    roomCtrl.currentRoomName.value = room['name'] as String;
    roomCtrl.hasActiveRoom.value = true;
    Get.toNamed('/room-detail');
  }
}

// ============================================================
// 迷你房间挂件（退出房间时浮在其他页面右侧）
// 类似微信语音退出后的小窗
// ============================================================
class RoomMiniWidget extends StatelessWidget {
  const RoomMiniWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 迷你挂件代表的是"已进入但最小化的房间"，因此读 room 实例
    final ctrl = Get.find<StudyRoomController>(tag: StudyRoomController.roomTag);

    return Obx(() {
      // 没有活跃房间时不显示挂件
      if (!ctrl.hasActiveRoom.value) return const SizedBox.shrink();

      return Positioned(
        right: 0,
        top: 200.h, // 距顶部位置
        child: GestureDetector(
          // 点击挂件返回房间
          onTap: () => Get.toNamed('/room-detail'),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8.r),
                bottomLeft: Radius.circular(8.r),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 关闭按钮（彻底退出房间）
                GestureDetector(
                  onTap: () {
                    // 二次确认弹窗（防误触）
                    Get.dialog(AlertDialog(
                      title: const Text('关闭暖圈专注钟'),
                      content: const Text('确定要关闭吗？关闭后本次计时将结束'),
                      actions: [
                        TextButton(
                            onPressed: () => Get.back(),
                            child: const Text('继续专注')),
                        TextButton(
                          onPressed: () {
                            ctrl.closeRoom();
                            Get.back();
                          },
                          child: const Text('关闭', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ));
                  },
                  child: Icon(Icons.close, color: Colors.white, size: 14.sp),
                ),
                SizedBox(height: 4.h),
                Icon(Icons.timer, color: Colors.white, size: 16.sp),
                SizedBox(height: 2.h),
                // 实时显示计时
                Text(
                  ctrl.timeDisplay,
                  style: TextStyle(color: Colors.white, fontSize: 10.sp),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────
// 扩散涟漪组件 —— 计时中持续从计时器中心向外扩散柔光环
// 速度模型：周期 = 3.5s × (1 - 0.75·progress^1.8)
//   progress=0    → 3.5s/周期（慢，悠长）
//   progress=0.5  → ~2.6s/周期
//   progress=0.85 → ~1.4s/周期（明显加速）
//   progress=1.0  → ~0.9s/周期（接近末尾节奏紧迫）
// 多种时长（25/30/45/60 分钟）下视觉节奏一致，因为基于进度比例而非绝对秒
// ─────────────────────────────────────────────────────────────
class _DiffusionRing extends StatefulWidget {
  final StudyRoomController ctrl;
  final Color color;
  final double baseSize;

  const _DiffusionRing({
    required this.ctrl,
    required this.color,
    required this.baseSize,
  });

  @override
  State<_DiffusionRing> createState() => _DiffusionRingState();
}

class _DiffusionRingState extends State<_DiffusionRing>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _phase = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    if (!mounted) return;
    final dt = _last == Duration.zero
        ? 0.0
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    if (widget.ctrl.isRunning.value) {
      final p = widget.ctrl.focusProgress.clamp(0.0, 1.0);
      final speedFactor = 1.0 - 0.75 * pow(p, 1.8);
      final period = 3.5 * speedFactor;
      _phase = (_phase + dt / period) % 1.0;
      setState(() {});
    } else if (_phase != 0) {
      // 暂停后让现存涟漪缓慢消散到一周期边界
      _phase = (_phase + dt * 0.15) % 1.0;
      if (_phase < 0.01) _phase = 0;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvasSize = widget.baseSize * 1.7;
    // 关键：widget 只占 baseSize×baseSize 的布局空间（不撑大父 Stack），
    // 用 OverflowBox 让绘制区域突破到 canvasSize，涟漪可以扩散到圆盘之外
    return Obx(() => SizedBox(
          width: widget.baseSize,
          height: widget.baseSize,
          child: OverflowBox(
            minWidth: 0,
            minHeight: 0,
            maxWidth: canvasSize,
            maxHeight: canvasSize,
            child: SizedBox(
              width: canvasSize,
              height: canvasSize,
              child: CustomPaint(
                painter: _DiffusionPainter(
                  phase: _phase,
                  innerR: widget.baseSize / 2,
                  maxR: canvasSize / 2,
                  active: widget.ctrl.isRunning.value,
                  color: widget.color,
                ),
              ),
            ),
          ),
        ));
  }
}

class _DiffusionPainter extends CustomPainter {
  final double phase;
  final double innerR;
  final double maxR;
  final bool active;
  final Color color;

  _DiffusionPainter({
    required this.phase,
    required this.innerR,
    required this.maxR,
    required this.active,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    if (!active && phase == 0) return;
    const ringCount = 3;
    for (int i = 0; i < ringCount; i++) {
      final p = ((phase + i / ringCount) % 1.0);
      final r = innerR + (maxR - innerR) * p;
      // 透明度从 0.30 渐隐到 0
      final alpha = ((1.0 - p) * 0.30).clamp(0.0, 1.0);
      if (alpha < 0.01) continue;
      final stroke = (4.0 - p * 2.5).clamp(0.6, 6.0);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = color.withOpacity(alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  @override
  bool shouldRepaint(_DiffusionPainter old) =>
      old.phase != phase ||
      old.active != active ||
      old.innerR != innerR ||
      old.maxR != maxR;
}

// ─────────────────────────────────────────────────────────────
// 学习结束反馈弹窗（核心闭环最后一步：用户反馈用于下次调整）
// 选项：轻松 / 一般 / 有点难，写到 StrengthEngine.recordFeedback
// ─────────────────────────────────────────────────────────────
class _EndOfStudyDialog extends StatelessWidget {
  final int focusedSeconds;
  final void Function(String label) onFeedback;
  const _EndOfStudyDialog({
    required this.focusedSeconds,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final mins = (focusedSeconds / 60).round();
    final options = const [
      {'label': '轻松', 'icon': Icons.sentiment_satisfied, 'tint': Color(0xFF6CB87C)},
      {'label': '一般', 'icon': Icons.sentiment_neutral, 'tint': Color(0xFF9CA3AF)},
      {'label': '有点难', 'icon': Icons.sentiment_dissatisfied, 'tint': Color(0xFFE08A6E)},
    ];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 14.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration_outlined,
                size: 32.sp, color: const Color(0xFFE08A6E)),
            SizedBox(height: 10.h),
            Text(
              '今天完成 $mins 分钟，很棒',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              '感觉怎么样？告诉我一下，下次我会更懂你',
              style: TextStyle(
                  fontSize: 12.sp, color: Colors.grey[600], height: 1.5),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 18.h),
            Row(
              children: options.map((o) {
                final tint = o['tint'] as Color;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: GestureDetector(
                      onTap: () {
                        onFeedback(o['label'] as String);
                        Get.back();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        decoration: BoxDecoration(
                          color: tint.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: tint.withOpacity(0.40)),
                        ),
                        child: Column(
                          children: [
                            Icon(o['icon'] as IconData,
                                size: 24.sp, color: tint),
                            SizedBox(height: 4.h),
                            Text(
                              o['label'] as String,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: tint,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 12.h),
            TextButton(
              onPressed: () => Get.back(),
              child: Text('暂时跳过',
                  style: TextStyle(
                      fontSize: 12.sp, color: Colors.grey[500])),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 时长选择条：25 / 30 / 45 / 60 + 自定义
// lobby 和 room 都用同一个组件，避免重复
// ─────────────────────────────────────────────────────────────
class DurationChipBar extends StatelessWidget {
  final StudyRoomController ctrl;
  final Color primary;
  const DurationChipBar({Key? key, required this.ctrl, required this.primary})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    const presets = [25, 30, 45, 60];
    final currentMin = ctrl.focusTotalDuration.value ~/ 60;
    final isCustom = !presets.contains(currentMin);
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...presets.map((min) {
            final isSelected = currentMin == min && !isCustom;
            return _chip(
              label: '$min分',
              selected: isSelected,
              onTap: () => ctrl.setDuration(min * 60),
            );
          }),
          // 自定义 chip：若当前不是预设值，显示当前分钟数；否则显示"自定义"
          _chip(
            label: isCustom ? '$currentMin 分' : '自定义',
            selected: isCustom,
            onTap: () => showDurationPickerDialog(context, ctrl),
          ),
        ],
      ),
    );
  }

  Widget _chip({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.symmetric(horizontal: 2.w),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: selected ? Colors.white : Colors.grey[600],
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// 自定义专注时长 dialog（lobby + room 共用）
Future<void> showDurationPickerDialog(BuildContext context, StudyRoomController ctrl) async {
  final tc = TextEditingController(
    text: (ctrl.focusTotalDuration.value ~/ 60).toString(),
  );
  await Get.dialog(
    AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
      title: Text('自定义专注时长', style: TextStyle(fontSize: 15.sp)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '输入分钟数（1 - 180）',
            style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: tc,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              suffixText: '分钟',
              hintText: '例如 90',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            style: TextStyle(fontSize: 14.sp),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final n = int.tryParse(tc.text.trim());
            if (n == null || n <= 0) return;
            ctrl.setDuration(n.clamp(1, 180) * 60);
            Get.back();
          },
          child: const Text('确定'),
        ),
      ],
    ),
    barrierDismissible: true,
  );
}
