import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locationrealtime/pages/friend_requests_page.dart';

void main() {
  group('FriendRequestsPage', () {
    test('should be a StatefulWidget', () {
      const page = FriendRequestsPage();
      expect(page, isA<StatefulWidget>());
    });

    test('should have proper widget type', () {
      const page = FriendRequestsPage();
      expect(page.runtimeType, FriendRequestsPage);
    });

    test('should be able to create instance', () {
      // Test that we can create an instance without errors
      const page = FriendRequestsPage();
      expect(page, isNotNull);
    });

    test('should have correct key', () {
      const key = Key('test_key');
      const page = FriendRequestsPage(key: key);
      expect(page.key, equals(key));
    });

    test('should have no key by default', () {
      const page = FriendRequestsPage();
      expect(page.key, isNull);
    });

    test('should be const constructible', () {
      const page = FriendRequestsPage();
      expect(page, isA<FriendRequestsPage>());
    });

    test('should have correct widget name', () {
      const page = FriendRequestsPage();
      expect(page.toString(), contains('FriendRequestsPage'));
    });
  });
}
