// ============================================================
// 文件：widgets/quote_card.dart
// 作用：语录卡片组件（首页 + 知识小馆都用到）
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QuoteCard extends StatelessWidget {
  // 语录数据（Map格式，包含content/author/category等字段）
  final Map<String, dynamic> quote;

  // 是否显示收藏/分享操作按钮（知识小馆里显示，首页迷你版不显示）
  final bool showActions;

  const QuoteCard({
    Key? key,
    required this.quote,
    this.showActions = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        // 渐变背景，让语录卡片更有氛围感
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.1),
            Theme.of(context).primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 引号装饰符
          Text(
            '"',
            style: TextStyle(
              fontSize: 40.sp,
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              height: 0.5,
            ),
          ),

          SizedBox(height: 8.h),

          // 语录正文（温柔治愈文案）
          Text(
            quote['content'] ?? '',
            style: TextStyle(
              fontSize: 16.sp,
              color: const Color(0xFF333333),
              height: 1.6, // 行高，让文字不拥挤
              fontWeight: FontWeight.w500,
            ),
          ),

          SizedBox(height: 12.h),

          // 作者信息
          Row(
            children: [
              Container(
                width: 20.w,
                height: 1.h,
                color: Theme.of(context).primaryColor.withOpacity(0.4),
              ),
              SizedBox(width: 8.w),
              Text(
                quote['author'] ?? '小暖',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),

          // 来源为"一言"时显示来源标识（遵守 hitokoto.cn 开源协议要求）
          if (quote['source'] == '一言') ...[
            SizedBox(height: 6.h),
            Row(
              children: [
                Icon(Icons.link, size: 11.sp, color: Colors.grey[400]),
                SizedBox(width: 4.w),
                Text(
                  '预览来源：一言 hitokoto.cn',
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey[400]),
                ),
              ],
            ),
          ],

          // 操作按钮（收藏/分享），在知识小馆显示
          if (showActions) ...[
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 收藏按钮
                IconButton(
                  icon: Icon(Icons.bookmark_outline, size: 20.sp),
                  onPressed: () {
                    // TODO: 收藏语录 API
                  },
                  color: Colors.grey[500],
                ),
                // 分享按钮
                IconButton(
                  icon: Icon(Icons.share_outlined, size: 20.sp),
                  onPressed: () {
                    // TODO: 生成语录图片海报并分享
                  },
                  color: Colors.grey[500],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
