import 'package:flutter/material.dart';
import '../theme.dart';

class EmptyStateMapNoFriends extends StatelessWidget {
  final VoidCallback onAddFriends;
  const EmptyStateMapNoFriends({super.key, required this.onAddFriends});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapIllustration(),
              const SizedBox(height: 16),
              const Text(
                'Chưa có bạn bè nào',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kết thêm bạn để xem vị trí của họ trên bản đồ.',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.buttonShadow,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onAddFriends,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_add_alt_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Thêm bạn bè', style: AppTheme.buttonTextStyle),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyStateChatNoMessages extends StatelessWidget {
  const EmptyStateChatNoMessages({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _ChatIllustration(),
              SizedBox(height: 16),
              Text('Hãy bắt đầu cuộc trò chuyện',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('Gửi lời chào đến bạn bè của bạn.',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyStateFriendRequestsEmpty extends StatelessWidget {
  const EmptyStateFriendRequestsEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _InboxIllustration(),
              SizedBox(height: 16),
              Text('Không có lời mời nào',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('Khi có lời mời, bạn sẽ thấy chúng ở đây.',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyStateTravelHistoryEmpty extends StatelessWidget {
  const EmptyStateTravelHistoryEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _RouteIllustration(),
              SizedBox(height: 16),
              Text('Chưa có lịch sử di chuyển',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('Lộ trình của bạn sẽ xuất hiện tại đây.',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondaryColor),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// Simple friendly flat-style illustrations using shapes
class _MapIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 140,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFFEDEBFF), Color(0xFFF3F0FF)],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _DashedRoutePainter(),
            ),
          ),
          // greyed markers
          Positioned(
            left: 20,
            top: 20,
            child: _marker(Colors.grey.shade300),
          ),
          Positioned(
            right: 26,
            top: 36,
            child: _marker(Colors.grey.shade300),
          ),
          Positioned(
            left: 48,
            bottom: 18,
            child: _marker(Colors.grey.shade300),
          ),
        ],
      ),
    );
  }

  Widget _marker(Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8),
        ],
      ),
      child: const Icon(Icons.person_outline_rounded, color: Colors.white),
    );
  }
}

class _ChatIllustration extends StatelessWidget {
  const _ChatIllustration();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 110,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFFEDEBFF), Color(0xFFF3F0FF)],
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppTheme.primaryColor.withOpacity(0.15),
              ),
              child: const Icon(Icons.chat_bubble_rounded,
                  color: AppTheme.primaryColor, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxIllustration extends StatelessWidget {
  const _InboxIllustration();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 110,
      child: Stack(children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFFF7F5FF),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.inbox_rounded,
                color: AppTheme.primaryColor, size: 28),
          ),
        )
      ]),
    );
  }
}

class _RouteIllustration extends StatelessWidget {
  const _RouteIllustration();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 120,
      child: Stack(children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFFEDEBFF), Color(0xFFF3F0FF)],
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _DashedRoutePainter())),
        Positioned(
          left: 20,
          top: 20,
          child: _dot(AppTheme.primaryColor.withOpacity(0.2)),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: _dot(AppTheme.primaryColor.withOpacity(0.4)),
        ),
      ]),
    );
  }

  Widget _dot(Color c) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }
}

class _DashedRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryColor.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const dashWidth = 6.0;
    const dashSpace = 6.0;
    double startX = 16;
    final path = Path()
      ..moveTo(startX, size.height - 30)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.3, size.width - 16, 24);
    final metrics = path.computeMetrics().first;
    double distance = 0.0;
    while (distance < metrics.length) {
      final next = distance + dashWidth;
      canvas.drawPath(
        metrics.extractPath(distance, next),
        paint,
      );
      distance = next + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}