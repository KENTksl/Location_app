import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme.dart';
import '../widgets/empty_states.dart';
import '../services/toast_service.dart';

class FriendRequestsPage extends StatefulWidget {
  const FriendRequestsPage({super.key});

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  List<Map<String, String>> _requests = [];
  bool _loading = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _status = '';
    });
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final reqRef = FirebaseDatabase.instance.ref('friend_requests/$userId');
    final event = await reqRef.once();
    final reqs = event.snapshot.value as Map?;
    List<Map<String, String>> result = [];
    if (reqs != null) {
      for (final fromUserId in reqs.keys) {
        // Lấy email của người gửi lời mời
        final userSnap = await FirebaseDatabase.instance
            .ref('users/$fromUserId')
            .get();
        final email = userSnap.child('email').value?.toString() ?? fromUserId;
        result.add({'userId': fromUserId, 'email': email});
      }
    }
    setState(() {
      _requests = result;
      _loading = false;
    });
  }

  Future<void> _acceptRequest(String fromUserId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      // Kiểm tra giới hạn bạn bè cho cả hai phía
      // Kiểm tra người dùng hiện tại
      final curProSnap = await FirebaseDatabase.instance
          .ref('users/$userId/proActive')
          .get();
      bool curIsPro = false;
      final curProVal = curProSnap.value;
      if (curProVal is bool) {
        curIsPro = curProVal;
      } else if (curProVal is String) {
        curIsPro = curProVal.toLowerCase() == 'true';
      } else if (curProVal is num) {
        curIsPro = curProVal != 0;
      }

      int curFriendCount = 0;
      if (!curIsPro) {
        final curFriendsSnap = await FirebaseDatabase.instance
            .ref('users/$userId/friends')
            .get();
        if (curFriendsSnap.exists && curFriendsSnap.value is Map) {
          curFriendCount = (curFriendsSnap.value as Map).length;
        }
        if (curFriendCount >= 3) {
          _status =
              'Bạn đã đạt giới hạn 3 bạn. Nâng cấp VIP để kết bạn không giới hạn.';
          ToastService.show(
            context,
            message:
                'Không thể xác nhận: bạn đã đạt giới hạn 3 bạn (chỉ VIP không giới hạn).',
            type: AppToastType.warning,
          );
          setState(() {});
          return;
        }
      }

      // Kiểm tra phía người gửi (đối phương)
      final otherProSnap = await FirebaseDatabase.instance
          .ref('users/$fromUserId/proActive')
          .get();
      bool otherIsPro = false;
      final otherProVal = otherProSnap.value;
      if (otherProVal is bool) {
        otherIsPro = otherProVal;
      } else if (otherProVal is String) {
        otherIsPro = otherProVal.toLowerCase() == 'true';
      } else if (otherProVal is num) {
        otherIsPro = otherProVal != 0;
      }

      if (!otherIsPro) {
        final otherFriendsSnap = await FirebaseDatabase.instance
            .ref('users/$fromUserId/friends')
            .get();
        int otherFriendCount = 0;
        if (otherFriendsSnap.exists && otherFriendsSnap.value is Map) {
          otherFriendCount = (otherFriendsSnap.value as Map).length;
        }
        if (otherFriendCount >= 3) {
          _status =
              'Đối phương đã đạt giới hạn 3 bạn. Họ cần nâng cấp VIP để thêm bạn mới.';
          ToastService.show(
            context,
            message:
                'Không thể xác nhận: đối phương đã đạt giới hạn 3 bạn.',
            type: AppToastType.warning,
          );
          setState(() {});
          return;
        }
      }
      // Thêm vào danh sách bạn bè của cả hai
      await FirebaseDatabase.instance
          .ref('users/$userId/friends/$fromUserId')
          .set(true);
      await FirebaseDatabase.instance
          .ref('users/$fromUserId/friends/$userId')
          .set(true);

      // Xóa lời mời
      await FirebaseDatabase.instance
          .ref('friend_requests/$userId/$fromUserId')
          .remove();

      setState(() {
        _status = 'Đã xác nhận kết bạn thành công!';
      });

      ToastService.show(
        context,
        message: 'Đã xác nhận kết bạn thành công!',
        type: AppToastType.success,
      );

      // Đợi một chút để Firebase cập nhật
      await Future.delayed(const Duration(milliseconds: 500));

      // Thông báo cho trang danh sách bạn bè cập nhật
      if (mounted) {
        Navigator.pop(context, true); // Trả về true để báo hiệu cần refresh
      }
    } catch (e) {
      setState(() {
        _status = 'Lỗi khi xác nhận kết bạn: $e';
      });
      ToastService.show(
        context,
        message: 'Không thể xác nhận kết bạn. Vui lòng thử lại.',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _declineRequest(String fromUserId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    await FirebaseDatabase.instance
        .ref('friend_requests/$userId/$fromUserId')
        .remove();
    setState(() {
      _status = 'Đã từ chối lời mời của $fromUserId';
    });
    ToastService.show(
      context,
      message: 'Đã từ chối lời mời kết bạn',
      type: AppToastType.warning,
    );
    _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTheme.appBar(title: 'Lời mời kết bạn'),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: _loading
            ? AppTheme.loadingWidget(message: 'Đang tải...')
            : _requests.isEmpty
            ? const EmptyStateFriendRequestsEmpty()
            : ListView.separated(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                itemCount: _requests.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppTheme.spacingS),
                itemBuilder: (context, index) {
                  final req = _requests[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingS,
                    ),
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 35,
                            backgroundColor: AppTheme.warningColor.withValues(alpha: 0.1),
                            child: Text(
                              (req['email'] != null && req['email']!.isNotEmpty)
                                  ? req['email']![0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 28,
                                color: AppTheme.warningColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        Text(
                          req['email'] ?? '',
                          style: AppTheme.bodyStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spacingL),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Accept button
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXS),
                              decoration: BoxDecoration(
                                gradient: AppTheme.accentGradient,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.borderRadiusS,
                                ),
                                boxShadow: AppTheme.buttonShadow,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.borderRadiusS,
                                  ),
                                  onTap: () => _acceptRequest(req['userId']!),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppTheme.spacingM,
                                      vertical: AppTheme.spacingS,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: AppTheme.spacingXS),
                                        Text(
                                          'Xác nhận',
                                          style: AppTheme.buttonTextStyle
                                              .copyWith(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            // Decline button
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXS),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.borderRadiusS,
                                ),
                                boxShadow: AppTheme.buttonShadow,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.borderRadiusS,
                                  ),
                                  onTap: () => _declineRequest(req['userId']!),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppTheme.spacingM,
                                      vertical: AppTheme.spacingS,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: AppTheme.spacingXS),
                                        Text(
                                          'Từ chối',
                                          style: AppTheme.buttonTextStyle
                                              .copyWith(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      bottomNavigationBar: _status.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                boxShadow: AppTheme.cardShadow,
              ),
              child: Text(
                _status,
                style: TextStyle(
                  color: _status.contains('thành công')
                      ? AppTheme.successColor
                      : AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : null,
    );
  }
}
