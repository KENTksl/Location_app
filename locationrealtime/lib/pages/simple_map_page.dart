import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/location_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

class SimpleMapPage extends StatefulWidget {
  const SimpleMapPage({Key? key}) : super(key: key);

  @override
  State<SimpleMapPage> createState() => _SimpleMapPageState();
}

class _SimpleMapPageState extends State<SimpleMapPage> {
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();

  List<LocationModel> _locations = [];
  List<UserModel> _users = [];
  UserModel? _currentUser;

  bool _isTracking = false;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
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

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Lỗi khởi tạo: $e';
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

  void _onLocationUpdate(LocationModel location) {
    setState(() {
      // Cập nhật hoặc thêm vị trí mới
      final index = _locations.indexWhere((l) => l.userId == location.userId);
      if (index != -1) {
        _locations[index] = location;
      } else {
        _locations.add(location);
      }
    });
  }

  void _onLocationError(String error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
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
    setState(() => _isLoading = false);
  }

  Color _getStatusColor(String? status) {
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

  String _getStatusText(String? status) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theo dõi vị trí'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLocations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initializeData,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Header với thông tin hiện tại
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vị trí hiện tại',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            Text(
                              '${_locations.length} người đang chia sẻ vị trí',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _isTracking ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _isTracking ? 'Đang theo dõi' : 'Dừng theo dõi',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Danh sách vị trí
                Expanded(
                  child: _locations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_off,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Chưa có vị trí nào',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Bắt đầu chia sẻ vị trí để xem trên bản đồ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _locations.length,
                          itemBuilder: (context, index) {
                            final location = _locations[index];
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

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getStatusColor(
                                    location.status,
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  user.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      location.address ?? 'Không có địa chỉ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(
                                              location.status,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _getStatusText(location.status),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _getStatusColor(
                                              location.status,
                                            ),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          location.formattedSpeed,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Cập nhật: ${location.formattedTime}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'details':
                                        _showLocationDetails(location, user);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'details',
                                      child: Row(
                                        children: [
                                          Icon(Icons.info),
                                          SizedBox(width: 8),
                                          Text('Chi tiết'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
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
    );
  }

  void _showLocationDetails(LocationModel location, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getStatusColor(location.status),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(location.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(location.status),
                    style: TextStyle(
                      color: _getStatusColor(location.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Vị trí', location.address ?? 'Không có địa chỉ'),
            _buildDetailRow(
              'Tọa độ',
              '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
            ),
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
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Tính năng xem bản đồ sẽ có sẵn khi cấu hình Google Maps API',
                      ),
                    ),
                  );
                },
                child: const Text('Xem trên bản đồ'),
              ),
            ),
          ],
        ),
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

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}
