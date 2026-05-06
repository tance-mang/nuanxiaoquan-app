import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/tap_scale.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({Key? key}) : super(key: key);

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _contentCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  List<Map<String, dynamic>> _feedbacks = [];
  String _selectedType = '功能建议';
  bool _submitting = false;

  static const _types = ['功能建议', 'Bug反馈', '内容问题', '其他'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('warm_feedbacks') ?? [];
    setState(() {
      _feedbacks = raw.map((s) => Map<String, dynamic>.from(jsonDecode(s))).toList();
      _feedbacks.sort((a, b) => (b['ts'] as int).compareTo(a['ts'] as int));
    });
  }

  Future<void> _submit() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写反馈内容'), duration: Duration(seconds: 2)),
      );
      return;
    }
    setState(() => _submitting = true);
    final item = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'type': _selectedType,
      'content': content,
      'contact': _contactCtrl.text.trim(),
      'status': '待处理',
    };
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('warm_feedbacks') ?? [];
    raw.add(jsonEncode(item));
    await prefs.setStringList('warm_feedbacks', raw);
    _contentCtrl.clear();
    _contactCtrl.clear();
    setState(() {
      _submitting = false;
      _selectedType = '功能建议';
    });
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('感谢你的反馈！我们会认真查看～'),
        backgroundColor: Colors.green.shade400,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('意见反馈')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            // ── 提交表单 ─────────────────────────
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('提交新反馈',
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
                  SizedBox(height: 14.h),

                  // 类型选择
                  Text('反馈类型', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 8.w,
                    children: _types.map((t) {
                      final selected = t == _selectedType;
                      return TapScale(
                        scale: 0.93,
                        onTap: () => setState(() => _selectedType = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: selected ? theme.primaryColor : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: selected ? theme.primaryColor : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(t,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: selected ? Colors.white : Colors.grey[600],
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              )),
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 14.h),

                  // 反馈内容
                  Text('反馈内容 *', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                  SizedBox(height: 6.h),
                  TextField(
                    controller: _contentCtrl,
                    maxLines: 4,
                    maxLength: 500,
                    style: TextStyle(fontSize: 13.sp),
                    decoration: InputDecoration(
                      hintText: '请详细描述你的建议或遇到的问题…',
                      hintStyle: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),

                  SizedBox(height: 10.h),

                  // 联系方式（选填）
                  Text('联系方式（选填）', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                  SizedBox(height: 6.h),
                  TextField(
                    controller: _contactCtrl,
                    maxLength: 60,
                    style: TextStyle(fontSize: 13.sp),
                    decoration: InputDecoration(
                      hintText: '微信 / 邮箱，方便我们联系你',
                      hintStyle: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  SizedBox(
                    width: double.infinity,
                    height: 44.h,
                    child: TapScale(
                      onTap: _submitting ? null : _submit,
                      child: ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
                          elevation: 0,
                        ),
                        child: _submitting
                            ? SizedBox(
                                width: 20.w, height: 20.w,
                                child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text('提交反馈', style: TextStyle(fontSize: 15.sp, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.h),

            // ── 历史反馈 ─────────────────────────
            if (_feedbacks.isNotEmpty) ...[
              Text('我的反馈记录',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              SizedBox(height: 10.h),
              ..._feedbacks.map((f) => _buildFeedbackItem(f, theme)),
            ] else ...[
              Center(
                child: Column(
                  children: [
                    SizedBox(height: 32.h),
                    Icon(Icons.feedback_outlined, size: 52.sp, color: Colors.grey[200]),
                    SizedBox(height: 12.h),
                    Text('还没有提交过反馈', style: TextStyle(color: Colors.grey[400], fontSize: 14.sp)),
                    SizedBox(height: 6.h),
                    Text('你的每一条建议都会让暖小圈更好 ☁️',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12.sp)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackItem(Map<String, dynamic> f, ThemeData theme) {
    final dt = DateTime.fromMillisecondsSinceEpoch(f['ts'] as int);
    final dateStr = '${dt.month}-${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final status = f['status'] as String? ?? '待处理';
    final statusColor = status == '已处理' ? Colors.green : Colors.orange;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(f['type'] ?? '', style: TextStyle(fontSize: 10.sp, color: theme.primaryColor)),
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(status, style: TextStyle(fontSize: 10.sp, color: statusColor)),
            ),
            const Spacer(),
            Text(dateStr, style: TextStyle(fontSize: 11.sp, color: Colors.grey[400])),
          ]),
          SizedBox(height: 8.h),
          Text(f['content'] ?? '',
              style: TextStyle(fontSize: 13.sp, color: const Color(0xFF2D2D2D), height: 1.5)),
          if ((f['contact'] as String? ?? '').isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text('联系方式：${f['contact']}',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
          ],
          SizedBox(height: 6.h),
          Row(children: [
            Icon(Icons.reply_outlined, size: 13.sp, color: Colors.grey[400]),
            SizedBox(width: 4.w),
            Text('官方回复：感谢你的反馈，我们会认真改进！',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
          ]),
        ],
      ),
    );
  }
}
