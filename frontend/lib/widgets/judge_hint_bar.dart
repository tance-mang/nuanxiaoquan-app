// ============================================================
// 综合判定提示条 —— C 类规则的视觉出口
// 仅在计时器空闲时显示，不打断正在专注的用户
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../services/today_judge.dart';

class JudgeHintBar extends StatefulWidget {
  /// 用户当前选中的专注秒数。改变时会触发重新判定（这是用户考虑努力强度的时刻）
  final int durationSec;

  const JudgeHintBar({Key? key, required this.durationSec}) : super(key: key);

  @override
  State<JudgeHintBar> createState() => _JudgeHintBarState();
}

class _JudgeHintBarState extends State<JudgeHintBar> {
  JudgeHint? _hint;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(JudgeHintBar old) {
    super.didUpdateWidget(old);
    if (old.durationSec != widget.durationSec) _load();
  }

  Future<void> _load() async {
    final gender = Get.find<AppController>().userGender.value;
    final h = await TodayJudge.compute(
      durationSec: widget.durationSec,
      userGender: gender,
    );
    if (!mounted) return;
    setState(() {
      _hint = h;
      _loaded = true;
    });
  }

  Color _tint(int kind) {
    switch (kind) {
      case 0:
        return const Color(0xFFE08A6E); // 暖橘 / 轻量
      case 1:
        return const Color(0xFF6CB87C); // 绿 / 状态好
      case 2:
        return const Color(0xFFB48FD2); // 粉紫 / 周期相关
      default:
        return const Color(0xFF888888);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _hint == null) return const SizedBox.shrink();
    final tint = _tint(_hint!.kind);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w, vertical: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: tint.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: tint.withOpacity(0.30)),
      ),
      child: Text(
        _hint!.text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.sp,
          color: tint,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
