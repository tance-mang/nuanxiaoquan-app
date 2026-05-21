// ============================================================
// 兴趣偏好设置（C 类数据输入 · 个性化干预的来源）
//
// 让用户选择愿意在专注疲劳时尝试的微休息活动。
// BehaviorTracker 触发微休息弹窗时，会从这里读取启用的活动池。
//
// 存储：
//   - SharedPreferences key 'interest_activities_v1' (JSON list of activity ids)
//   - 默认全开 4 个内置活动
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/app_controller.dart';
import '../services/behavior_tracker.dart';

/// 单条兴趣活动（id 用于持久化，title/desc/emoji 用于显示）
class InterestActivity {
  final String id;
  final String emoji;
  final String title;
  final String desc;
  final bool isBuiltIn;
  const InterestActivity({
    required this.id,
    required this.emoji,
    required this.title,
    required this.desc,
    this.isBuiltIn = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'emoji': emoji,
        'title': title,
        'desc': desc,
        'isBuiltIn': isBuiltIn,
      };

  factory InterestActivity.fromJson(Map<String, dynamic> j) =>
      InterestActivity(
        id: j['id'] as String,
        emoji: j['emoji'] as String,
        title: j['title'] as String,
        desc: j['desc'] as String? ?? '',
        isBuiltIn: j['isBuiltIn'] as bool? ?? false,
      );
}

/// 全 App 共享：内置默认活动
const List<InterestActivity> kBuiltInActivities = [
  InterestActivity(
    id: 'music',
    emoji: '🎵',
    title: '听 5 分钟音乐',
    desc: '挑一首喜欢的，让大脑放空',
    isBuiltIn: true,
  ),
  InterestActivity(
    id: 'stretch',
    emoji: '🧘',
    title: '伸展 2 分钟',
    desc: '颈肩 / 腰背 / 眼睛各放松一下',
    isBuiltIn: true,
  ),
  InterestActivity(
    id: 'doodle',
    emoji: '🎨',
    title: '简单涂鸦放空',
    desc: '随手在纸上画几笔，让思维换轨',
    isBuiltIn: true,
  ),
  InterestActivity(
    id: 'tea',
    emoji: '☕',
    title: '泡一杯热饮',
    desc: '起身倒水的 3 分钟，比硬撑有用',
    isBuiltIn: true,
  ),
];

/// 加载用户当前的活动池（启用项 + 自定义项），永不返回空——空池没意义
Future<List<InterestActivity>> loadInterestActivities() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('interest_activities_v1');
  if (raw == null) return List<InterestActivity>.from(kBuiltInActivities);
  try {
    final list = (jsonDecode(raw) as List)
        .map((j) =>
            InterestActivity.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
    if (list.isEmpty) return List<InterestActivity>.from(kBuiltInActivities);
    return list;
  } catch (_) {
    return List<InterestActivity>.from(kBuiltInActivities);
  }
}

Future<void> _saveActivities(List<InterestActivity> list) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      'interest_activities_v1',
      jsonEncode(list.map((a) => a.toJson()).toList()));
}

// ============================================================
// 偏好编辑页
// ============================================================

class InterestPrefsScreen extends StatefulWidget {
  const InterestPrefsScreen({Key? key}) : super(key: key);

  @override
  State<InterestPrefsScreen> createState() => _InterestPrefsScreenState();
}

class _InterestPrefsScreenState extends State<InterestPrefsScreen> {
  List<InterestActivity> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await loadInterestActivities();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await _saveActivities(_items);
  }

  void _removeAt(int i) async {
    if (_items[i].isBuiltIn) {
      // 内置项不真正删除，而是重置为默认全开（避免空池）
      Get.snackbar('提示', '内置活动不可删除，可以添加自己的替代它',
          snackPosition: SnackPosition.TOP);
      return;
    }
    setState(() => _items.removeAt(i));
    await _save();
  }

  Future<void> _addCustom() async {
    final emojiCtrl = TextEditingController(text: '🌟');
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('添加自定义活动'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 60.w,
                  child: TextField(
                    controller: emojiCtrl,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: 'Emoji'),
                    maxLength: 2,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: TextField(
                    controller: titleCtrl,
                    decoration:
                        const InputDecoration(labelText: '活动名（如 散步）'),
                    maxLength: 12,
                  ),
                ),
              ],
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: '一句话说明（可选）'),
              maxLength: 28,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消')),
        ElevatedButton(
            onPressed: () => Get.back(result: true), child: const Text('添加')),
      ],
    ));
    if (ok != true) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;
    final newItem = InterestActivity(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      emoji: emojiCtrl.text.trim().isEmpty ? '🌟' : emojiCtrl.text.trim(),
      title: title,
      desc: descCtrl.text.trim(),
    );
    setState(() => _items.add(newItem));
    await _save();
  }

  Future<void> _resetToDefault() async {
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('恢复默认'),
      content: const Text('将清除你添加的自定义活动，恢复 4 个内置活动。确定继续？'),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false), child: const Text('取消')),
        TextButton(
            onPressed: () => Get.back(result: true),
            child:
                const Text('恢复', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true) {
      setState(() => _items = List<InterestActivity>.from(kBuiltInActivities));
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('微休息偏好'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _resetToDefault,
            child: const Text('恢复默认', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 32.h),
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: primary.withOpacity(0.18)),
                  ),
                  child: Obx(() {
                    final ac = Get.find<AppController>();
                    final mins = ac.microRestIdleMinutes.value;
                    return Text(
                      '当小暖判断你在自习室专注过久（连续 $mins 分钟没操作），\n会从这个列表里挑一个活动建议你尝试。\n你可以随时增删，列表里至少保留 1 项。',
                      style: TextStyle(
                          fontSize: 12.sp,
                          color: const Color(0xFF374151),
                          height: 1.55),
                    );
                  }),
                ),
                SizedBox(height: 12.h),
                // 干预总开关
                _buildIntervenSettings(primary),
                SizedBox(height: 10.h),
                // 立即预览小暖提示长什么样（不用等 3 分钟）
                InkWell(
                  onTap: () {
                    try {
                      Get.find<BehaviorTracker>().previewMicroRest();
                    } catch (_) {}
                  },
                  borderRadius: BorderRadius.circular(10.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 14.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined,
                            size: 16.sp, color: Colors.grey[600]),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            '预览小暖会怎么提示我',
                            style: TextStyle(
                                fontSize: 12.5.sp,
                                color: const Color(0xFF374151),
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 16.sp, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                ..._items.asMap().entries.map((e) {
                  final i = e.key;
                  final a = e.value;
                  return _ActivityCard(
                    activity: a,
                    onDelete: () => _removeAt(i),
                  );
                }),
                SizedBox(height: 14.h),
                // 添加自定义活动
                InkWell(
                  onTap: _addCustom,
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: primary.withOpacity(0.30),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded,
                            color: primary, size: 18.sp),
                        SizedBox(width: 6.w),
                        Text(
                          '添加自定义活动',
                          style: TextStyle(
                              fontSize: 13.sp,
                              color: primary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // 干预开关 + 阈值滑块
  Widget _buildIntervenSettings(Color primary) {
    final ac = Get.find<AppController>();
    return Obx(() {
      final enabled = ac.microRestEnabled.value;
      final mins = ac.microRestIdleMinutes.value;
      return Container(
        padding: EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 10.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            // 开关
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('启用微休息提示',
                  style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827))),
              subtitle: Text(
                  enabled
                      ? '当前会在 $mins 分钟无操作时柔和地提醒你'
                      : '完全不打扰，全靠你自己掌握节奏',
                  style: TextStyle(
                      fontSize: 11.sp, color: Colors.grey[500])),
              value: enabled,
              onChanged: (v) => ac.setMicroRestEnabled(v),
            ),
            // 阈值滑块（开关关闭时禁用）
            Opacity(
              opacity: enabled ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !enabled,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('提示阈值',
                              style: TextStyle(
                                  fontSize: 12.sp,
                                  color: const Color(0xFF374151),
                                  fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Text('$mins 分钟',
                              style: TextStyle(
                                  fontSize: 12.sp,
                                  color: primary,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: primary,
                          inactiveTrackColor: Colors.grey.shade200,
                          thumbColor: primary,
                          overlayColor: primary.withOpacity(0.15),
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: mins.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          onChanged: (v) =>
                              ac.setMicroRestIdleMinutes(v.round()),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('1 分钟',
                                style: TextStyle(
                                    fontSize: 9.sp,
                                    color: Colors.grey[400])),
                            Text('10 分钟',
                                style: TextStyle(
                                    fontSize: 9.sp,
                                    color: Colors.grey[400])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _ActivityCard extends StatelessWidget {
  final InterestActivity activity;
  final VoidCallback onDelete;
  const _ActivityCard({required this.activity, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 8.w, 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Text(activity.emoji, style: TextStyle(fontSize: 22.sp)),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(activity.title,
                        style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111827))),
                    if (activity.isBuiltIn) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 5.w, vertical: 1.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text('内置',
                            style: TextStyle(
                                fontSize: 9.sp, color: Colors.grey[600])),
                      ),
                    ],
                  ],
                ),
                if (activity.desc.isNotEmpty) ...[
                  SizedBox(height: 3.h),
                  Text(activity.desc,
                      style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey[500],
                          height: 1.4)),
                ],
              ],
            ),
          ),
          if (!activity.isBuiltIn)
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18.sp, color: Colors.grey[400]),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
