import '../models/favorite_place.dart';

abstract class FavoritePlacesRepository {
  Future<List<FavoritePlace>> listPlaces(String userId);
  Future<FavoritePlace> createPlace(String userId, FavoritePlace place);
  Future<void> updatePlace(String userId, FavoritePlace place);
  Future<void> deletePlace(String userId, String placeId);
  Stream<List<FavoritePlace>> watchPlaces(String userId);
}