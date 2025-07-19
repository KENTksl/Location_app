class DeviceModel {
  final String id;
  final String name;
  final String type; // 'vehicle', 'employee', 'asset', 'device'
  final String? description;
  final String? assignedUserId;
  final String? assignedUserName;
  final String status; // 'active', 'inactive', 'maintenance', 'lost'
  final DateTime createdAt;
  final DateTime? lastSeenAt;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic>? settings;

  DeviceModel({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.assignedUserId,
    this.assignedUserName,
    this.status = 'active',
    required this.createdAt,
    this.lastSeenAt,
    this.metadata,
    this.settings,
  });

  factory DeviceModel.fromMap(Map<String, dynamic> map) {
    return DeviceModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'device',
      description: map['description'],
      assignedUserId: map['assignedUserId'],
      assignedUserName: map['assignedUserName'],
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      lastSeenAt: map['lastSeenAt'] != null
          ? DateTime.parse(map['lastSeenAt'])
          : null,
      metadata: map['metadata'],
      settings: map['settings'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'assignedUserId': assignedUserId,
      'assignedUserName': assignedUserName,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'lastSeenAt': lastSeenAt?.toIso8601String(),
      'metadata': metadata,
      'settings': settings,
    };
  }

  DeviceModel copyWith({
    String? id,
    String? name,
    String? type,
    String? description,
    String? assignedUserId,
    String? assignedUserName,
    String? status,
    DateTime? createdAt,
    DateTime? lastSeenAt,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? settings,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      assignedUserId: assignedUserId ?? this.assignedUserId,
      assignedUserName: assignedUserName ?? this.assignedUserName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      metadata: metadata ?? this.metadata,
      settings: settings ?? this.settings,
    );
  }

  bool get isActive => status == 'active';
  bool get isVehicle => type == 'vehicle';
  bool get isEmployee => type == 'employee';
  bool get isAsset => type == 'asset';
  bool get isAssigned => assignedUserId != null;

  String get statusText {
    switch (status) {
      case 'active':
        return 'Hoạt động';
      case 'inactive':
        return 'Không hoạt động';
      case 'maintenance':
        return 'Bảo trì';
      case 'lost':
        return 'Mất tích';
      default:
        return 'Không xác định';
    }
  }

  String get typeText {
    switch (type) {
      case 'vehicle':
        return 'Xe cộ';
      case 'employee':
        return 'Nhân viên';
      case 'asset':
        return 'Tài sản';
      case 'device':
        return 'Thiết bị';
      default:
        return 'Khác';
    }
  }

  bool get isOnline {
    if (lastSeenAt == null) return false;
    final now = DateTime.now();
    final difference = now.difference(lastSeenAt!);
    return difference.inMinutes <
        5; // Online nếu hoạt động trong 5 phút gần đây
  }

  String get formattedLastSeen {
    if (lastSeenAt == null) return 'Chưa có dữ liệu';

    final now = DateTime.now();
    final difference = now.difference(lastSeenAt!);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else {
      return '${difference.inDays} ngày trước';
    }
  }
}
