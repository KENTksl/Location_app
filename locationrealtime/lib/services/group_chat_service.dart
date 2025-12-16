import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/chat_message.dart';

class GroupChatService {
  final FirebaseAuth _auth;
  final FirebaseDatabase _database;

  GroupChatService({FirebaseAuth? auth, FirebaseDatabase? database})
    : _auth = auth ?? FirebaseAuth.instance,
      _database = database ?? FirebaseDatabase.instance;

  Future<String?> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final groupId = DateTime.now().millisecondsSinceEpoch.toString();
    final members = <String, bool>{};
    for (final id in {...memberIds, user.uid}) {
      members[id] = true;
    }

    final groupRef = _database.ref('group_chats/$groupId');
    final userGroupsRef = _database.ref('users/${user.uid}/groups/$groupId');

    try {
      await groupRef.set({
        'id': groupId,
        'name': name,
        'createdBy': user.uid,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'members': members,
      });

      // Index nhóm theo user để dễ lấy danh sách nhóm
      await userGroupsRef.set(true);
      for (final id in memberIds) {
        await _database.ref('users/$id/groups/$groupId').set(true);
      }

      return groupId;
    } catch (e) {
      print('Error creating group: $e');
      return null;
    }
  }

  Stream<List<Map>> listenToMessages(String groupId) {
    final ref = _database.ref('group_chats/$groupId/messages');
    return ref.onValue.map((event) {
      final data = event.snapshot.value as List?;
      if (data == null) return <Map>[];
      return data.whereType<Map>().map((m) {
        final mm = Map<String, dynamic>.from(m);
        mm['chatId'] = groupId;
        return mm;
      }).toList();
    });
  }

  Future<void> sendMessage(String groupId, String text) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _database.ref('group_chats/$groupId/messages');
    try {
      final snap = await ref.get();
      List msgs = [];
      if (snap.exists && snap.value is List) {
        msgs = List.from(snap.value as List);
      }
      if (msgs.length >= 50) {
        msgs = msgs.sublist(msgs.length - 49);
      }

      msgs.add({
        'from': user.uid,
        'text': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'readBy': {user.uid: true},
      });
      await ref.set(msgs);
    } catch (e) {
      print('Error sending group message: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserGroups() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final groupsIndexRef = _database.ref('users/${user.uid}/groups');
      final indexSnap = await groupsIndexRef.get();
      final groups = <Map<String, dynamic>>[];

      if (indexSnap.exists && indexSnap.value is Map) {
        final groupIds = (indexSnap.value as Map).keys;
        for (final groupId in groupIds) {
          final groupRef = _database.ref('group_chats/$groupId');
          final groupSnap = await groupRef.get();
          if (groupSnap.exists) {
            final data = Map<String, dynamic>.from(groupSnap.value as Map);
            groups.add({
              'id': data['id'],
              'name': data['name'],
              'createdBy': data['createdBy'],
              'members': Map<String, bool>.from(data['members']),
            });
          }
        }
      }
      return groups;
    } catch (e) {
      print('Error fetching user groups: $e');
      return [];
    }
  }

  Future<ChatMessage?> getLastMessage(String groupId) async {
    try {
      final ref = _database.ref('group_chats/$groupId/messages');
      final snap = await ref.get();
      if (snap.exists && snap.value is List) {
        final messages = snap.value as List;
        if (messages.isNotEmpty) {
          final lastMsg = messages.last as Map;
          return ChatMessage.fromJson({...lastMsg, 'chatId': groupId});
        }
      }
      return null;
    } catch (e) {
      print('Error getting last group message: $e');
      return null;
    }
  }

  Stream<List<Map>> listenToRawMessages(String groupId) {
    final ref = _database.ref('group_chats/$groupId/messages');
    return ref.onValue.map((event) {
      final data = event.snapshot.value as List?;
      if (data != null) {
        return data.whereType<Map>().toList();
      }
      return <Map>[];
    });
  }

  Future<bool> leaveGroup(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final createdBySnap = await _database
          .ref('group_chats/$groupId/createdBy')
          .get();
      final createdBy = createdBySnap.value?.toString();
      if (createdBy == user.uid) {
        return false;
      }
      await _database.ref('group_chats/$groupId/members/${user.uid}').remove();
      await _database.ref('users/${user.uid}/groups/$groupId').remove();
      await _database.ref('users/${user.uid}/pinned_groups/$groupId').remove();
      String label = user.uid;
      try {
        final usnap = await _database.ref('users/${user.uid}').get();
        label = usnap.child('email').value?.toString() ?? label;
      } catch (_) {}
      await _appendSystemMessage(groupId, '$label đã rời khỏi nhóm chat');
      return true;
    } catch (e) {
      print('Error leaving group: $e');
      return false;
    }
  }

  Future<bool> isGroupPinned(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final ref = _database.ref('users/${user.uid}/pinned_groups/$groupId');
      final snap = await ref.get();
      return snap.exists && snap.value == true;
    } catch (e) {
      print('Error checking pinned status: $e');
      return false;
    }
  }

  Future<void> setGroupPinned(String groupId, bool pinned) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final ref = _database.ref('users/${user.uid}/pinned_groups/$groupId');
      if (pinned) {
        await ref.set(true);
      } else {
        await ref.remove();
      }
    } catch (e) {
      print('Error setting pinned status: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMemberDetails(String groupId) async {
    try {
      final groupRef = _database.ref('group_chats/$groupId/members');
      final snap = await groupRef.get();
      final result = <Map<String, dynamic>>[];
      if (snap.exists && snap.value is Map) {
        final members = Map<String, dynamic>.from(snap.value as Map);
        for (final uid in members.keys) {
          final userSnap = await _database.ref('users/$uid').get();
          String email = uid;
          String? avatarUrl;
          if (userSnap.exists) {
            final data = Map<String, dynamic>.from(userSnap.value as Map);
            email = (data['email']?.toString() ?? email);
            avatarUrl = data['avatarUrl']?.toString();
          }
          result.add({'id': uid, 'email': email, 'avatarUrl': avatarUrl});
        }
      }
      return result;
    } catch (e) {
      print('Error fetching group member details: $e');
      return [];
    }
  }

  Future<bool> isLeader(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final snap = await _database.ref('group_chats/$groupId/createdBy').get();
      final createdBy = snap.value?.toString();
      return createdBy == user.uid;
    } catch (e) {
      print('Error checking leader: $e');
      return false;
    }
  }

  Future<bool> renameGroup(String groupId, String newName) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final createdBySnap = await _database
          .ref('group_chats/$groupId/createdBy')
          .get();
      if (createdBySnap.value?.toString() != user.uid) {
        return false;
      }
      await _database.ref('group_chats/$groupId/name').set(newName);
      return true;
    } catch (e) {
      print('Error renaming group: $e');
      return false;
    }
  }

  Future<bool> transferLeadership(String groupId, String newLeaderId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final createdBySnap = await _database
          .ref('group_chats/$groupId/createdBy')
          .get();
      if (createdBySnap.value?.toString() != user.uid) {
        return false;
      }
      // Ensure new leader is a member
      final memberSnap = await _database
          .ref('group_chats/$groupId/members/$newLeaderId')
          .get();
      if (!memberSnap.exists) {
        return false;
      }
      await _database.ref('group_chats/$groupId/createdBy').set(newLeaderId);
      return true;
    } catch (e) {
      print('Error transferring leadership: $e');
      return false;
    }
  }

  Future<bool> dissolveGroup(String groupId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final createdBySnap = await _database
          .ref('group_chats/$groupId/createdBy')
          .get();
      if (createdBySnap.value?.toString() != user.uid) {
        return false;
      }
      // Get members
      final membersSnap = await _database
          .ref('group_chats/$groupId/members')
          .get();
      final members = <String>[];
      if (membersSnap.exists && membersSnap.value is Map) {
        final m = Map<String, dynamic>.from(membersSnap.value as Map);
        members.addAll(m.keys);
      }
      // Remove group index for each member
      for (final uid in members) {
        await _database.ref('users/$uid/groups/$groupId').remove();
        await _database.ref('users/$uid/pinned_groups/$groupId').remove();
      }
      // Remove group node
      await _database.ref('group_chats/$groupId').remove();
      return true;
    } catch (e) {
      print('Error dissolving group: $e');
      return false;
    }
  }

  Future<void> _appendSystemMessage(String groupId, String text) async {
    final ref = _database.ref('group_chats/$groupId/messages');
    try {
      final snap = await ref.get();
      List msgs = [];
      if (snap.exists && snap.value is List) {
        msgs = List.from(snap.value as List);
      }
      if (msgs.length >= 50) {
        msgs = msgs.sublist(msgs.length - 49);
      }
      msgs.add({
        'type': 'system',
        'text': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await ref.set(msgs);
    } catch (e) {
      print('Error appending system message: $e');
    }
  }

  Future<bool> removeMember(String groupId, String memberId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      // Only leader can remove
      final createdBySnap = await _database
          .ref('group_chats/$groupId/createdBy')
          .get();
      if (createdBySnap.value?.toString() != user.uid) {
        return false;
      }
      // Cannot remove self via this API
      if (memberId == user.uid) return false;
      await _database.ref('group_chats/$groupId/members/$memberId').remove();
      await _database.ref('users/$memberId/groups/$groupId').remove();
      await _database.ref('users/$memberId/pinned_groups/$groupId').remove();
      String label = memberId;
      try {
        final usnap = await _database.ref('users/$memberId').get();
        label = usnap.child('email').value?.toString() ?? label;
      } catch (_) {}
      await _appendSystemMessage(groupId, '$label đã bị đuổi khỏi nhóm chat');
      return true;
    } catch (e) {
      print('Error removing member: $e');
      return false;
    }
  }

  Future<void> sendFavoritePlace(
    String groupId, {
    required String name,
    required String address,
    required double lat,
    required double lng,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _database.ref('group_chats/$groupId/messages');
    try {
      final snap = await ref.get();
      List msgs = [];
      if (snap.exists && snap.value is List) {
        msgs = List.from(snap.value as List);
      }
      if (msgs.length >= 50) {
        msgs = msgs.sublist(msgs.length - 49);
      }
      msgs.add({
        'from': user.uid,
        'type': 'favorite_place',
        'place': {'name': name, 'address': address, 'lat': lat, 'lng': lng},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'readBy': {user.uid: true},
      });
      await ref.set(msgs);
    } catch (e) {
      print('Error sending favorite place to group: $e');
    }
  }

  Future<void> sendRouteMessageData(
    String groupId, {
    required Map<String, dynamic> routeData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _database.ref('group_chats/$groupId/messages');
    try {
      final snap = await ref.get();
      List msgs = [];
      if (snap.exists && snap.value is List) {
        msgs = List.from(snap.value as List);
      }
      if (msgs.length >= 50) {
        msgs = msgs.sublist(msgs.length - 49);
      }
      msgs.add({
        'from': user.uid,
        'type': 'route_share',
        'routeData': routeData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'readBy': {user.uid: true},
      });
      await ref.set(msgs);
    } catch (e) {
      print('Error sending route to group: $e');
    }
  }
}
