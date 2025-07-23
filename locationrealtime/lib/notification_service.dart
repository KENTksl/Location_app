import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  static Future<void> initialize() async {
    // Yêu cầu quyền thông báo
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Người dùng đã cấp quyền thông báo');
    } else {
      print('Người dùng từ chối quyền thông báo');
    }

    // Lấy FCM token
    String? token = await _messaging.getToken();
    if (token != null) {
      await _saveTokenToDatabase(token);
    }

    // Lắng nghe token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _saveTokenToDatabase(newToken);
    });

    // Xử lý thông báo khi app đang mở
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });

    // Xử lý khi click vào thông báo
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });
  }

  static Future<void> _saveTokenToDatabase(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _database.ref('users/${user.uid}/fcmToken').set(token);
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    // Hiển thị thông báo local
    print('Nhận thông báo: ${message.notification?.title}');
    
    // Có thể thêm logic hiển thị SnackBar hoặc Dialog
  }

  static void _handleNotificationTap(RemoteMessage message) {
    // Xử lý khi người dùng tap vào thông báo
    print('Tap vào thông báo: ${message.data}');
    
    // Có thể navigate đến trang phù hợp dựa trên data
    String? type = message.data['type'];
    String? friendId = message.data['friendId'];
    
    if (type == 'friend_request' && friendId != null) {
      // Navigate đến trang friend requests
    } else if (type == 'message' && friendId != null) {
      // Navigate đến chat page
    }
  }

  static Future<void> sendFriendRequestNotification(String targetUserId, String senderEmail) async {
    try {
      // Lấy FCM token của người nhận
      final tokenSnap = await _database.ref('users/$targetUserId/fcmToken').get();
      if (tokenSnap.exists) {
        final token = tokenSnap.value as String;
        
        // Gửi thông báo qua Cloud Functions hoặc server
        // Đây là ví dụ, bạn cần implement server-side logic
        await _database.ref('notifications/$targetUserId').push().set({
          'type': 'friend_request',
          'senderId': FirebaseAuth.instance.currentUser?.uid,
          'senderEmail': senderEmail,
          'message': '$senderEmail đã gửi lời mời kết bạn',
          'timestamp': DateTime.now().toIso8601String(),
          'read': false,
        });
      }
    } catch (e) {
      print('Lỗi gửi thông báo: $e');
    }
  }

  static Future<void> sendMessageNotification(String targetUserId, String senderEmail, String message) async {
    try {
      final tokenSnap = await _database.ref('users/$targetUserId/fcmToken').get();
      if (tokenSnap.exists) {
        final token = tokenSnap.value as String;
        
        await _database.ref('notifications/$targetUserId').push().set({
          'type': 'message',
          'senderId': FirebaseAuth.instance.currentUser?.uid,
          'senderEmail': senderEmail,
          'message': message,
          'timestamp': DateTime.now().toIso8601String(),
          'read': false,
        });
      }
    } catch (e) {
      print('Lỗi gửi thông báo tin nhắn: $e');
    }
  }
} 