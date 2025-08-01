import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import 'map_page.dart';
import 'main_navigation_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _message = '';
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() => _message = 'Vui lòng nhập đầy đủ thông tin!');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      setState(() => _message = 'Đăng nhập thành công!');

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
        final snap = await userRef.get();
        if (!snap.exists) {
          await userRef.set({
            'email': user.email,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationPage()),
      );
    } catch (e) {
      setState(() => _message = 'Lỗi đăng nhập: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    // Logo và title
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusM,
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXL),
                    const Text(
                      'Chào mừng trở lại!',
                      style: AppTheme.headingStyle,
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      'Đăng nhập để kết nối với bạn bè',
                      style: AppTheme.subheadingStyle.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXXL),
                    // Form đăng nhập
                    AppTheme.card(
                      padding: const EdgeInsets.all(AppTheme.spacingL),
                      borderRadius: AppTheme.borderRadiusL,
                      child: Column(
                        children: [
                          // Email field
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: AppTheme.getInputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icons.email_rounded,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingM),
                          // Password field
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: AppTheme.getInputDecoration(
                              labelText: 'Mật khẩu',
                              prefixIcon: Icons.lock_rounded,
                              suffixIcon: _obscurePassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              onSuffixPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _navigateToForgotPassword,
                              child: Text(
                                'Quên mật khẩu?',
                                style: TextStyle(color: AppTheme.primaryColor),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingL),
                          // Login button
                          AppTheme.primaryButton(
                            text: 'Đăng nhập',
                            onPressed: _isLoading ? () {} : _signIn,
                            isLoading: _isLoading,
                          ),
                          if (_message.isNotEmpty) ...[
                            const SizedBox(height: AppTheme.spacingM),
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacingM),
                              decoration: BoxDecoration(
                                color: _message.contains('thành công')
                                    ? AppTheme.successColor.withOpacity(0.1)
                                    : AppTheme.errorColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.borderRadiusS,
                                ),
                                border: Border.all(
                                  color: _message.contains('thành công')
                                      ? AppTheme.successColor.withOpacity(0.3)
                                      : AppTheme.errorColor.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _message,
                                style: TextStyle(
                                  color: _message.contains('thành công')
                                      ? AppTheme.successColor
                                      : AppTheme.errorColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Sign up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Chưa có tài khoản? ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignupPage(),
                              ),
                            );
                          },
                          child: const Text(
                            'Đăng ký ngay',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
