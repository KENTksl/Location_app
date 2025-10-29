import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BackgroundLocationService {
  static const MethodChannel _channel = MethodChannel('background_location');
  
  static BackgroundLocationService? _instance;
  static BackgroundLocationService get instance => _instance ??= BackgroundLocationService._();
  
  BackgroundLocationService._();
  
  StreamSubscription<Position>? _locationSubscription;
  Timer? _backgroundTimer;
  bool _isRunning = false;
  
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Bắt đầu background location tracking
  Future<bool> startBackgroundLocationTracking() async {
    if (_isRunning) return true;
    
    try {
      // Kiểm tra permissions
      final permission = await _checkLocationPermissions();
      if (!permission) {
        print('Background location permission denied');
        return false;
      }
      
      // Bắt đầu foreground service trên Android
      if (Platform.isAndroid) {
        await _startForegroundService();
      }
      
      // Bắt đầu location tracking
      await _startLocationTracking();
      
      _isRunning = true;
      print('Background location tracking started');
      return true;
    } catch (e) {
      print('Error starting background location tracking: $e');
      return false;
    }
  }
  
  /// Dừng background location tracking
  Future<void> stopBackgroundLocationTracking() async {
    if (!_isRunning) return;
    
    try {
      // Dừng location tracking
      await _locationSubscription?.cancel();
      _backgroundTimer?.cancel();
      
      // Dừng foreground service trên Android
      if (Platform.isAndroid) {
        await _stopForegroundService();
      }
      
      _isRunning = false;
      print('Background location tracking stopped');
    } catch (e) {
      print('Error stopping background location tracking: $e');
    }
  }
  
  /// Kiểm tra và yêu cầu permissions
  Future<bool> _checkLocationPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied');
      return false;
    }
    
    // Yêu cầu background location permission
    if (permission == LocationPermission.whileInUse) {
      // Trên Android 10+, cần yêu cầu background location riêng
      if (Platform.isAndroid) {
        try {
          await Geolocator.requestPermission();
        } catch (e) {
          print('Error requesting background location permission: $e');
        }
      }
    }
    
    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }
  
  /// Bắt đầu location tracking
  Future<void> _startLocationTracking() async {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Cập nhật khi di chuyển 10 mét
      timeLimit: Duration(seconds: 30),
    );
    
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) async {
        await _updateLocationToFirebase(position);
      },
      onError: (error) {
        print('Location stream error: $error');
        // Fallback to periodic updates
        _startPeriodicLocationUpdates();
      },
    );
    
    // Backup timer để đảm bảo location được cập nhật
    _backgroundTimer = Timer.periodic(
      const Duration(minutes: 1),
      (timer) async {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 15),
          );
          await _updateLocationToFirebase(position);
        } catch (e) {
          print('Error getting periodic location: $e');
        }
      },
    );
  }
  
  /// Fallback periodic location updates
  void _startPeriodicLocationUpdates() {
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 15),
          );
          await _updateLocationToFirebase(position);
        } catch (e) {
          print('Error in periodic location update: $e');
        }
      },
    );
  }
  
  /// Cập nhật location lên Firebase
  Future<void> _updateLocationToFirebase(Position position) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      await _database.ref('users/${user.uid}/location').set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'isOnline': true,
        'isSharingLocation': true,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'altitude': position.altitude,
        'timestamp': position.timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      });
      
      print('Background location updated: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Error updating location to Firebase: $e');
    }
  }
  
  /// Bắt đầu foreground service (Android)
  Future<void> _startForegroundService() async {
    try {
      await _channel.invokeMethod('startForegroundService', {
        'title': 'Chia sẻ vị trí',
        'content': 'Ứng dụng đang theo dõi vị trí của bạn',
        'icon': 'ic_location',
      });
    } on PlatformException catch (e) {
      print('Error starting foreground service: $e');
    }
  }
  
  /// Dừng foreground service (Android)
  Future<void> _stopForegroundService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } on PlatformException catch (e) {
      print('Error stopping foreground service: $e');
    }
  }
  
  /// Kiểm tra trạng thái service
  bool get isRunning => _isRunning;
  
  /// Dispose resources
  void dispose() {
    _locationSubscription?.cancel();
    _backgroundTimer?.cancel();
    _isRunning = false;
  }
}