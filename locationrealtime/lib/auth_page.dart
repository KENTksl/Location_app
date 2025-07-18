import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _message = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      setState(() => _message = 'Đăng nhập thành công!');
    } catch (e) {
      setState(() => _message = 'Lỗi đăng nhập: $e');
    }
  }

  Future<void> _signUp() async {
    // Kiểm tra xác nhận mật khẩu
    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      setState(() => _message = 'Mật khẩu xác nhận không khớp!');
      return;
    }

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      setState(() => _message = 'Đăng ký thành công!');
    } catch (e) {
      setState(() => _message = 'Lỗi đăng ký: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng nhập / Đăng ký'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Đăng nhập'),
            Tab(text: 'Đăng ký'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSignInForm(), _buildSignUpForm()],
      ),
    );
  }

  Widget _buildSignInForm() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Mật khẩu'),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _signIn, child: const Text('Đăng nhập')),
          const SizedBox(height: 16),
          Text(_message, style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Mật khẩu'),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu'),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _signUp, child: const Text('Đăng ký')),
          const SizedBox(height: 16),
          Text(_message, style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}
