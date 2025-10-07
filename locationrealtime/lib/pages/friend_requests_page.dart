import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme.dart';

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
            ? AppTheme.emptyStateWidget(
                message:
                    'Không có lời mời kết bạn nào.\nHãy chủ động kết bạn với mọi người!',
                icon: Icons.mark_email_unread_rounded,
              )
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
