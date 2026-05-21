import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/tap_scale.dart';
import '../widgets/state_trend_bar.dart';
import '../widgets/today_focus_card.dart';
import '../widgets/start_study_cta.dart';
import '../controllers/app_controller.dart';

// ── 粒子特效 Painter ──────────────────────────────────────────
class _SparkPainter extends CustomPainter {
  final double t;
  final List<({double vx, double vy, double r, Color c})> sparks;
  const _SparkPainter(this.t, this.sparks);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in sparks) {
      final opacity = (1 - t * t).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(size.width / 2 + s.vx * t * 44,
               size.height / 2 + s.vy * t * 44),
        (s.r * (1 - t * 0.4)).clamp(0.5, 8),
        Paint()..color = s.c.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter o) => o.t != t;
}

// ── 小任务行 ──────────────────────────────────────────────────
class _TaskRow extends StatelessWidget {
  final String text;
  final bool done;
  final VoidCallback onToggle;
  final Color primary;

  const _TaskRow({
    required this.text,
    required this.done,
    required this.onToggle,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      scale: 0.97,
      onTap: onToggle,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 5.h),
        child: Row(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              key: ValueKey(done),
              size: 18.sp,
              color: done ? Colors.green : Colors.grey[350],
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 13.sp,
                color: done ? Colors.grey[400] : Colors.grey[700],
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: Colors.grey[400],
              ),
              child: Text(text),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── 侧滑完成卡片 ─────────────────────────────────────────────
class _PlanCard extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Color primary;
  final bool isExpanded;
  final VoidCallback onCompleteDay;
  final void Function(String taskId) onToggleTask;
  final VoidCallback onToggleExpand;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final int listIndex;
  /// C 类：今日状态偏低（精力≤4 或 痛经/焦虑/累），第一张卡显示"今天轻量版"
  final bool isLowStateToday;
  /// 用户挑选的"今日必保"计划 → 该卡片显示绿色徽章 + 排到第一位
  final bool isMustDo;
  /// 用户长按弹出菜单时切换 must-do 选择
  final VoidCallback onToggleMustDo;

  const _PlanCard({
    Key? key,
    required this.plan,
    required this.primary,
    required this.isExpanded,
    required this.onCompleteDay,
    required this.onToggleTask,
    required this.onToggleExpand,
    required this.onEdit,
    required this.onDelete,
    required this.listIndex,
    required this.onToggleMustDo,
    this.isLowStateToday = false,
    this.isMustDo = false,
  }) : super(key: key);

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> with TickerProviderStateMixin {
  double _dragX = 0;
  double _snapFromX = 0;
  late AnimationController _snapCtrl;
  late AnimationController _sparkCtrl;
  late List<({double vx, double vy, double r, Color c})> _sparks;
  static final _rng = Random();

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 340))
      ..addListener(() {
        if (mounted) {
          setState(() => _dragX = _snapFromX *
              (1 - Curves.easeOutCubic.transform(_snapCtrl.value)));
        }
      });
    _sparkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _buildSparks();
  }

  void _buildSparks() {
    final hues = [0.0, 30.0, 55.0, 190.0, 280.0, 340.0];
    _sparks = List.generate(10, (i) {
      final angle = i * pi / 5;
      final speed = 0.6 + _rng.nextDouble() * 0.8;
      return (
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        r: 2.5 + _rng.nextDouble() * 3.5,
        c: HSLColor.fromAHSL(1, hues[i % hues.length], 0.85, 0.58).toColor(),
      );
    });
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    _sparkCtrl.dispose();
    super.dispose();
  }

  bool get _todayDone => widget.plan['todayDone'] == true;

  List<Map<String, dynamic>> get _tasks {
    final raw = widget.plan['dailyTasks'];
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
        (raw as List).map((t) => Map<String, dynamic>.from(t as Map)));
  }

  double get _taskProgress {
    final tasks = _tasks;
    if (tasks.isEmpty) return _todayDone ? 1.0 : 0.0;
    final done = tasks.where((t) => t['done'] == true).length;
    return done / tasks.length;
  }

  double get _overallProgress {
    final comp = (widget.plan['completedDays'] ?? 0) as num;
    final total = (widget.plan['duration'] ?? 1) as num;
    return (comp / total).clamp(0.0, 1.0);
  }

  Color get _skinBg {
    final p = _overallProgress;
    if (p >= 1.0) return const Color(0xFFFFF8E1);
    if (p >= 0.6) return const Color(0xFFF0F8FF);
    if (p >= 0.3) return const Color(0xFFF8F5FF);
    return Colors.white;
  }

  Color? get _skinBorder {
    final p = _overallProgress;
    if (p >= 1.0) return const Color(0xFFFFD700).withOpacity(0.5);
    if (p >= 0.6) return widget.primary.withOpacity(0.35);
    return null;
  }

  void _onDragUpdate(DragUpdateDetails d, double cardWidth) {
    if (_todayDone) return;
    _snapCtrl.stop();
    setState(() {
      _dragX = (_dragX + d.delta.dx).clamp(0.0, cardWidth * 0.88);
    });
  }

  void _onDragEnd(DragEndDetails d, double cardWidth) {
    if (_todayDone) return;
    if (_dragX / cardWidth >= 0.78) {
      HapticFeedback.lightImpact();
      _sparkCtrl.forward(from: 0);
      setState(() => _dragX = 0);
      widget.onCompleteDay();
    } else {
      _snapFromX = _dragX;
      _snapCtrl.forward(from: 0);
    }
  }

  /// 长按 plan 卡 → 弹底部菜单（编辑 / 设为必保 / 删除）
  void _showCardMenu() {
    HapticFeedback.selectionClick();
    final isMustDo = widget.isMustDo;
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                widget.plan['title'] as String? ?? '我的计划',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 12.h),
              _menuRow(
                icon: Icons.shield_outlined,
                title: isMustDo ? '取消今日必保' : '设为今日必保',
                desc: isMustDo
                    ? '不再优先显示这一项'
                    : '把它排到第一位，并给绿色徽章',
                tint: const Color(0xFF047857),
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onToggleMustDo();
                },
              ),
              _menuRow(
                icon: Icons.edit_outlined,
                title: '编辑',
                desc: '改名 / 内容 / 任务',
                tint: widget.primary,
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onEdit();
                },
              ),
              _menuRow(
                icon: Icons.delete_outline,
                title: '删除',
                desc: '从列表中移除',
                tint: const Color(0xFFE11D48),
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuRow({
    required IconData icon,
    required String title,
    required String desc,
    required Color tint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 10.h),
        child: Row(
          children: [
            Container(
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withOpacity(0.14),
              ),
              child: Icon(icon, size: 16.sp, color: tint),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827))),
                  SizedBox(height: 2.h),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 11.sp, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18.sp, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primary;
    final plan = widget.plan;
    final title = plan['title'] as String? ?? '我的计划';
    final content = plan['content'] as String? ?? '';
    final streak = (plan['streak'] ?? 0) as int;
    final comp = (plan['completedDays'] ?? 0) as int;
    final total = (plan['duration'] ?? 30) as int;
    final tasks = _tasks;
    final tasksDoneCount = tasks.where((t) => t['done'] == true).length;
    final skinBorder = _skinBorder;

    return LayoutBuilder(builder: (ctx, constraints) {
      final cardWidth = constraints.maxWidth;
      final swipeFrac = (_dragX / cardWidth).clamp(0.0, 1.0);
      final nearThreshold = swipeFrac >= 0.78;

      return GestureDetector(
        onHorizontalDragUpdate: (d) => _onDragUpdate(d, cardWidth),
        onHorizontalDragEnd: (d) => _onDragEnd(d, cardWidth),
        // 长按弹菜单：设为/取消「今日必保」
        onLongPress: () => _showCardMenu(),
        child: Container(
          margin: EdgeInsets.only(bottom: 10.h),
          decoration: BoxDecoration(
            color: _skinBg,
            borderRadius: BorderRadius.circular(14.r),
            border: skinBorder != null
                ? Border.all(color: skinBorder, width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: primary.withOpacity(_overallProgress >= 0.6 ? 0.10 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            // 滑动填充
            if (!_todayDone && _dragX > 0)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: _dragX,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        primary.withOpacity(0.10),
                        primary.withOpacity(0.22),
                      ]),
                    ),
                  ),
                ),
              ),

            // 阈值提示
            if (nearThreshold && !_todayDone)
              Positioned(
                right: 14.w, top: 0, bottom: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check, color: Colors.white, size: 13.sp),
                      SizedBox(width: 2.w),
                      Text('完成', style: TextStyle(
                          color: Colors.white, fontSize: 11.sp,
                          fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),

            // 主内容
            Padding(
              padding: EdgeInsets.all(14.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行（点击展开/收起）
                  GestureDetector(
                    onTap: widget.onToggleExpand,
                    behavior: HitTestBehavior.opaque,
                    child: Row(children: [
                    ReorderableDragStartListener(
                      index: widget.listIndex,
                      child: Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: Icon(Icons.drag_indicator,
                            size: 18.sp, color: Colors.grey[300]),
                      ),
                    ),
                    Expanded(
                      child: Text(title,
                          style: TextStyle(
                              fontSize: 14.sp, fontWeight: FontWeight.w600)),
                    ),
                    // 基础任务"保险箱"：用户长按选定的「今日必保」计划得到绿色徽章
                    // 状态差时这条 100% 可完成 → 维持心理安全感
                    if (widget.isMustDo && !_todayDone)
                      Container(
                        margin: EdgeInsets.only(right: 6.w),
                        padding: EdgeInsets.symmetric(
                            horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8.r),
                          border:
                              Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined,
                                size: 11.sp,
                                color: const Color(0xFF047857)),
                            SizedBox(width: 3.w),
                            Text('今日必保',
                                style: TextStyle(
                                    fontSize: 10.sp,
                                    color: const Color(0xFF047857),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    if (streak >= 3)
                      Container(
                        margin: EdgeInsets.only(right: 6.w),
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text('$streak天',
                            style: TextStyle(
                                fontSize: 10.sp, color: Colors.orange[700])),
                      ),
                    if (_todayDone)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text('✓ 今日完成',
                            style: TextStyle(
                                fontSize: 10.sp, color: Colors.green[600],
                                fontWeight: FontWeight.w600)),
                      )
                    else
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text('${total}天',
                            style: TextStyle(fontSize: 10.sp, color: primary)),
                      ),
                  ])),  // closes Row + GestureDetector

                  // 注：plan 卡上不再重复显示"今天轻量版"，
                  // 同样的提示已经由首页顶部的全局推荐行（_stateRecommendation）承担

                  SizedBox(height: 8.h),

                  // 总进度条
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: Stack(children: [
                      Container(height: 5.h, color: Colors.grey.shade100),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        height: 5.h,
                        width: cardWidth * _overallProgress,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _overallProgress >= 1.0
                                ? [Colors.amber, Colors.orange]
                                : [primary.withOpacity(0.55), primary],
                          ),
                          boxShadow: _overallProgress >= 0.5
                              ? [BoxShadow(
                                  color: primary.withOpacity(0.30),
                                  blurRadius: 4, offset: const Offset(0, 1))]
                              : null,
                        ),
                      ),
                    ]),
                  ),
                  SizedBox(height: 4.h),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$comp/$total 天  ${(_overallProgress * 100).toInt()}%',
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey[400])),
                      if (!_todayDone && tasks.isEmpty)
                        Text('右滑完成今日',
                            style: TextStyle(
                                fontSize: 10.sp, color: primary.withOpacity(0.35)))
                      else if (!_todayDone && tasks.isNotEmpty)
                        Text('$tasksDoneCount/${tasks.length} 项',
                            style: TextStyle(
                                fontSize: 10.sp, color: primary.withOpacity(0.6))),
                    ],
                  ),

                  // 展开区域
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeInOut,
                    child: widget.isExpanded
                        ? Padding(
                            padding: EdgeInsets.only(top: 10.h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Divider(height: 1, color: Colors.grey.shade200),
                                SizedBox(height: 10.h),

                                // 小任务列表
                                if (tasks.isNotEmpty) ...[
                                  Text('今日任务',
                                      style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[600])),
                                  SizedBox(height: 4.h),
                                  ...tasks.map((task) => _TaskRow(
                                    text: task['text'] as String? ?? '',
                                    done: task['done'] == true,
                                    primary: primary,
                                    onToggle: () =>
                                        widget.onToggleTask(task['id'] as String),
                                  )),
                                  // 任务进度条（仅当有任务时）
                                  if (tasks.length > 1) ...[
                                    SizedBox(height: 6.h),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(3.r),
                                      child: Stack(children: [
                                        Container(
                                            height: 3.h, color: Colors.grey.shade100),
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 400),
                                          height: 3.h,
                                          width: cardWidth * _taskProgress,
                                          color: Colors.green.withOpacity(0.6),
                                        ),
                                      ]),
                                    ),
                                    SizedBox(height: 6.h),
                                  ],
                                  Divider(height: 12, color: Colors.grey.shade200),
                                ],

                                // 计划描述
                                if (content.isNotEmpty) ...[
                                  Text(content,
                                      style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.grey[500],
                                          height: 1.65)),
                                  SizedBox(height: 10.h),
                                ],

                                // 操作按钮
                                Wrap(spacing: 8.w, children: [
                                  _ActionChip(
                                    icon: Icons.edit_outlined,
                                    label: '编辑',
                                    color: primary,
                                    onTap: widget.onEdit,
                                  ),
                                  _ActionChip(
                                    icon: Icons.delete_outline,
                                    label: '删除',
                                    color: Colors.red.shade300,
                                    onTap: widget.onDelete,
                                  ),
                                  if (_todayDone)
                                    _ActionChip(
                                      icon: Icons.undo,
                                      label: '撤销今日',
                                      color: Colors.orange.shade400,
                                      onTap: widget.onCompleteDay,
                                    ),
                                ]),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // 粒子特效
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _sparkCtrl,
                  builder: (_, __) => _sparkCtrl.value > 0
                      ? CustomPaint(
                          painter: _SparkPainter(_sparkCtrl.value, _sparks))
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip(
      {required this.icon, required this.label,
       required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12.sp, color: color),
          SizedBox(width: 3.w),
          Text(label,
              style: TextStyle(fontSize: 11.sp, color: color,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ── HomeScreen ───────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _userPlans = [];
  final Set<String> _expandedIds = {};
  static const _plansKey = 'home_user_plans_v2';

  // ── C 类状态采集（最小起步）─────────────────────────────────
  // 仅前端本地采集，按日期 key 存 SharedPreferences。
  // 后续 C 类规则引擎会消费这份数据（精力 + 不适标签 → 任务推荐策略）。
  Map<String, dynamic>? _todayState;
  bool _stateExpanded = false;
  int _editingEnergy = 6;
  String? _editingCondition;

  /// 用户手动指定的"今日必保"计划 ID（null = 没选）
  /// 持久化到 SharedPreferences key 'must_do_plan_id'，跨日保留直到用户改
  String? _mustDoPlanId;
  static const _mustDoKey = 'must_do_plan_id';

  late AnimationController _breathCtrl;
  late Animation<double> _breathAnim;

  // 预置示例（首次使用时自动添加，可删除）
  static final _defaultPlans = [
    {
      'id': 'default_morning',
      'title': '晨间习惯养成 21 天',
      'content': '培养早起、冥想、阅读三件事，21 天形成肌肉记忆。',
      'duration': 21,
      'dailyTasks': [
        {'id': 'dm1', 'text': '早起 6:30 打卡', 'done': false},
        {'id': 'dm2', 'text': '冥想 10 分钟', 'done': false},
        {'id': 'dm3', 'text': '阅读 20 页', 'done': false},
      ],
      'completedDays': 0,
      'todayDone': false,
      'lastCompletedDate': '',
      'streak': 0,
      'progress': 0,
      'status': '进行中',
      'createdAt': '2026-01-01T00:00:00.000Z',
    },
    {
      'id': 'default_english',
      'title': '考研英语备考 60 天',
      'content': '每日三步走，60 天稳扎稳打攻克考研英语阅读与写作。',
      'duration': 60,
      'dailyTasks': [
        {'id': 'de1', 'text': '背 20 个核心词汇', 'done': false},
        {'id': 'de2', 'text': '精读一篇阅读理解', 'done': false},
        {'id': 'de3', 'text': '整理生词到笔记本', 'done': false},
      ],
      'completedDays': 0,
      'todayDone': false,
      'lastCompletedDate': '',
      'streak': 0,
      'progress': 0,
      'status': '进行中',
      'createdAt': '2026-01-01T00:00:01.000Z',
    },
  ];

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 1.0, end: 1.022).animate(
        CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut));
    _loadPlans();
    _loadTodayState();
    _loadMustDoId();
  }

  // ── 加载/保存 今日状态 ────────────────────────────────────
  String _stateKey() => 'daily_state_${_todayStr()}';

  Future<void> _loadMustDoId() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _mustDoPlanId = prefs.getString(_mustDoKey));
  }

  Future<void> _setMustDoPlan(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_mustDoKey);
    } else {
      await prefs.setString(_mustDoKey, id);
    }
    if (!mounted) return;
    setState(() => _mustDoPlanId = id);
  }

  /// 切换某个 plan 为必保 / 取消（若已经是必保则取消）
  void _toggleMustDo(String planId) {
    if (_mustDoPlanId == planId) {
      _setMustDoPlan(null);
    } else {
      _setMustDoPlan(planId);
    }
  }

  /// 排序：用户挑的「今日必保」永远排第一位，其他按原顺序
  List<Map<String, dynamic>> get _sortedPlans {
    if (_mustDoPlanId == null) return _userPlans;
    final mustDo = _userPlans.where((p) => p['id'] == _mustDoPlanId);
    if (mustDo.isEmpty) return _userPlans;
    final others = _userPlans.where((p) => p['id'] != _mustDoPlanId);
    return [...mustDo, ...others];
  }

  Future<void> _loadTodayState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey());
    if (!mounted) return;
    setState(() {
      if (raw != null) {
        _todayState = jsonDecode(raw) as Map<String, dynamic>;
        _editingEnergy = (_todayState!['energy'] as int?) ?? 6;
        _editingCondition = _todayState!['condition'] as String?;
      }
    });
  }

  Future<void> _saveTodayState() async {
    final prefs = await SharedPreferences.getInstance();
    final m = {
      'date': _todayStr(),
      'energy': _editingEnergy,
      'condition': _editingCondition,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_stateKey(), jsonEncode(m));
    if (!mounted) return;
    setState(() {
      _todayState = m;
      _stateExpanded = false;
    });
    // 清掉"请求编辑状态"标志，让卡片重新折叠（实际是隐藏）
    Get.find<AppController>().clearEditState();
  }

  /// C 类：今日是否处于"状态偏低"
  ///
  /// 判定规则（命中任一即为低状态）：
  ///   1. energy <= 4：自评精力 1-10 分中 4 分及以下，明显的低能量
  ///   2. condition == '痛经不适'：女性用户主动选择，身体不适
  ///   3. condition == '焦虑'：情绪压力高，认知负荷敏感
  ///   4. condition == '有点累'：精力虽然中等但已被自评累
  ///
  /// 中性（不命中）的情况会被推荐成"中性 → 不打扰"，避免误判。
  ///
  /// 数据源：SharedPreferences key 'daily_state_<YYYY-MM-DD>'
  /// 写入方：HomeScreen `_saveTodayState`（用户主动"记一下"）
  /// 消费方：
  ///   - 首页顶部推荐行 `_stateRecommendation`
  ///   - （已删）plan 卡的"今天轻量版" subline，避免重复
  bool get _isLowStateToday {
    if (_todayState == null) return false;
    final e = _todayState!['energy'] as int? ?? 6;
    final c = _todayState!['condition'] as String?;
    return e <= 4 ||
        c == '痛经不适' ||
        c == '焦虑' ||
        c == '有点累';
  }

  // ── C 类规则起步：把今日状态映射为一句温和建议 ──────────────
  // 注意：这只是提示，不替用户做决定，不弹窗
  // 返回 (emoji+文案, color) 或 null（中性状态不打扰）
  ({String text, Color tint})? _stateRecommendation(Color primary) {
    if (_todayState == null) return null;
    final e = _todayState!['energy'] as int? ?? 6;
    final c = _todayState!['condition'] as String?;
    final isNegCond = c == '痛经不适' || c == '焦虑' || c == '有点累';
    if (e >= 8 && !isNegCond) {
      return (
        text: '✨ 状态不错，今天可以挑战难一点的任务',
        tint: const Color(0xFF6CB87C),
      );
    }
    if (e <= 4 || isNegCond) {
      return (
        text: '🌿 今天先轻量为主，完成基础打卡就够',
        tint: const Color(0xFFE08A6E),
      );
    }
    return null;
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    super.dispose();
  }

  String _todayStr() => DateTime.now().toIso8601String().substring(0, 10);
  String _yesterdayStr() =>
      DateTime.now().subtract(const Duration(days: 1))
          .toIso8601String().substring(0, 10);

  Future<void> _loadPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_plansKey);
    if (raw != null) {
      final today = _todayStr();
      final plans = List<Map<String, dynamic>>.from(jsonDecode(raw));
      for (final p in plans) {
        // 新的一天，重置今日状态和任务完成情况
        if ((p['lastCompletedDate'] ?? '') != today) {
          p['todayDone'] = false;
          final tasks = p['dailyTasks'];
          if (tasks is List) {
            p['dailyTasks'] = tasks.map((t) {
              final m = Map<String, dynamic>.from(t as Map);
              m['done'] = false;
              return m;
            }).toList();
          }
        }
      }
      setState(() => _userPlans = plans);
    } else {
      // 首次使用，预置示例计划
      setState(() => _userPlans =
          _defaultPlans.map((p) => Map<String, dynamic>.from(p)).toList());
      _savePlans();
    }
  }

  Future<void> _savePlans() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_plansKey, jsonEncode(_userPlans));
  }

  // ── 完成 / 撤销今日 ──────────────────────────────────────────
  void _completeToday(int index) {
    final plan = Map<String, dynamic>.from(_userPlans[index]);
    final alreadyDone = plan['todayDone'] == true;

    if (alreadyDone) {
      // 撤销
      plan['todayDone'] = false;
      plan['lastCompletedDate'] = '';
      final comp = ((plan['completedDays'] ?? 1) as num).toInt();
      plan['completedDays'] = (comp - 1).clamp(0, 9999);
      plan['progress'] = ((plan['completedDays'] as num) /
          ((plan['duration'] ?? 1) as num) * 100).toInt();
      // 重置任务
      final tasks = plan['dailyTasks'];
      if (tasks is List) {
        plan['dailyTasks'] = tasks.map((t) {
          final m = Map<String, dynamic>.from(t as Map);
          m['done'] = false;
          return m;
        }).toList();
      }
    } else {
      // 完成
      final total = ((plan['duration'] ?? 30) as num).toInt();
      final comp = ((plan['completedDays'] ?? 0) as num).toInt();
      plan['completedDays'] = (comp + 1).clamp(0, total);
      plan['todayDone'] = true;
      plan['lastCompletedDate'] = _todayStr();
      final prevDate = plan['lastCompletedDate'] as String? ?? '';
      final streak = ((plan['streak'] ?? 0) as num).toInt();
      plan['streak'] = prevDate == _yesterdayStr() ? streak + 1 : 1;
      plan['progress'] = ((plan['completedDays'] as num) / total * 100).toInt();
      // 标记所有任务完成
      final tasks = plan['dailyTasks'];
      if (tasks is List) {
        plan['dailyTasks'] = tasks.map((t) {
          final m = Map<String, dynamic>.from(t as Map);
          m['done'] = true;
          return m;
        }).toList();
      }
    }

    setState(() => _userPlans[index] = plan);
    _savePlans();

    // C 类强反馈：完成"今日必保"任务时给一个去评价化的鼓励 snackbar
    // 现在挂在用户挑选的「今日必保」计划上，不再固定在第一条
    final completedId = plan['id'] as String?;
    if (!alreadyDone && completedId == _mustDoPlanId && _mustDoPlanId != null) {
      final encouragement = _isLowStateToday
          ? '今天状态不在最佳，能完成基础就够了'
          : '基础骨架稳稳的，进阶任务可以慢慢来';
      Get.snackbar(
        '🛡 今日必保 已完成',
        encouragement,
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFD1FAE5),
        colorText: const Color(0xFF065F46),
        margin: EdgeInsets.all(14.w),
        borderRadius: 12,
        duration: const Duration(seconds: 3),
        icon: const Icon(Icons.shield_outlined,
            color: Color(0xFF047857)),
      );
    }
  }

  // ── 勾选单个小任务 ────────────────────────────────────────────
  void _toggleTask(int planIndex, String taskId) {
    final plan = Map<String, dynamic>.from(_userPlans[planIndex]);
    final raw = plan['dailyTasks'];
    if (raw == null) return;

    final tasks = List<Map<String, dynamic>>.from(
        (raw as List).map((t) => Map<String, dynamic>.from(t as Map)));
    final idx = tasks.indexWhere((t) => t['id'] == taskId);
    if (idx < 0) return;

    tasks[idx]['done'] = !(tasks[idx]['done'] == true);
    plan['dailyTasks'] = tasks;

    // 全部勾完 → 自动触发完成今日
    final allDone =
        tasks.isNotEmpty && tasks.every((t) => t['done'] == true);
    setState(() => _userPlans[planIndex] = plan);
    _savePlans();

    if (allDone && plan['todayDone'] != true) {
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 180),
          () => _completeToday(planIndex));
    }
  }

  void _toggleExpand(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  void _onReorder(int oldIdx, int newIdx) {
    if (newIdx > oldIdx) newIdx--;
    setState(() {
      final item = _userPlans.removeAt(oldIdx);
      _userPlans.insert(newIdx, item);
    });
    _savePlans();
  }

  // ── 今日概览 ──────────────────────────────────────────────────
  Widget _buildTodaySummary(Color primary) {
    if (_userPlans.isEmpty) return const SizedBox.shrink();
    final total = _userPlans.length;
    final done = _userPlans.where((p) => p['todayDone'] == true).length;
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary.withOpacity(0.08), primary.withOpacity(0.03)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: primary.withOpacity(0.14)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              done == total ? '🎉 今日全部完成！' : '今日待完成 ${total - done}/$total 个计划',
              style: TextStyle(
                fontSize: 13.sp, fontWeight: FontWeight.w600,
                color: done == total ? Colors.green[700] : const Color(0xFF2D2D2D)),
            ),
            SizedBox(height: 6.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(3.r),
              child: LinearProgressIndicator(
                value: done / total,
                backgroundColor: Colors.white,
                valueColor: AlwaysStoppedAnimation<Color>(
                    done == total ? Colors.green : primary),
                minHeight: 4.h,
              ),
            ),
          ]),
        ),
        SizedBox(width: 14.w),
        Text('$done/$total',
            style: TextStyle(
                fontSize: 22.sp, fontWeight: FontWeight.bold, color: primary)),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 今日状态采集卡（C 类最小起步）
  // 已记录：紧凑摘要 + 调整入口
  // 未记录或调整中：精力滑块 1-10 + 状态 chip + 保存按钮
  // ─────────────────────────────────────────────────────────────
  Widget _buildDailyStateCard(Color primary) {
    // 状态已记录 → 隐藏整个卡，不再与 hero CTA 重复显示
    // （hero CTA 顶部已经有"今天 · 状态XX"的 chip）
    // 用户想调整 → hero CTA 右上 ⋯ 菜单的「调整今日状态」会触发 needsEditState=true
    final ac = Get.find<AppController>();
    final needsEdit = ac.needsEditState.value;
    final logged = _todayState != null && !_stateExpanded && !needsEdit;
    if (logged) {
      return const SizedBox.shrink();
    }
    // 从更多菜单点了"调整今日状态"，强制展开
    if (needsEdit && !_stateExpanded) {
      _stateExpanded = true;
    }

    // 痛经不适仅女性用户显示（且不假设每个女生都受影响——只是提供这个选项）
    final isFemale = Get.find<AppController>().userGender.value == 'female';
    final conditions = <String>[
      '精力很好',
      '一般',
      '有点累',
      if (isFemale) '痛经不适',
      '焦虑',
    ];
    final eColor = Color.lerp(
        const Color(0xFF6FA8FF), primary, _editingEnergy / 10.0)!;
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: primary.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('今日状态',
                style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2D2D2D))),
            const Spacer(),
            Text('精力 $_editingEnergy/10',
                style: TextStyle(fontSize: 12.sp, color: eColor)),
          ]),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: eColor,
              inactiveTrackColor: Colors.grey.shade200,
              thumbColor: eColor,
              overlayColor: eColor.withOpacity(0.15),
              trackHeight: 3,
            ),
            child: Slider(
              value: _editingEnergy.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (v) =>
                  setState(() => _editingEnergy = v.round()),
            ),
          ),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: conditions.map((c) {
              final selected = _editingCondition == c;
              return GestureDetector(
                onTap: () => setState(() =>
                    _editingCondition = selected ? null : c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(
                      horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: selected
                        ? primary.withOpacity(0.12)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: selected
                          ? primary.withOpacity(0.6)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Text(c,
                      style: TextStyle(
                          fontSize: 12.sp,
                          color: selected ? primary : Colors.grey[700],
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 10.h),
          Row(children: [
            const Spacer(),
            if (_stateExpanded)
              GestureDetector(
                onTap: () => setState(() => _stateExpanded = false),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  child: Text('取消',
                      style: TextStyle(
                          fontSize: 12.sp, color: Colors.grey[500])),
                ),
              ),
            GestureDetector(
              onTap: _saveTodayState,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 16.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text('记一下',
                    style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 28.w, height: 28.w,
            decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
            child: Center(child: Text('暖',
                style: TextStyle(color: Colors.white, fontSize: 13.sp,
                    fontWeight: FontWeight.bold))),
          ),
          SizedBox(width: 8.w),
          Text('暖小圈',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPlans,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 120.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero CTA：核心闭环入口，状态 + 推荐模式 + 一键开始学习
              const StartStudyCta(),
              _buildTodaySummary(primary),
              // 今日累计专注（仅当今日已专注 > 0 秒时显示）
              const TodayFocusCard(),
              // 最近 7 天精力趋势（仅当有任意一天数据时才显示）
              const StateTrendBar(),
              // 今日状态输入卡：未记录时显示完整表单，已记录后隐藏
              // （已记录时由 hero CTA 顶部 chip 显示状态结论，避免重复）
              // 调整入口：hero CTA ⋯ 菜单的「调整今日状态」会请求展开
              Obx(() {
                // 触达 needsEditState 让 Obx 重建
                Get.find<AppController>().needsEditState.value;
                return _buildDailyStateCard(primary);
              }),
              // 旧的"推荐行"已删除：hero CTA 的 rationale 已经覆盖同样信息
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('我的学习计划',
                      style: TextStyle(fontSize: 17.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D2D2D))),
                  TextButton.icon(
                    onPressed: _showCreateSheet,
                    icon: Icon(Icons.add, size: 15.sp),
                    label: Text('新建', style: TextStyle(fontSize: 13.sp)),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              if (_userPlans.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: Center(child: Column(children: [
                    Icon(Icons.add_task_outlined,
                        size: 32.sp, color: Colors.grey[300]),
                    SizedBox(height: 8.h),
                    Text('还没有计划，点击下方创建',
                        style: TextStyle(fontSize: 13.sp,
                            color: Colors.grey[400])),
                  ])),
                )
              else
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: _onReorder,
                  proxyDecorator: (child, _, __) =>
                      Material(color: Colors.transparent,
                          elevation: 8, child: child),
                  children: _sortedPlans.asMap().entries.map((e) {
                    final id = e.value['id'] as String;
                    // 找到该计划在原始 _userPlans 里的真实索引（操作需要用真实索引）
                    final realIdx =
                        _userPlans.indexWhere((p) => p['id'] == id);
                    return _PlanCard(
                      key: ValueKey(id),
                      plan: e.value,
                      primary: primary,
                      isExpanded: _expandedIds.contains(id),
                      listIndex: e.key,
                      isLowStateToday: _isLowStateToday,
                      isMustDo: id == _mustDoPlanId,
                      onCompleteDay: () => _completeToday(realIdx),
                      onToggleTask: (tid) => _toggleTask(realIdx, tid),
                      onToggleExpand: () => _toggleExpand(id),
                      onEdit: () => _editPlan(e.value, realIdx),
                      onDelete: () {
                        // 如果删的是必保 plan，清掉必保
                        if (id == _mustDoPlanId) _setMustDoPlan(null);
                        setState(() => _userPlans.removeAt(realIdx));
                        _savePlans();
                      },
                      onToggleMustDo: () => _toggleMustDo(id),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
      bottomSheet: _buildBottomBar(primary),
    );
  }

  Widget _buildBottomBar(Color primary) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: TapScale(
          onTap: _showCreateSheet,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 14.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [primary, primary.withOpacity(0.75)]),
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [BoxShadow(
                  color: primary.withOpacity(0.28),
                  blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_circle_outline, color: Colors.white, size: 18.sp),
              SizedBox(width: 8.w),
              Text('创建学习计划', style: TextStyle(
                  color: Colors.white, fontSize: 15.sp,
                  fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }

  void _useSamplePlan(Map<String, dynamic> sample) {
    _showPlanEditor(
        titleCtrl: TextEditingController(text: sample['title'] as String),
        contentCtrl: TextEditingController(text: sample['content'] as String),
        duration: (sample['duration'] ?? 30) as int,
        isSample: true);
  }

  void _editPlan(Map<String, dynamic> plan, int index) {
    final tasks = plan['dailyTasks'] as List? ?? [];
    final tasksText = tasks.map((t) => (t as Map)['text']).join('\n');
    _showPlanEditor(
        titleCtrl: TextEditingController(text: plan['title'] as String? ?? ''),
        contentCtrl: TextEditingController(text: plan['content'] as String? ?? ''),
        tasksCtrl: TextEditingController(text: tasksText),
        duration: ((plan['duration'] ?? 30) as num).toInt(),
        existingIndex: index);
  }

  void _showCreateSheet() {
    _showPlanEditor(
        titleCtrl: TextEditingController(),
        contentCtrl: TextEditingController());
  }

  void _showPlanEditor({
    required TextEditingController titleCtrl,
    required TextEditingController contentCtrl,
    TextEditingController? tasksCtrl,
    int? existingIndex,
    bool isSample = false,
    int duration = 30,
  }) {
    final primary = Theme.of(Get.context!).primaryColor;
    int dur = duration;
    final tCtrl = tasksCtrl ?? TextEditingController();

    Get.bottomSheet(
      StatefulBuilder(builder: (ctx, setLS) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.82,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 38.w, height: 4.h,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.r)),
              )),
              SizedBox(height: 16.h),
              Row(children: [
                Text(
                  isSample ? '复用计划' : (existingIndex != null ? '编辑计划' : '新建学习计划'),
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TapScale(
                  onTap: () { Get.back(); Get.toNamed('/create-plan'); },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(children: [
                      Icon(Icons.auto_awesome, size: 14.sp, color: primary),
                      SizedBox(width: 4.w),
                      Text('AI 帮我写',
                          style: TextStyle(fontSize: 12.sp, color: primary)),
                    ]),
                  ),
                ),
              ]),
              SizedBox(height: 12.h),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  hintText: '计划标题（如：考研数学60天）',
                  filled: true, fillColor: const Color(0xFFF7F7FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w, vertical: 12.h),
                ),
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8.h),
              // 天数
              Row(children: [
                Text('总天数：',
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[600])),
                ...([7, 21, 30, 60, 90]).map((d) => TapScale(
                  onTap: () => setLS(() => dur = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: dur == d ? primary.withOpacity(0.12) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: dur == d ? primary : Colors.grey.shade300,
                        width: dur == d ? 1.5 : 1),
                    ),
                    child: Text('$d',
                        style: TextStyle(fontSize: 12.sp,
                            color: dur == d ? primary : Colors.grey[600],
                            fontWeight: dur == d ? FontWeight.w600 : FontWeight.normal)),
                  ),
                )),
              ]),
              SizedBox(height: 8.h),
              // 每日任务
              Text('今日小任务（每行一项，逐个完成更有成就感）',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[500])),
              SizedBox(height: 4.h),
              SizedBox(
                height: 90.h,
                child: TextField(
                  controller: tCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: '背20个单词\n精读一篇阅读\n整理错题笔记',
                    filled: true, fillColor: const Color(0xFFF7F7FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.all(12.w),
                  ),
                  style: TextStyle(fontSize: 13.sp, height: 1.6),
                ),
              ),
              SizedBox(height: 8.h),
              // 计划描述
              Expanded(
                child: TextField(
                  controller: contentCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: '计划总体安排（阶段目标、方法等，可选填）',
                    filled: true, fillColor: const Color(0xFFF7F7FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.all(12.w),
                  ),
                  style: TextStyle(fontSize: 13.sp, height: 1.6),
                ),
              ),
              SizedBox(height: 12.h),
              TapScale(
                onTap: () {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) {
                    Get.snackbar('提示', '请填写计划标题',
                        snackPosition: SnackPosition.TOP);
                    return;
                  }
                  // 解析小任务
                  final taskLines = tCtrl.text
                      .split('\n')
                      .map((l) => l.trim())
                      .where((l) => l.isNotEmpty)
                      .toList();
                  final now = DateTime.now();
                  final taskId = existingIndex != null
                      ? _userPlans[existingIndex]['id'] as String
                      : now.millisecondsSinceEpoch.toString();
                  final dailyTasks = taskLines.asMap().entries.map((e) => {
                    'id': '${taskId}_t${e.key}',
                    'text': e.value,
                    'done': false,
                  }).toList();
                  final entry = {
                    'id': taskId,
                    'title': title,
                    'content': contentCtrl.text.trim(),
                    'duration': dur,
                    'dailyTasks': dailyTasks,
                    'completedDays': existingIndex != null
                        ? _userPlans[existingIndex]['completedDays'] ?? 0 : 0,
                    'todayDone': existingIndex != null
                        ? _userPlans[existingIndex]['todayDone'] ?? false : false,
                    'lastCompletedDate': existingIndex != null
                        ? _userPlans[existingIndex]['lastCompletedDate'] ?? '' : '',
                    'streak': existingIndex != null
                        ? _userPlans[existingIndex]['streak'] ?? 0 : 0,
                    'progress': existingIndex != null
                        ? _userPlans[existingIndex]['progress'] ?? 0 : 0,
                    'status': '进行中',
                    'createdAt': now.toIso8601String(),
                  };
                  Get.back();
                  setState(() {
                    if (existingIndex != null) {
                      _userPlans[existingIndex] = entry;
                    } else {
                      _userPlans.insert(0, entry);
                    }
                  });
                  _savePlans();
                  Get.snackbar('✅ 已保存', '计划已添加',
                      snackPosition: SnackPosition.TOP,
                      duration: const Duration(seconds: 2));
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [primary, primary.withOpacity(0.75)]),
                    borderRadius: BorderRadius.circular(14.r),
                    boxShadow: [BoxShadow(
                        color: primary.withOpacity(0.28),
                        blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Center(child: Text('保存计划',
                      style: TextStyle(color: Colors.white, fontSize: 15.sp,
                          fontWeight: FontWeight.w600))),
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        );
      }),
      isScrollControlled: true,
    );
  }
}
