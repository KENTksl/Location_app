import 'package:geolocator/geolocator.dart';

abstract class GeolocatorWrapper {
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition({LocationAccuracy? desiredAccuracy});
  double distanceBetween(double startLatitude, double startLongitude, double endLatitude, double endLongitude);
}

class GeolocatorWrapperImpl implements GeolocatorWrapper {
  @override
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  @override
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  @override
  Future<Position> getCurrentPosition({LocationAccuracy? desiredAccuracy}) async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: desiredAccuracy ?? LocationAccuracy.high,
    );
  }

  @override
  double distanceBetween(double startLatitude, double startLongitude, double endLatitude, double endLongitude) {
    return Geolocator.distanceBetween(startLatitude, startLongitude, endLatitude, endLongitude);
  }
}
