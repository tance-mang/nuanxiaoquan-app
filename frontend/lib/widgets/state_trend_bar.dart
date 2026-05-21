// ============================================================
// 最近 7 天状态趋势迷你条
//
// 横向 7 个小柱：每天高度 = 精力 / 10，颜色 = 由状态决定
//   - 正面（精力≥7 且无负面 condition）→ 绿
//   - 负面（痛经/焦虑/有点累 或 精力≤4）→ 暖橘
//   - 中性                              → 灰
// 没数据的日子显示空槽
//
// 数据来自 SharedPreferences 'daily_state_<YYYY-MM-DD>'
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StateTrendBar extends StatefulWidget {
  const StateTrendBar({Key? key}) : super(key: key);

  @override
  State<StateTrendBar> createState() => _StateTrendBarState();
}

class _DayState {
  final DateTime date;
  final int? energy;
  final String? condition;
  _DayState(this.date, this.energy, this.condition);
  bool get hasData => energy != null;
}

class _StateTrendBarState extends State<StateTrendBar> {
  List<_DayState> _days = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = <_DayState>[];
    final today = DateTime.now();
    for (int offset = 6; offset >= 0; offset--) {
      final d = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: offset));
      final key = 'daily_state_${d.toIso8601String().substring(0, 10)}';
      final raw = prefs.getString(key);
      if (raw == null) {
        list.add(_DayState(d, null, null));
      } else {
        try {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          list.add(_DayState(
            d,
            m['energy'] as int?,
            m['condition'] as String?,
          ));
        } catch (_) {
          list.add(_DayState(d, null, null));
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _days = list;
      _loaded = true;
    });
  }

  Color _colorFor(_DayState d) {
    if (!d.hasData) return const Color(0xFFE5E7EB);
    final e = d.energy!;
    final c = d.condition;
    final neg = c == '痛经不适' || c == '焦虑' || c == '有点累';
    if (neg || e <= 4) return const Color(0xFFE08A6E);
    if (e >= 7 && c != '焦虑' && c != '痛经不适' && c != '有点累') {
      return const Color(0xFF6CB87C);
    }
    return const Color(0xFF9CA3AF);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return SizedBox(height: 70.h);
    // 至少有 1 天数据才显示
    final dataDays = _days.where((d) => d.hasData).length;
    if (dataDays == 0) return const SizedBox.shrink();

    const labels = ['日', '一', '二', '三', '四', '五', '六'];

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.fromLTRB(14.w, 11.h, 14.w, 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded,
                  size: 14.sp, color: Colors.grey[500]),
              SizedBox(width: 6.w),
              Text(
                '最近 7 天精力趋势',
                style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                '$dataDays / 7 天有记录',
                style: TextStyle(fontSize: 10.sp, color: Colors.grey[400]),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          // 柱状区：每柱高度 1..10 → 8..36 px，对齐到底部
          SizedBox(
            height: 40.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _days.map((d) {
                final color = _colorFor(d);
                final h = d.hasData
                    ? (8 + (d.energy! - 1) / 9.0 * 28).h
                    : 4.h;
                final isToday = d.date.day == DateTime.now().day &&
                    d.date.month == DateTime.now().month;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: d.hasData
                                ? color
                                : color.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(3.r),
                            border: isToday
                                ? Border.all(
                                    color: color.withOpacity(0.6),
                                    width: 1.5,
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            children: _days.map((d) {
              final label = labels[d.date.weekday % 7];
              final isToday = d.date.day == DateTime.now().day &&
                  d.date.month == DateTime.now().month;
              return Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: isToday
                        ? const Color(0xFF111827)
                        : Colors.grey[400],
                    fontWeight: isToday
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
