import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'notification_service.dart';

class FriendSearchPage extends StatefulWidget {
  const FriendSearchPage({Key? key}) : super(key: key);

  @override
  State<FriendSearchPage> createState() => _FriendSearchPageState();
}

class _FriendSearchPageState extends State<FriendSearchPage> {
  final TextEditingController _emailController = TextEditingController();
  String? _foundUserId;
  String? _foundUserEmail;
  String _status = '';
  bool _loading = false;

  Future<void> _searchUser() async {
    setState(() { _loading = true; _status = ''; _foundUserId = null; _foundUserEmail = null; });
    final usersRef = FirebaseDatabase.instance.ref('users');
    final event = await usersRef.once();
    final users = event.snapshot.value as Map?;
    final searchEmail = _emailController.text.trim();
    if (users != null) {
      users.forEach((userId, userData) {
        if (userData['email'] == searchEmail) {
          _foundUserId = userId;
          _foundUserEmail = userData['email'];
        }
      });
    }
    if (_foundUserId == null) {
      setState(() { _status = 'Không tìm thấy người dùng.'; _loading = false; });
    } else if (_foundUserId == FirebaseAuth.instance.currentUser?.uid) {
      setState(() { _status = 'Đây là bạn!'; _loading = false; });
    } else {
      setState(() { _status = ''; _loading = false; });
    }
  }

  Future<void> _sendFriendRequest() async {
    final fromUserId = FirebaseAuth.instance.currentUser?.uid;
    final toUserId = _foundUserId;
    if (fromUserId == null || toUserId == null) return;
    setState(() { _loading = true; });
    await FirebaseDatabase.instance.ref('friend_requests/$toUserId/$fromUserId').set(true);
    
    // Gửi thông báo cho người nhận
    await NotificationService.sendFriendRequestNotification(
      toUserId,
      _foundUserEmail ?? '',
    );
    
    setState(() { _status = 'Đã gửi lời mời kết bạn!'; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm bạn bè'), backgroundColor: Colors.blue, elevation: 1),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Nhập email bạn bè',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                prefixIcon: const Icon(Icons.email),
                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              ),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _searchUser,
                child: _loading ? const CircularProgressIndicator() : const Text('Tìm kiếm', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_foundUserId != null && _foundUserId != FirebaseAuth.instance.currentUser?.uid)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      (_foundUserEmail != null && _foundUserEmail!.isNotEmpty)
                          ? _foundUserEmail![0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 24, color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(_foundUserEmail ?? '', style: theme.textTheme.titleMedium),
                  subtitle: Text('ID: $_foundUserId', style: theme.textTheme.bodySmall),
                  trailing: ElevatedButton.icon(
                    onPressed: _loading ? null : _sendFriendRequest,
                    icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                    label: const Text('Kết bạn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_status, style: const TextStyle(color: Colors.blue, fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }
} 