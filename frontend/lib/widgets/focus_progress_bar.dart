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
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<StudyRoomController>();
    final color = Theme.of(context).primaryColor;
    final screenW = MediaQuery.of(context).size.width;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Obx(() {
        final isActive = ctrl.showFocusBar;
        final progress = ctrl.focusProgress;

        if (!isActive) {
          // 静态淡角弧，无动画
          return CustomPaint(
            size: Size(screenW, 32),
            painter: _CornerGlowPainter(
              progress: 0,
              isActive: false,
              color: color,
              shimmerT: 0,
            ),
          );
        }

        // 计时中：带流光动画
        return AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (ctx, _) => CustomPaint(
            size: Size(screenW, 32),
            painter: _CornerGlowPainter(
              progress: progress,
              isActive: true,
              color: color,
              shimmerT: _shimmerCtrl.value,
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

  const _CornerGlowPainter({
    required this.progress,
    required this.isActive,
    required this.color,
    required this.shimmerT,
  });

  static const double _arcR = 22.0;   // 顶角圆弧半径
  static const double _dropH = 12.0;  // 弧线在侧边向下延伸的高度

  /// 构建路径：角弧 + 沿顶边延伸的直线
  Path _buildPath(double w, double prog, bool isLeft) {
    final halfW = w / 2;
    // 直线段：从圆弧末端到进度位置
    final straightLen = (halfW - _arcR) * prog.clamp(0.0, 1.0);
    final path = Path();

    if (isLeft) {
      path.moveTo(0, _dropH);
      path.quadraticBezierTo(0, 0, _arcR, 0);
      if (straightLen > 0) path.lineTo(_arcR + straightLen, 0);
    } else {
      path.moveTo(w, _dropH);
      path.quadraticBezierTo(w, 0, w - _arcR, 0);
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
        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withOpacity(0.10)
          ..strokeCap = StrokeCap.round);
      }
      return;
    }

    // ── 计时中：流光从两角向中间汇聚 ───────────────────────────
    for (final isLeft in [true, false]) {
      _paintGlowArc(canvas, w, isLeft);
    }
  }

  void _paintGlowArc(Canvas canvas, double w, bool isLeft) {
    final path = _buildPath(w, progress, isLeft);

    // 层 1：最宽柔光晕（远距散射）
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..color = color.withOpacity(0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9)
      ..strokeCap = StrokeCap.round);

    // 层 2：中光晕
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = color.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
      ..strokeCap = StrokeCap.round);

    // 层 3：核心光线（渐变：角处淡 → 前端亮）
    final halfW = w / 2;
    final endX = isLeft
        ? _arcR + (halfW - _arcR) * progress
        : w - _arcR - (halfW - _arcR) * progress;
    final startX = isLeft ? 0.0 : w;

    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          color.withOpacity(0.25),
          color.withOpacity(0.70),
        ],
        begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
      ).createShader(Rect.fromPoints(
        Offset(startX, 0),
        Offset(endX, 0),
      )));

    // 流光头部：脉冲亮斑
    if (progress > 0.02) {
      final pulse = 0.55 + 0.45 * sin(shimmerT * 2 * pi);
      // 外柔晕
      canvas.drawCircle(
        Offset(endX, 0),
        7,
        Paint()
          ..color = color.withOpacity(0.10 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // 中光点
      canvas.drawCircle(
        Offset(endX, 0),
        3.5,
        Paint()
          ..color = color.withOpacity(0.30 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      // 亮核
      canvas.drawCircle(
        Offset(endX, 0),
        1.5,
        Paint()..color = color.withOpacity(0.80 * pulse),
      );
    }
  }

  @override
  bool shouldRepaint(_CornerGlowPainter old) {
    // 未激活时两者都静止，跳过重绘
    if (!isActive && !old.isActive) return false;
    return old.progress != progress ||
        old.isActive != isActive ||
        old.shimmerT != shimmerT;
  }
}
