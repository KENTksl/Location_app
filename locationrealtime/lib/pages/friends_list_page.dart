import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'friend_search_page.dart';
import 'user_profile_page.dart';
import 'package:random_avatar/random_avatar.dart';
import 'chat_page.dart';
import 'dart:async'; // Import for StreamSubscription
import 'main_navigation_page.dart'; // Added import for MainNavigationPage

class FriendsListPage extends StatefulWidget {
  const FriendsListPage({super.key});

  @override
  State<FriendsListPage> createState() => _FriendsListPageState();
}

class _FriendsListPageState extends State<FriendsListPage> {
  String? _userAvatarUrl;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  final Map<String, StreamSubscription> _friendAvatarSubscriptions = {};
  String _searchQuery = '';
  String? _userEmail;

  // Location tracking variables
  Position? _currentPosition;
  final Map<String, double> _friendDistances = {};
  final Map<String, StreamSubscription> _friendLocationSubscriptions = {};
  Timer? _distanceUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadFriends();
    _loadFriendRequests();
    _listenToFriendsChanges();
    _getCurrentLocation();
    _startDistanceUpdateTimer();
  }

  @override
  void dispose() {
    // Hủy tất cả subscriptions
    for (var subscription in _friendAvatarSubscriptions.values) {
      subscription.cancel();
    }
    for (var subscription in _friendLocationSubscriptions.values) {
      subscription.cancel();
    }
    _distanceUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email;
      });

      // Load avatar
      final avatarRef = FirebaseDatabase.instance.ref(
        'users/${user.uid}/avatarUrl',
      );
      final avatarSnap = await avatarRef.get();
      if (avatarSnap.exists) {
        setState(() {
          _userAvatarUrl = avatarSnap.value as String?;
        });
      }

      // Lắng nghe thay đổi avatar
      avatarRef.onValue.listen((event) {
        if (event.snapshot.exists && mounted) {
          setState(() {
            _userAvatarUrl = event.snapshot.value as String?;
          });
        }
      });
    }
  }

  Future<void> _loadFriends() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Hủy tất cả subscriptions cũ
    for (var subscription in _friendAvatarSubscriptions.values) {
      subscription.cancel();
    }
    _friendAvatarSubscriptions.clear();

    // Thử load theo cấu trúc cũ trước
    final friendsRef = FirebaseDatabase.instance.ref(
      'users/${user.uid}/friends',
    );
    final friendsSnap = await friendsRef.get();

    if (friendsSnap.exists) {
      final friendsData = friendsSnap.value as Map<dynamic, dynamic>;
      final friendsList = <Map<String, dynamic>>[];

      for (final friendId in friendsData.keys) {
        final friendRef = FirebaseDatabase.instance.ref('users/$friendId');
        final friendSnap = await friendRef.get();

        if (friendSnap.exists) {
          final friendData = friendSnap.value as Map<dynamic, dynamic>;
          friendsList.add({
            'id': friendId,
            'email': friendData['email'] ?? '',
            'avatarUrl': friendData['avatarUrl'],
            'isOnline': false,
          });

          // Lắng nghe thay đổi avatar của bạn bè
          _listenToFriendAvatar(friendId);
        }
      }

      setState(() {
        _friends = friendsList;
        _isLoading = false;
      });

      // Khởi tạo khoảng cách cho tất cả bạn bè
      if (_currentPosition != null) {
        _updateAllFriendDistances();
      }
    } else {
      // Thử load theo cấu trúc mới
      final newFriendsRef = FirebaseDatabase.instance.ref(
        'friends/${user.uid}',
      );
      final newFriendsSnap = await newFriendsRef.get();

      if (newFriendsSnap.exists) {
        final friendsData = newFriendsSnap.value as Map<dynamic, dynamic>;
        final friendsList = <Map<String, dynamic>>[];

        for (final friendId in friendsData.keys) {
          final friendRef = FirebaseDatabase.instance.ref('users/$friendId');
          final friendSnap = await friendRef.get();

          if (friendSnap.exists) {
            final friendData = friendSnap.value as Map<dynamic, dynamic>;
            friendsList.add({
              'id': friendId,
              'email': friendData['email'] ?? '',
              'avatarUrl': friendData['avatarUrl'],
              'isOnline': false,
            });

            // Lắng nghe thay đổi avatar của bạn bè
            _listenToFriendAvatar(friendId);
          }
        }

        setState(() {
          _friends = friendsList;
          _isLoading = false;
        });

        // Khởi tạo khoảng cách cho tất cả bạn bè
        if (_currentPosition != null) {
          _updateAllFriendDistances();
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _listenToFriendAvatar(String friendId) {
    final avatarRef = FirebaseDatabase.instance.ref(
      'users/$friendId/avatarUrl',
    );
    final subscription = avatarRef.onValue.listen((event) {
      if (event.snapshot.exists && mounted) {
        print(
          'Friends: Friend $friendId avatar updated to: ${event.snapshot.value}',
        );
        setState(() {
          // Cập nhật avatar trong danh sách bạn bè
          final friendIndex = _friends.indexWhere(
            (friend) => friend['id'] == friendId,
          );
          if (friendIndex != -1) {
            _friends[friendIndex]['avatarUrl'] =
                event.snapshot.value as String?;
          }
        });
      }
    });

    _friendAvatarSubscriptions[friendId] = subscription;
  }

  Future<void> _loadFriendRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final requestsRef = FirebaseDatabase.instance.ref(
      'friend_requests/${user.uid}',
    );
    final requestsSnap = await requestsRef.get();

    if (requestsSnap.exists) {
      final requestsData = requestsSnap.value as Map<dynamic, dynamic>;
      final requestsList = <Map<String, dynamic>>[];

      for (final requestId in requestsData.keys) {
        final requestData = requestsData[requestId] as Map<dynamic, dynamic>;
        final senderRef = FirebaseDatabase.instance.ref('users/$requestId');
        final senderSnap = await senderRef.get();

        if (senderSnap.exists) {
          final senderData = senderSnap.value as Map<dynamic, dynamic>;
          requestsList.add({
            'id': requestId,
            'email': senderData['email'] ?? '',
            'avatarUrl': senderData['avatarUrl'],
          });
        }
      }

      setState(() {
        _requests = requestsList;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredFriends {
    if (_searchQuery.isEmpty) {
      return _friends;
    }
    return _friends
        .where(
          (friend) => friend['email'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  Widget _buildUserAvatar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserProfilePage()),
        );
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF10b981), width: 2),
        ),
        child: _userAvatarUrl != null && _userAvatarUrl!.isNotEmpty
            ? (_userAvatarUrl!.startsWith('random:')
                  ? RandomAvatar(
                      _userAvatarUrl!.substring(7),
                      height: 40,
                      width: 40,
                    )
                  : _userAvatarUrl!.startsWith('http')
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: _userAvatarUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => _buildDefaultAvatar(),
                        errorWidget: (context, url, error) =>
                            _buildDefaultAvatar(),
                      ),
                    )
                  : ClipOval(
                      child: Image.file(
                        File(_userAvatarUrl!),
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildDefaultAvatar(),
                      ),
                    ))
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10b981).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _userEmail?.isNotEmpty == true ? _userEmail![0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFF10b981),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFriendAvatar(String? avatarUrl, String email) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('random:')) {
        // Hiển thị random avatar với seed từ avatarUrl
        final seed = avatarUrl.substring(7);
        return RandomAvatar(seed, height: 50, width: 50);
      } else if (avatarUrl.startsWith('http')) {
        // Hiển thị network image
        return ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: CachedNetworkImage(
            imageUrl: avatarUrl,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.grey),
            ),
            errorWidget: (context, url, error) =>
                _buildDefaultFriendAvatar(email),
          ),
        );
      } else {
        // Hiển thị local file
        return ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Image.file(
            File(avatarUrl),
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildDefaultFriendAvatar(email),
          ),
        );
      }
    }
    return _buildDefaultFriendAvatar(email);
  }

  Widget _buildDefaultFriendAvatar(String email) {
    return Container(
      width: 50,
      height: 50,
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _listenToFriendsChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final friendsRef = FirebaseDatabase.instance.ref(
      'users/${user.uid}/friends',
    );

    friendsRef.onValue.listen((event) {
      if (mounted) {
        // Cập nhật danh sách bạn bè khi có thay đổi
        _loadFriends();
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      // Cập nhật khoảng cách cho tất cả bạn bè
      _updateAllFriendDistances();
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  void _startDistanceUpdateTimer() {
    _distanceUpdateTimer?.cancel();
    _distanceUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentPosition != null) {
        _updateAllFriendDistances();
      }
    });
  }

  void _updateAllFriendDistances() {
    if (_currentPosition == null) return;

    for (final friend in _friends) {
      final friendId = friend['id'] as String;
      _updateFriendDistance(friendId);
    }
  }

  void _updateFriendDistance(String friendId) {
    if (_currentPosition == null) return;

    final locationRef = FirebaseDatabase.instance.ref(
      'users/$friendId/location',
    );

    // Hủy subscription cũ nếu có
    _friendLocationSubscriptions[friendId]?.cancel();

    // Lắng nghe vị trí của bạn bè
    final subscription = locationRef.onValue.listen((event) {
      if (event.snapshot.exists && mounted) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;
        final isOnline = data['isOnline'] as bool? ?? false;
        final isSharing = data['isSharingLocation'] as bool? ?? false;

        if (lat != null && lng != null && isOnline && isSharing) {
          // Tính khoảng cách
          final distance =
              Geolocator.distanceBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                lat,
                lng,
              ) /
              1000; // Chuyển đổi sang km

          setState(() {
            _friendDistances[friendId] = distance;
          });
        } else {
          setState(() {
            _friendDistances.remove(friendId);
          });
        }
      } else {
        setState(() {
          _friendDistances.remove(friendId);
        });
      }
    });

    _friendLocationSubscriptions[friendId] = subscription;
  }

  String _formatDistance(double? distance) {
    if (distance == null) return 'N/A';
    if (distance < 1) {
      return '${(distance * 1000).toStringAsFixed(0)}m';
    } else {
      return '${distance.toStringAsFixed(1)}km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header với avatar user và search
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Top row với avatar và title
                    Row(
                      children: [
                        _buildUserAvatar(),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Bạn bè',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1e293b),
                            ),
                          ),
                        ),
                        if (_requests.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFef4444).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.notifications_rounded,
                                  color: Color(0xFFef4444),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_requests.length}',
                                  style: const TextStyle(
                                    color: Color(0xFFef4444),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm bạn bè...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.person_add_rounded),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const FriendSearchPage(),
                                ),
                              );
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredFriends.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'Chưa có bạn bè nào'
                                    : 'Không tìm thấy bạn bè',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const FriendSearchPage(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Thêm bạn bè',
                                    style: TextStyle(color: Color(0xFF667eea)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredFriends.length,
                          itemBuilder: (context, index) {
                            final friend = _filteredFriends[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  _buildFriendAvatar(
                                    friend['avatarUrl'],
                                    friend['email'],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          friend['email'].split('@')[0],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1e293b),
                                          ),
                                        ),
                                        Text(
                                          friend['email'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on_rounded,
                                              size: 14,
                                              color:
                                                  _friendDistances[friend['id']] !=
                                                      null
                                                  ? const Color(0xFF10b981)
                                                  : Colors.grey.shade400,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _friendDistances[friend['id']] !=
                                                      null
                                                  ? _formatDistance(
                                                      _friendDistances[friend['id']],
                                                    )
                                                  : 'Không chia sẻ vị trí',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    _friendDistances[friend['id']] !=
                                                        null
                                                    ? const Color(0xFF10b981)
                                                    : Colors.grey.shade500,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Action buttons
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Chat button
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFf59e0b,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.chat_bubble_rounded,
                                            color: Color(0xFFf59e0b),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ChatPage(
                                                  friendId: friend['id'],
                                                  friendEmail: friend['email'],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Location button
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF667eea,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.location_on_rounded,
                                            color: Color(0xFF667eea),
                                          ),
                                          onPressed: () {
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    MainNavigationPage(
                                                      focusFriendId:
                                                          friend['id'],
                                                      focusFriendEmail:
                                                          friend['email'],
                                                      selectedTab: 0,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
