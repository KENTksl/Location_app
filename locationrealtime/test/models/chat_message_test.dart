import 'package:flutter_test/flutter_test.dart';
import 'package:locationrealtime/models/chat_message.dart';

void main() {
  group('ChatMessage Model Tests', () {
    test('should create ChatMessage with required fields', () {
      final message = ChatMessage(
        from: 'user-id',
        text: 'Hello world',
        timestamp: 1234567890,
      );

      expect(message.from, 'user-id');
      expect(message.text, 'Hello world');
      expect(message.timestamp, 1234567890);
      expect(message.chatId, null);
    });

    test('should create ChatMessage with all fields', () {
      final message = ChatMessage(
        from: 'user-id',
        text: 'Hello world',
        timestamp: 1234567890,
        chatId: 'chat-id',
      );

      expect(message.from, 'user-id');
      expect(message.text, 'Hello world');
      expect(message.timestamp, 1234567890);
      expect(message.chatId, 'chat-id');
    });

    test('should create ChatMessage from JSON with all fields', () {
      final json = {
        'from': 'user-id',
        'text': 'Hello world',
        'timestamp': 1234567890,
        'chatId': 'chat-id',
      };

      final message = ChatMessage.fromJson(json);

      expect(message.from, 'user-id');
      expect(message.text, 'Hello world');
      expect(message.timestamp, 1234567890);
      expect(message.chatId, 'chat-id');
    });

    test('should create ChatMessage from JSON with null fields', () {
      final json = {
        'from': 'user-id',
        'text': 'Hello world',
        'timestamp': 1234567890,
      };

      final message = ChatMessage.fromJson(json);

      expect(message.from, 'user-id');
      expect(message.text, 'Hello world');
      expect(message.timestamp, 1234567890);
      expect(message.chatId, null);
    });

    test('should create ChatMessage from JSON with empty string defaults', () {
      final json = {
        'from': null,
        'text': null,
        'timestamp': null,
      };

      final message = ChatMessage.fromJson(json);

      expect(message.from, '');
      expect(message.text, '');
      expect(message.timestamp, 0);
    });

    test('should convert ChatMessage to JSON with all fields', () {
      final message = ChatMessage(
        from: 'user-id',
        text: 'Hello world',
        timestamp: 1234567890,
        chatId: 'chat-id',
      );

      final json = message.toJson();

      expect(json['from'], 'user-id');
      expect(json['text'], 'Hello world');
      expect(json['timestamp'], 1234567890);
      expect(json['chatId'], 'chat-id');
    });

    test('should convert ChatMessage to JSON with null fields', () {
      final message = ChatMessage(
        from: 'user-id',
        text: 'Hello world',
        timestamp: 1234567890,
      );

      final json = message.toJson();

      expect(json['from'], 'user-id');
      expect(json['text'], 'Hello world');
      expect(json['timestamp'], 1234567890);
      expect(json['chatId'], null);
    });

    test('should copy ChatMessage with new values', () {
      final originalMessage = ChatMessage(
        from: 'original-user',
        text: 'Original message',
        timestamp: 1234567890,
        chatId: 'original-chat',
      );

      final copiedMessage = originalMessage.copyWith(
        from: 'new-user',
        text: 'New message',
        timestamp: 9876543210,
        chatId: 'new-chat',
      );

      expect(copiedMessage.from, 'new-user');
      expect(copiedMessage.text, 'New message');
      expect(copiedMessage.timestamp, 9876543210);
      expect(copiedMessage.chatId, 'new-chat');
    });

    test('should copy ChatMessage with null values', () {
      final originalMessage = ChatMessage(
        from: 'user-id',
        text: 'Hello world',
        timestamp: 1234567890,
        chatId: 'chat-id',
      );

      final copiedMessage = originalMessage.copyWith(
        chatId: null,
      );

      expect(copiedMessage.from, 'user-id');
      expect(copiedMessage.text, 'Hello world');
      expect(copiedMessage.timestamp, 1234567890);
      expect(copiedMessage.chatId, 'chat-id');
    });

    test('should copy ChatMessage without changing any fields', () {
      final originalMessage = ChatMessage(
        from: 'user-id',
        text: 'Hello world',
        timestamp: 1234567890,
        chatId: 'chat-id',
      );

      final copiedMessage = originalMessage.copyWith();

      expect(copiedMessage.from, originalMessage.from);
      expect(copiedMessage.text, originalMessage.text);
      expect(copiedMessage.timestamp, originalMessage.timestamp);
      expect(copiedMessage.chatId, originalMessage.chatId);
    });

    test('should handle empty JSON', () {
      final json = <String, dynamic>{};

      final message = ChatMessage.fromJson(json);

      expect(message.from, '');
      expect(message.text, '');
      expect(message.timestamp, 0);
      expect(message.chatId, null);
    });

    test('should handle timestamp as int in fromJson', () {
      final json = {
        'from': 'user-id',
        'text': 'Hello world',
        'timestamp': 1234567890,
      };

      final message = ChatMessage.fromJson(json);

      expect(message.from, 'user-id');
      expect(message.text, 'Hello world');
      expect(message.timestamp, 1234567890);
    });

    test('should handle timestamp as double in fromJson', () {
      final json = {
        'from': 'user-id',
        'text': 'Hello world',
        'timestamp': 1234567890.0,
      };

      final message = ChatMessage.fromJson(json);

      expect(message.from, 'user-id');
      expect(message.text, 'Hello world');
      expect(message.timestamp, 1234567890);
    });

    test('should handle null timestamp in fromJson', () {
      final json = {
        'from': 'user-id',
        'text': 'Hello world',
        'timestamp': null,
      };

      final message = ChatMessage.fromJson(json);

      expect(message.from, 'user-id');
      expect(message.text, 'Hello world');
      expect(message.timestamp, 0);
    });

    test('should handle long text message', () {
      final longText = 'A' * 1000; // 1000 character message
      
      final message = ChatMessage(
        from: 'user-id',
        text: longText,
        timestamp: 1234567890,
      );

      expect(message.from, 'user-id');
      expect(message.text, longText);
      expect(message.text.length, 1000);
      expect(message.timestamp, 1234567890);
    });

    test('should handle special characters in text', () {
      final specialText = 'Hello! @#\$%^&*()_+-=[]{}|;:,.<>?/';
      
      final message = ChatMessage(
        from: 'user-id',
        text: specialText,
        timestamp: 1234567890,
      );

      expect(message.from, 'user-id');
      expect(message.text, specialText);
      expect(message.timestamp, 1234567890);
    });

    test('should handle unicode characters in text', () {
      final unicodeText = 'Hello 世界 🌍 emoji 😀';
      
      final message = ChatMessage(
        from: 'user-id',
        text: unicodeText,
        timestamp: 1234567890,
      );

      expect(message.from, 'user-id');
      expect(message.text, unicodeText);
      expect(message.timestamp, 1234567890);
    });

    test('should handle empty text', () {
      final message = ChatMessage(
        from: 'user-id',
        text: '',
        timestamp: 1234567890,
      );

      expect(message.from, 'user-id');
      expect(message.text, '');
      expect(message.timestamp, 1234567890);
    });

    test('should handle zero timestamp', () {
      final message = ChatMessage(
        from: 'user-id',
        text: 'Hello world',
        timestamp: 0,
      );

      expect(message.from, 'user-id');
      expect(message.text, 'Hello world');
      expect(message.timestamp, 0);
    });

    test('should handle negative timestamp', () {
      final message = ChatMessage(
        from: 'user-id',
        text: 'Hello world',
        timestamp: -1234567890,
      );

      expect(message.from, 'user-id');
      expect(message.text, 'Hello world');
      expect(message.timestamp, -1234567890);
    });
  });
} 