class FriendRequest {
  final String id;
  final String email;
  final String? avatarUrl;
  final DateTime? createdAt;

  FriendRequest({
    required this.id,
    required this.email,
    this.avatarUrl,
    this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatarUrl'],
      createdAt: json['createdAt'] != null
          ? (() {
              try {
                return DateTime.parse(json['createdAt']);
              } catch (e) {
                return null;
              }
            })()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  FriendRequest copyWith({
    String? id,
    String? email,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return FriendRequest(
      id: id ?? this.id,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
