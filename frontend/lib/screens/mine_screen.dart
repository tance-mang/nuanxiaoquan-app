// ============================================================
// 文件：screens/mine_screen.dart
// 作用：「我的」页面 - 个人中心
// 包含：
//   - 顶部：头像 + 双等级徽章 + 昵称设置
//   - 中部：记账助手 / 备忘录 / 暖圈关怀（仅女性可见）入口
//   - 下部：我的发布 / 我的收藏 / 我的点赞
//   - 底部：设置入口
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../widgets/level_badge.dart';
import '../widgets/tap_scale.dart';

class MineScreen extends StatelessWidget {
  const MineScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get.find 找到之前注入的全局控制器
    final controller = Get.find<AppController>();

    final primary = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 28.w,
            height: 28.w,
            decoration:
                BoxDecoration(color: primary, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '我',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Text('我的',
              style:
                  TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
        ]),
        actions: [
          // 右上角设置按钮
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Get.toNamed('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ===================================================
            // 1. 顶部个人信息区
            // ===================================================
            _buildProfileHeader(context, controller),

            SizedBox(height: 12.h),

            // ===================================================
            // 2. 双等级详情卡片
            // ===================================================
            _buildLevelCard(context, controller),

            SizedBox(height: 12.h),

            // ===================================================
            // 3. 核心功能入口
            // ===================================================
            _buildFunctionGrid(context, controller),

            SizedBox(height: 12.h),

            // ===================================================
            // 4. 我的内容管理
            // ===================================================
            _buildMyContentSection(context),

            SizedBox(height: 12.h),

            // ===================================================
            // 5. 其他设置区
            // ===================================================
            _buildSettingsSection(context, controller),

            SizedBox(height: 40.h), // 底部留白
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // 1. 顶部个人信息区
  // -------------------------------------------------------
  Widget _buildProfileHeader(BuildContext context, AppController controller) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
      color: Colors.white,
      child: Obx(() => Row(
        children: [
          // 头像（点击弹出昵称设置）
          GestureDetector(
            onTap: () => _showNicknameDialog(context, controller),
            child: CircleAvatar(
              radius: 30.r,
              backgroundImage: controller.currentUserAvatar.value.isNotEmpty
                  ? NetworkImage(controller.currentUserAvatar.value)
                  : null,
              child: controller.currentUserAvatar.value.isEmpty
                  ? Icon(
                  controller.isLoggedIn ? Icons.person : Icons.login,
                  size: 26.sp, color: Colors.white)
                  : null,
              backgroundColor: Theme.of(context).primaryColor,
            ),
          ),

          SizedBox(width: 16.w),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.isLoggedIn ? controller.currentUserName.value : '游客模式',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6.h),
                if (controller.isLoggedIn)
                  Row(children: [
                    LevelBadge(level: controller.studyLevel.value, type: LevelType.study),
                    SizedBox(width: 8.w),
                    LevelBadge(level: controller.contributeLevel.value, type: LevelType.contribute),
                  ])
                else
                  TapScale(
                    onTap: () => Get.toNamed('/login'),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Text('登录 / 注册',
                          style: TextStyle(fontSize: 12.sp, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),

          // 已隐藏箭头，后续版本再启用
          // Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      )),
    );
  }

  // ── 昵称设置弹窗 ────────────────────────────────────────────
  void _showNicknameDialog(BuildContext context, AppController controller) {
    if (!controller.isLoggedIn) {
      Get.toNamed('/login');
      return;
    }

    final nicknameCtrl = TextEditingController(text: controller.currentUserName.value);

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            Icon(Icons.edit, color: Theme.of(context).primaryColor, size: 22.sp),
            SizedBox(width: 8.w),
            Text('修改昵称', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
          ],
        ),
        content: TextField(
          controller: nicknameCtrl,
          maxLength: 20,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '请输入昵称',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('取消', style: TextStyle(fontSize: 15.sp)),
          ),
          ElevatedButton(
            onPressed: () {
              final newNickname = nicknameCtrl.text.trim();
              if (newNickname.isNotEmpty) {
                controller.currentUserName.value = newNickname;
                // TODO: 调用后端 API 保存昵称
                Get.snackbar('成功', '昵称已更新',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
            ),
            child: Text('确定', style: TextStyle(fontSize: 15.sp, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // 2. 双等级详情卡片
  // -------------------------------------------------------
  static const _studyLevelNames = [
    '', '学习萌新', '勤奋学徒', '专注达人', '学习先锋',
    '知识猎手', '高手进阶', '学海领航', '智识大师', '卓越学者', '暖圈之星'
  ];
  static const _contributeLevelNames = [
    '', '初心分享者', '知识播种者', '干货贡献者', '学海引路人',
    '知识守护者', '精英输出者', '教研先行者', '知识灯塔', '学界权威', '暖圈导师'
  ];

  void _showLevelSheet(BuildContext context, AppController ctrl) {
    final primary = Theme.of(context).primaryColor;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 10.h, bottom: 4.h),
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Text('我的等级',
                    style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Obx(() => ListView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 32.h),
                  children: [
                    _buildLevelDetailCard(
                      icon: '⭐', title: '星途学阶', subtitle: '日常学习 · 打卡专属',
                      levelName: _studyLevelNames[ctrl.studyLevel.value.clamp(1, 10)],
                      level: ctrl.studyLevel.value, exp: ctrl.studyExp.value,
                      nextExp: _getStudyNextLevelExp(ctrl.studyLevel.value),
                      color: Colors.amber,
                      howToEarn: const ['每日专注自习 +5 经验', '完成学习计划 +10 经验', '连续打卡7天 +20 经验', '发布暖句 +3 经验'],
                    ),
                    SizedBox(height: 14.h),
                    _buildLevelDetailCard(
                      icon: '📚', title: '知源贡献', subtitle: '发布学习资源专属',
                      levelName: _contributeLevelNames[ctrl.contributeLevel.value.clamp(1, 10)],
                      level: ctrl.contributeLevel.value, exp: ctrl.contributeExp.value,
                      nextExp: _getContributeNextLevelExp(ctrl.contributeLevel.value),
                      color: Colors.deepPurple,
                      howToEarn: const ['发布存知内容 +15 经验', '内容获得收藏 +8 经验', '内容获得点赞 +3 经验', '连续7天发布 +30 经验'],
                    ),
                  ],
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelDetailCard({
    required String icon, required String title, required String subtitle,
    required String levelName, required int level, required int exp,
    required int nextExp, required Color color, required List<String> howToEarn,
  }) {
    final progress = nextExp > 0 ? (exp / nextExp).clamp(0.0, 1.0) : 1.0;
    final isMax = level >= 10;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: color.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 52.w, height: 52.w,
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Center(child: Text(icon, style: TextStyle(fontSize: 22.sp))),
            ),
            SizedBox(width: 12.w),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)),
              Text(subtitle, style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
            ])),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20.r)),
              child: Text('Lv.$level', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14.sp)),
            ),
          ]),
          SizedBox(height: 12.h),
          Text(levelName, style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold, color: color)),
          SizedBox(height: 10.h),
          if (!isMax) ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('经验值', style: TextStyle(fontSize: 12.sp, color: Colors.grey[500])),
              Text('$exp / $nextExp', style: TextStyle(fontSize: 12.sp, color: color, fontWeight: FontWeight.w600)),
            ]),
            SizedBox(height: 6.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: progress, backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 8.h,
              ),
            ),
            SizedBox(height: 4.h),
            Text('还需 ${nextExp - exp} 经验升到 Lv.${level + 1}',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[400])),
          ] else
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
              child: Text('已达最高等级！', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13.sp)),
            ),
          SizedBox(height: 14.h),
          Divider(height: 1, color: Colors.grey.shade100),
          SizedBox(height: 10.h),
          Text('如何获得经验', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          SizedBox(height: 6.h),
          ...howToEarn.map((tip) => Padding(
            padding: EdgeInsets.only(bottom: 5.h),
            child: Row(children: [
              Container(width: 5.w, height: 5.w, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              SizedBox(width: 8.w),
              Text(tip, style: TextStyle(fontSize: 13.sp, color: Colors.grey[600])),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _buildLevelCard(BuildContext context, AppController controller) {
    return TapScale(
        onTap: () => _showLevelSheet(context, controller),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Obx(() => Column(
            children: [
              // 星途学阶等级行
              _buildLevelRow(
                context,
                title: '⭐ 星途学阶',
                subtitle: '日常学习 / 打卡专属等级',
                level: controller.studyLevel.value,
                currentExp: controller.studyExp.value,
                // 星途学阶每级所需经验（升级快，门槛低）
                nextLevelExp: _getStudyNextLevelExp(controller.studyLevel.value),
                color: Colors.amber,
              ),
              SizedBox(height: 16.h),
              Divider(height: 1.h, color: Colors.grey.shade100),
              SizedBox(height: 16.h),
              // 知源贡献等级行
              _buildLevelRow(
                context,
                title: '📚 知源贡献',
                subtitle: '发布学习资源专属等级',
                level: controller.contributeLevel.value,
                currentExp: controller.contributeExp.value,
                // 知源贡献每级所需经验（比学阶高30%以上）
                nextLevelExp: _getContributeNextLevelExp(controller.contributeLevel.value),
                color: Colors.deepPurple,
              ),
            ],
          )),
        ));
  }

  // 单行等级展示（进度条）
  Widget _buildLevelRow(
      BuildContext context, {
        required String title,
        required String subtitle,
        required int level,
        required int currentExp,
        required int nextLevelExp,
        required Color color,
      }) {
    // 计算进度百分比（0.0 ~ 1.0）
    final progress = nextLevelExp > 0
        ? (currentExp / nextLevelExp).clamp(0.0, 1.0)
        : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14.sp, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11.sp, color: Colors.grey[500])),
                ],
              ),
            ),
            // 等级数字
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                'Lv.$level',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        // 进度条
        ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6.h,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          '$currentExp / $nextLevelExp EXP',
          style: TextStyle(fontSize: 10.sp, color: Colors.grey[400]),
        ),
      ],
    );
  }

  // -------------------------------------------------------
  // 星途学阶：每级升级所需总经验
  // 升级快，门槛低，每日打卡即可轻松升级
  // Lv1→2: 100, Lv2→3: 200, ... 每级递增100
  // -------------------------------------------------------
  int _getStudyNextLevelExp(int level) {
    if (level >= 10) return 9999; // 满级
    return level * 100; // 线性增长，轻松升级
  }

  // -------------------------------------------------------
  // 知源贡献：每级升级所需总经验
  // 比星途学阶同等级高 30%+，升级更难，体现稀缺优越感
  // Lv1→2: 150, Lv2→3: 300, ... 每级递增更多
  // -------------------------------------------------------
  int _getContributeNextLevelExp(int level) {
    if (level >= 10) return 9999; // 满级
    return (level * 100 * 1.5).toInt(); // 比学阶高50%，升级明显更慢
  }

  // -------------------------------------------------------
  // 3. 功能入口网格
  // -------------------------------------------------------
  Widget _buildFunctionGrid(BuildContext context, AppController controller) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('我的工具',
              style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700])),
          SizedBox(height: 12.h),

          // Obx监听性别变化，自动决定是否显示暖圈关怀入口
          Obx(() {
            // 暖圈关怀入口仅女性可见
            final showMenstrual = controller.isMenstrualUnlocked;

            return LayoutBuilder(
              builder: (context, constraints) {
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: showMenstrual ? 3 : 2, // 女性显示3列，男性2列
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                  childAspectRatio: 1.15,
                  children: [
                    // 暖账（所有用户可见）
                    _buildFunctionItem(
                      context,
                      icon: Icons.account_balance_wallet_outlined,
                      label: '暖账',
                      color: Colors.green,
                      onTap: () => Get.toNamed('/accounting'),
                    ),
                    // 暖记（所有用户可见）
                    _buildFunctionItem(
                      context,
                      icon: Icons.note_alt_outlined,
                      label: '暖记',
                      color: Colors.orange,
                      onTap: () => Get.toNamed('/memo'),
                    ),
                    // 暖圈关怀（仅女性用户可见）
                    if (showMenstrual)
                      _buildFunctionItem(
                        context,
                        icon: Icons.favorite_outline,
                        label: '暖圈关怀',
                        color: Colors.pink,
                        onTap: () => Get.toNamed('/warmcare'),
                      ),
                  ],
                );
              },
            );
          }),
        ],
      ),
    );
  }

  // 单个功能入口卡片
  Widget _buildFunctionItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap,
      }) {
    return TapScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28.sp),
            SizedBox(height: 6.h),
            Text(
              label,
              style: TextStyle(fontSize: 12.sp, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // 4. 我的内容管理
  // -------------------------------------------------------
  Widget _buildMyContentSection(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          _buildListTile(
            icon: Icons.upload_file_outlined,
            iconColor: Colors.blue,
            title: '我的发布',
            subtitle: '管理发布的学习资源',
            onTap: () => Get.toNamed('/my-resources'),
          ),
          _buildDivider(),
          _buildListTile(
            icon: Icons.bookmark_outline,
            iconColor: Colors.amber,
            title: '我的收藏',
            subtitle: '收藏夹 + 自建分类',
            onTap: () => Get.toNamed('/my-collects'),
          ),
          _buildDivider(),
          _buildListTile(
            icon: Icons.thumb_up_outlined,
            iconColor: Colors.pink,
            title: '我的点赞',
            subtitle: '点赞过的语录和资源',
            onTap: () => Get.toNamed('/my-likes'),
          ),
          _buildDivider(),
          // 30天回收站
          _buildListTile(
            icon: Icons.restore_from_trash_outlined,
            iconColor: Colors.grey,
            title: '回收站',
            subtitle: '30天内删除的内容可找回',
            onTap: () => Get.toNamed('/recycle-bin'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // 5. 设置区
  // -------------------------------------------------------
  Widget _buildSettingsSection(BuildContext context, AppController controller) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          _buildListTile(
            icon: Icons.smart_toy_outlined,
            iconColor: Colors.purple,
            title: '小暖AI设置',
            subtitle: '悬浮按钮 / 问候气泡 / 服务开关',
            onTap: () => Get.toNamed('/ai-settings'),
          ),
          _buildDivider(),
          _buildListTile(
            icon: Icons.palette_outlined,
            iconColor: Colors.teal,
            title: '主题换肤',
            subtitle: '5种主题，一键全局换色',
            onTap: () => Get.toNamed('/theme-settings'),
          ),
          _buildDivider(),
          _buildListTile(
            icon: Icons.security_outlined,
            iconColor: Colors.indigo,
            title: '隐私与安全',
            subtitle: '账号安全、数据加密设置',
            onTap: () => Get.toNamed('/privacy-settings'),
          ),
          _buildDivider(),
          _buildListTile(
            icon: Icons.feedback_outlined,
            iconColor: Colors.orange,
            title: '意见反馈',
            subtitle: '联系我们，帮助暖小圈更好',
            onTap: () => Get.toNamed('/feedback'),
          ),
          _buildDivider(),
          // 登录 / 退出登录
          Obx(() => _buildListTile(
            icon: controller.isLoggedIn ? Icons.logout : Icons.login,
            iconColor: controller.isLoggedIn ? Colors.red : Theme.of(context).primaryColor,
            title: controller.isLoggedIn ? '退出登录' : '登录 / 注册',
            onTap: () {
              if (!controller.isLoggedIn) {
                Get.toNamed('/login');
                return;
              }
              Get.dialog(AlertDialog(
                title: const Text('确定退出登录？'),
                actions: [
                  TextButton(onPressed: () => Get.back(), child: const Text('取消')),
                  TextButton(
                    onPressed: () {
                      controller.logout();
                      Get.back();
                    },
                    child: const Text('退出', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ));
            },
          )),
        ],
      ),
    );
  }

  // 列表项组件
  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return TapScale(
      scale: 0.97,
      onTap: onTap,
      child: ListTile(
        leading: Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, color: iconColor, size: 20.sp),
        ),
        title: Text(title, style: TextStyle(fontSize: 14.sp)),
        subtitle: subtitle != null
            ? Text(subtitle,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]))
            : null,
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 18.sp),
        onTap: null,
      ),
    );
  }

  // 分割线
  Widget _buildDivider() {
    return Divider(
      height: 1.h,
      indent: 56.w, // 左边缩进，对齐文字
      color: Colors.grey.shade100,
    );
  }
}
