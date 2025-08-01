import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _message = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    // Kiểm tra các trường bắt buộc
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _confirmPasswordController.text.trim().isEmpty) {
      setState(() => _message = 'Vui lòng nhập đầy đủ thông tin!');
      return;
    }

    // Kiểm tra xác nhận mật khẩu
    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      setState(() => _message = 'Mật khẩu xác nhận không khớp!');
      return;
    }

    // Kiểm tra độ dài mật khẩu
    if (_passwordController.text.trim().length < 6) {
      setState(() => _message = 'Mật khẩu phải có ít nhất 6 ký tự!');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      setState(() => _message = 'Đăng ký thành công!');

      // Lưu thông tin user vào Realtime Database
      final user = userCredential.user;
      if (user != null) {
        await FirebaseDatabase.instance.ref('users/${user.uid}').set({
          'email': user.email,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }

      // Chờ một chút để hiển thị thông báo thành công
      await Future.delayed(const Duration(seconds: 2));

      // Quay lại trang đăng nhập
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      setState(() => _message = 'Lỗi đăng ký: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTheme.appBar(title: 'Đăng ký'),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                // Logo và title
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXL),
                const Text('Tạo tài khoản mới', style: AppTheme.headingStyle),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  'Điền thông tin để đăng ký',
                  style: AppTheme.subheadingStyle.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXXL),
                // Form đăng ký
                AppTheme.card(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  borderRadius: AppTheme.borderRadiusL,
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: AppTheme.getInputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icons.email_rounded,
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      TextField(
                        controller: _passwordController,
                        decoration: AppTheme.getInputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: Icons.lock_rounded,
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      TextField(
                        controller: _confirmPasswordController,
                        decoration: AppTheme.getInputDecoration(
                          labelText: 'Xác nhận mật khẩu',
                          prefixIcon: Icons.lock_outline_rounded,
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      AppTheme.primaryButton(
                        text: 'Đăng ký',
                        onPressed: _isLoading ? () {} : _signUp,
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
                const SizedBox(height: AppTheme.spacingXL),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Đã có tài khoản? ',
                      style: AppTheme.subheadingStyle.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Đăng nhập',
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
    );
  }
}
