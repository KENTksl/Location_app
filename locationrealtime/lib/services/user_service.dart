import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user.dart' as app_user;
import 'geolocator_wrapper.dart';

class UserService {
  final auth.FirebaseAuth _auth;
  final FirebaseDatabase _database;

  final GeolocatorWrapper _geolocator;

  // Constructor with dependency injection for better testability
  UserService({
    auth.FirebaseAuth? firebaseAuth,
    FirebaseDatabase? database,
    GeolocatorWrapper? geolocator,
  }) : _auth = firebaseAuth ?? auth.FirebaseAuth.instance,
       _database = database ?? FirebaseDatabase.instance,
       _geolocator = geolocator ?? GeolocatorWrapperImpl();

  // Lấy thông tin user hiện tại
  app_user.User? getCurrentUser() {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    return app_user.User(id: firebaseUser.uid, email: firebaseUser.email ?? '');
  }

  // Lấy thông tin user từ Firebase
  Future<app_user.User?> getUserById(String userId) async {
    try {
      final snapshot = await _database.ref('users/$userId').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        return app_user.User.fromJson({'id': userId, ...data});
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // Cập nhật thông tin user
  Future<void> updateUser(app_user.User user) async {
    try {
      await _database.ref('users/${user.id}').update(user.toJson());
    } catch (e) {
      print('Error updating user: $e');
    }
  }

  // Lưu user mới
  Future<void> saveUser(app_user.User user) async {
    try {
      await _database.ref('users/${user.id}').set(user.toJson());
    } catch (e) {
      print('Error saving user: $e');
    }
  }

  // Cập nhật avatar
  Future<void> updateAvatar(String userId, String avatarUrl) async {
    try {
      await _database.ref('users/$userId/avatarUrl').set(avatarUrl);
    } catch (e) {
      print('Error updating avatar: $e');
    }
  }

  // Cập nhật trạng thái chia sẻ vị trí
  Future<void> updateLocationSharing(String userId, bool isSharing) async {
    try {
      await _database.ref('users/$userId/isSharingLocation').set(isSharing);
    } catch (e) {
      print('Error updating location sharing: $e');
    }
  }

  // Cập nhật cài đặt luôn chia sẻ vị trí
  Future<void> updateAlwaysShareLocation(
    String userId,
    bool alwaysShare,
  ) async {
    try {
      await _database.ref('users/$userId/alwaysShareLocation').set(alwaysShare);
    } catch (e) {
      print('Error updating always share location: $e');
    }
  }

  // Cập nhật vị trí hiện tại
  Future<void> updateCurrentLocation(
    String userId,
    double latitude,
    double longitude,
  ) async {
    try {
      await _database.ref('users/$userId/location').set({
        'latitude': latitude,
        'longitude': longitude,
        'isOnline': true,
        'isSharingLocation': true,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  // Kiểm tra quyền vị trí
  Future<bool> checkLocationPermission() async {
    try {
      final permission = await _geolocator.checkPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      print('Error checking location permission: $e');
      return false;
    }
  }

  // Yêu cầu quyền vị trí
  Future<bool> requestLocationPermission() async {
    try {
      final permission = await _geolocator.requestPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }

  // Lấy vị trí hiện tại
  Future<Map<String, double>?> getCurrentLocation() async {
    try {
      final position = await _geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return {'latitude': position.latitude, 'longitude': position.longitude};
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  // Lắng nghe thay đổi avatar
  Stream<String?> listenToAvatarChanges(String userId) {
    return _database.ref('users/$userId/avatarUrl').onValue.map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as String?;
      }
      return null;
    });
  }

  // Lắng nghe thay đổi trạng thái chia sẻ vị trí
  Stream<bool> listenToLocationSharingChanges(String userId) {
    return _database.ref('users/$userId/isSharingLocation').onValue.map((
      event,
    ) {
      if (event.snapshot.exists) {
        return event.snapshot.value as bool? ?? false;
      }
      return false;
    });
  }
}
