class MapsConfig {
  // Google Maps API Key - Thay thế bằng API key thật của bạn
  static const String googleMapsApiKey = 'AIzaSyB-EXAMPLE-KEY-PLEASE-REPLACE';

  // Cấu hình bản đồ mặc định
  static const double defaultLatitude = 21.0285; // Hà Nội
  static const double defaultLongitude = 105.8542;
  static const double defaultZoom = 12.0;

  // Cấu hình theo dõi vị trí
  static const int locationUpdateInterval = 30; // giây
  static const double locationDistanceFilter = 10.0; // mét

  // Cấu hình marker
  static const double markerSize = 40.0;
  static const double markerRotation = 0.0;

  // Cấu hình polyline
  static const double polylineWidth = 3.0;
  static const int polylineColor = 0xFF2196F3; // Màu xanh dương
}
