// ============================================================
// 文件：screens/xiaonuan_screen.dart
// 作用：小暖 AI 对话页面
//
// 核心交互流程：
//   1. 用户发消息 → 后端 /ai/chat（WAF检测 + 豆包意图识别）
//   2. 根据 intent 决定显示哪种卡片：
//      study_plan  → 学习计划确认卡（可编辑 + "设为今天计划"按钮）
//      accounting  → 记账确认框（金额/分类/备注 + 确认记账）
//      period      → 生理期建议卡（只展示，不操作）
//      chat_redirect/general → 普通对话气泡
//   3. 用户确认后，本地存储 or 调用对应 API
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';
import '../services/offline_calculator.dart';
import '../widgets/particle_background.dart';

class XiaoNuanScreen extends StatefulWidget {
  const XiaoNuanScreen({Key? key}) : super(key: key);

  @override
  State<XiaoNuanScreen> createState() => _XiaoNuanScreenState();
}

class _XiaoNuanScreenState extends State<XiaoNuanScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _api = ApiService();

  // 消息列表，每条 = {role: 'user'|'assistant', content: '...', action: {...}, intent: '...'}
  final List<Map<String, dynamic>> _messages = [];

  // 保留最近 6 轮对话作为上下文（不超发 token）
  List<Map<String, String>> get _history {
    final filtered = _messages
        .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
        .toList();
    final recent = filtered.length > 12 ? filtered.sublist(filtered.length - 12) : filtered;
    return recent.map<Map<String, String>>((m) => {
          'role': m['role'] as String,
          'content': m['content'] as String,
        }).toList();
  }

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // 进入时显示小暖问候
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addAssistantMsg(
        '你好呀～我是小暖 🌸 我可以帮你：\n\n'
        '📝 **生成学习计划**（告诉我学什么、学几天）\n'
        '💰 **帮你记一笔账**（说"花了xx元买xx"）\n'
        '🌙 **生理期建议**（问我"现在适合学习吗"）\n\n'
        '说说看，今天想做什么？',
        intent: 'greeting',
        action: {},
      );
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── 发送消息 ───────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _loading) return;

    _inputCtrl.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _loading = true;
    });
    _scrollToBottom();

    try {
      final resp = await _api.post('/ai/chat', body: {
        'message': text,
        'history': _history.where((m) => m['role'] != 'assistant' || !_messages
            .any((msg) => msg['content'] == m['content'] && msg['intent'] != null))
            .toList(),
      });

      if (resp != null) {
        _addAssistantMsg(
          resp['reply'] ?? '小暖想了想，没想好怎么说～',
          intent: resp['intent'] ?? 'general',
          action: Map<String, dynamic>.from(resp['action'] ?? {}),
        );
      } else {
        _addAssistantMsg(
          '网络好像断了～不过我的离线功能还在，试试说"帮我生成学习计划"？',
          intent: 'general',
          action: {},
        );
      }
    } catch (_) {
      _addAssistantMsg('出了点小问题，稍后再试试吧～', intent: 'general', action: {});
    } finally {
      setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  void _addAssistantMsg(String content,
      {required String intent, required Map<String, dynamic> action}) {
    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': content,
        'intent': intent,
        'action': action,
      });
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── 构建 UI ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(
            radius: 14.r,
            backgroundColor: theme.primaryColor,
            child: Text('暖', style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold)),
          ),
          SizedBox(width: 8.w),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('小暖', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)),
            Text('专注·记账·生理期·学习', style: TextStyle(fontSize: 10.sp, color: Colors.grey[500])),
          ]),
        ]),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 粒子背景（轻柔版）
          const Opacity(opacity: 0.3, child: ParticleBackground()),

          Column(children: [
            // 消息列表
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                itemCount: _messages.length + (_loading ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (_loading && i == _messages.length) {
                    return _buildTypingIndicator();
                  }
                  final msg = _messages[i];
                  if (msg['role'] == 'user') return _buildUserBubble(msg['content']);
                  return _buildAssistantMessage(msg);
                },
              ),
            ),

            // 输入栏
            _buildInputBar(theme),
          ]),
        ],
      ),
    );
  }

  // 用户气泡（右侧）
  Widget _buildUserBubble(String content) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              constraints: BoxConstraints(maxWidth: 260.w),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                  bottomLeft: Radius.circular(16.r),
                  bottomRight: Radius.circular(4.r),
                ),
              ),
              child: Text(content, style: TextStyle(color: Colors.white, fontSize: 14.sp)),
            ),
          ),
          SizedBox(width: 8.w),
          CircleAvatar(radius: 16.r, backgroundColor: Colors.grey[300],
              child: Icon(Icons.person, size: 16.sp, color: Colors.white)),
        ],
      ),
    );
  }

  // 小暖消息（左侧，根据 intent 显示不同卡片）
  Widget _buildAssistantMessage(Map<String, dynamic> msg) {
    final intent = msg['intent'] ?? 'general';
    final action = Map<String, dynamic>.from(msg['action'] ?? {});
    final content = msg['content'] as String;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 小暖头像
          Container(
            width: 32.w, height: 32.w,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(child: Text('暖', style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold))),
          ),
          SizedBox(width: 8.w),

          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 文字回复气泡
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  constraints: BoxConstraints(maxWidth: 280.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4.r),
                      topRight: Radius.circular(16.r),
                      bottomLeft: Radius.circular(16.r),
                      bottomRight: Radius.circular(16.r),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Text(content, style: TextStyle(fontSize: 14.sp, color: Colors.grey[800], height: 1.5)),
                ),

                // 操作卡片（根据 intent 显示）
                if (intent == 'study_plan' && action.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  _StudyPlanCard(action: action, onConfirm: _onConfirmStudyPlan),
                ],
                if (intent == 'accounting' && action.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  _AccountingCard(action: action, onConfirm: _onConfirmAccounting),
                ],
                if (intent == 'period' && action.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  _PeriodAdviceCard(action: action),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 正在输入指示器
  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(children: [
        Container(
          width: 32.w, height: 32.w,
          decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
          child: Center(child: Text('暖', style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold))),
        ),
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _Dot(delay: 0), _Dot(delay: 150), _Dot(delay: 300),
          ]),
        ),
      ]),
    );
  }

  // 底部输入栏
  Widget _buildInputBar(ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: '和小暖说说你想做什么～',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13.sp),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44.w, height: 44.w,
              decoration: BoxDecoration(
                color: _loading ? Colors.grey[300] : theme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.send_rounded, color: Colors.white, size: 20.sp),
            ),
          ),
        ]),
      ),
    );
  }

  // ── 操作确认回调 ───────────────────────────────────────────

  Future<void> _onConfirmStudyPlan(Map<String, dynamic> plan) async {
    // 存到本地 SharedPreferences，HomeScreen 会读取展示
    final resp = await _api.post('/study/plan/set-today', body: plan);
    final ok = resp != null;
    _addAssistantMsg(
      ok ? '好的！学习计划已设为今天的任务，加油～ 💪' : '计划保存到本地了，稍后网络好了再同步～',
      intent: 'general',
      action: {},
    );
  }

  Future<void> _onConfirmAccounting(Map<String, dynamic> data) async {
    final resp = await _api.post('/accounting/add', body: data);
    final ok = resp != null;
    _addAssistantMsg(
      ok ? '记账成功！已记录 ¥${data['amount']}（${data['category']}）💰' : '网络不好，已存到本地，下次联网自动同步～',
      intent: 'general',
      action: {},
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 学习计划确认卡
// ──────────────────────────────────────────────────────────────
class _StudyPlanCard extends StatefulWidget {
  final Map<String, dynamic> action;
  final Future<void> Function(Map<String, dynamic>) onConfirm;

  const _StudyPlanCard({required this.action, required this.onConfirm});

  @override
  State<_StudyPlanCard> createState() => _StudyPlanCardState();
}

class _StudyPlanCardState extends State<_StudyPlanCard> {
  bool _confirmed = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    if (_confirmed) {
      return Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Row(children: [
          Icon(Icons.check_circle, color: Colors.green, size: 18.sp),
          SizedBox(width: 6.w),
          Text('已设为今天的计划！', style: TextStyle(color: Colors.green[700], fontSize: 13.sp)),
        ]),
      );
    }

    final tasks = List<String>.from(widget.action['tasks'] ?? []);
    final subject = widget.action['subject'] ?? widget.action['plan_name'] ?? '学习计划';
    final days = widget.action['total_days'] ?? 7;
    final hours = widget.action['daily_hours'] ?? 2;

    return Container(
      constraints: BoxConstraints(maxWidth: 280.w),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12.r), topRight: Radius.circular(12.r)),
            ),
            child: Row(children: [
              Icon(Icons.menu_book_outlined, size: 15.sp, color: Colors.orange[700]),
              SizedBox(width: 6.w),
              Text('学习计划草稿', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.orange[700])),
            ]),
          ),

          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 计划概要
              Text('📘 $subject', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 4.h),
              Text('共 $days 天 · 每天 $hours 小时', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),

              if (tasks.isNotEmpty) ...[
                SizedBox(height: 8.h),
                ...tasks.take(3).map((t) => Padding(
                  padding: EdgeInsets.only(bottom: 3.h),
                  child: Row(children: [
                    Icon(Icons.circle, size: 6.sp, color: Colors.orange[400]),
                    SizedBox(width: 6.w),
                    Flexible(child: Text(t, style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]))),
                  ]),
                )),
                if (tasks.length > 3)
                  Text('...还有 ${tasks.length - 3} 项任务', style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
              ],

              SizedBox(height: 10.h),
              // 确认按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : () async {
                    setState(() => _loading = true);
                    await widget.onConfirm(widget.action);
                    if (mounted) setState(() { _loading = false; _confirmed = true; });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                  ),
                  child: _loading
                      ? SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('✅ 设为今天的计划', style: TextStyle(fontSize: 13.sp, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 记账确认卡
// ──────────────────────────────────────────────────────────────
class _AccountingCard extends StatefulWidget {
  final Map<String, dynamic> action;
  final Future<void> Function(Map<String, dynamic>) onConfirm;

  const _AccountingCard({required this.action, required this.onConfirm});

  @override
  State<_AccountingCard> createState() => _AccountingCardState();
}

class _AccountingCardState extends State<_AccountingCard> {
  late TextEditingController _amountCtrl;
  late String _category;
  late TextEditingController _noteCtrl;
  bool _confirmed = false;
  bool _loading = false;

  final _categories = ['餐饮', '交通', '学习', '娱乐', '购物', '医疗', '其他'];

  @override
  void initState() {
    super.initState();
    final amount = widget.action['amount'];
    _amountCtrl = TextEditingController(
        text: (amount != null && amount != 0) ? amount.toString() : '');
    _category = widget.action['category'] ?? '其他';
    if (!_categories.contains(_category)) _category = '其他';
    _noteCtrl = TextEditingController(text: widget.action['note'] ?? '');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmed) {
      return Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12.r), border: Border.all(color: Colors.green[200]!)),
        child: Row(children: [
          Icon(Icons.check_circle, color: Colors.green, size: 18.sp),
          SizedBox(width: 6.w),
          Text('记账成功！', style: TextStyle(color: Colors.green[700], fontSize: 13.sp)),
        ]),
      );
    }

    return Container(
      constraints: BoxConstraints(maxWidth: 280.w),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.only(topLeft: Radius.circular(12.r), topRight: Radius.circular(12.r)),
          ),
          child: Row(children: [
            Icon(Icons.account_balance_wallet_outlined, size: 15.sp, color: Colors.green[700]),
            SizedBox(width: 6.w),
            Text('记账确认', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.green[700])),
          ]),
        ),
        Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(children: [
            // 金额
            Row(children: [
              Text('金额', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
              SizedBox(width: 8.w),
              Text('¥', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.green[700])),
              SizedBox(width: 4.w),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 8.w),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.r)),
                  ),
                ),
              ),
            ]),
            SizedBox(height: 8.h),
            // 分类
            Row(children: [
              Text('分类', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
              SizedBox(width: 8.w),
              DropdownButton<String>(
                value: _category,
                isDense: true,
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(fontSize: 13.sp)))).toList(),
                onChanged: (v) => setState(() => _category = v ?? '其他'),
              ),
            ]),
            SizedBox(height: 8.h),
            // 备注
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                hintText: '备注（可选）',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 10.w),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.r)),
              ),
            ),
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : () async {
                  final amount = double.tryParse(_amountCtrl.text.trim());
                  if (amount == null || amount <= 0) {
                    Get.snackbar('提示', '请输入正确的金额', snackPosition: SnackPosition.BOTTOM);
                    return;
                  }
                  setState(() => _loading = true);
                  await widget.onConfirm({
                    'amount': amount,
                    'category': _category,
                    'note': _noteCtrl.text.trim(),
                  });
                  if (mounted) setState(() { _loading = false; _confirmed = true; });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                ),
                child: _loading
                    ? SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('💰 确认记账', style: TextStyle(fontSize: 13.sp, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 生理期建议卡（只展示）
// ──────────────────────────────────────────────────────────────
class _PeriodAdviceCard extends StatelessWidget {
  final Map<String, dynamic> action;
  const _PeriodAdviceCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 280.w),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.pink[50],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.pink[200]!),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.favorite_outline, size: 15.sp, color: Colors.pink[400]),
          SizedBox(width: 6.w),
          Text('暖心建议', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.pink[600])),
        ]),
        SizedBox(height: 8.h),
        Text(action['advice'] ?? '', style: TextStyle(fontSize: 13.sp, color: Colors.grey[700], height: 1.5)),
        if (action['intensity_tip'] != null) ...[
          SizedBox(height: 6.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.pink[100],
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text('📚 ${action['intensity_tip']}', style: TextStyle(fontSize: 11.sp, color: Colors.pink[700])),
          ),
        ],
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 打字中指示器的小圆点（弹跳动画）
// ──────────────────────────────────────────────────────────────
class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _anim = Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7.w, height: 7.w,
          margin: EdgeInsets.symmetric(horizontal: 2.w),
          decoration: BoxDecoration(
            color: Colors.grey[400],
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
