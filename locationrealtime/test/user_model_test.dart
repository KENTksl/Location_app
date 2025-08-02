import 'package:flutter_test/flutter_test.dart';
import 'package:locationrealtime/models/user.dart';

void main() {
  group('User Model Tests', () {
    group('Constructor', () {
      test('should create user with required fields', () {
        // Arrange & Act
        final user = User(
          id: 'user123',
          email: 'test@example.com',
        );

        // Assert
        expect(user.id, equals('user123'));
        expect(user.email, equals('test@example.com'));
        expect(user.avatarUrl, isNull);
        expect(user.createdAt, isNull);
        expect(user.isSharingLocation, isNull);
        expect(user.alwaysShareLocation, isNull);
        expect(user.location, isNull);
      });

      test('should create user with all fields', () {
        // Arrange
        final createdAt = DateTime.now();
        final location = {'latitude': 10.0, 'longitude': 20.0};

        // Act
        final user = User(
          id: 'user123',
          email: 'test@example.com',
          avatarUrl: 'https://example.com/avatar.jpg',
          createdAt: createdAt,
          isSharingLocation: true,
          alwaysShareLocation: false,
          location: location,
        );

        // Assert
        expect(user.id, equals('user123'));
        expect(user.email, equals('test@example.com'));
        expect(user.avatarUrl, equals('https://example.com/avatar.jpg'));
        expect(user.createdAt, equals(createdAt));
        expect(user.isSharingLocation, isTrue);
        expect(user.alwaysShareLocation, isFalse);
        expect(user.location, equals(location));
      });
    });

    group('fromJson', () {
      test('should create user from valid JSON', () {
        // Arrange
        final json = {
          'id': 'user123',
          'email': 'test@example.com',
          'avatarUrl': 'https://example.com/avatar.jpg',
          'createdAt': '2023-01-01T00:00:00.000Z',
          'isSharingLocation': true,
          'alwaysShareLocation': false,
          'location': {'latitude': 10.0, 'longitude': 20.0},
        };

        // Act
        final user = User.fromJson(json);

        // Assert
        expect(user.id, equals('user123'));
        expect(user.email, equals('test@example.com'));
        expect(user.avatarUrl, equals('https://example.com/avatar.jpg'));
        expect(user.createdAt, isNotNull);
        expect(user.createdAt!.year, equals(2023));
        expect(user.createdAt!.month, equals(1));
        expect(user.createdAt!.day, equals(1));
        expect(user.isSharingLocation, isTrue);
        expect(user.alwaysShareLocation, isFalse);
        expect(user.location, equals({'latitude': 10.0, 'longitude': 20.0}));
      });

      test('should create user from JSON with missing optional fields', () {
        // Arrange
        final json = {
          'id': 'user123',
          'email': 'test@example.com',
        };

        // Act
        final user = User.fromJson(json);

        // Assert
        expect(user.id, equals('user123'));
        expect(user.email, equals('test@example.com'));
        expect(user.avatarUrl, isNull);
        expect(user.createdAt, isNull);
        expect(user.isSharingLocation, isNull);
        expect(user.alwaysShareLocation, isNull);
        expect(user.location, isNull);
      });

      test('should handle null values in JSON', () {
        // Arrange
        final json = {
          'id': 'user123',
          'email': 'test@example.com',
          'avatarUrl': null,
          'createdAt': null,
          'isSharingLocation': null,
          'alwaysShareLocation': null,
          'location': null,
        };

        // Act
        final user = User.fromJson(json);

        // Assert
        expect(user.id, equals('user123'));
        expect(user.email, equals('test@example.com'));
        expect(user.avatarUrl, isNull);
        expect(user.createdAt, isNull);
        expect(user.isSharingLocation, isNull);
        expect(user.alwaysShareLocation, isNull);
        expect(user.location, isNull);
      });

      test('should handle empty string values', () {
        // Arrange
        final json = {
          'id': '',
          'email': '',
          'avatarUrl': '',
          'createdAt': '',
          'isSharingLocation': false,
          'alwaysShareLocation': false,
          'location': {},
        };

        // Act
        final user = User.fromJson(json);

        // Assert
        expect(user.id, equals(''));
        expect(user.email, equals(''));
        expect(user.avatarUrl, equals(''));
        expect(user.createdAt, isNull); // Empty string should result in null
        expect(user.isSharingLocation, isFalse);
        expect(user.alwaysShareLocation, isFalse);
        expect(user.location, equals({}));
      });
    });

    group('toJson', () {
      test('should convert user to JSON with all fields', () {
        // Arrange
        final createdAt = DateTime(2023, 1, 1, 12, 0, 0);
        final location = {'latitude': 10.0, 'longitude': 20.0};
        final user = User(
          id: 'user123',
          email: 'test@example.com',
          avatarUrl: 'https://example.com/avatar.jpg',
          createdAt: createdAt,
          isSharingLocation: true,
          alwaysShareLocation: false,
          location: location,
        );

        // Act
        final json = user.toJson();

        // Assert
        expect(json['id'], equals('user123'));
        expect(json['email'], equals('test@example.com'));
        expect(json['avatarUrl'], equals('https://example.com/avatar.jpg'));
        expect(json['createdAt'], equals('2023-01-01T12:00:00.000'));
        expect(json['isSharingLocation'], isTrue);
        expect(json['alwaysShareLocation'], isFalse);
        expect(json['location'], equals(location));
      });

      test('should convert user to JSON with null optional fields', () {
        // Arrange
        final user = User(
          id: 'user123',
          email: 'test@example.com',
        );

        // Act
        final json = user.toJson();

        // Assert
        expect(json['id'], equals('user123'));
        expect(json['email'], equals('test@example.com'));
        expect(json['avatarUrl'], isNull);
        expect(json['createdAt'], isNull);
        expect(json['isSharingLocation'], isNull);
        expect(json['alwaysShareLocation'], isNull);
        expect(json['location'], isNull);
      });

      test('should handle empty string values in JSON', () {
        // Arrange
        final user = User(
          id: '',
          email: '',
          avatarUrl: '',
        );

        // Act
        final json = user.toJson();

        // Assert
        expect(json['id'], equals(''));
        expect(json['email'], equals(''));
        expect(json['avatarUrl'], equals(''));
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        // Arrange
        final originalUser = User(
          id: 'user123',
          email: 'test@example.com',
          avatarUrl: 'https://example.com/avatar.jpg',
          createdAt: DateTime(2023, 1, 1),
          isSharingLocation: true,
          alwaysShareLocation: false,
          location: {'latitude': 10.0, 'longitude': 20.0},
        );

        // Act
        final updatedUser = originalUser.copyWith(
          email: 'updated@example.com',
          isSharingLocation: false,
          location: {'latitude': 30.0, 'longitude': 40.0},
        );

        // Assert
        expect(updatedUser.id, equals('user123')); // Unchanged
        expect(updatedUser.email, equals('updated@example.com')); // Updated
        expect(updatedUser.avatarUrl, equals('https://example.com/avatar.jpg')); // Unchanged
        expect(updatedUser.createdAt, equals(DateTime(2023, 1, 1))); // Unchanged
        expect(updatedUser.isSharingLocation, isFalse); // Updated
        expect(updatedUser.alwaysShareLocation, isFalse); // Unchanged
        expect(updatedUser.location, equals({'latitude': 30.0, 'longitude': 40.0})); // Updated
      });

      test('should create copy with all fields updated', () {
        // Arrange
        final originalUser = User(
          id: 'user123',
          email: 'test@example.com',
        );

        final newCreatedAt = DateTime(2024, 1, 1);
        final newLocation = {'latitude': 50.0, 'longitude': 60.0};

        // Act
        final updatedUser = originalUser.copyWith(
          id: 'user456',
          email: 'new@example.com',
          avatarUrl: 'https://example.com/new-avatar.jpg',
          createdAt: newCreatedAt,
          isSharingLocation: true,
          alwaysShareLocation: true,
          location: newLocation,
        );

        // Assert
        expect(updatedUser.id, equals('user456'));
        expect(updatedUser.email, equals('new@example.com'));
        expect(updatedUser.avatarUrl, equals('https://example.com/new-avatar.jpg'));
        expect(updatedUser.createdAt, equals(newCreatedAt));
        expect(updatedUser.isSharingLocation, isTrue);
        expect(updatedUser.alwaysShareLocation, isTrue);
        expect(updatedUser.location, equals(newLocation));
      });

      test('should create copy with null values', () {
        // Arrange
        final originalUser = User(
          id: 'user123',
          email: 'test@example.com',
          avatarUrl: 'https://example.com/avatar.jpg',
          createdAt: DateTime(2023, 1, 1),
          isSharingLocation: true,
          alwaysShareLocation: false,
          location: {'latitude': 10.0, 'longitude': 20.0},
        );

        // Act
        final updatedUser = originalUser.copyWith(
          avatarUrl: null,
          createdAt: null,
          isSharingLocation: null,
          alwaysShareLocation: null,
          location: null,
        );

        // Assert
        expect(updatedUser.id, equals('user123')); // Unchanged
        expect(updatedUser.email, equals('test@example.com')); // Unchanged
        expect(updatedUser.avatarUrl, isNull); // Set to null
        expect(updatedUser.createdAt, isNull); // Set to null
        expect(updatedUser.isSharingLocation, isNull); // Set to null
        expect(updatedUser.alwaysShareLocation, isNull); // Set to null
        expect(updatedUser.location, isNull); // Set to null
      });
    });

    group('Equality', () {
      test('should be equal when all fields are the same', () {
        // Arrange
        final user1 = User(
          id: 'user123',
          email: 'test@example.com',
          avatarUrl: 'https://example.com/avatar.jpg',
          createdAt: DateTime(2023, 1, 1),
          isSharingLocation: true,
          alwaysShareLocation: false,
          location: {'latitude': 10.0, 'longitude': 20.0},
        );

        final user2 = User(
          id: 'user123',
          email: 'test@example.com',
          avatarUrl: 'https://example.com/avatar.jpg',
          createdAt: DateTime(2023, 1, 1),
          isSharingLocation: true,
          alwaysShareLocation: false,
          location: {'latitude': 10.0, 'longitude': 20.0},
        );

        // Act & Assert
        expect(user1, equals(user2));
        expect(user1.hashCode, equals(user2.hashCode));
      });

      test('should not be equal when fields are different', () {
        // Arrange
        final user1 = User(
          id: 'user123',
          email: 'test@example.com',
        );

        final user2 = User(
          id: 'user456',
          email: 'test@example.com',
        );

        // Act & Assert
        expect(user1, isNot(equals(user2)));
      });
    });

    group('Edge Cases', () {
      test('should handle very long email addresses', () {
        // Arrange
        final longEmail = 'a' * 100 + '@example.com';

        // Act
        final user = User(
          id: 'user123',
          email: longEmail,
        );

        // Assert
        expect(user.email, equals(longEmail));
        expect(user.toJson()['email'], equals(longEmail));
      });

      test('should handle special characters in email', () {
        // Arrange
        final specialEmail = 'test+tag@example.com';

        // Act
        final user = User(
          id: 'user123',
          email: specialEmail,
        );

        // Assert
        expect(user.email, equals(specialEmail));
        expect(user.toJson()['email'], equals(specialEmail));
      });

      test('should handle complex location data', () {
        // Arrange
        final complexLocation = {
          'latitude': 10.123456789,
          'longitude': -20.987654321,
          'altitude': 100.5,
          'accuracy': 5.0,
          'timestamp': 1234567890,
        };

        // Act
        final user = User(
          id: 'user123',
          email: 'test@example.com',
          location: complexLocation,
        );

        // Assert
        expect(user.location, equals(complexLocation));
        expect(user.toJson()['location'], equals(complexLocation));
      });
    });
  });
} 