import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({Key? key}) : super(key: key);

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  List<Map<String, dynamic>> _chatList = [];
  bool _loading = true;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadChatList();
  }

  Future<void> _loadChatList() async {
    if (user == null) return;

    setState(() => _loading = true);

    try {
      // Lấy danh sách bạn bè
      final friendsRef = FirebaseDatabase.instance.ref(
        'users/${user!.uid}/friends',
      );
      final friendsSnap = await friendsRef.get();

      List<Map<String, dynamic>> chats = [];

      if (friendsSnap.exists && friendsSnap.value is Map) {
        final friends = friendsSnap.value as Map;

        for (final friendId in friends.keys) {
          // Lấy thông tin bạn bè
          final userSnap = await FirebaseDatabase.instance
              .ref('users/$friendId')
              .get();
          final friendEmail =
              userSnap.child('email').value?.toString() ?? friendId;

          // Lấy tin nhắn cuối cùng
          final chatId = _getChatId(user!.uid, friendId);
          final chatRef = FirebaseDatabase.instance.ref(
            'chats/$chatId/messages',
          );
          final chatSnap = await chatRef.get();

          String lastMessage = 'Chưa có tin nhắn';
          String lastTime = '';

          if (chatSnap.exists && chatSnap.value is List) {
            final messages = chatSnap.value as List;
            if (messages.isNotEmpty) {
              final lastMsg = messages.last as Map;
              lastMessage = lastMsg['text']?.toString() ?? 'Chưa có tin nhắn';
              final timestamp = lastMsg['timestamp'];
              if (timestamp != null) {
                final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
                lastTime = _formatTime(date);
              }
            }
          }

          chats.add({
            'friendId': friendId,
            'friendEmail': friendEmail,
            'lastMessage': lastMessage,
            'lastTime': lastTime,
          });
        }
      }

      setState(() {
        _chatList = chats;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      print('Lỗi tải danh sách chat: $e');
    }
  }

  String _getChatId(String uid1, String uid2) {
    return (uid1.compareTo(uid2) < 0) ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin nhắn'),
        backgroundColor: Colors.blue,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChatList,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _chatList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Chưa có cuộc trò chuyện nào',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Hãy kết bạn và bắt đầu trò chuyện!',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _chatList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final chat = _chatList[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        (chat['friendEmail'] != null &&
                                chat['friendEmail'].isNotEmpty)
                            ? chat['friendEmail'][0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      chat['friendEmail'] ?? chat['friendId'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      chat['lastMessage'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: chat['lastTime'].isNotEmpty
                        ? Text(
                            chat['lastTime'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatPage(
                            friendId: chat['friendId'],
                            friendEmail: chat['friendEmail'] ?? '',
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
