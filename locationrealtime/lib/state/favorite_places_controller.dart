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
      _places = await repository.listPlaces(uid);
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
      final created = await repository.createPlace(
        uid,
        FavoritePlace(id: '', name: name, address: address, lat: lat, lng: lng),
      );
      _places = [..._places, created];
      notifyListeners();
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
        _places = list;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}