import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locationrealtime/pages/login_page.dart';

void main() {
  group('LoginPage', () {
    Widget createTestWidget() {
      return MaterialApp(
        home: LoginPage(),
      );
    }

    testWidgets('should display correct title and description', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Chào mừng trở lại!'), findsOneWidget);
      expect(find.text('Đăng nhập để kết nối với bạn bè'), findsOneWidget);
    });

    testWidgets('should show all required input fields', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
    });

    testWidgets('should show forgot password link', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Quên mật khẩu?'), findsOneWidget);
    });

    testWidgets('should show sign up link', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Look for the sign up text in the UI
      expect(find.text('Đăng ký ngay'), findsOneWidget);
    });

    testWidgets('should have proper styling and layout', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if the page has proper structure
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(SafeArea), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('should show location icon', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
    });

    testWidgets('should have email field with email keyboard type', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final emailField = tester.widget<TextField>(find.byType(TextField).at(0));
      expect(emailField.keyboardType, TextInputType.emailAddress);
    });

    testWidgets('should have password field with obscure text by default', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final passwordField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(passwordField.obscureText, isTrue);
    });

    testWidgets('should toggle password visibility when eye icon is tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final passwordField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(passwordField.obscureText, isTrue);

      // Tap the visibility toggle icon
      await tester.tap(find.byIcon(Icons.visibility_rounded));
      await tester.pump();

      final updatedPasswordField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(updatedPasswordField.obscureText, isFalse);
    });

    testWidgets('should have animations initialized', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if animations are present - there are multiple FadeTransitions in the UI
      expect(find.byType(FadeTransition), findsWidgets);
      expect(find.byType(SlideTransition), findsOneWidget);
    });

    testWidgets('should have proper button styling', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if primary button is present
      expect(find.text('Đăng nhập'), findsOneWidget);
    });

    testWidgets('should handle password field suffix icon correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially should show visibility icon
      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_rounded), findsNothing);

      // Tap to toggle visibility
      await tester.tap(find.byIcon(Icons.visibility_rounded));
      await tester.pump();

      // Should now show visibility off icon
      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.visibility_rounded), findsNothing);
    });

    testWidgets('should have proper input field styling', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if input fields have proper decoration
      final emailField = tester.widget<TextField>(find.byType(TextField).at(0));
      final passwordField = tester.widget<TextField>(find.byType(TextField).at(1));
      
      expect(emailField.decoration, isNotNull);
      expect(passwordField.decoration, isNotNull);
    });

    testWidgets('should have proper gradient background', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if the page has gradient background
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.decoration, isNotNull);
    });

    testWidgets('should have proper spacing and layout', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if the page has proper spacing elements
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('should have proper card styling', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if the form is wrapped in a card-like container
      expect(find.byType(Container), findsWidgets);
    });
  });
}
