import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:random_avatar/random_avatar.dart';
import 'dart:io';
import 'dart:async'; // Added for StreamSubscription

class ChatPage extends StatefulWidget {
  final String friendId;
  final String friendEmail;
  const ChatPage({Key? key, required this.friendId, required this.friendEmail})
    : super(key: key);

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

    // // Gửi thông báo cho bạn bè
    // await NotificationService.sendMessageNotification(
    //   widget.friendId,
    //   _myEmail ?? '',
    //   text,
    // );

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
        print('Chat: Initial my avatar loaded: ${myAvatarSnap.value}');
        setState(() {
          _myAvatarUrl = myAvatarSnap.value as String?;
        });
      } else {
        print('Chat: No initial my avatar found');
      }

      // Lắng nghe thay đổi avatar của tôi
      _myAvatarSubscription = myAvatarRef.onValue.listen((event) {
        if (event.snapshot.exists && mounted) {
          print('Chat: My avatar updated to: ${event.snapshot.value}');
          setState(() {
            _myAvatarUrl = event.snapshot.value as String?;
          });
          // Force rebuild để cập nhật avatar ngay lập tức
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});
            }
          });
          // Force refresh messages
          _refreshMessages();
        }
      });

      // Load friend avatar
      final friendAvatarRef = FirebaseDatabase.instance.ref(
        'users/${widget.friendId}/avatarUrl',
      );
      final friendAvatarSnap = await friendAvatarRef.get();
      if (friendAvatarSnap.exists) {
        print('Chat: Initial friend avatar loaded: ${friendAvatarSnap.value}');
        setState(() {
          _friendAvatarUrl = friendAvatarSnap.value as String?;
        });
      } else {
        print('Chat: No initial friend avatar found');
      }

      // Lắng nghe thay đổi avatar của bạn bè
      _friendAvatarSubscription = friendAvatarRef.onValue.listen((event) {
        if (event.snapshot.exists && mounted) {
          print('Chat: Friend avatar updated to: ${event.snapshot.value}');
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

  void _refreshMessages() {
    // Force rebuild toàn bộ chat
    setState(() {});
  }

  Widget _buildMessage(Map msg, bool isMe) {
    final time = msg['timestamp'] != null
        ? DateFormat(
            'HH:mm',
          ).format(DateTime.fromMillisecondsSinceEpoch(msg['timestamp']))
        : '';

    final avatarUrl = isMe ? _myAvatarUrl : _friendAvatarUrl;
    final email = isMe ? (_myEmail ?? '') : widget.friendEmail;

    // Debug: In ra thông tin avatar
    // if (isMe) {
    //   print('Chat: Building message for me with avatar: $avatarUrl');
    // } else {
    //   print('Chat: Building message for friend with avatar: $avatarUrl');
    // }

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
                    vertical: 10,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blue : Colors.grey.shade200,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    msg['text'] ?? '',
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Text(
                    time,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
        gradient: LinearGradient(
          colors: [const Color(0xFF10b981), const Color(0xFF059669)],
        ),
        shape: BoxShape.circle,
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
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(widget.friendEmail, style: const TextStyle(fontSize: 18)),
          ],
        ),
        backgroundColor: Colors.blue,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['from'] == user?.uid;
                      return _buildMessage(msg, isMe);
                    },
                  ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
