import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/location_model.dart';
import 'database_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final DatabaseService _databaseService = DatabaseService();

  StreamSubscription<Position>? _locationSubscription;
  Timer? _locationTimer;
  bool _isTracking = false;

  // Callback để thông báo vị trí mới
  Function(LocationModel)? onLocationUpdate;
  Function(String)? onError;

  // ========== PERMISSION & SETUP ==========

  Future<bool> requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Kiểm tra dịch vụ vị trí có được bật không
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      onError?.call('Dịch vụ vị trí chưa được bật');
      return false;
    }

    // Kiểm tra quyền truy cập vị trí
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        onError?.call('Quyền truy cập vị trí bị từ chối');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      onError?.call('Quyền truy cập vị trí bị từ chối vĩnh viễn');
      return false;
    }

    return true;
  }

  // ========== LOCATION TRACKING ==========

  Future<void> startTracking({
    required String userId,
    required String userName,
    Duration interval = const Duration(seconds: 30),
    double distanceFilter = 10.0, // Cập nhật khi di chuyển ít nhất 10m
  }) async {
    if (_isTracking) {
      await stopTracking();
    }

    final hasPermission = await requestLocationPermission();
    if (!hasPermission) return;

    _isTracking = true;

    try {
      // Lấy vị trí hiện tại ngay lập tức
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _processLocation(currentPosition, userId, userName);

      // Bắt đầu theo dõi vị trí
      _locationSubscription =
          Geolocator.getPositionStream(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: distanceFilter.toInt(),
              timeLimit: Duration(seconds: 30),
            ),
          ).listen(
            (Position position) async {
              await _processLocation(position, userId, userName);
            },
            onError: (error) {
              onError?.call('Lỗi theo dõi vị trí: $error');
            },
          );

      // Timer để đảm bảo cập nhật định kỳ
      _locationTimer = Timer.periodic(interval, (timer) async {
        if (_isTracking) {
          try {
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
            await _processLocation(position, userId, userName);
          } catch (e) {
            onError?.call('Lỗi cập nhật vị trí: $e');
          }
        }
      });
    } catch (e) {
      _isTracking = false;
      onError?.call('Lỗi bắt đầu theo dõi: $e');
    }
  }

  Future<void> stopTracking() async {
    _isTracking = false;

    await _locationSubscription?.cancel();
    _locationSubscription = null;

    _locationTimer?.cancel();
    _locationTimer = null;
  }

  Future<void> _processLocation(
    Position position,
    String userId,
    String userName,
  ) async {
    try {
      // Lấy địa chỉ từ tọa độ
      String? address;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          address =
              [
                    placemark.street,
                    placemark.subLocality,
                    placemark.locality,
                    placemark.administrativeArea,
                  ]
                  .where((element) => element != null && element.isNotEmpty)
                  .join(', ');
        }
      } catch (e) {
        // Bỏ qua lỗi geocoding
      }

      // Xác định trạng thái di chuyển
      String status = 'online';
      if (position.speed > 1.0) {
        status = 'moving';
      } else if (position.speed < 0.5) {
        status = 'stopped';
      }

      // Tạo model vị trí
      final location = LocationModel(
        id: '',
        userId: userId,
        userName: userName,
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
        speed: position.speed * 3.6, // Chuyển từ m/s sang km/h
        heading: position.heading,
        timestamp: DateTime.now(),
        address: address,
        status: status,
        metadata: {'timestamp': position.timestamp.toIso8601String()},
      );

      // Lưu vào database
      await _databaseService.saveLocation(location);

      // Thông báo vị trí mới
      onLocationUpdate?.call(location);
    } catch (e) {
      onError?.call('Lỗi xử lý vị trí: $e');
    }
  }

  // ========== SINGLE LOCATION REQUEST ==========

  Future<LocationModel?> getCurrentLocation({
    required String userId,
    required String userName,
  }) async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Lấy địa chỉ
      String? address;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          address =
              [
                    placemark.street,
                    placemark.subLocality,
                    placemark.locality,
                    placemark.administrativeArea,
                  ]
                  .where((element) => element != null && element.isNotEmpty)
                  .join(', ');
        }
      } catch (e) {
        // Bỏ qua lỗi geocoding
      }

      final location = LocationModel(
        id: '',
        userId: userId,
        userName: userName,
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        accuracy: position.accuracy,
        speed: position.speed * 3.6,
        heading: position.heading,
        timestamp: DateTime.now(),
        address: address,
        status: 'online',
        metadata: {'timestamp': position.timestamp.toIso8601String()},
      );

      await _databaseService.saveLocation(location);
      return location;
    } catch (e) {
      onError?.call('Lỗi lấy vị trí hiện tại: $e');
      return null;
    }
  }

  // ========== UTILITY METHODS ==========

  bool get isTracking => _isTracking;

  Future<double> calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return [
          placemark.street,
          placemark.subLocality,
          placemark.locality,
          placemark.administrativeArea,
        ].where((element) => element != null && element.isNotEmpty).join(', ');
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Location?> getCoordinatesFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return locations.first;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ========== CLEANUP ==========

  void dispose() {
    stopTracking();
  }
}
