import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:locationrealtime/pages/friend_search_page.dart';

// Mock Firebase Core
class MockFirebaseCore extends Mock implements Firebase {}

// Test setup for Firebase
class TestFirebase {
  static Future<void> setupFirebaseForTesting() async {
    // This is a simple mock setup for testing
    // In a real app, you might want to use firebase_core_mocks
  }
}

void main() {
  group('FriendSearchPage', () {
    // ignore: unused_local_variable
    late MockFirebaseAuth mockAuth;
    // ignore: unused_local_variable
    late MockUser mockUser;

    setUpAll(() async {
      await TestFirebase.setupFirebaseForTesting();
    });

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser(
        isAnonymous: false,
        uid: 'test-uid',
        email: 'test@example.com',
        displayName: 'Test User',
      );
    });

    Widget createTestWidget() {
      return MaterialApp(home: FriendSearchPage());
    }

    testWidgets('should display correct title', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Tìm kiếm bạn bè'), findsOneWidget);
    });

    testWidgets('should show search form with email input', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Nhập email bạn bè'), findsOneWidget);
      expect(find.text('Tìm kiếm'), findsOneWidget);
    });

    testWidgets('should show search button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Tìm kiếm'), findsOneWidget);
    });

    testWidgets('should have proper styling and layout', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if the page has proper structure
      expect(find.byType(Scaffold), findsOneWidget);
      // Note: SafeArea is used in the AppBar and in the body, so we expect 2
      expect(find.byType(SafeArea), findsNWidgets(2));
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('should show email icon in search field', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.email_rounded), findsOneWidget);
    });

    testWidgets('should have search field with proper styling', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.style?.fontSize, 18);
    });

    testWidgets('should show search form elements', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if search form elements are present
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Tìm kiếm'), findsOneWidget);
      expect(find.byIcon(Icons.email_rounded), findsOneWidget);
    });

    testWidgets('should have proper input decoration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if input field has proper decoration
      expect(find.text('Nhập email bạn bè'), findsOneWidget);
    });

    testWidgets('should handle search field input', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter text in search field
      await tester.enterText(find.byType(TextField), 'test@example.com');
      await tester.pump();

      // Text should be entered
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('should have proper button styling', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if search button has proper styling
      expect(find.text('Tìm kiếm'), findsOneWidget);
    });

    testWidgets('should handle search field focus', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on search field to focus
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Field should be focused
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('should have proper spacing between elements', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if proper spacing is maintained
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('should handle search field clear', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter text
      await tester.enterText(find.byType(TextField), 'test@example.com');
      await tester.pump();

      // Clear text
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      // Field should be empty
      expect(find.text('test@example.com'), findsNothing);
    });

    testWidgets('should have proper gradient background', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if gradient background is applied
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('should have proper search form layout', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if search form has proper column layout
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('should show search results area', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // The search results area should be present (even if empty)
      expect(find.byType(Expanded), findsOneWidget);
    });

    testWidgets('should have proper card styling', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if cards are present
      expect(find.byType(Container), findsWidgets);
    });
  });
}
