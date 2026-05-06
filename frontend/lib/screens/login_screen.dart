// ============================================================
// 文件：screens/login_screen.dart
// 作用：登录页 — 蓝紫渐变背景、毛玻璃输入框、轻柔浮动Logo
//        含用户协议 & 隐私政策弹窗（nuanxiaoquan.cn）
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';
import '../controllers/app_controller.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _authService = AuthService();

  int _countdown = 0;
  bool _isLoggingIn = false;

  // 浮动动画
  late AnimationController _floatController;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── 渐变背景 ──
          _buildGradientBg(),
          // ── 柔光流动粒子层（简单静态光晕） ──
          _buildGlowLayer(),
          // ── 主内容 ──
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                child: Column(
                  children: [
                    SizedBox(height: 100.h),
                    // Logo区域（轻柔上下浮动）
                    AnimatedBuilder(
                      animation: _floatAnim,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, _floatAnim.value),
                        child: child,
                      ),
                      child: _buildLogo(),
                    ),
                    SizedBox(height: 56.h),
                    // 毛玻璃卡片（输入框区域）
                    _buildGlassCard(),
                    SizedBox(height: 16.h),
                    // 游客模式入口
                    _buildGuestButton(),
                    SizedBox(height: 24.h),
                    // 协议文字
                    _buildAgreementRow(),
                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 蓝紫渐变背景 ──────────────────────────────────────────
  Widget _buildGradientBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFBDD5F5), // 浅蓝
            Color(0xFFD4C5F0), // 浅紫
            Color(0xFFEDD5F0), // 浅粉紫
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  // ── 柔光光晕（营造高级感）────────────────────────────────
  Widget _buildGlowLayer() {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GlowPainter(),
      ),
    );
  }

  // ── Logo区域 ─────────────────────────────────────────────
  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 84.w,
          height: 84.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF8FB0), Color(0xFFE57BA8)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE57BA8).withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '暖',
              style: TextStyle(
                color: Colors.white,
                fontSize: 38.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: 14.h),
        Text(
          '暖小圈',
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D2D2D),
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          '你的智能学习伙伴',
          style: TextStyle(fontSize: 13.sp, color: const Color(0xFF888888)),
        ),
      ],
    );
  }

  // ── 毛玻璃卡片输入区 ─────────────────────────────────────
  Widget _buildGlassCard() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.70),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInput(
            controller: _phoneController,
            hint: '请输入11位手机号',
            label: '手机号',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            maxLength: 11,
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: _buildInput(
                  controller: _codeController,
                  hint: '6位验证码',
                  label: '验证码',
                  icon: Icons.sms_outlined,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
              ),
              SizedBox(width: 10.w),
              _buildSendCodeBtn(),
            ],
          ),
          SizedBox(height: 20.h),
          _buildLoginButton(),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLength = 100,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13.sp),
        prefixIcon: Icon(icon, size: 18.sp, color: const Color(0xFFE57BA8)),
        counterText: '',
        filled: true,
        fillColor: Colors.white.withOpacity(0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: Color(0xFFE57BA8), width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      ),
    );
  }

  Widget _buildSendCodeBtn() {
    return GestureDetector(
      onTap: _countdown > 0 ? null : _sendVerificationCode,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: _countdown > 0
              ? Colors.grey.shade200
              : const Color(0xFFE57BA8).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: _countdown > 0
                ? Colors.grey.shade300
                : const Color(0xFFE57BA8).withOpacity(0.4),
          ),
        ),
        child: Text(
          _countdown > 0 ? '${_countdown}s' : '发送验证码',
          style: TextStyle(
            fontSize: 12.sp,
            color: _countdown > 0 ? Colors.grey : const Color(0xFFE57BA8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _isLoggingIn ? null : _loginWithPhone,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity,
        height: 48.h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8FB0), Color(0xFFE57BA8)],
          ),
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE57BA8).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _isLoggingIn
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  '登录 / 注册',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
    );
  }

  // ── 游客模式按钮 ─────────────────────────────────────────
  Widget _buildGuestButton() {
    return TextButton(
      onPressed: () => Get.off(() => const MainScreen()),
      child: Text(
        '暂不登录，先看看 →',
        style: TextStyle(
          fontSize: 13.sp,
          color: const Color(0xFF666666),
        ),
      ),
    );
  }

  // ── 协议行 ───────────────────────────────────────────────
  Widget _buildAgreementRow() {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        Text(
          '登录即表示您已同意 ',
          style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
        ),
        GestureDetector(
          onTap: () => _showAgreementDialog('user'),
          child: Text(
            '《用户协议》',
            style: TextStyle(
              fontSize: 11.sp,
              color: const Color(0xFF5B9BD5),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        Text(
          ' 和 ',
          style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
        ),
        GestureDetector(
          onTap: () => _showAgreementDialog('privacy'),
          child: Text(
            '《隐私政策》',
            style: TextStyle(
              fontSize: 11.sp,
              color: const Color(0xFF5B9BD5),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  // ── 协议弹窗 ─────────────────────────────────────────────
  void _showAgreementDialog(String type) {
    final isUser = type == 'user';
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r)),
        child: Container(
          height: 520.h,
          padding: EdgeInsets.all(20.w),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isUser ? '用户协议' : '隐私政策',
                      style: TextStyle(
                          fontSize: 17.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Get.back(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              Divider(height: 16.h),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    isUser ? _userAgreementText : _privacyPolicyText,
                    style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[700],
                        height: 1.8),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE57BA8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r)),
                  ),
                  child: const Text('我已阅读并同意',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 业务逻辑 ─────────────────────────────────────────────
  Future<void> _sendVerificationCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 11) {
      Get.snackbar('提示', '请输入正确的11位手机号',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() => _countdown = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _countdown--);
      return _countdown > 0;
    });
    Get.snackbar('已发送', '验证码已发送到 $phone',
        snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> _loginWithPhone() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (phone.length != 11) {
      Get.snackbar('提示', '请输入正确的手机号');
      return;
    }
    if (code.length != 6) {
      Get.snackbar('提示', '请输入6位验证码');
      return;
    }
    setState(() => _isLoggingIn = true);
    try {
      final controller = Get.find<AppController>();
      await controller.updateUserInfo(
          userId: 1, name: '暖小圈用户', gender: 'unknown');
      Get.off(() => const MainScreen());
    } catch (e) {
      setState(() => _isLoggingIn = false);
      Get.snackbar('登录失败', '验证码错误或已过期');
    }
  }

  // ── 协议文本（来自产品文档）────────────────────────────
  static const String _userAgreementText = '''
用户协议

一、服务说明
本APP（暖小圈，域名 nuanxiaoquan.cn）是个人开发的纯学习工具类应用，为用户提供自习、AI学习计划、学习干货分享、暖记备忘、暖账记账等免费学习服务，所有基础功能免费使用，后期商用将另行告知。

二、用户行为规范
用户仅可使用本APP进行个人学习、原创内容发布，严禁发布侵权、违规、违法、广告内容，严禁搬运他人学习资料、盗版文件、违规图文，违者平台有权删除内容、限制功能。

三、隐私说明
用户个人信息严格按照《隐私政策》保护，仅用于APP功能实现，不泄露、不商用、不售卖给第三方。

四、版权规范
APP内所有AI生成内容、用户原创内容版权归归属方所有，禁止未经授权搬运、商用、转载；本APP不存储盗版教材、付费资料，不侵犯任何第三方版权。

五、免责声明
本APP仅提供学习工具服务，用户发布内容仅代表个人观点，与平台无关；开发者不对用户自主发布的内容承担法律责任，如有侵权请联系删除。

六、协议修改
本协议可根据运营需求更新，更新后通过APP官方公告告知，用户继续登录即视为同意最新协议。
''';

  static const String _privacyPolicyText = '''
隐私政策

本APP（暖小圈，域名 nuanxiaoquan.cn）高度重视用户隐私保护，严格遵守国家法律法规，收集、使用用户个人信息遵循合法、正当、必要原则，具体条款如下：

一、信息收集
仅收集用户登录账号、昵称、头像、自主填写的个人资料，仅用于APP功能实现，不强制收集敏感个人信息。

二、信息使用
收集的信息仅用于APP正常功能运行、消息通知、合规审核，不用于任何商业推广、不售卖、不泄露给第三方。

三、信息安全
采取安全技术保护用户个人信息，防止信息泄露、丢失、被篡改。

四、权限说明
本APP仅申请必要的存储、网络权限，用于图片上传、内容加载、数据缓存，无恶意权限获取。

五、用户权利
用户可随时编辑、删除个人信息，可注销个人账号，账号注销后清除所有个人数据。

六、政策更新
本政策可根据合规要求更新，通过APP内公告告知，未尽事宜严格按照国家网络安全、个人信息保护法律法规执行。

联系方式：如有隐私问题，请通过APP内意见反馈联系我们。
''';
}

// ── 柔光背景画笔 ─────────────────────────────────────────
class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFFFFB6C8).withOpacity(0.18);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.25), 120, paint);

    paint.color = const Color(0xFFB8C8FF).withOpacity(0.15);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.15), 100, paint);

    paint.color = const Color(0xFFD4B8FF).withOpacity(0.12);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.75), 140, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter old) => false;
}
