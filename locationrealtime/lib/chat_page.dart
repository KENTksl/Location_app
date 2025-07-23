import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';

class ChatPage extends StatefulWidget {
  final String friendId;
  final String friendEmail;
  const ChatPage({Key? key, required this.friendId, required this.friendEmail}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _chatId = _getChatId(FirebaseAuth.instance.currentUser!.uid, widget.friendId);
    _myEmail = FirebaseAuth.instance.currentUser?.email;
    _listenMessages();
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
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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
    
    // Gửi thông báo cho bạn bè
    await NotificationService.sendMessageNotification(
      widget.friendId,
      _myEmail ?? '',
      text,
    );
    
    _controller.clear();
  }

  Widget _buildMessage(Map msg, bool isMe) {
    final avaLetter = isMe
        ? (_myEmail != null && _myEmail!.isNotEmpty ? _myEmail![0].toUpperCase() : '?')
        : (widget.friendEmail.isNotEmpty ? widget.friendEmail[0].toUpperCase() : '?');
    final time = msg['timestamp'] != null
        ? DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(msg['timestamp']))
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue.shade100,
                child: Text(avaLetter, style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
                  child: Text(time, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ),
              ],
            ),
          ),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.green.shade100,
                child: Text(avaLetter, style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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