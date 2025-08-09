import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

import 'package:locationrealtime/models/location_history.dart';
import 'package:locationrealtime/services/location_history_service.dart';

import '../services/mock.mocks.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseDatabase mockDatabase;
  late MockDatabaseReference mockRef;
  late MockUser mockUser;

  late LocationHistoryService service;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockDatabase = MockFirebaseDatabase();
    mockRef = MockDatabaseReference();
    mockUser = MockUser();

    SharedPreferences.setMockInitialValues({});

    service = LocationHistoryService(auth: mockAuth, database: mockDatabase);
  });

  LocationRoute createFakeRoute() {
    final points = [
      LocationPoint(
        latitude: 10.0,
        longitude: 20.0,
        timestamp: DateTime.now(),
        accuracy: 5,
        speed: 1,
        altitude: 0,
      ),
      LocationPoint(
        latitude: 10.001,
        longitude: 20.001,
        timestamp: DateTime.now().add(const Duration(seconds: 5)),
        accuracy: 5,
        speed: 1,
        altitude: 0,
      ),
    ];

    return LocationRoute(
      id: 'r1',
      name: 'Test Route',
      points: points,
      startTime: points.first.timestamp,
      endTime: points.last.timestamp,
      totalDistance: 0.5,
      totalDuration: const Duration(seconds: 5),
    );
  }

  group('Local storage', () {
    test('saveRouteLocally and getRoutesLocally', () async {
      final route = createFakeRoute();
      await service.saveRouteLocally(route);

      final result = await service.getRoutesLocally();
      expect(result.length, 1);
      expect(result.first.name, 'Test Route');
    });

    test('saveCurrentRoute, getCurrentRoute, clearCurrentRoute', () async {
      final route = createFakeRoute();
      await service.saveCurrentRoute(route);

      final loaded = await service.getCurrentRoute();
      expect(loaded!.name, 'Test Route');

      await service.clearCurrentRoute();
      expect(await service.getCurrentRoute(), isNull);
    });

    test('saveStats and getStats', () async {
      final stats = LocationHistoryStats(
        totalRoutes: 1,
        totalDistance: 1.2,
        totalDuration: const Duration(minutes: 5),
        averageSpeed: 12.0,
        dailyStats: {'2025-08-09': 1},
      );

      await service.saveStats(stats);
      final loaded = await service.getStats();
      expect(loaded!.totalRoutes, 1);
    });
  });

  group('Firebase', () {
    test('saveRouteToFirebase calls database set when user exists', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('u1');
      when(mockDatabase.ref(any)).thenReturn(mockRef);
      when(mockRef.set(any)).thenAnswer((_) async => {});

      final route = createFakeRoute();
      await service.saveRouteToFirebase(route);

      verify(
        mockDatabase.ref('users/u1/locationHistory/${route.id}'),
      ).called(1);
    });

    test('getRoutesFromFirebase returns empty if no user', () async {
      when(mockAuth.currentUser).thenReturn(null);
      final result = await service.getRoutesFromFirebase();
      expect(result, isEmpty);
    });

    test('deleteRoute removes from local and firebase', () async {
      final route = createFakeRoute();
      await service.saveRouteLocally(route);

      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('u1');
      when(mockDatabase.ref(any)).thenReturn(mockRef);
      when(mockRef.remove()).thenAnswer((_) async => {});

      await service.deleteRoute(route.id);

      final localRoutes = await service.getRoutesLocally();
      expect(localRoutes, isEmpty);
      verify(
        mockDatabase.ref('users/u1/locationHistory/${route.id}'),
      ).called(1);
    });
  });

  group('Calculations', () {
    test('calculateTotalDistance works', () {
      final points = createFakeRoute().points;
      final dist = service.calculateTotalDistance(points);
      expect(dist, greaterThan(0));
    });

    test('isValidRoute returns true for valid route', () {
      final points = createFakeRoute().points;
      expect(service.isValidRoute(points), true);
    });

    test('shouldAddPoint returns true for far points', () {
      final points = createFakeRoute().points;
      final newPoint = LocationPoint(
        latitude: 10.01,
        longitude: 20.01,
        timestamp: DateTime.now().add(const Duration(seconds: 20)),
        accuracy: 5,
        speed: 1,
        altitude: 0,
      );
      expect(service.shouldAddPoint(newPoint, points), true);
    });

    test('calculateStats returns correct values', () {
      final route = createFakeRoute();
      final stats = service.calculateStats([route]);
      expect(stats.totalRoutes, 1);
    });

    test('generateRouteName returns correct format', () {
      final route = createFakeRoute();
      final name = service.generateRouteName(route);
      expect(name, contains('${route.startTime.day}/${route.startTime.month}'));
    });

    test('filterRoutesByDistance works', () {
      final route = createFakeRoute();
      final filtered = service.filterRoutesByDistance([route], 0.1, 1.0);
      expect(filtered.length, 1);
    });

    test('exportRouteData and importRouteData works', () {
      final route = createFakeRoute();
      final data = service.exportRouteData(route);
      final imported = service.importRouteData(data);
      expect(imported!.id, route.id);
    });
  });
}
