import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/favorite_place.dart';
import 'favorite_places_repository.dart';

class FirestoreFavoritePlacesRepository implements FavoritePlacesRepository {
  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorite_places');
  }

  @override
  Future<List<FavoritePlace>> listPlaces(String userId) async {
    final snap = await _collection(userId).orderBy('name').get();
    return snap.docs
        .map((d) => FavoritePlace.fromMap(d.data()))
        .toList(growable: false);
  }

  @override
  Future<FavoritePlace> createPlace(String userId, FavoritePlace place) async {
    final doc = _collection(userId).doc();
    final withId = FavoritePlace(
      id: doc.id,
      name: place.name,
      address: place.address,
      lat: place.lat,
      lng: place.lng,
    );
    await doc.set(withId.toMap());
    return withId;
  }

  @override
  Future<void> updatePlace(String userId, FavoritePlace place) async {
    await _collection(userId).doc(place.id).set(place.toMap());
  }

  @override
  Future<void> deletePlace(String userId, String placeId) async {
    await _collection(userId).doc(placeId).delete();
  }

  @override
  Stream<List<FavoritePlace>> watchPlaces(String userId) {
    return _collection(userId)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FavoritePlace.fromMap(d.data()))
            .toList(growable: false));
  }
}