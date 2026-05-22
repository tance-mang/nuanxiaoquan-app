import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';
import '../services/strength_engine.dart';
import '../services/hitokoto_service.dart';
import '../services/cycle_phase_knowledge.dart';
import '../services/proactive_companion.dart';
import '../controllers/app_controller.dart';
import '../widgets/tap_scale.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({Key? key}) : super(key: key);
  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

// ── 预置暖语（带分类）────────────────────────────────────────
const _sampleQuotes = [
  {'id':1,'content':'你不需要很厉害才能开始，但你需要开始才能很厉害。','author':'暖小圈','category':'励志','isPreset':true},
  {'id':2,'content':'每一个你觉得努力撑不下去的今天，都是明天更强大的自己的起点。','author':'暖小圈','category':'励志','isPreset':true},
  {'id':3,'content':'慢慢来，比较快。你专注的样子，已经很美了。','author':'暖小圈','category':'治愈','isPreset':true},
  {'id':4,'content':'学习不是赛跑，是修行。每天进步一点点，岁月自然给你答案。','author':'暖小圈','category':'学习','isPreset':true},
  {'id':5,'content':'考试失利不是终点，只是提醒你哪里还有空间可以生长。','author':'暖小圈','category':'学习','isPreset':true},
  {'id':6,'content':'不必羡慕别人的进度，你走的每一步都算数。','author':'暖小圈','category':'治愈','isPreset':true},
  {'id':7,'content':'休息也是一种努力，允许自己偶尔停下来喘口气。','author':'暖小圈','category':'放松','isPreset':true},
  {'id':8,'content':'今天的困惑，是明天顿悟的铺垫。','author':'暖小圈','category':'励志','isPreset':true},
  {'id':9,'content':'每一次你选择继续，都是在为未来的自己铺路。','author':'暖小圈','category':'坚持','isPreset':true},
];

// ── 预置存知（带分类）────────────────────────────────────────
const _sampleResources = [
  {
    'id':1,'title':'备考心得｜考研数学高效刷题法',
    'content':'建议先看教材把基础打牢，再刷660+汤家凤1800。错题要二刷三刷，专项练习配合真题。每天2小时，三个月即可见效。重要：错题本一定要整理！',
    'category':'考研','isPreset':true,
  },
  {
    'id':2,'title':'计算机学习路线｜从零到会写项目',
    'content':'第一步：学Python基础语法（2周）→ 第二步：数据结构与算法（1个月）→ 第三步：选方向（前端/后端/算法）→ 第四步：做项目。推荐资源：CS61A、LeetCode、B站黑马程序员。',
    'category':'计算机','isPreset':true,
  },
  {
    'id':3,'title':'公考行测｜数量关系秒杀技巧',
    'content':'数量关系不用全做，先跳过难题做言语和资料。核心技巧：① 代入法秒杀选择题 ② 整除特性判断 ③ 比例法处理工程问题。每天练15道，30天提升明显。',
    'category':'公考','isPreset':true,
  },
  {
    'id':4,'title':'大学英语四级｜阅读理解拿分秘诀',
    'content':'四级阅读核心：先看题目定位关键词，再回文章找细节。长句拆解法：找到主干（主谓宾），定语从句单独理解。每天1篇精读+2篇泛读，六周必过。',
    'category':'大学课程','isPreset':true,
  },
  {
    'id':5,'title':'网络安全入门｜渗透测试学习路线',
    'content':'基础：Linux+Python+网络协议 → 中级：Kali工具使用、CTF题目练习 → 进阶：漏洞挖掘、代码审计。推荐平台：Hack The Box、攻防世界、BUUCTF。',
    'category':'网络安全','isPreset':true,
  },
  {
    'id':6,'title':'职场新人｜高效沟通的5个技巧',
    'content':'① 先说结论再说过程 ② 用数据支撑观点 ③ 遇到分歧先共情再讲理 ④ 邮件三段式：背景+问题+方案 ⑤ 会议前准备好1-3个关键点。',
    'category':'职场','isPreset':true,
  },
  {
    'id':7,'title':'中小学｜数学思维培养方法',
    'content':'数学思维三步走：① 看懂题目（找关键条件）② 想解题思路（联系已学知识）③ 回验结果。每天练习一道开放性题目，鼓励多种解法，比反复刷题效果好10倍。',
    'category':'中小学','isPreset':true,
  },
];

class _KnowledgeScreenState extends State<KnowledgeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _apiService = ApiService();

  List<dynamic> _quotes = [];
  List<dynamic> _resources = [];
  bool _quotesLoading = true;
  bool _resourcesLoading = true;

  final _quoteSearchCtrl = TextEditingController();
  final _resSearchCtrl = TextEditingController();
  String _quoteQuery = '';
  String _resQuery = '';

  // 暖语分类
  final _quoteCats = ['全部', '励志', '治愈', '学习', '坚持', '放松'];
  String _selectedQuoteCat = '全部';

  // 存知分类
  final _resCats = ['全部', '中小学', '大学课程', '计算机', '网络安全', '考研', '公考', '语言', '职场', '自我成长'];
  String _selectedResCat = '全部';

  @override
  // ── 今日推荐（根据 StrengthEngine 推荐模式动态挑选）─────
  Map<String, dynamic>? _todayPick;
  String? _todayPickModeLabel;
  String? _todayPickRationale;
  Color? _todayPickTint;

  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _quoteSearchCtrl.addListener(() => setState(() => _quoteQuery = _quoteSearchCtrl.text));
    _resSearchCtrl.addListener(() => setState(() => _resQuery = _resSearchCtrl.text));
    _loadQuotes();
    _loadResources();
    _loadTodayPick();
  }

  Future<void> _loadTodayPick() async {
    final r = await StrengthEngine.compute();
    // mode → 暖语类别映射（本地规则，无 AI 依赖）
    final Set<String> cats;
    switch (r.mode) {
      case StrengthMode.light:    cats = {'治愈', '放松'}; break;
      case StrengthMode.standard: cats = {'学习', '励志'}; break;
      case StrengthMode.sprint:   cats = {'励志', '坚持'}; break;
      case StrengthMode.restDay:  cats = {'放松', '治愈'}; break;
      case StrengthMode.free:     cats = {'励志', '学习', '治愈', '坚持', '放松'}; break;
    }

    // 优先级：
    //   1) 处于 pms / menstrual / luteal 阶段 → 用阶段专属暖句池（更贴当下）
    //   2) 否则 → 一言公开 API（24h 缓存）
    //   3) 都没有 → 本地预置暖句
    Map<String, dynamic> pick;
    final phase = await CyclePhaseKnowledge.inferCurrentPhase();
    final phaseQuote = (phase == 'pms' || phase == 'menstrual' || phase == 'luteal')
        ? CyclePhaseKnowledge.pickQuoteOfDay(phase)
        : null;

    if (phaseQuote != null) {
      pick = {
        'content': phaseQuote,
        'author': '暖小圈',
        'category': '阶段陪伴',
        'source': '阶段',
      };
    } else {
      final hito = await HitokotoService.getDailyQuote();
      if (hito != null && (hito['content']?.isNotEmpty ?? false)) {
        pick = {
          'content': hito['content'],
          'author': '一言',
          'category': '今日推荐',
          'source': '一言',
        };
      } else {
        final pool = _sampleQuotes.where((q) => cats.contains(q['category'])).toList();
        final candidates = pool.isEmpty
            ? List<Map<String, dynamic>>.from(_sampleQuotes.map((e) => Map<String, dynamic>.from(e)))
            : pool.map((e) => Map<String, dynamic>.from(e)).toList();
        // 按日期 hash 选——同一天同一条，避免来回切换刷新
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final seed = today.hashCode.abs();
        pick = candidates[seed % candidates.length];
      }
    }

    if (!mounted) return;
    setState(() {
      _todayPick = pick;
      _todayPickModeLabel = r.modeShortLabel;
      _todayPickRationale = r.rationale;
      _todayPickTint = Color(r.tintHex);
    });
  }

  void _showPickRationale() {
    final tint = _todayPickTint ?? Theme.of(context).primaryColor;
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        title: Row(children: [
          Icon(Icons.auto_awesome, size: 16.sp, color: tint),
          SizedBox(width: 6.w),
          Text('为什么推荐这条',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: tint.withOpacity(0.14),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text('${_todayPickModeLabel ?? "标准"} 模式',
                  style: TextStyle(fontSize: 11.sp, color: tint, fontWeight: FontWeight.w600)),
            ),
            SizedBox(height: 10.h),
            Text(_todayPickRationale ?? '',
                style: TextStyle(fontSize: 13.sp, color: const Color(0xFF374151), height: 1.6)),
            SizedBox(height: 10.h),
            Text(
              '根据你今天的状态 + 行为，引擎选了类别匹配当前节奏的暖句。每天 0 点自动换。',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[500], height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('知道了')),
        ],
      ),
    );
  }

  Widget _buildTodayPickCard(ThemeData theme) {
    if (_todayPick == null) return const SizedBox.shrink();
    final tint = _todayPickTint ?? theme.primaryColor;
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 4.h),
      padding: EdgeInsets.all(13.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tint.withOpacity(0.13), tint.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: tint.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 13.sp, color: tint),
              SizedBox(width: 5.w),
              Text(
                '今日推荐 · ${_todayPickModeLabel ?? ""}',
                style: TextStyle(
                    fontSize: 11.sp,
                    color: tint,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showPickRationale,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: tint.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 11.sp, color: tint),
                      SizedBox(width: 3.w),
                      Text(
                        '为什么推荐',
                        style: TextStyle(
                            fontSize: 10.sp,
                            color: tint,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            _todayPick!['content'] as String,
            style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF1F2937),
                height: 1.55,
                fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 6.h),
          Text(
            '— ${_todayPick!['author']} · ${_todayPick!['category']}',
            style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
          ),
          // 一言来源时显示来源标识（遵守 hitokoto.cn 开源协议要求）
          if (_todayPick!['source'] == '一言') ...[
            SizedBox(height: 4.h),
            Row(
              children: [
                Icon(Icons.link, size: 10.sp, color: Colors.grey[400]),
                SizedBox(width: 3.w),
                Text(
                  '预览来源：一言 hitokoto.cn',
                  style: TextStyle(fontSize: 9.sp, color: Colors.grey[400]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── 过滤逻辑（本地预置数据也真正过滤）───────────────────

  List<dynamic> get _displayQuotes {
    final base = _quotes.isEmpty ? List<dynamic>.from(_sampleQuotes) : _quotes;
    return base.where((q) {
      final matchCat = _selectedQuoteCat == '全部' || (q['category'] ?? '') == _selectedQuoteCat;
      final matchSearch = _quoteQuery.isEmpty || (q['content'] ?? '').toString().contains(_quoteQuery);
      return matchCat && matchSearch;
    }).toList();
  }

  List<dynamic> get _displayResources {
    final base = _resources.isEmpty ? List<dynamic>.from(_sampleResources) : _resources;
    return base.where((r) {
      final matchCat = _selectedResCat == '全部' || (r['category'] ?? '') == _selectedResCat;
      final matchSearch = _resQuery.isEmpty ||
          (r['title'] ?? '').toString().contains(_resQuery) ||
          (r['content'] ?? '').toString().contains(_resQuery);
      return matchCat && matchSearch;
    }).toList();
  }

  Future<void> _loadQuotes() async {
    setState(() => _quotesLoading = true);
    try {
      final result = await _apiService.get('/quote/list?limit=50');
      setState(() {
        _quotes = result == null ? [] : (result is List ? result : (result['content'] ?? []));
        _quotesLoading = false;
      });
    } catch (_) { setState(() => _quotesLoading = false); }
  }

  Future<void> _loadResources() async {
    setState(() => _resourcesLoading = true);
    try {
      final result = await _apiService.get('/resource/list?limit=50');
      setState(() {
        _resources = result == null ? [] : (result is List ? result : (result['content'] ?? []));
        _resourcesLoading = false;
      });
    } catch (_) { setState(() => _resourcesLoading = false); }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quoteSearchCtrl.dispose();
    _resSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 26.w, height: 26.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.7)]),
            ),
            child: Center(child: Text('知', style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold))),
          ),
          SizedBox(width: 8.w),
          Text('知识小馆', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
        ]),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.primaryColor,
          indicatorWeight: 3,
          labelColor: theme.primaryColor,
          unselectedLabelColor: Colors.grey[500],
          labelStyle: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
          unselectedLabelStyle: TextStyle(fontSize: 15.sp),
          tabs: const [
            Tab(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('暖语'), Text('摘抄短句，自愈前行', style: TextStyle(fontSize: 9, fontWeight: FontWeight.normal)),
            ])),
            Tab(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('存知'), Text('记录所学，沉淀成长', style: TextStyle(fontSize: 9, fontWeight: FontWeight.normal)),
            ])),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildQuotesTab(theme), _buildResourcesTab(theme)],
      ),
      floatingActionButton: _buildFab(theme),
    );
  }

  Widget _buildFab(ThemeData theme) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (_, __) {
        final isQuotes = _tabController.index == 0;
        return TapScale(
          onTap: isQuotes ? _showPostQuoteDialog : _showPostResourceDialog,
          child: FloatingActionButton.extended(
            onPressed: null,
            backgroundColor: theme.primaryColor,
            icon: Icon(isQuotes ? Icons.format_quote : Icons.lightbulb_outline, size: 18.sp),
            label: Text(isQuotes ? '发布暖句' : '发布存学', style: TextStyle(fontSize: 13.sp)),
          ),
        );
      },
    );
  }

  // ══ 暖语 Tab ══════════════════════════════════════════════
  Widget _buildQuotesTab(ThemeData theme) {
    return Column(children: [
      // 今日推荐卡（按强度模式挑选，每日固定一条）
      _buildTodayPickCard(theme),
      _buildSearchBar(_quoteSearchCtrl, '搜索暖句关键词…', theme),
      _buildHorizontalCats(_quoteCats, _selectedQuoteCat, (cat) => setState(() => _selectedQuoteCat = cat), theme),
      Expanded(
        child: _quotesLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadQuotes,
                child: _displayQuotes.isEmpty
                    ? _buildEmpty('没有找到相关暖句', Icons.format_quote)
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 80.h),
                        itemCount: _displayQuotes.length,
                        itemBuilder: (ctx, i) => _buildQuoteCard(_displayQuotes[i], theme),
                      ),
              ),
      ),
    ]);
  }

  Widget _buildQuoteCard(Map<dynamic, dynamic> q, ThemeData theme) {
    final palette = [
      [const Color(0xFFFFF0F5), const Color(0xFFFFB6C8)],
      [const Color(0xFFF0F4FF), const Color(0xFFB6C8FF)],
      [const Color(0xFFF5F0FF), const Color(0xFFCFB6FF)],
      [const Color(0xFFF0FFF5), const Color(0xFFB6FFCF)],
      [const Color(0xFFFFFBF0), const Color(0xFFFFDDB6)],
    ];
    final idx = ((q['id'] ?? 0) as num).toInt() % palette.length;
    final c = palette[idx];
    final isPreset = q['isPreset'] == true;
    return TapScale(
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: c[0], borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: c[1].withOpacity(0.5)),
          boxShadow: [BoxShadow(color: c[1].withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('"', style: TextStyle(fontSize: 36.sp, color: c[1], height: 0.6, fontWeight: FontWeight.bold)),
          SizedBox(height: 8.h),
          Text(q['content'] ?? '', style: TextStyle(fontSize: 15.sp, color: const Color(0xFF2D2D2D), height: 1.6, fontWeight: FontWeight.w500)),
          SizedBox(height: 10.h),
          Row(children: [
            if (q['category'] != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(color: c[1].withOpacity(0.2), borderRadius: BorderRadius.circular(4.r)),
                child: Text(q['category'], style: TextStyle(fontSize: 10.sp, color: c[1])),
              ),
            if (isPreset) ...[
              SizedBox(width: 5.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4.r)),
                child: Text('示例', style: TextStyle(fontSize: 9.sp, color: Colors.grey[400])),
              ),
            ],
            const Spacer(),
            // 快捷"记到暖记"——把暖句带上下文塞到笔记
            GestureDetector(
              onTap: () => _quickMemo(
                title: '收藏一句话',
                content: q['content'] as String? ?? '',
                source: q['author'] ?? q['userNickname'] ?? '暖小圈',
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 6.w, vertical: 2.h),
                margin: EdgeInsets.only(right: 6.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4.r),
                  border: Border.all(color: c[1].withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_add_outlined,
                        size: 10.sp, color: c[1]),
                    SizedBox(width: 2.w),
                    Text('记到暖记',
                        style: TextStyle(
                            fontSize: 10.sp, color: c[1])),
                  ],
                ),
              ),
            ),
            Text(q['author'] ?? q['userNickname'] ?? '暖小圈', style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
          ]),
        ]),
      ),
    );
  }

  /// 快速跳到暖记并预填内容（带当前推荐模式标签 + 来源）
  void _quickMemo({required String title, required String content, String? source}) {
    final mode = _todayPickModeLabel ?? '';
    final tag = mode.isNotEmpty ? '#${mode}' : '';
    final src = source != null ? '\n— $source' : '';
    final body = '$content$src\n\n$tag';
    Get.toNamed('/memo', arguments: {
      'prefill_title': title,
      'prefill_content': body,
      'source_screen': 'knowledge',
    });
    // 小暖傲娇式提醒：别只收藏不读
    _notifyCompanion('resource_collected');
  }

  /// 通过悬浮球冒泡通道触发小暖一句话（频次由 ProactiveCompanion 兜底）
  Future<void> _notifyCompanion(String eventKey) async {
    final text = await ProactiveCompanion.eventMessage(eventKey);
    if (text == null) return;
    if (Get.isRegistered<AppController>()) {
      Get.find<AppController>().tellCompanion(text);
    }
  }

  // ══ 存知 Tab ══════════════════════════════════════════════
  Widget _buildResourcesTab(ThemeData theme) {
    return Column(children: [
      _buildSearchBar(_resSearchCtrl, '搜索学习干货…', theme),
      _buildHorizontalCats(_resCats, _selectedResCat, (cat) => setState(() => _selectedResCat = cat), theme),
      Expanded(
        child: _resourcesLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadResources,
                child: _displayResources.isEmpty
                    ? _buildEmpty('没有找到相关内容', Icons.school_outlined)
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 80.h),
                        itemCount: _displayResources.length,
                        itemBuilder: (ctx, i) => _buildResourceCard(_displayResources[i], theme),
                      ),
              ),
      ),
    ]);
  }

  // ── 通用组件 ──────────────────────────────────────────────

  Widget _buildSearchBar(TextEditingController ctrl, String hint, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 4.h),
      child: TextField(
        controller: ctrl,
        style: TextStyle(fontSize: 13.sp),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, size: 18.sp, color: Colors.grey[400]),
          suffixIcon: ctrl.text.isNotEmpty
              ? GestureDetector(onTap: () => ctrl.clear(), child: Icon(Icons.close, size: 16.sp, color: Colors.grey[400]))
              : null,
          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12.w),
          filled: true, fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24.r), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildHorizontalCats(List<String> cats, String selected, void Function(String) onTap, ThemeData theme) {
    return SizedBox(
      height: 40.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 4.h),
        itemCount: cats.length,
        itemBuilder: (ctx, i) {
          final cat = cats[i];
          final isSelected = cat == selected;
          return TapScale(
            scale: 0.93,
            onTap: () => onTap(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: 8.w),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: isSelected ? theme.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: isSelected ? theme.primaryColor : Colors.grey.shade300),
                boxShadow: isSelected ? [BoxShadow(color: theme.primaryColor.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))] : null,
              ),
              child: Text(cat, style: TextStyle(
                fontSize: 12.sp,
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              )),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResourceCard(Map<dynamic, dynamic> r, ThemeData theme) {
    final isPreset = r['isPreset'] == true;
    return TapScale(
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14.r),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4.r)),
              child: Text(r['category'] ?? '学习', style: TextStyle(fontSize: 10.sp, color: theme.primaryColor)),
            ),
            if (isPreset) ...[
              SizedBox(width: 5.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4.r)),
                child: Text('示例', style: TextStyle(fontSize: 9.sp, color: Colors.grey[400])),
              ),
            ],
            const Spacer(),
            if (r['isAiGenerated'] == true)
              Row(children: [
                Icon(Icons.auto_awesome, size: 11.sp, color: Colors.amber[600]),
                SizedBox(width: 2.w),
                Text('AI生成', style: TextStyle(fontSize: 10.sp, color: Colors.amber[600])),
              ]),
          ]),
          SizedBox(height: 10.h),
          if ((r['title'] ?? '').toString().isNotEmpty)
            Text(r['title'], style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: const Color(0xFF2D2D2D))),
          SizedBox(height: 6.h),
          Text(r['content'] ?? '', style: TextStyle(fontSize: 13.sp, color: Colors.grey[600], height: 1.5), maxLines: 4, overflow: TextOverflow.ellipsis),
          SizedBox(height: 8.h),
          Row(children: [
            Text(r['userNickname'] ?? '暖小圈', style: TextStyle(fontSize: 11.sp, color: Colors.grey[400])),
            const Spacer(),
            // 快捷"记到暖记"
            GestureDetector(
              onTap: () => _quickMemo(
                title: r['title'] as String? ?? '学习笔记',
                content: r['content'] as String? ?? '',
                source: '知识小馆·${r['category'] ?? "学习"}',
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 7.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(
                      color: theme.primaryColor.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_add_outlined,
                        size: 11.sp, color: theme.primaryColor),
                    SizedBox(width: 3.w),
                    Text('记到暖记',
                        style: TextStyle(
                            fontSize: 10.sp,
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildEmpty(String msg, IconData icon) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 52.sp, color: Colors.grey[200]),
      SizedBox(height: 16.h),
      Text(msg, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400], fontSize: 14.sp, height: 1.6)),
    ]));
  }

  // ── 发布对话框 ────────────────────────────────────────────
  void _showPostQuoteDialog() {
    final ctrl = Get.find<AppController>();
    if (!ctrl.isLoggedIn) { Get.toNamed('/login'); return; }
    final contentCtrl = TextEditingController();
    Get.dialog(AlertDialog(
      title: Row(children: [
        Icon(Icons.format_quote, color: Theme.of(Get.context!).primaryColor, size: 20.sp),
        SizedBox(width: 6.w), Text('发布暖句', style: TextStyle(fontSize: 16.sp)),
      ]),
      content: TextField(controller: contentCtrl, maxLines: 4, maxLength: 200,
          decoration: const InputDecoration(hintText: '分享一句治愈的话～', border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          if (contentCtrl.text.trim().isEmpty) return;
          try {
            await _apiService.post('/quote/post', body: {'content': contentCtrl.text.trim()});
            Get.back();
            Get.snackbar('发布成功', '你的暖句已发布～', backgroundColor: Colors.green, colorText: Colors.white);
            _loadQuotes();
          } catch (_) { Get.snackbar('发布失败', '请稍后重试'); }
        }, child: const Text('发布')),
      ],
    ));
  }

  void _showPostResourceDialog() {
    final ctrl = Get.find<AppController>();
    if (!ctrl.isLoggedIn) { Get.toNamed('/login'); return; }
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String selectedCat = '计算机';
    final cats = ['中小学', '大学课程', '计算机', '网络安全', '考研', '公考', '语言', '职场', '自我成长'];
    Get.dialog(StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: Row(children: [
        Icon(Icons.lightbulb_outline, color: Theme.of(Get.context!).primaryColor, size: 20.sp),
        SizedBox(width: 6.w), Text('发布存学', style: TextStyle(fontSize: 16.sp)),
      ]),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          value: selectedCat,
          decoration: const InputDecoration(labelText: '学习类目'),
          items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setS(() => selectedCat = v ?? '计算机'),
        ),
        SizedBox(height: 10.h),
        TextField(controller: titleCtrl, maxLength: 50,
            decoration: const InputDecoration(labelText: '标题（选填）', border: OutlineInputBorder())),
        SizedBox(height: 10.h),
        TextField(controller: contentCtrl, maxLines: 5, maxLength: 500,
            decoration: const InputDecoration(hintText: '分享学习干货、笔记、经验～\n（仅支持原创文字，禁止搬运）', border: OutlineInputBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        ElevatedButton(onPressed: () async {
          if (contentCtrl.text.trim().isEmpty) return;
          try {
            await _apiService.post('/resource/post', body: {'title': titleCtrl.text.trim(), 'content': contentCtrl.text.trim(), 'category': selectedCat});
            Get.back();
            Get.snackbar('发布成功', '你的学习干货已发布～', backgroundColor: Colors.green, colorText: Colors.white);
            _loadResources();
          } catch (_) { Get.snackbar('发布失败', '请稍后重试'); }
        }, child: const Text('发布')),
      ],
    )));
  }
}
