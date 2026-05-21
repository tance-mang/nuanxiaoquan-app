// ============================================================
// 学习强度引擎 —— 暖小圈系统设计·核心闭环
//
// 公式：
//   score = stateCoef × energyCoef × behaviorCoef
//
// 输入（全部从 SharedPreferences 实时读取，无副作用）：
//   - daily_state_<YYYY-MM-DD>     精力 + condition
//   - focus_seconds_<YYYY-MM-DD>   今日是否已经开始学习
//   - interrupts_<YYYY-MM-DD>      今日中断次数
//
// 输出 modes：
//   - light    score < 0.6   → 20-30 分钟（复习/简单任务）
//   - standard 0.6 ≤ s ≤ 0.85 → 45 分钟（分段学习）
//   - sprint   score > 0.85   → 60-90 分钟（深度专注）
//
// 设计原则：默认自动，用户不必关心数学，看到的是"轻启动/标准/冲刺"和推荐时长。
// ============================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'cycle_phase_knowledge.dart';

enum StrengthMode { light, standard, sprint, restDay, free }

class StrengthRecommendation {
  final double score;        // 0..1+
  final StrengthMode mode;
  final int recommendedMinutes;
  final String stateLevel;   // 'good' | 'normal' | 'bad'
  final bool lowEnergy;
  /// 微调量（分钟，可正可负）—— 显示给用户看，用于"稍微加一点 / 更轻一点"
  final int manualAdjust;
  /// 一句话解释推荐理由（用于首页 hero CTA）
  final String rationale;

  /// 当前生理期阶段（'menstrual'/'follicular'/'ovulation'/'luteal'/'pms'）
  /// 没记录或未启用暖圈关怀时为 null —— UI 应判 null 跳过
  final String? phase;

  /// 怎么开始学习的一条具体建议（来自 cycle_phase_knowledge）
  /// 仅当 phase 非 null 时有内容；用于首页 CTA 的"今天怎么开始"小提示
  final String? kickStartHint;

  const StrengthRecommendation({
    required this.score,
    required this.mode,
    required this.recommendedMinutes,
    required this.stateLevel,
    required this.lowEnergy,
    required this.rationale,
    this.manualAdjust = 0,
    this.phase,
    this.kickStartHint,
  });

  String get modeLabel {
    switch (mode) {
      case StrengthMode.light:    return '轻启动模式';
      case StrengthMode.standard: return '标准模式';
      case StrengthMode.sprint:   return '冲刺模式';
      case StrengthMode.restDay:  return '今天休息';
      case StrengthMode.free:     return '自由模式';
    }
  }

  String get modeShortLabel {
    switch (mode) {
      case StrengthMode.light:    return '轻启动';
      case StrengthMode.standard: return '标准';
      case StrengthMode.sprint:   return '冲刺';
      case StrengthMode.restDay:  return '休息';
      case StrengthMode.free:     return '自由';
    }
  }

  String get modeDescription {
    switch (mode) {
      case StrengthMode.light:    return '$recommendedMinutes 分钟 · 复习或简单任务';
      case StrengthMode.standard: return '$recommendedMinutes 分钟 · 分段学习';
      case StrengthMode.sprint:   return '$recommendedMinutes 分钟 · 深度专注';
      case StrengthMode.restDay:  return '今天先不学，给身体一点空间';
      case StrengthMode.free:     return '你来决定时长，引擎不干涉';
    }
  }

  /// 色调：light=暖橘 / standard=蓝 / sprint=绿 / restDay=紫灰 / free=中性灰
  int get tintHex {
    switch (mode) {
      case StrengthMode.light:    return 0xFFE08A6E;
      case StrengthMode.standard: return 0xFF6FA8FF;
      case StrengthMode.sprint:   return 0xFF6CB87C;
      case StrengthMode.restDay:  return 0xFFB48FD2;
      case StrengthMode.free:     return 0xFF6B7280;
    }
  }
}

class StrengthEngine {
  /// 读取今日状态 + 行为，计算推荐强度
  static Future<StrengthRecommendation> compute() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // ── 特殊覆盖优先级最高 ───────────────────────────────
    // override_<date> 可能是 'no_study' / 'free'，否则按引擎正常计算
    final override = prefs.getString('override_$today');
    if (override == 'no_study') {
      return const StrengthRecommendation(
        score: 0,
        mode: StrengthMode.restDay,
        recommendedMinutes: 0,
        stateLevel: 'bad',
        lowEnergy: true,
        rationale: '今天你选了休息，明天再聊',
      );
    }
    if (override == 'free') {
      return const StrengthRecommendation(
        score: 0.5,
        mode: StrengthMode.free,
        recommendedMinutes: 30,
        stateLevel: 'normal',
        lowEnergy: false,
        rationale: '自由模式：时长由你定',
      );
    }

    // ── 1. 今日状态 ──────────────────────────────────────
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

    // 状态级别 + 系数（按规约："good 1.0 / normal 0.8 / bad 0.5"）
    String stateLevel;
    double stateCoef;
    final negCond = condition == '焦虑' ||
        condition == '痛经不适' ||
        condition == '有点累';
    if (condition == '精力很好' || (energy >= 7 && !negCond)) {
      stateLevel = 'good';
      stateCoef = 1.0;
    } else if (energy <= 4 || negCond) {
      stateLevel = 'bad';
      stateCoef = 0.5;
    } else {
      stateLevel = 'normal';
      stateCoef = 0.8;
    }

    // ── 2. 能量系数 ──────────────────────────────────────
    // 痛经不适或自评累 → low-energy
    final lowEnergy = condition == '痛经不适' || condition == '有点累';
    final energyCoef = lowEnergy ? 0.6 : 1.0;

    // ── 3. 行为系数 ──────────────────────────────────────
    final focusSec = prefs.getInt('focus_seconds_$today') ?? 0;
    final started = focusSec >= 60; // 至少专注 60 秒算"已开始"
    final interrupts = prefs.getInt('interrupts_$today') ?? 0;
    final startCoef = started ? 1.0 : 0.7;
    final interruptCoef = interrupts >= 2 ? 0.7 : (interrupts == 1 ? 0.9 : 1.0);
    final behaviorCoef = startCoef * interruptCoef;

    // ── 综合 score（先按精力/行为/能量算一遍）────────────
    double score = stateCoef * energyCoef * behaviorCoef;

    // ── 生理期阶段微调（可选层；无记录时跳过，不影响旧逻辑）─
    // 经期 / 经前期 → 系数 0.80，趋向轻启动
    // 排卵期        → 系数 1.10，可上探到冲刺
    // 卵泡 / 黄体   → 不变
    final phase = await CyclePhaseKnowledge.inferCurrentPhase();
    if (phase == 'menstrual' || phase == 'pms') {
      score *= 0.80;
    } else if (phase == 'ovulation') {
      score *= 1.10;
    }

    // ── 输出 mode + 时长 ─────────────────────────────────
    StrengthMode mode;
    int baseMin;
    if (score < 0.6) {
      mode = StrengthMode.light;
      baseMin = 25; // 20-30 取中
    } else if (score <= 0.85) {
      mode = StrengthMode.standard;
      baseMin = 45;
    } else {
      mode = StrengthMode.sprint;
      baseMin = 60; // 60-90 起步
    }

    // ── 用户微调（"稍微加一点 / 更轻一点"）─────────────
    final manualAdjust = prefs.getInt('manual_adjust_$today') ?? 0;
    final minutes = (baseMin + manualAdjust).clamp(10, 120);

    // ── 一句话推荐理由 ──────────────────────────────────
    String rationale;
    if (mode == StrengthMode.light && lowEnergy) {
      rationale = '今天能量偏低，先轻量打卡就好';
    } else if (mode == StrengthMode.light) {
      rationale = '状态一般，先来个短的暖身';
    } else if (mode == StrengthMode.standard) {
      rationale = '状态可以，标准节奏稳稳推进';
    } else {
      rationale = '状态不错，今天可以深度专注';
    }

    // 生理期阶段补一句解释（如果有阶段且没被强引导覆盖）
    final phaseKnowledge = CyclePhaseKnowledge.of(phase);
    if (phaseKnowledge != null) {
      if (phase == 'menstrual') {
        rationale += '·经期，强度自动降一档';
      } else if (phase == 'pms') {
        rationale += '·经前期，建议轻量推进';
      } else if (phase == 'ovulation') {
        rationale += '·排卵期，体能在线';
      } else if (phase == 'follicular') {
        rationale += '·卵泡期，攻坚窗口';
      } else if (phase == 'luteal') {
        rationale += '·黄体期，按计划稳推';
      }
    }

    if (manualAdjust > 0) rationale += '（你加了 $manualAdjust 分钟）';
    if (manualAdjust < 0) rationale += '（你减了 ${-manualAdjust} 分钟）';

    // 取该阶段的第一条 kickstart 提示（如果有）
    final kickStartHint = phaseKnowledge != null && phaseKnowledge.kickStartHints.isNotEmpty
        ? phaseKnowledge.kickStartHints.first
        : null;

    return StrengthRecommendation(
      score: score,
      mode: mode,
      recommendedMinutes: minutes,
      stateLevel: stateLevel,
      lowEnergy: lowEnergy,
      manualAdjust: manualAdjust,
      rationale: rationale,
      phase: phase,
      kickStartHint: kickStartHint,
    );
  }

  // ── 持久化辅助 ─────────────────────────────────────────

  /// 微调今日推荐时长（正数 = 加分钟，负数 = 减分钟）
  static Future<void> applyManualAdjust(int delta) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final key = 'manual_adjust_$today';
    final cur = prefs.getInt(key) ?? 0;
    final next = (cur + delta).clamp(-30, 60);
    await prefs.setInt(key, next);
    logEvent('manual_adjust', {'delta': delta, 'total': next});
  }

  /// 清零今日微调
  static Future<void> clearManualAdjust() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.remove('manual_adjust_$today');
  }

  /// 设置今日特殊覆盖（'no_study' / 'free' / null=取消）
  static Future<void> setOverride(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final key = 'override_$today';
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
    logEvent('override', {'value': value});
  }

  /// 重置今日状态（删除 daily_state，让用户重新评估）
  static Future<void> resetTodayState() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.remove('daily_state_$today');
    await prefs.remove('manual_adjust_$today');
    await prefs.remove('override_$today');
    logEvent('reset_state', {});
  }

  /// 记录一次中断（在 _persistInterrupt 之前用户切回来 / 暂停时调用）
  static Future<void> recordInterrupt() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final key = 'interrupts_$today';
    final cur = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, cur + 1);
    logEvent('interrupt', {'totalToday': cur + 1});
  }

  /// 记录一次学习结束反馈（轻松/一般/有点难）
  /// 用于下次系统调整 + 行为日志
  static Future<void> recordFeedback(String feedback) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final key = 'feedback_$today';
    // 多次完成会覆盖最新一次
    await prefs.setString(key, feedback);
    logEvent('feedback', {'value': feedback});
  }

  // ── 行为日志（统一存到 'behavior_log' 滚动 JSON 数组，保留最近 200 条）──
  static const _logKey = 'behavior_log';
  static const _logMaxEntries = 200;

  /// 追加一条结构化行为事件
  /// 用作"系统闭环"的可分析数据源
  static Future<void> logEvent(
      String type, Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_logKey);
      List<dynamic> list;
      if (raw == null) {
        list = [];
      } else {
        list = jsonDecode(raw) as List<dynamic>;
      }
      list.add({
        'at': DateTime.now().toIso8601String(),
        'type': type,
        'payload': payload,
      });
      if (list.length > _logMaxEntries) {
        list = list.sublist(list.length - _logMaxEntries);
      }
      await prefs.setString(_logKey, jsonEncode(list));
    } catch (_) {
      // 行为日志失败不影响主流程
    }
  }

  /// 读取所有日志（最近 N 条 reversed = 倒序，新→旧）
  static Future<List<Map<String, dynamic>>> readLog({int? limit}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_logKey);
      if (raw == null) return [];
      final list = (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList()
          .reversed
          .toList();
      if (limit != null && list.length > limit) {
        return list.sublist(0, limit);
      }
      return list;
    } catch (_) {
      return [];
    }
  }
}
