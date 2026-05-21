// ============================================================
// 首页 Hero CTA —— 暖小圈核心闭环的入口
//
// 显示：今日状态等级 + 系统推荐模式 + 大按钮"开始学习"
//      + 微调（就这样 / 稍微加 / 更轻）+ 更多（休息/自由/重置/引导风格）
//
// 引导风格 (guidancePreference)：
//   autonomous → 文案弱化（按钮"开始"），不主推 rationale
//   light      → 默认；显示完整 rationale + 微调
//   strong     → 文案最主动（按钮"立即开始"），自动应用引擎时长
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../services/strength_engine.dart';
import '../screens/study_room_screen.dart';

class StartStudyCta extends StatefulWidget {
  const StartStudyCta({Key? key}) : super(key: key);

  @override
  State<StartStudyCta> createState() => _StartStudyCtaState();
}

class _StartStudyCtaState extends State<StartStudyCta> {
  StrengthRecommendation? _rec;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await StrengthEngine.compute();
    if (!mounted) return;
    setState(() => _rec = r);
  }

  void _start() {
    final r = _rec;
    if (r == null) return;
    // restDay 直接拦截 —— 不进自习室
    if (r.mode == StrengthMode.restDay) {
      Get.snackbar('今天休息', '明天再聊吧 🌙',
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFFEDE7F6),
          colorText: const Color(0xFF4527A0),
          duration: const Duration(seconds: 2));
      return;
    }
    // 把推荐时长写入 lobby 计时器
    try {
      final ctrl = Get.find<StudyRoomController>(
          tag: StudyRoomController.lobbyTag);
      ctrl.setDuration(r.recommendedMinutes * 60);
    } catch (_) {}
    Get.toNamed('/main', arguments: {'tab': 1});
  }

  String _stateChineseLabel(String level) {
    switch (level) {
      case 'good':   return '状态不错';
      case 'normal': return '状态一般';
      case 'bad':    return '状态偏低';
      default:       return '状态待评估';
    }
  }

  String _startButtonText(String guidancePref, StrengthMode mode) {
    if (mode == StrengthMode.restDay) return '查看明天建议';
    if (mode == StrengthMode.free) return '开始（自定义时长）';
    switch (guidancePref) {
      case 'autonomous': return '开始';
      case 'strong':     return '立即开始';
      default:           return '开始学习';
    }
  }

  Future<void> _adjust(int deltaMin) async {
    await StrengthEngine.applyManualAdjust(deltaMin);
    _load();
  }

  Future<void> _openMoreMenu() async {
    final r = _rec;
    if (r == null) return;
    await showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) => _MoreSheet(
        currentMode: r.mode,
        onSelect: (action) async {
          Navigator.of(ctx).pop();
          switch (action) {
            case 'edit_state':
              // 触发首页状态输入卡展开
              Get.find<AppController>().requestEditState();
              return;
            case 'rest':
              await StrengthEngine.setOverride('no_study');
              break;
            case 'free':
              await StrengthEngine.setOverride('free');
              break;
            case 'reset':
              await StrengthEngine.resetTodayState();
              break;
            case 'cancel_override':
              await StrengthEngine.setOverride(null);
              break;
            case 'guidance':
              _openGuidanceSheet();
              return;
          }
          _load();
        },
      ),
    );
  }

  Future<void> _openGuidanceSheet() async {
    final ac = Get.find<AppController>();
    final current = ac.guidancePreference.value;
    await showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) => _GuidanceSheet(
        current: current,
        onPick: (p) async {
          await ac.setGuidancePreference(p);
          Navigator.of(ctx).pop();
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _rec;
    if (r == null) {
      return Container(
        margin: EdgeInsets.only(bottom: 16.h),
        height: 130.h,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: const Center(
            child: SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    final tint = Color(r.tintHex);
    final ac = Get.find<AppController>();
    return Obx(() {
      final guidancePref = ac.guidancePreference.value;
      final hideRationale = guidancePref == 'autonomous';
      return Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 12.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [tint.withOpacity(0.14), tint.withOpacity(0.04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: tint.withOpacity(0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶行：状态 chip + lowEnergy + 更多按钮
            Row(
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: tint.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    '今天 · ${_stateChineseLabel(r.stateLevel)}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: tint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                if (r.lowEnergy)
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      '能量偏低',
                      style: TextStyle(
                          fontSize: 10.sp, color: Colors.grey[600]),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: _openMoreMenu,
                  child: Padding(
                    padding: EdgeInsets.all(4.w),
                    child: Icon(Icons.more_horiz_rounded,
                        size: 18.sp, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            // 模式标题 + 描述
            Text(
              r.modeLabel,
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111827),
                height: 1.2,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              r.modeDescription,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            if (!hideRationale) ...[
              SizedBox(height: 6.h),
              Text(
                r.rationale,
                style: TextStyle(
                  fontSize: 11.5.sp,
                  color: tint,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // 生理期阶段补一句"今天怎么开始"——只在有阶段数据时显示
              if (r.kickStartHint != null) ...[
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          size: 13.sp, color: tint),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          r.kickStartHint!,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey[700],
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            SizedBox(height: 12.h),
            // 大按钮 + 微调
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _start,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 13.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [tint, tint.withOpacity(0.85)],
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                    boxShadow: [
                      BoxShadow(
                        color: tint.withOpacity(0.32),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        r.mode == StrengthMode.restDay
                            ? Icons.bedtime_outlined
                            : Icons.play_arrow_rounded,
                        size: 22.sp,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        _startButtonText(guidancePref, r.mode),
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 微调按钮（restDay/free 隐藏，因为不适用）
            if (r.mode != StrengthMode.restDay &&
                r.mode != StrengthMode.free) ...[
              SizedBox(height: 8.h),
              Row(
                children: [
                  _MicroAdjustChip(
                    label: '今天更轻',
                    delta: -10,
                    selected: r.manualAdjust < 0,
                    onTap: () => _adjust(-5),
                  ),
                  SizedBox(width: 6.w),
                  _MicroAdjustChip(
                    label: '就这样',
                    delta: 0,
                    selected: r.manualAdjust == 0,
                    onTap: () async {
                      await StrengthEngine.clearManualAdjust();
                      _load();
                    },
                  ),
                  SizedBox(width: 6.w),
                  _MicroAdjustChip(
                    label: '稍微加一点',
                    delta: 5,
                    selected: r.manualAdjust > 0,
                    onTap: () => _adjust(5),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────
// 微调小 chip：今天更轻 / 就这样 / 稍微加一点
// ─────────────────────────────────────────────────────────────
class _MicroAdjustChip extends StatelessWidget {
  final String label;
  final int delta;
  final bool selected;
  final VoidCallback onTap;
  const _MicroAdjustChip({
    required this.label,
    required this.delta,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: 7.h),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: selected
                  ? const Color(0xFF111827).withOpacity(0.20)
                  : Colors.grey.withOpacity(0.25),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? const Color(0xFF111827)
                    : Colors.grey[600],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 更多选项 bottom sheet：今天不学 / 自由模式 / 重置今日 / 引导风格
// ─────────────────────────────────────────────────────────────
class _MoreSheet extends StatelessWidget {
  final StrengthMode currentMode;
  final void Function(String action) onSelect;
  const _MoreSheet({required this.currentMode, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final inOverride =
        currentMode == StrengthMode.restDay || currentMode == StrengthMode.free;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 拖动条
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
              '更多选项',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
            SizedBox(height: 10.h),
            // 调整今日状态 —— 放最上面，最常用
            _row(Icons.tune_outlined, '调整今日状态',
                '改一下精力 / 不适标签', () => onSelect('edit_state'),
                tint: const Color(0xFFE08A6E)),
            Divider(height: 24.h, color: Colors.grey.shade100),
            if (!inOverride) ...[
              _row(Icons.bedtime_outlined, '今天不学习',
                  '让今天彻底休息，明天再聊', () => onSelect('rest'),
                  tint: const Color(0xFFB48FD2)),
              _row(Icons.tune, '自由模式',
                  '引擎不干涉，你自己挑时长', () => onSelect('free'),
                  tint: const Color(0xFF6B7280)),
            ] else
              _row(Icons.undo, '回到引擎推荐',
                  '撤销今天的特殊覆盖', () => onSelect('cancel_override'),
                  tint: const Color(0xFF6CB87C)),
            _row(Icons.restart_alt, '重置今日状态',
                '清掉今日状态/微调/覆盖，重新评估', () => onSelect('reset'),
                tint: const Color(0xFFE08A6E)),
            Divider(height: 24.h, color: Colors.grey.shade100),
            _row(Icons.psychology_outlined, '引导风格',
                '让小暖更主动 / 更克制', () => onSelect('guidance'),
                tint: const Color(0xFF6FA8FF)),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String title, String desc, VoidCallback onTap,
      {required Color tint}) {
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
                        color: const Color(0xFF111827),
                      )),
                  SizedBox(height: 2.h),
                  Text(desc,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[500],
                      )),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18.sp, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 引导风格 bottom sheet：自主 / 轻引导 / 强引导
// ─────────────────────────────────────────────────────────────
class _GuidanceSheet extends StatelessWidget {
  final String current;
  final void Function(String value) onPick;
  const _GuidanceSheet({required this.current, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final options = const [
      {
        'value': 'autonomous',
        'title': '自主型',
        'desc': '我自己安排，引擎建议看看就好',
        'icon': Icons.self_improvement,
      },
      {
        'value': 'light',
        'title': '轻引导（默认）',
        'desc': '引擎给推荐和理由，由我决定是否采纳',
        'icon': Icons.handshake_outlined,
      },
      {
        'value': 'strong',
        'title': '强引导',
        'desc': '引擎推什么我就做什么，少思考',
        'icon': Icons.flag_outlined,
      },
    ];
    return SafeArea(
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
              '选个引导风格',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '决定小暖建议你的力度，可随时改',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
            ),
            SizedBox(height: 12.h),
            ...options.map((o) {
              final v = o['value'] as String;
              final isCur = current == v;
              return InkWell(
                onTap: () => onPick(v),
                borderRadius: BorderRadius.circular(12.r),
                child: Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: isCur
                        ? const Color(0xFF6FA8FF).withOpacity(0.10)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isCur
                          ? const Color(0xFF6FA8FF).withOpacity(0.50)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(o['icon'] as IconData,
                          size: 18.sp,
                          color: isCur
                              ? const Color(0xFF1D4ED8)
                              : Colors.grey[500]),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o['title'] as String,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              o['desc'] as String,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isCur)
                        Icon(Icons.check_circle,
                            size: 18.sp,
                            color: const Color(0xFF1D4ED8)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
