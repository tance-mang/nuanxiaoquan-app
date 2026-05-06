import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../themes/app_themes.dart';
import '../widgets/tap_scale.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _sectionTitle('个人偏好'),
          _buildGenderSection(context, ctrl),
          SizedBox(height: 8.h),
          _sectionTitle('主题换肤'),
          _buildThemeSection(context, ctrl),
          SizedBox(height: 8.h),
          _sectionTitle('小暖 AI'),
          _buildAiSection(ctrl),
          SizedBox(height: 8.h),
          _sectionTitle('隐私与安全'),
          _buildPrivacySection(),
          SizedBox(height: 8.h),
          _sectionTitle('关于'),
          _buildAboutSection(),
          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 20.h, 0, 8.h),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 13.sp,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildGenderSection(BuildContext context, AppController ctrl) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r)),
      child: Obx(() {
        final gender = ctrl.userGender.value;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('我的性别', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500)),
          SizedBox(height: 4.h),
          Text('选择"女生"后，将解锁「暖圈关怀」生理期管理功能',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
          SizedBox(height: 14.h),
          Row(children: [
            _genderChip('男生', 'male', Icons.face_outlined, Colors.blue, gender, ctrl),
            SizedBox(width: 12.w),
            _genderChip('女生', 'female', Icons.face_3_outlined, Colors.pink, gender, ctrl),
            SizedBox(width: 12.w),
            _genderChip('不透露', 'unknown', Icons.help_outline, Colors.grey, gender, ctrl),
          ]),
          if (gender == 'female') ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.pink.shade50, borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(children: [
                const Text('💕', style: TextStyle(fontSize: 13)),
                SizedBox(width: 6.w),
                Text('暖圈关怀已解锁，可在「我的工具」中找到',
                    style: TextStyle(fontSize: 12.sp, color: Colors.pink.shade400)),
              ]),
            ),
          ],
        ]);
      }),
    );
  }

  Widget _genderChip(String label, String value, IconData icon, Color color, String current, AppController ctrl) {
    final selected = current == value;
    return TapScale(
      scale: 0.92,
      onTap: () => ctrl.updateGender(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16.sp, color: selected ? color : Colors.grey[500]),
          SizedBox(width: 4.w),
          Text(label, style: TextStyle(fontSize: 13.sp, color: selected ? color : Colors.grey[600], fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
        ]),
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context, AppController ctrl) {
    final themes = [
      {'key': AppThemes.pinkTheme, 'name': '温柔粉', 'color': const Color(0xFFE89DAC)},
      {'key': AppThemes.purpleTheme, 'name': '优雅紫', 'color': const Color(0xFF9B8CC4)},
      {'key': AppThemes.blueTheme, 'name': '清新蓝', 'color': const Color(0xFF5B9BD5)},
      {'key': AppThemes.mintTheme, 'name': '薄荷绿', 'color': const Color(0xFF7CBEA7)},
      {'key': AppThemes.defaultTheme, 'name': '简约灰', 'color': const Color(0xFF8B8B8B)},
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Wrap(
        spacing: 12.w,
        runSpacing: 12.h,
        children: themes.map((t) {
          final key = t['key'] as String;
          final color = t['color'] as Color;
          final name = t['name'] as String;
          final isCurrent = ctrl.onThemeChange != null;

          return TapScale(
            onTap: () {
              ctrl.onThemeChange?.call(key);
              Get.snackbar('已切换', '主题已切换为 $name',
                  snackPosition: SnackPosition.TOP,
                  duration: const Duration(seconds: 1));
            },
            child: Column(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Theme.of(Get.context!).primaryColor == color
                      ? const Icon(Icons.check, color: Colors.white, size: 22)
                      : null,
                ),
                SizedBox(height: 6.h),
                Text(name,
                    style:
                        TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAiSection(AppController ctrl) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Obx(() => Column(
            children: [
              SwitchListTile(
                title: const Text('显示小暖悬浮按钮'),
                subtitle: const Text('全局悬浮的 AI 助手快捷入口'),
                value: ctrl.aiButtonMode.value == 1,
                onChanged: (v) => ctrl.setAiButtonMode(v ? 1 : 0),
              ),
              Divider(height: 1, indent: 16.w),
              SwitchListTile(
                title: const Text('每日问候气泡'),
                subtitle: const Text('进入首页时小暖打招呼'),
                value: ctrl.showDailyGreeting.value,
                onChanged: (v) {
                  ctrl.showDailyGreeting.value = v;
                },
              ),
            ],
          )),
    );
  }

  Widget _buildPrivacySection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Colors.indigo),
            title: const Text('隐私设置'),
            subtitle: const Text('内容隐私 · 信息保护'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Get.snackbar('', '功能开发中…',
                snackPosition: SnackPosition.TOP),
          ),
          Divider(height: 1, indent: 16.w),
          ListTile(
            leading: const Icon(Icons.security_outlined, color: Colors.teal),
            title: const Text('账号安全'),
            subtitle: const Text('修改密码 · 登录管理'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Get.snackbar('', '功能开发中…',
                snackPosition: SnackPosition.TOP),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.campaign_outlined, color: Colors.orange),
            title: const Text('官方公告'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Get.dialog(AlertDialog(
              title: const Text('官方公告'),
              content: const Text(
                  '欢迎使用暖小圈 v1.0！\n\n本版本包含：AI学习计划、自习室、知识小馆、暖记、暖账、暖圈关怀。\n\n域名 nuanxiaoquan.cn 备案中，敬请期待正式上线 🌸'),
              actions: [
                TextButton(onPressed: () => Get.back(), child: const Text('好的')),
              ],
            )),
          ),
          Divider(height: 1, indent: 16.w),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.blue),
            title: const Text('关于暖小圈'),
            subtitle: const Text('v1.0  AI 学习助手'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Get.dialog(AlertDialog(
              title: const Text('关于暖小圈'),
              content: const Text(
                  '暖小圈 v1.0\n\n一款面向学生的温暖学习助手，让学习更有温度。\n\nAI 支持：\n• 火山引擎豆包大模型\n• DeepSeek 大模型\n\n域名：nuanxiaoquan.cn\n©2026 暖小圈团队'),
              actions: [
                TextButton(onPressed: () => Get.back(), child: const Text('关闭')),
              ],
            )),
          ),
          Divider(height: 1, indent: 16.w),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined, color: Colors.grey),
            title: const Text('清理缓存'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              Get.snackbar('完成', '缓存已清理',
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: Colors.green.withOpacity(0.9),
                  colorText: Colors.white,
                  duration: const Duration(seconds: 2));
            },
          ),
        ],
      ),
    );
  }
}
