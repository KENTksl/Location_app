class Friend {
  final String id;
  final String email;
  final String? avatarUrl;
  final double? distance;
  final bool? isOnline;
  final bool? isSharingLocation;
  final Map<String, dynamic>? location;

  Friend({
    required this.id,
    required this.email,
    this.avatarUrl,
    this.distance,
    this.isOnline,
    this.isSharingLocation,
    this.location,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatarUrl'],
      distance: json['distance']?.toDouble(),
      isOnline: json['isOnline'],
      isSharingLocation: json['isSharingLocation'],
      location: json['location'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'avatarUrl': avatarUrl,
      'distance': distance,
      'isOnline': isOnline,
      'isSharingLocation': isSharingLocation,
      'location': location,
    };
  }

  Friend copyWith({
    String? id,
    String? email,
    String? avatarUrl,
    double? distance,
    bool? isOnline,
    bool? isSharingLocation,
    Map<String, dynamic>? location,
  }) {
    return Friend(
      id: id ?? this.id,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      distance: distance ?? this.distance,
      isOnline: isOnline ?? this.isOnline,
      isSharingLocation: isSharingLocation ?? this.isSharingLocation,
      location: location ?? this.location,
    );
  }
}
