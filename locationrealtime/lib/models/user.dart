class User {
  final String id;
  final String email;
  final String? avatarUrl;
  final DateTime? createdAt;
  final bool? isSharingLocation;
  final bool? alwaysShareLocation;
  final Map<String, dynamic>? location;

  User({
    required this.id,
    required this.email,
    this.avatarUrl,
    this.createdAt,
    this.isSharingLocation,
    this.alwaysShareLocation,
    this.location,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatarUrl'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      isSharingLocation: json['isSharingLocation'],
      alwaysShareLocation: json['alwaysShareLocation'],
      location: json['location'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt?.toIso8601String(),
      'isSharingLocation': isSharingLocation,
      'alwaysShareLocation': alwaysShareLocation,
      'location': location,
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? avatarUrl,
    DateTime? createdAt,
    bool? isSharingLocation,
    bool? alwaysShareLocation,
    Map<String, dynamic>? location,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      isSharingLocation: isSharingLocation ?? this.isSharingLocation,
      alwaysShareLocation: alwaysShareLocation ?? this.alwaysShareLocation,
      location: location ?? this.location,
    );
  }
}
