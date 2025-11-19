import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';

class MapNavigationService {
  MapNavigationService._();
  static final MapNavigationService instance = MapNavigationService._();

  final ValueNotifier<LatLng?> focusRequest = ValueNotifier<LatLng?>(null);

  void requestFocus(LatLng target) {
    focusRequest.value = target;
  }

  // Xóa trạng thái focus hiện tại trên bản đồ
  void clearFocus() {
    focusRequest.value = null;
  }
}