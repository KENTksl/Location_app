import 'package:google_maps_flutter/google_maps_flutter.dart';

// Helper converters to make JSON parsing resilient across int/double/string
double _asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

double? _asNullableDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

DateTime _asDateTime(dynamic v) {
  if (v is int) {
    return DateTime.fromMillisecondsSinceEpoch(v);
  }
  if (v is String) {
    // Try ISO8601 first, then treat as milliseconds string
    try {
      return DateTime.parse(v);
    } catch (_) {
      final ms = int.tryParse(v);
      if (ms != null) {
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }
  }
  throw ArgumentError('Invalid timestamp value: $v');
}

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
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      timestamp: _asDateTime(json['timestamp']),
      accuracy: _asNullableDouble(json['accuracy']),
      speed: _asNullableDouble(json['speed']),
      altitude: _asNullableDouble(json['altitude']),
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
    final rawPoints = json['points'];
    final pointsList = (rawPoints is List)
        ? rawPoints
            .map((p) => LocationPoint.fromJson(
                  Map<String, dynamic>.from(p as Map),
                ))
            .toList()
        : <LocationPoint>[];

    final rawMetadata = json['metadata'];
    final metadataMap = rawMetadata is Map
        ? Map<String, dynamic>.from(rawMetadata)
        : null;

    return LocationRoute(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      points: pointsList,
      startTime: _asDateTime(json['startTime']),
      endTime: json['endTime'] != null ? _asDateTime(json['endTime']) : null,
      totalDistance: _asDouble(json['totalDistance']),
      totalDuration: Duration(milliseconds: _asInt(json['totalDuration'])),
      description: json['description']?.toString(),
      metadata: metadataMap,
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
    final rawDaily = json['dailyStats'];
    final daily = rawDaily is Map
        ? rawDaily.map((key, value) => MapEntry(key.toString(), _asInt(value)))
        : <String, int>{};

    return LocationHistoryStats(
      totalRoutes: _asInt(json['totalRoutes']),
      totalDistance: _asDouble(json['totalDistance']),
      totalDuration: Duration(milliseconds: _asInt(json['totalDuration'])),
      averageSpeed: _asDouble(json['averageSpeed']),
      lastActivity:
          json['lastActivity'] != null ? _asDateTime(json['lastActivity']) : null,
      dailyStats: daily,
    );
  }
}