import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:random_avatar/random_avatar.dart';
import '../theme.dart';
import 'call_page.dart';
import 'dart:io';
import 'dart:async'; // Added for StreamSubscription
import '../services/unread_message_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../widgets/skeletons.dart';
import '../widgets/empty_states.dart';
import '../services/toast_service.dart';
import 'package:provider/provider.dart';
import '../state/favorite_places_controller.dart';
import '../models/favorite_place.dart';
import '../services/map_navigation_service.dart';
import 'main_navigation_page.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

class ChatPage extends StatefulWidget {
  final String friendId;
  final String friendEmail;
  const ChatPage({
    super.key,
    required this.friendId,
    required this.friendEmail,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map> _messages = [];
  bool _loading = true;
  late String _chatId;
  String? _myEmail;
  String? _myAvatarUrl;
  String? _friendAvatarUrl;
  StreamSubscription? _myAvatarSubscription;
  StreamSubscription? _friendAvatarSubscription;
  // Presence fields
  StreamSubscription? _friendOnlineSubscription;
  StreamSubscription? _friendLastSeenSubscription;
  bool _isFriendOnline = false;
  int? _friendLastSeenMs;
  String _presenceSubtitle = '';
  final UnreadMessageService _unreadMessageService = UnreadMessageService();
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _chatId = _getChatId(
      FirebaseAuth.instance.currentUser!.uid,
      widget.friendId,
    );
    _myEmail = FirebaseAuth.instance.currentUser?.email;
    _loadAvatarUrls();
    _listenMessages();
    _markMessagesAsRead();
    _loadFriendNickname();
    _listenFriendPresence();
  }

  @override
  void dispose() {
    _controller.dispose();
    _myAvatarSubscription?.cancel();
    _friendAvatarSubscription?.cancel();
    _friendOnlineSubscription?.cancel();
    _friendLastSeenSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadFriendNickname() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('friend_nicknames');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        final nickname = map[widget.friendId];
        if (nickname is String && nickname.trim().isNotEmpty) {
          _displayName = nickname.trim();
        }
      }
    } catch (_) {
      // Ignore errors, fallback will be email
    }
    if (_displayName.isEmpty) {
      final email = widget.friendEmail;
      _displayName = email.isNotEmpty
          ? email.split('@').first
          : widget.friendId;
    }
    if (mounted) setState(() {});
  }

  void _listenFriendPresence() async {
    // Listen to online status
    final onlineRef = FirebaseDatabase.instance.ref(
      'online/${widget.friendId}',
    );
    _friendOnlineSubscription = onlineRef.onValue.listen((event) {
      final val = event.snapshot.value;
      final online = val == true;
      setState(() {
        _isFriendOnline = online;
        _presenceSubtitle = online
            ? 'Đang hoạt động'
            : _formatLastSeen(_friendLastSeenMs);
      });
    });

    // Listen to last seen timestamp
    final lastSeenRef = FirebaseDatabase.instance.ref(
      'lastSeen/${widget.friendId}',
    );
    _friendLastSeenSubscription = lastSeenRef.onValue.listen((event) {
      final v = event.snapshot.value;
      int? ms;
      if (v is int) {
        ms = v;
      } else if (v is num) {
        ms = v.toInt();
      } else if (v is String) {
        ms = int.tryParse(v);
      }
      if (ms != null) {
        setState(() {
          _friendLastSeenMs = ms;
          if (!_isFriendOnline) {
            _presenceSubtitle = _formatLastSeen(ms);
          }
        });
      }
    });

    // Prime initial values
    try {
      final onlineSnap = await onlineRef.get();
      final online = onlineSnap.value == true;
      final lastSeenSnap = await lastSeenRef.get();
      int? ms;
      final v = lastSeenSnap.value;
      if (v is int) {
        ms = v;
      } else if (v is num) {
        ms = v.toInt();
      } else if (v is String) {
        ms = int.tryParse(v);
      }
      setState(() {
        _isFriendOnline = online;
        _friendLastSeenMs = ms;
        _presenceSubtitle = online ? 'Đang hoạt động' : _formatLastSeen(ms);
      });
    } catch (_) {}
  }

  String _formatLastSeen(int? ms) {
    if (ms == null) return 'Hoạt động lúc không xác định';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dayKey = DateTime(dt.year, dt.month, dt.day);

    final timeStr = DateFormat('HH:mm').format(dt);
    if (dayKey == today) {
      return 'Hoạt động lúc $timeStr';
    } else if (dayKey == yesterday) {
      return 'Hoạt động hôm qua, $timeStr';
    } else {
      final dateStr = DateFormat('dd/MM/yyyy').format(dt);
      return 'Hoạt động $timeStr, $dateStr';
    }
  }

  String _getChatId(String uid1, String uid2) {
    return (uid1.compareTo(uid2) < 0) ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  void _listenMessages() {
    final ref = FirebaseDatabase.instance.ref('chats/$_chatId/messages');
    ref.onValue.listen((event) {
      final data = event.snapshot.value as List?;
      if (data != null) {
        final msgs = data.whereType<Map>().toList();
        setState(() {
          _messages = msgs;
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      } else {
        setState(() {
          _messages = [];
          _loading = false;
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ToastService.show(
        context,
        message: 'Vui lòng nhập nội dung tin nhắn.',
        type: AppToastType.warning,
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ToastService.show(
        context,
        message: 'Bạn cần đăng nhập để gửi tin nhắn.',
        type: AppToastType.error,
      );
      return;
    }
    try {
      final ref = FirebaseDatabase.instance.ref('chats/$_chatId/messages');
      final snap = await ref.get();
      List msgs = [];
      if (snap.exists && snap.value is List) {
        msgs = List.from(snap.value as List);
      }
      // Giới hạn 30 tin nhắn gần nhất
      if (msgs.length >= 30) {
        msgs = msgs.sublist(msgs.length - 29);
      }
      msgs.add({
        'from': user.uid,
        'text': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await ref.set(msgs);
      _controller.clear();
    } catch (e) {
      ToastService.show(
        context,
        message: 'Không thể gửi tin nhắn. Vui lòng thử lại.',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _sendFavoritePlaceMessage(FavoritePlace place) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ToastService.show(
        context,
        message: 'Bạn cần đăng nhập để chia sẻ địa điểm.',
        type: AppToastType.error,
      );
      return;
    }
    try {
      final ref = FirebaseDatabase.instance.ref('chats/$_chatId/messages');
      final snap = await ref.get();
      List msgs = [];
      if (snap.exists && snap.value is List) {
        msgs = List.from(snap.value as List);
      }
      // Giới hạn 30 tin nhắn gần nhất
      if (msgs.length >= 30) {
        msgs = msgs.sublist(msgs.length - 29);
      }
      msgs.add({
        'from': user.uid,
        'type': 'favorite_place',
        'place': {
          'name': place.name,
          'address': place.address,
          'lat': place.lat,
          'lng': place.lng,
        },
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await ref.set(msgs);
      ToastService.show(
        context,
        message: 'Đã chia sẻ địa điểm yêu thích',
        type: AppToastType.success,
      );
    } catch (e) {
      ToastService.show(
        context,
        message: 'Không thể chia sẻ địa điểm. Vui lòng thử lại.',
        type: AppToastType.error,
      );
    }
  }

  void _openShareFavoritePlaceSheet() {
    final favCtrl = context.read<FavoritePlacesController>();
    final places = favCtrl.places;
    if (places.isEmpty) {
      ToastService.show(
        context,
        message: 'Bạn chưa có địa điểm yêu thích để chia sẻ.',
        type: AppToastType.warning,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Chia sẻ địa điểm yêu thích',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: places.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final p = places[i];
                    return ListTile(
                      leading: const Icon(Icons.place_rounded, color: Colors.deepPurple),
                      title: Text(p.name),
                      subtitle: Text(p.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendFavoritePlaceMessage(p);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadAvatarUrls() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Load my avatar
      final myAvatarRef = FirebaseDatabase.instance.ref(
        'users/${user.uid}/avatarUrl',
      );
      final myAvatarSnap = await myAvatarRef.get();
      if (myAvatarSnap.exists) {
        setState(() {
          _myAvatarUrl = myAvatarSnap.value as String?;
        });
      }

      // Lắng nghe thay đổi avatar của tôi
      _myAvatarSubscription = myAvatarRef.onValue.listen((event) {
        if (event.snapshot.exists && mounted) {
          setState(() {
            _myAvatarUrl = event.snapshot.value as String?;
          });
          // Force rebuild để cập nhật avatar ngay lập tức
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});
            }
          });
        }
      });

      // Load friend avatar
      final friendAvatarRef = FirebaseDatabase.instance.ref(
        'users/${widget.friendId}/avatarUrl',
      );
      final friendAvatarSnap = await friendAvatarRef.get();
      if (friendAvatarSnap.exists) {
        setState(() {
          _friendAvatarUrl = friendAvatarSnap.value as String?;
        });
      }

      // Lắng nghe thay đổi avatar của bạn bè
      _friendAvatarSubscription = friendAvatarRef.onValue.listen((event) {
        if (event.snapshot.exists && mounted) {
          setState(() {
            _friendAvatarUrl = event.snapshot.value as String?;
          });
          // Force rebuild để cập nhật avatar ngay lập tức
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});
            }
          });
        }
      });
    }
  }

  Widget _buildMessage(Map msg, bool isMe) {
    final time = msg['timestamp'] != null
        ? DateFormat(
            'HH:mm',
          ).format(DateTime.fromMillisecondsSinceEpoch(msg['timestamp']))
        : '';

    final avatarUrl = isMe ? _myAvatarUrl : _friendAvatarUrl;
    final label = isMe
        ? (_myEmail ?? '')
        : (_displayName.isNotEmpty ? _displayName : widget.friendEmail);

    // Hiển thị tin nhắn chia sẻ địa điểm yêu thích
    if (msg['type'] == 'favorite_place' && msg['place'] is Map) {
      final Map place = msg['place'] as Map;
      return _buildFavoritePlaceMessage(place, isMe, time, avatarUrl, label);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildAvatarWidget(avatarUrl, label),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingS,
                    horizontal: AppTheme.spacingM,
                  ),
                  decoration: BoxDecoration(
                    // Bubble colors per spec
                    gradient: isMe ? AppTheme.primaryGradient : null,
                    color: isMe ? null : Colors.white,
                    // Rounded 18–22dp (use 20dp)
                    borderRadius: BorderRadius.circular(20),
                    // Soft shadow for incoming only
                    boxShadow: isMe
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Text(
                    msg['text'] ?? '',
                    style: TextStyle(
                      color: isMe ? Colors.white : AppTheme.textPrimaryColor,
                      fontSize: 16,
                      fontWeight: isMe ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
                Padding(
                  // Increase spacing above timestamp by +6px (2 -> 8)
                  padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      time,
                      style: AppTheme.captionStyle.copyWith(
                        fontSize: 10,
                        // Increase contrast
                        color: AppTheme.textPrimaryColor.withOpacity(0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _buildAvatarWidget(avatarUrl, label),
            ),
        ],
      ),
    );
  }

  Widget _buildFavoritePlaceMessage(
    Map place,
    bool isMe,
    String time,
    String? avatarUrl,
    String label,
  ) {
    final name = (place['name'] ?? '') as String;
    final address = (place['address'] ?? '') as String;
    final lat = (place['lat'] as num).toDouble();
    final lng = (place['lng'] as num).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildAvatarWidget(avatarUrl, label),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: isMe ? AppTheme.primaryGradient : null,
                    color: isMe ? null : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isMe
                        ? null
                        : [
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
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.primaryGradient,
                              boxShadow: AppTheme.buttonShadow,
                            ),
                            child: const Icon(Icons.place_rounded, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : AppTheme.textPrimaryColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isMe ? Colors.white70 : AppTheme.textSecondaryColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            TextButton.icon(
                              onPressed: () {
                                final ctrl = context.read<FavoritePlacesController>();
                                ctrl.addPlace(name: name, address: address, lat: lat, lng: lng).then((created) {
                                  if (created != null) {
                                    ToastService.show(
                                      context,
                                      message: 'Đã lưu vào địa điểm yêu thích',
                                      type: AppToastType.success,
                                    );
                                  } else {
                                    ToastService.show(
                                      context,
                                      message: 'Không thể lưu địa điểm',
                                      type: AppToastType.error,
                                    );
                                  }
                                });
                              },
                              icon: const Icon(Icons.bookmark_add_outlined),
                              label: const Text('Lưu'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () {
                                MapNavigationService.instance.requestFocus(LatLng(lat, lng));
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MainNavigationPage(selectedTab: 0),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.map_rounded),
                              label: const Text('Xem'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      time,
                      style: AppTheme.captionStyle.copyWith(
                        fontSize: 10,
                        color: AppTheme.textPrimaryColor.withOpacity(0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _buildAvatarWidget(avatarUrl, label),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarWidget(
    String? avatarUrl,
    String label, {
    double radius = 16,
  }) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('random:')) {
        // Hiển thị random avatar với seed từ avatarUrl
        final seed = avatarUrl.substring(7);
        return RandomAvatar(seed, height: radius * 2, width: radius * 2);
      } else if (avatarUrl.startsWith('http')) {
        // Hiển thị network image
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: CachedNetworkImage(
            imageUrl: avatarUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildDefaultAvatar(label, radius),
            errorWidget: (context, url, error) =>
                _buildDefaultAvatar(label, radius),
          ),
        );
      } else {
        // Hiển thị local file
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.file(
            File(avatarUrl),
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildDefaultAvatar(label, radius),
          ),
        );
      }
    }
    return _buildDefaultAvatar(label, radius);
  }

  Widget _buildDefaultAvatar(String label, double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        shape: BoxShape.circle,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Center(
        child: Text(
          _firstInitial(label),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _firstInitial(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  List<Widget> _buildMessageItems(String? myUid) {
    final List<Widget> items = [];
    DateTime? previousDay;
    for (final msg in _messages) {
      final ts = msg['timestamp'];
      DateTime dt;
      if (ts is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(ts);
      } else if (ts is String) {
        final parsed = int.tryParse(ts);
        dt = DateTime.fromMillisecondsSinceEpoch(parsed ?? 0);
      } else {
        dt = DateTime.now();
      }
      final dayKey = DateTime(dt.year, dt.month, dt.day);
      if (previousDay == null || dayKey != previousDay) {
        items.add(_buildDateSeparator(dt));
        previousDay = dayKey;
      }
      final isMe = msg['from'] == myUid;
      items.add(_buildMessage(msg, isMe));
    }
    return items;
  }

  Widget _buildDateSeparator(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dayKey = DateTime(dt.year, dt.month, dt.day);
    String label;
    if (dayKey == today) {
      label = 'Hôm nay';
    } else if (dayKey == yesterday) {
      label = 'Hôm qua';
    } else {
      label = DateFormat('dd/MM/yyyy').format(dt);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              label,
              style: AppTheme.captionStyle.copyWith(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppTheme.appBar(
        title: _displayName.isNotEmpty ? _displayName : widget.friendEmail,
        subtitle: _presenceSubtitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CallPage(
                    friendId: widget.friendId,
                    friendEmail: _displayName.isNotEmpty
                        ? _displayName
                        : widget.friendEmail,
                  ),
                ),
              );
            },
          ),
          const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
        ],
      ),
      body: Container(
        // Softer background gradient with ~40% reduced saturation
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE6EAFF), // softened from primary
              Color(0xFFF4EEFF), // softened from secondary
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const ChatSkeleton()
                  : _messages.isEmpty
                  ? const EmptyStateChatNoMessages()
                  : ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      children: _buildMessageItems(user?.uid),
                    ),
            ),
            // Input area
            Container(
              margin: const EdgeInsets.all(AppTheme.spacingM),
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadiusM,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadiusM,
                          ),
                          borderSide: BorderSide(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadiusM,
                          ),
                          borderSide: BorderSide(
                            color: AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingS,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  // Nút chia sẻ địa điểm yêu thích
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadiusM,
                      ),
                      boxShadow: AppTheme.buttonShadow,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusM,
                        ),
                        onTap: _openShareFavoritePlaceSheet,
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          child: const Icon(
                            Icons.place_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadiusM,
                      ),
                      boxShadow: AppTheme.buttonShadow,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusM,
                        ),
                        onTap: _sendMessage,
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Đánh dấu tất cả tin nhắn là đã đọc
  void _markMessagesAsRead() {
    _unreadMessageService.markAllAsRead(widget.friendId);
  }
}
