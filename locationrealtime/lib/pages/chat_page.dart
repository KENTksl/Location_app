import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:random_avatar/random_avatar.dart';
import '../theme.dart';
import 'call_page.dart';
import 'dart:io';
import 'dart:async'; // Added for StreamSubscription
import '../services/unread_message_service.dart';

class ChatPage extends StatefulWidget {
  final String friendId;
  final String friendEmail;
  const ChatPage({
    super.key,
    required this.friendId,
    required this.friendEmail,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map> _messages = [];
  bool _loading = true;
  late String _chatId;
  String? _myEmail;
  String? _myAvatarUrl;
  String? _friendAvatarUrl;
  StreamSubscription? _myAvatarSubscription;
  StreamSubscription? _friendAvatarSubscription;
  final UnreadMessageService _unreadMessageService = UnreadMessageService();

  @override
  void initState() {
    super.initState();
    _chatId = _getChatId(
      FirebaseAuth.instance.currentUser!.uid,
      widget.friendId,
    );
    _myEmail = FirebaseAuth.instance.currentUser?.email;
    _loadAvatarUrls();
    _listenMessages();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _controller.dispose();
    _myAvatarSubscription?.cancel();
    _friendAvatarSubscription?.cancel();
    super.dispose();
  }

  String _getChatId(String uid1, String uid2) {
    return (uid1.compareTo(uid2) < 0) ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  void _listenMessages() {
    final ref = FirebaseDatabase.instance.ref('chats/$_chatId/messages');
    ref.onValue.listen((event) {
      final data = event.snapshot.value as List?;
      if (data != null) {
        final msgs = data.whereType<Map>().toList();
        setState(() {
          _messages = msgs;
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      } else {
        setState(() {
          _messages = [];
          _loading = false;
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = FirebaseDatabase.instance.ref('chats/$_chatId/messages');
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
    });
    await ref.set(msgs);
    _controller.clear();
  }

  Future<void> _loadAvatarUrls() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Load my avatar
      final myAvatarRef = FirebaseDatabase.instance.ref(
        'users/${user.uid}/avatarUrl',
      );
      final myAvatarSnap = await myAvatarRef.get();
      if (myAvatarSnap.exists) {
        setState(() {
          _myAvatarUrl = myAvatarSnap.value as String?;
        });
      }

      // Lắng nghe thay đổi avatar của tôi
      _myAvatarSubscription = myAvatarRef.onValue.listen((event) {
        if (event.snapshot.exists && mounted) {
          setState(() {
            _myAvatarUrl = event.snapshot.value as String?;
          });
          // Force rebuild để cập nhật avatar ngay lập tức
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});
            }
          });
        }
      });

      // Load friend avatar
      final friendAvatarRef = FirebaseDatabase.instance.ref(
        'users/${widget.friendId}/avatarUrl',
      );
      final friendAvatarSnap = await friendAvatarRef.get();
      if (friendAvatarSnap.exists) {
        setState(() {
          _friendAvatarUrl = friendAvatarSnap.value as String?;
        });
      }

      // Lắng nghe thay đổi avatar của bạn bè
      _friendAvatarSubscription = friendAvatarRef.onValue.listen((event) {
        if (event.snapshot.exists && mounted) {
          setState(() {
            _friendAvatarUrl = event.snapshot.value as String?;
          });
          // Force rebuild để cập nhật avatar ngay lập tức
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});
            }
          });
        }
      });
    }
  }

  Widget _buildMessage(Map msg, bool isMe) {
    final time = msg['timestamp'] != null
        ? DateFormat(
            'HH:mm',
          ).format(DateTime.fromMillisecondsSinceEpoch(msg['timestamp']))
        : '';

    final avatarUrl = isMe ? _myAvatarUrl : _friendAvatarUrl;
    final email = isMe ? (_myEmail ?? '') : widget.friendEmail;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildAvatarWidget(avatarUrl, email),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingS,
                    horizontal: AppTheme.spacingM,
                  ),
                  decoration: BoxDecoration(
                    gradient: isMe ? AppTheme.primaryGradient : null,
                    color: isMe ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppTheme.borderRadiusM),
                      topRight: const Radius.circular(AppTheme.borderRadiusM),
                      bottomLeft: Radius.circular(
                        isMe ? AppTheme.borderRadiusM : AppTheme.borderRadiusS,
                      ),
                      bottomRight: Radius.circular(
                        isMe ? AppTheme.borderRadiusS : AppTheme.borderRadiusM,
                      ),
                    ),
                    boxShadow: isMe
                        ? AppTheme.buttonShadow
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Text(
                    msg['text'] ?? '',
                    style: TextStyle(
                      color: isMe ? Colors.white : AppTheme.textPrimaryColor,
                      fontSize: 16,
                      fontWeight: isMe ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      time,
                      style: AppTheme.captionStyle.copyWith(
                        fontSize: 10,
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _buildAvatarWidget(avatarUrl, email),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarWidget(
    String? avatarUrl,
    String email, {
    double radius = 16,
  }) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('random:')) {
        // Hiển thị random avatar với seed từ avatarUrl
        final seed = avatarUrl.substring(7);
        return RandomAvatar(seed, height: radius * 2, width: radius * 2);
      } else if (avatarUrl.startsWith('http')) {
        // Hiển thị network image
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: CachedNetworkImage(
            imageUrl: avatarUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildDefaultAvatar(email, radius),
            errorWidget: (context, url, error) =>
                _buildDefaultAvatar(email, radius),
          ),
        );
      } else {
        // Hiển thị local file
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.file(
            File(avatarUrl),
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildDefaultAvatar(email, radius),
          ),
        );
      }
    }
    return _buildDefaultAvatar(email, radius);
  }

  Widget _buildDefaultAvatar(String email, double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        shape: BoxShape.circle,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Center(
        child: Text(
          email.split('@')[0][0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppTheme.appBar(
        title: widget.friendEmail,
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallPage(
                    friendId: widget.friendId,
                    friendEmail: widget.friendEmail,
                  ),
                ),
              );
            },
          ),
          const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? AppTheme.loadingWidget(message: 'Đang tải tin nhắn...')
                  : _messages.isEmpty
                  ? AppTheme.emptyStateWidget(
                      message: 'Chưa có tin nhắn nào.\nHãy bắt đầu trò chuyện!',
                      icon: Icons.chat_bubble_outline_rounded,
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg['from'] == user?.uid;
                        return _buildMessage(msg, isMe);
                      },
                    ),
            ),
            // Input area
            Container(
              margin: const EdgeInsets.all(AppTheme.spacingM),
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadiusM,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadiusM,
                          ),
                          borderSide: BorderSide(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadiusM,
                          ),
                          borderSide: BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingS,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadiusM,
                      ),
                      boxShadow: AppTheme.buttonShadow,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusM,
                        ),
                        onTap: _sendMessage,
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Đánh dấu tất cả tin nhắn là đã đọc
  void _markMessagesAsRead() {
    _unreadMessageService.markAllAsRead(widget.friendId);
  }
}
