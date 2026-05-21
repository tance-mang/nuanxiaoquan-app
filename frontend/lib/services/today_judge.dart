// ============================================================
// 今日综合判定（C 类规则起步 · 第二砖）
//
// 输入：今日状态（精力 + 不适标签）+ 暖圈关怀周期阶段 + 用户选定专注时长
// 输出：一句温和的中文提示（或 null = 不打扰）
//
// 规则按优先级从上到下匹配，第一个命中即返回。
// 不替用户做决定，不弹窗，仅作为视觉提示出现在计时器附近。
//
// 数据来源：
//   - daily_state_<YYYY-MM-DD>     （HomeScreen 写入）
//   - warmcare_cycles              （WarmCareScreen 写入，list of ISO 日期字符串）
//   - userGender                   （只对 female 计算周期相关规则）
// ============================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class JudgeHint {
  final String text;
  /// 0 = 轻量提醒（暖橘）, 1 = 状态好可上量（绿）, 2 = 周期相关（粉紫）
  final int kind;
  const JudgeHint(this.text, this.kind);
}

class TodayJudge {
  /// 计算当前应当显示的提示
  /// [durationSec] 用户当前选定的专注秒数（25*60 / 30*60 / 45*60 / 60*60）
  static Future<JudgeHint?> compute({
    int durationSec = 1500,
    String userGender = 'unknown',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // ── 今日状态 ────────────────────────────────────────────
    int energy = 6;
    String? condition;
    final stateRaw = prefs.getString('daily_state_$today');
    if (stateRaw != null) {
      try {
        final m = jsonDecode(stateRaw) as Map<String, dynamic>;
        energy = (m['energy'] as int?) ?? 6;
        condition = m['condition'] as String?;
      } catch (_) {}
    }

    // ── 周期阶段（仅女性用户计算）───────────────────────────
    String phase = 'unknown';
    if (userGender == 'female') {
      final cycles = prefs.getStringList('warmcare_cycles') ?? [];
      phase = _computePhase(cycles);
    }

    return _evaluate(energy, condition, phase, (durationSec / 60).round());
  }

  /// 从经期开始日列表推断当前阶段（与 WarmCareScreen 算法对齐）
  static String _computePhase(List<String> cycleDates) {
    if (cycleDates.isEmpty) return 'unknown';
    DateTime? lastStart;
    for (final s in cycleDates) {
      try {
        final d = DateTime.parse(s);
        if (lastStart == null || d.isAfter(lastStart)) lastStart = d;
      } catch (_) {}
    }
    if (lastStart == null) return 'unknown';
    const cycleLen = 28;
    const flowDuration = 5;
    final today = DateTime.now();
    final dayInCycle = today.difference(lastStart).inDays + 1;
    if (dayInCycle <= 0 || dayInCycle > cycleLen) return 'unknown';
    if (dayInCycle <= flowDuration) return 'menstrual';
    if (dayInCycle <= 13) return 'follicular';
    if (dayInCycle <= 16) return 'ovulation';
    if (dayInCycle >= cycleLen - 3) return 'pms';
    return 'luteal';
  }

  static JudgeHint? _evaluate(
    int energy,
    String? condition,
    String phase,
    int durMin,
  ) {
    final isLowMood = condition == '痛经不适' ||
        condition == '焦虑' ||
        condition == '有点累';

    // ── 优先级 1：明确的"今天不适合硬刚"信号 ──────────────────
    if (condition == '痛经不适' ||
        (phase == 'menstrual' && energy <= 5)) {
      return const JudgeHint(
          '🌿 今天身体在说"慢下来"，25 分钟基础打卡就好', 0);
    }
    if (energy <= 4 || condition == '焦虑') {
      // 长时长 + 状态差 → 建议短时长
      if (durMin >= 45) {
        return const JudgeHint('🌿 状态不太理想，今天选 25 或 30 分钟更容易完成', 0);
      }
      return const JudgeHint('🌿 先来个短的暖身打卡，做完再决定要不要继续', 0);
    }

    // ── 优先级 2：状态好 + 周期窗口期 → 鼓励上强度 ──────────
    if (phase == 'ovulation' && energy >= 7) {
      return const JudgeHint('✨ 状态巅峰期，今天可以挑战 45 或 60 分钟', 1);
    }
    if (energy >= 8 &&
        !isLowMood &&
        phase != 'menstrual' &&
        phase != 'pms') {
      return const JudgeHint('✨ 状态不错，稳稳上一节高效专注', 1);
    }

    // ── 优先级 3：周期阶段相关的温和提示 ─────────────────────
    if (phase == 'pms') {
      return const JudgeHint('💛 经前期容易起伏，对自己温柔点，30 分钟刚好', 2);
    }
    if (phase == 'luteal' && energy <= 6) {
      return const JudgeHint('💛 黄体期略疲，今天以复习巩固为主', 2);
    }

    return null; // 中性状态，不打扰
  }
}
