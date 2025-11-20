import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/favorite_place.dart';
import '../repositories/favorite_places_repository.dart';

class FavoritePlacesController extends ChangeNotifier {
  final FavoritePlacesRepository repository;
  FavoritePlacesController(this.repository);

  List<FavoritePlace> _places = [];
  bool _loading = false;
  String? _error;
  StreamSubscription<List<FavoritePlace>>? _subscription;

  List<FavoritePlace> get places => _places;
  bool get loading => _loading;
  String? get error => _error;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> load() async {
    final uid = _uid;
    if (uid == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final list = await repository.listPlaces(uid);
      _places = _dedupPlaces(list);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<FavoritePlace?> addPlace({
    required String name,
    required String address,
    required double lat,
    required double lng,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      // Tránh tạo bản ghi trùng nhau theo tọa độ (sai số rất nhỏ) hoặc tên+tọa độ
      for (final p in _places) {
        final sameCoords = (p.lat - lat).abs() < 1e-6 && (p.lng - lng).abs() < 1e-6;
        final sameName = p.name.trim().toLowerCase() == name.trim().toLowerCase();
        if (sameCoords || (sameName && sameCoords)) {
          // Trả về bản ghi sẵn có để UI vẫn có thể dùng nếu cần
          return p;
        }
      }
      final created = await repository.createPlace(
        uid,
        FavoritePlace(id: '', name: name, address: address, lat: lat, lng: lng),
      );
      // Không tự thêm vào danh sách cục bộ để tránh hiển thị trùng;
      // danh sách sẽ được cập nhật qua stream watchPlaces hoặc lần load tiếp theo.
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> deletePlace(String id) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await repository.deletePlace(uid, id);
      _places = _places.where((p) => p.id != id).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Lắng nghe thay đổi realtime từ Firestore để UI cập nhật ngay lập tức
  void startListening() {
    final uid = _uid;
    if (uid == null) return;
    _subscription?.cancel();
    _subscription = repository.watchPlaces(uid).listen(
      (list) {
        _places = _dedupPlaces(list);
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  /// Loại bỏ các phần tử trùng theo `id`, fallback theo `name + lat/lng`
  List<FavoritePlace> _dedupPlaces(List<FavoritePlace> input) {
    final seenId = <String>{};
    final seenKey = <String>{};
    final result = <FavoritePlace>[];
    for (final p in input) {
      final idOk = p.id.isNotEmpty && seenId.add(p.id);
      final key = '${p.name.trim().toLowerCase()}|${p.lat.toStringAsFixed(6)}|${p.lng.toStringAsFixed(6)}';
      final keyOk = seenKey.add(key);
      if (idOk || keyOk) {
        result.add(p);
      }
    }
    return result;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}