// ============================================================
// 文件：screens/qa_screen.dart
// 作用：暖圈答疑页面（内置在知识小馆里的一个 Tab）
//
// 设计说明：
//   · 入口在"知识小馆"页面的 Tab 栏，不单独占一个底部导航
//   · 用户可以提问，选择分类（记账/生理期/学习/资源/其他）
//   · 管理员（开发者）用同一个 APP 登录，显示额外的"回复"按钮
//   · 官方回复标注"暖圈官方 ✓"徽章，一眼可识
//   · 已有官方回复的问题显示"已解答"绿色标签
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';
import '../controllers/app_controller.dart';

class QAScreen extends StatefulWidget {
  const QAScreen({Key? key}) : super(key: key);

  @override
  State<QAScreen> createState() => _QAScreenState();
}

class _QAScreenState extends State<QAScreen> with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  final _appController = Get.find<AppController>();

  List<dynamic> _questions = [];
  bool _isLoading = true;
  String _selectedCategory = '全部';

  // 分类选项（和后端保持一致）
  final _categories = ['全部', '记账', '生理期', '学习', '资源', '其他'];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.get(
        '/qa/list?category=${Uri.encodeComponent(_selectedCategory)}'
      );
      setState(() {
        _questions = result?['content'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ─── 分类筛选条 ───
          _buildCategoryBar(theme),
          // ─── 问题列表 ───
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadQuestions,
                    child: _questions.isEmpty
                        ? _buildEmptyHint()
                        : ListView.builder(
                            padding: EdgeInsets.all(12.w),
                            itemCount: _questions.length,
                            itemBuilder: (ctx, i) => _buildQuestionCard(_questions[i], theme),
                          ),
                  ),
          ),
        ],
      ),
      // 提问按钮（管理员时显示"回复"图标）
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAskDialog,
        icon: const Icon(Icons.edit_outlined),
        label: Text('提问', style: TextStyle(fontSize: 14.sp)),
        backgroundColor: theme.primaryColor,
      ),
    );
  }

  // 分类筛选条
  Widget _buildCategoryBar(ThemeData theme) {
    return Container(
      height: 40.h,
      margin: EdgeInsets.symmetric(vertical: 8.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        itemCount: _categories.length,
        itemBuilder: (ctx, i) {
          final cat = _categories[i];
          final selected = cat == _selectedCategory;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = cat);
              _loadQuestions();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: 8.w),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: selected ? theme.primaryColor : theme.cardColor,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: selected ? theme.primaryColor : Colors.grey.shade300,
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: selected ? Colors.white : Colors.grey[600],
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 问题卡片
  Widget _buildQuestionCard(Map<String, dynamic> question, ThemeData theme) {
    final hasOfficial = question['hasOfficialReply'] == true;
    final isAdmin = _appController.isAdmin;  // 从控制器判断是否管理员

    return Card(
      margin: EdgeInsets.only(bottom: 10.h),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: () => _openDetail(question),
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 问题内容
              Text(
                question['content'] ?? '',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8.h),

              // 底部：用户 + 时间 + 标签 + 管理员回复按钮
              Row(
                children: [
                  // 分类标签
                  _buildTag(question['category'] ?? '其他', theme.primaryColor.withOpacity(0.1),
                      theme.primaryColor),
                  SizedBox(width: 6.w),

                  // 已解答标签
                  if (hasOfficial)
                    _buildTag('已解答', Colors.green.shade50, Colors.green),

                  const Spacer(),

                  // 管理员专属"回复"按钮（普通用户看不到）
                  if (isAdmin)
                    TextButton.icon(
                      onPressed: () => _showReplyDialog(question['id']),
                      icon: Icon(Icons.reply, size: 14.sp, color: theme.primaryColor),
                      label: Text('官方回复', style: TextStyle(fontSize: 12.sp, color: theme.primaryColor)),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        minimumSize: Size.zero,
                      ),
                    ),

                  // 点赞数
                  Row(
                    children: [
                      Icon(Icons.thumb_up_outlined, size: 12.sp, color: Colors.grey[400]),
                      SizedBox(width: 3.w),
                      Text('${question['likes'] ?? 0}',
                          style: TextStyle(fontSize: 11.sp, color: Colors.grey[400])),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color bg, Color text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4.r)),
      child: Text(label, style: TextStyle(fontSize: 11.sp, color: text)),
    );
  }

  // 空状态提示
  Widget _buildEmptyHint() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.help_outline, size: 48.sp, color: Colors.grey[300]),
          SizedBox(height: 12.h),
          Text('还没有问题，来第一个提问吧～',
              style: TextStyle(color: Colors.grey[400], fontSize: 14.sp)),
        ],
      ),
    );
  }

  // 进入问题详情（显示所有回复）
  void _openDetail(Map<String, dynamic> question) {
    Get.to(() => _QADetailPage(questionId: question['id']));
  }

  // 提问弹框
  void _showAskDialog() {
    final contentCtrl = TextEditingController();
    String selectedCat = '其他';

    Get.dialog(
      AlertDialog(
        title: Text('提问', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 分类选择
            DropdownButtonFormField<String>(
              value: selectedCat,
              decoration: const InputDecoration(labelText: '问题分类'),
              items: ['记账', '生理期', '学习', '资源', '其他']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => selectedCat = v ?? '其他',
            ),
            SizedBox(height: 12.h),
            // 内容输入
            TextField(
              controller: contentCtrl,
              maxLines: 4,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: '描述你的问题，尽量说清楚～',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (contentCtrl.text.trim().isEmpty) return;
              try {
                await _apiService.post('/qa/ask', body: {
                  'content': contentCtrl.text.trim(),
                  'category': selectedCat,
                });
                Get.back();
                Get.snackbar('提问成功', '暖圈君会尽快回答～',
                    backgroundColor: Colors.green, colorText: Colors.white);
                _loadQuestions();
              } catch (e) {
                Get.snackbar('提问失败', '请稍后重试');
              }
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }

  // 管理员回复弹框（普通用户永远不会看到这个）
  void _showReplyDialog(int postId) {
    final contentCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.verified, color: Theme.of(context).primaryColor, size: 18.sp),
            SizedBox(width: 6.w),
            Text('官方回复', style: TextStyle(fontSize: 16.sp)),
          ],
        ),
        content: TextField(
          controller: contentCtrl,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: '输入官方回复...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (contentCtrl.text.trim().isEmpty) return;
              try {
                await _apiService.post('/qa/reply', body: {
                  'parentId': postId,
                  'content': contentCtrl.text.trim(),
                });
                Get.back();
                Get.snackbar('回复成功', '', backgroundColor: Colors.green, colorText: Colors.white);
                _loadQuestions();
              } catch (e) {
                Get.snackbar('回复失败', '请检查网络');
              }
            },
            child: const Text('发布官方回复'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 问题详情页（显示所有回复）
// ============================================================
class _QADetailPage extends StatefulWidget {
  final int questionId;
  const _QADetailPage({required this.questionId});

  @override
  State<_QADetailPage> createState() => _QADetailPageState();
}

class _QADetailPageState extends State<_QADetailPage> {
  final _apiService = ApiService();
  Map<String, dynamic>? _question;
  List<dynamic> _replies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final result = await _apiService.get('/qa/detail/${widget.questionId}');
      setState(() {
        _question = result?['question'];
        _replies = result?['replies'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('答疑详情'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                // 原始问题
                if (_question != null) _buildQuestion(_question!, context),
                SizedBox(height: 16.h),
                if (_replies.isNotEmpty)
                  Text('全部回复 (${_replies.length})',
                      style: TextStyle(fontSize: 13.sp, color: Colors.grey[500])),
                SizedBox(height: 8.h),
                ..._replies.map((r) => _buildReply(r, context)),
                if (_replies.isEmpty)
                  Center(
                    child: Text('还没有回复，等待暖圈君～',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14.sp)),
                  ),
              ],
            ),
    );
  }

  Widget _buildQuestion(Map<String, dynamic> q, BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, size: 16.sp, color: Theme.of(context).primaryColor),
              SizedBox(width: 4.w),
              Text(q['userNickname'] ?? '匿名用户',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[500])),
            ],
          ),
          SizedBox(height: 8.h),
          Text(q['content'] ?? '', style: TextStyle(fontSize: 15.sp)),
        ],
      ),
    );
  }

  Widget _buildReply(Map<String, dynamic> reply, BuildContext context) {
    final isOfficial = reply['isOfficial'] == true;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isOfficial
            ? Theme.of(context).primaryColor.withOpacity(0.05)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: isOfficial
              ? Theme.of(context).primaryColor.withOpacity(0.2)
              : Colors.grey.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isOfficial) ...[
                Icon(Icons.verified, size: 14.sp, color: Theme.of(context).primaryColor),
                SizedBox(width: 4.w),
              ],
              Text(
                isOfficial ? '暖圈官方' : (reply['userNickname'] ?? '匿名'),
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: isOfficial ? FontWeight.w600 : FontWeight.normal,
                  color: isOfficial ? Theme.of(context).primaryColor : Colors.grey[500],
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(reply['content'] ?? '', style: TextStyle(fontSize: 14.sp)),
        ],
      ),
    );
  }
}
