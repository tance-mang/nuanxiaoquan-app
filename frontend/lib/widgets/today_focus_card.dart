// ============================================================
// 今日累计专注卡（首页）
//
// 显示今天累计的专注时间（来自 SharedPreferences focus_seconds_<date>）
// 这是 lobby + room 两个 StudyRoomController 共同累加的。
// 重启 app / 刷新页面 都不会丢，给用户"我今天确实做了事"的心理锚点。
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TodayFocusCard extends StatefulWidget {
  const TodayFocusCard({Key? key}) : super(key: key);

  @override
  State<TodayFocusCard> createState() => _TodayFocusCardState();
}

class _TodayFocusCardState extends State<TodayFocusCard> {
  int _seconds = 0;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    // 计时进行中时，每 12 秒刷新一次显示（与 StudyRoomController 的 10 秒持久化匹配）
    _refresh = Timer.periodic(const Duration(seconds: 12), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final key =
        'focus_seconds_${DateTime.now().toIso8601String().substring(0, 10)}';
    final s = prefs.getInt(key) ?? 0;
    if (!mounted) return;
    setState(() => _seconds = s);
  }

  String _formatMinutes(int sec) {
    if (sec < 60) return '$sec 秒';
    final mins = sec ~/ 60;
    if (mins < 60) return '$mins 分钟';
    final hours = mins ~/ 60;
    final remMin = mins % 60;
    if (remMin == 0) return '$hours 小时';
    return '$hours 小时 $remMin 分';
  }

  @override
  Widget build(BuildContext context) {
    if (_seconds == 0) return const SizedBox.shrink();
    final primary = Theme.of(context).primaryColor;
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.fromLTRB(14.w, 11.h, 14.w, 11.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withOpacity(0.10),
            primary.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: primary.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withOpacity(0.14),
            ),
            child: Icon(Icons.timer_outlined, size: 18.sp, color: primary),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今日已专注',
                    style: TextStyle(
                        fontSize: 11.sp, color: Colors.grey[500])),
                SizedBox(height: 2.h),
                Text(
                  _formatMinutes(_seconds),
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${(_seconds / 60).toStringAsFixed(0)} 分',
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
