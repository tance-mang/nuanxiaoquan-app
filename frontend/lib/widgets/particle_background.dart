// ============================================================
// 文件：widgets/particle_background.dart
// 作用：暖小圈专属粒子背景特效（触摸互动）
//
// 特色：
//   · 小暖光点漂浮上升（模拟"暖意上涌"的感觉）
//   · 点击/触摸屏幕 → 爆发粒子涟漪效果
//   · 颜色跟随当前主题色（橙暖/粉暖/蓝清等）
//   · 纯 Flutter CustomPainter 实现，不依赖任何第三方包
//   · 性能优化：最多 50 个粒子，超过自动清理
//
// 使用方法：
//   Stack(children: [
//     ParticleBackground(),   // 放在最底层
//     你的内容...
//   ])
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';

// 单个粒子的数据
class _Particle {
  double x;       // 当前 X 坐标（0.0~1.0，相对屏幕宽度）
  double y;       // 当前 Y 坐标
  double vx;      // X 方向速度
  double vy;      // Y 方向速度（负数=向上漂）
  double size;    // 粒子大小
  double opacity; // 透明度（0.0~1.0）
  bool isBurst;   // 是否为触摸爆发粒子

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
    this.isBurst = false,
  });
}

class ParticleBackground extends StatefulWidget {
  final Color particleColor;  // 粒子颜色，默认橙暖色
  final int particleCount;    // 常驻粒子数量

  const ParticleBackground({
    Key? key,
    this.particleColor = const Color(0xFFFF8C42),
    this.particleCount = 30,
  }) : super(key: key);

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final _random = Random();
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    // 动画控制器：每帧都触发重绘
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _controller.addListener(_updateParticles);
  }

  // 初始化常驻粒子（随机分布在屏幕各处）
  void _initParticles() {
    if (_size == Size.zero) return;
    _particles.clear();
    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(_createFloatingParticle(randomY: true));
    }
  }

  // 创建一个从底部开始漂浮上升的粒子
  _Particle _createFloatingParticle({bool randomY = false}) {
    return _Particle(
      x: _random.nextDouble(),
      y: randomY ? _random.nextDouble() : 1.0 + _random.nextDouble() * 0.1,
      vx: (_random.nextDouble() - 0.5) * 0.001,  // 轻微左右飘
      vy: -(0.001 + _random.nextDouble() * 0.002), // 向上漂浮
      size: 2 + _random.nextDouble() * 4,          // 2~6 像素
      opacity: 0.2 + _random.nextDouble() * 0.5,   // 半透明
    );
  }

  // 触摸位置爆发一批粒子（涟漪效果）
  void _createBurst(Offset position) {
    if (_size == Size.zero) return;
    final bx = position.dx / _size.width;
    final by = position.dy / _size.height;
    for (int i = 0; i < 12; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 0.003 + _random.nextDouble() * 0.006;
      _particles.add(_Particle(
        x: bx,
        y: by,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        size: 3 + _random.nextDouble() * 5,
        opacity: 0.8,
        isBurst: true,
      ));
    }
    // 粒子过多时清理老粒子，保证性能
    if (_particles.length > 80) {
      _particles.removeRange(0, 20);
    }
  }

  // 每帧更新所有粒子位置
  void _updateParticles() {
    if (_size == Size.zero) return;
    final toRemove = <_Particle>[];

    for (final p in _particles) {
      p.x += p.vx;
      p.y += p.vy;

      // 爆发粒子：逐渐淡出
      if (p.isBurst) {
        p.opacity -= 0.015;
        p.size *= 0.98;
        if (p.opacity <= 0) toRemove.add(p);
      } else {
        // 漂浮粒子：飘出屏幕顶部后从底部重生
        if (p.y < -0.05) {
          p.x = _random.nextDouble();
          p.y = 1.0;
          p.opacity = 0.2 + _random.nextDouble() * 0.5;
        }
        // 飘出左右边界时回绕
        if (p.x < 0) p.x = 1.0;
        if (p.x > 1) p.x = 0.0;
      }
    }
    _particles.removeWhere((p) => toRemove.contains(p));

    // 补充漂浮粒子（保持数量稳定）
    final floatingCount = _particles.where((p) => !p.isBurst).length;
    if (floatingCount < widget.particleCount) {
      _particles.add(_createFloatingParticle());
    }

    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_updateParticles);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final newSize = Size(constraints.maxWidth, constraints.maxHeight);
        if (_size != newSize) {
          _size = newSize;
          // 第一次确定尺寸时初始化粒子
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_particles.isEmpty) _initParticles();
          });
        }

        return GestureDetector(
          // 触摸任意位置 → 爆发粒子
          onTapDown: (details) => _createBurst(details.localPosition),
          onPanUpdate: (details) {
            // 拖动时每 5 帧创建一次粒子（避免太密）
            if (_random.nextInt(5) == 0) {
              _createBurst(details.localPosition);
            }
          },
          child: CustomPaint(
            size: Size.infinite,
            painter: _ParticlePainter(
              particles: _particles,
              size: _size,
              color: widget.particleColor,
            ),
          ),
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Size size;
  final Color color;

  _ParticlePainter({
    required this.particles,
    required this.size,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (size == Size.zero) return;

    for (final p in particles) {
      final paint = Paint()
        ..color = color.withOpacity(p.opacity.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2); // 发光效果

      canvas.drawCircle(
        Offset(p.x * canvasSize.width, p.y * canvasSize.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}
