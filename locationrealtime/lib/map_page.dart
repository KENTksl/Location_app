import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'user_profile_page.dart';
import 'package:geolocator/geolocator.dart';
import 'friend_search_page.dart';
import 'friend_requests_page.dart';
import 'package:firebase_database/firebase_database.dart';
import 'friends_list_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:async/async.dart';

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? mapController;

  LatLng? _currentPosition;
  final LatLng _defaultCenter = const LatLng(21.0285, 105.8542); // Hà Nội
  Set<Marker> _markers = {};
  Map<String, StreamSubscription> _locationStreams = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      await _getCurrentLocation();
      _listenToFriendsLocations();
    } catch (e) {
      print('Lỗi khởi tạo map: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (var subscription in _locationStreams.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _listenToFriendsLocations() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final friendsRef = FirebaseDatabase.instance.ref('users/${user.uid}/friends');
    friendsRef.onValue.listen((event) {
      final friends = event.snapshot.value as Map?;
      if (friends != null) {
        for (final friendId in friends.keys) {
          _listenToFriendLocation(friendId);
        }
      }
    });
  }

  void _listenToFriendLocation(String friendId) async {
    _locationStreams[friendId]?.cancel();
    final locationRef = FirebaseDatabase.instance.ref('locations/$friendId');
    final onlineRef = FirebaseDatabase.instance.ref('online/$friendId');
    final userSnap = await FirebaseDatabase.instance.ref('users/$friendId').get();
    final friendEmail = userSnap.child('email').value?.toString() ?? friendId;

    StreamSubscription? onlineSub;
    StreamSubscription? locationSub;

    void updateMarker(bool isOnline, DataSnapshot? locationSnap) {
      if (isOnline && locationSnap != null && locationSnap.exists) {
        final data = locationSnap.value as Map;
        final lat = data['lat'] as double? ?? (data['lat'] as num).toDouble();
        final lng = data['lng'] as double? ?? (data['lng'] as num).toDouble();
        final LatLng friendPos = LatLng(lat, lng);
        setState(() {
          _markers.removeWhere((marker) => marker.markerId.value == 'friend_$friendId');
          _markers.add(
            Marker(
              markerId: MarkerId('friend_$friendId'),
              position: friendPos,
              infoWindow: InfoWindow(title: 'Bạn bè: $friendEmail'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            ),
          );
        });
      } else {
        setState(() {
          _markers.removeWhere((marker) => marker.markerId.value == 'friend_$friendId');
        });
      }
    }

    bool isOnline = false;
    DataSnapshot? lastLocationSnap;

    onlineSub = onlineRef.onValue.listen((event) {
      isOnline = event.snapshot.value == true;
      updateMarker(isOnline, lastLocationSnap);
    });

    locationSub = locationRef.onValue.listen((event) {
      lastLocationSnap = event.snapshot;
      updateMarker(isOnline, lastLocationSnap);
    });

    _locationStreams[friendId]?.cancel();
    _locationStreams[friendId] = StreamGroup.merge([onlineSub!, locationSub!]).listen((_) {});
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng bật GPS để sử dụng tính năng này'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _currentPosition = _defaultCenter;
          _markers = {
            Marker(
              markerId: const MarkerId('default'),
              position: _defaultCenter,
              infoWindow: const InfoWindow(title: 'Vị trí mặc định'),
            ),
          };
        });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cần quyền truy cập vị trí để hiển thị bản đồ'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _currentPosition = _defaultCenter;
          _markers = {
            Marker(
              markerId: const MarkerId('default'),
              position: _defaultCenter,
              infoWindow: const InfoWindow(title: 'Vị trí mặc định'),
            ),
          };
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        _markers = {
          Marker(
            markerId: const MarkerId('me'),
            position: LatLng(pos.latitude, pos.longitude),
            infoWindow: const InfoWindow(title: 'Vị trí của tôi'),
          ),
        };
      });
      if (mounted && mapController != null) {
        try {
          mapController?.animateCamera(
            CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
          );
        } catch (e) {
          print('Lỗi di chuyển camera: $e');
        }
      }
    } catch (e) {
      print('Lỗi lấy vị trí: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể lấy vị trí: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _currentPosition = _defaultCenter;
        _markers = {
          Marker(
            markerId: const MarkerId('default'),
            position: _defaultCenter,
            infoWindow: const InfoWindow(title: 'Vị trí mặc định'),
          ),
        };
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_currentPosition != null) {
      mapController?.moveCamera(
        CameraUpdate.newLatLng(_currentPosition!),
      );
    }
  }

  Future<void> _showFriendOnMap(String friendId, String friendEmail) async {
    final locSnap = await FirebaseDatabase.instance.ref('locations/$friendId').get();
    if (locSnap.exists) {
      final data = locSnap.value as Map;
      final lat = data['lat'] as double? ?? (data['lat'] as num).toDouble();
      final lng = data['lng'] as double? ?? (data['lng'] as num).toDouble();
      final LatLng friendPos = LatLng(lat, lng);
      setState(() {
        _markers.add(
          Marker(
            markerId: MarkerId('friend_$friendId'),
            position: friendPos,
            infoWindow: InfoWindow(title: 'Bạn bè: $friendEmail'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
        );
      });
      mapController?.animateCamera(CameraUpdate.newLatLngZoom(friendPos, 18));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$friendEmail chưa chia sẻ vị trí!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ Google Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group, size: 26),
            tooltip: 'Danh sách bạn bè',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FriendsListPage()),
              );
              if (result != null && result is Map && result['userId'] != null) {
                await _showFriendOnMap(result['userId'], result['email'] ?? '');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications, size: 26),
            tooltip: 'Lời mời kết bạn',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FriendRequestsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 28),
            tooltip: 'Tìm bạn bè',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FriendSearchPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30),
            tooltip: 'Trang cá nhân',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserProfilePage()),
              );
            },
          ),
        ],
        backgroundColor: Colors.blue,
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition ?? _defaultCenter,
                    zoom: 18.0, // Zoom gần hơn
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  markers: _markers,
                ),
                Positioned(
                  bottom: 24,
                  left: 24,
                  child: FloatingActionButton(
                    onPressed: _getCurrentLocation,
                    child: const Icon(Icons.my_location),
                    tooltip: 'Lấy vị trí hiện tại',
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    elevation: 4,
                  ),
                ),
              ],
            ),
    );
  }
} 