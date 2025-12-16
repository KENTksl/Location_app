import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:provider/provider.dart';
import '../state/favorite_places_controller.dart';
import '../services/map_navigation_service.dart';
import '../services/toast_service.dart';
import '../theme.dart';

class FavoritePlacePickerPage extends StatefulWidget {
  const FavoritePlacePickerPage({super.key});

  @override
  State<FavoritePlacePickerPage> createState() =>
      _FavoritePlacePickerPageState();
}

class _FavoritePlacePickerPageState extends State<FavoritePlacePickerPage> {
  GoogleMapController? _mapController;
  Marker? _marker;
  final LatLng _center = const LatLng(10.8231, 106.6297);
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn địa điểm yêu thích')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 13),
            onMapCreated: (c) => _mapController = c,
            onLongPress: (pos) async {
              setState(() {
                _marker = Marker(
                  markerId: const MarkerId('fav'),
                  position: pos,
                );
              });
              await _promptForNameAndSave(pos);
            },
            markers: _marker != null ? {_marker!} : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: AppTheme.card(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: const Text(
                'Giữ tay trên bản đồ để đặt marker, sau đó nhập tên để lưu.',
                style: AppTheme.captionStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptForNameAndSave(LatLng pos) async {
    final controller = context.read<FavoritePlacesController>();
    final name = await _askForName();
    if (name == null || name.trim().isEmpty) {
      ToastService.show(
        context,
        message: 'Tên địa điểm không được để trống',
        type: AppToastType.warning,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final placemarks = await geo.placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      final placeMark = placemarks.isNotEmpty ? placemarks.first : null;
      final address = placeMark != null
          ? [
              placeMark.street,
              placeMark.subLocality,
              placeMark.locality,
              placeMark.administrativeArea,
            ].where((e) => e != null && e.isNotEmpty).join(', ')
          : 'Không rõ địa chỉ';

      final created = await controller.addPlace(
        name: name.trim(),
        address: address,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      if (created != null) {
        // Hiển thị toast ở trang Hồ sơ để đảm bảo overlay luôn còn
        MapNavigationService.instance.requestFocus(pos);
        if (mounted) {
          // Trả về địa điểm đã tạo để trang Hồ sơ có thể hiển thị toast
          Navigator.of(context).pop(created);
        }
      } else {
        ToastService.show(
          context,
          message: 'Không thể lưu địa điểm',
          type: AppToastType.error,
        );
      }
    } catch (e) {
      ToastService.show(
        context,
        message: 'Geocoding lỗi: $e',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _askForName() async {
    String? name;
    await showDialog(
      context: context,
      builder: (ctx) {
        final textCtrl = TextEditingController();
        return AlertDialog(
          title: const Text('Tên địa điểm'),
          content: TextField(
            controller: textCtrl,
            decoration: const InputDecoration(hintText: 'Nhập tên'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                name = textCtrl.text;
                Navigator.pop(ctx);
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
    return name;
  }
}
