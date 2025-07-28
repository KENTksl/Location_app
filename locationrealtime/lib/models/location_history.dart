import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;
  final double? speed;
  final double? altitude;

  LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.speed,
    this.altitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'accuracy': accuracy,
      'speed': speed,
      'altitude': altitude,
    };
  }

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      accuracy: json['accuracy'] as double?,
      speed: json['speed'] as double?,
      altitude: json['altitude'] as double?,
    );
  }

  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }
}

class LocationRoute {
  final String id;
  final String name;
  final List<LocationPoint> points;
  final DateTime startTime;
  final DateTime? endTime;
  final double totalDistance;
  final Duration totalDuration;
  final String? description;
  final Map<String, dynamic>? metadata;

  LocationRoute({
    required this.id,
    required this.name,
    required this.points,
    required this.startTime,
    this.endTime,
    required this.totalDistance,
    required this.totalDuration,
    this.description,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'points': points.map((point) => point.toJson()).toList(),
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'totalDistance': totalDistance,
      'totalDuration': totalDuration.inMilliseconds,
      'description': description,
      'metadata': metadata,
    };
  }

  factory LocationRoute.fromJson(Map<String, dynamic> json) {
    return LocationRoute(
      id: json['id'] as String,
      name: json['name'] as String,
      points: (json['points'] as List)
          .map((point) => LocationPoint.fromJson(point as Map<String, dynamic>))
          .toList(),
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
      endTime: json['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['endTime'] as int)
          : null,
      totalDistance: json['totalDistance'] as double,
      totalDuration: Duration(milliseconds: json['totalDuration'] as int),
      description: json['description'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  double get averageSpeed {
    if (totalDuration.inSeconds == 0) return 0;
    return totalDistance / (totalDuration.inSeconds / 3600); // km/h
  }

  List<LatLng> get latLngPoints {
    return points.map((point) => point.toLatLng()).toList();
  }
}

class LocationHistoryStats {
  final int totalRoutes;
  final double totalDistance;
  final Duration totalDuration;
  final double averageSpeed;
  final DateTime? lastActivity;
  final Map<String, int> dailyStats;

  LocationHistoryStats({
    required this.totalRoutes,
    required this.totalDistance,
    required this.totalDuration,
    required this.averageSpeed,
    this.lastActivity,
    required this.dailyStats,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalRoutes': totalRoutes,
      'totalDistance': totalDistance,
      'totalDuration': totalDuration.inMilliseconds,
      'averageSpeed': averageSpeed,
      'lastActivity': lastActivity?.millisecondsSinceEpoch,
      'dailyStats': dailyStats,
    };
  }

  factory LocationHistoryStats.fromJson(Map<String, dynamic> json) {
    return LocationHistoryStats(
      totalRoutes: json['totalRoutes'] as int,
      totalDistance: json['totalDistance'] as double,
      totalDuration: Duration(milliseconds: json['totalDuration'] as int),
      averageSpeed: json['averageSpeed'] as double,
      lastActivity: json['lastActivity'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastActivity'] as int)
          : null,
      dailyStats: Map<String, int>.from(json['dailyStats'] as Map),
    );
  }
} 