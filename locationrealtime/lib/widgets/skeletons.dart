import 'package:flutter/material.dart';
import '../theme.dart';

class PastelShimmer extends StatefulWidget {
  final Widget child;
  const PastelShimmer({super.key, required this.child});

  @override
  State<PastelShimmer> createState() => _PastelShimmerState();
}

class _PastelShimmerState extends State<PastelShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value; // 0..1
        final start = (t - 0.2).clamp(0.0, 1.0);
        final mid = t.clamp(0.0, 1.0);
        final end = (t + 0.2).clamp(0.0, 1.0);
        final gradient = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.grey.shade200,
            AppTheme.primaryColor.withOpacity(0.18),
            Colors.grey.shade200,
          ],
          stops: [start, mid, end],
        );
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: gradient,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class FriendListSkeleton extends StatelessWidget {
  final int itemCount;
  const FriendListSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar shimmer
                SizedBox(
                  width: 50,
                  height: 50,
                  child: const PastelShimmer(
                    child: SizedBox.expand(),
                  ),
                ),
                const SizedBox(width: 12),
                // Text bars
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SizedBox(height: 10),
                      PastelShimmer(
                        child: SizedBox(height: 12, width: double.infinity),
                      ),
                      SizedBox(height: 8),
                      PastelShimmer(
                        child: SizedBox(height: 10, width: 180),
                      ),
                      SizedBox(height: 12),
                      PastelShimmer(
                        child: SizedBox(height: 10, width: 120),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ChatSkeleton extends StatelessWidget {
  final int bubbleCount;
  const ChatSkeleton({super.key, this.bubbleCount = 10});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      itemCount: bubbleCount,
      itemBuilder: (context, i) {
        final isLeft = i % 2 == 0;
        return Align(
          alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: const PastelShimmer(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: SizedBox(width: 160, height: 16),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MapLoadingOverlay extends StatelessWidget {
  final bool isVisible;
  const MapLoadingOverlay({super.key, required this.isVisible});

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    return Container(
      color: Colors.white.withOpacity(0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 12),
            const Text('Đang tải bản đồ...',
                style: TextStyle(color: AppTheme.textSecondaryColor)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _markerPlaceholder(),
                const SizedBox(width: 12),
                _markerPlaceholder(),
                const SizedBox(width: 12),
                _markerPlaceholder(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _markerPlaceholder() {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6),
        ],
      ),
    );
  }
}