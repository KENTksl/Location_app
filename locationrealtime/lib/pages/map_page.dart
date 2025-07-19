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

  bool _isTracking = false;
  bool _isLoading = true;
  String _errorMessage = '';

  // Camera position mặc định (Hà Nội)
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(21.0285, 105.8542),
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

      // Lấy thông tin người dùng hiện tại
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _currentUser = await _databaseService.getUser(user.uid);
      }

      // Thiết lập callback cho location service
      _locationService.onLocationUpdate = _onLocationUpdate;
      _locationService.onError = _onLocationError;

      // Lấy tất cả vị trí hiện tại
      await _loadCurrentLocations();

      // Lấy danh sách người dùng
      await _loadUsers();

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

      final marker = Marker(
        markerId: MarkerId(location.userId),
        position: location.latLng,
        infoWindow: InfoWindow(
          title: user.displayName,
          snippet: location.address ?? 'Không có địa chỉ',
          onTap: () => _showLocationDetails(location, user),
        ),
        icon: _getMarkerIcon(location.status ?? 'online'),
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
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: _defaultPosition,
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
                  onPressed: () {
                    if (_currentUser != null) {
                      _locationService.getCurrentLocation(
                        userId: _currentUser!.uid,
                        userName: _currentUser!.displayName,
                      );
                    }
                  },
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
