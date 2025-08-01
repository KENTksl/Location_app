import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme.dart';

class FriendSearchPage extends StatefulWidget {
  const FriendSearchPage({super.key});

  @override
  State<FriendSearchPage> createState() => _FriendSearchPageState();
}

class _FriendSearchPageState extends State<FriendSearchPage> {
  final TextEditingController _emailController = TextEditingController();
  String? _foundUserId;
  String? _foundUserEmail;
  String _status = '';
  bool _loading = false;

  Future<void> _searchUser() async {
    setState(() {
      _loading = true;
      _status = '';
      _foundUserId = null;
      _foundUserEmail = null;
    });
    final usersRef = FirebaseDatabase.instance.ref('users');
    final event = await usersRef.once();
    final users = event.snapshot.value as Map?;
    final searchEmail = _emailController.text.trim();
    if (users != null) {
      users.forEach((userId, userData) {
        if (userData['email'] == searchEmail) {
          _foundUserId = userId;
          _foundUserEmail = userData['email'];
        }
      });
    }
    if (_foundUserId == null) {
      setState(() {
        _status = 'Không tìm thấy người dùng.';
        _loading = false;
      });
    } else if (_foundUserId == FirebaseAuth.instance.currentUser?.uid) {
      setState(() {
        _status = 'Đây là bạn!';
        _loading = false;
      });
    } else {
      setState(() {
        _status = '';
        _loading = false;
      });
    }
  }

  Future<void> _sendFriendRequest() async {
    final fromUserId = FirebaseAuth.instance.currentUser?.uid;
    final toUserId = _foundUserId;
    if (fromUserId == null || toUserId == null) return;
    setState(() {
      _loading = true;
    });
    await FirebaseDatabase.instance
        .ref('friend_requests/$toUserId/$fromUserId')
        .set(true);

    // Gửi thông báo cho người nhận
    // await NotificationService.sendFriendRequestNotification(
    //   toUserId,
    //   _foundUserEmail ?? '',
    // );

    setState(() {
      _status = 'Đã gửi lời mời kết bạn!';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTheme.appBar(title: 'Tìm kiếm bạn bè'),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              children: [
                // Search form
                AppTheme.card(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  borderRadius: AppTheme.borderRadiusL,
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: AppTheme.getInputDecoration(
                          labelText: 'Nhập email bạn bè',
                          prefixIcon: Icons.email_rounded,
                        ),
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      AppTheme.primaryButton(
                        text: 'Tìm kiếm',
                        onPressed: _loading ? () {} : _searchUser,
                        isLoading: _loading,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXL),
                // Search results area
                Expanded(
                  child: Column(
                    children: [
                      if (_foundUserId != null &&
                          _foundUserId !=
                              FirebaseAuth.instance.currentUser?.uid)
                        AppTheme.card(
                          padding: const EdgeInsets.all(AppTheme.spacingL),
                          borderRadius: AppTheme.borderRadiusL,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingL,
                              vertical: AppTheme.spacingM,
                            ),
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundColor: AppTheme.primaryColor
                                  .withOpacity(0.1),
                              child: Text(
                                (_foundUserEmail != null &&
                                        _foundUserEmail!.isNotEmpty)
                                    ? _foundUserEmail![0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 24,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              _foundUserEmail ?? '',
                              style: AppTheme.bodyStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'ID: $_foundUserId',
                              style: AppTheme.captionStyle,
                            ),
                            trailing: Container(
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
                                  onTap: _loading ? null : _sendFriendRequest,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppTheme.spacingM,
                                      vertical: AppTheme.spacingS,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.person_add_alt_1_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(
                                          width: AppTheme.spacingXS,
                                        ),
                                        Text(
                                          'Kết bạn',
                                          style: AppTheme.buttonTextStyle
                                              .copyWith(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_status.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spacingM),
                        Container(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          decoration: BoxDecoration(
                            color:
                                _status.contains('thành công') ||
                                    _status.contains('Đã gửi')
                                ? AppTheme.successColor.withOpacity(0.1)
                                : AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.borderRadiusS,
                            ),
                            border: Border.all(
                              color:
                                  _status.contains('thành công') ||
                                      _status.contains('Đã gửi')
                                  ? AppTheme.successColor.withOpacity(0.3)
                                  : AppTheme.primaryColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _status,
                            style: TextStyle(
                              color:
                                  _status.contains('thành công') ||
                                      _status.contains('Đã gửi')
                                  ? AppTheme.successColor
                                  : AppTheme.primaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
