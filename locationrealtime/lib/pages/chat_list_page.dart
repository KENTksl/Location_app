import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

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
      appBar: AppTheme.appBar(
        title: 'Tin nhắn',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadChatList,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: _loading
            ? AppTheme.loadingWidget(message: 'Đang tải tin nhắn...')
            : _chatList.isEmpty
            ? AppTheme.emptyStateWidget(
                message:
                    'Chưa có cuộc trò chuyện nào.\nHãy kết bạn và bắt đầu trò chuyện!',
                icon: Icons.chat_bubble_outline_rounded,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                itemCount: _chatList.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppTheme.spacingS),
                itemBuilder: (context, index) {
                  final chat = _chatList[index];
                  return AppTheme.card(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    borderRadius: AppTheme.borderRadiusL,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingM,
                        vertical: AppTheme.spacingS,
                      ),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: Text(
                          (chat['friendEmail'] != null &&
                                  chat['friendEmail'].isNotEmpty)
                              ? chat['friendEmail'][0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 24,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        chat['friendEmail'] ?? chat['friendId'],
                        style: AppTheme.bodyStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        chat['lastMessage'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.captionStyle,
                      ),
                      trailing: chat['lastTime'].isNotEmpty
                          ? Text(
                              chat['lastTime'],
                              style: AppTheme.captionStyle.copyWith(
                                fontSize: 12,
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
      ),
    );
  }
}
