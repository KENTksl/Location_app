import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_history.dart';

class LocationHistoryService {
  static const String _routesKey = 'location_routes';
  static const String _currentRouteKey = 'current_route';
  static const String _statsKey = 'location_stats';

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Lưu route vào local storage
  Future<void> saveRouteLocally(LocationRoute route) async {
    final prefs = await SharedPreferences.getInstance();
    final routesJson = prefs.getStringList(_routesKey) ?? [];

    // Thêm route mới
    routesJson.add(jsonEncode(route.toJson()));

    // Giữ tối đa 100 routes gần nhất
    if (routesJson.length > 100) {
      routesJson.removeAt(0);
    }

    await prefs.setStringList(_routesKey, routesJson);
  }

  // Lấy tất cả routes từ local storage
  Future<List<LocationRoute>> getRoutesLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final routesJson = prefs.getStringList(_routesKey) ?? [];

    return routesJson
        .map((json) => LocationRoute.fromJson(jsonDecode(json)))
        .toList();
  }

  // Lưu route vào Firebase
  Future<void> saveRouteToFirebase(LocationRoute route) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _database
        .ref('users/${user.uid}/locationHistory/${route.id}')
        .set(route.toJson());
  }

  // Lấy routes từ Firebase
  Future<List<LocationRoute>> getRoutesFromFirebase() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _database
        .ref('users/${user.uid}/locationHistory')
        .get();

    if (!snapshot.exists) return [];

    final routes = <LocationRoute>[];
    for (final child in snapshot.children) {
      try {
        final route = LocationRoute.fromJson(
          Map<String, dynamic>.from(child.value as Map),
        );
        routes.add(route);
      } catch (e) {
        print('Error parsing route: $e');
      }
    }

    return routes;
  }

  // Tính khoảng cách giữa 2 điểm
  double calculateDistance(LocationPoint point1, LocationPoint point2) {
    return Geolocator.distanceBetween(
          point1.latitude,
          point1.longitude,
          point2.latitude,
          point2.longitude,
        ) /
        1000; // Convert to km
  }

  // Tính tổng khoảng cách của route
  double calculateTotalDistance(List<LocationPoint> points) {
    if (points.length < 2) return 0;

    double totalDistance = 0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += calculateDistance(points[i], points[i + 1]);
    }
    return totalDistance;
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

  // Lưu stats
  Future<void> saveStats(LocationHistoryStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, jsonEncode(stats.toJson()));
  }

  // Lấy stats
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
}
