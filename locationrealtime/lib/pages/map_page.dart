import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/location_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  List<LocationModel> _locations = [];
  List<UserModel> _users = [];
  UserModel? _currentUser;

  CameraPosition? _initialCameraPosition;
  bool _isTracking = false;
  bool _isLoading = true;
  String _errorMessage = '';
  LocationModel? _pendingCameraLocation;

  // Camera position mặc định (Hồ Chí Minh)
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(10.7769, 106.7009), // Hồ Chí Minh
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      setState(() => _isLoading = true);

      // Luôn đặt mặc định là Hồ Chí Minh
      _initialCameraPosition = _defaultPosition;

      // Lấy thông tin người dùng hiện tại
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _currentUser = await _databaseService.getUser(user.uid);
      }

      // Thiết lập callback cho location service
      _locationService.onLocationUpdate = _onLocationUpdate;
      _locationService.onError = _onLocationError;

      // Chủ động lấy vị trí hiện tại của thiết bị và lưu vào database
      if (_currentUser != null) {
        await _locationService.getCurrentLocation(
          userId: _currentUser!.uid,
          userName: _currentUser!.displayName,
        );
      }

      // Lấy tất cả vị trí hiện tại
      await _loadCurrentLocations();

      // Lấy danh sách người dùng
      await _loadUsers();

      // Tìm vị trí hiện tại của user
      LocationModel? myLocation;
      if (_currentUser != null) {
        try {
          myLocation = _locations.firstWhere(
            (l) => l.userId == _currentUser!.uid,
          );
        } catch (_) {
          myLocation = null;
        }
        // Chỉ animate camera nếu vị trí hợp lệ (không phải 0,0)
        if (myLocation != null &&
            (myLocation.latitude.abs() > 0.0001 ||
                myLocation.longitude.abs() > 0.0001)) {
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(myLocation.latLng, 16.0),
            );
          } else {
            _pendingCameraLocation = myLocation;
          }
        }
      }

      // Tạo markers
      _createMarkers();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Lỗi khởi tạo bản đồ: $e';
      });
    }
  }

  Future<void> _loadCurrentLocations() async {
    try {
      _locations = await _databaseService.getAllCurrentLocations();
    } catch (e) {
      _errorMessage = 'Lỗi tải vị trí: $e';
    }
  }

  Future<void> _loadUsers() async {
    try {
      _users = await _databaseService.getAllUsers();
    } catch (e) {
      _errorMessage = 'Lỗi tải danh sách người dùng: $e';
    }
  }

  void _createMarkers() {
    _markers.clear();

    for (final location in _locations) {
      final user = _users.firstWhere(
        (u) => u.uid == location.userId,
        orElse: () => UserModel(
          uid: location.userId,
          email: '',
          displayName: location.userName,
          role: 'employee',
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        ),
      );

      // Nếu là user hiện tại, dùng icon khác biệt
      final isCurrentUser =
          _currentUser != null && location.userId == _currentUser!.uid;

      final marker = Marker(
        markerId: MarkerId(location.userId),
        position: location.latLng,
        infoWindow: InfoWindow(
          title: isCurrentUser ? 'Bạn' : user.displayName,
          snippet: location.address ?? 'Không có địa chỉ',
          onTap: () => _showLocationDetails(location, user),
        ),
        icon: isCurrentUser
            ? BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ) // màu xanh dương cho user hiện tại
            : _getMarkerIcon(location.status ?? 'online'),
        rotation: location.heading ?? 0.0,
        flat: true,
      );

      _markers.add(marker);
    }
  }

  BitmapDescriptor _getMarkerIcon(String status) {
    switch (status) {
      case 'online':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case 'moving':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case 'stopped':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueYellow,
        );
      case 'offline':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  void _onLocationUpdate(LocationModel location) {
    setState(() {
      // Cập nhật hoặc thêm vị trí mới
      final index = _locations.indexWhere((l) => l.userId == location.userId);
      if (index != -1) {
        _locations[index] = location;
      } else {
        _locations.add(location);
      }

      // Cập nhật markers
      _createMarkers();
    });
  }

  void _onLocationError(String error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
  }

  void _showLocationDetails(LocationModel location, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildLocationDetails(location, user),
    );
  }

  Widget _buildLocationDetails(LocationModel location, UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: _getStatusColor(location.status ?? 'online'),
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user.role,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    location.status ?? 'online',
                  ).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(location.status ?? 'online'),
                  style: TextStyle(
                    color: _getStatusColor(location.status ?? 'online'),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailRow('Vị trí', location.address ?? 'Không có địa chỉ'),
          _buildDetailRow('Tốc độ', location.formattedSpeed),
          _buildDetailRow('Độ chính xác', location.formattedAccuracy),
          _buildDetailRow('Cập nhật', location.formattedTime),
          if (location.speed != null && location.speed! > 0)
            _buildDetailRow(
              'Hướng',
              '${location.heading?.toStringAsFixed(0)}°',
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _centerOnLocation(location.latLng),
              child: const Text('Đi đến vị trí này'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online':
        return Colors.green;
      case 'moving':
        return Colors.blue;
      case 'stopped':
        return Colors.orange;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'online':
        return 'Trực tuyến';
      case 'moving':
        return 'Đang di chuyển';
      case 'stopped':
        return 'Đã dừng';
      case 'offline':
        return 'Ngoại tuyến';
      default:
        return 'Không xác định';
    }
  }

  void _centerOnLocation(LatLng position) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 15.0));
    Navigator.pop(context);
  }

  Future<void> _toggleTracking() async {
    if (_currentUser == null) return;

    if (_isTracking) {
      await _locationService.stopTracking();
      setState(() => _isTracking = false);
    } else {
      await _locationService.startTracking(
        userId: _currentUser!.uid,
        userName: _currentUser!.displayName,
      );
      setState(() => _isTracking = true);
    }
  }

  Future<void> _refreshLocations() async {
    setState(() => _isLoading = true);
    await _loadCurrentLocations();
    _createMarkers();
    setState(() => _isLoading = false);
  }

  void _goToMyLocation() async {
    if (_currentUser == null) return;
    setState(() => _isLoading = true);
    try {
      final location = await _locationService.getCurrentLocation(
        userId: _currentUser!.uid,
        userName: _currentUser!.displayName,
      );
      if (location != null) {
        // Cập nhật hoặc thêm vị trí mới vào danh sách
        final index = _locations.indexWhere((l) => l.userId == location.userId);
        if (index != -1) {
          _locations[index] = location;
        } else {
          _locations.add(location);
        }
        _createMarkers();
        // Di chuyển camera đến vị trí hiện tại
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(location.latLng, 16.0),
        );
      }
    } catch (e) {
      _errorMessage = 'Không thể lấy vị trí hiện tại: $e';
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ theo dõi'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLocations,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              if (_pendingCameraLocation != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(
                    _pendingCameraLocation!.latLng,
                    16.0,
                  ),
                );
                _pendingCameraLocation = null;
              }
            },
            initialCameraPosition: _initialCameraPosition ?? _defaultPosition,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onTap: (position) {
              // Ẩn bàn phím nếu có
              FocusScope.of(context).unfocus();
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
          if (_errorMessage.isNotEmpty)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          // Floating action buttons
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'myLocation',
                  onPressed: _goToMyLocation,
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'tracking',
                  onPressed: _toggleTracking,
                  backgroundColor: _isTracking ? Colors.red : Colors.blue,
                  child: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}
