import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/app_controller.dart';

// 小暖当前的情绪状态
enum _Mood { idle, shy, dormant }

double _lerp(double a, double b, double t) => a + (b - a) * t;

class AiFloatButton extends StatefulWidget {
  const AiFloatButton({Key? key}) : super(key: key);

  @override
  State<AiFloatButton> createState() => _AiFloatButtonState();
}

class _AiFloatButtonState extends State<AiFloatButton>
    with TickerProviderStateMixin {
  // ── 位置 ──────────────────────────────────────────────────────────
  double _right = 20;
  double _bottom = 100;

  // ── 情绪 ──────────────────────────────────────────────────────────
  _Mood _mood = _Mood.idle;

  // ── 问候气泡 ──────────────────────────────────────────────────────
  bool _showGreeting = false;
  late AnimationController _greetingCtrl;
  late Animation<double> _greetingOpacity;

  // ── 呼吸动画（1.0 ↔ 1.08，2.5s 一循环）────────────────────────────
  late AnimationController _breatheCtrl;

  // ── 漂浮轨迹（Lissajous 弧线，3.2s）──────────────────────────────
  late AnimationController _floatCtrl;

  // ── 害羞点击动画（缩 → 弹 → 稳，420ms）────────────────────────────
  late AnimationController _tapCtrl;

  // ── 犯困渐暗（30s 无互动触发，1.5s 渐入）──────────────────────────
  late AnimationController _dormantCtrl;
  Timer? _dormantTimer;

  // ── 拖拽形变 + 弹回 ───────────────────────────────────────────────
  bool _dragging = false;
  double _dragSX = 1.0; // scaleX during drag
  double _dragSY = 1.0; // scaleY during drag
  double _squishStartX = 1.0;
  double _squishStartY = 1.0;
  late AnimationController _squishCtrl;

  final _appCtrl = Get.find<AppController>();

  // ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initAnims();
    _breatheCtrl.repeat(reverse: true);
    _floatCtrl.repeat(reverse: true);
    _startDormantTimer();
    _checkDailyGreeting();
  }

  void _initAnims() {
    _greetingCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _greetingOpacity = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _greetingCtrl, curve: Curves.easeIn));

    _breatheCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500));

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200));

    _tapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _tapCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _mood = _Mood.idle);
      }
    });

    _dormantCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));

    _squishCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _squishCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() {
          _dragging = false;
          _dragSX = 1.0;
          _dragSY = 1.0;
        });
      }
    });
  }

  // ── 犯困计时器 ────────────────────────────────────────────────────
  void _startDormantTimer() {
    _dormantTimer?.cancel();
    _dormantTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _mood == _Mood.idle) {
        setState(() => _mood = _Mood.dormant);
        _dormantCtrl.forward();
      }
    });
  }

  void _wakeUp() {
    _dormantTimer?.cancel();
    if (_mood == _Mood.dormant && mounted) {
      setState(() => _mood = _Mood.idle);
      _dormantCtrl.reverse();
    }
    _startDormantTimer();
  }

  // ── 每日问候气泡 ──────────────────────────────────────────────────
  Future<void> _checkDailyGreeting() async {
    if (!_appCtrl.showDailyGreeting.value) return;
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if ((prefs.getString('last_greeting_day') ?? '') == today) return;
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _showGreeting = true);
    _greetingCtrl.forward();
    await prefs.setString('last_greeting_day', today);
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    await _greetingCtrl.reverse();
    if (mounted) setState(() => _showGreeting = false);
  }

  @override
  void dispose() {
    _dormantTimer?.cancel();
    _greetingCtrl.dispose();
    _breatheCtrl.dispose();
    _floatCtrl.dispose();
    _tapCtrl.dispose();
    _dormantCtrl.dispose();
    _squishCtrl.dispose();
    super.dispose();
  }

  // ── 手势处理 ──────────────────────────────────────────────────────
  void _onTap() {
    _wakeUp();
    setState(() => _mood = _Mood.shy);
    _tapCtrl.reset();
    _tapCtrl.forward();
    Get.toNamed('/ai-chat');
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _wakeUp();
    final size = MediaQuery.of(context).size;
    setState(() {
      _right = (_right - d.delta.dx).clamp(0.0, size.width - 56.0);
      _bottom = (_bottom - d.delta.dy).clamp(80.0, size.height - 120.0);
      // 椭圆形变：横向速度越快越扁
      final speed = d.delta.dx.abs() + d.delta.dy.abs();
      final hRatio = d.delta.dx.abs() / (speed + 0.001);
      _dragSX = (1.0 + hRatio * speed * 0.022).clamp(0.82, 1.45);
      _dragSY = (1.0 - hRatio * speed * 0.014).clamp(0.72, 1.0);
      _dragging = true;
    });
  }

  void _onDragEnd(DragEndDetails _) {
    _squishStartX = _dragSX;
    _squishStartY = _dragSY;
    _squishCtrl.reset();
    _squishCtrl.forward();
  }

  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Positioned(
      right: _right,
      bottom: _bottom,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 问候气泡 ────────────────────────────────────────────
          if (_showGreeting)
            FadeTransition(
              opacity: _greetingOpacity,
              child: Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                constraints: BoxConstraints(maxWidth: 200.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Text(
                  '我是你的专属助手小暖，随时帮你规划学习、整理生活～',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                ),
              ),
            ),

          // ── 小暖球体 ────────────────────────────────────────────
          GestureDetector(
            onPanUpdate: _onDragUpdate,
            onPanEnd: _onDragEnd,
            onTap: _onTap,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _breatheCtrl,
                _floatCtrl,
                _tapCtrl,
                _dormantCtrl,
                _squishCtrl,
              ]),
              builder: (ctx, _) {
                final isDormant = _mood == _Mood.dormant;
                final dormT = _dormantCtrl.value;

                // ── 呼吸缩放 ──────────────────────────────────────
                final breatheMult = isDormant ? 0.25 : 1.0;
                final breatheScale = 1.0 + _breatheCtrl.value * 0.08 * breatheMult;

                // ── 漂浮偏移（Lissajous 弧线）────────────────────
                final ft = _floatCtrl.value;
                final floatMult = isDormant ? 0.3 : 1.0;
                final floatX = sin(ft * pi) * 3.0 * floatMult;
                final floatY = sin(ft * 2 * pi) * 2.5 * floatMult;

                // ── 害羞点击动画 ──────────────────────────────────
                double tapScale = 1.0;
                double textTilt = 0.0;
                double ringOpacity = 0.0;
                double ringScaleV = 1.0;

                if (_tapCtrl.isAnimating || _mood == _Mood.shy) {
                  final t = _tapCtrl.value;
                  // 三段：缩 → 弹 → 稳
                  if (t < 0.30) {
                    tapScale = _lerp(1.0, 0.82, t / 0.30);
                    textTilt = _lerp(0.0, -0.16, t / 0.30);
                  } else if (t < 0.70) {
                    tapScale = _lerp(0.82, 1.13, (t - 0.30) / 0.40);
                    textTilt = _lerp(-0.16, 0.11, (t - 0.30) / 0.40);
                  } else {
                    tapScale = _lerp(1.13, 1.0, (t - 0.70) / 0.30);
                    textTilt = _lerp(0.11, 0.0, (t - 0.70) / 0.30);
                  }
                  // 外圈：快速亮起，慢慢消散
                  ringOpacity = t < 0.20
                      ? (t / 0.20) * 0.85
                      : _lerp(0.85, 0.0, (t - 0.20) / 0.80);
                  ringOpacity = ringOpacity.clamp(0.0, 0.85);
                  ringScaleV = 1.0 + t * 0.95;
                }

                // ── 犯困：变暗 + 文字下沉 ─────────────────────────
                final dimOpacity = dormT * 0.28;
                final textDropY = dormT * 3.2;
                final shadowAlpha = (0.38 - dormT * 0.22).clamp(0.0, 0.38);

                // ── 拖拽形变 + 弹回 ───────────────────────────────
                double squishX, squishY;
                if (_dragging) {
                  squishX = _dragSX;
                  squishY = _dragSY;
                } else if (_squishCtrl.isAnimating) {
                  final et =
                      Curves.elasticOut.transform(_squishCtrl.value.clamp(0.0, 1.0));
                  squishX = _lerp(_squishStartX, 1.0, et);
                  squishY = _lerp(_squishStartY, 1.0, et);
                } else {
                  squishX = 1.0;
                  squishY = 1.0;
                }

                final finalScale = breatheScale * tapScale;

                return Transform.translate(
                  offset: Offset(floatX, floatY),
                  child: SizedBox(
                    width: 70.w,
                    height: 70.w,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // ── 外圈闪光（点击时）───────────────────
                        if (ringOpacity > 0.01)
                          Transform.scale(
                            scale: ringScaleV,
                            child: Container(
                              width: 52.w,
                              height: 52.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primary.withOpacity(ringOpacity),
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),

                        // ── 外层柔光晕（待机常亮）─────────────
                        Opacity(
                          opacity: isDormant ? 0.12 : 0.22,
                          child: Container(
                            width: 58.w,
                            height: 58.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primary.withOpacity(0.35),
                            ),
                          ),
                        ),

                        // ── 球体主体 ─────────────────────────
                        Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.diagonal3Values(
                              finalScale * squishX, finalScale * squishY, 1.0),
                          child: Container(
                            width: 52.w,
                            height: 52.w,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(-0.35, -0.38),
                                radius: 0.88,
                                colors: [
                                  // 左上高光，让球有立体感
                                  Color.lerp(Colors.white, primary, 0.42)!,
                                  primary,
                                  Color.lerp(primary, Colors.black, 0.15)!,
                                ],
                                stops: const [0.0, 0.6, 1.0],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withOpacity(shadowAlpha),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // 犯困遮暗层
                                if (dimOpacity > 0.01)
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withOpacity(dimOpacity),
                                    ),
                                  ),
                                // 文字：有形变 + 下坠
                                Center(
                                  child: Transform.translate(
                                    offset: Offset(0, textDropY),
                                    child: Transform.rotate(
                                      angle: textTilt,
                                      child: Text(
                                        '小\n暖',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withOpacity(isDormant ? 0.75 : 1.0),
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.bold,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
