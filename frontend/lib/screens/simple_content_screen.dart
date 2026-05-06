import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 通用内容列表页（我的发布 / 我的收藏 / 我的点赞 / 回收站）
class SimpleContentScreen extends StatelessWidget {
  final String title;
  final IconData emptyIcon;
  final String emptyText;

  const SimpleContentScreen({
    Key? key,
    required this.title,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyText = '这里还没有内容',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 64.sp, color: Colors.grey[300]),
            SizedBox(height: 16.h),
            Text(emptyText,
                style: TextStyle(color: Colors.grey[500], fontSize: 15.sp)),
            SizedBox(height: 8.h),
            Text('登录后同步你的内容',
                style: TextStyle(color: Colors.grey[400], fontSize: 13.sp)),
          ],
        ),
      ),
    );
  }
}
