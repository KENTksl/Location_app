import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';
import '../models/location_model.dart';
import '../models/device_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Users collection
  DatabaseReference get usersRef => _database.child('users');
  DatabaseReference userRef(String uid) => usersRef.child(uid);

  // Locations collection
  DatabaseReference get locationsRef => _database.child('locations');
  DatabaseReference locationRef(String id) => locationsRef.child(id);
  DatabaseReference userLocationRef(String userId) =>
      locationsRef.child('users').child(userId);

  // Devices collection
  DatabaseReference get devicesRef => _database.child('devices');
  DatabaseReference deviceRef(String id) => devicesRef.child(id);
  DatabaseReference deviceLocationRef(String deviceId) =>
      locationsRef.child('devices').child(deviceId);

  // History collection
  DatabaseReference get historyRef => _database.child('history');
  DatabaseReference userHistoryRef(String userId) =>
      historyRef.child('users').child(userId);
  DatabaseReference deviceHistoryRef(String deviceId) =>
      historyRef.child('devices').child(deviceId);

  // Online status collection
  DatabaseReference get onlineStatusRef => _database.child('online_status');

  // ========== USER OPERATIONS ==========

  Future<void> createUser(UserModel user) async {
    try {
      await userRef(user.uid).set(user.toMap());
    } catch (e) {
      throw Exception('Lỗi tạo người dùng: $e');
    }
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final snapshot = await userRef(uid).get();
      if (snapshot.exists) {
        return UserModel.fromMap(
          Map<String, dynamic>.from(snapshot.value as Map),
        );
      }
      return null;
    } catch (e) {
      throw Exception('Lỗi lấy thông tin người dùng: $e');
    }
  }

  Future<void> updateUser(UserModel user) async {
    try {
      await userRef(user.uid).update(user.toMap());
    } catch (e) {
      throw Exception('Lỗi cập nhật người dùng: $e');
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot = await usersRef.get();
      final List<UserModel> users = [];

      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map;
        data.forEach((key, value) {
          users.add(UserModel.fromMap(Map<String, dynamic>.from(value)));
        });
      }

      return users;
    } catch (e) {
      throw Exception('Lỗi lấy danh sách người dùng: $e');
    }
  }

  // ========== LOCATION OPERATIONS ==========

  Future<void> saveLocation(LocationModel location) async {
    try {
      final locationId = location.id.isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : location.id;
      final locationWithId = location.copyWith(id: locationId);

      // Lưu vị trí hiện tại
      await userLocationRef(location.userId).set(locationWithId.toMap());

      // Lưu vào lịch sử
      await userHistoryRef(
        location.userId,
      ).child(locationId).set(locationWithId.toMap());

      // Cập nhật trạng thái online
      await onlineStatusRef.child(location.userId).set({
        'isOnline': true,
        'lastSeenAt': DateTime.now().toIso8601String(),
        'locationId': locationId,
      });
    } catch (e) {
      throw Exception('Lỗi lưu vị trí: $e');
    }
  }

  Future<LocationModel?> getCurrentLocation(String userId) async {
    try {
      final snapshot = await userLocationRef(userId).get();
      if (snapshot.exists) {
        return LocationModel.fromMap(
          Map<String, dynamic>.from(snapshot.value as Map),
        );
      }
      return null;
    } catch (e) {
      throw Exception('Lỗi lấy vị trí hiện tại: $e');
    }
  }

  Future<List<LocationModel>> getLocationHistory(
    String userId, {
    int limit = 100,
  }) async {
    try {
      final snapshot = await userHistoryRef(
        userId,
      ).orderByChild('timestamp').limitToLast(limit).get();

      final List<LocationModel> locations = [];

      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map;
        data.forEach((key, value) {
          locations.add(
            LocationModel.fromMap(Map<String, dynamic>.from(value)),
          );
        });
      }

      // Sắp xếp theo thời gian mới nhất
      locations.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return locations;
    } catch (e) {
      throw Exception('Lỗi lấy lịch sử vị trí: $e');
    }
  }

  Future<List<LocationModel>> getAllCurrentLocations() async {
    try {
      final snapshot = await locationsRef.child('users').get();
      final List<LocationModel> locations = [];

      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map;
        data.forEach((userId, value) {
          if (value != null) {
            locations.add(
              LocationModel.fromMap(Map<String, dynamic>.from(value)),
            );
          }
        });
      }

      return locations;
    } catch (e) {
      throw Exception('Lỗi lấy tất cả vị trí hiện tại: $e');
    }
  }

  // ========== DEVICE OPERATIONS ==========

  Future<void> createDevice(DeviceModel device) async {
    try {
      final deviceId = device.id.isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : device.id;
      final deviceWithId = device.copyWith(id: deviceId);

      await deviceRef(deviceId).set(deviceWithId.toMap());
    } catch (e) {
      throw Exception('Lỗi tạo thiết bị: $e');
    }
  }

  Future<DeviceModel?> getDevice(String deviceId) async {
    try {
      final snapshot = await deviceRef(deviceId).get();
      if (snapshot.exists) {
        return DeviceModel.fromMap(
          Map<String, dynamic>.from(snapshot.value as Map),
        );
      }
      return null;
    } catch (e) {
      throw Exception('Lỗi lấy thông tin thiết bị: $e');
    }
  }

  Future<void> updateDevice(DeviceModel device) async {
    try {
      await deviceRef(device.id).update(device.toMap());
    } catch (e) {
      throw Exception('Lỗi cập nhật thiết bị: $e');
    }
  }

  Future<List<DeviceModel>> getAllDevices() async {
    try {
      final snapshot = await devicesRef.get();
      final List<DeviceModel> devices = [];

      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map;
        data.forEach((key, value) {
          devices.add(DeviceModel.fromMap(Map<String, dynamic>.from(value)));
        });
      }

      return devices;
    } catch (e) {
      throw Exception('Lỗi lấy danh sách thiết bị: $e');
    }
  }

  Future<void> assignDeviceToUser(
    String deviceId,
    String userId,
    String userName,
  ) async {
    try {
      await deviceRef(deviceId).update({
        'assignedUserId': userId,
        'assignedUserName': userName,
        'lastSeenAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Lỗi gán thiết bị: $e');
    }
  }

  // ========== REAL-TIME LISTENERS ==========

  Stream<LocationModel?> watchUserLocation(String userId) {
    return userLocationRef(userId).onValue.map((event) {
      if (event.snapshot.exists) {
        return LocationModel.fromMap(
          Map<String, dynamic>.from(event.snapshot.value as Map),
        );
      }
      return null;
    });
  }

  Stream<List<LocationModel>> watchAllLocations() {
    return locationsRef.child('users').onValue.map((event) {
      final List<LocationModel> locations = [];

      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map;
        data.forEach((userId, value) {
          if (value != null) {
            locations.add(
              LocationModel.fromMap(Map<String, dynamic>.from(value)),
            );
          }
        });
      }

      return locations;
    });
  }

  Stream<List<DeviceModel>> watchAllDevices() {
    return devicesRef.onValue.map((event) {
      final List<DeviceModel> devices = [];

      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map;
        data.forEach((key, value) {
          devices.add(DeviceModel.fromMap(Map<String, dynamic>.from(value)));
        });
      }

      return devices;
    });
  }

  // ========== UTILITY METHODS ==========

  Future<void> setUserOffline(String userId) async {
    try {
      await onlineStatusRef.child(userId).update({
        'isOnline': false,
        'lastSeenAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Lỗi cập nhật trạng thái offline: $e');
    }
  }

  Future<Map<String, bool>> getOnlineStatus() async {
    try {
      final snapshot = await onlineStatusRef.get();
      final Map<String, bool> status = {};

      if (snapshot.exists) {
        final Map<dynamic, dynamic> data = snapshot.value as Map;
        data.forEach((userId, value) {
          if (value != null) {
            final userData = Map<String, dynamic>.from(value);
            status[userId.toString()] = userData['isOnline'] ?? false;
          }
        });
      }

      return status;
    } catch (e) {
      throw Exception('Lỗi lấy trạng thái online: $e');
    }
  }

  Future<void> deleteUser(String uid) async {
    try {
      // Xóa user
      await userRef(uid).remove();

      // Xóa vị trí hiện tại
      await userLocationRef(uid).remove();

      // Xóa lịch sử
      await userHistoryRef(uid).remove();

      // Xóa trạng thái online
      await onlineStatusRef.child(uid).remove();

      // Cập nhật thiết bị được gán
      final devices = await getAllDevices();
      for (final device in devices) {
        if (device.assignedUserId == uid) {
          await deviceRef(
            device.id,
          ).update({'assignedUserId': null, 'assignedUserName': null});
        }
      }
    } catch (e) {
      throw Exception('Lỗi xóa người dùng: $e');
    }
  }
}
