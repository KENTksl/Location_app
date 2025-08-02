import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:locationrealtime/pages/login_page.dart';

import 'login_page_test.mocks.dart';

@GenerateMocks([FirebaseAuth, FirebaseDatabase, UserCredential, User, DatabaseReference, DatabaseEvent])
void main() {
  group('LoginPage Widget Tests', () {
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

    Widget createLoginPage() {
      return MaterialApp(
        home: LoginPage(),
      );
    }

    group('UI Elements', () {
      testWidgets('should display all required UI elements', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createLoginPage());

        // Assert
        expect(find.text('Chào mừng trở lại!'), findsOneWidget);
        expect(find.text('Đăng nhập để kết nối với bạn bè'), findsOneWidget);
        expect(find.byType(TextField), findsNWidgets(2)); // Email and password fields
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Mật khẩu'), findsOneWidget);
        expect(find.text('Đăng nhập'), findsOneWidget);
        expect(find.text('Quên mật khẩu?'), findsOneWidget);
        expect(find.text('Chưa có tài khoản?'), findsOneWidget);
        expect(find.text('Đăng ký ngay'), findsOneWidget);
      });

      testWidgets('should have email and password text fields', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createLoginPage());

        // Assert
        expect(find.byType(TextField), findsNWidgets(2));
        
        // Check email field
        final emailField = find.byType(TextField).first;
        expect(tester.widget<TextField>(emailField).decoration!.labelText, 'Email');
        expect(tester.widget<TextField>(emailField).keyboardType, TextInputType.emailAddress);

        // Check password field
        final passwordField = find.byType(TextField).last;
        expect(tester.widget<TextField>(passwordField).decoration!.labelText, 'Mật khẩu');
        expect(tester.widget<TextField>(passwordField).obscureText, isTrue);
      });

      testWidgets('should have login button', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createLoginPage());

        // Assert
        expect(find.text('Đăng nhập'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });

      testWidgets('should have forgot password link', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createLoginPage());

        // Assert
        expect(find.text('Quên mật khẩu?'), findsOneWidget);
        expect(find.byType(TextButton), findsOneWidget);
      });

      testWidgets('should have sign up link', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createLoginPage());

        // Assert
        expect(find.text('Chưa có tài khoản?'), findsOneWidget);
        expect(find.text('Đăng ký ngay'), findsOneWidget);
      });
    });

    group('Form Interaction', () {
      testWidgets('should allow entering email and password', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createLoginPage());

        // Act
        await tester.enterText(find.byType(TextField).first, 'test@example.com');
        await tester.enterText(find.byType(TextField).last, 'password123');

        // Assert
        expect(find.text('test@example.com'), findsOneWidget);
        expect(find.text('password123'), findsOneWidget);
      });

      testWidgets('should toggle password visibility', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createLoginPage());

        // Get password field
        final passwordField = find.byType(TextField).last;
        final passwordFieldWidget = tester.widget<TextField>(passwordField);

        // Initially password should be obscured
        expect(passwordFieldWidget.obscureText, isTrue);

        // Find and tap the visibility toggle button
        final visibilityButton = find.byType(IconButton);
        await tester.tap(visibilityButton);
        await tester.pump();

        // Password should now be visible
        final updatedPasswordFieldWidget = tester.widget<TextField>(passwordField);
        expect(updatedPasswordFieldWidget.obscureText, isFalse);
      });

      testWidgets('should show loading indicator when login button is pressed', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createLoginPage());

        // Enter credentials
        await tester.enterText(find.byType(TextField).first, 'test@example.com');
        await tester.enterText(find.byType(TextField).last, 'password123');

        // Act - Tap login button
        await tester.tap(find.text('Đăng nhập'));
        await tester.pump();

        // Assert - Should show loading indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Form Validation', () {
      testWidgets('should show error message when fields are empty', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createLoginPage());

        // Act - Tap login button without entering any data
        await tester.tap(find.text('Đăng nhập'));
        await tester.pump();

        // Assert
        expect(find.text('Vui lòng nhập đầy đủ thông tin!'), findsOneWidget);
      });

      testWidgets('should show error message when email is empty', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createLoginPage());

        // Act - Enter only password
        await tester.enterText(find.byType(TextField).last, 'password123');
        await tester.tap(find.text('Đăng nhập'));
        await tester.pump();

        // Assert
        expect(find.text('Vui lòng nhập đầy đủ thông tin!'), findsOneWidget);
      });

      testWidgets('should show error message when password is empty', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createLoginPage());

        // Act - Enter only email
        await tester.enterText(find.byType(TextField).first, 'test@example.com');
        await tester.tap(find.text('Đăng nhập'));
        await tester.pump();

        // Assert
        expect(find.text('Vui lòng nhập đầy đủ thông tin!'), findsOneWidget);
      });
    });

    group('Navigation', () {
      testWidgets('should navigate to forgot password page', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createLoginPage());

        // Act
        await tester.tap(find.text('Quên mật khẩu?'));
        await tester.pumpAndSettle();

        // Assert - Should navigate to forgot password page
        expect(find.text('Quên mật khẩu'), findsOneWidget);
      });

      testWidgets('should navigate to signup page', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createLoginPage());

        // Act
        await tester.tap(find.text('Đăng ký ngay'));
        await tester.pumpAndSettle();

        // Assert - Should navigate to signup page
        expect(find.text('Tạo tài khoản mới'), findsOneWidget);
      });
    });

    group('Animation', () {
      testWidgets('should have fade and slide animations', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createLoginPage());

        // Assert - Check for animation widgets
        expect(find.byType(FadeTransition), findsOneWidget);
        expect(find.byType(SlideTransition), findsOneWidget);
      });

      testWidgets('should animate on page load', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createLoginPage());

        // Initial frame
        await tester.pump();

        // Wait for animation to complete
        await tester.pump(const Duration(milliseconds: 1000));

        // Assert - All elements should be visible after animation
        expect(find.text('Chào mừng trở lại!'), findsOneWidget);
        expect(find.text('Đăng nhập'), findsOneWidget);
      });
    });

    group('Error Handling', () {
      testWidgets('should show error message for invalid credentials', (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createLoginPage());

        // Enter credentials
        await tester.enterText(find.byType(TextField).first, 'invalid@example.com');
        await tester.enterText(find.byType(TextField).last, 'wrongpassword');

        // Act - Tap login button
        await tester.tap(find.text('Đăng nhập'));
        await tester.pump();

        // Wait for async operation
        await tester.pump(const Duration(seconds: 2));

        // Assert - Should show error message
        expect(find.textContaining('Lỗi đăng nhập'), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('should have proper semantic labels', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createLoginPage());

        // Assert
        expect(find.bySemanticsLabel('Email'), findsOneWidget);
        expect(find.bySemanticsLabel('Mật khẩu'), findsOneWidget);
        expect(find.bySemanticsLabel('Đăng nhập'), findsOneWidget);
      });

      testWidgets('should be accessible with screen readers', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createLoginPage());

        // Assert - Check for proper text widgets
        expect(find.text('Chào mừng trở lại!'), findsOneWidget);
        expect(find.text('Đăng nhập để kết nối với bạn bè'), findsOneWidget);
      });
    });
  });
} 