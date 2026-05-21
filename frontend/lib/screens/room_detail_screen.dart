import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'dart:math';
import 'study_room_screen.dart';
import '../widgets/judge_hint_bar.dart';
import '../services/behavior_tracker.dart';

class RoomDetailScreen extends StatefulWidget {
  const RoomDetailScreen({Key? key}) : super(key: key);

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  @override
  void initState() {
    super.initState();
    // 标记进入房间详情，让行为感知服务识别为"自习 surface"
    try {
      Get.find<BehaviorTracker>().setInRoom(true);
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      Get.find<BehaviorTracker>().setInRoom(false);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 房间内页 —— 用 room 实例（与外面 lobby 计时器互不同步）
    final ctrl = Get.find<StudyRoomController>(tag: StudyRoomController.roomTag);
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4FF),
      body: Stack(
        children: [
          // 元气星球粒子背景
          _buildPlanetParticles(primary),

          // 进度填充式夕阳：随计时进度自上而下铺满，并按进度加速的柔光呼吸
          const _AnimatedSunset(),

          SafeArea(
            child: Column(
              children: [
                // 顶栏
                _buildTopBar(context, ctrl, primary),

                SizedBox(height: 8.h),

                // C 类综合判定提示（仅未启动时显示）
                Obx(() => ctrl.isRunning.value
                    ? const SizedBox.shrink()
                    : JudgeHintBar(
                        durationSec: ctrl.focusTotalDuration.value,
                      )),

                SizedBox(height: 8.h),

                // 时长选择 + 自定义（仅未启动时显示）
                Obx(() => ctrl.isRunning.value
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child:
                            DurationChipBar(ctrl: ctrl, primary: primary),
                      )),

                // 大时钟
                Obx(() => _buildClock(context, ctrl, primary)),

                SizedBox(height: 20.h),

                // 控制按钮
                Obx(() => _buildControls(ctrl, primary)),

                SizedBox(height: 12.h),

                // 元气星球成员区域（Expanded 让其自适应，但内部 planet 缩小到 220w 防溢出）
                Expanded(
                  child: _buildPlanetMembers(primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 元气星球粒子背景 ────────────────────────────────────────
  Widget _buildPlanetParticles(Color primary) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _PlanetParticlePainter(primary: primary),
      ),
    );
  }

  // ── 夕阳天幕（顶部暖色渐变，覆盖顶部~45%，柔和不抢戏）────────
  // 暖橘 → 桃霞 → 奶米 → 透明，没有圆盘没有云朵，纯氛围
  Widget _buildSunsetSky() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 360.h,
      child: IgnorePointer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFB17A), // 暮橘
                Color(0xFFFFC8A8), // 桃霞
                Color(0xFFFADBC4), // 奶米
                Color(0x00FADBC4), // 渐隐到透明
              ],
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
          ),
        ),
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
          onTap: ctrl.isRunning.value
              ? ctrl.pauseTimer
              : () {
                  // 进入房间并启动专注 → 外面 lobby 计时器自动暂停（不冲突）
                  Get.find<StudyRoomController>(tag: StudyRoomController.lobbyTag).pauseTimer();
                  ctrl.startTimer();
                },
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

  // ── 元气星球成员区域（核心视觉）──────────────────────────────
  Widget _buildPlanetMembers(Color primary) {
    // 模拟在线成员（实际对接后端）
    final members = [
      {'name': '考', 'isOnline': true, 'isFocusing': true},
      {'name': '编', 'isOnline': true, 'isFocusing': true},
      {'name': '高', 'isOnline': true, 'isFocusing': false},
      {'name': '你', 'isOnline': true, 'isFocusing': true},
    ];

    // planet 整体缩到 220w，轨道半径 70w，避免在小屏占满 Expanded 后被切掉
    const double planetSize = 220.0;
    const double orbitR = 70.0;
    const double orbBase = 40.0; // 球体直径 (单位 w)，与 _AnimatedOrb 内部 width 一致
    return Center(
      child: SizedBox(
        width: planetSize.w,
        height: planetSize.w,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none, // 允许漂动到框外，不被切
          children: [
            // 星球底盘光晕
            Container(
              width: planetSize.w,
              height: planetSize.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primary.withOpacity(0.08),
                    primary.withOpacity(0.02),
                    Colors.transparent,
                  ],
                  stops: const [0.3, 0.6, 1.0],
                ),
              ),
            ),

            // 成员光点（悬浮在星球上）
            ...members.asMap().entries.map((entry) {
              final index = entry.key;
              final member = entry.value;
              final angle = (index / members.length) * 2 * pi;
              final x = cos(angle) * orbitR;
              final y = sin(angle) * orbitR;

              return Positioned(
                left: (planetSize / 2).w + x.w - (orbBase / 2).w,
                top: (planetSize / 2).w + y.w - (orbBase / 2).w,
                child: _AnimatedOrb(
                  name: member['name'] as String,
                  isOnline: member['isOnline'] as bool,
                  isFocusing: member['isFocusing'] as bool,
                  primary: primary,
                  index: index,
                ),
              );
            }).toList(),

            // （已删除：中心静止装饰圆点—无功能且会让画面有"卡住"的视觉）
          ],
        ),
      ),
    );
  }

  // ── 成员光点小球 ────────────────────────────────────────────
  Widget _buildMemberOrb({
    required String name,
    required bool isOnline,
    required bool isFocusing,
    required Color primary,
  }) {
    final opacity = isOnline ? 1.0 : 0.4;
    final glowColor = isFocusing
        ? primary.withOpacity(0.4 * opacity)
        : Colors.grey.withOpacity(0.2 * opacity);

    return Container(
      width: 40.w,
      height: 40.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFocusing
            ? primary.withOpacity(0.25 * opacity)
            : Colors.grey.withOpacity(0.15 * opacity),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: isFocusing ? 15 : 8,
            spreadRadius: isFocusing ? 3 : 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          name,
          style: TextStyle(
            fontSize: 14.sp,
            color: isFocusing ? primary : Colors.grey[400],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ── 底部会员入口 ────────────────────────────────────────────
  Widget _buildMembershipEntry(Color primary) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: GestureDetector(
        onTap: () {
          Get.dialog(
            AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.diamond, color: primary, size: 24.sp),
                  SizedBox(width: 8.w),
                  Text('会员权益', style: TextStyle(fontSize: 18.sp)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _membershipItem('🔒 私密锁房功能'),
                  _membershipItem('✨ 专属粒子特效'),
                  _membershipItem('👥 更大房间人数（8人/12人）'),
                  SizedBox(height: 12.h),
                  Text(
                    '功能暂未开放，后续版本上线',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('知道了'),
                ),
              ],
            ),
          );
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          margin: EdgeInsets.symmetric(horizontal: 24.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primary.withOpacity(0.1),
                primary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: primary.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.diamond_outlined, color: primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                '开通会员解锁更多权益',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _membershipItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 18.sp, color: Colors.green),
          SizedBox(width: 8.w),
          Text(text, style: TextStyle(fontSize: 14.sp)),
        ],
      ),
    );
  }
}

// ── 星球粒子绘制器 ────────────────────────────────────────────
class _PlanetParticlePainter extends CustomPainter {
  final Color primary;
  final _random = Random();

  _PlanetParticlePainter({required this.primary});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // 绘制漂浮的小粒子（营造氛围）
    for (int i = 0; i < 20; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      final radius = _random.nextDouble() * 2 + 1;
      final opacity = _random.nextDouble() * 0.3 + 0.1;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = primary.withOpacity(opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(_PlanetParticlePainter old) => false;
}

// ─────────────────────────────────────────────────────────────
// 进度填充式夕阳 —— 高度随计时进度增长（"一点点铺满"），
// 同时柔光呼吸；接近结束时呼吸周期明显变快（^1.8 加速曲线）。
// 不依赖 AnimationController，用 Ticker 自管时间，便于动态调速。
// ─────────────────────────────────────────────────────────────
class _AnimatedSunset extends StatefulWidget {
  const _AnimatedSunset();

  @override
  State<_AnimatedSunset> createState() => _AnimatedSunsetState();
}

class _AnimatedSunsetState extends State<_AnimatedSunset>
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
    final ctrl = Get.find<StudyRoomController>(tag: StudyRoomController.roomTag);
    final p = ctrl.focusProgress.clamp(0.0, 1.0);
    // 越接近结束，呼吸周期越短（视觉上明显加速）
    final speedFactor = 1.0 - 0.75 * pow(p, 1.8);
    final period = ctrl.isRunning.value ? 3.5 * speedFactor : 6.0;
    _phase = (_phase + dt / period) % 1.0;
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<StudyRoomController>(tag: StudyRoomController.roomTag);
    return Obx(() {
      // 关键：未启动计时器时完全不渲染夕阳（用户期望）
      if (!ctrl.isRunning.value) return const SizedBox.shrink();
      final p = ctrl.focusProgress.clamp(0.0, 1.0);
      // 启动即可见的基线 60h，随进度铺到 ~480h
      final h = 60.h + 420.h * p;
      // 呼吸亮度（频率随进度加速，结尾节奏紧迫）
      final breath = 0.89 + 0.11 * sin(_phase * 2 * pi);
      // 启动后约 3 秒（25分钟焦点会话的 0.2%）淡入到满，避免突然 pop
      final fadeIn = (p / 0.002).clamp(0.0, 1.0);
      Color top = Color.fromRGBO(0xFF, 0xB1, 0x7A, 0.92 * breath * fadeIn);
      Color mid = Color.fromRGBO(0xFF, 0xC8, 0xA8, 0.62 * breath * fadeIn);
      Color low = Color.fromRGBO(0xFA, 0xDB, 0xC4, 0.30 * breath * fadeIn);
      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: h,
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [top, mid, low, const Color(0x00FADBC4)],
                stops: const [0.0, 0.4, 0.75, 1.0],
              ),
            ),
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────
// 房间成员小球：轻浮 + 光晕脉冲，每个球错相，整体星球感而非僵硬列表
// ─────────────────────────────────────────────────────────────
class _AnimatedOrb extends StatefulWidget {
  final String name;
  final bool isOnline;
  final bool isFocusing;
  final Color primary;
  final int index;

  const _AnimatedOrb({
    required this.name,
    required this.isOnline,
    required this.isFocusing,
    required this.primary,
    required this.index,
  });

  @override
  State<_AnimatedOrb> createState() => _AnimatedOrbState();
}

class _AnimatedOrbState extends State<_AnimatedOrb>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _t = 0;

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
    _t += dt;
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 大幅 Lissajous 飘动：横轴 ±18w，纵轴 ±14w，每个球错相 1.7 弧度
    final phase = _t * 0.7 + widget.index * 1.7;
    final driftX = sin(phase * 0.85) * 18.w;
    final driftY = sin(phase * 1.15 + widget.index * 0.5) * 14.w;
    final pulse = 0.7 + 0.3 * sin(phase * 1.3);
    final opacity = widget.isOnline ? 1.0 : 0.4;
    final glowColor = widget.isFocusing
        ? widget.primary.withOpacity(0.4 * opacity * pulse)
        : Colors.grey.withOpacity(0.2 * opacity);
    return Transform.translate(
      offset: Offset(driftX, driftY),
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isFocusing
              ? widget.primary.withOpacity(0.25 * opacity)
              : Colors.grey.withOpacity(0.15 * opacity),
          boxShadow: [
            BoxShadow(
              color: glowColor,
              blurRadius: widget.isFocusing ? 18 * pulse : 8,
              spreadRadius: widget.isFocusing ? 3.5 * pulse : 1,
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.name,
            style: TextStyle(
              fontSize: 14.sp,
              color: widget.isFocusing ? widget.primary : Colors.grey[400],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
