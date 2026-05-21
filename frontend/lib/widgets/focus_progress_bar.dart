import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screens/study_room_screen.dart';

/// 全局顶角流光组件
/// - 未计时：顶部左右角极淡圆弧暗纹，精致收边
/// - 计时中：流光从两侧角向中间汇聚，进度联动，暖柔微光
class FocusProgressBar extends StatefulWidget {
  const FocusProgressBar({Key? key}) : super(key: key);

  @override
  State<FocusProgressBar> createState() => _FocusProgressBarState();
}

class _FocusProgressBarState extends State<FocusProgressBar>
    with TickerProviderStateMixin {
  late AnimationController _shimmerCtrl;

  // 流动动画控制器（控制流光从角到中间的流动过程）
  late AnimationController _flowCtrl;
  late Animation<double> _flowAnim;

  /// 监听计时状态，禁止在 [build] 里改 AnimationController（会触发级联错误 / Web 红屏）
  Worker? _runningWorker;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _flowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _flowAnim = CurvedAnimation(
      parent: _flowCtrl,
      curve: Curves.easeOutCubic,
    );

    // 顶部全局光带跟随 lobby 实例（外页个人专注），房间内自有时钟与之独立
    final ctrl = Get.find<StudyRoomController>(tag: StudyRoomController.lobbyTag);
    _runningWorker = ever<bool>(ctrl.isRunning, (running) {
      if (!mounted) return;
      if (running) {
        if (_flowCtrl.status != AnimationStatus.forward) {
          _flowCtrl.forward(from: 0);
        }
      } else {
        if (_flowCtrl.status != AnimationStatus.reverse) {
          _flowCtrl.reverse();
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Get.find<StudyRoomController>(tag: StudyRoomController.lobbyTag).isRunning.value) {
        if (_flowCtrl.status != AnimationStatus.forward) {
          _flowCtrl.forward(from: 0);
        }
      }
    });
  }

  @override
  void dispose() {
    _runningWorker?.dispose();
    _shimmerCtrl.dispose();
    _flowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<StudyRoomController>(tag: StudyRoomController.lobbyTag);
    // 使用更暖的色调
    final baseColor = Theme.of(context).primaryColor;
    final warmColor = Color.lerp(baseColor, const Color(0xFFFF9A76), 0.3) ?? baseColor;
    final screenW = MediaQuery.of(context).size.width;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Obx(() {
        final isActive = ctrl.isRunning.value;
        final progress = ctrl.focusProgress;

        // 始终显示（无论是否计时）
        return AnimatedBuilder(
          animation: Listenable.merge([_shimmerCtrl, _flowAnim]),
          builder: (ctx, _) => CustomPaint(
            size: Size(screenW, 36),
            painter: _CornerGlowPainter(
              progress: progress,
              isActive: isActive,
              color: warmColor,
              shimmerT: _shimmerCtrl.value,
              flowT: _flowAnim.value,
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter：顶角流光绘制
// ─────────────────────────────────────────────────────────────────────────────
class _CornerGlowPainter extends CustomPainter {
  final double progress;  // 0.0 ~ 1.0
  final bool isActive;
  final Color color;
  final double shimmerT;  // 0.0 ~ 1.0, 流光脉冲节奏
  final double flowT;     // 0.0 ~ 1.0, 流动过程

  const _CornerGlowPainter({
    required this.progress,
    required this.isActive,
    required this.color,
    required this.shimmerT,
    required this.flowT,
  });

  static const double _arcR = 24.0;   // 顶角圆弧半径（稍大一点）
  static const double _dropH = 14.0;  // 弧线在侧边向下延伸的高度

  /// 构建路径：角弧 + 沿顶边延伸的直线
  Path _buildPath(double w, double prog, bool isLeft) {
    final halfW = w / 2;
    // 直线段：从圆弧末端到进度位置
    final straightLen = (halfW - _arcR) * prog.clamp(0.0, 1.0);
    final path = Path();

    if (isLeft) {
      // 更柔和的贝塞尔曲线
      path.moveTo(0, _dropH);
      path.cubicTo(0, _dropH * 0.3, _arcR * 0.4, 0, _arcR, 0);
      if (straightLen > 0) path.lineTo(_arcR + straightLen, 0);
    } else {
      path.moveTo(w, _dropH);
      path.cubicTo(w, _dropH * 0.3, w - _arcR * 0.4, 0, w - _arcR, 0);
      if (straightLen > 0) path.lineTo(w - _arcR - straightLen, 0);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;

    if (!isActive) {
      // ── 未计时：极淡静态角弧，精致收边 ─────────────────────
      for (final left in [true, false]) {
        final path = _buildPath(w, 0, left);
        // 两层淡弧，更有质感
        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withOpacity(0.08)
          ..strokeCap = StrokeCap.round);

        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = color.withOpacity(0.15)
          ..strokeCap = StrokeCap.round);
      }
      return;
    }

    // ── 计时中：流光从两角向中间汇聚 ───────────────────────────
    // 流动效果：progress 是目标位置，flowT 控制从 0 到 progress 的过程
    final animatedProgress = progress * flowT;

    for (final isLeft in [true, false]) {
      _paintGlowArc(canvas, w, isLeft, animatedProgress);
    }
  }

  void _paintGlowArc(Canvas canvas, double w, bool isLeft, double animProgress) {
    final path = _buildPath(w, animProgress, isLeft);

    // 层 1：最宽柔光晕（远距散射）- 更柔和
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..color = color.withOpacity(0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..strokeCap = StrokeCap.round);

    // 层 2：中光晕
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = color.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..strokeCap = StrokeCap.round);

    // 层 3：核心光线（渐变：角处淡 → 前端亮）
    final halfW = w / 2;
    final endX = isLeft
        ? _arcR + (halfW - _arcR) * animProgress
        : w - _arcR - (halfW - _arcR) * animProgress;
    final startX = isLeft ? 0.0 : w;

    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0.20),
          color.withOpacity(0.65),
        ],
        begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
      ).createShader(Rect.fromPoints(
        Offset(startX, 0),
        Offset(endX, 0),
      )));

    // 流光头部：脉冲亮斑（更精致的三层光点）
    if (animProgress > 0.02) {
      final pulse = 0.50 + 0.50 * sin(shimmerT * 2 * pi);

      // 外柔晕（最大最淡）
      canvas.drawCircle(
        Offset(endX, 0),
        8,
        Paint()
          ..color = color.withOpacity(0.08 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );

      // 中光点
      canvas.drawCircle(
        Offset(endX, 0),
        4,
        Paint()
          ..color = color.withOpacity(0.25 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );

      // 亮核（最小最亮）
      canvas.drawCircle(
        Offset(endX, 0),
        1.8,
        Paint()..color = color.withOpacity(0.75 * pulse),
      );
    }
  }

  @override
  bool shouldRepaint(_CornerGlowPainter old) {
    return old.progress != progress ||
        old.isActive != isActive ||
        old.shimmerT != shimmerT ||
        old.flowT != flowT;
  }
}
