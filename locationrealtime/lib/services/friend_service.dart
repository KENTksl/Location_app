import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import '../models/friend.dart';
import '../models/friend_request.dart';
import 'geolocator_wrapper.dart';

class FriendService {
  final FirebaseAuth _auth;
  final FirebaseDatabase _database;
  final GeolocatorWrapper _geolocator;

  // Constructor with dependency injection for better testability
  FriendService({
    FirebaseAuth? auth,
    FirebaseDatabase? database,
    GeolocatorWrapper? geolocator,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _database = database ?? FirebaseDatabase.instance,
       _geolocator = geolocator ?? GeolocatorWrapperImpl();

  // Lấy danh sách bạn bè
  Future<List<Friend>> getFriends() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final friendsRef = _database.ref('users/${user.uid}/friends');
      final friendsSnap = await friendsRef.get();

      if (friendsSnap.exists) {
        final friendsData = friendsSnap.value as Map<dynamic, dynamic>;
        final friendsList = <Friend>[];

        for (final friendId in friendsData.keys) {
          final friendRef = _database.ref('users/$friendId');
          final friendSnap = await friendRef.get();

          if (friendSnap.exists) {
            final friendData = friendSnap.value as Map<dynamic, dynamic>;
            friendsList.add(
              Friend.fromJson({
                'id': friendId,
                'email': friendData['email'] ?? '',
                'avatarUrl': friendData['avatarUrl'],
              }),
            );
          }
        }

        return friendsList;
      }
      return [];
    } catch (e) {
      print('Error getting friends: $e');
      return [];
    }
  }

  // Thêm bạn bè
  Future<void> addFriend(String friendId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Thêm vào danh sách bạn bè của cả hai
      await _database.ref('users/${user.uid}/friends/$friendId').set(true);
      await _database.ref('users/$friendId/friends/${user.uid}').set(true);
    } catch (e) {
      print('Error adding friend: $e');
    }
  }

  // Xóa bạn bè
  Future<void> removeFriend(String friendId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Xóa khỏi danh sách bạn bè của cả hai
      await _database.ref('users/${user.uid}/friends/$friendId').remove();
      await _database.ref('users/$friendId/friends/${user.uid}').remove();
    } catch (e) {
      print('Error removing friend: $e');
    }
  }

  // Gửi lời mời kết bạn
  Future<void> sendFriendRequest(String toUserId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _database.ref('friend_requests/$toUserId/${user.uid}').set({
        'from': user.uid,
        'email': user.email,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Error sending friend request: $e');
    }
  }

  // Lấy danh sách lời mời kết bạn
  Future<List<FriendRequest>> getFriendRequests() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final requestsRef = _database.ref('friend_requests/${user.uid}');
      final requestsSnap = await requestsRef.get();

      if (requestsSnap.exists) {
        final requestsData = requestsSnap.value as Map<dynamic, dynamic>;
        final requestsList = <FriendRequest>[];

        for (final requestId in requestsData.keys) {
          final requestData = requestsData[requestId] as Map<dynamic, dynamic>;
          final senderRef = _database.ref('users/$requestId');
          final senderSnap = await senderRef.get();

          if (senderSnap.exists) {
            final senderData = senderSnap.value as Map<dynamic, dynamic>;
            requestsList.add(
              FriendRequest.fromJson({
                'id': requestId,
                'email': senderData['email'] ?? '',
                'avatarUrl': senderData['avatarUrl'],
              }),
            );
          }
        }

        return requestsList;
      }
      return [];
    } catch (e) {
      print('Error getting friend requests: $e');
      return [];
    }
  }

  // Chấp nhận lời mời kết bạn
  Future<void> acceptFriendRequest(String fromUserId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Thêm vào danh sách bạn bè của cả hai
      await _database.ref('users/${user.uid}/friends/$fromUserId').set(true);
      await _database.ref('users/$fromUserId/friends/${user.uid}').set(true);

      // Xóa lời mời
      await _database.ref('friend_requests/${user.uid}/$fromUserId').remove();
    } catch (e) {
      print('Error accepting friend request: $e');
    }
  }

  // Từ chối lời mời kết bạn
  Future<void> rejectFriendRequest(String fromUserId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _database.ref('friend_requests/${user.uid}/$fromUserId').remove();
    } catch (e) {
      print('Error rejecting friend request: $e');
    }
  }

  // Tính khoảng cách giữa hai điểm
  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return _geolocator.distanceBetween(lat1, lng1, lat2, lng2) /
        1000; // Convert to km
  }

  // Lắng nghe thay đổi vị trí của bạn bè
  Stream<Map<String, dynamic>?> listenToFriendLocation(String friendId) {
    return _database.ref('users/$friendId/location').onValue.map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as Map<String, dynamic>?;
      }
      return null;
    });
  }

  // Lắng nghe thay đổi avatar của bạn bè
  Stream<String?> listenToFriendAvatar(String friendId) {
    return _database.ref('users/$friendId/avatarUrl').onValue.map((event) {
      if (event.snapshot.exists) {
        return event.snapshot.value as String?;
      }
      return null;
    });
  }

  // Lắng nghe thay đổi danh sách bạn bè
  Stream<void> listenToFriendsChanges() {
    final user = _auth.currentUser;
    if (user == null) return Stream.empty();

    return _database.ref('users/${user.uid}/friends').onValue.map((event) {
      // Chỉ trả về void để trigger rebuild
    });
  }
}
