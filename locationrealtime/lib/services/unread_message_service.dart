import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/chat_message.dart';

class UnreadMessageService {
  final FirebaseAuth _auth;
  final FirebaseDatabase _database;

  UnreadMessageService({
    FirebaseAuth? auth,
    FirebaseDatabase? database,
  }) : _auth = auth ?? FirebaseAuth.instance,
        _database = database ?? FirebaseDatabase.instance;

  // Tạo chat ID
  String _getChatId(String uid1, String uid2) {
    return (uid1.compareTo(uid2) < 0) ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  // Lắng nghe số tin nhắn chưa đọc từ một bạn bè
  Stream<int> listenToUnreadCount(String friendId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    final chatId = _getChatId(user.uid, friendId);
    final ref = _database.ref('chats/$chatId/messages');

    return ref.onValue.map((event) {
      final data = event.snapshot.value as List?;
      if (data == null) return 0;

      int unreadCount = 0;
      for (final msgData in data.whereType<Map>()) {
        final message = ChatMessage.fromJson(Map<String, dynamic>.from(msgData));
        // Nếu tin nhắn không phải từ user hiện tại và chưa được đọc
        if (message.from != user.uid && !message.isReadBy(user.uid)) {
          unreadCount++;
        }
      }
      
      return unreadCount;
    });
  }

  // Lắng nghe tổng số tin nhắn chưa đọc từ tất cả bạn bè
  Stream<Map<String, int>> listenToAllUnreadCounts() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value({});

    // Lắng nghe thay đổi trong tất cả chats
    return _database.ref('chats').onValue.asyncMap((event) async {
      // Lấy danh sách bạn bè
      final friendsSnapshot = await _database.ref('users/${user.uid}/friends').get();
      final friendsData = friendsSnapshot.value as Map?;
      if (friendsData == null) return <String, int>{};

      Map<String, int> unreadCounts = {};
      
      for (final friendId in friendsData.keys) {
        final count = await _getUnreadCountForFriend(friendId);
        unreadCounts[friendId] = count;
      }
      
      return unreadCounts;
    });
  }

  // Lấy số tin nhắn chưa đọc từ một bạn bè (async)
  Future<int> _getUnreadCountForFriend(String friendId) async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final chatId = _getChatId(user.uid, friendId);
    final ref = _database.ref('chats/$chatId/messages');

    try {
      final snapshot = await ref.get();
      final data = snapshot.value as List?;
      if (data == null) return 0;

      int unreadCount = 0;
      for (final msgData in data.whereType<Map>()) {
        final message = ChatMessage.fromJson(Map<String, dynamic>.from(msgData));
        // Nếu tin nhắn không phải từ user hiện tại và chưa được đọc
        if (message.from != user.uid && !message.isReadBy(user.uid)) {
          unreadCount++;
        }
      }
      
      return unreadCount;
    } catch (e) {
      print('Error getting unread count for $friendId: $e');
      return 0;
    }
  }

  // Đánh dấu tất cả tin nhắn trong chat là đã đọc
  Future<void> markAllAsRead(String friendId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final chatId = _getChatId(user.uid, friendId);
    final ref = _database.ref('chats/$chatId/messages');

    try {
      final snapshot = await ref.get();
      final data = snapshot.value as List?;
      if (data == null) return;

      // BẢO TOÀN CÁC TRƯỜNG TÙY CHỈNH: không serialize lại qua ChatMessage
      // để tránh mất các key như 'type', 'place' của tin nhắn đặc biệt.
      List<Map<String, dynamic>> updatedMessages = [];
      bool hasUpdates = false;

      for (final msgData in data.whereType<Map>()) {
        final raw = Map<String, dynamic>.from(msgData);
        final from = raw['from']?.toString() ?? '';

        // Lấy readBy hiện có, nếu chưa có thì tạo mới
        Map<String, bool> readBy = {};
        final existingReadBy = raw['readBy'];
        if (existingReadBy is Map) {
          readBy = Map<String, bool>.from(existingReadBy.map((k, v) => MapEntry(k.toString(), v == true)));
        }

        // Chỉ cập nhật tin nhắn từ người khác và chưa được đọc
        final alreadyRead = readBy[user.uid] == true;
        if (from != user.uid && !alreadyRead) {
          readBy[user.uid] = true;
          raw['readBy'] = readBy; // cập nhật trực tiếp vào raw map, giữ nguyên các field khác
          hasUpdates = true;
        }

        updatedMessages.add(raw);
      }

      if (hasUpdates) {
        await ref.set(updatedMessages);
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Lấy số tin nhắn chưa đọc dạng string (hiển thị "5+" nếu > 5)
  String getUnreadCountDisplay(int count) {
    if (count == 0) return '';
    if (count > 5) return '5+';
    return count.toString();
  }
}