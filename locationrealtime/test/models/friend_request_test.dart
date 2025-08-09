import 'package:flutter_test/flutter_test.dart';
import 'package:locationrealtime/models/friend_request.dart';

void main() {
  group('FriendRequest Model Tests', () {
    test('should create FriendRequest with required fields', () {
      final request = FriendRequest(
        id: 'request-id',
        email: 'friend@example.com',
      );

      expect(request.id, 'request-id');
      expect(request.email, 'friend@example.com');
      expect(request.avatarUrl, null);
      expect(request.createdAt, null);
    });

    test('should create FriendRequest with all fields', () {
      final now = DateTime.now();
      
      final request = FriendRequest(
        id: 'request-id',
        email: 'friend@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: now,
      );

      expect(request.id, 'request-id');
      expect(request.email, 'friend@example.com');
      expect(request.avatarUrl, 'https://example.com/avatar.jpg');
      expect(request.createdAt, now);
    });

    test('should create FriendRequest from JSON with all fields', () {
      final now = DateTime.now();
      
      final json = {
        'id': 'request-id',
        'email': 'friend@example.com',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'createdAt': now.toIso8601String(),
      };

      final request = FriendRequest.fromJson(json);

      expect(request.id, 'request-id');
      expect(request.email, 'friend@example.com');
      expect(request.avatarUrl, 'https://example.com/avatar.jpg');
      expect(request.createdAt?.year, now.year);
      expect(request.createdAt?.month, now.month);
      expect(request.createdAt?.day, now.day);
    });

    test('should create FriendRequest from JSON with null fields', () {
      final json = {
        'id': 'request-id',
        'email': 'friend@example.com',
      };

      final request = FriendRequest.fromJson(json);

      expect(request.id, 'request-id');
      expect(request.email, 'friend@example.com');
      expect(request.avatarUrl, null);
      expect(request.createdAt, null);
    });

    test('should create FriendRequest from JSON with empty string defaults', () {
      final json = {
        'id': null,
        'email': null,
      };

      final request = FriendRequest.fromJson(json);

      expect(request.id, '');
      expect(request.email, '');
    });

    test('should convert FriendRequest to JSON with all fields', () {
      final now = DateTime.now();
      
      final request = FriendRequest(
        id: 'request-id',
        email: 'friend@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: now,
      );

      final json = request.toJson();

      expect(json['id'], 'request-id');
      expect(json['email'], 'friend@example.com');
      expect(json['avatarUrl'], 'https://example.com/avatar.jpg');
      expect(json['createdAt'], now.toIso8601String());
    });

    test('should convert FriendRequest to JSON with null fields', () {
      final request = FriendRequest(
        id: 'request-id',
        email: 'friend@example.com',
      );

      final json = request.toJson();

      expect(json['id'], 'request-id');
      expect(json['email'], 'friend@example.com');
      expect(json['avatarUrl'], null);
      expect(json['createdAt'], null);
    });

    test('should copy FriendRequest with new values', () {
      final originalRequest = FriendRequest(
        id: 'original-id',
        email: 'original@example.com',
        avatarUrl: 'https://example.com/original.jpg',
        createdAt: DateTime(2023, 1, 1),
      );

      final copiedRequest = originalRequest.copyWith(
        id: 'new-id',
        email: 'new@example.com',
        avatarUrl: 'https://example.com/new.jpg',
        createdAt: DateTime(2023, 12, 31),
      );

      expect(copiedRequest.id, 'new-id');
      expect(copiedRequest.email, 'new@example.com');
      expect(copiedRequest.avatarUrl, 'https://example.com/new.jpg');
      expect(copiedRequest.createdAt, DateTime(2023, 12, 31));
    });

    test('should copy FriendRequest with null values', () {
      final originalRequest = FriendRequest(
        id: 'request-id',
        email: 'friend@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: DateTime(2023, 1, 1),
      );

      final copiedRequest = originalRequest.copyWith(
        avatarUrl: null,
        createdAt: null,
      );

      expect(copiedRequest.id, 'request-id');
      expect(copiedRequest.email, 'friend@example.com');
      expect(copiedRequest.avatarUrl, 'https://example.com/avatar.jpg');
      expect(copiedRequest.createdAt, DateTime(2023, 1, 1));
    });

    test('should copy FriendRequest without changing any fields', () {
      final originalRequest = FriendRequest(
        id: 'request-id',
        email: 'friend@example.com',
        avatarUrl: 'https://example.com/avatar.jpg',
        createdAt: DateTime(2023, 1, 1),
      );

      final copiedRequest = originalRequest.copyWith();

      expect(copiedRequest.id, originalRequest.id);
      expect(copiedRequest.email, originalRequest.email);
      expect(copiedRequest.avatarUrl, originalRequest.avatarUrl);
      expect(copiedRequest.createdAt, originalRequest.createdAt);
    });

    test('should handle invalid DateTime in fromJson', () {
      final json = {
        'id': 'request-id',
        'email': 'friend@example.com',
        'createdAt': 'invalid-date',
      };

      final request = FriendRequest.fromJson(json);

      expect(request.id, 'request-id');
      expect(request.email, 'friend@example.com');
      expect(request.createdAt, null);
    });

    test('should handle empty JSON', () {
      final json = <String, dynamic>{};

      final request = FriendRequest.fromJson(json);

      expect(request.id, '');
      expect(request.email, '');
      expect(request.avatarUrl, null);
      expect(request.createdAt, null);
    });

    test('should handle long email address', () {
      final longEmail = 'very.long.email.address.with.many.parts@very.long.domain.name.com';
      
      final request = FriendRequest(
        id: 'request-id',
        email: longEmail,
      );

      expect(request.id, 'request-id');
      expect(request.email, longEmail);
      expect(request.email.length, longEmail.length);
    });

    test('should handle special characters in email', () {
      final specialEmail = 'test+tag@example.com';
      
      final request = FriendRequest(
        id: 'request-id',
        email: specialEmail,
      );

      expect(request.id, 'request-id');
      expect(request.email, specialEmail);
    });

    test('should handle unicode characters in email', () {
      final unicodeEmail = 'test@世界.com';
      
      final request = FriendRequest(
        id: 'request-id',
        email: unicodeEmail,
      );

      expect(request.id, 'request-id');
      expect(request.email, unicodeEmail);
    });

    test('should handle empty email', () {
      final request = FriendRequest(
        id: 'request-id',
        email: '',
      );

      expect(request.id, 'request-id');
      expect(request.email, '');
    });

    test('should handle long avatar URL', () {
      final longUrl = 'https://example.com/very/long/path/to/avatar/image/with/many/segments/and/parameters?param1=value1&param2=value2&param3=value3';
      
      final request = FriendRequest(
        id: 'request-id',
        email: 'friend@example.com',
        avatarUrl: longUrl,
      );

      expect(request.id, 'request-id');
      expect(request.email, 'friend@example.com');
      expect(request.avatarUrl, longUrl);
      expect(request.avatarUrl!.length, longUrl.length);
    });

    test('should handle special characters in avatar URL', () {
      final specialUrl = 'https://example.com/avatar.jpg?param=value&another=test';
      
      final request = FriendRequest(
        id: 'request-id',
        email: 'friend@example.com',
        avatarUrl: specialUrl,
      );

      expect(request.id, 'request-id');
      expect(request.email, 'friend@example.com');
      expect(request.avatarUrl, specialUrl);
    });

    test('should handle future date', () {
      final futureDate = DateTime.now().add(Duration(days: 365));
      
      final request = FriendRequest(
        id: 'request-id',
        email: 'friend@example.com',
        createdAt: futureDate,
      );

      expect(request.id, 'request-id');
      expect(request.email, 'friend@example.com');
      expect(request.createdAt, futureDate);
    });

    test('should handle past date', () {
      final pastDate = DateTime.now().subtract(Duration(days: 365));
      
      final request = FriendRequest(
        id: 'request-id',
        email: 'friend@example.com',
        createdAt: pastDate,
      );

      expect(request.id, 'request-id');
      expect(request.email, 'friend@example.com');
      expect(request.createdAt, pastDate);
    });

    test('should handle very old date', () {
      final oldDate = DateTime(1900, 1, 1);
      
      final request = FriendRequest(
        id: 'request-id',
        email: 'friend@example.com',
        createdAt: oldDate,
      );

      expect(request.id, 'request-id');
      expect(request.email, 'friend@example.com');
      expect(request.createdAt, oldDate);
    });
  });
} 