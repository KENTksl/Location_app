import 'package:geolocator/geolocator.dart';

/// Wrapper class for Geolocator to enable mocking in tests
abstract class GeolocatorWrapper {
  Future<Position> getCurrentPosition({LocationSettings? locationSettings});
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<bool> isLocationServiceEnabled();
  double distanceBetween(double startLatitude, double startLongitude, double endLatitude, double endLongitude);
}

/// Default implementation of GeolocatorWrapper
class GeolocatorWrapperImpl implements GeolocatorWrapper {
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    return Geolocator.getCurrentPosition(locationSettings: locationSettings);
  }

  @override
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  @override
  Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }

  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  double distanceBetween(double startLatitude, double startLongitude, double endLatitude, double endLongitude) {
    return Geolocator.distanceBetween(startLatitude, startLongitude, endLatitude, endLongitude);
  }
}
