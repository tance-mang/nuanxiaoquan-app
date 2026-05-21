import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../services/proactive_companion.dart';

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

  // ── 主动气泡（每日 opener + 切 tab 上下文，统一通道）────────────
  bool _showGreeting = false;
  String _greetingText = '';
  late AnimationController _greetingCtrl;
  late Animation<double> _greetingOpacity;
  Timer? _greetingDismissTimer;
  // 监听 AppController.companionBubbleSeq 变化的 worker
  Worker? _companionWorker;

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

  // ── 拖拽近期能量（用于动量光晕：动了亮，停了暗）────────────────
  double _lastDragSpeed = 0;
  DateTime _lastDragTime = DateTime.fromMillisecondsSinceEpoch(0);

  final _appCtrl = Get.find<AppController>();

  // ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initAnims();
    _breatheCtrl.repeat(reverse: true);
    _floatCtrl.repeat(reverse: true);
    _startDormantTimer();
    _checkDailyOpener();

    // 监听跨 widget 触发的"小暖讲一句" —— 比如切到某个 Tab 时
    _companionWorker = ever<int>(_appCtrl.companionBubbleSeq, (_) {
      final text = _appCtrl.companionBubbleText;
      if (text.isNotEmpty) _showBubble(text);
    });
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

  // ── 每日首次打开问候（按北京时间 0:00 分日）────────────────────
  // 由 ProactiveCompanion 内部判定，今日已问候过则返回 null
  Future<void> _checkDailyOpener() async {
    if (!_appCtrl.showDailyGreeting.value) return;
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final text = await ProactiveCompanion.dailyOpener();
    if (text == null || !mounted) return;
    _showBubble(text);
  }

  // ── 统一的"小暖说一句"气泡通道 ───────────────────────────────
  // 显示 5 秒后淡出。再次触发会取消上次的定时器。
  void _showBubble(String text) {
    _greetingDismissTimer?.cancel();
    setState(() {
      _greetingText = text;
      _showGreeting = true;
    });
    _greetingCtrl.forward(from: 0);
    _greetingDismissTimer = Timer(const Duration(seconds: 5), () async {
      if (!mounted) return;
      await _greetingCtrl.reverse();
      if (mounted) setState(() => _showGreeting = false);
    });
  }

  @override
  void dispose() {
    _dormantTimer?.cancel();
    _greetingDismissTimer?.cancel();
    _companionWorker?.dispose();
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
      // 记录拖拽速度供光晕使用
      _lastDragSpeed = speed;
      _lastDragTime = DateTime.now();
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
                  _greetingText.isEmpty
                      ? '我在这。'
                      : _greetingText,
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

                // ── 漂浮偏移（Lissajous 弧线，幅度加大让"波动"看得见）────
                final ft = _floatCtrl.value;
                final floatMult = isDormant ? 0.3 : 1.0;
                final floatX = sin(ft * pi) * 8.0 * floatMult;
                final floatY = sin(ft * 2 * pi) * 6.0 * floatMult;

                // ── 动量光晕：基于当前漂浮速度 + 拖拽近期速度 ──────
                // 自然 Lissajous 速度的解析导数
                final natVx = cos(ft * pi) * pi * 8.0 * floatMult;
                final natVy = cos(ft * 2 * pi) * 2 * pi * 6.0 * floatMult;
                final natSpeed =
                    sqrt(natVx * natVx + natVy * natVy) / 45.0; // 归一化 ~0..1
                // 拖拽能量：300ms 半衰期，停手即消散
                final dragMs = DateTime.now()
                    .difference(_lastDragTime)
                    .inMilliseconds
                    .toDouble();
                final dragDecay = (1.0 - (dragMs / 600).clamp(0.0, 1.0));
                final dragEnergy =
                    (_lastDragSpeed / 30.0).clamp(0.0, 1.0) * dragDecay;
                // 综合动量：拖拽优先（用户主动操作），再叠加自然漂浮
                final motionEnergy =
                    (max(dragEnergy, natSpeed * 0.65)).clamp(0.0, 1.0);

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
                      clipBehavior: Clip.none, // 允许点击 ring/光晕扩散到 70w 框外
                      children: [
                        // ── 动量光晕（最底层）：球动了就亮大、停了就暗小 ─────
                        // 不是扩散环（避免和计时器涟漪混），而是单层放射光
                        Container(
                          width: 52.w * (1.0 + motionEnergy * 0.55),
                          height: 52.w * (1.0 + motionEnergy * 0.55),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                primary.withOpacity(
                                    isDormant ? 0.04 : 0.10 + motionEnergy * 0.30),
                                primary.withOpacity(
                                    isDormant ? 0.02 : 0.04 + motionEnergy * 0.18),
                                primary.withOpacity(0.0),
                              ],
                              stops: const [0.0, 0.55, 1.0],
                            ),
                          ),
                        ),

                        // ── 点击瞬时 flash 环（覆盖动量光晕之上，明显反馈）─────
                        // 加粗到 3.5w + 放大到 60w 起点，同时叠加柔光让"啪"的反馈更强
                        if (ringOpacity > 0.01)
                          Transform.scale(
                            scale: ringScaleV,
                            child: Container(
                              width: 60.w,
                              height: 60.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primary.withOpacity(ringOpacity),
                                  width: 3.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withOpacity(
                                        ringOpacity * 0.45),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // ── 球体主体（多层渲染：底色 + 边缘暗 + 环境反射 + 镜面高光）
                        Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.diagonal3Values(
                              finalScale * squishX, finalScale * squishY, 1.0),
                          child: Container(
                            width: 52.w,
                            height: 52.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              // 主底色：径向渐变模拟体积
                              gradient: RadialGradient(
                                center: const Alignment(-0.32, -0.35),
                                radius: 1.05,
                                colors: [
                                  Color.lerp(Colors.white, primary, 0.35)!,
                                  primary,
                                  Color.lerp(primary, Colors.black, 0.28)!,
                                ],
                                stops: const [0.0, 0.55, 1.0],
                              ),
                              // 多层阴影：紧贴的暗影 + 中等模糊主投影 + 远处柔光
                              boxShadow: [
                                // 紧贴硬边阴影（接触感）
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18 *
                                      (1 - dormT * 0.6)),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                                // 主投影
                                BoxShadow(
                                  color: primary.withOpacity(shadowAlpha),
                                  blurRadius: 18,
                                  offset: const Offset(0, 7),
                                ),
                                // 远柔光（让球有"飘起来"的感觉）
                                BoxShadow(
                                  color: primary.withOpacity(
                                      0.18 * (1 - dormT * 0.6)),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                // 底部环境反射（rim light）：
                                // 模拟来自下方暖光向上反弹的微亮，使球体不"贴底"
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        center: const Alignment(0.0, 1.05),
                                        radius: 0.85,
                                        colors: [
                                          Color.lerp(Colors.white, primary, 0.55)!
                                              .withOpacity(0.55),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 1.0],
                                      ),
                                    ),
                                  ),
                                ),

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
                                          shadows: const [
                                            // 文字微投影，与球体融合
                                            Shadow(
                                              color: Color(0x55000000),
                                              blurRadius: 2,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // 镜面高光（specular）：左上椭圆，让球更"有光泽"
                                Positioned(
                                  left: 9.w,
                                  top: 7.w,
                                  child: Transform.rotate(
                                    angle: -0.45,
                                    child: Container(
                                      width: 18.w,
                                      height: 9.w,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(20.r),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.white.withOpacity(
                                                isDormant ? 0.18 : 0.55),
                                            Colors.white.withOpacity(0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // 第二个微高光：右上小亮点，提升金属/玻璃质感
                                Positioned(
                                  right: 12.w,
                                  top: 14.w,
                                  child: Container(
                                    width: 4.w,
                                    height: 4.w,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(
                                          isDormant ? 0.10 : 0.45),
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
