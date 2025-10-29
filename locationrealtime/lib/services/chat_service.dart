import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/chat_message.dart';

class ChatService {
  final FirebaseAuth _auth;
  final FirebaseDatabase _database;

  ChatService({
    FirebaseAuth? auth,
    FirebaseDatabase? database,
  }) : _auth = auth ?? FirebaseAuth.instance,
        _database = database ?? FirebaseDatabase.instance;

  // Tạo chat ID
  String _getChatId(String uid1, String uid2) {
    return (uid1.compareTo(uid2) < 0) ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  // Lắng nghe tin nhắn
  Stream<List<ChatMessage>> listenToMessages(String friendId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    final chatId = _getChatId(user.uid, friendId);
    final ref = _database.ref('chats/$chatId/messages');

    return ref.onValue.map((event) {
      final data = event.snapshot.value as List?;
      if (data != null) {
        return data.whereType<Map>().map((msg) {
          return ChatMessage.fromJson({...msg, 'chatId': chatId});
        }).toList();
      }
      return [];
    });
  }

  // Gửi tin nhắn
  Future<void> sendMessage(String friendId, String text) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final chatId = _getChatId(user.uid, friendId);
    final ref = _database.ref('chats/$chatId/messages');

    try {
      final snap = await ref.get();
      List msgs = [];
      if (snap.exists && snap.value is List) {
        msgs = List.from(snap.value as List);
      }

      // Giới hạn 30 tin nhắn gần nhất
      if (msgs.length >= 30) {
        msgs = msgs.sublist(msgs.length - 29);
      }

      msgs.add({
        'from': user.uid,
        'text': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'readBy': {user.uid: true}, // Người gửi tự động đã đọc
      });

      await ref.set(msgs);
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  // Lấy tin nhắn cuối cùng
  Future<ChatMessage?> getLastMessage(String friendId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final chatId = _getChatId(user.uid, friendId);
    final ref = _database.ref('chats/$chatId/messages');

    try {
      final snap = await ref.get();
      if (snap.exists && snap.value is List) {
        final messages = snap.value as List;
        if (messages.isNotEmpty) {
          final lastMsg = messages.last as Map;
          return ChatMessage.fromJson({...lastMsg, 'chatId': chatId});
        }
      }
      return null;
    } catch (e) {
      print('Error getting last message: $e');
      return null;
    }
  }

  // Lấy danh sách chat
  Future<List<Map<String, dynamic>>> getChatList() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      // Lấy danh sách bạn bè
      final friendsRef = _database.ref('users/${user.uid}/friends');
      final friendsSnap = await friendsRef.get();

      List<Map<String, dynamic>> chats = [];

      if (friendsSnap.exists && friendsSnap.value is Map) {
        final friends = friendsSnap.value as Map;

        for (final friendId in friends.keys) {
          // Lấy thông tin bạn bè
          final userSnap = await _database.ref('users/$friendId').get();
          final friendEmail =
              userSnap.child('email').value?.toString() ?? friendId;

          // Lấy tin nhắn cuối cùng
          final lastMessage = await getLastMessage(friendId);

          chats.add({
            'friendId': friendId,
            'friendEmail': friendEmail,
            'lastMessage': lastMessage?.text ?? 'Chưa có tin nhắn',
            'lastTime': lastMessage?.timestamp != null
                ? _formatTime(
                    DateTime.fromMillisecondsSinceEpoch(lastMessage!.timestamp),
                  )
                : '',
          });
        }
      }

      return chats;
    } catch (e) {
      print('Error getting chat list: $e');
      return [];
    }
  }

  // Format thời gian
  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }
}
