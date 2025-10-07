import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_database/firebase_database.dart';

// Mock Firebase for testing
class MockFirebase {
  static Future<void> setup() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Create mock Firebase app
    final mockApp = MockFirebaseApp();

    // Mock Firebase.initializeApp to return our mock app
    when(Firebase.initializeApp()).thenAnswer((_) async => mockApp);
    when(Firebase.app()).thenReturn(mockApp);
  }
}

// Mock Firebase App
class MockFirebaseApp extends Mock implements FirebaseApp {
  @override
  String get name => '[DEFAULT]';

  @override
  FirebaseOptions get options => MockFirebaseOptions();
}

// Mock Firebase Options
// ignore: must_be_immutable
class MockFirebaseOptions extends Mock implements FirebaseOptions {
  @override
  String get apiKey => 'test-api-key';

  @override
  String get appId => 'test-app-id';

  @override
  String get messagingSenderId => 'test-sender-id';

  @override
  String get projectId => 'test-project-id';
}

// Mock Firebase Database
class MockFirebaseDatabase extends Mock implements FirebaseDatabase {
  @override
  DatabaseReference ref([String? path]) => MockDatabaseReference();
}

// Mock Database Reference
class MockDatabaseReference extends Mock implements DatabaseReference {
  @override
  DatabaseReference child(String path) => this;

  @override
  Future<DataSnapshot> get() async => MockDataSnapshot();

  @override
  Future<void> set(dynamic value) async {}
}

// Mock Data Snapshot
class MockDataSnapshot extends Mock implements DataSnapshot {
  @override
  bool get exists => false;

  @override
  Iterable<DataSnapshot> get children => [];

  @override
  dynamic get value => null;

  @override
  String? get key => null;
}

// Test app wrapper that provides a simple test environment
class TestApp extends StatelessWidget {
  final Widget child;

  const TestApp({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: child);
  }
}

// Test utilities
class TestUtils {
  static Future<void> pumpWidget(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(TestApp(child: widget));
    await tester.pumpAndSettle();
  }

  static Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
}
