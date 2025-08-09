import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:locationrealtime/models/location_history.dart';

void main() {
  group('LocationPoint Model Tests', () {
    test('should create LocationPoint with required fields', () {
      final point = LocationPoint(
        latitude: 10.0,
        longitude: 20.0,
        timestamp: DateTime(2023, 1, 1, 12, 0, 0),
      );

      expect(point.latitude, 10.0);
      expect(point.longitude, 20.0);
      expect(point.timestamp, DateTime(2023, 1, 1, 12, 0, 0));
      expect(point.accuracy, null);
      expect(point.speed, null);
      expect(point.altitude, null);
    });

    test('should create LocationPoint with all fields', () {
      final point = LocationPoint(
        latitude: 10.0,
        longitude: 20.0,
        timestamp: DateTime(2023, 1, 1, 12, 0, 0),
        accuracy: 5.0,
        speed: 30.0,
        altitude: 100.0,
      );

      expect(point.latitude, 10.0);
      expect(point.longitude, 20.0);
      expect(point.timestamp, DateTime(2023, 1, 1, 12, 0, 0));
      expect(point.accuracy, 5.0);
      expect(point.speed, 30.0);
      expect(point.altitude, 100.0);
    });

    test('should convert LocationPoint to JSON', () {
      final point = LocationPoint(
        latitude: 10.0,
        longitude: 20.0,
        timestamp: DateTime(2023, 1, 1, 12, 0, 0),
        accuracy: 5.0,
        speed: 30.0,
        altitude: 100.0,
      );

      final json = point.toJson();

      expect(json['latitude'], 10.0);
      expect(json['longitude'], 20.0);
      expect(json['timestamp'], DateTime(2023, 1, 1, 12, 0, 0).millisecondsSinceEpoch);
      expect(json['accuracy'], 5.0);
      expect(json['speed'], 30.0);
      expect(json['altitude'], 100.0);
    });

    test('should create LocationPoint from JSON', () {
      final json = {
        'latitude': 10.0,
        'longitude': 20.0,
        'timestamp': DateTime(2023, 1, 1, 12, 0, 0).millisecondsSinceEpoch,
        'accuracy': 5.0,
        'speed': 30.0,
        'altitude': 100.0,
      };

      final point = LocationPoint.fromJson(json);

      expect(point.latitude, 10.0);
      expect(point.longitude, 20.0);
      expect(point.timestamp, DateTime(2023, 1, 1, 12, 0, 0));
      expect(point.accuracy, 5.0);
      expect(point.speed, 30.0);
      expect(point.altitude, 100.0);
    });

    test('should convert LocationPoint to LatLng', () {
      final point = LocationPoint(
        latitude: 10.0,
        longitude: 20.0,
        timestamp: DateTime(2023, 1, 1, 12, 0, 0),
      );

      final latLng = point.toLatLng();

      expect(latLng.latitude, 10.0);
      expect(latLng.longitude, 20.0);
    });

    test('should handle negative coordinates', () {
      final point = LocationPoint(
        latitude: -10.0,
        longitude: -20.0,
        timestamp: DateTime(2023, 1, 1, 12, 0, 0),
      );

      expect(point.latitude, -10.0);
      expect(point.longitude, -20.0);
    });

    test('should handle extreme coordinates', () {
      final point = LocationPoint(
        latitude: 90.0,
        longitude: 180.0,
        timestamp: DateTime(2023, 1, 1, 12, 0, 0),
      );

      expect(point.latitude, 90.0);
      expect(point.longitude, 180.0);
    });
  });

  group('LocationRoute Model Tests', () {
    test('should create LocationRoute with required fields', () {
      final points = [
        LocationPoint(
          latitude: 10.0,
          longitude: 20.0,
          timestamp: DateTime(2023, 1, 1, 12, 0, 0),
        ),
        LocationPoint(
          latitude: 11.0,
          longitude: 21.0,
          timestamp: DateTime(2023, 1, 1, 12, 1, 0),
        ),
      ];

      final route = LocationRoute(
        id: 'route-id',
        name: 'Test Route',
        points: points,
        startTime: DateTime(2023, 1, 1, 12, 0, 0),
        totalDistance: 5.0,
        totalDuration: Duration(minutes: 30),
      );

      expect(route.id, 'route-id');
      expect(route.name, 'Test Route');
      expect(route.points, points);
      expect(route.startTime, DateTime(2023, 1, 1, 12, 0, 0));
      expect(route.endTime, null);
      expect(route.totalDistance, 5.0);
      expect(route.totalDuration, Duration(minutes: 30));
      expect(route.description, null);
      expect(route.metadata, null);
    });

    test('should create LocationRoute with all fields', () {
      final points = [
        LocationPoint(
          latitude: 10.0,
          longitude: 20.0,
          timestamp: DateTime(2023, 1, 1, 12, 0, 0),
        ),
        LocationPoint(
          latitude: 11.0,
          longitude: 21.0,
          timestamp: DateTime(2023, 1, 1, 12, 1, 0),
        ),
      ];

      final route = LocationRoute(
        id: 'route-id',
        name: 'Test Route',
        points: points,
        startTime: DateTime(2023, 1, 1, 12, 0, 0),
        endTime: DateTime(2023, 1, 1, 12, 30, 0),
        totalDistance: 5.0,
        totalDuration: Duration(minutes: 30),
        description: 'A test route',
        metadata: {'type': 'walking', 'weather': 'sunny'},
      );

      expect(route.id, 'route-id');
      expect(route.name, 'Test Route');
      expect(route.points, points);
      expect(route.startTime, DateTime(2023, 1, 1, 12, 0, 0));
      expect(route.endTime, DateTime(2023, 1, 1, 12, 30, 0));
      expect(route.totalDistance, 5.0);
      expect(route.totalDuration, Duration(minutes: 30));
      expect(route.description, 'A test route');
      expect(route.metadata, {'type': 'walking', 'weather': 'sunny'});
    });

    test('should convert LocationRoute to JSON', () {
      final points = [
        LocationPoint(
          latitude: 10.0,
          longitude: 20.0,
          timestamp: DateTime(2023, 1, 1, 12, 0, 0),
        ),
        LocationPoint(
          latitude: 11.0,
          longitude: 21.0,
          timestamp: DateTime(2023, 1, 1, 12, 1, 0),
        ),
      ];

      final route = LocationRoute(
        id: 'route-id',
        name: 'Test Route',
        points: points,
        startTime: DateTime(2023, 1, 1, 12, 0, 0),
        endTime: DateTime(2023, 1, 1, 12, 30, 0),
        totalDistance: 5.0,
        totalDuration: Duration(minutes: 30),
        description: 'A test route',
        metadata: {'type': 'walking', 'weather': 'sunny'},
      );

      final json = route.toJson();

      expect(json['id'], 'route-id');
      expect(json['name'], 'Test Route');
      expect(json['points'], isA<List>());
      expect(json['startTime'], DateTime(2023, 1, 1, 12, 0, 0).millisecondsSinceEpoch);
      expect(json['endTime'], DateTime(2023, 1, 1, 12, 30, 0).millisecondsSinceEpoch);
      expect(json['totalDistance'], 5.0);
      expect(json['totalDuration'], Duration(minutes: 30).inMilliseconds);
      expect(json['description'], 'A test route');
      expect(json['metadata'], {'type': 'walking', 'weather': 'sunny'});
    });

    test('should create LocationRoute from JSON', () {
      final json = {
        'id': 'route-id',
        'name': 'Test Route',
        'points': [
          {
            'latitude': 10.0,
            'longitude': 20.0,
            'timestamp': DateTime(2023, 1, 1, 12, 0, 0).millisecondsSinceEpoch,
          },
          {
            'latitude': 11.0,
            'longitude': 21.0,
            'timestamp': DateTime(2023, 1, 1, 12, 1, 0).millisecondsSinceEpoch,
          },
        ],
        'startTime': DateTime(2023, 1, 1, 12, 0, 0).millisecondsSinceEpoch,
        'endTime': DateTime(2023, 1, 1, 12, 30, 0).millisecondsSinceEpoch,
        'totalDistance': 5.0,
        'totalDuration': Duration(minutes: 30).inMilliseconds,
        'description': 'A test route',
        'metadata': {'type': 'walking', 'weather': 'sunny'},
      };

      final route = LocationRoute.fromJson(json);

      expect(route.id, 'route-id');
      expect(route.name, 'Test Route');
      expect(route.points.length, 2);
      expect(route.startTime, DateTime(2023, 1, 1, 12, 0, 0));
      expect(route.endTime, DateTime(2023, 1, 1, 12, 30, 0));
      expect(route.totalDistance, 5.0);
      expect(route.totalDuration, Duration(minutes: 30));
      expect(route.description, 'A test route');
      expect(route.metadata, {'type': 'walking', 'weather': 'sunny'});
    });

    test('should calculate average speed correctly', () {
      final points = [
        LocationPoint(
          latitude: 10.0,
          longitude: 20.0,
          timestamp: DateTime(2023, 1, 1, 12, 0, 0),
        ),
        LocationPoint(
          latitude: 11.0,
          longitude: 21.0,
          timestamp: DateTime(2023, 1, 1, 12, 1, 0),
        ),
      ];

      final route = LocationRoute(
        id: 'route-id',
        name: 'Test Route',
        points: points,
        startTime: DateTime(2023, 1, 1, 12, 0, 0),
        endTime: DateTime(2023, 1, 1, 12, 1, 0),
        totalDistance: 5.0,
        totalDuration: Duration(minutes: 1),
        description: 'A test route',
      );

      // 5 km in 1 minute = 300 km/h
      expect(route.averageSpeed, 300.0);
    });

    test('should return 0 average speed for zero duration', () {
      final points = [
        LocationPoint(
          latitude: 10.0,
          longitude: 20.0,
          timestamp: DateTime(2023, 1, 1, 12, 0, 0),
        ),
      ];

      final route = LocationRoute(
        id: 'route-id',
        name: 'Test Route',
        points: points,
        startTime: DateTime(2023, 1, 1, 12, 0, 0),
        endTime: DateTime(2023, 1, 1, 12, 0, 0),
        totalDistance: 5.0,
        totalDuration: Duration.zero,
        description: 'A test route',
      );

      expect(route.averageSpeed, 0.0);
    });

    test('should convert points to LatLng list', () {
      final points = [
        LocationPoint(
          latitude: 10.0,
          longitude: 20.0,
          timestamp: DateTime(2023, 1, 1, 12, 0, 0),
        ),
        LocationPoint(
          latitude: 11.0,
          longitude: 21.0,
          timestamp: DateTime(2023, 1, 1, 12, 1, 0),
        ),
      ];

      final route = LocationRoute(
        id: 'route-id',
        name: 'Test Route',
        points: points,
        startTime: DateTime(2023, 1, 1, 12, 0, 0),
        totalDistance: 5.0,
        totalDuration: Duration(minutes: 30),
      );

      final latLngPoints = route.latLngPoints;

      expect(latLngPoints.length, 2);
      expect(latLngPoints[0].latitude, 10.0);
      expect(latLngPoints[0].longitude, 20.0);
      expect(latLngPoints[1].latitude, 11.0);
      expect(latLngPoints[1].longitude, 21.0);
    });
  });

  group('LocationHistoryStats Model Tests', () {
    test('should create LocationHistoryStats with required fields', () {
      final stats = LocationHistoryStats(
        totalRoutes: 10,
        totalDistance: 50.0,
        totalDuration: Duration(hours: 2),
        averageSpeed: 25.0,
        dailyStats: {'2023-01-01': 5, '2023-01-02': 5},
      );

      expect(stats.totalRoutes, 10);
      expect(stats.totalDistance, 50.0);
      expect(stats.totalDuration, Duration(hours: 2));
      expect(stats.averageSpeed, 25.0);
      expect(stats.lastActivity, null);
      expect(stats.dailyStats, {'2023-01-01': 5, '2023-01-02': 5});
    });

    test('should create LocationHistoryStats with all fields', () {
      final lastActivity = DateTime(2023, 1, 2, 12, 0, 0);
      
      final stats = LocationHistoryStats(
        totalRoutes: 10,
        totalDistance: 50.0,
        totalDuration: Duration(hours: 2),
        averageSpeed: 25.0,
        lastActivity: lastActivity,
        dailyStats: {'2023-01-01': 5, '2023-01-02': 5},
      );

      expect(stats.totalRoutes, 10);
      expect(stats.totalDistance, 50.0);
      expect(stats.totalDuration, Duration(hours: 2));
      expect(stats.averageSpeed, 25.0);
      expect(stats.lastActivity, lastActivity);
      expect(stats.dailyStats, {'2023-01-01': 5, '2023-01-02': 5});
    });

    test('should convert LocationHistoryStats to JSON', () {
      final lastActivity = DateTime(2023, 1, 2, 12, 0, 0);
      
      final stats = LocationHistoryStats(
        totalRoutes: 10,
        totalDistance: 50.0,
        totalDuration: Duration(hours: 2),
        averageSpeed: 25.0,
        lastActivity: lastActivity,
        dailyStats: {'2023-01-01': 5, '2023-01-02': 5},
      );

      final json = stats.toJson();

      expect(json['totalRoutes'], 10);
      expect(json['totalDistance'], 50.0);
      expect(json['totalDuration'], Duration(hours: 2).inMilliseconds);
      expect(json['averageSpeed'], 25.0);
      expect(json['lastActivity'], lastActivity.millisecondsSinceEpoch);
      expect(json['dailyStats'], {'2023-01-01': 5, '2023-01-02': 5});
    });

    test('should create LocationHistoryStats from JSON', () {
      final lastActivity = DateTime(2023, 1, 2, 12, 0, 0);
      
      final json = {
        'totalRoutes': 10,
        'totalDistance': 50.0,
        'totalDuration': Duration(hours: 2).inMilliseconds,
        'averageSpeed': 25.0,
        'lastActivity': lastActivity.millisecondsSinceEpoch,
        'dailyStats': {'2023-01-01': 5, '2023-01-02': 5},
      };

      final stats = LocationHistoryStats.fromJson(json);

      expect(stats.totalRoutes, 10);
      expect(stats.totalDistance, 50.0);
      expect(stats.totalDuration, Duration(hours: 2));
      expect(stats.averageSpeed, 25.0);
      expect(stats.lastActivity, lastActivity);
      expect(stats.dailyStats, {'2023-01-01': 5, '2023-01-02': 5});
    });

    test('should handle null lastActivity in fromJson', () {
      final json = {
        'totalRoutes': 10,
        'totalDistance': 50.0,
        'totalDuration': Duration(hours: 2).inMilliseconds,
        'averageSpeed': 25.0,
        'lastActivity': null,
        'dailyStats': {'2023-01-01': 5, '2023-01-02': 5},
      };

      final stats = LocationHistoryStats.fromJson(json);

      expect(stats.totalRoutes, 10);
      expect(stats.totalDistance, 50.0);
      expect(stats.totalDuration, Duration(hours: 2));
      expect(stats.averageSpeed, 25.0);
      expect(stats.lastActivity, null);
      expect(stats.dailyStats, {'2023-01-01': 5, '2023-01-02': 5});
    });

    test('should handle empty dailyStats', () {
      final stats = LocationHistoryStats(
        totalRoutes: 0,
        totalDistance: 0.0,
        totalDuration: Duration.zero,
        averageSpeed: 0.0,
        dailyStats: {},
      );

      expect(stats.totalRoutes, 0);
      expect(stats.totalDistance, 0.0);
      expect(stats.totalDuration, Duration.zero);
      expect(stats.averageSpeed, 0.0);
      expect(stats.dailyStats, {});
    });

    test('should handle large numbers', () {
      final stats = LocationHistoryStats(
        totalRoutes: 1000000,
        totalDistance: 999999.99,
        totalDuration: Duration(days: 365),
        averageSpeed: 999.99,
        dailyStats: {'2023-01-01': 1000, '2023-01-02': 2000},
      );

      expect(stats.totalRoutes, 1000000);
      expect(stats.totalDistance, 999999.99);
      expect(stats.totalDuration, Duration(days: 365));
      expect(stats.averageSpeed, 999.99);
      expect(stats.dailyStats, {'2023-01-01': 1000, '2023-01-02': 2000});
    });
  });
} 