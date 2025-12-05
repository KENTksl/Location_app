import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_history.dart';

class LocationHistoryService {
  static const String _routesKey = 'location_routes';
  static const String _currentRouteKey = 'current_route';
  static const String _statsKey = 'location_stats';
  static const String _retentionDaysKey = 'route_retention_days';

  // Validation constants
  static const double _minDistance = 1.0; // 1 meter minimum
  static const Duration _minDuration = Duration(
    seconds: 3,
  ); // 3 seconds minimum

  final FirebaseDatabase _database;
  final FirebaseAuth _auth;

  LocationHistoryService({FirebaseAuth? auth, FirebaseDatabase? database})
      : _auth = auth ?? FirebaseAuth.instance,
        _database = database ?? FirebaseDatabase.instance;

  // Thiết lập số ngày giữ lại lộ trình (null để tắt tự xóa)
  Future<void> setRetentionDays(int? days) async {
    final prefs = await SharedPreferences.getInstance();
    if (days == null) {
      await prefs.remove(_retentionDaysKey);
    } else {
      await prefs.setInt(_retentionDaysKey, days);
    }
  }

  // Lấy số ngày giữ lại hiện tại (null nếu chưa cài đặt)
  Future<int?> getRetentionDays() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_retentionDaysKey)) return null;
    return prefs.getInt(_retentionDaysKey);
  }

  // Lưu route vào local storage
  Future<void> saveRouteLocally(LocationRoute route) async {
    final prefs = await SharedPreferences.getInstance();
    final routesJson = prefs.getStringList(_routesKey) ?? [];

    // Thêm route mới
    routesJson.add(jsonEncode(route.toJson()));

    // Giữ tối đa 50 routes gần nhất
    if (routesJson.length > 50) {
      routesJson.removeAt(0);
    }

    await prefs.setStringList(_routesKey, routesJson);
    // Áp dụng retention sau khi lưu
    await purgeOldRoutes();
  }

  // Lấy tất cả routes từ local storage
  Future<List<LocationRoute>> getRoutesLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final routesJson = prefs.getStringList(_routesKey) ?? [];

    return routesJson
        .map((json) => LocationRoute.fromJson(jsonDecode(json)))
        .toList();
  }

  // Tự động xóa các lộ trình quá hạn theo retention (local + Firebase)
  Future<void> purgeOldRoutes({int? days}) async {
    final effectiveDays = days ?? await getRetentionDays();
    if (effectiveDays == null || effectiveDays <= 0) return;

    final cutoff = DateTime.now().subtract(Duration(days: effectiveDays));

    // Purge local
    final prefs = await SharedPreferences.getInstance();
    final routesJson = prefs.getStringList(_routesKey) ?? [];
    final filtered = <String>[];
    for (final jsonStr in routesJson) {
      try {
        final route = LocationRoute.fromJson(jsonDecode(jsonStr));
        final endOrStart = route.endTime ?? route.startTime;
        if (endOrStart.isAfter(cutoff)) {
          filtered.add(jsonStr);
        }
      } catch (_) {
        // Nếu parse lỗi, giữ lại để tránh mất dữ liệu ngoài ý muốn
        filtered.add(jsonStr);
      }
    }
    await prefs.setStringList(_routesKey, filtered);

    // Purge Firebase
    final user = _auth.currentUser;
    if (user != null) {
      final ref = _database.ref('users/${user.uid}/locationHistory');
      final snap = await ref.get();
      if (snap.exists) {
        for (final child in snap.children) {
          try {
            final data = Map<String, dynamic>.from(child.value as Map);
            final route = LocationRoute.fromJson(data);
            final endOrStart = route.endTime ?? route.startTime;
            if (endOrStart.isBefore(cutoff)) {
              final key = child.key;
              if (key != null) {
                await ref.child(key).remove();
              }
            }
          } catch (e) {
            // Bỏ qua lỗi parse
          }
        }
      }
    }
  }

  // Lưu route vào Firebase
  Future<void> saveRouteToFirebase(LocationRoute route) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _database
        .ref('users/${user.uid}/locationHistory/${route.id}')
        .set(route.toJson());
  }

  // Lấy routes từ Firebase (kèm fallback legacy)
  Future<List<LocationRoute>> getRoutesFromFirebase() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    // Primary path
    final primaryRef = _database.ref('users/${user.uid}/locationHistory');
    final primarySnap = await primaryRef.get();

    List<LocationRoute> routes = [];
    if (primarySnap.exists) {
      for (final child in primarySnap.children) {
        try {
          final route = LocationRoute.fromJson(
            Map<String, dynamic>.from(child.value as Map),
          );
          routes.add(route);
        } catch (e) {
          print('Error parsing route (primary): $e');
        }
      }
    }

    // Fallback to legacy path if primary empty
    if (routes.isEmpty) {
      final legacyRef = _database.ref('history/${user.uid}');
      final legacySnap = await legacyRef.get();
      if (legacySnap.exists) {
        for (final child in legacySnap.children) {
          try {
            final route = LocationRoute.fromJson(
              Map<String, dynamic>.from(child.value as Map),
            );
            routes.add(route);
          } catch (e) {
            print('Error parsing route (legacy): $e');
          }
        }
      }
    }

    return routes;
  }

  // Kiểm tra permission và service
  Future<bool> checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  // Tính khoảng cách giữa 2 điểm
  double _distanceBetween(LocationPoint a, LocationPoint b) {
    const double earthRadius = 6371e3; // meters
    const double deg2rad = 3.141592653589793 / 180.0;
    final double lat1 = a.latitude * deg2rad;
    final double lat2 = b.latitude * deg2rad;
    final double dLat = (b.latitude - a.latitude) * deg2rad;
    final double dLon = (b.longitude - a.longitude) * deg2rad;

    final double sinDLat = sin(dLat / 2);
    final double sinDLon = sin(dLon / 2);
    double h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon;
    h = h.clamp(0.0, 1.0);
    final double c = 2 * asin(sqrt(h));
    return earthRadius * c / 1000; // km
  }

  // Tính tổng khoảng cách của route
  double calculateTotalDistance(List<LocationPoint> points) {
    if (points.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += _distanceBetween(points[i - 1], points[i]);
    }
    return total;
  }

  // Hàm công khai tính khoảng cách giữa hai điểm (km)
  double calculateDistance(LocationPoint point1, LocationPoint point2) {
    return _distanceBetween(point1, point2);
  }

  // Kiểm tra route có hợp lệ không
  bool isValidRoute(List<LocationPoint> points) {
    if (points.length < 2) return false;
    final totalDistance = calculateTotalDistance(points);
    final totalDuration = points.last.timestamp.difference(points.first.timestamp);
    // totalDistance is in km; _minDistance is in meters
    return totalDistance >= (_minDistance / 1000) && totalDuration >= _minDuration;
  }

  // Tạo route mới
  LocationRoute createRoute({
    required String name,
    required List<LocationPoint> points,
    String? description,
  }) {
    final startTime = points.first.timestamp;
    final endTime = points.last.timestamp;
    final totalDistance = calculateTotalDistance(points);
    final totalDuration = endTime.difference(startTime);

    return LocationRoute(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      points: points,
      startTime: startTime,
      endTime: endTime,
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      description: description,
    );
  }

  // Lấy vị trí hiện tại với error handling
  Future<LocationPoint?> getCurrentLocationPoint() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return LocationPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
        accuracy: position.accuracy,
        speed: position.speed,
        altitude: position.altitude,
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  // Kiểm tra có nên thêm điểm mới vào route không
  bool shouldAddPoint(
    LocationPoint newPoint,
    List<LocationPoint> existingPoints,
  ) {
    if (existingPoints.isEmpty) return true;

    final lastPoint = existingPoints.last;
    final distanceKm = _distanceBetween(lastPoint, newPoint);
    final timeDiff = newPoint.timestamp.difference(lastPoint.timestamp);

    // Thêm nếu khoảng cách > 1m (0.001 km) hoặc thời gian > 10s
    return distanceKm > (_minDistance / 1000) || timeDiff.inSeconds > 10;
  }

  // Lưu current route
  Future<void> saveCurrentRoute(LocationRoute route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentRouteKey, jsonEncode(route.toJson()));
  }

  // Lấy current route
  Future<LocationRoute?> getCurrentRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final routeJson = prefs.getString(_currentRouteKey);
    if (routeJson == null) return null;

    try {
      return LocationRoute.fromJson(jsonDecode(routeJson));
    } catch (e) {
      print('Error parsing current route: $e');
      return null;
    }
  }

  // Xóa current route
  Future<void> clearCurrentRoute() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentRouteKey);
  }

  // Lưu thống kê
  Future<void> saveStats(LocationHistoryStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, jsonEncode(stats.toJson()));
  }

  // Lấy thống kê
  Future<LocationHistoryStats?> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    final statsJson = prefs.getString(_statsKey);
    if (statsJson == null) return null;

    try {
      return LocationHistoryStats.fromJson(jsonDecode(statsJson));
    } catch (e) {
      print('Error parsing stats: $e');
      return null;
    }
  }

  // Tính toán stats
  LocationHistoryStats calculateStats(List<LocationRoute> routes) {
    if (routes.isEmpty) {
      return LocationHistoryStats(
        totalRoutes: 0,
        totalDistance: 0,
        totalDuration: Duration.zero,
        averageSpeed: 0,
        dailyStats: {},
      );
    }

    double totalDistance = 0;
    Duration totalDuration = Duration.zero;
    final dailyStats = <String, int>{};
    DateTime? lastActivity;

    for (final route in routes) {
      totalDistance += route.totalDistance;
      totalDuration += route.totalDuration;

      final dateKey = route.startTime.toIso8601String().split('T')[0];
      dailyStats[dateKey] = (dailyStats[dateKey] ?? 0) + 1;

      if (lastActivity == null || route.startTime.isAfter(lastActivity)) {
        lastActivity = route.startTime;
      }
    }

    final averageSpeed = totalDuration.inSeconds > 0
        ? totalDistance / (totalDuration.inSeconds / 3600)
        : 0;

    return LocationHistoryStats(
      totalRoutes: routes.length,
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      averageSpeed: averageSpeed.toDouble(),
      lastActivity: lastActivity,
      dailyStats: dailyStats,
    );
  }

  // Tạo tên route tự động
  String generateRouteName(LocationRoute route) {
    final startTime = route.startTime;
    final hour = startTime.hour;

    if (hour >= 6 && hour < 12) {
      return 'Buổi sáng ${startTime.day}/${startTime.month}';
    } else if (hour >= 12 && hour < 18) {
      return 'Buổi chiều ${startTime.day}/${startTime.month}';
    } else {
      return 'Buổi tối ${startTime.day}/${startTime.month}';
    }
  }

  // Lọc routes theo thời gian
  List<LocationRoute> filterRoutesByDate(
    List<LocationRoute> routes,
    DateTime startDate,
    DateTime endDate,
  ) {
    return routes.where((route) {
      return route.startTime.isAfter(startDate) &&
          route.startTime.isBefore(endDate);
    }).toList();
  }

  // Lọc routes theo khoảng cách
  List<LocationRoute> filterRoutesByDistance(
    List<LocationRoute> routes,
    double minDistance,
    double maxDistance,
  ) {
    return routes.where((route) {
      return route.totalDistance >= minDistance &&
          route.totalDistance <= maxDistance;
    }).toList();
  }

  // Xóa route
  Future<void> deleteRoute(String routeId) async {
    // Xóa từ local storage
    final prefs = await SharedPreferences.getInstance();
    final routesJson = prefs.getStringList(_routesKey) ?? [];
    routesJson.removeWhere((json) {
      try {
        final route = LocationRoute.fromJson(jsonDecode(json));
        return route.id == routeId;
      } catch (e) {
        return false;
      }
    });
    await prefs.setStringList(_routesKey, routesJson);

    // Xóa từ Firebase
    final user = _auth.currentUser;
    if (user != null) {
      await _database
          .ref('users/${user.uid}/locationHistory/$routeId')
          .remove();
    }
  }

  // Đổi tên route
  Future<void> renameRoute(String routeId, String newName) async {
    // Cập nhật ở local storage
    final prefs = await SharedPreferences.getInstance();
    final routesJson = prefs.getStringList(_routesKey) ?? [];
    final updated = <String>[];
    for (final jsonStr in routesJson) {
      try {
        final route = LocationRoute.fromJson(jsonDecode(jsonStr));
        if (route.id == routeId) {
          final renamed = LocationRoute(
            id: route.id,
            name: newName,
            points: route.points,
            startTime: route.startTime,
            endTime: route.endTime,
            totalDistance: route.totalDistance,
            totalDuration: route.totalDuration,
            description: route.description,
            metadata: route.metadata,
          );
          updated.add(jsonEncode(renamed.toJson()));
        } else {
          updated.add(jsonStr);
        }
      } catch (_) {
        updated.add(jsonStr);
      }
    }
    await prefs.setStringList(_routesKey, updated);

    // Cập nhật ở Firebase (chỉ cập nhật field name)
    final user = _auth.currentUser;
    if (user != null) {
      await _database
          .ref('users/${user.uid}/locationHistory/$routeId')
          .update({'name': newName});
    }
  }

  // Export route data
  Map<String, dynamic> exportRouteData(LocationRoute route) {
    return {
      'route': route.toJson(),
      'exportedAt': DateTime.now().toIso8601String(),
      'version': '1.0',
    };
  }

  // Import route data
  LocationRoute? importRouteData(Map<String, dynamic> data) {
    try {
      final routeData = data['route'] as Map<String, dynamic>;
      return LocationRoute.fromJson(routeData);
    } catch (e) {
      print('Error importing route data: $e');
      return null;
    }
  }
}
