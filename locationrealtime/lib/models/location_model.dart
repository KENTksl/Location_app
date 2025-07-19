import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationModel {
  final String id;
  final String userId;
  final String userName;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final DateTime timestamp;
  final String? address;
  final String? status; // 'online', 'offline', 'moving', 'stopped'
  final Map<String, dynamic>? metadata;

  LocationModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.speed,
    this.heading,
    required this.timestamp,
    this.address,
    this.status,
    this.metadata,
  });

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      altitude: map['altitude']?.toDouble(),
      accuracy: map['accuracy']?.toDouble(),
      speed: map['speed']?.toDouble(),
      heading: map['heading']?.toDouble(),
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      address: map['address'],
      status: map['status'],
      metadata: map['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'timestamp': timestamp.toIso8601String(),
      'address': address,
      'status': status,
      'metadata': metadata,
    };
  }

  LatLng get latLng => LatLng(latitude, longitude);

  LocationModel copyWith({
    String? id,
    String? userId,
    String? userName,
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    double? speed,
    double? heading,
    DateTime? timestamp,
    String? address,
    String? status,
    Map<String, dynamic>? metadata,
  }) {
    return LocationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
      address: address ?? this.address,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isOnline => status == 'online';
  bool get isMoving => status == 'moving';
  bool get isStopped => status == 'stopped';

  String get formattedSpeed {
    if (speed == null) return 'N/A';
    if (speed! < 1) return 'Dừng';
    return '${speed!.toStringAsFixed(1)} km/h';
  }

  String get formattedAccuracy {
    if (accuracy == null) return 'N/A';
    return '${accuracy!.toStringAsFixed(1)}m';
  }

  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

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
