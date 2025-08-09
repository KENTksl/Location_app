import 'package:flutter_test/flutter_test.dart';
import 'package:locationrealtime/models/user.dart';

void main() {
  group('User Model Tests', () {
    test('should create User with required fields', () {
      final user = User(
        id: 'test-id',
        email: 'test@example.com',
      );

      expect(user.id, 'test-id');
      expect(user.email, 'test@example.com');
      expect(user.avatarUrl, null);
      expect(user.createdAt, null);
      expect(user.isSharingLocation, null);
      expect(user.alwaysShareLocation, null);
      expect(user.location, null);
    });

    test('should create User with all fields', () {
      final now = DateTime.now();
      final location = {'latitude': 10.0, 'longitude': 20.0};
      
      final user = User(
        id: 'test-id',
        email: 'test@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: now,
        isSharingLocation: true,
        alwaysShareLocation: false,
        location: location,
      );

      expect(user.id, 'test-id');
      expect(user.email, 'test@example.com');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
      expect(user.createdAt, now);
      expect(user.isSharingLocation, true);
      expect(user.alwaysShareLocation, false);
      expect(user.location, location);
    });

    test('should create User from JSON with all fields', () {
      final now = DateTime.now();
      final location = {'latitude': 10.0, 'longitude': 20.0};
      
      final json = {
        'id': 'test-id',
        'email': 'test@example.com',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'createdAt': now.toIso8601String(),
        'isSharingLocation': true,
        'alwaysShareLocation': false,
        'location': location,
      };

      final user = User.fromJson(json);

      expect(user.id, 'test-id');
      expect(user.email, 'test@example.com');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
      expect(user.createdAt?.year, now.year);
      expect(user.createdAt?.month, now.month);
      expect(user.createdAt?.day, now.day);
      expect(user.isSharingLocation, true);
      expect(user.alwaysShareLocation, false);
      expect(user.location, location);
    });

    test('should create User from JSON with null fields', () {
      final json = {
        'id': 'test-id',
        'email': 'test@example.com',
      };

      final user = User.fromJson(json);

      expect(user.id, 'test-id');
      expect(user.email, 'test@example.com');
      expect(user.avatarUrl, null);
      expect(user.createdAt, null);
      expect(user.isSharingLocation, null);
      expect(user.alwaysShareLocation, null);
      expect(user.location, null);
    });

    test('should create User from JSON with empty string defaults', () {
      final json = {
        'id': null,
        'email': null,
      };

      final user = User.fromJson(json);

      expect(user.id, '');
      expect(user.email, '');
    });

    test('should convert User to JSON with all fields', () {
      final now = DateTime.now();
      final location = {'latitude': 10.0, 'longitude': 20.0};
      
      final user = User(
        id: 'test-id',
        email: 'test@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: now,
        isSharingLocation: true,
        alwaysShareLocation: false,
        location: location,
      );

      final json = user.toJson();

      expect(json['id'], 'test-id');
      expect(json['email'], 'test@example.com');
      expect(json['avatarUrl'], 'https://example.com/avatar.jpg');
      expect(json['createdAt'], now.toIso8601String());
      expect(json['isSharingLocation'], true);
      expect(json['alwaysShareLocation'], false);
      expect(json['location'], location);
    });

    test('should convert User to JSON with null fields', () {
      final user = User(
        id: 'test-id',
        email: 'test@example.com',
      );

      final json = user.toJson();

      expect(json['id'], 'test-id');
      expect(json['email'], 'test@example.com');
      expect(json['avatarUrl'], null);
      expect(json['createdAt'], null);
      expect(json['isSharingLocation'], null);
      expect(json['alwaysShareLocation'], null);
      expect(json['location'], null);
    });

    test('should copy User with new values', () {
      final originalUser = User(
        id: 'original-id',
        email: 'original@example.com',
        avatarUrl: 'https://example.com/original.jpg',
        createdAt: DateTime(2023, 1, 1),
        isSharingLocation: false,
        alwaysShareLocation: false,
        location: {'latitude': 0.0, 'longitude': 0.0},
      );

      final copiedUser = originalUser.copyWith(
        id: 'new-id',
        email: 'new@example.com',
        isSharingLocation: true,
      );

      expect(copiedUser.id, 'new-id');
      expect(copiedUser.email, 'new@example.com');
      expect(copiedUser.avatarUrl, 'https://example.com/original.jpg');
      expect(copiedUser.createdAt, DateTime(2023, 1, 1));
      expect(copiedUser.isSharingLocation, true);
      expect(copiedUser.alwaysShareLocation, false);
      expect(copiedUser.location, {'latitude': 0.0, 'longitude': 0.0});
    });

    test('should copy User with null values', () {
      final originalUser = User(
        id: 'test-id',
        email: 'test@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: DateTime(2023, 1, 1),
        isSharingLocation: true,
        alwaysShareLocation: true,
        location: {'latitude': 10.0, 'longitude': 20.0},
      );

      final copiedUser = originalUser.copyWith(
        avatarUrl: null,
        createdAt: null,
        isSharingLocation: null,
        alwaysShareLocation: null,
        location: null,
      );

      expect(copiedUser.id, 'test-id');
      expect(copiedUser.email, 'test@example.com');
      expect(copiedUser.avatarUrl, 'https://example.com/avatar.jpg');
      expect(copiedUser.createdAt, DateTime(2023, 1, 1));
      expect(copiedUser.isSharingLocation, true);
      expect(copiedUser.alwaysShareLocation, true);
      expect(copiedUser.location, {'latitude': 10.0, 'longitude': 20.0});
    });

    test('should copy User without changing any fields', () {
      final originalUser = User(
        id: 'test-id',
        email: 'test@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: DateTime(2023, 1, 1),
        isSharingLocation: true,
        alwaysShareLocation: false,
        location: {'latitude': 10.0, 'longitude': 20.0},
      );

      final copiedUser = originalUser.copyWith();

      expect(copiedUser.id, originalUser.id);
      expect(copiedUser.email, originalUser.email);
      expect(copiedUser.avatarUrl, originalUser.avatarUrl);
      expect(copiedUser.createdAt, originalUser.createdAt);
      expect(copiedUser.isSharingLocation, originalUser.isSharingLocation);
      expect(copiedUser.alwaysShareLocation, originalUser.alwaysShareLocation);
      expect(copiedUser.location, originalUser.location);
    });

    test('should handle invalid DateTime in fromJson', () {
      final json = {
        'id': 'test-id',
        'email': 'test@example.com',
        'createdAt': 'invalid-date',
      };

      final user = User.fromJson(json);

      expect(user.id, 'test-id');
      expect(user.email, 'test@example.com');
      expect(user.createdAt, null);
    });

    test('should handle empty JSON', () {
      final json = <String, dynamic>{};

      final user = User.fromJson(json);

      expect(user.id, '');
      expect(user.email, '');
      expect(user.avatarUrl, null);
      expect(user.createdAt, null);
      expect(user.isSharingLocation, null);
      expect(user.alwaysShareLocation, null);
      expect(user.location, null);
    });
  });
} 