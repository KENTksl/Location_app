import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:locationrealtime/pages/location_history_page.dart';
import 'package:locationrealtime/models/location_history.dart';
import 'package:locationrealtime/services/location_history_service.dart';

// Generate mocks for the services
@GenerateMocks([LocationHistoryService])
import 'location_history_page_test.mocks.dart';

void main() {
  group('LocationHistoryPage Basic Tests', () {
    late MockLocationHistoryService mockService;

    setUp(() {
      mockService = MockLocationHistoryService();

      // Mock the service methods to return empty data
      when(mockService.getRoutesLocally()).thenAnswer((_) async => []);
      when(mockService.getRoutesFromFirebase()).thenAnswer((_) async => []);

      // Create a mock stats object
      final mockStats = LocationHistoryStats(
        totalRoutes: 0,
        totalDistance: 0.0,
        totalDuration: const Duration(seconds: 0),
        averageSpeed: 0.0,
        lastActivity: null,
        dailyStats: {},
      );
      when(mockService.calculateStats(any)).thenReturn(mockStats);
    });

    testWidgets('should create LocationHistoryPage without crashing', (
      WidgetTester tester,
    ) async {
      // Create a test widget with mocked service
      await tester.pumpWidget(
        MaterialApp(home: LocationHistoryPage(service: mockService)),
      );

      // Wait for the widget to settle
      await tester.pumpAndSettle();

      // If we get here, the widget was created successfully
      expect(find.byType(LocationHistoryPage), findsOneWidget);
    });
  });

  group('RouteDetailsPage', () {
    late LocationRoute mockRoute;

    setUp(() {
      final mockPoints = [
        LocationPoint(
          latitude: 10.762622,
          longitude: 106.660172,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          speed: 25.0,
          altitude: 10.0,
        ),
        LocationPoint(
          latitude: 10.762622,
          longitude: 106.660172,
          timestamp: DateTime.now().add(const Duration(minutes: 5)),
          accuracy: 5.0,
          speed: 30.0,
          altitude: 10.0,
        ),
      ];

      mockRoute = LocationRoute(
        id: 'route1',
        name: 'Test Route',
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now(),
        points: mockPoints,
        totalDistance: 15.5,
        totalDuration: const Duration(hours: 1),
        description: 'Test route description',
      );
    });

    testWidgets('should display route details page', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: RouteDetailsPage(route: mockRoute)),
      );

      // Should show the route name in the app bar
      expect(find.text('Test Route'), findsOneWidget);
    });

    testWidgets('should display map when route has points', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: RouteDetailsPage(route: mockRoute)),
      );

      // Should show GoogleMap widget
      expect(find.byType(GoogleMap), findsOneWidget);
    });
  });
}
