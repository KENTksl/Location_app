import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart' show consolidateHttpClientResponseBytes;
import 'package:flutter_svg/flutter_svg.dart' as svg;
import '../models/location_history.dart';
import '../services/location_history_service.dart';
import '../services/background_location_service.dart';
import 'location_history_page.dart';

class MapPage extends StatefulWidget {
  final String? focusFriendId;
  final String? focusFriendEmail;

  const MapPage({super.key, this.focusFriendId, this.focusFriendEmail});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? mapController;
  Set<Marker> _markers = {};
  LatLng? _currentPosition;
  final LatLng _defaultCenter = const LatLng(10.8231, 106.6297); // HCMC
  final Map<String, List<StreamSubscription>> _locationStreams = {};
  bool _isLoading = true;
  Polyline? _routePolyline;
  String? _routeDistance;
  Timer? _routeTimer;
  String? _selectedFriendId;
  String? _myAvatarUrl;
  final Map<String, String> _friendEmails = {};
  final Map<String, String> _friendAvatars = {};

  final Map<String, Marker> _friendMarkers = {};

  // Lưu vị trí cuối cùng và timer để animate di chuyển mượt
  final Map<String, LatLng> _friendLastPositions = {};
  final Map<String, Timer> _friendMoveTimers = {};

  // Nickname storage
  final Map<String, String> _friendNicknames = {};

  // Location History variables
  final LocationHistoryService _locationHistoryService =
      LocationHistoryService();
  List<LocationPoint> _currentRoutePoints = [];
  LocationRoute? _currentRoute;
  bool _isRecordingRoute = false;
  Timer? _routeRecordingTimer;
  StreamSubscription<Position>? _routeLocationSubscription;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadFriendsData();
    _loadMyAvatar();
    _listenToFriendsLocations();
    _loadCurrentRoute();
    _listenToMySharingStatus(); // Lắng nghe trạng thái chia sẻ vị trí của bản thân
    _loadNicknames(); // Load biệt danh

    if (widget.focusFriendId != null) {
      _autoRouteToFriend(widget.focusFriendId!, widget.focusFriendEmail);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMyAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final avatarRef = FirebaseDatabase.instance.ref(
          'users/${user.uid}/avatarUrl',
        );
        final avatarSnap = await avatarRef.get();
        if (avatarSnap.exists && mounted) {
          setState(() {
            _myAvatarUrl = avatarSnap.value as String?;
          });
        }

        // Lắng nghe thay đổi avatar
        avatarRef.onValue.listen((event) {
          if (event.snapshot.exists && mounted) {
            setState(() {
              _myAvatarUrl = event.snapshot.value as String?;
            });
            // Cập nhật marker khi avatar thay đổi
            if (_currentPosition != null) {
              _createMyMarker();
            }
          }
        });
      } catch (e) {
        print('Error loading my avatar: $e');
      }
    }
  }

  void _initializeMap() async {
    await _getCurrentLocation();
    await _loadFriendsData();
    _listenToFriendsLocations();

    if (widget.focusFriendId != null) {
      _autoRouteToFriend(widget.focusFriendId!, widget.focusFriendEmail);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFriendsData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Load friends theo cấu trúc cũ
    final friendsRef = FirebaseDatabase.instance.ref(
      'users/${user.uid}/friends',
    );
    final friendsSnap = await friendsRef.get();

    if (friendsSnap.exists) {
      final friendsData = friendsSnap.value as Map<dynamic, dynamic>;

      for (final friendId in friendsData.keys) {
        final friendRef = FirebaseDatabase.instance.ref('users/$friendId');
        final friendSnap = await friendRef.get();

        if (friendSnap.exists) {
          final friendData = friendSnap.value as Map<dynamic, dynamic>;
          _friendEmails[friendId] = friendData['email']?.toString() ?? '';
          _friendAvatars[friendId] = friendData['avatarUrl']?.toString() ?? '';

          // Kiểm tra trạng thái chia sẻ vị trí của bạn bè
          final locationRef = FirebaseDatabase.instance.ref(
            'users/$friendId/location',
          );
          final locationSnap = await locationRef.get();

          if (locationSnap.exists) {
            final locationData = locationSnap.value as Map<dynamic, dynamic>;
            final isSharing =
                locationData['isSharingLocation'] as bool? ?? false;
          }
        }
      }
    } else {}
  }

  Widget _buildAvatarWidget(String? avatarUrl, String email) {
    if (avatarUrl != null) {
      if (avatarUrl.startsWith('random:')) {
        // Hiển thị random avatar
        final seed = avatarUrl.substring(7);
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF10b981), width: 2),
          ),
          child: ClipOval(child: RandomAvatar(seed, height: 40, width: 40)),
        );
      } else if (avatarUrl.startsWith('http')) {
        // Network image
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF10b981), width: 2),
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: avatarUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildDefaultAvatar(email),
              errorWidget: (context, url, error) => _buildDefaultAvatar(email),
            ),
          ),
        );
      } else {
        // Local file
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF10b981), width: 2),
          ),
          child: ClipOval(
            child: Image.file(
              File(avatarUrl),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildDefaultAvatar(email),
            ),
          ),
        );
      }
    } else {
      return _buildDefaultAvatar(email);
    }
  }

  Widget _buildDefaultAvatar(String email) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF10b981).withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF10b981), width: 2),
      ),
      child: Center(
        child: Text(
          email.isNotEmpty ? email[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF10b981),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Hủy tất cả streams
    for (var streams in _locationStreams.values) {
      for (var stream in streams) {
        stream.cancel();
      }
    }
    _routeTimer?.cancel();
    _routeRecordingTimer?.cancel();
    _routeLocationSubscription?.cancel();
    super.dispose();
  }

  void _listenToFriendsLocations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final friendsSnap = await FirebaseDatabase.instance
          .ref('users/${user.uid}/friends')
          .get();
      if (friendsSnap.exists && friendsSnap.value is Map) {
        final friends = friendsSnap.value as Map;

        for (String friendId in friends.keys) {
          _listenToFriendLocation(friendId);
        }
      }
    } catch (e) {
      print('Lỗi listen friends locations: $e');
    }

    // Thêm listener để theo dõi thay đổi danh sách bạn bè
    final friendsRef = FirebaseDatabase.instance.ref(
      'users/${user.uid}/friends',
    );
    friendsRef.onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value is Map) {
        final friends = event.snapshot.value as Map;

        // Hủy các stream cũ không còn trong danh sách bạn bè
        final currentFriendIds = friends.keys.cast<String>();
        _locationStreams.keys.toList().forEach((friendId) {
          if (!currentFriendIds.contains(friendId)) {
            _locationStreams[friendId]?.forEach((sub) => sub.cancel());
            _locationStreams.remove(friendId);
            setState(() {
              _friendMarkers.remove(friendId);
            });
          }
        });

        // Thêm listener cho bạn bè mới
        for (String friendId in currentFriendIds) {
          if (!_locationStreams.containsKey(friendId)) {
            _listenToFriendLocation(friendId);
          }
        }
      }
    });
  }

  void _listenToFriendLocation(String friendId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Hủy stream cũ nếu có
    _locationStreams[friendId]?.forEach((sub) => sub.cancel());

    // Lắng nghe vị trí của bạn bè
    final locationRef = FirebaseDatabase.instance.ref(
      'users/$friendId/location',
    );
    final stream = locationRef.onValue;

  _locationStreams[friendId] = [
      stream.listen(
        (event) async {
          if (event.snapshot.exists) {
            final data = event.snapshot.value as Map<dynamic, dynamic>;
            final lat = data['latitude'] as double?;
            final lng = data['longitude'] as double?;
            final isOnline = data['isOnline'] as bool? ?? false;
            final isSharing = data['isSharingLocation'] as bool? ?? false;
            final lastUpdated = data['lastUpdated'] as int?;

            print(
              'Friend $friendId data: lat=$lat, lng=$lng, isOnline=$isOnline, isSharing=$isSharing',
            );

            // Kiểm tra xem dữ liệu có mới không (trong vòng 30 phút)
            final now = DateTime.now().millisecondsSinceEpoch;
            final isDataFresh =
                lastUpdated != null &&
                (now - lastUpdated) < 30 * 60 * 1000; // 30 phút

            if (lat != null && lng != null && isOnline && isSharing) {
              final position = LatLng(lat, lng);
              final friendEmail = _friendEmails[friendId] ?? '';
              final displayName = _getDisplayName(friendId, friendEmail);
              final avatarUrl = _friendAvatars[friendId];

              // Tạo custom marker chỉ khi chưa có marker trước đó
              BitmapDescriptor? markerIcon;
              if (!_friendMarkers.containsKey(friendId)) {
                markerIcon = await _createCustomMarkerFromAvatar(
                  avatarUrl,
                  displayName.isNotEmpty ? displayName : friendEmail,
                );
              }

              // Tính khoảng cách từ vị trí hiện tại tới bạn bè (km)
              double? distanceKm;
              if (_currentPosition != null) {
                distanceKm = Geolocator.distanceBetween(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                      position.latitude,
                      position.longitude,
                    ) /
                    1000; // km
              }
              final String snippetText =
                  distanceKm != null ? '${distanceKm.toStringAsFixed(1)} km' : '';

              final infoWindow = InfoWindow(
                title: displayName,
                snippet: snippetText,
              );

              if (!_friendMarkers.containsKey(friendId)) {
                setState(() {
                  _friendMarkers[friendId] = Marker(
                    markerId: MarkerId(friendId),
                    position: position,
                    icon: markerIcon!,
                    infoWindow: infoWindow,
                  );
                });
                _friendLastPositions[friendId] = position;
              } else {
                _updateFriendMarkerSmooth(friendId, position, infoWindow);
              }

              print(
                'Added marker for friend: $friendId, total markers: ${_friendMarkers.length}',
              );

              // Vẽ đường đi nếu có bạn bè được chọn
              if (_selectedFriendId == friendId) {
                _drawRouteToFriend(friendId, position);
              }
            } else {
              print(
                'Removing friend marker: $friendId - offline or stale data (lat=$lat, lng=$lng, isOnline=$isOnline, isSharing=$isSharing)',
              );
              setState(() {
                _friendMarkers.remove(friendId);
              });
            }
          } else {
            setState(() {
              _friendMarkers.remove(friendId);
            });
          }
        },
        onError: (error) {
          print('Error listening to friend location: $error');
          setState(() {
            _friendMarkers.remove(friendId);
          });
        },
      ),
    ];
  }

  void _updateFriendMarkerSmooth(
    String friendId,
    LatLng newPos,
    InfoWindow infoWindow, {
    int durationMs = 500,
    int steps = 20,
  }) {
    final existing = _friendMarkers[friendId];
    if (existing == null) {
      setState(() {
        _friendMarkers[friendId] = Marker(
          markerId: MarkerId(friendId),
          position: newPos,
          icon: BitmapDescriptor.defaultMarker,
          infoWindow: infoWindow,
        );
      });
      _friendLastPositions[friendId] = newPos;
      return;
    }

    final from = _friendLastPositions[friendId] ?? existing.position;
    final totalSteps = steps.clamp(5, 60);
    final stepDuration = Duration(milliseconds: (durationMs / totalSteps).round());

    // Hủy animation trước đó nếu có
    _friendMoveTimers[friendId]?.cancel();
    int currentStep = 0;
    _friendMoveTimers[friendId] = Timer.periodic(stepDuration, (timer) {
      currentStep++;
      final t = currentStep / totalSteps;
      final double lat = from.latitude + (newPos.latitude - from.latitude) * t;
      final double lng = from.longitude + (newPos.longitude - from.longitude) * t;
      final LatLng interpolated = LatLng(lat, lng);

      // Giữ nguyên icon và markerId
      final Marker m = existing;
      setState(() {
        _friendMarkers[friendId] = Marker(
          markerId: m.markerId,
          position: interpolated,
          icon: m.icon,
          infoWindow: infoWindow,
        );
      });

      if (currentStep >= totalSteps) {
        timer.cancel();
        _friendMoveTimers.remove(friendId);
        _friendLastPositions[friendId] = newPos;
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng bật GPS để sử dụng tính năng này'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _currentPosition = _defaultCenter;
        });
        await _createMyMarker();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cần quyền truy cập vị trí để hiển thị bản đồ'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _currentPosition = _defaultCenter;
        });
        await _createMyMarker();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
      });
      await _createMyMarker();

      if (mounted && mapController != null) {
        try {
          mapController?.animateCamera(
            CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
          );
        } catch (e) {
          print('Lỗi di chuyển camera: $e');
        }
      }
    } catch (e) {
      print('Lỗi lấy vị trí: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể lấy vị trí: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _currentPosition = _defaultCenter;
      });
      await _createMyMarker();
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_currentPosition != null) {
      mapController?.moveCamera(CameraUpdate.newLatLng(_currentPosition!));
    }
  }

  Future<void> _showFriendOnMap(String friendId, String friendEmail) async {
    final locSnap = await FirebaseDatabase.instance
        .ref('locations/$friendId')
        .get();
    if (locSnap.exists) {
      final data = locSnap.value as Map;
      final lat = data['lat'] as double? ?? (data['lat'] as num).toDouble();
      final lng = data['lng'] as double? ?? (data['lng'] as num).toDouble();
      final LatLng friendPos = LatLng(lat, lng);

      // Tính khoảng cách từ vị trí hiện tại tới bạn bè (km)
      double? distanceKm;
      if (_currentPosition != null) {
        distanceKm = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              friendPos.latitude,
              friendPos.longitude,
            ) /
            1000; // km
      }
      final String snippetText =
          distanceKm != null ? '${distanceKm.toStringAsFixed(1)} km' : '';
      final String displayName = _getDisplayName(friendId, friendEmail);

      // Dùng custom marker với avatar bạn bè
      final String? avatarUrl = _friendAvatars[friendId];
      final markerIcon = await _createCustomMarkerFromAvatar(
        avatarUrl,
        displayName.isNotEmpty ? displayName : friendEmail,
      );

      setState(() {
        _markers.add(
          Marker(
            markerId: MarkerId('friend_$friendId'),
            position: friendPos,
            infoWindow: InfoWindow(title: displayName, snippet: snippetText),
            icon: markerIcon,
          ),
        );
      });
      mapController?.animateCamera(CameraUpdate.newLatLngZoom(friendPos, 18));
      await _drawRouteToFriend(friendId, friendPos);
      _startRouteTimer(friendId, friendPos, interval: 8);
    }
  }

  Future<void> _drawRouteToFriend(String friendId, LatLng friendPos) async {
    if (_currentPosition == null) return;
    final origin = _currentPosition!;
    final destination = friendPos;
    final apiKey = "AIzaSyCkM75BbiZB7jj2FCpukf-cq4F2FLfYJv8";
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$apiKey&mode=walking";
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(Uri.parse(url));
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    final data = jsonDecode(responseBody);
    if (data['status'] == 'OK') {
      final points = data['routes'][0]['overview_polyline']['points'];
      final polylinePoints = _decodePolyline(points);
      final distance = data['routes'][0]['legs'][0]['distance']['text'];
      if (mounted) {
        setState(() {
          _routePolyline = Polyline(
            polylineId: PolylineId('route_to_$friendId'),
            color: Colors.blue,
            width: 6,
            points: polylinePoints,
          );
          _routeDistance = distance;
          _selectedFriendId = friendId;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _routePolyline = null;
          _routeDistance = null;
          _selectedFriendId = null;
        });
      }
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
  }

  void _startRouteTimer(
    String friendId,
    LatLng friendPos, {
    int interval = 15,
  }) {
    _routeTimer?.cancel();
    _routeTimer = Timer.periodic(Duration(seconds: interval), (_) {
      _drawRouteToFriend(friendId, friendPos);
    });
  }

  void _stopRouteTimer() {
    _routeTimer?.cancel();
    _routeTimer = null;
    if (mounted) {
      setState(() {
        _routePolyline = null;
        _routeDistance = null;
        _selectedFriendId = null;
      });
    }
  }

  void _fitBounds() {
    if (_markers.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final marker in _markers) {
      minLat = min(minLat, marker.position.latitude);
      maxLat = max(maxLat, marker.position.latitude);
      minLng = min(minLng, marker.position.longitude);
      maxLng = max(maxLng, marker.position.longitude);
    }

    // Thêm vị trí hiện tại nếu có
    if (_currentPosition != null) {
      minLat = min(minLat, _currentPosition!.latitude);
      maxLat = max(maxLat, _currentPosition!.latitude);
      minLng = min(minLng, _currentPosition!.longitude);
      maxLng = max(maxLng, _currentPosition!.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  void _resetView() {
    if (_currentPosition != null) {
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition!, 15),
      );
    } else {
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_defaultCenter, 15),
      );
    }
  }

  void _autoRouteToFriend(String friendId, String? friendEmail) async {
    // Kiểm tra vị trí hiện tại của bạn bè trước
    final locationRef = FirebaseDatabase.instance.ref(
      'users/$friendId/location',
    );
    final currentLocationSnap = await locationRef.get();

    if (currentLocationSnap.exists && _currentPosition != null) {
      final data = currentLocationSnap.value as Map;
      final lat =
          data['latitude'] as double? ?? (data['latitude'] as num).toDouble();
      final lng =
          data['longitude'] as double? ?? (data['longitude'] as num).toDouble();
      final isOnline = data['isOnline'] as bool? ?? false;
      final isSharing = data['isSharingLocation'] as bool? ?? false;

      if (isOnline && isSharing) {
        final LatLng friendPos = LatLng(lat, lng);

        // Focus camera vào vị trí bạn bè ngay lập tức
        mapController?.animateCamera(CameraUpdate.newLatLngZoom(friendPos, 16));

        _drawRouteToFriend(friendId, friendPos);
        _startRouteTimer(friendId, friendPos, interval: 8);
      }
    }

    // Lắng nghe thay đổi vị trí bạn bè
    locationRef.onValue.listen((event) async {
      if (event.snapshot.exists && _currentPosition != null) {
        final data = event.snapshot.value as Map;
        final lat =
            data['latitude'] as double? ?? (data['latitude'] as num).toDouble();
        final lng =
            data['longitude'] as double? ??
            (data['longitude'] as num).toDouble();
        final LatLng friendPos = LatLng(lat, lng);

        // Đợi một chút để đảm bảo mapController đã sẵn sàng
        await Future.delayed(const Duration(milliseconds: 500));

        // Focus camera vào vị trí bạn bè
        mapController?.animateCamera(CameraUpdate.newLatLngZoom(friendPos, 16));

        _drawRouteToFriend(friendId, friendPos);
        _startRouteTimer(friendId, friendPos, interval: 8);
      } else {
        _stopRouteTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              mapController = controller;
              _initializeMap();
            },
            initialCameraPosition: CameraPosition(
              target: _defaultCenter,
              zoom: 15.0,
            ),
            markers: {..._markers, ..._friendMarkers.values},
            polylines: _routePolyline != null ? {_routePolyline!} : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            onTap: (_) => _stopRouteTimer(),
          ),

          // Modern App Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(
                top: 50,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF10b981),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Bản đồ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _getCurrentLocation,
                      icon: const Icon(
                        Icons.my_location_rounded,
                        color: Color(0xFF10b981),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Simplified Zoom Controls - chỉ giữ lại zoom in/out
          Positioned(
            top: 100,
            right: 16,
            child: Column(
              children: [
                _buildControlButton(
                  icon: Icons.add_rounded,
                  onPressed: () {
                    mapController?.animateCamera(CameraUpdate.zoomIn());
                  },
                ),
                const SizedBox(height: 8),
                _buildControlButton(
                  icon: Icons.remove_rounded,
                  onPressed: () {
                    mapController?.animateCamera(CameraUpdate.zoomOut());
                  },
                ),
                const SizedBox(height: 8),
                _buildControlButton(
                  icon: _isRecordingRoute
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  onPressed: _isRecordingRoute
                      ? _stopRouteRecording
                      : _startRouteRecording,
                  isActive: _isRecordingRoute,
                ),
                const SizedBox(height: 8),
                _buildControlButton(
                  icon: Icons.history_rounded,
                  onPressed: _showLocationHistory,
                ),
              ],
            ),
          ),
          // Route Distance Card
          if (_routeDistance != null)
            Positioned(
              top: 100,
              left: 16,
              right: 100,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.route_rounded,
                        color: Color(0xFF667eea),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Khoảng cách: $_routeDistance',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1e293b),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF667eea),
                      ),
                      onPressed: () {
                        setState(() {
                          _routePolyline = null;
                          _routeDistance = null;
                          _selectedFriendId = null;
                        });
                        _stopRouteTimer();
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Recording Route Card
          if (_isRecordingRoute)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Đang ghi lộ trình',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${_currentRoutePoints.length} điểm - ${_locationHistoryService.calculateTotalDistance(_currentRoutePoints).toStringAsFixed(2)}km',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop_rounded, color: Colors.white),
                      onPressed: _stopRouteRecording,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF667eea)
            : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isActive ? Colors.white : const Color(0xFF667eea),
        ),
        onPressed: onPressed,
      ),
    );
  }

  Future<BitmapDescriptor> _createCustomMarkerFromAvatar(
    String? avatarUrl,
    String label,
  ) async {
    try {
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        if (avatarUrl.startsWith('random:')) {
          // Random avatar (tạm thời hiển thị avatar mặc định chữ cái)
          final seed = avatarUrl.substring(7); // Remove 'random:' prefix
          return await _createMarkerFromRandomAvatar(seed, label);
        } else if (avatarUrl.startsWith('http')) {
          // Network image
          return await _createMarkerFromNetworkImage(avatarUrl, label);
        } else {
          // Local file
          return await _createMarkerFromLocalFile(avatarUrl);
        }
      } else {
        // Default avatar
        return await _createMarkerFromDefaultAvatar(label);
      }
    } catch (e) {
      print('Error creating custom marker: $e');
      return await _createMarkerFromDefaultAvatar(label);
    }
  }

  Future<BitmapDescriptor> _createMarkerFromRandomAvatar(String seed, String label) async {
    try {
      // Tạm thời: dùng avatar mặc định (chữ cái) để tránh lỗi parser SVG.
      // Khi cần hiển thị đúng random_avatar, sẽ tích hợp render SVG tương thích.
      return await _createMarkerFromDefaultAvatar(label);
    } catch (e) {
      print('Error creating random avatar marker: $e');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  Future<BitmapDescriptor> _createMarkerFromNetworkImage(
    String imageUrl,
    String email,
  ) async {
    try {
      // Tải ảnh mạng và vẽ thành icon tròn nhỏ, nét
      const double size = 36.0;
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(imageUrl));
      final response = await request.close();
      if (response.statusCode == 200) {
        final Uint8List bytes = await consolidateHttpClientResponseBytes(response);
        return await _circularImageMarkerFromBytes(
          bytes,
          size: size,
          borderColor: Colors.white,
          borderWidth: 2.0,
        );
      } else {
        // Fallback về default avatar nếu tải ảnh thất bại
        return await _createMarkerFromDefaultAvatar(email);
      }
    } catch (e) {
      print('Error creating network image marker: $e');
      return await _createMarkerFromDefaultAvatar(email);
    }
  }

  Future<BitmapDescriptor> _createMarkerFromLocalFile(String filePath) async {
    try {
      // Đọc file và vẽ icon tròn nhỏ, nét
      const double size = 36.0;
      final Uint8List bytes = await File(filePath).readAsBytes();
      return await _circularImageMarkerFromBytes(bytes, size: size, borderColor: Colors.white, borderWidth: 2.0);
    } catch (e) {
      print('Error creating local file marker: $e');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
    }
  }

  Future<BitmapDescriptor> _createMarkerFromDefaultAvatar(String label) async {
    try {
      final text = label.trim();
      final initial = text.isNotEmpty ? text[0].toUpperCase() : '?';
      const double size = 36.0;
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final Rect rect = Rect.fromLTWH(0, 0, size, size);

      // Nền tròn màu xanh
      final Paint fillPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2, fillPaint);

      // Viền trắng
      final Paint borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2, borderPaint);

      // Chữ cái đầu
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset((size - tp.width) / 2, (size - tp.height) / 2),
      );

      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
      final ByteData? bd = await image.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.bytes(bd!.buffer.asUint8List());
    } catch (e) {
      print('Error creating default avatar marker: $e');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }

  Future<BitmapDescriptor> _circularImageMarkerFromBytes(
    Uint8List bytes, {
    double size = 36.0,
    Color borderColor = Colors.white,
    double borderWidth = 2.0,
  }) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: size.toInt(),
        targetHeight: size.toInt(),
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image img = frame.image;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final Rect rect = Rect.fromLTWH(0, 0, size, size);
      final Path clipPath = Path()..addOval(rect);

      // Vẽ ảnh với clip hình tròn
      canvas.save();
      canvas.clipPath(clipPath);
      paintImage(
        canvas: canvas,
        rect: rect,
        image: img,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
      canvas.restore();

      // Viền trắng
      final Paint borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - borderWidth / 2, borderPaint);

      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
    } catch (e) {
      print('Error creating circular image marker: $e');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
    }
  }

  Future<BitmapDescriptor> _createFallbackMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 36.0;

    // Vẽ hình tròn với màu nền xanh dương
    final Paint circlePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 2,
      circlePaint,
    );

    // Vẽ viền trắng
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 2 - 2,
      borderPaint,
    );

    // Vẽ chữ cái A
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'A',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    final Uint8List uint8List = byteData!.buffer.asUint8List();
    return BitmapDescriptor.bytes(uint8List);
  }

  // Marker chấm tròn cho vị trí của bản thân
  Future<BitmapDescriptor> _createDotMarker({
    Color fillColor = const Color(0xFF1E88E5),
    Color borderColor = Colors.white,
    double size = 20.0,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    // Nền trong suốt
    final Paint transparent = Paint()
      ..color = const Color(0x00000000)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size, size), transparent);

    // Vòng tròn viền trắng
    final double radius = size / 2 - 1;
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), radius, borderPaint);

    // Chấm xanh ở giữa
    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), radius - 3, fillPaint);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();
    return BitmapDescriptor.bytes(uint8List);
  }

  Future<void> _createMyMarker() async {
    // Không tạo marker tùy chỉnh cho vị trí bản thân nữa.
    // Sử dụng chấm mặc định của Google Map (myLocationEnabled: true).
    // Đảm bảo không có marker 'me' trùng lặp.
    setState(() {
      _markers = {};
    });
  }

  void _listenToMySharingStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final sharingRef = FirebaseDatabase.instance.ref(
      'users/${user.uid}/isSharingLocation',
    );

    sharingRef.onValue.listen((event) {
      if (mounted) {
        // Cập nhật marker khi trạng thái chia sẻ thay đổi
        _createMyMarker();
      }
    });

    // Lắng nghe thay đổi dữ liệu vị trí
    final locationRef = FirebaseDatabase.instance.ref(
      'users/${user.uid}/location',
    );

    locationRef.onValue.listen((event) {
      if (mounted) {
        if (!event.snapshot.exists) {
          // Xóa marker khi dữ liệu vị trí bị xóa
          setState(() {
            _markers = {};
          });
        } else {
          // Cập nhật marker khi có dữ liệu vị trí mới
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          final lat = data['latitude'] as double?;
          final lng = data['longitude'] as double?;

          if (lat != null && lng != null) {
            setState(() {
              _currentPosition = LatLng(lat, lng);
            });
            _createMyMarker();
          }
        }
      }
    });
  }

  String _getAvatarType(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return 'Default Avatar';
    } else if (avatarUrl.startsWith('random:')) {
      return 'Random Avatar';
    } else if (avatarUrl.startsWith('http')) {
      return 'Network Avatar';
    } else {
      return 'Local Avatar';
    }
  }

  // Location History Methods
  Future<void> _loadCurrentRoute() async {
    try {
      _currentRoute = await _locationHistoryService.getCurrentRoute();
      if (_currentRoute != null) {
        _currentRoutePoints = _currentRoute!.points;
        setState(() {
          _isRecordingRoute = true;
        });
        // Resume location tracking
        _startLocationTracking();
      }
    } catch (e) {
      print('Error loading current route: $e');
    }
  }

  Future<void> _checkLocationPermission() async {
    _hasLocationPermission = await _locationHistoryService
        .checkLocationPermission();
    if (!_hasLocationPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cần quyền truy cập vị trí để ghi lộ trình'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _startRouteRecording() async {
    // Kiểm tra permission trước
    await _checkLocationPermission();
    if (!_hasLocationPermission) {
      return;
    }

    // Lấy vị trí hiện tại
    final currentPoint = await _locationHistoryService
        .getCurrentLocationPoint();
    if (currentPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lấy vị trí hiện tại'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print(
      'Current location point: ${currentPoint.latitude}, ${currentPoint.longitude}',
    );

    setState(() {
      _isRecordingRoute = true;
      _currentRoutePoints = [currentPoint];
    });

    // Bắt đầu theo dõi vị trí real-time
    _startLocationTracking();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bắt đầu ghi lộ trình'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _stopRouteRecording() async {
    _routeLocationSubscription?.cancel();

    // Kiểm tra route có hợp lệ không
    if (!_locationHistoryService.isValidRoute(_currentRoutePoints)) {
      setState(() {
        _isRecordingRoute = false;
        _currentRoutePoints = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lộ trình quá ngắn hoặc thời gian quá ít'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Tạo route mới với tên tự động
    final routeName =
        _currentRoute?.name ??
        _locationHistoryService.generateRouteName(
          _locationHistoryService.createRoute(
            name: 'Temp',
            points: _currentRoutePoints,
          ),
        );

    final route = _locationHistoryService.createRoute(
      name: routeName,
      points: _currentRoutePoints,
    );

    // Lưu route
    await _locationHistoryService.saveRouteLocally(route);
    await _locationHistoryService.saveRouteToFirebase(route);
    await _locationHistoryService.clearCurrentRoute();

    setState(() {
      _isRecordingRoute = false;
      _currentRoutePoints = [];
      _currentRoute = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã lưu lộ trình: ${route.totalDistance.toStringAsFixed(2)}km',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _startLocationTracking() {
    _routeLocationSubscription?.cancel();

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1, // 1 meter
      timeLimit: Duration(seconds: 30),
    );

    _routeLocationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _onLocationUpdate(position);
          },
          onError: (error) {
            print('Location stream error: $error');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Lỗi theo dõi vị trí: $error'),
                backgroundColor: Colors.red,
              ),
            );
          },
        );
  }

  void _onLocationUpdate(Position position) async {
    if (!_isRecordingRoute) return;

    final newPoint = LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      accuracy: position.accuracy,
      speed: position.speed,
      altitude: position.altitude,
    );

    // Kiểm tra xem có nên thêm điểm mới không
    if (_locationHistoryService.shouldAddPoint(newPoint, _currentRoutePoints)) {
      print(
        'Adding new point to route. Total points: ${_currentRoutePoints.length + 1}',
      );

      setState(() {
        _currentRoutePoints.add(newPoint);
      });

      // Cập nhật current route
      if (_currentRoute != null) {
        _currentRoute = _locationHistoryService.createRoute(
          name: _currentRoute!.name,
          points: _currentRoutePoints,
          description: _currentRoute!.description,
        );
        await _locationHistoryService.saveCurrentRoute(_currentRoute!);
      } else {
        _currentRoute = _locationHistoryService.createRoute(
          name: 'Lộ trình đã ghi',
          points: _currentRoutePoints,
        );
        await _locationHistoryService.saveCurrentRoute(_currentRoute!);
      }

      // Cập nhật vị trí hiện tại trên map
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      await _createMyMarker();
    } else {}
  }

  void _showLocationHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationHistoryPage()),
    );
  }

  // Load nicknames from SharedPreferences
  Future<void> _loadNicknames() async {
    final prefs = await SharedPreferences.getInstance();
    final nicknamesJson = prefs.getString('friend_nicknames');
    if (nicknamesJson != null) {
      final Map<String, dynamic> decoded = json.decode(nicknamesJson);
      setState(() {
        _friendNicknames.clear();
        decoded.forEach((key, value) {
          _friendNicknames[key] = value.toString();
        });
      });
    }
  }

  // Get display name (nickname or original name)
  String _getDisplayName(String friendId, String friendEmail) {
    return _friendNicknames[friendId] ?? friendEmail.split('@')[0];
  }
}


