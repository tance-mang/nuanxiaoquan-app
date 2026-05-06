import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'dart:ui';
import 'study_room_screen.dart';

class RoomDetailScreen extends StatelessWidget {
  const RoomDetailScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<StudyRoomController>();
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4FF),
      body: Stack(
        children: [
          // 柔光背景粒子效果
          _buildBgDecor(primary),

          SafeArea(
            child: Column(
              children: [
                // 顶栏
                _buildTopBar(context, ctrl, primary),

                SizedBox(height: 24.h),

                // 大时钟
                Obx(() => _buildClock(context, ctrl, primary)),

                SizedBox(height: 32.h),

                // 控制按钮
                Obx(() => _buildControls(ctrl, primary)),

                SizedBox(height: 32.h),

                // 房间成员占位
                _buildMembersArea(primary),

                const Spacer(),

                // 底部提示
                Padding(
                  padding: EdgeInsets.only(bottom: 32.h),
                  child: Text(
                    '全程静默 · 专注自习 · 无打扰',
                    style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[400],
                        letterSpacing: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBgDecor(Color primary) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200.w,
              height: 200.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: Container(
              width: 160.w,
              height: 160.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withOpacity(0.06),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, StudyRoomController ctrl, Color primary) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              ctrl.exitRoomKeepTimer();
              Get.back();
            },
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.r),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 16),
            ),
          ),
          SizedBox(width: 16.w),
          Obx(() => Text(
                ctrl.currentRoomName.value,
                style:
                    TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              )),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Get.dialog(AlertDialog(
                title: const Text('离开房间'),
                content: const Text('确定退出并结束本次专注吗？'),
                actions: [
                  TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('继续专注')),
                  TextButton(
                    onPressed: () {
                      ctrl.closeRoom();
                      Get.back();
                      Get.back();
                    },
                    child: const Text('退出', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ));
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text('离开',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClock(BuildContext context, StudyRoomController ctrl, Color primary) {
    return Container(
      width: 200.w,
      height: 200.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            ctrl.timeDisplay,
            style: TextStyle(
              fontSize: 44.sp,
              fontWeight: FontWeight.bold,
              color: primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            ctrl.isRunning.value ? '专注中…' : '暂停',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
          ),
          SizedBox(height: 8.h),
          Text(
            '累计 ${(ctrl.totalFocusSeconds.value ~/ 60)} 分钟',
            style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(StudyRoomController ctrl, Color primary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _controlBtn(
          icon: Icons.refresh,
          label: '重置',
          onTap: ctrl.stopTimer,
          bgColor: Colors.grey.shade100,
          fgColor: Colors.grey[600]!,
        ),
        SizedBox(width: 20.w),
        _controlBtn(
          icon: ctrl.isRunning.value ? Icons.pause_rounded : Icons.play_arrow_rounded,
          label: ctrl.isRunning.value ? '暂停' : '开始',
          onTap: ctrl.isRunning.value ? ctrl.pauseTimer : ctrl.startTimer,
          bgColor: primary,
          fgColor: Colors.white,
          large: true,
        ),
      ],
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color bgColor,
    required Color fgColor,
    bool large = false,
  }) {
    final size = large ? 64.w : 52.w;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              boxShadow: large
                  ? [
                      BoxShadow(
                          color: bgColor.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]
                  : [],
            ),
            child: Icon(icon, color: fgColor, size: large ? 30.sp : 22.sp),
          ),
          SizedBox(height: 6.h),
          Text(label,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildMembersArea(Color primary) {
    // 模拟在线成员头像（实际对接后端）
    final members = ['考', '编', '高', '你'];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.white.withOpacity(0.7)),
            ),
            child: Row(
              children: [
                ...members.map((m) => Container(
                      margin: EdgeInsets.only(right: 8.w),
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(m,
                            style: TextStyle(
                                fontSize: 12.sp,
                                color: primary,
                                fontWeight: FontWeight.bold)),
                      ),
                    )),
                const Spacer(),
                Text(
                  '${members.length} 人自习中',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
