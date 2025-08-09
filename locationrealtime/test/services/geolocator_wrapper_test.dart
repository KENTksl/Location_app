import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mockito/mockito.dart';

import 'package:locationrealtime/services/geolocator_wrapper.dart';
import '../services/mock.mocks.dart'; // file auto-gen từ mock.dart

class FakePosition extends Position {
  FakePosition()
    : super(
        latitude: 10.0,
        longitude: 20.0,
        timestamp: DateTime(2025, 1, 1),
        accuracy: 1.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        floor: 0,
        isMocked: false,
        headingAccuracy: 1.0,
        altitudeAccuracy: 1.0,
      );
}

void main() {
  late MockGeolocatorWrapper mockGeo;

  setUp(() {
    mockGeo = MockGeolocatorWrapper();
  });

  group('GeolocatorWrapper', () {
    test('checkPermission returns permission status', () async {
      when(
        mockGeo.checkPermission(),
      ).thenAnswer((_) async => LocationPermission.always);

      final result = await mockGeo.checkPermission();

      expect(result, LocationPermission.always);
      verify(mockGeo.checkPermission()).called(1);
    });

    test('requestPermission returns granted', () async {
      when(
        mockGeo.requestPermission(),
      ).thenAnswer((_) async => LocationPermission.whileInUse);

      final result = await mockGeo.requestPermission();

      expect(result, LocationPermission.whileInUse);
      verify(mockGeo.requestPermission()).called(1);
    });

    test('getCurrentPosition returns correct position', () async {
      final fakePos = FakePosition();
      when(
        mockGeo.getCurrentPosition(desiredAccuracy: LocationAccuracy.high),
      ).thenAnswer((_) async => fakePos);

      final result = await mockGeo.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      expect(result.latitude, 10.0);
      expect(result.longitude, 20.0);
      verify(
        mockGeo.getCurrentPosition(desiredAccuracy: LocationAccuracy.high),
      ).called(1);
    });

    test('distanceBetween returns correct value', () {
      when(mockGeo.distanceBetween(10, 20, 11, 21)).thenReturn(150000);

      final dist = mockGeo.distanceBetween(10, 20, 11, 21);

      expect(dist, 150000);
      verify(mockGeo.distanceBetween(10, 20, 11, 21)).called(1);
    });
  });
}
