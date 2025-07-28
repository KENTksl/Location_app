import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FriendRequestsPage extends StatefulWidget {
  const FriendRequestsPage({Key? key}) : super(key: key);

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  List<Map<String, String>> _requests = [];
  bool _loading = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() { _loading = true; _status = ''; });
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final reqRef = FirebaseDatabase.instance.ref('friend_requests/$userId');
    final event = await reqRef.once();
    final reqs = event.snapshot.value as Map?;
    List<Map<String, String>> result = [];
    if (reqs != null) {
      for (final fromUserId in reqs.keys) {
        // Lấy email của người gửi lời mời
        final userSnap = await FirebaseDatabase.instance.ref('users/$fromUserId').get();
        final email = userSnap.child('email').value?.toString() ?? fromUserId;
        result.add({'userId': fromUserId, 'email': email});
      }
    }
    setState(() { _requests = result; _loading = false; });
  }

  Future<void> _acceptRequest(String fromUserId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    try {
      // Thêm vào danh sách bạn bè của cả hai
      await FirebaseDatabase.instance.ref('users/$userId/friends/$fromUserId').set(true);
      await FirebaseDatabase.instance.ref('users/$fromUserId/friends/$userId').set(true);
      
      // Xóa lời mời
      await FirebaseDatabase.instance.ref('friend_requests/$userId/$fromUserId').remove();
      
      setState(() { 
        _status = 'Đã xác nhận kết bạn thành công!'; 
      });
      
      // Đợi một chút để Firebase cập nhật
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Thông báo cho trang danh sách bạn bè cập nhật
      if (mounted) {
        Navigator.pop(context, true); // Trả về true để báo hiệu cần refresh
      }
      
    } catch (e) {
      setState(() { 
        _status = 'Lỗi khi xác nhận kết bạn: $e'; 
      });
    }
  }

  Future<void> _declineRequest(String fromUserId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    await FirebaseDatabase.instance.ref('friend_requests/$userId/$fromUserId').remove();
    setState(() { _status = 'Đã từ chối lời mời của $fromUserId'; });
    _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Lời mời kết bạn'), backgroundColor: Colors.blue, elevation: 1),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.mark_email_unread, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Không có lời mời kết bạn nào.', style: TextStyle(fontSize: 18)),
                      SizedBox(height: 8),
                      Text('Hãy chủ động kết bạn với mọi người!', style: TextStyle(color: Colors.blueGrey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final req = _requests[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.orange.shade100,
                          child: Text(
                            (req['email'] != null && req['email']!.isNotEmpty)
                                ? req['email']![0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 24, color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(req['email'] ?? req['userId']!, style: theme.textTheme.titleMedium),
                        subtitle: Text('ID: ${req['userId']}', style: theme.textTheme.bodySmall),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _acceptRequest(req['userId']!),
                              icon: const Icon(Icons.check, color: Colors.white),
                              label: const Text('Xác nhận'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _declineRequest(req['userId']!),
                              icon: const Icon(Icons.close, color: Colors.white),
                              label: const Text('Từ chối'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: _status.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(_status, style: const TextStyle(color: Colors.blue)),
            )
          : null,
    );
  }
} 