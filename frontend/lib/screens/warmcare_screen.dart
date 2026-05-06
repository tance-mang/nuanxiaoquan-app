import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/tap_scale.dart';

// 暖圈关怀 — 生理期管理页
// 底层逻辑：本地计算周期预测，不依赖AI；AI仅用于分析建议
class WarmCareScreen extends StatefulWidget {
  const WarmCareScreen({Key? key}) : super(key: key);
  @override
  State<WarmCareScreen> createState() => _WarmCareScreenState();
}

// ── 数据模型 ──────────────────────────────────────────────────

class _DayRecord {
  final DateTime date;
  final int flow;      // 0=无 1=轻 2=中 3=重
  final int pain;      // 0-5
  final int mood;      // 0-4 (emoji index)
  final List<String> symptoms;

  _DayRecord({required this.date, this.flow = 0, this.pain = 0,
      this.mood = 2, this.symptoms = const []});

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'flow': flow, 'pain': pain, 'mood': mood, 'symptoms': symptoms,
  };

  factory _DayRecord.fromJson(Map<String, dynamic> j) => _DayRecord(
    date: DateTime.parse(j['date']),
    flow: j['flow'] ?? 0, pain: j['pain'] ?? 0,
    mood: j['mood'] ?? 2, symptoms: List<String>.from(j['symptoms'] ?? []),
  );
}

// ── 常量 ─────────────────────────────────────────────────────

const _moodEmojis = ['😢', '😕', '😐', '🙂', '😊'];
const _moodLabels = ['难受', '低落', '平静', '还好', '开心'];
const _flowLabels = ['无', '轻', '中', '重'];
const _flowColors = [Color(0xFFEEEEEE), Color(0xFFFFCDD2), Color(0xFFEF9A9A), Color(0xFFE57373)];
const _symptomOptions = ['痛经', '头痛', '腰酸', '乳胀', '疲惫', '水肿', '失眠', '情绪波动', '食欲增加', '皮肤问题'];

const _healingQuotes = [
  '今天比昨天好一点点，就是最大的进步。',
  '不是每天都要很厉害，但每天都要对自己温柔一点。',
  '慢慢来，比较快。你专注的样子，已经很美了。',
  '生理期要好好休息，学习也要照顾好身体，这才是长久之道。',
  '情绪波动是正常的，感受它，然后放下它。',
  '给自己泡一杯热饮，今天的任务可以稍微少一点。',
  '身体在说"慢下来"，那就慢下来，明天还是最好的你。',
];

// 各周期阶段学习建议
const _phaseAdvice = {
  'menstrual': '经期前2天适合轻度复习，避免高强度记忆任务，多喝热水，注意保暖。',
  'follicular': '卵泡期精力渐佳，适合攻克新知识点、做题刷题，效率最高。',
  'ovulation': '排卵期状态巅峰，可以挑战难题、参加考试或做重要演讲。',
  'luteal': '黄体期容易疲惫，建议以复习巩固为主，减少新内容输入，注意早睡。',
  'pms': '经前综合征阶段：减少熬夜，多做轻松的阅读，避免给自己太大压力。',
};

class _WarmCareScreenState extends State<WarmCareScreen> {
  List<_DayRecord> _records = [];
  List<DateTime> _cycleDates = []; // 每次经期开始日期

  // 今天的记录草稿
  int _todayFlow = 0;
  int _todayPain = 0;
  int _todayMood = 2;
  List<String> _todaySymptoms = [];
  bool _todaySaved = false;

  // 周期统计
  int _avgCycleLen = 28;
  int _avgDuration = 5;

  DateTime get _today => DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final rawRecords = prefs.getStringList('warmcare_records') ?? [];
    _records = rawRecords.map((s) => _DayRecord.fromJson(jsonDecode(s))).toList();

    final rawCycles = prefs.getStringList('warmcare_cycles') ?? [];
    _cycleDates = rawCycles.map((s) => DateTime.parse(s)).toList()
      ..sort((a, b) => a.compareTo(b));

    // 计算平均周期
    if (_cycleDates.length >= 2) {
      int total = 0;
      for (int i = 1; i < _cycleDates.length; i++) {
        total += _cycleDates[i].difference(_cycleDates[i - 1]).inDays;
      }
      _avgCycleLen = (total / (_cycleDates.length - 1)).round().clamp(21, 40);
    }

    // 加载今日草稿
    final todayRec = _records.where((r) => _sameDay(r.date, _today));
    if (todayRec.isNotEmpty) {
      final r = todayRec.first;
      _todayFlow = r.flow; _todayPain = r.pain;
      _todayMood = r.mood; _todaySymptoms = List.from(r.symptoms);
      _todaySaved = true;
    }

    if (mounted) setState(() {});
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── 周期计算逻辑 ─────────────────────────────────────────

  DateTime? get _lastPeriodStart => _cycleDates.isEmpty ? null : _cycleDates.last;

  DateTime? get _nextPeriodPredicted =>
      _lastPeriodStart == null ? null : _lastPeriodStart!.add(Duration(days: _avgCycleLen));

  // 今天是周期第几天
  int get _currentCycleDay {
    if (_lastPeriodStart == null) return 0;
    return _today.difference(_lastPeriodStart!).inDays + 1;
  }

  String get _currentPhase {
    final day = _currentCycleDay;
    if (day <= 0 || day > _avgCycleLen) return 'unknown';
    if (day <= _avgDuration) return 'menstrual';
    if (day <= 13) return 'follicular';
    if (day <= 16) return 'ovulation';
    if (day >= _avgCycleLen - 3) return 'pms';
    return 'luteal';
  }

  String get _phaseLabel {
    switch (_currentPhase) {
      case 'menstrual': return '经期 🩸';
      case 'follicular': return '卵泡期 🌱';
      case 'ovulation': return '排卵期 ✨';
      case 'luteal': return '黄体期 🌙';
      case 'pms': return '经前期 ⚠️';
      default: return '暖圈关怀';
    }
  }

  Color get _phaseColor {
    switch (_currentPhase) {
      case 'menstrual': return const Color(0xFFE57373);
      case 'follicular': return const Color(0xFF81C784);
      case 'ovulation': return const Color(0xFFFFD54F);
      case 'luteal': return const Color(0xFF9575CD);
      case 'pms': return const Color(0xFFFF8A65);
      default: return const Color(0xFFE89DAC);
    }
  }

  int? get _daysUntilNext {
    if (_nextPeriodPredicted == null) return null;
    return _nextPeriodPredicted!.difference(_today).inDays;
  }

  // ── 保存逻辑 ─────────────────────────────────────────────

  Future<void> _saveToday() async {
    final rec = _DayRecord(
      date: _today, flow: _todayFlow, pain: _todayPain,
      mood: _todayMood, symptoms: _todaySymptoms,
    );

    _records.removeWhere((r) => _sameDay(r.date, _today));
    _records.add(rec);

    // 如果有经血记录且不在已知经期内，标记为新经期开始
    if (_todayFlow > 0 && (_lastPeriodStart == null ||
        _today.difference(_lastPeriodStart!).inDays > 14)) {
      _cycleDates.add(_today);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('warmcare_records',
        _records.map((r) => jsonEncode(r.toJson())).toList());
    await prefs.setStringList('warmcare_cycles',
        _cycleDates.map((d) => d.toIso8601String()).toList());

    setState(() => _todaySaved = true);
    _showSaveSuccess();
    await _load();
  }

  Future<void> _markPeriodStart() async {
    if (_lastPeriodStart != null && _today.difference(_lastPeriodStart!).inDays < 14) {
      Get.snackbar('提示', '本次经期已记录，无需重复标记', snackPosition: SnackPosition.TOP);
      return;
    }
    _cycleDates.add(_today);
    _todayFlow = 2;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('warmcare_cycles',
        _cycleDates.map((d) => d.toIso8601String()).toList());
    setState(() {});
    Get.snackbar('已记录', '经期开始日已标记 🩸', backgroundColor: const Color(0xFFE57373), colorText: Colors.white);
  }

  void _showSaveSuccess() {
    final quote = (_healingQuotes..shuffle()).first;
    final showQuote = _todayMood <= 1;
    Get.snackbar(
      '记录成功 ✓',
      showQuote ? '"$quote"' : '今日暖记已保存，好好照顾自己～',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 3),
      backgroundColor: _phaseColor.withOpacity(0.9),
      colorText: Colors.white,
    );
  }

  // ── 构建 UI ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        title: const Text('暖圈关怀'),
        backgroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _markPeriodStart,
            icon: const Text('🩸', style: TextStyle(fontSize: 14)),
            label: const Text('经期开始', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 32.h),
        children: [
          _buildCycleStatusCard(theme),
          SizedBox(height: 14.h),
          _buildCalendar(theme),
          SizedBox(height: 14.h),
          _buildTodayLogCard(theme),
          SizedBox(height: 14.h),
          if (_currentPhase != 'unknown') _buildPhaseAdviceCard(theme),
          if (_currentPhase != 'unknown') SizedBox(height: 14.h),
          if (_todayMood <= 1 && _todaySaved) _buildHealingCard(theme),
          if (_todayMood <= 1 && _todaySaved) SizedBox(height: 14.h),
          _buildRecentRecords(theme),
        ],
      ),
    );
  }

  // ── 周期状态卡 ───────────────────────────────────────────
  Widget _buildCycleStatusCard(ThemeData theme) {
    final daysLeft = _daysUntilNext;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_phaseColor, _phaseColor.withOpacity(0.7)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [BoxShadow(color: _phaseColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(_phaseLabel, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_currentCycleDay > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12.r)),
                child: Text('第 $_currentCycleDay 天', style: TextStyle(color: Colors.white, fontSize: 12.sp)),
              ),
          ]),
          SizedBox(height: 12.h),
          if (_lastPeriodStart == null)
            Text('点右上角「经期开始」记录第一次经期，\n系统将自动计算周期规律', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13.sp, height: 1.5))
          else
            Row(children: [
              _statItem('上次经期', '${_lastPeriodStart!.month}/${_lastPeriodStart!.day}'),
              SizedBox(width: 24.w),
              _statItem('平均周期', '$_avgCycleLen 天'),
              SizedBox(width: 24.w),
              if (daysLeft != null)
                _statItem('下次预测', daysLeft <= 0 ? '今天' : '$daysLeft 天后'),
            ]),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11.sp)),
      Text(value, style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w600)),
    ],
  );

  // ── 月历视图 ─────────────────────────────────────────────
  Widget _buildCalendar(ThemeData theme) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=Sun

    // 哪些天有流量记录
    final flowDays = {for (var r in _records.where((r) => r.flow > 0)) '${r.date.month}/${r.date.day}': r.flow};

    // 预测经期天数
    Set<int> predictedDays = {};
    if (_nextPeriodPredicted != null && _nextPeriodPredicted!.month == now.month) {
      for (int i = 0; i < _avgDuration; i++) {
        final d = _nextPeriodPredicted!.add(Duration(days: i));
        if (d.month == now.month) predictedDays.add(d.day);
      }
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${now.month}月', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 10.h),
          // 星期头
          Row(
            children: ['日','一','二','三','四','五','六'].map((w) =>
              Expanded(child: Center(child: Text(w, style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]))))).toList(),
          ),
          SizedBox(height: 6.h),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 2, childAspectRatio: 1),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (ctx, i) {
              if (i < startWeekday) return const SizedBox.shrink();
              final day = i - startWeekday + 1;
              final key = '${now.month}/$day';
              final flow = flowDays[key] ?? 0;
              final isPredicted = predictedDays.contains(day);
              final isToday = day == now.day;
              Color? bg;
              if (flow > 0) bg = _flowColors[flow];
              else if (isPredicted) bg = const Color(0xFFFCE4EC);
              return Container(
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: isToday ? Border.all(color: const Color(0xFFE89DAC), width: 1.5) : null,
                ),
                child: Center(child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: flow > 0 ? Colors.white : (isToday ? const Color(0xFFE89DAC) : Colors.grey[700]),
                  ),
                )),
              );
            },
          ),
          SizedBox(height: 8.h),
          Row(children: [
            _legend(const Color(0xFFEF9A9A), '经期'),
            SizedBox(width: 14.w),
            _legend(const Color(0xFFFCE4EC), '预测'),
            SizedBox(width: 14.w),
            Container(width: 12.w, height: 12.w, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE89DAC), width: 1.5))),
            SizedBox(width: 4.w),
            Text('今天', style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
          ]),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(children: [
    Container(width: 12.w, height: 12.w, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    SizedBox(width: 4.w),
    Text(label, style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
  ]);

  // ── 今日记录卡 ───────────────────────────────────────────
  Widget _buildTodayLogCard(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('今日记录', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              '${_today.month}月${_today.day}日',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
            ),
          ]),
          SizedBox(height: 14.h),

          // 经血量
          Text('经血量', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
          SizedBox(height: 8.h),
          Row(
            children: List.generate(4, (i) => Expanded(
              child: TapScale(
                scale: 0.90,
                onTap: () => setState(() => _todayFlow = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: EdgeInsets.only(right: i < 3 ? 8.w : 0),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: _todayFlow == i ? _flowColors[i == 0 ? 0 : i] : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: _todayFlow == i ? _flowColors[i == 0 ? 0 : i] : Colors.grey.shade300),
                  ),
                  child: Center(child: Text(_flowLabels[i],
                      style: TextStyle(fontSize: 12.sp, color: _todayFlow == i ? (i == 0 ? Colors.grey[600] : Colors.white) : Colors.grey[600]))),
                ),
              ),
            )),
          ),

          SizedBox(height: 14.h),

          // 疼痛程度
          Text('疼痛程度 · ${_todayPain == 0 ? "无" : "$_todayPain/5"}',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
          SizedBox(height: 6.h),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: const Color(0xFFE57373),
              inactiveTrackColor: Colors.grey.shade200,
              thumbColor: const Color(0xFFE57373),
              overlayColor: const Color(0xFFE57373).withOpacity(0.15),
            ),
            child: Slider(
              min: 0, max: 5, divisions: 5,
              value: _todayPain.toDouble(),
              onChanged: (v) => setState(() => _todayPain = v.round()),
            ),
          ),

          SizedBox(height: 10.h),

          // 心情
          Text('今日心情', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(5, (i) => TapScale(
              scale: 0.85,
              onTap: () => setState(() => _todayMood = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: _todayMood == i ? const Color(0xFFFFF0F5) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12.r),
                  border: _todayMood == i ? Border.all(color: const Color(0xFFE89DAC)) : null,
                ),
                child: Column(children: [
                  Text(_moodEmojis[i], style: TextStyle(fontSize: 22.sp)),
                  SizedBox(height: 2.h),
                  Text(_moodLabels[i], style: TextStyle(fontSize: 10.sp,
                      color: _todayMood == i ? const Color(0xFFE89DAC) : Colors.grey[500])),
                ]),
              ),
            )),
          ),

          SizedBox(height: 14.h),

          // 症状
          Text('不适症状（可多选）', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w, runSpacing: 6.h,
            children: _symptomOptions.map((s) {
              final selected = _todaySymptoms.contains(s);
              return TapScale(
                scale: 0.92,
                onTap: () => setState(() {
                  if (selected) _todaySymptoms.remove(s);
                  else _todaySymptoms.add(s);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFFEBEE) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: selected ? const Color(0xFFE57373) : Colors.grey.shade300),
                  ),
                  child: Text(s, style: TextStyle(
                    fontSize: 12.sp,
                    color: selected ? const Color(0xFFE57373) : Colors.grey[600],
                  )),
                ),
              );
            }).toList(),
          ),

          SizedBox(height: 16.h),

          SizedBox(
            width: double.infinity, height: 42.h,
            child: TapScale(
              onTap: _saveToday,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE89DAC),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21.r)),
                  elevation: 0,
                ),
                child: Text(_todaySaved ? '更新记录 ✓' : '保存今日记录',
                    style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 周期建议卡 ───────────────────────────────────────────
  Widget _buildPhaseAdviceCard(ThemeData theme) {
    final advice = _phaseAdvice[_currentPhase] ?? '';
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _phaseColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _phaseColor.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('💡', style: TextStyle(fontSize: 14.sp)),
          SizedBox(width: 6.w),
          Text('$_phaseLabel · 学习建议',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: _phaseColor)),
        ]),
        SizedBox(height: 8.h),
        Text(advice, style: TextStyle(fontSize: 13.sp, color: Colors.grey[700], height: 1.6)),
        if (_currentPhase == 'menstrual' || _currentPhase == 'pms') ...[
          SizedBox(height: 8.h),
          Row(children: [
            Icon(Icons.nightlight_outlined, size: 13.sp, color: Colors.deepPurple[300]),
            SizedBox(width: 4.w),
            Text('⚠️ 提醒：这几天尽量不要熬夜学习，身体比成绩更重要！',
                style: TextStyle(fontSize: 12.sp, color: Colors.deepPurple[300], fontWeight: FontWeight.w500)),
          ]),
        ],
      ]),
    );
  }

  // ── 治愈语录卡（心情差时显示）────────────────────────────
  Widget _buildHealingCard(ThemeData theme) {
    final quote = _healingQuotes[DateTime.now().day % _healingQuotes.length];
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFFFF0F5), const Color(0xFFFCE4EC)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('💕', style: TextStyle(fontSize: 14.sp)),
          SizedBox(width: 6.w),
          Text('今日治愈语录', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFFE89DAC))),
        ]),
        SizedBox(height: 10.h),
        Text('"$quote"',
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFF2D2D2D), height: 1.7, fontStyle: FontStyle.italic)),
        SizedBox(height: 8.h),
        Text('心情不好没关系，今天可以少学一点点，好好照顾自己 🌸',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[500])),
      ]),
    );
  }

  // ── 近期记录列表 ─────────────────────────────────────────
  Widget _buildRecentRecords(ThemeData theme) {
    final recent = _records.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final display = recent.take(7).toList();
    if (display.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('近期记录', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 10.h),
          ...display.map((r) => Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Row(children: [
              Container(
                width: 38.w, height: 38.w,
                decoration: BoxDecoration(color: _flowColors[r.flow].withOpacity(0.3), shape: BoxShape.circle),
                child: Center(child: Text(_moodEmojis[r.mood], style: TextStyle(fontSize: 18.sp))),
              ),
              SizedBox(width: 10.w),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r.date.month}月${r.date.day}日  ${_flowLabels[r.flow]}  疼痛${r.pain}/5',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[700])),
                if (r.symptoms.isNotEmpty)
                  Text(r.symptoms.join(' · '), style: TextStyle(fontSize: 11.sp, color: Colors.grey[400])),
              ])),
            ]),
          )),
        ],
      ),
    );
  }
}
