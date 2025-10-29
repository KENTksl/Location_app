import 'package:flutter/material.dart';
import 'map_page.dart';
import 'friends_list_page.dart';
import 'user_profile_page.dart';
import '../services/call_notification_service.dart';

class MainNavigationPage extends StatefulWidget {
  final String? focusFriendId;
  final String? focusFriendEmail;
  final int? selectedTab;
  const MainNavigationPage({
    super.key,
    this.focusFriendId,
    this.focusFriendEmail,
    this.selectedTab,
  });

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage>
    with TickerProviderStateMixin {
  late int _selectedIndex;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Widget> _pages = const [
    MapPage(),
    FriendsListPage(),
    UserProfilePage(),
  ];

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.map_rounded,
      label: 'Bản đồ',
      color: const Color(0xFF667eea),
    ),
    NavigationItem(
      icon: Icons.people_rounded,
      label: 'Bạn bè',
      color: const Color(0xFF10b981),
    ),
    NavigationItem(
      icon: Icons.person_rounded,
      label: 'Cá nhân',
      color: const Color(0xFF06b6d4),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedTab ?? 0;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    
    // Initialize call notification service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CallNotificationService().initialize(context);
      CallNotificationService().checkForActiveCalls();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    CallNotificationService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      MapPage(
        focusFriendId: widget.focusFriendId,
        focusFriendEmail: widget.focusFriendEmail,
      ),
      const FriendsListPage(),
      const UserProfilePage(),
    ];

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF1e293b),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                _navigationItems.length,
                (index) => _buildNavigationItem(index),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationItem(int index) {
    final item = _navigationItems[index];
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        _animationController.reset();
        _animationController.forward();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    item.color.withValues(alpha: 0.2),
                item.color.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(isSelected ? 6 : 3),
              decoration: BoxDecoration(
                color: isSelected ? item.color : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                size: isSelected ? 20 : 18,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).brightness == Brightness.light
                    ? const Color(0xFF94a3b8)
                    : const Color(0xFF64748b),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: isSelected ? 10 : 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? item.color
                    : Theme.of(context).brightness == Brightness.light
                    ? const Color(0xFF94a3b8)
                    : const Color(0xFF64748b),
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final Color color;

  NavigationItem({
    required this.icon,
    required this.label,
    required this.color,
  });
}
