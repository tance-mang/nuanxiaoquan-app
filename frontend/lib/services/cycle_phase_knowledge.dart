// ============================================================
// 文件：services/cycle_phase_knowledge.dart
// 作用：生理期各阶段的预设知识库（纯本地数据，零网络依赖）
//
// 配合 WarmCareScreen 已有 5 阶段（menstrual / follicular / ovulation /
// luteal / pms）使用 —— 这里只补充内容，不引入新概念。
//
// 风格遵循小暖人设：理性、克制、不矫情，给具体可执行的建议而非情绪安慰。
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';

/// 一个阶段的完整知识包
class PhaseKnowledge {
  /// 阶段 key（与 WarmCareScreen._currentPhase 保持一致）
  final String phase;

  /// 中文名（"经期" / "卵泡期" 等）
  final String name;

  /// 身体特征（事实描述，3-4 条）
  final List<String> bodyNotes;

  /// 认知特点（精力 / 专注 / 记忆 / 逻辑分别如何）
  final List<String> cognitiveNotes;

  /// 推荐学习强度的"建议级别"
  /// 取值：'light' / 'standard' / 'sprint' / 'rest'
  /// StrengthEngine 据此对 score 做微调，但不强制覆盖
  final String recommendedStrength;

  /// 适合做的任务类型（具体，可对照到日历安排）
  final List<String> bestTasks;

  /// 不建议这个阶段做的任务（明确"别强迫自己做这个"）
  final List<String> avoidTasks;

  /// 怎么开始学习——3 条具体可执行的建议
  /// 这是用户最需要的：克服启动惰性
  final List<String> kickStartHints;

  /// 该阶段适合推送的暖句池（10 条+，克制理智风格）
  /// 用于"今日推荐"在该阶段时优先取
  final List<String> pushQuotes;

  /// 生活提醒（睡眠、饮食、运动）
  final List<String> lifestyleTips;

  /// 消费提醒（仅 pms / menstrual 阶段提供有意义的内容）
  /// 用于暖账模块在该阶段触发"先冷静 24 小时"之类的提示
  final String? spendingAlert;

  const PhaseKnowledge({
    required this.phase,
    required this.name,
    required this.bodyNotes,
    required this.cognitiveNotes,
    required this.recommendedStrength,
    required this.bestTasks,
    required this.avoidTasks,
    required this.kickStartHints,
    required this.pushQuotes,
    required this.lifestyleTips,
    this.spendingAlert,
  });
}

class CyclePhaseKnowledge {
  /// 5 阶段静态表。key 与 WarmCareScreen._currentPhase 完全一致。
  static const Map<String, PhaseKnowledge> _table = {
    // ════════════════════════════════════════════════════════════
    // 1. 经期 menstrual
    // ════════════════════════════════════════════════════════════
    'menstrual': PhaseKnowledge(
      phase: 'menstrual',
      name: '经期',
      bodyNotes: [
        '激素水平整体偏低，基础代谢慢。',
        '盆腔可能不适，久坐学习要每 40 分钟起身一次。',
        '体温微升、易出汗，含铁食物（红肉、菠菜）补血更有帮助。',
        '免疫力波动，体感容易疲劳。',
      ],
      cognitiveNotes: [
        '注意力比平时短，单次专注 25-30 分钟更合适。',
        '逻辑推理能力没太大影响，但工作记忆容量略降。',
        '情绪敏感度上升，遇挫更容易放弃，要预判这一点。',
      ],
      recommendedStrength: 'light',
      bestTasks: [
        '错题本整理、笔记复盘',
        '已学知识的低强度复习（默写、自测）',
        '听课件回放、纪录片',
        '把上周的任务清单梳理一遍',
      ],
      avoidTasks: [
        '熬夜攻坚新章节',
        '需要长时间高度集中的考试模拟',
        '高难度数学/逻辑推导（容易卡住放弃，伤信心）',
      ],
      kickStartHints: [
        '今天先做 10 分钟的"整理"——翻昨天的笔记、错题集，不学新东西。',
        '把书桌收拾干净，泡杯热的，再决定要不要继续。',
        '完成度比难度重要：写两个易题，就算今天的学习指标达成了。',
      ],
      pushQuotes: [
        '身体在说"慢一点"，听它的不丢人。',
        '今天的目标不是进步，是不退步。',
        '能维持基本节奏，就已经赢了大多数人。',
        '复习也是学习。整理也是学习。',
        '把昨天没看完的看完，比硬开新章靠谱。',
        '强度可以降，但别让自己彻底停下来。',
        '今天少做一点，明天不会失去什么。',
        '允许自己以 70% 的状态生活两三天，规律比强度更有用。',
        '不舒服时翻翻笔记，比硬刷题划算。',
        '一个温柔的开始就够了。',
      ],
      lifestyleTips: [
        '睡眠不要少于 7 小时，缺觉会放大不适。',
        '少喝冰饮和咖啡因（咖啡因会加重痛感）。',
        '推荐快走、拉伸、瑜伽——别做剧烈运动。',
      ],
      spendingAlert:
          '经期情绪敏感时容易"奖励性消费"。看到想买的东西，先加购物车放 24 小时再决定，多数时候热度会过去。',
    ),

    // ════════════════════════════════════════════════════════════
    // 2. 卵泡期 follicular（经期结束 ~ 排卵前，全周期最佳学习窗口）
    // ════════════════════════════════════════════════════════════
    'follicular': PhaseKnowledge(
      phase: 'follicular',
      name: '卵泡期',
      bodyNotes: [
        '雌激素稳步上升，基础代谢提高。',
        '体能恢复，运动表现回到甚至超过平日。',
        '皮肤、睡眠质量整体走好。',
        '免疫力回到稳定水位。',
      ],
      cognitiveNotes: [
        '大脑神经可塑性最强，是记新单词、新公式、新框架的黄金窗口。',
        '注意力可以维持 45-60 分钟单段。',
        '逻辑、空间、创造性思考都在高位。',
      ],
      recommendedStrength: 'standard',
      bestTasks: [
        '攻坚新章节、新概念',
        '需要构建新知识体系的任务（建立大纲、串模型）',
        '需要长时间专注的整套真题',
        '英语单词突击、外语口语训练',
      ],
      avoidTasks: [
        '把时间用在反复刷已经会的题',
        '只做整理性低价值任务（浪费窗口）',
      ],
      kickStartHints: [
        '今天本来就该攻坚——直接挑你拖最久的那个难点章节，给自己 45 分钟。',
        '把这周的"必须搞懂的 3 件事"列出来，第一件现在就开始。',
        '不要从最简单的开始热身——这个阶段允许你直接上强度。',
      ],
      pushQuotes: [
        '这是你这个月最锋利的时段，别浪费。',
        '该硬啃的章节，趁这几天硬啃。',
        '可以专注 50 分钟的状态不常有，别拿去刷手机。',
        '攻最难的山头，下周回看会感谢自己。',
        '所谓"学得进去"，就是这种感觉，记住它。',
        '难题等你的不是一辈子。',
        '把窗口期用好，比天赋更重要。',
        '今天的输入决定了下周的产出。',
        '挑战清单上排第一的那个，开始它。',
        '现在不冲，下次要再等 28 天。',
      ],
      lifestyleTips: [
        '可以加大运动量，配合学习产出。',
        '睡眠保持规律，别因为状态好就熬夜。',
        '蛋白质摄入充足，给大脑供能。',
      ],
      spendingAlert: null,
    ),

    // ════════════════════════════════════════════════════════════
    // 3. 排卵期 ovulation（窗口很短，1-3 天，体能巅峰）
    // ════════════════════════════════════════════════════════════
    'ovulation': PhaseKnowledge(
      phase: 'ovulation',
      name: '排卵期',
      bodyNotes: [
        '雌激素和睾酮短时间共同处于高位，身体处于全月巅峰。',
        '体温会有 0.3-0.5℃ 的轻微上升。',
        '少部分人会有腹部轻微不适，几小时内会过去。',
      ],
      cognitiveNotes: [
        '反应速度最快，应变能力最好。',
        '社交、表达、说服力都在峰值——适合面试、答辩、演讲。',
        '决策果断性强，但要警惕"过度自信"导致的草率。',
      ],
      recommendedStrength: 'sprint',
      bestTasks: [
        '模拟考、限时套题',
        '答辩、面试、口语考试',
        '需要表达的小组讨论、汇报',
        '一次性需要爆发产出的任务（写一篇完整论文、做一份完整 PPT）',
      ],
      avoidTasks: [
        '机械抄写、纯重复劳动（用在这种事上太可惜）',
      ],
      kickStartHints: [
        '今天把一件需要"一口气做完"的事拎出来——一鼓作气干完。',
        '有面试/演讲/答辩排上今天最好；没有的话，挑套真题计时模拟。',
        '坐下就开始，不要预热。这个状态自己启动得了。',
      ],
      pushQuotes: [
        '巅峰状态用在小事上是浪费。',
        '今天能 60 分钟不出戏，干一件大的。',
        '果断比完美重要——但别冲动。',
        '需要爆发的事，留给今天。',
        '一鼓作气是这个阶段的关键词。',
        '该出手就出手，状态不会等人。',
        '今天的产出可以抵平时三天。',
        '把藏了很久的"我应该做"变成"我做了"。',
        '不要回头检查太多次，先冲完再说。',
        '此刻的清晰度，自己要记住。',
      ],
      lifestyleTips: [
        '保持水分摄入。',
        '运动可以高强度，但要做好热身。',
        '别熬夜——状态再好，连续亏睡也撑不住。',
      ],
      spendingAlert: null,
    ),

    // ════════════════════════════════════════════════════════════
    // 4. 黄体期 luteal（排卵后 ~ 经前，前半段还能学，后半段下滑）
    // ════════════════════════════════════════════════════════════
    'luteal': PhaseKnowledge(
      phase: 'luteal',
      name: '黄体期',
      bodyNotes: [
        '孕酮上升、雌激素小幅回落。',
        '基础代谢略升，容易嘴馋，饱腹感来得快也散得快。',
        '体温整体偏高，午睡需求增加。',
        '皮肤可能出油增多，睡眠浅。',
      ],
      cognitiveNotes: [
        '前半段（排卵后 4-7 天）认知能力还在线，可以保持标准节奏。',
        '后半段开始接近经前，注意力容易飘，情绪敏感度上升。',
        '执行力强于创造力——适合"按计划推进"而非"发散探索"。',
      ],
      recommendedStrength: 'standard',
      bestTasks: [
        '复习巩固、串联章节',
        '把卵泡期攻下的新知识做配套练习',
        '整理错题、归纳错误类型',
        '准备阶段测试',
      ],
      avoidTasks: [
        '强迫自己产出全新创意（这个阶段创造力下降）',
        '彻夜赶 ddl',
      ],
      kickStartHints: [
        '今天用"清单 + 计时"开局：列出 3 个具体任务，每个限时 30 分钟。',
        '不要开新坑，先把上周开的那个收尾。',
        '感觉烦躁就停 10 分钟，喝口水再回来，别硬撑。',
      ],
      pushQuotes: [
        '不是状态变差，是身体在过渡。',
        '复习比扩张更适合这周。',
        '执行你列的清单，今天就够了。',
        '"按部就班"听起来无聊，但能让人走得远。',
        '排卵期攻下的山头，黄体期巩固。',
        '稳，是这周的关键词。',
        '把已经会的练熟，比学三个新的更值。',
        '现在的疲惫不代表能力下降。',
        '推进 80% 就停，留点余量给身体。',
        '今天能完成一半计划就合格。',
      ],
      lifestyleTips: [
        '咖啡因减半——黄体期对咖啡更敏感。',
        '高糖零食控制下，糖飙完落差会让情绪更差。',
        '运动选中等强度（慢跑、骑车），不建议挑战极限。',
      ],
      spendingAlert: null,
    ),

    // ════════════════════════════════════════════════════════════
    // 5. 经前期 pms（经前 5-3 天，最难熬的阶段）
    // ════════════════════════════════════════════════════════════
    'pms': PhaseKnowledge(
      phase: 'pms',
      name: '经前期',
      bodyNotes: [
        '激素急剧下降，水钠潴留可能让你"看起来胖了 2 斤"——不是真胖。',
        '乳房胀痛、头痛、腹胀、便秘都是这个阶段常见的。',
        '睡眠质量明显变差，多梦易醒。',
        '皮肤状态最差，痘痘、出油都集中在这两三天。',
      ],
      cognitiveNotes: [
        '注意力分散，工作记忆容量明显下降。',
        '情绪极易被小事点燃，容易把"今天没学好"放大成"我是不是不行"。',
        '决策容易冲动，尤其是"现在就买"这种念头要警惕。',
      ],
      recommendedStrength: 'light',
      bestTasks: [
        '低强度复习、看视频课',
        '把房间收拾、把课表/计划整理一遍',
        '听课、抄写、机械整理类任务',
        '阅读型任务（不需要构建新知识）',
      ],
      avoidTasks: [
        '决定要不要换专业、要不要分手、要不要买东西——所有重大决策推迟到经期后',
        '攻坚新章节、限时模拟',
        '熬夜——这阶段熬一晚要恢复三天',
      ],
      kickStartHints: [
        '今天的目标降到平时的 50%——做完就奖励自己，不愧疚。',
        '先做最容易的那个任务（哪怕只是抄写），用完成感对抗情绪低落。',
        '感觉学不进去就停。这不是懒，是身体在调节。',
      ],
      pushQuotes: [
        '这几天烦躁不是你的错，是激素的事。',
        '现在做的任何决定都建议先放 24 小时。',
        '今天能起床、能吃饭、能完成一件小事，就够了。',
        '别用平时的标准要求这几天的自己。',
        '难受是真的，但它会过去——通常 3 天内。',
        '减少社交摩擦，避开能让你烦的事和人。',
        '"做不下去"是这个阶段的常态，不是退步。',
        '清单上做一项就是赢，不用做完。',
        '允许自己今天不优秀。',
        '把"应该"换成"能做就做"。',
      ],
      lifestyleTips: [
        '减少盐、糖、咖啡因——会加重水肿和情绪波动。',
        '可以补充镁（坚果、深色蔬菜），对缓解 PMS 有据可查。',
        '强烈推荐 22:30 前睡——这是缓解 PMS 最便宜的方法。',
        '避免和恋人/家人在这两天讨论重大议题。',
      ],
      spendingAlert:
          '经前期是情绪化消费高发期。看到想买的东西先放购物车，到下次经期结束再看——通常 70% 的购买冲动会自己消失。',
    ),
  };

  /// 获取指定阶段的知识（找不到时返回 null）
  static PhaseKnowledge? of(String? phase) {
    if (phase == null) return null;
    return _table[phase];
  }

  /// 已知阶段列表
  static List<String> get allPhases => _table.keys.toList();

  // ──────────────────────────────────────────────────────────────
  // 当前阶段的本地推断
  // 从 SharedPreferences 读 warmcare_cycles + warmcare_records，
  // 复用 WarmCareScreen 的规则计算，避免概念分裂。
  // ──────────────────────────────────────────────────────────────

  /// 平均周期天数读取键
  static const _kCycles = 'warmcare_cycles';

  /// 推断今天的阶段。无数据返回 null（不是 'unknown'，让调用方判 null 跳过）
  static Future<String?> inferCurrentPhase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawCycles = prefs.getStringList(_kCycles) ?? [];
      if (rawCycles.isEmpty) return null;

      final dates = rawCycles.map((s) => DateTime.parse(s)).toList()
        ..sort((a, b) => a.compareTo(b));

      // 平均周期
      int avgCycleLen = 28;
      if (dates.length >= 2) {
        int total = 0;
        for (int i = 1; i < dates.length; i++) {
          total += dates[i].difference(dates[i - 1]).inDays;
        }
        avgCycleLen = (total / (dates.length - 1)).round().clamp(21, 40);
      }

      // 平均经期持续天数：固定 5（与 WarmCareScreen 一致）
      const avgDuration = 5;

      final today = DateTime.now();
      final t = DateTime(today.year, today.month, today.day);
      final last = dates.last;
      final day = t.difference(last).inDays + 1;
      if (day <= 0 || day > avgCycleLen + 7) return null;

      if (day <= avgDuration) return 'menstrual';
      if (day <= 13) return 'follicular';
      if (day <= 16) return 'ovulation';
      if (day >= avgCycleLen - 3) return 'pms';
      return 'luteal';
    } catch (_) {
      return null;
    }
  }

  /// 一站式：读阶段 → 返回知识包（找不到时返回 null）
  static Future<PhaseKnowledge?> currentKnowledge() async {
    final phase = await inferCurrentPhase();
    return of(phase);
  }

  // ──────────────────────────────────────────────────────────────
  // 工具：从阶段池里挑一句暖句
  // 按日期 hash 选择，同一天结果稳定
  // ──────────────────────────────────────────────────────────────
  static String? pickQuoteOfDay(String? phase) {
    final k = of(phase);
    if (k == null || k.pushQuotes.isEmpty) return null;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final seed = today.hashCode.abs();
    return k.pushQuotes[seed % k.pushQuotes.length];
  }
}
