import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'friend_search_page.dart';
import 'user_profile_page.dart';
import 'package:random_avatar/random_avatar.dart';
import 'chat_page.dart';
import 'group_chat_page.dart';
import '../services/group_chat_service.dart';
import 'dart:async'; // Import for StreamSubscription
import 'main_navigation_page.dart'; // Added import for MainNavigationPage
import '../services/unread_message_service.dart';
import '../theme.dart';
import '../widgets/skeletons.dart';
import '../services/toast_service.dart';

class FriendsListPage extends StatefulWidget {
  const FriendsListPage({super.key});

  @override
  State<FriendsListPage> createState() => _FriendsListPageState();
}

class _FriendsListPageState extends State<FriendsListPage> {
  String? _userAvatarUrl;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  final Map<String, StreamSubscription> _friendAvatarSubscriptions = {};
  String _searchQuery = '';
  String? _userEmail;

  // Location tracking variables
  Position? _currentPosition;
  final Map<String, double> _friendDistances = {};
  final Map<String, StreamSubscription> _friendLocationSubscriptions = {};
  Timer? _distanceUpdateTimer;

  // Nickname storage
  final Map<String, String> _friendNicknames = {};

  // Unread message service
  final UnreadMessageService _unreadMessageService = UnreadMessageService();
  final Map<String, int> _unreadCounts = {};
  // Groups
  List<Map<String, dynamic>> _groups = [];
  bool _isGroupsLoading = true;
  final Map<String, StreamSubscription> _groupMessageSubscriptions = {};
  final Map<String, String> _userEmailCache = {};
  final Map<String, StreamSubscription> _groupMetaSubscriptions = {};

  // Hiển thị hộp thoại xác nhận xóa kết bạn
  void _showDeleteFriendDialog(Map<String, dynamic> friend) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xóa kết bạn'),
          content: Text(
            'Bạn có chắc chắn muốn xóa kết bạn với ${friend['email'].split('@')[0]}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                _deleteFriend(friend['id']);
                Navigator.of(context).pop();
              },
              child: const Text(
                'Xóa',
                style: TextStyle(color: Color(0xFFef4444)),
              ),
            ),
          ],
        );
      },
    );
  }

  // Xử lý xóa kết bạn
  Future<void> _deleteFriend(String friendId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Xóa bạn bè từ danh sách của người dùng hiện tại
        await FirebaseDatabase.instance
            .ref('users/${user.uid}/friends/$friendId')
            .remove();

        // Xóa người dùng hiện tại từ danh sách bạn bè của người bạn
        await FirebaseDatabase.instance
            .ref('users/$friendId/friends/${user.uid}')
            .remove();

        // Cập nhật UI
        setState(() {
          _friends.removeWhere((friend) => friend['id'] == friendId);
        });

        ToastService.show(
          context,
          message: 'Đã xóa kết bạn thành công',
          type: AppToastType.success,
        );
      }
    } catch (e) {
      ToastService.show(
        context,
        message: 'Không thể xóa kết bạn. Vui lòng thử lại.',
        type: AppToastType.error,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadFriends();
    _loadFriendRequests();
    _listenToFriendsChanges();
    _getCurrentLocation();
    _startDistanceUpdateTimer();
    _loadNicknames();
    _listenToUnreadMessages();
    _loadGroups();
    _listenToGroupsChanges();
  }

  @override
  void dispose() {
    // Hủy tất cả subscriptions
    for (var subscription in _friendAvatarSubscriptions.values) {
      subscription.cancel();
    }
    for (var subscription in _friendLocationSubscriptions.values) {
      subscription.cancel();
    }
    for (var subscription in _groupMessageSubscriptions.values) {
      subscription.cancel();
    }
    for (var subscription in _groupMetaSubscriptions.values) {
      subscription.cancel();
    }
    _distanceUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email;
      });

      // Load avatar
      final avatarRef = FirebaseDatabase.instance.ref(
        'users/${user.uid}/avatarUrl',
      );
      final avatarSnap = await avatarRef.get();
      if (avatarSnap.exists) {
        setState(() {
          _userAvatarUrl = avatarSnap.value as String?;
        });
      }

      // Lắng nghe thay đổi avatar
      avatarRef.onValue.listen((event) {
        if (event.snapshot.exists && mounted) {
          setState(() {
            _userAvatarUrl = event.snapshot.value as String?;
          });
        }
      });
    }
  }

  Future<void> _loadFriends() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Hủy tất cả subscriptions cũ
    for (var subscription in _friendAvatarSubscriptions.values) {
      subscription.cancel();
    }
    _friendAvatarSubscriptions.clear();

    // Thử load theo cấu trúc cũ trước
    final friendsRef = FirebaseDatabase.instance.ref(
      'users/${user.uid}/friends',
    );
    final friendsSnap = await friendsRef.get();

    if (friendsSnap.exists) {
      final friendsData = friendsSnap.value as Map<dynamic, dynamic>;
      final friendsList = <Map<String, dynamic>>[];

      for (final friendId in friendsData.keys) {
        final friendRef = FirebaseDatabase.instance.ref('users/$friendId');
        final friendSnap = await friendRef.get();

        if (friendSnap.exists) {
          final friendData = friendSnap.value as Map<dynamic, dynamic>;
          friendsList.add({
            'id': friendId,
            'email': friendData['email'] ?? '',
            'avatarUrl': friendData['avatarUrl'],
            'isOnline': false,
          });

          // Lắng nghe thay đổi avatar của bạn bè
          _listenToFriendAvatar(friendId);
        }
      }

      setState(() {
        _friends = friendsList;
        _isLoading = false;
      });

      // Khởi tạo khoảng cách cho tất cả bạn bè
      if (_currentPosition != null) {
        _updateAllFriendDistances();
      }
    } else {
      // Thử load theo cấu trúc mới
      final newFriendsRef = FirebaseDatabase.instance.ref(
        'friends/${user.uid}',
      );
      final newFriendsSnap = await newFriendsRef.get();

      if (newFriendsSnap.exists) {
        final friendsData = newFriendsSnap.value as Map<dynamic, dynamic>;
        final friendsList = <Map<String, dynamic>>[];

        for (final friendId in friendsData.keys) {
          final friendRef = FirebaseDatabase.instance.ref('users/$friendId');
          final friendSnap = await friendRef.get();

          if (friendSnap.exists) {
            final friendData = friendSnap.value as Map<dynamic, dynamic>;
            friendsList.add({
              'id': friendId,
              'email': friendData['email'] ?? '',
              'avatarUrl': friendData['avatarUrl'],
              'isOnline': false,
            });

            // Lắng nghe thay đổi avatar của bạn bè
            _listenToFriendAvatar(friendId);
          }
        }

        setState(() {
          _friends = friendsList;
          _isLoading = false;
        });

        // Khởi tạo khoảng cách cho tất cả bạn bè
        if (_currentPosition != null) {
          _updateAllFriendDistances();
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _listenToFriendAvatar(String friendId) {
    final avatarRef = FirebaseDatabase.instance.ref(
      'users/$friendId/avatarUrl',
    );
    final subscription = avatarRef.onValue.listen((event) {
      if (event.snapshot.exists && mounted) {
        print(
          'Friends: Friend $friendId avatar updated to: ${event.snapshot.value}',
        );
        setState(() {
          // Cập nhật avatar trong danh sách bạn bè
          final friendIndex = _friends.indexWhere(
            (friend) => friend['id'] == friendId,
          );
          if (friendIndex != -1) {
            _friends[friendIndex]['avatarUrl'] =
                event.snapshot.value as String?;
          }
        });
      }
    });

    _friendAvatarSubscriptions[friendId] = subscription;
  }

  Future<void> _loadGroups() async {
    final service = GroupChatService();
    final groups = await service.getUserGroups();
    // fetch last message for each group
    final result = <Map<String, dynamic>>[];
    for (final g in groups) {
      final last = await service.getLastMessage(g['id'] as String);
      final pinned = await service.isGroupPinned(g['id'] as String);
      String? senderLabel;
      if (last != null && (last.from).isNotEmpty) {
        try {
          final usnap = await FirebaseDatabase.instance
              .ref('users/${last.from}')
              .get();
          senderLabel = usnap.child('email').value?.toString() ?? last.from;
        } catch (_) {
          senderLabel = last.from;
        }
      } else if (last != null && (last.text).isNotEmpty) {
        senderLabel = 'Hệ thống';
      }
      result.add({
        'id': g['id'],
        'name': g['name'],
        'members': g['members'],
        'lastText': last?.text ?? 'Chưa có tin nhắn',
        'lastTime': last?.timestamp,
        'pinned': pinned,
        'lastSender': senderLabel,
      });
    }
    if (mounted) {
      setState(() {
        result.sort((a, b) {
          final ap = (a['pinned'] as bool?) == true;
          final bp = (b['pinned'] as bool?) == true;
          if (ap && !bp) return -1;
          if (!ap && bp) return 1;
          final at = (a['lastTime'] as int?) ?? 0;
          final bt = (b['lastTime'] as int?) ?? 0;
          return bt.compareTo(at);
        });
        _groups = result;
        _isGroupsLoading = false;
      });
      _setupGroupMessageListeners(
        _groups.map((e) => e['id'] as String).toList(),
      );
      _setupGroupMetaListeners(_groups.map((e) => e['id'] as String).toList());
    }
  }

  void _listenToGroupsChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = FirebaseDatabase.instance.ref('users/${user.uid}/groups');
    ref.onValue.listen((event) {
      if (mounted) {
        _loadGroups();
      }
    });
  }

  void _setupGroupMessageListeners(List<String> groupIds) {
    final idsSet = groupIds.toSet();
    for (final entry in _groupMessageSubscriptions.entries.toList()) {
      if (!idsSet.contains(entry.key)) {
        entry.value.cancel();
        _groupMessageSubscriptions.remove(entry.key);
      }
    }
    for (final gid in groupIds) {
      if (_groupMessageSubscriptions.containsKey(gid)) continue;
      final sub = FirebaseDatabase.instance
          .ref('group_chats/$gid/messages')
          .onValue
          .listen((event) async {
            final data = event.snapshot.value as List?;
            Map<dynamic, dynamic>? last;
            if (data != null && data.isNotEmpty) {
              for (int i = data.length - 1; i >= 0; i--) {
                final v = data[i];
                if (v is Map) {
                  last = v;
                  break;
                }
              }
            }
            String lastText = 'Chưa có tin nhắn';
            int? lastTime;
            String? lastSender;
            if (last != null) {
              final m = Map<String, dynamic>.from(last!);
              lastText =
                  m['text']?.toString() ??
                  (m['type']?.toString() == 'system'
                      ? (m['text']?.toString() ?? 'Hệ thống')
                      : '');
              lastTime = (m['timestamp'] is int)
                  ? m['timestamp'] as int
                  : int.tryParse('${m['timestamp']}');
              final from = m['from']?.toString();
              if (from != null && from.isNotEmpty) {
                lastSender = _userEmailCache[from];
                if (lastSender == null) {
                  try {
                    final usnap = await FirebaseDatabase.instance
                        .ref('users/$from')
                        .get();
                    lastSender = usnap.child('email').value?.toString() ?? from;
                    _userEmailCache[from] = lastSender!;
                  } catch (_) {
                    lastSender = from;
                  }
                }
              } else {
                lastSender = 'Hệ thống';
              }
            }
            if (!mounted) return;
            setState(() {
              final idx = _groups.indexWhere((g) => g['id'] == gid);
              if (idx != -1) {
                _groups[idx]['lastText'] = lastText;
                _groups[idx]['lastTime'] = lastTime;
                _groups[idx]['lastSender'] = lastSender;
                _groups.sort((a, b) {
                  final ap = (a['pinned'] as bool?) == true;
                  final bp = (b['pinned'] as bool?) == true;
                  if (ap && !bp) return -1;
                  if (!ap && bp) return 1;
                  final at = (a['lastTime'] as int?) ?? 0;
                  final bt = (b['lastTime'] as int?) ?? 0;
                  return bt.compareTo(at);
                });
              }
            });
          });
      _groupMessageSubscriptions[gid] = sub;
    }
  }

  void _setupGroupMetaListeners(List<String> groupIds) {
    final idsSet = groupIds.toSet();
    for (final entry in _groupMetaSubscriptions.entries.toList()) {
      if (!idsSet.contains(entry.key)) {
        entry.value.cancel();
        _groupMetaSubscriptions.remove(entry.key);
      }
    }
    for (final gid in groupIds) {
      if (_groupMetaSubscriptions.containsKey(gid)) continue;
      final sub = FirebaseDatabase.instance
          .ref('group_chats/$gid')
          .onValue
          .listen((event) {
            if (!mounted) return;
            if (!event.snapshot.exists || event.snapshot.value is! Map) {
              setState(() {
                _groups.removeWhere((g) => g['id'] == gid);
              });
              // Hủy các subscriptions liên quan đến nhóm đã bị xoá
              _groupMetaSubscriptions.remove(gid)?.cancel();
              _groupMessageSubscriptions.remove(gid)?.cancel();
              return;
            }
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);
            final rawName = data['name'];
            final newName = rawName is String ? rawName : rawName?.toString();
            final createdBy = data['createdBy']?.toString();
            final membersRaw = data['members'];
            final members = (membersRaw is Map)
                ? Map<String, bool>.from(membersRaw as Map)
                : <String, bool>{};
            setState(() {
              final idx = _groups.indexWhere((g) => g['id'] == gid);
              if (idx != -1) {
                if (data.containsKey('name') &&
                    newName != null &&
                    newName.trim().isNotEmpty) {
                  _groups[idx]['name'] = newName.trim();
                }
                if (data.containsKey('createdBy') && createdBy != null) {
                  _groups[idx]['createdBy'] = createdBy;
                }
                if (data.containsKey('members') && members.isNotEmpty) {
                  _groups[idx]['members'] = members;
                }
              }
            });
          });
      _groupMetaSubscriptions[gid] = sub;
    }
  }

  Widget _buildGroupSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, color: Color(0xFF667eea)),
              const SizedBox(width: 8),
              const Text(
                'Tin nhắn nhóm',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1e293b),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _openCreateGroupSheet,
                child: const Text('Tạo nhóm'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: _isGroupsLoading
                ? const Center(child: CircularProgressIndicator())
                : _groups.isEmpty
                ? const Center(child: Text('Chưa có nhóm'))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      final g = _groups[index];
                      final nameRaw = g['name'] as String?;
                      final name = (nameRaw == null || nameRaw.trim().isEmpty)
                          ? 'Nhóm'
                          : nameRaw;
                      final lastText = g['lastText'] as String? ?? '';
                      final members = Map<String, bool>.from(
                        (g['members'] as Map),
                      );
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupChatPage(
                                groupId: g['id'] as String,
                                groupName: name,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 220,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if ((g['pinned'] as bool?) == true)
                                    const Icon(
                                      Icons.push_pin_rounded,
                                      size: 16,
                                      color: Color(0xFFf59e0b),
                                    ),
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1e293b),
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    onSelected: (value) async {
                                      final svc = GroupChatService();
                                      final id = g['id'] as String;
                                      final currentUid = FirebaseAuth
                                          .instance
                                          .currentUser
                                          ?.uid;
                                      final isLeader =
                                          g['createdBy']?.toString() ==
                                          (currentUid ?? '');
                                      if (value == 'pin') {
                                        await svc.setGroupPinned(id, true);
                                        ToastService.show(
                                          context,
                                          message: 'Đã ghim cuộc trò chuyện',
                                          type: AppToastType.success,
                                        );
                                        await _loadGroups();
                                      } else if (value == 'unpin') {
                                        await svc.setGroupPinned(id, false);
                                        ToastService.show(
                                          context,
                                          message: 'Đã bỏ ghim cuộc trò chuyện',
                                          type: AppToastType.success,
                                        );
                                        await _loadGroups();
                                      } else if (value == 'rename') {
                                        final controller =
                                            TextEditingController(text: name);
                                        if (!mounted) return;
                                        showDialog(
                                          context: context,
                                          builder: (ctx) {
                                            return AlertDialog(
                                              title: const Text('Đổi tên nhóm'),
                                              content: TextField(
                                                controller: controller,
                                                decoration:
                                                    const InputDecoration(
                                                      hintText: 'Tên nhóm mới',
                                                    ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(ctx).pop();
                                                  },
                                                  child: const Text('Hủy'),
                                                ),
                                                TextButton(
                                                  onPressed: () async {
                                                    final newName = controller
                                                        .text
                                                        .trim();
                                                    if (newName.isEmpty) {
                                                      return;
                                                    }
                                                    final ok = await svc
                                                        .renameGroup(
                                                          id,
                                                          newName,
                                                        );
                                                    Navigator.of(ctx).pop();
                                                    if (ok) {
                                                      ToastService.show(
                                                        context,
                                                        message:
                                                            'Đã đổi tên nhóm',
                                                        type: AppToastType
                                                            .success,
                                                      );
                                                      await _loadGroups();
                                                    } else {
                                                      ToastService.show(
                                                        context,
                                                        message:
                                                            'Bạn không phải trưởng nhóm',
                                                        type:
                                                            AppToastType.error,
                                                      );
                                                    }
                                                  },
                                                  child: const Text('Đổi tên'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      } else if (value == 'view_members') {
                                        final members = await svc
                                            .getMemberDetails(id);
                                        if (!mounted) return;
                                        showDialog(
                                          context: context,
                                          builder: (ctx) {
                                            return AlertDialog(
                                              title: const Text(
                                                'Thành viên nhóm',
                                              ),
                                              content: SizedBox(
                                                width: double.maxFinite,
                                                child: ListView.builder(
                                                  shrinkWrap: true,
                                                  itemCount: members.length,
                                                  itemBuilder: (ctx, i) {
                                                    final m = members[i];
                                                    final email =
                                                        (m['email']
                                                            as String?) ??
                                                        '';
                                                    final avatarUrl =
                                                        m['avatarUrl']
                                                            as String?;
                                                    final canKick =
                                                        isLeader &&
                                                        m['id'] != currentUid;
                                                    return ListTile(
                                                      leading:
                                                          _buildFriendAvatar(
                                                            avatarUrl,
                                                            email,
                                                          ),
                                                      title: Text(
                                                        email.split('@')[0],
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      subtitle: Text(
                                                        email,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      trailing: canKick
                                                          ? TextButton(
                                                              onPressed: () async {
                                                                final ok = await svc
                                                                    .removeMember(
                                                                      id,
                                                                      m['id']
                                                                          as String,
                                                                    );
                                                                Navigator.of(
                                                                  ctx,
                                                                ).pop();
                                                                if (ok) {
                                                                  ToastService.show(
                                                                    context,
                                                                    message:
                                                                        'Đã đuổi thành viên',
                                                                    type: AppToastType
                                                                        .success,
                                                                  );
                                                                  await _loadGroups();
                                                                } else {
                                                                  ToastService.show(
                                                                    context,
                                                                    message:
                                                                        'Bạn không phải trưởng nhóm',
                                                                    type: AppToastType
                                                                        .error,
                                                                  );
                                                                }
                                                              },
                                                              child: const Text(
                                                                'Đuổi',
                                                                style: TextStyle(
                                                                  color: Color(
                                                                    0xFFdc2626,
                                                                  ),
                                                                ),
                                                              ),
                                                            )
                                                          : null,
                                                    );
                                                  },
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(ctx).pop();
                                                  },
                                                  child: const Text('Đóng'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      } else if (value == 'transfer') {
                                        final members = await svc
                                            .getMemberDetails(id);
                                        final candidates = members
                                            .where((m) => m['id'] != currentUid)
                                            .toList();
                                        if (!mounted) return;
                                        showDialog(
                                          context: context,
                                          builder: (dctx) {
                                            return AlertDialog(
                                              title: const Text(
                                                'Chọn người nhận chìa khóa',
                                              ),
                                              content: SizedBox(
                                                width: double.maxFinite,
                                                child: ListView.builder(
                                                  shrinkWrap: true,
                                                  itemCount: candidates.length,
                                                  itemBuilder: (ctx2, i) {
                                                    final m = candidates[i];
                                                    final email =
                                                        (m['email']
                                                            as String?) ??
                                                        m['id'];
                                                    final avatarUrl =
                                                        m['avatarUrl']
                                                            as String?;
                                                    final uid =
                                                        m['id'] as String;
                                                    return ListTile(
                                                      leading:
                                                          _buildFriendAvatar(
                                                            avatarUrl,
                                                            email ?? uid,
                                                          ),
                                                      title: Text(
                                                        (email ?? uid).split(
                                                          '@',
                                                        )[0],
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      subtitle: Text(
                                                        email ?? uid,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      onTap: () async {
                                                        final ok = await svc
                                                            .transferLeadership(
                                                              id,
                                                              uid,
                                                            );
                                                        Navigator.of(
                                                          dctx,
                                                        ).pop();
                                                        if (ok) {
                                                          ToastService.show(
                                                            context,
                                                            message:
                                                                'Đã chuyển trưởng nhóm',
                                                            type: AppToastType
                                                                .success,
                                                          );
                                                          await _loadGroups();
                                                        } else {
                                                          ToastService.show(
                                                            context,
                                                            message:
                                                                'Không thể chuyển trưởng nhóm',
                                                            type: AppToastType
                                                                .error,
                                                          );
                                                        }
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(dctx).pop(),
                                                  child: const Text('Đóng'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      } else if (value == 'dissolve') {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (dctx) {
                                            return AlertDialog(
                                              title: const Text(
                                                'Xác nhận tan rã nhóm',
                                              ),
                                              content: const Text(
                                                'Tất cả thành viên sẽ bị xóa khỏi nhóm. Bạn có chắc?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    dctx,
                                                  ).pop(false),
                                                  child: const Text('Hủy'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    dctx,
                                                  ).pop(true),
                                                  child: const Text('Tan rã'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                        if (confirmed == true) {
                                          final ok = await svc.dissolveGroup(
                                            id,
                                          );
                                          if (ok) {
                                            ToastService.show(
                                              context,
                                              message: 'Nhóm đã tan rã',
                                              type: AppToastType.success,
                                            );
                                            await _loadGroups();
                                          } else {
                                            ToastService.show(
                                              context,
                                              message: 'Không thể tan rã nhóm',
                                              type: AppToastType.error,
                                            );
                                          }
                                        }
                                      } else if (value == 'leave') {
                                        final ok = await svc.leaveGroup(id);
                                        if (ok) {
                                          ToastService.show(
                                            context,
                                            message: 'Đã rời cuộc trò chuyện',
                                            type: AppToastType.success,
                                          );
                                          await _loadGroups();
                                        } else {
                                          ToastService.show(
                                            context,
                                            message:
                                                'Bạn là trưởng nhóm. Hãy chuyển nhượng chủ nhóm.',
                                            type: AppToastType.warning,
                                          );
                                        }
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      PopupMenuItem<String>(
                                        value: ((g['pinned'] as bool?) == true)
                                            ? 'unpin'
                                            : 'pin',
                                        child: Text(
                                          ((g['pinned'] as bool?) == true)
                                              ? 'Bỏ ghim'
                                              : 'Ghim cuộc trò chuyện',
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      if ((g['createdBy']?.toString() ?? '') ==
                                          (FirebaseAuth
                                                  .instance
                                                  .currentUser
                                                  ?.uid ??
                                              ''))
                                        const PopupMenuItem<String>(
                                          value: 'rename',
                                          child: Text('Đổi tên nhóm'),
                                        ),
                                      if ((g['createdBy']?.toString() ?? '') ==
                                          (FirebaseAuth
                                                  .instance
                                                  .currentUser
                                                  ?.uid ??
                                              ''))
                                        const PopupMenuDivider(),
                                      const PopupMenuItem<String>(
                                        value: 'view_members',
                                        child: Text('Xem thành viên'),
                                      ),
                                      const PopupMenuDivider(),
                                      if ((g['createdBy']?.toString() ?? '') !=
                                          (FirebaseAuth
                                                  .instance
                                                  .currentUser
                                                  ?.uid ??
                                              ''))
                                        const PopupMenuItem<String>(
                                          value: 'leave',
                                          child: Text('Rời cuộc trò chuyện'),
                                        ),
                                      if ((g['createdBy']?.toString() ?? '') ==
                                          (FirebaseAuth
                                                  .instance
                                                  .currentUser
                                                  ?.uid ??
                                              ''))
                                        const PopupMenuItem<String>(
                                          value: 'transfer',
                                          child: Text(
                                            'Chuyển nhượng trưởng nhóm',
                                          ),
                                        ),
                                      if ((g['createdBy']?.toString() ?? '') ==
                                          (FirebaseAuth
                                                  .instance
                                                  .currentUser
                                                  ?.uid ??
                                              ''))
                                        const PopupMenuItem<String>(
                                          value: 'dissolve',
                                          child: Text('Tan rã nhóm'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                (g['lastSender'] != null &&
                                        (g['lastSender'] as String).isNotEmpty)
                                    ? '${g['lastSender']}: $lastText'
                                    : '$lastText',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person_rounded,
                                    size: 14,
                                    color: Color(0xFF6b7280),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${members.length} thành viên',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6b7280),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadFriendRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final requestsRef = FirebaseDatabase.instance.ref(
      'friend_requests/${user.uid}',
    );
    final requestsSnap = await requestsRef.get();

    if (requestsSnap.exists) {
      final requestsData = requestsSnap.value as Map<dynamic, dynamic>;
      final requestsList = <Map<String, dynamic>>[];

      for (final requestId in requestsData.keys) {
        final requestData = requestsData[requestId] as Map<dynamic, dynamic>;
        final senderRef = FirebaseDatabase.instance.ref('users/$requestId');
        final senderSnap = await senderRef.get();

        if (senderSnap.exists) {
          final senderData = senderSnap.value as Map<dynamic, dynamic>;
          requestsList.add({
            'id': requestId,
            'email': senderData['email'] ?? '',
            'avatarUrl': senderData['avatarUrl'],
          });
        }
      }

      setState(() {
        _requests = requestsList;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredFriends {
    if (_searchQuery.isEmpty) {
      return _friends;
    }
    return _friends
        .where(
          (friend) => friend['email'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  Widget _buildUserAvatar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserProfilePage()),
        );
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF10b981), width: 2),
        ),
        child: _userAvatarUrl != null && _userAvatarUrl!.isNotEmpty
            ? (_userAvatarUrl!.startsWith('random:')
                  ? RandomAvatar(
                      _userAvatarUrl!.substring(7),
                      height: 40,
                      width: 40,
                    )
                  : _userAvatarUrl!.startsWith('http')
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: _userAvatarUrl!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => _buildDefaultAvatar(),
                        errorWidget: (context, url, error) =>
                            _buildDefaultAvatar(),
                      ),
                    )
                  : ClipOval(
                      child: Image.file(
                        File(_userAvatarUrl!),
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildDefaultAvatar(),
                      ),
                    ))
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10b981).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _userEmail?.isNotEmpty == true ? _userEmail![0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFF10b981),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFriendAvatar(String? avatarUrl, String email) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('random:')) {
        // Hiển thị random avatar với seed từ avatarUrl
        final seed = avatarUrl.substring(7);
        return RandomAvatar(seed, height: 50, width: 50);
      } else if (avatarUrl.startsWith('http')) {
        // Hiển thị network image
        return ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: CachedNetworkImage(
            imageUrl: avatarUrl,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.grey),
            ),
            errorWidget: (context, url, error) =>
                _buildDefaultFriendAvatar(email),
          ),
        );
      } else {
        // Hiển thị local file
        return ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Image.file(
            File(avatarUrl),
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildDefaultFriendAvatar(email),
          ),
        );
      }
    }
    return _buildDefaultFriendAvatar(email);
  }

  Widget _buildDefaultFriendAvatar(String email) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF10b981), const Color(0xFF059669)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          email.split('@')[0][0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _listenToFriendsChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final friendsRef = FirebaseDatabase.instance.ref(
      'users/${user.uid}/friends',
    );

    friendsRef.onValue.listen((event) {
      if (mounted) {
        // Cập nhật danh sách bạn bè khi có thay đổi
        _loadFriends();
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      // Cập nhật khoảng cách cho tất cả bạn bè
      _updateAllFriendDistances();
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  void _startDistanceUpdateTimer() {
    _distanceUpdateTimer?.cancel();
    _distanceUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentPosition != null) {
        _updateAllFriendDistances();
      }
    });
  }

  void _updateAllFriendDistances() {
    if (_currentPosition == null) return;

    for (final friend in _friends) {
      final friendId = friend['id'] as String;
      _updateFriendDistance(friendId);
    }
  }

  void _updateFriendDistance(String friendId) {
    if (_currentPosition == null) return;

    final locationRef = FirebaseDatabase.instance.ref(
      'users/$friendId/location',
    );

    // Hủy subscription cũ nếu có
    _friendLocationSubscriptions[friendId]?.cancel();

    // Lắng nghe vị trí của bạn bè
    final subscription = locationRef.onValue.listen((event) {
      if (event.snapshot.exists && mounted) {
        final raw = event.snapshot.value;
        if (raw is! Map) {
          setState(() {
            _friendDistances.remove(friendId);
          });
          return;
        }
        final data = raw;
        final latRaw = data['latitude'];
        final lngRaw = data['longitude'];
        double? lat;
        double? lng;
        if (latRaw is num) {
          lat = latRaw.toDouble();
        } else if (latRaw is String) {
          lat = double.tryParse(latRaw);
        }
        if (lngRaw is num) {
          lng = lngRaw.toDouble();
        } else if (lngRaw is String) {
          lng = double.tryParse(lngRaw);
        }
        final isOnline = data['isOnline'] as bool? ?? false;
        final isSharing = data['isSharingLocation'] as bool? ?? false;

        // Kiểm tra cả trạng thái chia sẻ vị trí ở cả hai nơi
        final isSharingLocation =
            isSharing &&
            (data['isSharingLocation'] != false); // Đảm bảo không phải false

        if (lat != null && lng != null && isOnline && isSharingLocation) {
          // Tính khoảng cách
          final distance =
              Geolocator.distanceBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                lat,
                lng,
              ) /
              1000; // Chuyển đổi sang km

          setState(() {
            _friendDistances[friendId] = distance;
          });
        } else {
          setState(() {
            _friendDistances.remove(friendId);
          });
        }
      } else {
        setState(() {
          _friendDistances.remove(friendId);
        });
      }
    });

    _friendLocationSubscriptions[friendId] = subscription;
  }

  String _formatDistance(double? distance) {
    if (distance == null) return 'N/A';
    if (distance < 1) {
      return '${(distance * 1000).toStringAsFixed(0)}m';
    } else {
      return '${distance.toStringAsFixed(1)}km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // Replace intense gradient with soft single-tone pastel
          color: Color(0xFFF7FAFC),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header với avatar user và search
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Top row với avatar và title
                    Row(
                      children: [
                        _buildUserAvatar(),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Bạn bè',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1e293b),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_requests.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFef4444).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.notifications_rounded,
                                  color: Color(0xFFef4444),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_requests.length}',
                                  style: const TextStyle(
                                    color: Color(0xFFef4444),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm bạn bè...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.person_add_rounded),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const FriendSearchPage(),
                                ),
                              );
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const FriendListSkeleton()
                      : _filteredFriends.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'Chưa có bạn bè nào'
                                    : 'Không tìm thấy bạn bè',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const FriendSearchPage(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Thêm bạn bè',
                                    style: TextStyle(color: Color(0xFF667eea)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          itemCount: _filteredFriends.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _buildGroupSection();
                            }
                            final friend = _filteredFriends[index - 1];
                            return Container(
                              // Compact height ~20% smaller via spacing
                              margin: EdgeInsets.only(
                                bottom: AppTheme.verticalCardSpacing,
                              ),
                              padding: EdgeInsets.all(AppTheme.cardPadding),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  // Soft neumorphism shadow at ~6%
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.10),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Main row with avatar and user info
                                  Row(
                                    children: [
                                      // Avatar
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppTheme.primaryColor,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.08,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: _buildFriendAvatar(
                                          friend['avatarUrl'],
                                          friend['email'],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // User info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _getDisplayName(friend),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1e293b),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              friend['email'],
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Bottom row with distance and actions
                                  Row(
                                    children: [
                                      // Distance info
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                _friendDistances[friend['id']] !=
                                                    null
                                                ? const Color(
                                                    0xFF34D399,
                                                  ).withOpacity(0.12)
                                                : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            boxShadow:
                                                _friendDistances[friend['id']] !=
                                                    null
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(
                                                        0xFF10B981,
                                                      ).withOpacity(0.12),
                                                      blurRadius: 8,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.location_on_rounded,
                                                size: 14,
                                                color:
                                                    _friendDistances[friend['id']] !=
                                                        null
                                                    ? const Color(0xFF10B981)
                                                    : Colors.grey.shade500,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  _friendDistances[friend['id']] !=
                                                          null
                                                      ? _formatDistance(
                                                          _friendDistances[friend['id']],
                                                        )
                                                      : 'Không chia sẻ vị trí',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        _friendDistances[friend['id']] !=
                                                            null
                                                        ? const Color(
                                                            0xFF059669,
                                                          )
                                                        : Colors.grey.shade600,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Action buttons
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Chat button with unread badge
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              gradient:
                                                  AppTheme.primaryGradient,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              boxShadow: AppTheme.buttonShadow,
                                            ),
                                            child: Stack(
                                              children: [
                                                IconButton(
                                                  padding: EdgeInsets.zero,
                                                  icon: Icon(
                                                    Icons.chat_bubble_rounded,
                                                    color: Colors.white,
                                                    size: AppTheme.iconSize,
                                                  ),
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            ChatPage(
                                                              friendId:
                                                                  friend['id'],
                                                              friendEmail:
                                                                  friend['email'],
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                                // Unread message badge
                                                if (_unreadCounts[friend['id']] !=
                                                        null &&
                                                    _unreadCounts[friend['id']]! >
                                                        0)
                                                  Positioned(
                                                    right: 0,
                                                    top: 0,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      constraints:
                                                          const BoxConstraints(
                                                            minWidth: 16,
                                                            minHeight: 16,
                                                          ),
                                                      child: Text(
                                                        _unreadMessageService
                                                            .getUnreadCountDisplay(
                                                              _unreadCounts[friend['id']]!,
                                                            ),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          // More actions menu
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Theme(
                                              data: Theme.of(context).copyWith(
                                                shadowColor: Colors.black
                                                    .withOpacity(0.12),
                                                popupMenuTheme:
                                                    const PopupMenuThemeData(
                                                      elevation: 8,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.all(
                                                              Radius.circular(
                                                                18,
                                                              ),
                                                            ),
                                                      ),
                                                      color: Colors.white,
                                                    ),
                                                dividerTheme: DividerThemeData(
                                                  color: Colors.black
                                                      .withOpacity(0.08),
                                                  thickness: 0.7,
                                                  space: 8,
                                                ),
                                              ),
                                              child: PopupMenuButton<String>(
                                                padding: EdgeInsets.zero,
                                                icon: Icon(
                                                  Icons.more_horiz_rounded,
                                                  color: Colors.grey.shade600,
                                                  size: 21,
                                                ),
                                                shape:
                                                    const RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.all(
                                                            Radius.circular(18),
                                                          ),
                                                    ),
                                                offset: const Offset(0, 40),
                                                itemBuilder: (context) => [
                                                  PopupMenuItem<String>(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 14,
                                                        ),
                                                    value: 'edit',
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.edit_rounded,
                                                          color: Color(
                                                            0xFF8b5cf6,
                                                          ),
                                                          size: 20,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        const Text(
                                                          'Sửa biệt danh',
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const PopupMenuDivider(),
                                                  PopupMenuItem<String>(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 14,
                                                        ),
                                                    value: 'location',
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .location_on_rounded,
                                                          color: Color(
                                                            0xFF667eea,
                                                          ),
                                                          size: 20,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        const Text(
                                                          'Xem vị trí',
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const PopupMenuDivider(),
                                                  PopupMenuItem<String>(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 14,
                                                        ),
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .person_remove_rounded,
                                                          color: Color(
                                                            0xFFef4444,
                                                          ),
                                                          size: 20,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        const Text(
                                                          'Xóa kết bạn',
                                                          style: TextStyle(
                                                            color: Color(
                                                              0xFFef4444,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                                onSelected: (value) {
                                                  switch (value) {
                                                    case 'edit':
                                                      _showNicknameDialog(
                                                        friend,
                                                      );
                                                      break;
                                                    case 'location':
                                                      if (_friendDistances[friend['id']] !=
                                                          null) {
                                                        Navigator.pushReplacement(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                MainNavigationPage(
                                                                  focusFriendId:
                                                                      friend['id'],
                                                                  focusFriendEmail:
                                                                      friend['email'],
                                                                  selectedTab:
                                                                      0,
                                                                ),
                                                          ),
                                                        );
                                                      } else {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Bạn này chưa chia sẻ vị trí',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                      break;
                                                    case 'delete':
                                                      _showDeleteFriendDialog(
                                                        friend,
                                                      );
                                                      break;
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Load nicknames from SharedPreferences
  Future<void> _loadNicknames() async {
    final prefs = await SharedPreferences.getInstance();
    final nicknamesJson = prefs.getString('friend_nicknames');
    if (nicknamesJson != null) {
      final Map<String, dynamic> decoded = json.decode(nicknamesJson);
      setState(() {
        _friendNicknames.clear();
        decoded.forEach((key, value) {
          _friendNicknames[key] = value.toString();
        });
      });
    }
  }

  // Save nicknames to SharedPreferences
  Future<void> _saveNicknames() async {
    final prefs = await SharedPreferences.getInstance();
    final nicknamesJson = json.encode(_friendNicknames);
    await prefs.setString('friend_nicknames', nicknamesJson);
  }

  // Set nickname for a friend
  Future<void> _setNickname(String friendId, String nickname) async {
    setState(() {
      if (nickname.trim().isEmpty) {
        _friendNicknames.remove(friendId);
      } else {
        _friendNicknames[friendId] = nickname.trim();
      }
    });
    await _saveNicknames();
  }

  // Get display name (nickname or original name)
  String _getDisplayName(Map<String, dynamic> friend) {
    final friendId = friend['id'] as String;
    return _friendNicknames[friendId] ??
        friend['name'] ??
        friend['email'] ??
        'Unknown';
  }

  // Show nickname dialog
  void _showNicknameDialog(Map<String, dynamic> friend) {
    final friendId = friend['id'] as String;
    final currentNickname = _friendNicknames[friendId] ?? '';
    final controller = TextEditingController(text: currentNickname);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Đặt biệt danh cho ${friend['name'] ?? friend['email']}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Nhập biệt danh...',
            border: OutlineInputBorder(),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              await _setNickname(friendId, controller.text);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _openCreateGroupSheet() {
    final selected = <String>{};
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: const Text(
                        'Tạo nhóm chat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          hintText: 'Tên nhóm...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _friends.length,
                        itemBuilder: (context, index) {
                          final f = _friends[index];
                          final id = f['id'] as String;
                          final title = _getDisplayName(f);
                          final email = f['email'] as String;
                          final checked = selected.contains(id);
                          return ListTile(
                            leading: _buildFriendAvatar(f['avatarUrl'], email),
                            title: Text(title),
                            subtitle: Text(email),
                            trailing: Checkbox(
                              value: checked,
                              onChanged: (v) {
                                setModalState(() {
                                  if (v == true) {
                                    selected.add(id);
                                  } else {
                                    selected.remove(id);
                                  }
                                });
                              },
                            ),
                            onTap: () {
                              setModalState(() {
                                if (checked) {
                                  selected.remove(id);
                                } else {
                                  selected.add(id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ToastService.show(
                              context,
                              message: 'Vui lòng nhập tên nhóm',
                              type: AppToastType.warning,
                            );
                            return;
                          }
                          if (selected.isEmpty) {
                            ToastService.show(
                              context,
                              message: 'Hãy chọn ít nhất 1 bạn',
                              type: AppToastType.warning,
                            );
                            return;
                          }
                          final service = GroupChatService();
                          final groupId = await service.createGroup(
                            name: name,
                            memberIds: selected.toList(),
                          );
                          if (groupId != null && mounted) {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupChatPage(
                                  groupId: groupId,
                                  groupName: name,
                                ),
                              ),
                            );
                          } else {
                            ToastService.show(
                              context,
                              message: 'Không thể tạo nhóm',
                              type: AppToastType.error,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Tạo nhóm'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Lắng nghe tin nhắn chưa đọc từ tất cả bạn bè
  void _listenToUnreadMessages() {
    _unreadMessageService.listenToAllUnreadCounts().listen((unreadCounts) {
      if (mounted) {
        setState(() {
          _unreadCounts.clear();
          _unreadCounts.addAll(unreadCounts);
        });
      }
    });
  }
}
