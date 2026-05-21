// ============================================================
// 文件：services/proactive_companion.dart
// 作用：小暖的"主动观察 + 主动开口"服务（本地规则，零 API 成本）
//
// 设计原则（人设 = INTP-A 水瓶座，傲娇而非可爱）：
//   - 克制：能不说话就不说话；说话短，不啰嗦
//   - 不讨好：不"加油"不"棒棒"不"哦"不"啦"
//   - 傲娇而非可爱：熟悉了之后允许"又是你""我都不用问"，但骨子里仍然是
//     "我观察到 X" 的视角，绝不卖萌
//   - 不会装可怜不示弱不撒娇
//
// 触发场景：
//   1) 每日首次打开（按北京时间 0:00 起算）  → dailyOpener()
//   2) 切换到某个页面/Tab                  → contextMessage(routeKey)
//   3) 用户完成一段番茄/中断/收藏/记账等   → eventMessage(eventName)
//   4) 早 07:30 / 晚 21:30 系统推送        → morningPush() / eveningPush()
//
// 频次保护（全局上限）：
//   - 每日首次问候：每天 1 次
//   - 每个 Tab 冒泡：每天每 Tab 1 次
//   - 事件冒泡（番茄钟等）：每事件类型每天 1 次
//   - 全天总冒泡上限：5 次
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';
import 'cycle_phase_knowledge.dart';

/// 用户与小暖的熟悉度阶段
enum Familiarity {
  /// 1-7 天：陌生期，最克制，统一用"你"
  stranger,

  /// 8-30 天：渐熟期，措辞松一点，开始有边界感的关注
  acquainted,

  /// 31-90 天：常客期，傲娇登场（"又是你""按你的老规矩"）
  regular,

  /// 90+ 天：默契期，可以"我都不用问就知道你今天怎么了"
  kin,
}

class ProactiveCompanion {
  // ─── 北京时间工具 ───────────────────────────────────────────

  static String _beijingDayKey() {
    final bj = DateTime.now().toUtc().add(const Duration(hours: 8));
    return '${bj.year.toString().padLeft(4, '0')}-'
        '${bj.month.toString().padLeft(2, '0')}-'
        '${bj.day.toString().padLeft(2, '0')}';
  }

  static int _beijingHour() =>
      DateTime.now().toUtc().add(const Duration(hours: 8)).hour;

  static String _timeSegment() {
    final h = _beijingHour();
    if (h < 5) return 'midnight';
    if (h < 9) return 'morning';
    if (h < 12) return 'forenoon';
    if (h < 14) return 'noon';
    if (h < 18) return 'afternoon';
    if (h < 22) return 'evening';
    return 'night';
  }

  /// 时段问候语（按熟悉度切换语气）
  static String _timeGreeting(Familiarity f) {
    final seg = _timeSegment();
    if (f == Familiarity.stranger) {
      switch (seg) {
        case 'midnight':  return '凌晨了';
        case 'morning':   return '早上好';
        case 'forenoon':  return '上午好';
        case 'noon':      return '中午';
        case 'afternoon': return '下午好';
        case 'evening':   return '晚上好';
        case 'night':     return '夜深了';
      }
    }
    if (f == Familiarity.acquainted) {
      switch (seg) {
        case 'midnight':  return '又熬夜';
        case 'morning':   return '早';
        case 'forenoon':  return '上午';
        case 'noon':      return '吃了吗';
        case 'afternoon': return '下午';
        case 'evening':   return '晚上';
        case 'night':     return '该睡了';
      }
    }
    if (f == Familiarity.regular) {
      // 傲娇登场：知道你又来了，但不动声色
      switch (seg) {
        case 'midnight':  return '又是这个点';
        case 'morning':   return '来了';
        case 'forenoon':  return '又来了';
        case 'noon':      return '记得吃饭';
        case 'afternoon': return '下午这段你最容易走神';
        case 'evening':   return '又是你';
        case 'night':     return '别又拖到这个点';
      }
    }
    // kin：默契期
    switch (seg) {
      case 'midnight':  return '我都不用看时间就知道是你';
      case 'morning':   return '准时';
      case 'forenoon':  return '今天来得不算早';
      case 'noon':      return '又跳过午饭？算了';
      case 'afternoon': return '该来的时候来了';
      case 'evening':   return '今天看起来还行';
      case 'night':     return '又不睡';
    }
    return '';
  }

  // ─── 熟悉度 ──────────────────────────────────────────────────

  static const _kActiveDays = 'companion_active_days';
  static const _kActiveDaysLastBumped = 'companion_active_days_last_bumped';

  /// 每天首次调用时 +1，返回最新活跃天数（北京时间分日）
  static Future<int> _bumpAndGetActiveDays() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _beijingDayKey();
    final last = prefs.getString(_kActiveDaysLastBumped) ?? '';
    int days = prefs.getInt(_kActiveDays) ?? 0;
    if (last != today) {
      days += 1;
      await prefs.setInt(_kActiveDays, days);
      await prefs.setString(_kActiveDaysLastBumped, today);
    }
    return days;
  }

  /// 只读拿当前活跃天数（不递增）
  static Future<int> activeDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kActiveDays) ?? 0;
  }

  static Familiarity _familiarityFromDays(int days) {
    if (days <= 7) return Familiarity.stranger;
    if (days <= 30) return Familiarity.acquainted;
    if (days <= 90) return Familiarity.regular;
    return Familiarity.kin;
  }

  static Future<Familiarity> _familiarity() async =>
      _familiarityFromDays(await activeDays());

  // ─── 频次保护 ────────────────────────────────────────────────

  static const _kLastOpenerDay = 'companion_last_opener_day';
  static const _kBubbleCountPrefix = 'companion_bubble_count_';
  static const _kTabFiredPrefix = 'companion_tab_fired_';
  static const _kEventFiredPrefix = 'companion_event_fired_';
  static const _kDailyBubbleLimit = 5;

  static Future<bool> _canFireMore() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _beijingDayKey();
    final count = prefs.getInt('$_kBubbleCountPrefix$today') ?? 0;
    return count < _kDailyBubbleLimit;
  }

  static Future<void> _markFired() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _beijingDayKey();
    final count = prefs.getInt('$_kBubbleCountPrefix$today') ?? 0;
    await prefs.setInt('$_kBubbleCountPrefix$today', count + 1);
  }

  // ─── 1. 每日首次打开 ─────────────────────────────────────────

  static Future<String?> dailyOpener() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _beijingDayKey();
    final last = prefs.getString(_kLastOpenerDay) ?? '';
    if (last == today) return null;

    await prefs.setString(_kLastOpenerDay, today);
    await _markFired();

    final days = await _bumpAndGetActiveDays();
    final f = _familiarityFromDays(days);
    final greeting = _timeGreeting(f);
    final phase = await CyclePhaseKnowledge.inferCurrentPhase();
    final phaseHint = _phaseOpenerHint(phase, f);
    final behaviorHint = await _behaviorOpenerHint(f);

    final parts = <String>[greeting];
    if (phaseHint != null) parts.add(phaseHint);
    if (behaviorHint != null) parts.add(behaviorHint);
    return parts.where((s) => s.isNotEmpty).join('，') + '。';
  }

  static String? _phaseOpenerHint(String? phase, Familiarity f) {
    if (phase == null) return null;
    final isLate = f == Familiarity.regular || f == Familiarity.kin;
    switch (phase) {
      case 'menstrual':
        return isLate ? '经期，老规矩降一档' : '经期了，今天降一档强度';
      case 'pms':
        return isLate ? '经前你最容易冲动，警告过你了' : '经前两天容易烦，目标定低一点';
      case 'ovulation':
        return isLate ? '排卵期，你最能打的时候' : '排卵期，状态在线';
      case 'follicular':
        return isLate ? '卵泡期，别浪费' : '卵泡期，是攻坚的窗口';
      case 'luteal':
        return isLate ? '黄体期，稳就行' : '黄体期，按计划稳推就行';
      default:
        return null;
    }
  }

  static Future<String?> _behaviorOpenerHint(Familiarity f) async {
    final prefs = await SharedPreferences.getInstance();
    final localToday = DateTime.now().toIso8601String().substring(0, 10);
    final focus = prefs.getInt('focus_seconds_$localToday') ?? 0;
    final interrupts = prefs.getInt('interrupts_$localToday') ?? 0;

    if (focus == 0) {
      switch (f) {
        case Familiarity.stranger:
          return '今天还没开始，先来 20 分钟暖身';
        case Familiarity.acquainted:
          return '今天还没动，先来 20 分钟';
        case Familiarity.regular:
          return '又是没开始的一天，老套路：20 分钟先';
        case Familiarity.kin:
          return '不用看我都知道，你又拖了';
      }
    }
    if (interrupts >= 3) {
      switch (f) {
        case Familiarity.stranger:
        case Familiarity.acquainted:
          return '中断有点多，今天先专注一段就好';
        case Familiarity.regular:
          return '你最近老是断，自己心里有数';
        case Familiarity.kin:
          return '不说了，你自己看中断次数';
      }
    }
    return null;
  }

  // ─── 2. Tab 切换上下文 ───────────────────────────────────────

  /// tabKey: 'home' | 'study' | 'knowledge' | 'mine' | 'warmcare' | 'accounting'
  static Future<String?> contextMessage(String tabKey) async {
    if (!await _canFireMore()) return null;
    final prefs = await SharedPreferences.getInstance();
    final today = _beijingDayKey();
    final firedKey = '$_kTabFiredPrefix${today}_$tabKey';
    if (prefs.getBool(firedKey) ?? false) return null;

    final f = await _familiarity();
    final localToday = DateTime.now().toIso8601String().substring(0, 10);
    final focus = prefs.getInt('focus_seconds_$localToday') ?? 0;
    final phase = await CyclePhaseKnowledge.inferCurrentPhase();
    final seg = _timeSegment();

    final text = _pickTabText(tabKey, f, focus, phase, seg);
    if (text == null) return null;

    await prefs.setBool(firedKey, true);
    await _markFired();
    return text;
  }

  static String? _pickTabText(
    String tab,
    Familiarity f,
    int focus,
    String? phase,
    String seg,
  ) {
    final isLate = f == Familiarity.regular || f == Familiarity.kin;
    switch (tab) {
      case 'home':
        if (focus == 0 && (seg == 'morning' || seg == 'forenoon')) {
          return isLate ? '又是这套路，开始就行。' : '还没开始？先点开始学习，25 分钟就行。';
        }
        if (focus >= 60 * 90) {
          return isLate ? '行了，去喝水。' : '今天已经专注挺久了，别忘了喝水起身。';
        }
        if (phase == 'pms' || phase == 'menstrual') {
          return isLate
              ? '这几天，完成就行，少跟自己较劲。'
              : '这几天先把"完成"做到，"完美"留到下一阶段。';
        }
        return null;

      case 'study':
        if (focus == 0) {
          return isLate
              ? '别想了，错题集翻 5 分钟就有思路。'
              : '不知道学什么？先打开错题集翻 5 分钟，会有思路。';
        }
        return isLate ? '接着上次。' : '继续上一段的节奏。';

      case 'knowledge':
        if (phase == 'pms' || phase == 'menstrual') {
          return isLate ? '今天读两段就够，别加。' : '今天读两段就够了，别给自己加任务。';
        }
        if (phase == 'ovulation' || phase == 'follicular') {
          return isLate
              ? '状态好，挑一篇之前没读完的。'
              : '状态好，挑一篇之前一直没读完的。';
        }
        return isLate
            ? '搜你薄弱点，比逛着看强。'
            : '存知里搜你最近的薄弱点，比随便看更有用。';

      case 'mine':
        if (seg == 'evening' || seg == 'night') {
          return isLate ? '记一下今天的账。' : '记一笔今天的账吧，明天复盘会用上。';
        }
        return null;

      case 'warmcare':
        if (phase == 'pms') {
          return isLate
              ? '经前的"怎么开始学习"那一栏，再翻一遍。'
              : '经前期建议看下"怎么开始学习"那一栏，别硬冲。';
        }
        if (phase == 'menstrual') {
          return isLate ? '保暖，少熬。' : '经期注意保暖，别熬夜。';
        }
        return null;

      case 'accounting':
        if (phase == 'pms' || phase == 'menstrual') {
          return isLate
              ? '想买的，先放购物车 24 小时。'
              : '这几天想买的东西，建议先放购物车 24 小时再决定。';
        }
        return null;
    }
    return null;
  }

  // ─── 3. 事件触发（番茄钟/收藏/记账等）────────────────────────

  /// eventKey:
  ///   'pomodoro_done'           番茄钟一段完成
  ///   'pomodoro_interrupted'    番茄钟被中断
  ///   'resource_collected'      知识小馆收藏
  ///   'accounting_added'        新增一笔账
  ///   'accounting_over_budget'  本月超预算
  ///   'plan_created'            新建学习计划
  ///   'plan_completed'          完成一个计划
  ///   'period_logged'           新增经期记录
  static Future<String?> eventMessage(String eventKey) async {
    if (!await _canFireMore()) return null;
    final prefs = await SharedPreferences.getInstance();
    final today = _beijingDayKey();
    final firedKey = '$_kEventFiredPrefix${today}_$eventKey';
    if (prefs.getBool(firedKey) ?? false) return null;

    final f = await _familiarity();
    final isLate = f == Familiarity.regular || f == Familiarity.kin;
    String? text;

    switch (eventKey) {
      case 'pomodoro_done':
        text = isLate ? '一段稳了，按节奏来。' : '一段完成。喝口水，准备下一段。';
        break;
      case 'pomodoro_interrupted':
        text = isLate ? '又断。下一段开始前先想好为什么。' : '断了。下一段开始前先想好为什么。';
        break;
      case 'resource_collected':
        text = isLate ? '别只收藏，要看完。' : '收藏不等于学过，找时间真的去读。';
        break;
      case 'accounting_added':
        text = isLate ? '记了。' : '记上了。';
        break;
      case 'accounting_over_budget':
        text = isLate
            ? '又超了。这个月剩下的，自己看着办。'
            : '本月预算超了。最近几笔不重要的，可以缓一缓。';
        break;
      case 'plan_created':
        text = isLate ? '计划做了就执行。' : '计划已经在。明天能不能开始，看你。';
        break;
      case 'plan_completed':
        text = isLate ? '搞定一个。' : '一个目标完成。可以继续下一个。';
        break;
      case 'period_logged':
        text = isLate ? '记了。这几天别硬冲。' : '记录已存。这几天注意节奏。';
        break;
    }

    if (text == null) return null;
    await prefs.setBool(firedKey, true);
    await _markFired();
    return text;
  }

  // ─── 4. 推送（早晨 / 晚间）────────────────────────────────

  /// 早晨 07:30 推送文案（由 PushNotificationService 排程时调用，本身不消耗冒泡额度）
  static Future<String> morningPush() async {
    final f = await _familiarity();
    final phase = await CyclePhaseKnowledge.inferCurrentPhase();

    if (phase == 'menstrual') {
      switch (f) {
        case Familiarity.stranger:
        case Familiarity.acquainted:
          return '经期了，今天降一档，慢慢来。';
        case Familiarity.regular:
        case Familiarity.kin:
          return '经期。老规矩，今天 70% 的强度。';
      }
    }
    if (phase == 'pms') {
      switch (f) {
        case Familiarity.stranger:
        case Familiarity.acquainted:
          return '经前两天，目标定低一点更容易完成。';
        case Familiarity.regular:
        case Familiarity.kin:
          return '经前期。情绪上你比平时容易冲动，预算/学习都缓一点。';
      }
    }
    if (phase == 'ovulation' || phase == 'follicular') {
      switch (f) {
        case Familiarity.stranger:
        case Familiarity.acquainted:
          return '今天状态在线，可以攻一下一直没动的硬骨头。';
        case Familiarity.regular:
        case Familiarity.kin:
          return '你这阶段最能打，挑一个之前没啃下来的。';
      }
    }
    switch (f) {
      case Familiarity.stranger:
        return '早上好。打开 App，今天的 25 分钟先开始。';
      case Familiarity.acquainted:
        return '早。今天先 25 分钟。';
      case Familiarity.regular:
        return '又一天。开 App，开始就行。';
      case Familiarity.kin:
        return '准时。';
    }
  }

  /// 晚间 21:30 推送文案
  static Future<String> eveningPush() async {
    final prefs = await SharedPreferences.getInstance();
    final localToday = DateTime.now().toIso8601String().substring(0, 10);
    final focus = prefs.getInt('focus_seconds_$localToday') ?? 0;
    final f = await _familiarity();

    if (focus == 0) {
      switch (f) {
        case Familiarity.stranger:
          return '今天还没学。睡前 15 分钟也行，别留遗憾。';
        case Familiarity.acquainted:
          return '今天还没开始。睡前 15 分钟也算。';
        case Familiarity.regular:
          return '一整天，零专注。明天要不要看一下日历？';
        case Familiarity.kin:
          return '你自己看记录吧。';
      }
    }
    if (focus >= 60 * 60 * 2) {
      switch (f) {
        case Familiarity.stranger:
        case Familiarity.acquainted:
          return '今天 ${focus ~/ 60} 分钟，挺好。该收尾了。';
        case Familiarity.regular:
        case Familiarity.kin:
          return '${focus ~/ 60} 分钟。可以了，去睡。';
      }
    }
    switch (f) {
      case Familiarity.stranger:
        return '记一笔今天的账，明天复盘会用上。';
      case Familiarity.acquainted:
        return '记账 + 复盘，10 分钟内能搞完。';
      case Familiarity.regular:
        return '别又拖到凌晨。';
      case Familiarity.kin:
        return '该睡了。';
    }
  }

  // ─── 调试 ────────────────────────────────────────────────────

  static Future<void> debugReset() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) =>
        k.startsWith(_kBubbleCountPrefix) ||
        k.startsWith(_kTabFiredPrefix) ||
        k.startsWith(_kEventFiredPrefix) ||
        k == _kLastOpenerDay);
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
