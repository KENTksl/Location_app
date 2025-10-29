import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/background_location_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:random_avatar/random_avatar.dart';
import 'dart:io';
import 'dart:async';
import 'login_page.dart';
import 'friend_requests_page.dart';
import 'location_history_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with TickerProviderStateMixin {
  User? user;
  String? _avatarUrl;
  bool _isSharing = false;
  bool _loading = false;
  String _status = '';
  int _friendCount = 0;
  int _requestCount = 0;
  bool _showAvatarSelector = false;
  bool _isUpdatingAvatar = false;
  String? _userEmail;
  List<String> _availableAvatars = [];
  Timer? _backgroundTimer;
  Timer? _locationTimer;
  StreamSubscription<Position>? _locationSubscription;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    _checkLocationSharingStatus();
    _loadAvatar();
    _loadStats();
    _generateAvailableAvatars();
    _listenToFriendRequests();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _backgroundTimer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkLocationSharingStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Kiểm tra cài đặt "luôn chia sẻ"
      final alwaysShareRef = FirebaseDatabase.instance.ref(
        'users/${user.uid}/alwaysShareLocation',
      );
      final alwaysShareSnap = await alwaysShareRef.get();

      if (alwaysShareSnap.exists && alwaysShareSnap.value == true) {
        // Kiểm tra quyền vị trí
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          // Tự động bật chia sẻ vị trí
          setState(() {
            _isSharing = true;
            _status = 'Đã khôi phục chia sẻ vị trí';
          });

          // Cập nhật trạng thái trong Firebase
          await FirebaseDatabase.instance
              .ref('users/${user.uid}/isSharingLocation')
              .set(true);

          // Cập nhật vị trí ngay lập tức
          await _updateLocationImmediately();

          // Bắt đầu background service
          _startBackgroundLocationSharing();
        } else {
          // Yêu cầu quyền vị trí
          final granted = await Geolocator.requestPermission();
          if (granted == LocationPermission.whileInUse ||
              granted == LocationPermission.always) {
            setState(() {
              _isSharing = true;
              _status = 'Đã khôi phục chia sẻ vị trí';
            });

            await FirebaseDatabase.instance
                .ref('users/${user.uid}/isSharingLocation')
                .set(true);

            // Cập nhật vị trí ngay lập tức
            await _updateLocationImmediately();

            // Bắt đầu background service
            _startBackgroundLocationSharing();
          } else {
            setState(() {
              _status = 'Cần quyền vị trí để khôi phục chia sẻ';
            });
          }
        }
      }
    } catch (e) {
      print('Error checking location sharing status: $e');
    }
  }

  void _generateAvailableAvatars() {
    // Tạo danh sách avatar có sẵn
    _availableAvatars = [
      'user1',
      'user2',
      'user3',
      'user4',
      'user5',
      'user6',
      'user7',
      'user8',
      'user9',
      'user10',
      'user11',
      'user12',
    ];
  }

  Future<void> _loadAvatar() async {
    if (user != null) {
      final avatarRef = FirebaseDatabase.instance.ref(
        'users/${user!.uid}/avatarUrl',
      );
      final avatarSnap = await avatarRef.get();
      if (avatarSnap.exists) {
        setState(() {
          _avatarUrl = avatarSnap.value as String?;
        });
      }
    }
  }

  Future<void> _loadStats() async {
    if (user == null) return;

    // Load friend count
    final friendsRef = FirebaseDatabase.instance.ref(
      'users/${user!.uid}/friends',
    );
    final friendsSnap = await friendsRef.get();
    if (friendsSnap.exists) {
      final friends = friendsSnap.value as Map?;
      setState(() {
        _friendCount = friends?.length ?? 0;
      });
    }

    // Load request count
    final requestsRef = FirebaseDatabase.instance.ref(
      'friend_requests/${user!.uid}',
    );
    final requestsSnap = await requestsRef.get();
    if (requestsSnap.exists) {
      final requests = requestsSnap.value as Map?;
      setState(() {
        _requestCount = requests?.length ?? 0;
      });
    }
  }

  Future<void> _showAvatarUpdateLoading() async {
    setState(() {
      _isUpdatingAvatar = true;
    });

    // Hiển thị loading trong 2 giây
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isUpdatingAvatar = false;
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _avatarUrl = image.path;
      });

      // Hiển thị loading
      await _showAvatarUpdateLoading();

      // Save to Firebase
      if (user != null) {
        await FirebaseDatabase.instance
            .ref('users/${user!.uid}/avatarUrl')
            .set(image.path);

        // Force refresh để đảm bảo cập nhật
        await Future.delayed(const Duration(milliseconds: 100));
        await FirebaseDatabase.instance
            .ref('users/${user!.uid}/avatarUrl')
            .set(image.path);
      }
    }
  }

  Future<void> _selectRandomAvatar(String seed) async {
    setState(() {
      _avatarUrl = 'random:$seed';
      _showAvatarSelector = false;
    });

    // Hiển thị loading
    await _showAvatarUpdateLoading();

    // Save to Firebase
    if (user != null) {
      await FirebaseDatabase.instance
          .ref('users/${user!.uid}/avatarUrl')
          .set('random:$seed');

      // Force refresh để đảm bảo cập nhật
      await Future.delayed(const Duration(milliseconds: 100));
      await FirebaseDatabase.instance
          .ref('users/${user!.uid}/avatarUrl')
          .set('random:$seed');
    }
  }

  void _toggleShare(bool value) async {
    setState(() {
      _loading = true;
      _status = '';
    });

    try {
      if (value) {
        // Bắt đầu chia sẻ vị trí
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          final granted = await Geolocator.requestPermission();
          if (granted != LocationPermission.whileInUse &&
              granted != LocationPermission.always) {
            setState(() {
              _status = 'Cần quyền truy cập vị trí để chia sẻ!';
              _loading = false;
            });
            return;
          }
        }

        setState(() {
          _isSharing = true;
          _status = 'Đang chia sẻ vị trí...';
        });

        // Lưu trạng thái chia sẻ vào Firebase
        if (user != null) {
          await FirebaseDatabase.instance
              .ref('users/${user!.uid}/isSharingLocation')
              .set(true);

          // Lưu thời gian bắt đầu chia sẻ
          await FirebaseDatabase.instance
              .ref('users/${user!.uid}/locationSharingStartedAt')
              .set(DateTime.now().millisecondsSinceEpoch);

          // Lưu cài đặt "luôn chia sẻ"
          await FirebaseDatabase.instance
              .ref('users/${user!.uid}/alwaysShareLocation')
              .set(true);

          // Cập nhật vị trí ngay lập tức
          await _updateLocationImmediately();
        }

        // Bắt đầu background service
        _startBackgroundLocationSharing();

        setState(() {
          _status = 'Chia sẻ vị trí thành công!';
          _loading = false;
        });
      } else {
        // Dừng chia sẻ vị trí
        setState(() {
          _isSharing = false;
          _status = 'Đã dừng chia sẻ vị trí';
        });

        // Dừng background service
        _stopBackgroundLocationSharing();

        // Xóa trạng thái chia sẻ khỏi Firebase
        if (user != null) {
          // Cập nhật trạng thái isSharingLocation thành false thay vì xóa
          await FirebaseDatabase.instance
              .ref('users/${user!.uid}/location/isSharingLocation')
              .set(false);

          // Đảm bảo cập nhật trường isSharingLocation riêng
          await FirebaseDatabase.instance
              .ref('users/${user!.uid}/isSharingLocation')
              .set(false);

          await FirebaseDatabase.instance
              .ref('users/${user!.uid}/locationSharingStartedAt')
              .remove();

          // Tắt cài đặt "luôn chia sẻ"
          await FirebaseDatabase.instance
              .ref('users/${user!.uid}/alwaysShareLocation')
              .set(false);
        }

        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Lỗi: $e';
        _loading = false;
      });
    }
  }

  Future<void> _updateLocationImmediately() async {
    if (user == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      await FirebaseDatabase.instance.ref('users/${user!.uid}/location').set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'isOnline': true,
        'isSharingLocation': true,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'altitude': position.altitude,
      });

      print(
        'Location updated immediately: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      print('Error updating location immediately: $e');
    }
  }

  void _startBackgroundLocationSharing() async {
    if (_isSharing && user != null) {
      // Sử dụng BackgroundLocationService cho background tracking
      final success = await BackgroundLocationService.instance.startBackgroundLocationTracking();
      
      if (success) {
        print('Background location service started successfully');
        
        // Cập nhật trạng thái ngay lập tức
        await _updateLocationImmediately();
      } else {
        print('Failed to start background location service, falling back to foreground tracking');
        // Fallback to old method if background service fails
        _startForegroundLocationSharing();
      }
    }
  }
  
  void _startForegroundLocationSharing() {
    _backgroundTimer?.cancel();
    _locationSubscription?.cancel();

    // Bắt đầu theo dõi vị trí real-time (foreground only)
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Cập nhật khi di chuyển 5 mét
      timeLimit: Duration(seconds: 30),
    );

    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) async {
            if (_isSharing && user != null) {
              try {
                await FirebaseDatabase.instance
                    .ref('users/${user!.uid}/location')
                    .set({
                      'latitude': position.latitude,
                      'longitude': position.longitude,
                      'isOnline': true,
                      'isSharingLocation': true,
                      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
                      'accuracy': position.accuracy,
                      'speed': position.speed,
                      'altitude': position.altitude,
                    });

                print(
                  'Location updated: ${position.latitude}, ${position.longitude}',
                );
              } catch (e) {
                print('Error updating location in real-time: $e');
              }
            }
          },
          onError: (error) {
            print('Location stream error: $error');
            // Fallback to periodic updates if stream fails
            _startPeriodicLocationUpdates();
          },
        );

    // Backup timer để đảm bảo vị trí được cập nhật ngay cả khi stream bị lỗi
    _backgroundTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      if (_isSharing && user != null) {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );

          await FirebaseDatabase.instance
              .ref('users/${user!.uid}/location')
              .set({
                'latitude': position.latitude,
                'longitude': position.longitude,
                'isOnline': true,
                'isSharingLocation': true,
                'lastUpdated': DateTime.now().millisecondsSinceEpoch,
                'accuracy': position.accuracy,
                'speed': position.speed,
                'altitude': position.altitude,
              });
        } catch (e) {
          print('Error updating location in background: $e');
        }
      }
    });
  }

  void _startPeriodicLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_isSharing && user != null) {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );

          await FirebaseDatabase.instance
              .ref('users/${user!.uid}/location')
              .set({
                'latitude': position.latitude,
                'longitude': position.longitude,
                'isOnline': true,
                'isSharingLocation': true,
                'lastUpdated': DateTime.now().millisecondsSinceEpoch,
                'accuracy': position.accuracy,
                'speed': position.speed,
                'altitude': position.altitude,
              });
        } catch (e) {
          print('Error updating location periodically: $e');
        }
      }
    });
  }

  void _stopBackgroundLocationSharing() async {
    // Dừng BackgroundLocationService
    await BackgroundLocationService.instance.stopBackgroundLocationTracking();
    
    // Dừng các timer và subscription cũ
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationTimer?.cancel();
    _locationTimer = null;
    
    print('Background location service stopped');
  }

  Widget _buildAvatar() {
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      if (_avatarUrl!.startsWith('random:')) {
        // Random avatar
        final seed = _avatarUrl!.substring(7);
        return GestureDetector(
          onTap: () {
            setState(() {
              _showAvatarSelector = !_showAvatarSelector;
            });
          },
          child: Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF667eea), width: 3),
            ),
            child: ClipOval(child: RandomAvatar(seed, height: 108, width: 108)),
          ),
        );
      } else if (_avatarUrl!.startsWith('http')) {
        // Network image
        return GestureDetector(
          onTap: () {
            setState(() {
              _showAvatarSelector = !_showAvatarSelector;
            });
          },
          child: Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF667eea), width: 3),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: _avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildDefaultAvatar(),
                errorWidget: (context, url, error) => _buildDefaultAvatar(),
              ),
            ),
          ),
        );
      } else {
        // Local file
        return GestureDetector(
          onTap: () {
            setState(() {
              _showAvatarSelector = !_showAvatarSelector;
            });
          },
          child: Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF667eea), width: 3),
            ),
            child: ClipOval(
              child: Image.file(
                File(_avatarUrl!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildDefaultAvatar(),
              ),
            ),
          ),
        );
      }
    } else {
      return GestureDetector(
        onTap: () {
          setState(() {
            _showAvatarSelector = !_showAvatarSelector;
          });
        },
        child: Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF667eea), width: 3),
          ),
          child: _buildDefaultAvatar(),
        ),
      );
    }
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF667eea), const Color(0xFF764ba2)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          user?.email != null && user!.email!.isNotEmpty
              ? user!.email![0].toUpperCase()
              : '?',
          style: const TextStyle(
            fontSize: 44,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSelector() {
    if (!_showAvatarSelector) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Chọn Avatar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1e293b),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _availableAvatars.length + 1, // +1 cho option chọn ảnh
            itemBuilder: (context, index) {
              if (index == 0) {
                // Option chọn ảnh từ gallery
                return GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF667eea),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_a_photo,
                      color: Color(0xFF667eea),
                      size: 24,
                    ),
                  ),
                );
              }

              final avatarSeed = _availableAvatars[index - 1];
              final isSelected = _avatarUrl == 'random:$avatarSeed';

              return GestureDetector(
                onTap: () => _selectRandomAvatar(avatarSeed),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF667eea)
                          : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: RandomAvatar(avatarSeed, height: 60, width: 60),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _showAvatarSelector = false;
              });
            },
            child: const Text(
              'Đóng',
              style: TextStyle(color: Color(0xFF667eea)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Text(
                          'Cá nhân',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Avatar Section
                    Center(
                      child: Stack(
                        children: [
                          _buildAvatar(),
                          if (_isUpdatingAvatar)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // User Info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.email ?? 'User',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1e293b),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'ID: ${user?.uid ?? 'N/A'}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748b),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Location Sharing Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isSharing
                                    ? Icons.location_on
                                    : Icons.location_off,
                                color: _isSharing ? Colors.green : Colors.grey,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Chia sẻ vị trí',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1e293b),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _status ?? 'Bật để chia sẻ vị trí với bạn bè',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748b),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Switch(
                                value: _isSharing,
                                onChanged: _loading ? null : _toggleShare,
                                activeColor: const Color(0xFF667eea),
                              ),
                              const Spacer(),
                              if (_loading)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                            ],
                          ),
                          if (_isSharing)
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10b981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(
                                    0xFF10b981,
                                  ).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.lightbulb_outline,
                                    color: Color(0xFF10b981),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '💡 Khi bật, vị trí sẽ được chia sẻ ngay cả khi tắt app',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF10b981),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Friend Requests Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.people,
                                color: Color(0xFF667eea),
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Lời mời kết bạn',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1e293b),
                                ),
                              ),
                              const Spacer(),
                              if (_requestCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF667eea),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$_requestCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _requestCount > 0
                                ? 'Bạn có $_requestCount lời mời kết bạn mới'
                                : 'Không có lời mời kết bạn nào',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748b),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const FriendRequestsPage(),
                                ),
                              );

                              // Nếu có kết quả từ trang lời mời kết bạn, cập nhật stats
                              if (result == true) {
                                _loadStats();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667eea),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              _requestCount > 0
                                  ? 'Xem lời mời'
                                  : 'Quản lý lời mời',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Location History Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LocationHistoryPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history_rounded),
                        label: const Text('Lịch sử di chuyển'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Đăng xuất',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showAvatarSelector)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(child: _buildAvatarSelector()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748b)),
        ),
      ],
    );
  }

  Future<void> _listenToFriendRequests() async {
    if (user == null) return;

    final requestsRef = FirebaseDatabase.instance.ref(
      'friend_requests/${user!.uid}',
    );

    requestsRef.onValue.listen((event) {
      if (mounted) {
        if (event.snapshot.exists) {
          final requests = event.snapshot.value as Map?;
          setState(() {
            _requestCount = requests?.length ?? 0;
          });
        } else {
          setState(() {
            _requestCount = 0;
          });
        }
      }
    });
  }
}
