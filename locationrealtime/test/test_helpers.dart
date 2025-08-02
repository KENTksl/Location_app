import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:locationrealtime/models/user.dart' as app_user;

// Common test data
class TestData {
  static const String validEmail = 'test@example.com';
  static const String validPassword = 'password123';
  static const String validUserId = 'user123';
  static const String invalidEmail = 'invalid@example.com';
  static const String invalidPassword = 'wrongpassword';
  static const String shortPassword = '123';
  static const String mismatchedPassword = 'differentpassword';

  static final DateTime testCreatedAt = DateTime(2023, 1, 1, 12, 0, 0);
  
  static final Map<String, dynamic> testLocation = {
    'latitude': 10.0,
    'longitude': 20.0,
  };

  static final app_user.User testUser = app_user.User(
    id: validUserId,
    email: validEmail,
    avatarUrl: 'https://example.com/avatar.jpg',
    createdAt: testCreatedAt,
    isSharingLocation: true,
    alwaysShareLocation: false,
    location: testLocation,
  );

  static final Map<String, dynamic> testUserJson = {
    'id': validUserId,
    'email': validEmail,
    'avatarUrl': 'https://example.com/avatar.jpg',
    'createdAt': testCreatedAt.toIso8601String(),
    'isSharingLocation': true,
    'alwaysShareLocation': false,
    'location': testLocation,
  };
}

// Common test utilities
class TestUtils {
  // Create a test widget with MaterialApp wrapper
  static Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  // Wait for async operations to complete
  static Future<void> waitForAsync(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  // Enter text in a text field by index
  static Future<void> enterTextByIndex(
    WidgetTester tester,
    int index,
    String text,
  ) async {
    final textField = find.byType(TextField).at(index);
    await tester.enterText(textField, text);
  }

  // Enter text in a text field by label
  static Future<void> enterTextByLabel(
    WidgetTester tester,
    String label,
    String text,
  ) async {
    final textField = find.byWidgetPredicate(
      (widget) => widget is TextField && 
          widget.decoration?.labelText == label,
    );
    await tester.enterText(textField, text);
  }

  // Tap button by text
  static Future<void> tapButtonByText(
    WidgetTester tester,
    String text,
  ) async {
    final button = find.text(text);
    await tester.tap(button);
  }

  // Check if error message is displayed
  static bool hasErrorMessage(WidgetTester tester, String message) {
    return find.text(message).evaluate().isNotEmpty;
  }

  // Check if success message is displayed
  static bool hasSuccessMessage(WidgetTester tester, String message) {
    return find.text(message).evaluate().isNotEmpty;
  }

  // Check if loading indicator is displayed
  static bool hasLoadingIndicator(WidgetTester tester) {
    return find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
  }

  // Check if widget is present
  static bool hasWidget(WidgetTester tester, Widget widget) {
    return find.byWidget(widget).evaluate().isNotEmpty;
  }

  // Check if text is present
  static bool hasText(WidgetTester tester, String text) {
    return find.text(text).evaluate().isNotEmpty;
  }
}

// Mock setup utilities
class MockSetup {
  static void setupFirebaseAuthMocks(
    MockFirebaseAuth mockAuth,
    MockUserCredential mockUserCredential,
    MockUser mockUser, {
    String? uid,
    String? email,
    bool shouldThrow = false,
    String? errorCode,
  }) {
    if (shouldThrow) {
      when(mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(FirebaseAuthException(code: errorCode ?? 'unknown-error'));

      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(FirebaseAuthException(code: errorCode ?? 'unknown-error'));
    } else {
      when(mockUser.uid).thenReturn(uid ?? TestData.validUserId);
      when(mockUser.email).thenReturn(email ?? TestData.validEmail);
      when(mockUserCredential.user).thenReturn(mockUser);

      when(mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockUserCredential);

      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockUserCredential);
    }
  }

  static void setupFirebaseDatabaseMocks(
    MockFirebaseDatabase mockDatabase,
    MockDatabaseReference mockRef,
    MockDatabaseEvent mockEvent, {
    bool userExists = true,
    Map<String, dynamic>? userData,
  }) {
    when(mockDatabase.ref(any)).thenReturn(mockRef);
    when(mockRef.get()).thenAnswer((_) async => mockEvent);
    when(mockEvent.exists).thenReturn(userExists);
    when(mockEvent.value).thenReturn(userData ?? TestData.testUserJson);
    when(mockRef.set(any)).thenAnswer((_) async => null);
  }

  static void setupPasswordResetMock(
    MockFirebaseAuth mockAuth, {
    bool shouldThrow = false,
    String? errorCode,
  }) {
    if (shouldThrow) {
      when(mockAuth.sendPasswordResetEmail(email: anyNamed('email')))
          .thenThrow(FirebaseAuthException(code: errorCode ?? 'user-not-found'));
    } else {
      when(mockAuth.sendPasswordResetEmail(email: anyNamed('email')))
          .thenAnswer((_) async => null);
    }
  }

  static void setupSignOutMock(
    MockFirebaseAuth mockAuth, {
    bool shouldThrow = false,
  }) {
    if (shouldThrow) {
      when(mockAuth.signOut()).thenThrow(Exception('Sign out failed'));
    } else {
      when(mockAuth.signOut()).thenAnswer((_) async => null);
    }
  }
}

// Common test matchers
class TestMatchers {
  static Matcher isFirebaseAuthException([String? code]) {
    return isA<FirebaseAuthException>().having(
      (e) => e.code,
      'code',
      code ?? any,
    );
  }

  static Matcher isUserWithEmail(String email) {
    return isA<app_user.User>().having(
      (user) => user.email,
      'email',
      email,
    );
  }

  static Matcher isUserWithId(String id) {
    return isA<app_user.User>().having(
      (user) => user.id,
      'id',
      id,
    );
  }
}

// Test constants
class TestConstants {
  static const Duration shortDelay = Duration(milliseconds: 100);
  static const Duration mediumDelay = Duration(milliseconds: 500);
  static const Duration longDelay = Duration(seconds: 2);

  static const String emptyFieldError = 'Vui lòng nhập đầy đủ thông tin!';
  static const String passwordMismatchError = 'Mật khẩu xác nhận không khớp!';
  static const String passwordTooShortError = 'Mật khẩu phải có ít nhất 6 ký tự!';
  static const String loginSuccessMessage = 'Đăng nhập thành công!';
  static const String signupSuccessMessage = 'Đăng ký thành công!';
  static const String loginErrorPrefix = 'Lỗi đăng nhập:';
  static const String signupErrorPrefix = 'Lỗi đăng ký:';
} 