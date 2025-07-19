class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String role; // 'admin', 'manager', 'driver', 'employee'
  final String? phoneNumber;
  final String? avatarUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final Map<String, dynamic>? permissions;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.phoneNumber,
    this.avatarUrl,
    this.isActive = true,
    required this.createdAt,
    required this.lastLoginAt,
    this.permissions,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      role: map['role'] ?? 'employee',
      phoneNumber: map['phoneNumber'],
      avatarUrl: map['avatarUrl'],
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.parse(map['lastLoginAt'])
          : DateTime.now(),
      permissions: map['permissions'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role,
      'phoneNumber': phoneNumber,
      'avatarUrl': avatarUrl,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt.toIso8601String(),
      'permissions': permissions,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? role,
    String? phoneNumber,
    String? avatarUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    Map<String, dynamic>? permissions,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      permissions: permissions ?? this.permissions,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get isDriver => role == 'driver';
  bool get isEmployee => role == 'employee';

  bool hasPermission(String permission) {
    if (isAdmin) return true;
    if (permissions == null) return false;
    return permissions![permission] == true;
  }
}
