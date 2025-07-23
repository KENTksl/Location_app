import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'chat_page.dart';

class FriendsListPage extends StatefulWidget {
  const FriendsListPage({Key? key}) : super(key: key);

  @override
  State<FriendsListPage> createState() => _FriendsListPageState();
}

class _FriendsListPageState extends State<FriendsListPage> {
  List<Map<String, String>> _friends = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() { _loading = true; });
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final friendsRef = FirebaseDatabase.instance.ref('users/$userId/friends');
    final event = await friendsRef.once();
    final friends = event.snapshot.value as Map?;
    List<Map<String, String>> result = [];
    if (friends != null) {
      for (final friendId in friends.keys) {
        final userSnap = await FirebaseDatabase.instance.ref('users/$friendId').get();
        final email = userSnap.child('email').value?.toString() ?? friendId;
        result.add({'userId': friendId, 'email': email});
      }
    }
    setState(() { _friends = result; _loading = false; });
  }

  void _selectFriend(String userId, String email) {
    Navigator.pop(context, {'userId': userId, 'email': email});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách bạn bè'), backgroundColor: Colors.blue, elevation: 1),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.group_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Bạn chưa có bạn bè nào.', style: TextStyle(fontSize: 18)),
                      SizedBox(height: 8),
                      Text('Hãy tìm kiếm và kết bạn ngay!', style: TextStyle(color: Colors.blueGrey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _friends.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final friend = _friends[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            (friend['email'] != null && friend['email']!.isNotEmpty)
                                ? friend['email']![0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 24, color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(friend['email'] ?? friend['userId']!, style: theme.textTheme.titleMedium),
                        subtitle: Text('ID: ${friend['userId']}', style: theme.textTheme.bodySmall),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _selectFriend(friend['userId']!, friend['email'] ?? ''),
                              icon: const Icon(Icons.location_pin, color: Colors.white),
                              label: const Text('Xem vị trí'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline, color: Colors.green, size: 28),
                              tooltip: 'Nhắn tin',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatPage(
                                      friendId: friend['userId']!,
                                      friendEmail: friend['email'] ?? '',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
} 