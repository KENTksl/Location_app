import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:random_avatar/random_avatar.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import '../models/location_history.dart';
import '../services/location_history_service.dart';
import 'location_history_page.dart';

class MapPage extends StatefulWidget {
  final String? focusFriendId;
  final String? focusFriendEmail;

  const MapPage({Key? key, this.focusFriendId, this.focusFriendEmail})
    : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? mapController;
  Set<Marker> _markers = {};
  LatLng? _currentPosition;
  final LatLng _defaultCenter = const LatLng(10.8231, 106.6297); // HCMC
  Map<String, List<StreamSubscription>> _locationStreams = {};
  bool _isLoading = true;
  Polyline? _routePolyline;
  String? _routeDistance;
  Timer? _routeTimer;
  String? _selectedFriendId;
  String? _myAvatarUrl;
  Map<String, String> _friendEmails = {};
  Map<String, String> _friendAvatars = {};
  bool _is3DEnabled = false;
  Map<String, Marker> _friendMarkers = {};

  // Location History variables
  final LocationHistoryService _locationHistoryService =
      LocationHistoryService();
  List<LocationPoint> _currentRoutePoints = [];
  LocationRoute? _currentRoute;
  bool _isRecordingRoute = false;
  Timer? _routeRecordingTimer;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadFriendsData();
    _loadMyAvatar();
    _listenToFriendsLocations();
    _loadCurrentRoute();
    _listenToMySharingStatus(); // Lắng nghe trạng thái chia sẻ vị trí của bản thân

    if (widget.focusFriendId != null) {
      _autoRouteToFriend(widget.focusFriendId!, widget.focusFriendEmail);
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadMyAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final avatarRef = FirebaseDatabase.instance.ref(
          'users/${user.uid}/avatarUrl',
        );
        final avatarSnap = await avatarRef.get();
        if (avatarSnap.exists) {
          setState(() {
            _myAvatarUrl = avatarSnap.value as String?;
          });
        }

        // Lắng nghe thay đổi avatar
        avatarRef.onValue.listen((event) {
          if (event.snapshot.exists && mounted) {
            print('Map: My avatar updated to: ${event.snapshot.value}');
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

    setState(() {
      _isLoading = false;
    });
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
        }
      }
    }
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
    _locationStreams.values.forEach((streams) {
      streams.forEach((stream) => stream.cancel());
    });
    _routeTimer?.cancel();
    _routeRecordingTimer?.cancel();
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
      stream.listen((event) async {
        if (event.snapshot.exists) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          final lat = data['latitude'] as double?;
          final lng = data['longitude'] as double?;
          final isOnline = data['isOnline'] as bool? ?? false;
          final isSharing = data['isSharingLocation'] as bool? ?? false;

          if (lat != null && lng != null && isOnline && isSharing) {
            final position = LatLng(lat, lng);
            final friendEmail = _friendEmails[friendId] ?? '';
            final avatarUrl = _friendAvatars[friendId];

            // Tạo custom marker với avatar
            final markerIcon = await _createCustomMarkerFromAvatar(
              avatarUrl,
              friendEmail,
            );

            setState(() {
              _friendMarkers[friendId] = Marker(
                markerId: MarkerId(friendId),
                position: position,
                icon: markerIcon,
                infoWindow: InfoWindow(
                  title: friendEmail.split('@')[0],
                  snippet: 'Bạn bè - ${_getAvatarType(avatarUrl)}',
                ),
              );
            });

            // Vẽ đường đi nếu có bạn bè được chọn
            if (_selectedFriendId == friendId) {
              _drawRouteToFriend(friendId, position);
            }
          } else {
            setState(() {
              _friendMarkers.remove(friendId);
            });
          }
        } else {
          setState(() {
            _friendMarkers.remove(friendId);
          });
        }
      }),
    ];
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
      setState(() {
        _markers.add(
          Marker(
            markerId: MarkerId('friend_$friendId'),
            position: friendPos,
            infoWindow: InfoWindow(title: 'Bạn bè: $friendEmail'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
        );
      });
      mapController?.animateCamera(CameraUpdate.newLatLngZoom(friendPos, 18));
      // Vẽ đường đi và cập nhật khoảng cách liên tục
      await _drawRouteToFriend(friendId, friendPos);
      _startRouteTimer(friendId, friendPos, interval: 8);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$friendEmail chưa chia sẻ vị trí!')),
      );
      _stopRouteTimer();
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
    } else {
      setState(() {
        _routePolyline = null;
        _routeDistance = null;
        _selectedFriendId = null;
      });
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
    setState(() {
      _routePolyline = null;
      _routeDistance = null;
      _selectedFriendId = null;
    });
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
    final locationRef = FirebaseDatabase.instance.ref('users/$friendId/location');
    final currentLocationSnap = await locationRef.get();
    
    if (currentLocationSnap.exists && _currentPosition != null) {
      final data = currentLocationSnap.value as Map;
      final lat = data['latitude'] as double? ?? (data['latitude'] as num).toDouble();
      final lng = data['longitude'] as double? ?? (data['longitude'] as num).toDouble();
      final isOnline = data['isOnline'] as bool? ?? false;
      final isSharing = data['isSharingLocation'] as bool? ?? false;
      
      if (lat != null && lng != null && isOnline && isSharing) {
        final LatLng friendPos = LatLng(lat, lng);
        
        // Focus camera vào vị trí bạn bè ngay lập tức
        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(friendPos, 16),
        );
        
        _drawRouteToFriend(friendId, friendPos);
        _startRouteTimer(friendId, friendPos, interval: 8);
      }
    }
    
    // Lắng nghe thay đổi vị trí bạn bè
    locationRef.onValue.listen((event) async {
      if (event.snapshot.exists && _currentPosition != null) {
        final data = event.snapshot.value as Map;
        final lat = data['latitude'] as double? ?? (data['latitude'] as num).toDouble();
        final lng = data['longitude'] as double? ?? (data['longitude'] as num).toDouble();
        final LatLng friendPos = LatLng(lat, lng);
        
        // Đợi một chút để đảm bảo mapController đã sẵn sàng
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Focus camera vào vị trí bạn bè
        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(friendPos, 16),
        );
        
        _drawRouteToFriend(friendId, friendPos);
        _startRouteTimer(friendId, friendPos, interval: 8);
      } else {
        _stopRouteTimer();
      }
    });
  }

  void _toggle3DView() {
    setState(() {
      _is3DEnabled = !_is3DEnabled;
    });

    if (_is3DEnabled) {
      // Tạo hiệu ứng 3D bằng cách zoom in và thay đổi bearing
      mapController?.animateCamera(CameraUpdate.zoomIn());
    } else {
      // Reset về view bình thường
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
    String email,
  ) async {
    try {
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        if (avatarUrl.startsWith('random:')) {
          // Random avatar - màu xanh dương với chữ cái đầu
          return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          );
        } else if (avatarUrl.startsWith('http')) {
          // Network image - màu cam với chữ cái đầu
          return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          );
        } else {
          // Local file - màu tím với chữ cái đầu
          return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          );
        }
      } else {
        // Default avatar - màu xanh lá với chữ cái đầu
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      }
    } catch (e) {
      print('Error creating custom marker: $e');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }

  Future<BitmapDescriptor> _createMarkerFromRandomAvatar(String seed) async {
    // Sử dụng màu xanh dương cho random avatar
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  Future<BitmapDescriptor> _createMarkerFromNetworkImage(String imageUrl) async {
    // Sử dụng màu cam cho network image
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
  }

  Future<BitmapDescriptor> _createMarkerFromLocalFile(String filePath) async {
    // Sử dụng màu tím cho local file
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
  }

  Future<BitmapDescriptor> _createMarkerFromDefaultAvatar(String email) async {
    // Sử dụng màu xanh lá cho default avatar
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  }

  Future<void> _createMyMarker() async {
    if (_currentPosition == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Kiểm tra trạng thái chia sẻ vị trí
    final sharingRef = FirebaseDatabase.instance.ref(
      'users/${user.uid}/isSharingLocation',
    );
    final sharingSnap = await sharingRef.get();
    
    // Chỉ tạo marker nếu đang chia sẻ vị trí
    if (sharingSnap.exists && sharingSnap.value == true) {
      final email = user.email ?? '';

      // Tạo custom marker với avatar
      final markerIcon = await _createCustomMarkerFromAvatar(_myAvatarUrl, email);

      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('me'),
            position: _currentPosition!,
            icon: markerIcon,
            infoWindow: InfoWindow(
              title: email.split('@')[0], 
              snippet: 'Bạn - ${_getAvatarType(_myAvatarUrl)}',
            ),
          ),
        };
      }
    } else {
      // Xóa marker nếu không chia sẻ vị trí
      setState(() {
        _markers = {};
      });
    }
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
          _createMyMarker();
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
      }
    } catch (e) {
      print('Error loading current route: $e');
    }
  }

  void _startRouteRecording() {
    if (_currentPosition == null) return;

    setState(() {
      _isRecordingRoute = true;
      _currentRoutePoints = [
        LocationPoint(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          timestamp: DateTime.now(),
        ),
      ];
    });

    // Bắt đầu ghi lại vị trí mỗi 10 giây
    _routeRecordingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _addLocationPoint();
    });
  }

  void _stopRouteRecording() async {
    _routeRecordingTimer?.cancel();

    if (_currentRoutePoints.length < 2) {
      setState(() {
        _isRecordingRoute = false;
        _currentRoutePoints = [];
      });
      return;
    }

    // Tạo route mới với tên đơn giản
    final routeName = _currentRoute?.name ?? 'Lộ trình ${DateTime.now().toString().substring(0, 16)}';
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
      const SnackBar(
        content: Text('Đã lưu lộ trình mới'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _addLocationPoint() async {
    if (_currentPosition == null) return;

    final point = LocationPoint(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      timestamp: DateTime.now(),
    );

    setState(() {
      _currentRoutePoints.add(point);
    });

    // Cập nhật current route nếu có
    if (_currentRoute != null) {
      _currentRoute = _locationHistoryService.createRoute(
        name: _currentRoute!.name,
        points: _currentRoutePoints,
        description: _currentRoute!.description,
      );
      await _locationHistoryService.saveCurrentRoute(_currentRoute!);
    } else {
      // Tạo current route mới nếu chưa có
      _currentRoute = _locationHistoryService.createRoute(
        name: 'Lộ trình đang ghi',
        points: _currentRoutePoints,
      );
      await _locationHistoryService.saveCurrentRoute(_currentRoute!);
    }
  }

  void _showLocationHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationHistoryPage()),
    );
  }
}
