import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:locationrealtime/pages/signup_page.dart';

import 'signup_page_test.mocks.dart';

@GenerateMocks([FirebaseAuth, FirebaseDatabase, UserCredential, User, DatabaseReference, DatabaseEvent])
void main() {
  group('SignupPage Widget Tests', () {
    late MockFirebaseAuth mockFirebaseAuth;
    late MockFirebaseDatabase mockFirebaseDatabase;
    late MockUserCredential mockUserCredential;
    late MockUser mockUser;
    late MockDatabaseReference mockDatabaseRef;
    late MockDatabaseEvent mockDatabaseEvent;

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
      mockFirebaseDatabase = MockFirebaseDatabase();
      mockUserCredential = MockUserCredential();
      mockUser = MockUser();
      mockDatabaseRef = MockDatabaseReference();
      mockDatabaseEvent = MockDatabaseEvent();
    });

    Widget createSignupPage() {
      return MaterialApp(
        home: SignupPage(),
      );
    }

    group('UI Elements', () {
      testWidgets('should display all required UI elements', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createSignupPage());

        // Assert
        expect(find.text('Tạo tài khoản mới'), findsOneWidget);
        expect(find.text('Điền thông tin để đăng ký'), findsOneWidget);
        expect(find.byType(TextField), findsNWidgets(3)); // Email, password, confirm password
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Mật khẩu'), findsOneWidget);
        expect(find.text('Xác nhận mật khẩu'), findsOneWidget);
        expect(find.text('Đăng ký'), findsOneWidget);
        expect(find.text('Đã có tài khoản?'), findsOneWidget);
        expect(find.text('Đăng nhập'), findsOneWidget);
        expect(find.text('Mật khẩu phải có ít nhất 6 ký tự'), findsOneWidget);
      });

      testWidgets('should have email text field', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createSignupPage());

        // Assert
        final emailField = find.byType(TextField).first;
        expect(tester.widget<TextField>(emailField).decoration!.labelText, 'Email');
        expect(tester.widget<TextField>(emailField).keyboardType, TextInputType.emailAddress);
      });

      testWidgets('should have password text field', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createSignupPage());

        // Assert
        final passwordField = find.byType(TextField).at(1);
        expect(tester.widget<TextField>(passwordField).decoration!.labelText, 'Mật khẩu');
        expect(tester.widget<TextField>(passwordField).obscureText, isTrue);
        expect(tester.widget<TextField>(passwordField).decoration!.helperText, 'Mật khẩu phải có ít nhất 6 ký tự');
      });

      testWidgets('should have confirm password text field', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createSignupPage());

        // Assert
        final confirmPasswordField = find.byType(TextField).last;
        expect(tester.widget<TextField>(confirmPasswordField).decoration!.labelText, 'Xác nhận mật khẩu');
        expect(tester.widget<TextField>(confirmPasswordField).obscureText, isTrue);
      });

      testWidgets('should have signup button', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createSignupPage());

        // Assert
        expect(find.text('Đăng ký'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });

      testWidgets('should have login link', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createSignupPage());

        // Assert
        expect(find.text('Đã có tài khoản?'), findsOneWidget);
        expect(find.text('Đăng nhập'), findsOneWidget);
      });
    });

    group('Form Interaction', () {
      testWidgets('should allow entering email, password and confirm password', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createSignupPage());

        // Act
        await tester.enterText(find.byType(TextField).first, 'test@example.com');
        await tester.enterText(find.byType(TextField).at(1), 'password123');
        await tester.enterText(find.byType(TextField).last, 'password123');

        // Assert
        expect(find.text('test@example.com'), findsOneWidget);
        expect(find.text('password123'), findsNWidgets(2));
      });

      testWidgets('should show loading indicator when signup button is pressed', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createSignupPage());

        // Enter valid credentials
        await tester.enterText(find.byType(TextField).first, 'test@example.com');
        await tester.enterText(find.byType(TextField).at(1), 'password123');
        await tester.enterText(find.byType(TextField).last, 'password123');

        // Act - Tap signup button
        await tester.tap(find.text('Đăng ký'));
        await tester.pump();

        // Assert - Should show loading indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Form Validation', () {
      testWidgets('should show error message when fields are empty', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createSignupPage());

        // Act - Tap signup button without entering any data
        await tester.tap(find.text('Đăng ký'));
        await tester.pump();

        // Assert
        expect(find.text('Vui lòng nhập đầy đủ thông tin!'), findsOneWidget);
      });

      testWidgets('should show error message when email is empty', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createSignupPage());

        // Act - Enter only passwords
        await tester.enterText(find.byType(TextField).at(1), 'password123');
        await tester.enterText(find.byType(TextField).last, 'password123');
        await tester.tap(find.text('Đăng ký'));
        await tester.pump();

        // Assert
        expect(find.text('Vui lòng nhập đầy đủ thông tin!'), findsOneWidget);
      });

      testWidgets('should show error message when password is empty', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createSignupPage());

        // Act - Enter only email and confirm password
        await tester.enterText(find.byType(TextField).first, 'test@example.com');
        await tester.enterText(find.byType(TextField).last, 'password123');
        await tester.tap(find.text('Đăng ký'));
        await tester.pump();

        // Assert
        expect(find.text('Vui lòng nhập đầy đủ thông tin!'), findsOneWidget);
      });

      testWidgets('should show error message when confirm password is empty', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createSignupPage());

        // Act - Enter only email and password
        await tester.enterText(find.byType(TextField).first, 'test@example.com');
        await tester.enterText(find.byType(TextField).at(1), 'password123');
        await tester.tap(find.text('Đăng ký'));
        await tester.pump();

        // Assert
        expect(find.text('Vui lòng nhập đầy đủ thông tin!'), findsOneWidget);
      });

      testWidgets('should show error message when passwords do not match', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createSignupPage());

        // Act - Enter different passwords
        await tester.enterText(find.byType(TextField).first, 'test@example.com');
        await tester.enterText(find.byType(TextField).at(1), 'password123');
        await tester.enterText(find.byType(TextField).last, 'differentpassword');
        await tester.tap(find.text('Đăng ký'));
        await tester.pump();

        // Assert
        expect(find.text('Mật khẩu xác nhận không khớp!'), findsOneWidget);
      });

      testWidgets('should show error message when password is too short', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createSignupPage());

        // Act - Enter short password
        await tester.enterText(find.byType(TextField).first, 'test@example.com');
        await tester.enterText(find.byType(TextField).at(1), '123');
        await tester.enterText(find.byType(TextField).last, '123');
        await tester.tap(find.text('Đăng ký'));
        await tester.pump();

        // Assert
        expect(find.text('Mật khẩu phải có ít nhất 6 ký tự!'), findsOneWidget);
      });

      testWidgets('should accept valid credentials', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createSignupPage());

        // Act - Enter valid credentials
        await tester.enterText(find.byType(TextField).first, 'test@example.com');
        await tester.enterText(find.byType(TextField).at(1), 'password123');
        await tester.enterText(find.byType(TextField).last, 'password123');
        await tester.tap(find.text('Đăng ký'));
        await tester.pump();

        // Assert - Should not show validation errors
        expect(find.text('Vui lòng nhập đầy đủ thông tin!'), findsNothing);
        expect(find.text('Mật khẩu xác nhận không khớp!'), findsNothing);
        expect(find.text('Mật khẩu phải có ít nhất 6 ký tự!'), findsNothing);
      });
    });

    group('Navigation', () {
      testWidgets('should navigate to login page', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createSignupPage());

        // Act
        await tester.tap(find.text('Đăng nhập'));
        await tester.pumpAndSettle();

        // Assert - Should navigate to login page
        expect(find.text('Chào mừng trở lại!'), findsOneWidget);
      });
    });

    group('Error Handling', () {
      testWidgets('should show error message for registration failure', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createSignupPage());

        // Enter valid credentials
        await tester.enterText(find.byType(TextField).first, 'existing@example.com');
        await tester.enterText(find.byType(TextField).at(1), 'password123');
        await tester.enterText(find.byType(TextField).last, 'password123');

        // Act - Tap signup button
        await tester.tap(find.text('Đăng ký'));
        await tester.pump();

        // Wait for async operation
        await tester.pump(const Duration(seconds: 2));

        // Assert - Should show error message
        expect(find.textContaining('Lỗi đăng ký'), findsOneWidget);
      });
    });

    group('Success Flow', () {
      testWidgets('should show success message and navigate to login on successful registration', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createSignupPage());

        // Enter valid credentials
        await tester.enterText(find.byType(TextField).first, 'newuser@example.com');
        await tester.enterText(find.byType(TextField).at(1), 'password123');
        await tester.enterText(find.byType(TextField).last, 'password123');

        // Act - Tap signup button
        await tester.tap(find.text('Đăng ký'));
        await tester.pump();

        // Wait for success message
        await tester.pump(const Duration(seconds: 2));

        // Assert - Should show success message
        expect(find.text('Đăng ký thành công!'), findsOneWidget);

        // Wait for navigation
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // Assert - Should navigate to login page
        expect(find.text('Chào mừng trở lại!'), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('should have proper semantic labels', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createSignupPage());

        // Assert
        expect(find.bySemanticsLabel('Email'), findsOneWidget);
        expect(find.bySemanticsLabel('Mật khẩu'), findsOneWidget);
        expect(find.bySemanticsLabel('Xác nhận mật khẩu'), findsOneWidget);
        expect(find.bySemanticsLabel('Đăng ký'), findsOneWidget);
      });

      testWidgets('should be accessible with screen readers', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createSignupPage());

        // Assert - Check for proper text widgets
        expect(find.text('Tạo tài khoản mới'), findsOneWidget);
        expect(find.text('Điền thông tin để đăng ký'), findsOneWidget);
      });
    });

    group('Password Requirements', () {
      testWidgets('should show helper text for password requirements', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createSignupPage());

        // Assert
        expect(find.text('Mật khẩu phải có ít nhất 6 ký tự'), findsOneWidget);
      });

      testWidgets('should validate password length correctly', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createSignupPage());

        // Test with 5 characters (too short)
        await tester.enterText(find.byType(TextField).first, 'test@example.com');
        await tester.enterText(find.byType(TextField).at(1), '12345');
        await tester.enterText(find.byType(TextField).last, '12345');
        await tester.tap(find.text('Đăng ký'));
        await tester.pump();

        expect(find.text('Mật khẩu phải có ít nhất 6 ký tự!'), findsOneWidget);

        // Clear and test with 6 characters (valid)
        await tester.enterText(find.byType(TextField).at(1), '123456');
        await tester.enterText(find.byType(TextField).last, '123456');
        await tester.tap(find.text('Đăng ký'));
        await tester.pump();

        expect(find.text('Mật khẩu phải có ít nhất 6 ký tự!'), findsNothing);
      });
    });
  });
} 