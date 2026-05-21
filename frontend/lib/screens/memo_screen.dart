import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/tap_scale.dart';

class MemoScreen extends StatefulWidget {
  const MemoScreen({Key? key}) : super(key: key);

  @override
  State<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends State<MemoScreen> {
  List<Map<String, dynamic>> _memos = [];
  static const _key = 'warm_memos';

  @override
  void initState() {
    super.initState();
    _load().then((_) => _maybeOpenPrefilledEditor());
  }

  /// 从知识小馆等页面跳过来 + 带预填内容时，自动打开编辑器
  void _maybeOpenPrefilledEditor() {
    final args = Get.arguments;
    if (args is Map &&
        (args['prefill_title'] != null || args['prefill_content'] != null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEditor(existing: {
          'title': args['prefill_title'] ?? '',
          'content': args['prefill_content'] ?? '',
        });
      });
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      setState(() {
        _memos = List<Map<String, dynamic>>.from(jsonDecode(raw));
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_memos));
  }

  void _showEditor({Map<String, dynamic>? existing, int? index}) {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final contentCtrl = TextEditingController(text: existing?['content'] ?? '');

    Get.bottomSheet(
      Container(
        height: MediaQuery.of(Get.context!).size.height * 0.75,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              existing == null ? '新建暖记' : '编辑暖记',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                hintText: '标题（选填）',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              ),
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: TextField(
                controller: contentCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: '写下你想记录的内容…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: EdgeInsets.all(14.w),
                ),
                style: TextStyle(fontSize: 14.sp, height: 1.6),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    child: const Text('取消'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final content = contentCtrl.text.trim();
                      if (content.isEmpty) {
                        Get.snackbar('提示', '内容不能为空',
                            snackPosition: SnackPosition.TOP);
                        return;
                      }
                      final now = DateTime.now();
                      final entry = {
                        'id': existing?['id'] ?? now.millisecondsSinceEpoch.toString(),
                        'title': titleCtrl.text.trim().isEmpty
                            ? '无标题'
                            : titleCtrl.text.trim(),
                        'content': content,
                        'updatedAt': now.toIso8601String(),
                      };
                      setState(() {
                        if (index != null) {
                          _memos[index] = entry;
                        } else {
                          _memos.insert(0, entry);
                        }
                      });
                      _save();
                      Get.back();
                    },
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _delete(int index) {
    Get.dialog(AlertDialog(
      title: const Text('删除这条暖记？'),
      content: const Text('删除后不可恢复'),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('取消')),
        TextButton(
          onPressed: () {
            Get.back();
            setState(() => _memos.removeAt(index));
            _save();
          },
          child: const Text('删除', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('暖记'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditor(),
          ),
        ],
      ),
      body: _memos.isEmpty
          ? _buildEmpty(primary)
          : ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: _memos.length,
              itemBuilder: (ctx, i) => _buildCard(_memos[i], i, primary),
            ),
      floatingActionButton: _memos.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showEditor(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildEmpty(Color primary) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.note_alt_outlined, size: 64.sp, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text('还没有暖记', style: TextStyle(color: Colors.grey[500], fontSize: 15.sp)),
          SizedBox(height: 8.h),
          Text('点击右上角 + 新建', style: TextStyle(color: Colors.grey[400], fontSize: 13.sp)),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () => _showEditor(),
            icon: const Icon(Icons.add),
            label: const Text('新建暖记'),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> memo, int index, Color primary) {
    final dt = DateTime.tryParse(memo['updatedAt'] ?? '');
    final dateStr = dt != null
        ? '${dt.month}/${dt.day}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';

    return TapScale(
      onTap: () => _showEditor(existing: memo, index: index),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    memo['title'] ?? '无标题',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => _delete(index),
                  child: Icon(Icons.delete_outline,
                      size: 18.sp, color: Colors.grey[400]),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              memo['content'] ?? '',
              style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.grey[600],
                  height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8.h),
            Text(
              dateStr,
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}
