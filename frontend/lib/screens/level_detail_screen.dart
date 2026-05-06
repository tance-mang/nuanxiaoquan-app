import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';

class LevelDetailScreen extends StatelessWidget {
  const LevelDetailScreen({Key? key}) : super(key: key);

  static const _studyLevelNames = [
    '', '学习萌新', '勤奋学徒', '专注达人', '学习先锋',
    '知识猎手', '高手进阶', '学海领航', '智识大师', '卓越学者', '暖圈之星'
  ];
  static const _contributeLevelNames = [
    '', '初心分享者', '知识播种者', '干货贡献者', '学海引路人',
    '知识守护者', '精英输出者', '教研先行者', '知识灯塔', '学界权威', '暖圈导师'
  ];

  int _getStudyNextExp(int level) {
    const exps = [0, 100, 250, 500, 900, 1400, 2100, 3000, 4200, 5800, 0];
    return level < exps.length ? exps[level] : 0;
  }

  int _getContributeNextExp(int level) {
    const exps = [0, 150, 380, 750, 1350, 2100, 3150, 4500, 6300, 8700, 0];
    return level < exps.length ? exps[level] : 0;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AppController>();
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('我的等级')),
      body: Obx(() => ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              _buildLevelCard(
                context: context,
                icon: '⭐',
                title: '星途学阶',
                subtitle: '日常学习 · 打卡专属',
                levelName: _studyLevelNames[
                    ctrl.studyLevel.value.clamp(1, 10)],
                level: ctrl.studyLevel.value,
                exp: ctrl.studyExp.value,
                nextExp: _getStudyNextExp(ctrl.studyLevel.value),
                color: Colors.amber,
                primary: primary,
                howToEarn: const [
                  '每日专注自习 +5 经验',
                  '完成学习计划 +10 经验',
                  '连续打卡7天 +20 经验',
                  '发布暖句 +3 经验',
                ],
              ),
              SizedBox(height: 16.h),
              _buildLevelCard(
                context: context,
                icon: '📚',
                title: '知源贡献',
                subtitle: '发布学习资源专属',
                levelName: _contributeLevelNames[
                    ctrl.contributeLevel.value.clamp(1, 10)],
                level: ctrl.contributeLevel.value,
                exp: ctrl.contributeExp.value,
                nextExp: _getContributeNextExp(ctrl.contributeLevel.value),
                color: Colors.deepPurple,
                primary: primary,
                howToEarn: const [
                  '发布存知内容 +15 经验',
                  '内容获得收藏 +8 经验',
                  '内容获得点赞 +3 经验',
                  '连续7天发布 +30 经验',
                ],
              ),
            ],
          )),
    );
  }

  Widget _buildLevelCard({
    required BuildContext context,
    required String icon,
    required String title,
    required String subtitle,
    required String levelName,
    required int level,
    required int exp,
    required int nextExp,
    required Color color,
    required Color primary,
    required List<String> howToEarn,
  }) {
    final progress = nextExp > 0 ? (exp / nextExp).clamp(0.0, 1.0) : 1.0;
    final isMax = level >= 10;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 等级徽章行
          Row(
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(icon, style: TextStyle(fontSize: 24.sp)),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 16.sp, fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12.sp, color: Colors.grey[500])),
                  ],
                ),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'Lv.$level',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp),
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // 等级称号
          Text(
            levelName,
            style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: color),
          ),

          SizedBox(height: 12.h),

          // 经验条
          if (!isMax) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('经验值',
                    style: TextStyle(
                        fontSize: 12.sp, color: Colors.grey[500])),
                Text('$exp / $nextExp',
                    style: TextStyle(
                        fontSize: 12.sp,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            SizedBox(height: 8.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8.h,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              '还需 ${nextExp - exp} 经验升到 Lv.${level + 1}',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[400]),
            ),
          ] else
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text('已达最高等级！',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp)),
            ),

          SizedBox(height: 16.h),
          Divider(height: 1, color: Colors.grey.shade100),
          SizedBox(height: 12.h),

          // 如何获得经验
          Text('如何获得经验',
              style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600])),
          SizedBox(height: 8.h),
          ...howToEarn.map((tip) => Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: Row(
                  children: [
                    Container(
                      width: 6.w,
                      height: 6.w,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    SizedBox(width: 8.w),
                    Text(tip,
                        style: TextStyle(
                            fontSize: 13.sp, color: Colors.grey[600])),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
