import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'login_page.dart';
import 'main_navigation_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  bool _pressPrimary = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding({bool showPermissionSheet = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (showPermissionSheet) {
      _showPermissionBottomSheet();
    } else {
      _navigateToApp();
    }
  }

  void _navigateToApp() {
    final user = FirebaseAuth.instance.currentUser;
    final target = user != null ? const MainNavigationPage() : const LoginPage();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => target),
      (route) => false,
    );
  }

  void _showPermissionBottomSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('location_permission_prompt_shown') ?? false;
    if (alreadyShown) {
      _navigateToApp();
      return;
    }

    // Build bottom sheet per spec
    // White rounded panel with 28dp corner radius, title, description, illustration, buttons
    // Use AppTheme styles and gradients
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: AppTheme.buttonShadow,
                  ),
                  child: const Icon(Icons.location_pin, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Bật chia sẻ vị trí?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1e293b)),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ứng dụng cần quyền truy cập vị trí để chia sẻ với bạn bè theo thời gian thực.',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748b)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _pressPrimary = true),
                      onTapCancel: () => setState(() => _pressPrimary = false),
                      onTapUp: (_) => setState(() => _pressPrimary = false),
                      onTap: () async {
                        // Mark prompt shown and proceed to request permission
                        await prefs.setBool('location_permission_prompt_shown', true);
                        if (mounted) Navigator.of(ctx).pop();
                        // Light-touch permission request; defer actual sharing toggles to Profile page
                        // We won't enforce permission here, just navigate forward
                        _navigateToApp();
                      },
                      child: AnimatedScale(
                        scale: _pressPrimary ? 0.97 : 1.0,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: AppTheme.buttonShadow,
                          ),
                          child: const Center(
                            child: Text('Bật ngay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        side: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
                        foregroundColor: const Color(0xFF1e293b),
                      ),
                      onPressed: () async {
                        await prefs.setBool('location_permission_prompt_shown', true);
                        if (mounted) Navigator.of(ctx).pop();
                        _navigateToApp();
                      },
                      child: const Text('Để sau', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (mounted) {
      _navigateToApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: const [
                    _OnboardingScreen(
                      title: 'Chia sẻ vị trí với bạn bè',
                      subtitle: 'Giúp bạn kết nối và biết bạn bè đang ở đâu theo thời gian thực.',
                      illustration: _IllustrationLocationSharing(),
                    ),
                    _OnboardingScreen(
                      title: 'Xem khoảng cách & lịch sử di chuyển',
                      subtitle: 'Theo dõi quãng đường, tốc độ và các lộ trình gần đây.',
                      illustration: _IllustrationDistanceHistory(),
                    ),
                    _OnboardingScreen(
                      title: 'Kiểm soát quyền riêng tư của bạn',
                      subtitle: 'Bạn chọn ai được xem vị trí và khi nào.',
                      illustration: _IllustrationPrivacyControl(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _PageIndicators(current: _currentPage, total: 3),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_currentPage < 2) {
                            _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                          } else {
                            _completeOnboarding(showPermissionSheet: true);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                            boxShadow: AppTheme.buttonShadow,
                          ),
                          child: Center(
                            child: Text(
                              _currentPage < 2 ? 'Tiếp' : 'Bắt đầu',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
      ),
    );
  }
}

class _PageIndicators extends StatelessWidget {
  final int current;
  final int total;
  const _PageIndicators({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 10 : 8,
          height: isActive ? 10 : 8,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
            shape: BoxShape.circle,
            boxShadow: isActive ? [
              BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 8, offset: const Offset(0, 2)),
            ] : null,
          ),
        );
      }),
    );
  }
}

class _OnboardingScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget illustration;
  const _OnboardingScreen({required this.title, required this.subtitle, required this.illustration});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Expanded(child: illustration),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

// Simple flat illustrations using shapes and icons, matching pastel theme
class _IllustrationLocationSharing extends StatelessWidget {
  const _IllustrationLocationSharing();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 280,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Positioned(
            left: 40,
            child: _avatarCircle(color: Colors.white),
          ),
          Positioned(
            right: 40,
            child: _avatarCircle(color: Colors.white),
          ),
          Positioned(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dot(), _dot(), _dot(), _dot(), _dot(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarCircle({required Color color}) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.9),
        boxShadow: AppTheme.buttonShadow,
      ),
      child: const Icon(Icons.person, color: AppTheme.primaryColor),
    );
  }

  Widget _dot() {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white70,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _IllustrationDistanceHistory extends StatelessWidget {
  const _IllustrationDistanceHistory();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 300,
            height: 190,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Positioned(
            top: 40,
            left: 40,
            right: 40,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: 40,
            right: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Icon(Icons.route_outlined, color: Colors.white),
                Icon(Icons.speed_outlined, color: Colors.white),
                Icon(Icons.stacked_line_chart_outlined, color: Colors.white),
              ],
            ),
          ),
          const Positioned(
            bottom: 32,
            child: Icon(Icons.pin_drop_outlined, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }
}

class _IllustrationPrivacyControl extends StatelessWidget {
  const _IllustrationPrivacyControl();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 260,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              boxShadow: AppTheme.buttonShadow,
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 40),
          ),
          const Positioned(
            bottom: 28,
            child: Icon(Icons.lock_outline, color: Colors.white),
          ),
        ],
      ),
    );
  }
}