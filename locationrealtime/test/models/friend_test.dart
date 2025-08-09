import 'package:flutter_test/flutter_test.dart';
import 'package:locationrealtime/models/friend.dart';

void main() {
  group('Friend Model Tests', () {
    test('should create Friend with required fields', () {
      final friend = Friend(
        id: 'friend-id',
        email: 'friend@example.com',
      );

      expect(friend.id, 'friend-id');
      expect(friend.email, 'friend@example.com');
      expect(friend.avatarUrl, null);
      expect(friend.distance, null);
      expect(friend.isOnline, null);
      expect(friend.isSharingLocation, null);
      expect(friend.location, null);
    });

    test('should create Friend with all fields', () {
      final location = {'latitude': 10.0, 'longitude': 20.0};
      
      final friend = Friend(
        id: 'friend-id',
        email: 'friend@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        distance: 5.5,
        isOnline: true,
        isSharingLocation: true,
        location: location,
      );

      expect(friend.id, 'friend-id');
      expect(friend.email, 'friend@example.com');
      expect(friend.avatarUrl, 'https://example.com/avatar.jpg');
      expect(friend.distance, 5.5);
      expect(friend.isOnline, true);
      expect(friend.isSharingLocation, true);
      expect(friend.location, location);
    });

    test('should create Friend from JSON with all fields', () {
      final location = {'latitude': 10.0, 'longitude': 20.0};
      
      final json = {
        'id': 'friend-id',
        'email': 'friend@example.com',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'distance': 5.5,
        'isOnline': true,
        'isSharingLocation': true,
        'location': location,
      };

      final friend = Friend.fromJson(json);

      expect(friend.id, 'friend-id');
      expect(friend.email, 'friend@example.com');
      expect(friend.avatarUrl, 'https://example.com/avatar.jpg');
      expect(friend.distance, 5.5);
      expect(friend.isOnline, true);
      expect(friend.isSharingLocation, true);
      expect(friend.location, location);
    });

    test('should create Friend from JSON with null fields', () {
      final json = {
        'id': 'friend-id',
        'email': 'friend@example.com',
      };

      final friend = Friend.fromJson(json);

      expect(friend.id, 'friend-id');
      expect(friend.email, 'friend@example.com');
      expect(friend.avatarUrl, null);
      expect(friend.distance, null);
      expect(friend.isOnline, null);
      expect(friend.isSharingLocation, null);
      expect(friend.location, null);
    });

    test('should create Friend from JSON with empty string defaults', () {
      final json = {
        'id': null,
        'email': null,
      };

      final friend = Friend.fromJson(json);

      expect(friend.id, '');
      expect(friend.email, '');
    });

    test('should convert Friend to JSON with all fields', () {
      final location = {'latitude': 10.0, 'longitude': 20.0};
      
      final friend = Friend(
        id: 'friend-id',
        email: 'friend@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        distance: 5.5,
        isOnline: true,
        isSharingLocation: true,
        location: location,
      );

      final json = friend.toJson();

      expect(json['id'], 'friend-id');
      expect(json['email'], 'friend@example.com');
      expect(json['avatarUrl'], 'https://example.com/avatar.jpg');
      expect(json['distance'], 5.5);
      expect(json['isOnline'], true);
      expect(json['isSharingLocation'], true);
      expect(json['location'], location);
    });

    test('should convert Friend to JSON with null fields', () {
      final friend = Friend(
        id: 'friend-id',
        email: 'friend@example.com',
      );

      final json = friend.toJson();

      expect(json['id'], 'friend-id');
      expect(json['email'], 'friend@example.com');
      expect(json['avatarUrl'], null);
      expect(json['distance'], null);
      expect(json['isOnline'], null);
      expect(json['isSharingLocation'], null);
      expect(json['location'], null);
    });

    test('should copy Friend with new values', () {
      final originalFriend = Friend(
        id: 'original-id',
        email: 'original@example.com',
        avatarUrl: 'https://example.com/original.jpg',
        distance: 1.0,
        isOnline: false,
        isSharingLocation: false,
        location: {'latitude': 0.0, 'longitude': 0.0},
      );

      final copiedFriend = originalFriend.copyWith(
        id: 'new-id',
        email: 'new@example.com',
        distance: 10.0,
        isOnline: true,
      );

      expect(copiedFriend.id, 'new-id');
      expect(copiedFriend.email, 'new@example.com');
      expect(copiedFriend.avatarUrl, 'https://example.com/original.jpg');
      expect(copiedFriend.distance, 10.0);
      expect(copiedFriend.isOnline, true);
      expect(copiedFriend.isSharingLocation, false);
      expect(copiedFriend.location, {'latitude': 0.0, 'longitude': 0.0});
    });

    test('should copy Friend with null values', () {
      final originalFriend = Friend(
        id: 'friend-id',
        email: 'friend@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        distance: 5.5,
        isOnline: true,
        isSharingLocation: true,
        location: {'latitude': 10.0, 'longitude': 20.0},
      );

      final copiedFriend = originalFriend.copyWith(
        avatarUrl: null,
        distance: null,
        isOnline: null,
        isSharingLocation: null,
        location: null,
      );

      expect(copiedFriend.id, 'friend-id');
      expect(copiedFriend.email, 'friend@example.com');
      expect(copiedFriend.avatarUrl, 'https://example.com/avatar.jpg');
      expect(copiedFriend.distance, 5.5);
      expect(copiedFriend.isOnline, true);
      expect(copiedFriend.isSharingLocation, true);
      expect(copiedFriend.location, {'latitude': 10.0, 'longitude': 20.0});
    });

    test('should copy Friend without changing any fields', () {
      final originalFriend = Friend(
        id: 'friend-id',
        email: 'friend@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        distance: 5.5,
        isOnline: true,
        isSharingLocation: true,
        location: {'latitude': 10.0, 'longitude': 20.0},
      );

      final copiedFriend = originalFriend.copyWith();

      expect(copiedFriend.id, originalFriend.id);
      expect(copiedFriend.email, originalFriend.email);
      expect(copiedFriend.avatarUrl, originalFriend.avatarUrl);
      expect(copiedFriend.distance, originalFriend.distance);
      expect(copiedFriend.isOnline, originalFriend.isOnline);
      expect(copiedFriend.isSharingLocation, originalFriend.isSharingLocation);
      expect(copiedFriend.location, originalFriend.location);
    });

    test('should handle distance as int in fromJson', () {
      final json = {
        'id': 'friend-id',
        'email': 'friend@example.com',
        'distance': 5,
      };

      final friend = Friend.fromJson(json);

      expect(friend.id, 'friend-id');
      expect(friend.email, 'friend@example.com');
      expect(friend.distance, 5.0);
    });

    test('should handle distance as double in fromJson', () {
      final json = {
        'id': 'friend-id',
        'email': 'friend@example.com',
        'distance': 5.5,
      };

      final friend = Friend.fromJson(json);

      expect(friend.id, 'friend-id');
      expect(friend.email, 'friend@example.com');
      expect(friend.distance, 5.5);
    });

    test('should handle empty JSON', () {
      final json = <String, dynamic>{};

      final friend = Friend.fromJson(json);

      expect(friend.id, '');
      expect(friend.email, '');
      expect(friend.avatarUrl, null);
      expect(friend.distance, null);
      expect(friend.isOnline, null);
      expect(friend.isSharingLocation, null);
      expect(friend.location, null);
    });

    test('should handle null distance in fromJson', () {
      final json = {
        'id': 'friend-id',
        'email': 'friend@example.com',
        'distance': null,
      };

      final friend = Friend.fromJson(json);

      expect(friend.id, 'friend-id');
      expect(friend.email, 'friend@example.com');
      expect(friend.distance, null);
    });
  });
} 