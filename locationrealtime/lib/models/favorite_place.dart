class FavoritePlace {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;

  FavoritePlace({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'lat': lat,
        'lng': lng,
      };

  factory FavoritePlace.fromMap(Map<String, dynamic> map) {
    return FavoritePlace(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
    );
  }
}