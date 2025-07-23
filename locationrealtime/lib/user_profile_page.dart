import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'login_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isSharing = false;
  bool _loading = false;
  String _status = '';
  int _friendCount = 0;
  int _requestCount = 0;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _checkSharingStatus();
    _loadFriendStats();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkSharingStatus() async {
    if (user == null) return;
    final ref = FirebaseDatabase.instance.ref('locations/${user!.uid}');
    final snap = await ref.get();
    setState(() {
      _isSharing = snap.exists;
    });
  }

  Future<void> _loadFriendStats() async {
    if (user == null) return;
    // Đếm bạn bè
    final friendsSnap = await FirebaseDatabase.instance.ref('users/${user!.uid}/friends').get();
    int friendCount = 0;
    if (friendsSnap.exists && friendsSnap.value is Map) {
      friendCount = (friendsSnap.value as Map).length;
    }
    // Đếm lời mời
    final reqSnap = await FirebaseDatabase.instance.ref('friend_requests/${user!.uid}').get();
    int reqCount = 0;
    if (reqSnap.exists && reqSnap.value is Map) {
      reqCount = (reqSnap.value as Map).length;
    }
    setState(() {
      _friendCount = friendCount;
      _requestCount = reqCount;
    });
  }

  Future<void> _toggleShare(bool value) async {
    if (user == null) return;
    setState(() { _loading = true; _status = ''; });
    final ref = FirebaseDatabase.instance.ref('locations/${user!.uid}');
    if (value) {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
          setState(() { _status = 'Không có quyền truy cập vị trí!'; _loading = false; });
          return;
        }
        final pos = await Geolocator.getCurrentPosition();
        await ref.set({
          'lat': pos.latitude,
          'lng': pos.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        });
        setState(() { _isSharing = true; _status = 'Đang chia sẻ vị trí'; });
        
        // Bắt đầu cập nhật vị trí định kỳ
        _startLocationUpdates();
      } catch (e) {
        setState(() { _status = 'Lỗi: $e'; });
      }
    } else {
      await ref.remove();
      _locationTimer?.cancel();
      setState(() { _isSharing = false; _status = 'Đã tắt chia sẻ vị trí'; });
    }
    setState(() { _loading = false; });
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (user != null && _isSharing && mounted) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
          final ref = FirebaseDatabase.instance.ref('locations/${user!.uid}');
          await ref.set({
            'lat': pos.latitude,
            'lng': pos.longitude,
            'timestamp': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          print('Lỗi cập nhật vị trí: $e');
          // Nếu lỗi quá nhiều lần, có thể tắt chia sẻ
          if (e.toString().contains('timeout') || e.toString().contains('permission')) {
            print('Tự động tắt chia sẻ vị trí do lỗi');
            _toggleShare(false);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Trang cá nhân'), backgroundColor: Colors.blue, elevation: 1),
      body: user == null
          ? const Center(child: Text('Chưa đăng nhập'))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 54,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        user!.email != null && user!.email!.isNotEmpty ? user!.email![0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 44, color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.email, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(user!.email ?? '', style: theme.textTheme.titleMedium),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.people, color: Colors.green),
                              const SizedBox(width: 8),
                              Text('Bạn bè: $_friendCount', style: theme.textTheme.bodyMedium),
                              const SizedBox(width: 24),
                              const Icon(Icons.notifications, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text('Lời mời: $_requestCount', style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Chia sẻ vị trí', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(_isSharing ? 'Bạn đang chia sẻ vị trí cho bạn bè.' : 'Bạn chưa chia sẻ vị trí.',
                                  style: TextStyle(color: _isSharing ? Colors.green : Colors.red)),
                            ],
                          ),
                          Switch(
                            value: _isSharing,
                            onChanged: _loading ? null : _toggleShare,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_loading) const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(),
                  ),
                  if (_status.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_status, style: TextStyle(color: _isSharing ? Colors.green : Colors.red)),
                  ],
                  const SizedBox(height: 32),
                  if (!_isSharing)
                    Card(
                      color: Colors.yellow.shade50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline, color: Colors.orange),
                            SizedBox(width: 12),
                            Expanded(child: Text('Bạn chưa chia sẻ vị trí, hãy bật để bạn bè biết bạn đang ở đâu!')),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginPage()),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 