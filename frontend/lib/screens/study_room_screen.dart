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

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'dart:async'; // 定时器

// ============================================================
// 自习室专属控制器（GetX控制器，跨页面保活）
// 为什么用控制器而不是 State？
// 因为 State 随页面销毁会消失，而 GetX 控制器注入后全局存活
// 切换到其他 Tab 计时不会中断
// ============================================================
class StudyRoomController extends GetxController {
  // 是否正在计时
  final RxBool isRunning = false.obs;

  // 本次专注设定总时长（秒），默认25分钟
  final RxInt focusTotalDuration = 1500.obs;

  // 剩余秒数
  final RxInt remainingSeconds = 1500.obs;

  // 累计专注秒数（跨多轮）
  final RxInt totalFocusSeconds = 0.obs;

  // 全局光影条进度 0.0~1.0
  double get focusProgress {
    final total = focusTotalDuration.value;
    if (total <= 0) return 0.0;
    return (1.0 - remainingSeconds.value / total).clamp(0.0, 1.0);
  }

  // 是否应显示全局光影条
  bool get showFocusBar =>
      isRunning.value ||
      (remainingSeconds.value < focusTotalDuration.value && remainingSeconds.value > 0);

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

  // 开始计时
  void startTimer() {
    if (isRunning.value) return; // 已经在计时了，不重复启动
    isRunning.value = true;
    // 每秒执行一次
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds.value > 0) {
        remainingSeconds.value--;
        totalFocusSeconds.value++;
      } else {
        // 计时结束
        stopTimer();
        _onTimerComplete();
      }
    });
  }

  // 暂停计时
  void pauseTimer() {
    _timer?.cancel();
    isRunning.value = false;
  }

  // 停止并重置
  void stopTimer() {
    _timer?.cancel();
    isRunning.value = false;
    remainingSeconds.value = focusTotalDuration.value; // 重置为当前设定时长
  }

  // 计时完成回调
  void _onTimerComplete() {
    // TODO: 发送通知、播放提示音、记录完成经验
    Get.snackbar('专注完成！', '暖圈钟响了，休息一下吧～',
        backgroundColor: Colors.green.withOpacity(0.9),
        colorText: Colors.white);
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
    // 把控制器注册到全局（永久存活，不随页面销毁）
    // permanent: true = 不自动销毁
    final controller = Get.put(StudyRoomController(), permanent: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('自习室'),
        actions: [
          // 创建房间按钮
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showCreateRoomDialog(context, controller),
          ),
        ],
      ),
      body: Column(
        children: [
          // ===================================================
          // 暖圈钟（番茄钟核心区域）
          // ===================================================
          Obx(() => _buildTimerSection(context, controller)),

          SizedBox(height: 20.h),

          // ===================================================
          // 房间列表（示例，实际从后端拉取）
          // ===================================================
          Expanded(
            child: _buildRoomList(context, controller),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // 暖圈钟计时区域
  // -------------------------------------------------------
  Widget _buildTimerSection(BuildContext context, StudyRoomController ctrl) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      color: Colors.white,
      child: Column(
        children: [
          Text(
            '暖圈钟',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
          ),
          SizedBox(height: 10.h),

          // 时长选择（仅停止时显示）
          if (!ctrl.isRunning.value)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [25, 30, 45, 60].map((min) {
                final primary = Theme.of(context).primaryColor;
                final isSelected = ctrl.focusTotalDuration.value == min * 60;
                return GestureDetector(
                  onTap: () => ctrl.setDuration(min * 60),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: isSelected ? primary.withOpacity(0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: isSelected ? primary : Colors.grey.shade300,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      '$min分',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isSelected ? primary : Colors.grey[600],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

          SizedBox(height: 12.h),

          // 大数字计时显示
          Text(
            ctrl.timeDisplay,
            style: TextStyle(
              fontSize: 56.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
              fontFeatures: const [FontFeature.tabularFigures()], // 等宽数字，不跳动
            ),
          ),

          SizedBox(height: 8.h),
          Text(
            '专注总时长：${(ctrl.totalFocusSeconds.value ~/ 60)} 分钟',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
          ),

          SizedBox(height: 20.h),

          // 控制按钮行
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 重置按钮
              OutlinedButton.icon(
                onPressed: ctrl.stopTimer,
                icon: const Icon(Icons.refresh),
                label: const Text('重置'),
              ),
              SizedBox(width: 16.w),
              // 开始/暂停按钮
              ElevatedButton.icon(
                onPressed: ctrl.isRunning.value
                    ? ctrl.pauseTimer
                    : ctrl.startTimer,
                icon: Icon(ctrl.isRunning.value ? Icons.pause : Icons.play_arrow),
                label: Text(ctrl.isRunning.value ? '暂停' : '开始专注'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                ),
              ),
            ],
          ),

          // 正在计时时显示提示
          if (ctrl.isRunning.value) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                '⏱ 正在专注中，切换页面不会中断计时',
                style: TextStyle(fontSize: 11.sp, color: Colors.green[700]),
              ),
            ),
          ],
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
      {'name': '📖 考研备战间', 'members': 5, 'isStudying': true},
      {'name': '💻 编程学习室', 'members': 3, 'isStudying': true},
      {'name': '✏️ 高考冲刺营', 'members': 8, 'isStudying': false},
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
    Get.dialog(
      AlertDialog(
        title: const Text('创建自习房间'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: '给你的自习房间起个名字',
            prefixIcon: Icon(Icons.meeting_room_outlined),
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                ctrl.currentRoomName.value = nameController.text.trim();
                ctrl.hasActiveRoom.value = true;
                Get.back();
                Get.toNamed('/room-detail'); // 跳转房间详情页
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  // 加入房间
  void _joinRoom(BuildContext context, StudyRoomController ctrl, Map room) {
    ctrl.currentRoomName.value = room['name'] as String;
    ctrl.hasActiveRoom.value = true;
    Get.toNamed('/room-detail'); // 跳转房间页面
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
    final ctrl = Get.find<StudyRoomController>();

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
