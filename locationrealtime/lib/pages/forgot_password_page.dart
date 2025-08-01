import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  String _message = '';
  bool _isLoading = false;
  bool _isEmailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _message = 'Vui lòng nhập email của bạn!');
      return;
    }

    // Validate email format
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      setState(() => _message = 'Vui lòng nhập email hợp lệ!');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      setState(() {
        _message =
            'Email đặt lại mật khẩu đã được gửi thành công!\nVui lòng kiểm tra hộp thư của bạn.';
        _isEmailSent = true;
      });
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Không tìm thấy tài khoản với email này.';
          break;
        case 'invalid-email':
          errorMessage = 'Email không hợp lệ.';
          break;
        case 'too-many-requests':
          errorMessage = 'Quá nhiều yêu cầu. Vui lòng thử lại sau.';
          break;
        default:
          errorMessage = 'Có lỗi xảy ra: ${e.message}';
      }
      setState(() => _message = errorMessage);
    } catch (e) {
      setState(() => _message = 'Có lỗi xảy ra: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTheme.appBar(title: 'Quên mật khẩu'),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                // Icon and title
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
                    Icons.lock_reset_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXL),
                const Text(
                  'Quên mật khẩu?',
                  style: AppTheme.headingStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  'Nhập email của bạn để nhận link đặt lại mật khẩu',
                  style: AppTheme.subheadingStyle.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingXXL),
                // Email input field
                if (!_isEmailSent) ...[
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
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: AppTheme.spacingL),
                        AppTheme.primaryButton(
                          text: 'Gửi email đặt lại mật khẩu',
                          onPressed: _isLoading ? () {} : _resetPassword,
                          isLoading: _isLoading,
                        ),
                      ],
                    ),
                  ),
                ],

                // Success message
                if (_isEmailSent) ...[
                  const SizedBox(height: AppTheme.spacingL),
                  AppTheme.card(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    borderRadius: AppTheme.borderRadiusL,
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.successColor,
                          size: 48,
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        Text(
                          _message,
                          style: TextStyle(
                            color: AppTheme.successColor,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  AppTheme.secondaryButton(
                    text: 'Gửi lại email',
                    onPressed: () {
                      setState(() {
                        _isEmailSent = false;
                        _message = '';
                        _emailController.clear();
                      });
                    },
                  ),
                ],

                // Error message
                if (_message.isNotEmpty && !_isEmailSent) ...[
                  const SizedBox(height: AppTheme.spacingM),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadiusS,
                      ),
                      border: Border.all(
                        color: AppTheme.errorColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: AppTheme.errorColor,
                          size: 20,
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: Text(
                            _message,
                            style: TextStyle(
                              color: AppTheme.errorColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppTheme.spacingXL),

                // Back to login button
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Quay lại đăng nhập',
                    style: AppTheme.subheadingStyle.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
