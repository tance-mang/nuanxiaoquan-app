// ============================================================
// 文件：screens/splash_screen.dart
// 作用：启动页 - 加入粒子特效 + 暖小圈品牌动画
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../widgets/particle_background.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );

    _animController.forward();

    // 2.5 秒后进入主页（游客模式，无需登录）
    Future.delayed(const Duration(milliseconds: 2500), () {
      Get.offAllNamed('/main');
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 渐变背景
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF3E0),
                  Color(0xFFFFE0B2),
                  Color(0xFFFFCCBC)
                ],
              ),
            ),
          ),

          // 粒子特效层（触摸有互动）
          const ParticleBackground(
            particleColor: Color(0xFFFF8C42),
            particleCount: 35,
          ),

          // 中央 Logo + 文字
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 暖字圆形 Logo（带发光阴影）
                    Container(
                      width: 88.w,
                      height: 88.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFF8C42),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF8C42).withOpacity(0.4),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '暖',
                          style: TextStyle(
                            fontSize: 40.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      '暖小圈',
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5D4037),
                        letterSpacing: 4,
                      ),
                    ),
                    SizedBox(height: 40.h),
                    SizedBox(
                      width: 24.w,
                      height: 24.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFFFF8C42).withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 版本号
          Positioned(
            bottom: 30.h,
            left: 0,
            right: 0,
            child: Text(
              'v1.1',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.sp, color: const Color(0xFFBCAAA4)),
            ),
          ),
        ],
      ),
    );
  }
}
