import 'package:flutter_test/flutter_test.dart';
import 'auth_service_test.dart' as auth_service_test;
import 'login_page_test.dart' as login_page_test;
import 'signup_page_test.dart' as signup_page_test;
import 'user_model_test.dart' as user_model_test;

void main() {
  group('Authentication Tests', () {
    group('AuthService Tests', () {
      auth_service_test.main();
    });

    group('LoginPage Tests', () {
      login_page_test.main();
    });

    group('SignupPage Tests', () {
      signup_page_test.main();
    });

    group('User Model Tests', () {
      user_model_test.main();
    });
  });
} 