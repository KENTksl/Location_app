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
import 'dart:ui';
import 'login_page.dart';
import 'friend_requests_page.dart';
import 'location_history_page.dart';
import '../theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../state/favorite_places_controller.dart';
import '../services/map_navigation_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'favorite_place_picker_page.dart';
import '../models/favorite_place.dart';
import 'main_navigation_page.dart';
import '../services/toast_service.dart';

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
  bool _pressFriend = false;
  bool _pressHistory = false;
  bool _pressLogout = false;
  bool _favoritesLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    _checkLocationSharingStatus();
    _loadAvatar();
    _loadStats();
    _generateAvailableAvatars();
    _listenToFriendRequests();
    // Show permission guidance if first time entering Profile
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowPermissionBottomSheet();
        // Ensure favorite places are loaded after auth is ready
        if (!_favoritesLoadedOnce) {
          _favoritesLoadedOnce = true;
          // Call load() via provider to refresh list when opening profile
          try {
            context.read<FavoritePlacesController>().load();
            // Bắt đầu lắng nghe realtime để phản ánh xoá/thêm ngay lập tức
            context.read<FavoritePlacesController>().startListening();
          } catch (_) {}
        }
      });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _backgroundTimer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _maybeShowPermissionBottomSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('location_permission_prompt_shown') ?? false;
    if (shown) return;
    await prefs.setBool('location_permission_prompt_shown', true);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      builder: (ctx) {
        bool pressPrimary = false;
        return StatefulBuilder(builder: (context, setBSState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                      boxShadow: AppTheme.buttonShadow,
                    ),
                    child: const Icon(Icons.location_pin, color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Bật chia sẻ vị trí?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1e293b)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ứng dụng cần quyền truy cập vị trí để chia sẻ với bạn bè theo thời gian thực.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748b)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTapDown: (_) => setBSState(() => pressPrimary = true),
                        onTapCancel: () => setBSState(() => pressPrimary = false),
                        onTapUp: (_) => setBSState(() => pressPrimary = false),
                        onTap: () async {
                          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã bật hướng dẫn chia sẻ vị trí.')),
                          );
                        },
                        child: AnimatedScale(
                          scale: pressPrimary ? 0.97 : 1.0,
                          duration: const Duration(milliseconds: 120),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: AppTheme.buttonShadow,
                            ),
                            child: const Center(
                              child: Text('Bật ngay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          side: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
                          foregroundColor: const Color(0xFF1e293b),
                        ),
                        onPressed: () {
                          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                        },
                        child: const Text('Để sau', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        });
      },
    );
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
      final success = await BackgroundLocationService.instance
          .startBackgroundLocationTracking();

      if (success) {
        print('Background location service started successfully');

        // Cập nhật trạng thái ngay lập tức
        await _updateLocationImmediately();
      } else {
        print(
          'Failed to start background location service, falling back to foreground tracking',
        );
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
        // Modal background: white, large top rounded corners (28px)
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Chọn Avatar',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600, // medium weight
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
                      // White tile, rounded 20px, soft shadow
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF8E6CF2),
                        width: 1, // thin purple border
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_a_photo,
                      color: Color(0xFF8E6CF2),
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
                    // White rounded-square tile (20px) with soft shadow
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF8E6CF2)
                          : Colors.transparent,
                      width: isSelected ? 2 : 0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                      if (isSelected)
                        BoxShadow(
                          // Soft glow for selected tile
                          color: const Color(0xFF8E6CF2).withOpacity(0.35),
                          blurRadius: 12,
                          spreadRadius: 0.5,
                          offset: const Offset(0, 3),
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    // Ensure avatars are fully visible with no overlays
                    child: RandomAvatar(avatarSeed, height: 60, width: 60),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favCtrl = context.watch<FavoritePlacesController>();
    return Scaffold(
      body: Container(
        // Soft purple-blue vertical gradient for the top area
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6F3FF), Color(0xFFECE8FF)],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                // Ensure avatar does not touch top status bar
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 28,
                  bottom: 20,
                ),
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
                            color: Color(0xFF1e293b),
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
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

                    const SizedBox(height: 14),

                    // Favorite Places Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.place_outlined,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Địa điểm yêu thích',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1e293b),
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const FavoritePlacePickerPage(),
                                    ),
                                  ).then((result) {
                                    // Làm mới danh sách sau khi quay lại từ trang chọn địa điểm
                                    try {
                                      context.read<FavoritePlacesController>().load();
                                    } catch (_) {}
                                    // Hiển thị toast ở trang Hồ sơ để đảm bảo overlay còn tồn tại
                                    if (result is FavoritePlace && mounted) {
                                      ToastService.show(
                                        context,
                                        message: 'Đã lưu địa điểm yêu thích',
                                        type: AppToastType.success,
                                      );
                                    }
                                  });
                                },
                                icon: const Icon(Icons.add_location_alt_rounded),
                                label: const Text('Thêm'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (favCtrl.loading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else if (favCtrl.places.isEmpty)
                            Text(
                              'Bạn chưa lưu địa điểm nào.',
                              style: TextStyle(
                                fontSize: 14,
                                color: const Color(0xFF1e293b).withOpacity(0.7),
                              ),
                            )
                          else
                            ListView.separated(
                              itemCount: favCtrl.places.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final p = favCtrl.places[i];
                                return Container(
                                  key: ValueKey<String>('fav_${p.id}'),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.place_rounded, color: AppTheme.primaryColor),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.name,
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              p.address,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748b)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Xem trên bản đồ',
                                        icon: const Icon(Icons.map_rounded),
                                        onPressed: () {
                                          MapNavigationService.instance
                                              .requestFocus(LatLng(p.lat, p.lng));
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const MainNavigationPage(selectedTab: 0),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        tooltip: 'Xóa',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Xóa địa điểm'),
                                              content: Text('Bạn có chắc muốn xóa "${p.name}"?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  child: const Text('Hủy'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: const Text('Xóa', style: TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            try {
                                              final controller = context.read<FavoritePlacesController>();
                                              await controller.deletePlace(p.id);
                                              // Đồng bộ lại danh sách từ Firestore để đảm bảo UI cập nhật tức thì
                                              await controller.load();
                                              if (mounted) {
                                                // Nếu bản đồ đang focus vào địa điểm này, hãy xóa trạng thái focus
                                                MapNavigationService.instance.clearFocus();
                                                setState(() {}); // ép rebuild giao diện
                                                ToastService.show(
                                                  context,
                                                  message: 'Đã xóa địa điểm',
                                                  type: AppToastType.success,
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ToastService.show(
                                                  context,
                                                  message: 'Xóa thất bại: $e',
                                                  type: AppToastType.error,
                                                );
                                              }
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Location Sharing Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
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
                                    ? Icons.location_on_outlined
                                    : Icons.location_off_outlined,
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

                    const SizedBox(height: 14),

                    // Friend Requests Card (Solid white card + gradient pill)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Lời mời kết bạn',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
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
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: AppTheme.buttonShadow,
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
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xFF1e293b).withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 10),
                          AnimatedScale(
                            scale: _pressFriend ? 0.97 : 1.0,
                            duration: const Duration(milliseconds: 120),
                            child: GestureDetector(
                              onTapDown: (_) =>
                                  setState(() => _pressFriend = true),
                              onTapCancel: () =>
                                  setState(() => _pressFriend = false),
                              onTapUp: (_) =>
                                  setState(() => _pressFriend = false),
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const FriendRequestsPage(),
                                  ),
                                );
                                if (result == true) {
                                  _loadStats();
                                }
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: AppTheme.buttonShadow,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Quản lý lời mời',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    left: 4,
                                    right: 4,
                                    child: Container(
                                      height: 6,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(3),
                                        color: Colors.white.withOpacity(0.15),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Location History Card (Solid white + gradient pill)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history_outlined,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Lịch sử di chuyển',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1e293b),
                              ),
                            ),
                          ),
                          AnimatedScale(
                            scale: _pressHistory ? 0.97 : 1.0,
                            duration: const Duration(milliseconds: 120),
                            child: GestureDetector(
                              onTapDown: (_) =>
                                  setState(() => _pressHistory = true),
                              onTapCancel: () =>
                                  setState(() => _pressHistory = false),
                              onTapUp: (_) =>
                                  setState(() => _pressHistory = false),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const LocationHistoryPage(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: AppTheme.buttonShadow,
                                ),
                                child: const Text(
                                  'Xem',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Logout Card (Solid white + red pill)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.logout_outlined,
                            color: Color(0xFFEF4444),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Đăng xuất',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1e293b),
                              ),
                            ),
                          ),
                          AnimatedScale(
                            scale: _pressLogout ? 0.97 : 1.0,
                            duration: const Duration(milliseconds: 120),
                            child: GestureDetector(
                              onTapDown: (_) =>
                                  setState(() => _pressLogout = true),
                              onTapCancel: () =>
                                  setState(() => _pressLogout = false),
                              onTapUp: (_) =>
                                  setState(() => _pressLogout = false),
                              onTap: () async {
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
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: AppTheme.buttonShadow,
                                ),
                                child: const Text(
                                  'Thoát',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
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
