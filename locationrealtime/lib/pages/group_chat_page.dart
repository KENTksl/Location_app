import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/group_chat_service.dart';
import '../models/chat_message.dart';
import '../theme.dart';
import '../services/toast_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:provider/provider.dart';
import '../state/favorite_places_controller.dart';
import '../models/favorite_place.dart';
import '../services/map_navigation_service.dart';
import 'main_navigation_page.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:intl/intl.dart';
import '../services/location_history_service.dart';
import '../models/location_history.dart';
import 'location_history_page.dart';

class GroupChatPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final GroupChatService _service = GroupChatService();
  final TextEditingController _controller = TextEditingController();
  final LocationHistoryService _routeService = LocationHistoryService();
  List<Map> _messages = [];
  Stream<List<Map>>? _messageStream;
  final ScrollController _scrollController = ScrollController();
  bool _isPinned = false;
  bool _isLeader = false;
  String? _leaderId;
  late String _groupName;
  Map<String, Map<String, String?>> _memberProfiles = {};
  final Set<String> _savingPlacesKeys = {};

  @override
  void initState() {
    super.initState();
    _groupName = widget.groupName;
    _messageStream = _service.listenToMessages(widget.groupId);
    _messageStream!.listen((msgs) {
      if (!mounted) return;
      setState(() {
        _messages = msgs;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });
    _loadPinned();
    _loadMemberProfiles();
    _loadLeader();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadLeader() async {
    try {
      final snap = await FirebaseDatabase.instance
          .ref('group_chats/${widget.groupId}/createdBy')
          .get();
      final leaderId = snap.value?.toString();
      final me = FirebaseAuth.instance.currentUser?.uid;
      if (mounted) {
        setState(() {
          _leaderId = leaderId;
          _isLeader = leaderId != null && leaderId == me;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMemberProfiles() async {
    final members = await _service.getMemberDetails(widget.groupId);
    final map = <String, Map<String, String?>>{};
    for (final m in members) {
      map[m['id'] as String] = {
        'email': m['email'] as String?,
        'avatarUrl': m['avatarUrl'] as String?,
      };
    }
    if (mounted) {
      setState(() {
        _memberProfiles = map;
      });
    }
  }

  Future<void> _loadPinned() async {
    final pinned = await _service.isGroupPinned(widget.groupId);
    if (mounted) {
      setState(() {
        _isPinned = pinned;
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      await _service.sendMessage(widget.groupId, text);
      _controller.clear();
      _scrollToBottom(animated: true);
    } catch (e) {
      ToastService.show(
        context,
        message: 'Không thể gửi tin nhắn nhóm',
        type: AppToastType.error,
      );
    }
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(position);
    }
  }

  Future<bool> _isProActive() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final snap = await FirebaseDatabase.instance
          .ref('users/${user.uid}/proActive')
          .get();
      final val = snap.value;
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
      if (val is num) return val != 0;
    } catch (_) {}
    return false;
  }

  void _openShareMenuSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.8;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'Chia sẻ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(
                        Icons.place_rounded,
                        color: Colors.blue,
                      ),
                      title: const Text('Địa điểm yêu thích'),
                      subtitle: const Text('Gửi địa điểm bạn đã lưu'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openShareFavoritePlaceSheet();
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.alt_route_rounded,
                        color: Colors.deepPurple,
                      ),
                      title: const Text('Lộ trình đã ghi'),
                      subtitle: const Text('Gửi lộ trình cho nhóm xem'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openShareRouteSheet();
                      },
                    ),
                    if (_isLeader) const Divider(),
                    if (_isLeader)
                      const Text(
                        'Quản trị nhóm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (_isLeader)
                      ListTile(
                        leading: const Icon(Icons.edit, color: Colors.orange),
                        title: const Text('Đổi tên nhóm'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final controller = TextEditingController(
                            text: _groupName,
                          );
                          showDialog(
                            context: context,
                            builder: (dctx) {
                              return AlertDialog(
                                title: const Text('Đổi tên nhóm'),
                                content: TextField(
                                  controller: controller,
                                  decoration: const InputDecoration(
                                    hintText: 'Tên nhóm mới',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(dctx).pop(),
                                    child: const Text('Hủy'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final newName = controller.text.trim();
                                      if (newName.isEmpty) return;
                                      final ok = await _service.renameGroup(
                                        widget.groupId,
                                        newName,
                                      );
                                      Navigator.of(dctx).pop();
                                      if (ok) {
                                        setState(() {
                                          _groupName = newName;
                                        });
                                        ToastService.show(
                                          context,
                                          message: 'Đã đổi tên nhóm',
                                          type: AppToastType.success,
                                        );
                                      } else {
                                        ToastService.show(
                                          context,
                                          message:
                                              'Bạn không phải trưởng nhóm hoặc lỗi hệ thống',
                                          type: AppToastType.error,
                                        );
                                      }
                                    },
                                    child: const Text('Đổi tên'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    if (_isLeader)
                      ListTile(
                        leading: const Icon(Icons.group, color: Colors.teal),
                        title: const Text('Quản lý thành viên'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final members = await _service.getMemberDetails(
                            widget.groupId,
                          );
                          if (!mounted) return;
                          showDialog(
                            context: context,
                            builder: (dctx) {
                              return AlertDialog(
                                title: const Text('Thành viên nhóm'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: members.length,
                                    itemBuilder: (ctx2, i) {
                                      final m = members[i];
                                      final email =
                                          (m['email'] as String?) ?? m['id'];
                                      final avatarUrl =
                                          m['avatarUrl'] as String?;
                                      final uid = m['id'] as String;
                                      final canKick =
                                          _leaderId != null && uid != _leaderId;
                                      final isMe =
                                          uid ==
                                          FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.uid;
                                      return ListTile(
                                        leading: _buildAvatar(
                                          avatarUrl,
                                          email ?? uid,
                                          showLeader:
                                              _leaderId != null &&
                                              uid == _leaderId,
                                        ),
                                        title: Text(
                                          (email ?? uid).split('@')[0],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          email ?? uid,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: (canKick && !isMe)
                                            ? TextButton(
                                                onPressed: () async {
                                                  final ok = await _service
                                                      .removeMember(
                                                        widget.groupId,
                                                        uid,
                                                      );
                                                  Navigator.of(dctx).pop();
                                                  if (ok) {
                                                    ToastService.show(
                                                      context,
                                                      message:
                                                          'Đã đuổi thành viên',
                                                      type:
                                                          AppToastType.success,
                                                    );
                                                  } else {
                                                    ToastService.show(
                                                      context,
                                                      message:
                                                          'Không thể đuổi thành viên',
                                                      type: AppToastType.error,
                                                    );
                                                  }
                                                },
                                                child: const Text(
                                                  'Đuổi',
                                                  style: TextStyle(
                                                    color: Color(0xFFdc2626),
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
                                    onPressed: () => Navigator.of(dctx).pop(),
                                    child: const Text('Đóng'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    if (_isLeader)
                      ListTile(
                        leading: const Icon(Icons.key, color: Colors.amber),
                        title: const Text('Chuyển nhượng trưởng nhóm'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final members = await _service.getMemberDetails(
                            widget.groupId,
                          );
                          final candidates = members
                              .where(
                                (m) =>
                                    m['id'] != _leaderId &&
                                    m['id'] !=
                                        FirebaseAuth.instance.currentUser?.uid,
                              )
                              .toList();
                          if (!mounted) return;
                          showDialog(
                            context: context,
                            builder: (dctx) {
                              return AlertDialog(
                                title: const Text('Chọn người nhận chìa khóa'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: candidates.length,
                                    itemBuilder: (ctx2, i) {
                                      final m = candidates[i];
                                      final email =
                                          (m['email'] as String?) ?? m['id'];
                                      final avatarUrl =
                                          m['avatarUrl'] as String?;
                                      final uid = m['id'] as String;
                                      return ListTile(
                                        leading: _buildAvatar(
                                          avatarUrl,
                                          email ?? uid,
                                        ),
                                        title: Text(
                                          (email ?? uid).split('@')[0],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          email ?? uid,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onTap: () async {
                                          final ok = await _service
                                              .transferLeadership(
                                                widget.groupId,
                                                uid,
                                              );
                                          Navigator.of(dctx).pop();
                                          if (ok) {
                                            setState(() {
                                              _leaderId = uid;
                                              _isLeader = false;
                                            });
                                            ToastService.show(
                                              context,
                                              message: 'Đã chuyển trưởng nhóm',
                                              type: AppToastType.success,
                                            );
                                          } else {
                                            ToastService.show(
                                              context,
                                              message:
                                                  'Không thể chuyển trưởng nhóm',
                                              type: AppToastType.error,
                                            );
                                          }
                                        },
                                      );
                                    },
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(dctx).pop(),
                                    child: const Text('Đóng'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    if (_isLeader)
                      ListTile(
                        leading: const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        title: const Text('Tan rã nhóm'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dctx) {
                              return AlertDialog(
                                title: const Text('Xác nhận tan rã nhóm'),
                                content: const Text(
                                  'Tất cả thành viên sẽ bị xóa khỏi nhóm. Bạn có chắc?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dctx).pop(false),
                                    child: const Text('Hủy'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dctx).pop(true),
                                    child: const Text('Tan rã'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (confirmed == true) {
                            final ok = await _service.dissolveGroup(
                              widget.groupId,
                            );
                            if (ok) {
                              ToastService.show(
                                context,
                                message: 'Nhóm đã tan rã',
                                type: AppToastType.success,
                              );
                              Navigator.pop(context);
                            } else {
                              ToastService.show(
                                context,
                                message: 'Không thể tan rã nhóm',
                                type: AppToastType.error,
                              );
                            }
                          }
                        },
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openShareFavoritePlaceSheet() async {
    final ctrl = context.read<FavoritePlacesController>();
    final places = ctrl.places;
    final isPro = await _isProActive();
    if (!isPro) {
      ToastService.show(
        context,
        message:
            'Tính năng chia sẻ địa điểm yêu thích chỉ dành cho người dùng Pro.',
        type: AppToastType.warning,
      );
      return;
    }
    if (places.isEmpty) {
      ToastService.show(
        context,
        message: 'Bạn chưa lưu địa điểm yêu thích nào.',
        type: AppToastType.warning,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.6;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: ListView.separated(
              itemCount: places.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx2, i) {
                final p = places[i];
                return ListTile(
                  leading: const Icon(Icons.place_rounded),
                  title: Text(p.name),
                  subtitle: Text(p.address),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _sendFavoritePlaceMessage(p);
                    },
                    child: const Text('Gửi'),
                  ),
                  onTap: () {
                    MapNavigationService.instance.requestFocus(
                      LatLng(p.lat, p.lng),
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const MainNavigationPage(selectedTab: 0),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openShareRouteSheet() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ToastService.show(
        context,
        message: 'Bạn cần đăng nhập để chia sẻ lộ trình.',
        type: AppToastType.error,
      );
      return;
    }
    final isPro = await _isProActive();
    if (!isPro) {
      ToastService.show(
        context,
        message: 'Tính năng chia sẻ lộ trình chỉ dành cho người dùng Pro.',
        type: AppToastType.warning,
      );
      return;
    }
    final localRoutes = await _routeService.getRoutesLocally();
    final cloudRoutes = await _routeService.getRoutesFromFirebase();
    final Map<String, LocationRoute> routeById = {};
    for (final r in [...localRoutes, ...cloudRoutes]) {
      routeById[r.id] = r;
    }
    final routes = routeById.values.toList()
      ..sort(
        (a, b) =>
            (b.endTime ?? b.startTime).compareTo(a.endTime ?? a.startTime),
      );
    if (routes.isEmpty) {
      ToastService.show(
        context,
        message: 'Bạn chưa có lộ trình nào để chia sẻ.',
        type: AppToastType.warning,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.6;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Chia sẻ lộ trình',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: routes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx2, i) {
                      final r = routes[i];
                      final duration = r.totalDuration;
                      final hours = duration.inHours;
                      final minutes = duration.inMinutes % 60;
                      final distanceKm = r.totalDistance;
                      final timeStr = DateFormat(
                        'dd/MM/yyyy HH:mm',
                      ).format(r.startTime);
                      return ListTile(
                        leading: const Icon(Icons.alt_route_rounded),
                        title: Text(
                          r.name.isNotEmpty ? r.name : 'Lộ trình ${r.id}',
                        ),
                        subtitle: Text(
                          '$timeStr • ${distanceKm.toStringAsFixed(2)} km • ${hours}h${minutes}m',
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _sendRouteMessage(r);
                          },
                          child: const Text('Gửi'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendFavoritePlaceMessage(FavoritePlace place) async {
    try {
      await _service.sendFavoritePlace(
        widget.groupId,
        name: place.name,
        address: place.address,
        lat: place.lat,
        lng: place.lng,
      );
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

  Future<void> _sendRouteMessage(LocationRoute route) async {
    try {
      final routeData = _routeService.exportRouteData(route);
      await _service.sendRouteMessageData(widget.groupId, routeData: routeData);
      ToastService.show(
        context,
        message: 'Đã chia sẻ lộ trình',
        type: AppToastType.success,
      );
    } catch (e) {
      ToastService.show(
        context,
        message: 'Không thể chia sẻ lộ trình. Vui lòng thử lại.',
        type: AppToastType.error,
      );
    }
  }

  String _timeLabel(dynamic ts) {
    DateTime dt;
    if (ts is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(ts);
    } else if (ts is String) {
      final parsed = int.tryParse(ts);
      dt = DateTime.fromMillisecondsSinceEpoch(parsed ?? 0);
    } else {
      dt = DateTime.now();
    }
    return DateFormat('HH:mm').format(dt);
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

  Widget _buildSystemMessage(String text, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
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
                  text,
                  style: AppTheme.captionStyle.copyWith(
                    fontSize: 12,
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map msg, bool isMe) {
    final senderId = msg['from']?.toString() ?? '';
    final profile = _memberProfiles[senderId] ?? {};
    String senderEmail = profile['email'] ?? senderId;
    if (!_memberProfiles.containsKey(senderId)) {
      senderEmail = 'Người dùng đã rời nhóm';
    }
    final avatarUrl = profile['avatarUrl'];
    final type = msg['type'];
    final time = _timeLabel(msg['timestamp']);
    final placeDyn = msg['place'];
    if (type == 'system') {
      return _buildSystemMessage((msg['text']?.toString() ?? ''), time);
    }
    if ((type == 'favorite_place' || placeDyn is Map) && placeDyn is Map) {
      final place = placeDyn;
      return _buildFavoritePlaceMessage(
        Map<String, dynamic>.from(place as Map),
        isMe,
        time,
        avatarUrl,
        senderEmail,
        senderId,
      );
    }
    final routeDataDyn = msg['routeData'];
    if (type == 'route_share' && routeDataDyn is Map) {
      return _buildRouteMessage(
        Map<String, dynamic>.from(routeDataDyn as Map),
        isMe,
        time,
        avatarUrl,
        senderEmail,
        senderId,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildAvatar(
                avatarUrl,
                senderEmail,
                showLeader: senderId.isNotEmpty && senderId == _leaderId,
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        senderEmail,
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                if (!isMe) const SizedBox(height: 6),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
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
                  child: Text(
                    (msg['text']?.toString() ?? ''),
                    style: TextStyle(
                      color: isMe ? Colors.white : AppTheme.textPrimaryColor,
                      fontSize: 15,
                    ),
                  ),
                ),
                Padding(
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
              child: _buildAvatar(
                avatarUrl,
                senderEmail,
                showLeader: senderId.isNotEmpty && senderId == _leaderId,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(_groupName, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1e293b),
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF5F7FB),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Chưa có tin nhắn'))
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    children: _buildMessageItems(userId),
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 10.0,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.transparent),
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.transparent),
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        filled: true,
                        fillColor: Color(0xFFF3F4F6),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.buttonShadow,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.more_horiz, color: Colors.white),
                      onPressed: _openShareMenuSheet,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.buttonShadow,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(
    String? avatarUrl,
    String email, {
    bool showLeader = false,
  }) {
    Widget base;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('random:')) {
        final seed = avatarUrl.substring(7);
        base = RandomAvatar(seed, height: 24, width: 24);
      } else if (avatarUrl.startsWith('http')) {
        base = ClipOval(
          child: CachedNetworkImage(
            imageUrl: avatarUrl,
            width: 24,
            height: 24,
            fit: BoxFit.cover,
          ),
        );
      } else {
        base = RandomAvatar(email, height: 24, width: 24);
      }
    } else {
      base = Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFF10b981),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            email.isNotEmpty ? email[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    if (!showLeader) return base;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        base,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Icon(
              Icons.vpn_key,
              size: 10,
              color: Color(0xFFf59e0b),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFavoritePlaceMessage(
    Map<String, dynamic> place,
    bool isMe,
    String time,
    String? avatarUrl,
    String label,
    String senderId,
  ) {
    final name = (place['name'] ?? '') as String;
    final address = (place['address'] ?? '') as String;
    final lat = (place['lat'] as num).toDouble();
    final lng = (place['lng'] as num).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildAvatar(
                avatarUrl,
                label,
                showLeader: senderId.isNotEmpty && senderId == _leaderId,
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
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
                            child: const Icon(
                              Icons.place_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white
                                        : AppTheme.textPrimaryColor,
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
                                    color: isMe
                                        ? Colors.white70
                                        : AppTheme.textSecondaryColor,
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
                              onPressed: () async {
                                final isPro = await _isProActive();
                                if (!isPro) {
                                  ToastService.show(
                                    context,
                                    message:
                                        'Tính năng lưu địa điểm chỉ dành cho người dùng Pro.',
                                    type: AppToastType.warning,
                                  );
                                  return;
                                }
                                final ctrl = context
                                    .read<FavoritePlacesController>();
                                final key = '$name|$lat|$lng';
                                if (_savingPlacesKeys.contains(key)) return;
                                final alreadyExists = ctrl.places.any((p) {
                                  final sameCoords =
                                      (p.lat - lat).abs() < 1e-6 &&
                                      (p.lng - lng).abs() < 1e-6;
                                  final sameName =
                                      p.name.trim().toLowerCase() ==
                                      name.trim().toLowerCase();
                                  return sameCoords || (sameName && sameCoords);
                                });
                                if (alreadyExists) {
                                  ToastService.show(
                                    context,
                                    message:
                                        'Địa điểm đã tồn tại trong danh sách',
                                    type: AppToastType.warning,
                                  );
                                  return;
                                }
                                _savingPlacesKeys.add(key);
                                try {
                                  final created = await ctrl.addPlace(
                                    name: name,
                                    address: address,
                                    lat: lat,
                                    lng: lng,
                                  );
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
                                } finally {
                                  _savingPlacesKeys.remove(key);
                                }
                              },
                              icon: const Icon(Icons.bookmark_add_outlined),
                              label: const Text('Lưu'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () {
                                MapNavigationService.instance.requestFocus(
                                  LatLng(lat, lng),
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MainNavigationPage(
                                      selectedTab: 0,
                                    ),
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
              child: _buildAvatar(
                avatarUrl,
                label,
                showLeader: senderId.isNotEmpty && senderId == _leaderId,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteMessage(
    Map<String, dynamic> routeData,
    bool isMe,
    String time,
    String? avatarUrl,
    String label,
    String senderId,
  ) {
    final routeJson = Map<String, dynamic>.from(routeData['route'] as Map);
    final route = LocationRoute.fromJson(routeJson);
    final duration = route.totalDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final distanceKm = route.totalDistance;
    final title = route.name.isNotEmpty ? route.name : 'Lộ trình ${route.id}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _buildAvatar(
                avatarUrl,
                label,
                showLeader: senderId.isNotEmpty && senderId == _leaderId,
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RouteDetailsPage(route: route),
                      ),
                    );
                  },
                  child: Container(
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
                              child: const Icon(
                                Icons.alt_route_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white
                                          : AppTheme.textPrimaryColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${distanceKm.toStringAsFixed(2)} km • ${hours}h${minutes}m',
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white70
                                          : AppTheme.textSecondaryColor,
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
                            if (!isMe)
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          RouteDetailsPage(route: route),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.remove_red_eye_outlined),
                                label: const Text('Xem'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
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
              child: _buildAvatar(
                avatarUrl,
                label,
                showLeader: senderId.isNotEmpty && senderId == _leaderId,
              ),
            ),
        ],
      ),
    );
  }
}
