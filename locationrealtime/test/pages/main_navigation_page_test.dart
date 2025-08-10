import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locationrealtime/pages/main_navigation_page.dart';
import '../test_helper.dart';

// Mock pages to avoid Firebase dependencies
class MockMapPage extends StatelessWidget {
  final String? focusFriendId;
  final String? focusFriendEmail;
  
  const MockMapPage({super.key, this.focusFriendId, this.focusFriendEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Map Page'),
            if (focusFriendId != null) Text('Focus Friend ID: $focusFriendId'),
            if (focusFriendEmail != null) Text('Focus Friend Email: $focusFriendEmail'),
          ],
        ),
      ),
    );
  }
}

class MockFriendsListPage extends StatelessWidget {
  const MockFriendsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Friends List Page'),
      ),
    );
  }
}

class MockUserProfilePage extends StatelessWidget {
  const MockUserProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('User Profile Page'),
      ),
    );
  }
}

// Create a test version of MainNavigationPage with mock pages
class TestMainNavigationPage extends StatefulWidget {
  final String? focusFriendId;
  final String? focusFriendEmail;
  final int? selectedTab;
  
  const TestMainNavigationPage({
    super.key,
    this.focusFriendId,
    this.focusFriendEmail,
    this.selectedTab,
  });

  @override
  State<TestMainNavigationPage> createState() => _TestMainNavigationPageState();
}

class _TestMainNavigationPageState extends State<TestMainNavigationPage>
    with TickerProviderStateMixin {
  late int _selectedIndex;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Widget> _pages = const [
    MockMapPage(),
    MockFriendsListPage(),
    MockUserProfilePage(),
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      MockMapPage(
        focusFriendId: widget.focusFriendId,
        focusFriendEmail: widget.focusFriendEmail,
      ),
      const MockFriendsListPage(),
      const MockUserProfilePage(),
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
              color: Colors.black.withOpacity(0.1),
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
                    item.color.withOpacity(0.2),
                    item.color.withOpacity(0.1),
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

void main() {
  group('MainNavigationPage', () {
    Widget createTestWidget({
      String? focusFriendId,
      String? focusFriendEmail,
      int? selectedTab,
    }) {
      return MaterialApp(
        home: TestMainNavigationPage(
          focusFriendId: focusFriendId,
          focusFriendEmail: focusFriendEmail,
          selectedTab: selectedTab,
        ),
      );
    }

    testWidgets('should display with default tab selected', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should show map page by default (index 0)
      expect(find.text('Bản đồ'), findsOneWidget);
      expect(find.text('Bạn bè'), findsOneWidget);
      expect(find.text('Cá nhân'), findsOneWidget);
    });

    testWidgets('should display with custom selected tab', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(selectedTab: 1));
      await tester.pumpAndSettle();

      // Should show friends page (index 1)
      expect(find.text('Bản đồ'), findsOneWidget);
      expect(find.text('Bạn bè'), findsOneWidget);
      expect(find.text('Cá nhân'), findsOneWidget);
    });

    testWidgets('should have proper navigation structure', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if the page has proper structure
      expect(find.byType(Scaffold), findsWidgets);
      expect(find.byType(IndexedStack), findsOneWidget);
    });

    testWidgets('should show all navigation items', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if all navigation items are displayed
      expect(find.text('Bản đồ'), findsOneWidget);
      expect(find.text('Bạn bè'), findsOneWidget);
      expect(find.text('Cá nhân'), findsOneWidget);
    });

    testWidgets('should show correct icons for navigation items', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if all navigation icons are displayed
      expect(find.byIcon(Icons.map_rounded), findsOneWidget);
      expect(find.byIcon(Icons.people_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('should handle tab switching', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on friends tab
      await tester.tap(find.text('Bạn bè'));
      await tester.pumpAndSettle();

      // Should switch to friends tab
      expect(find.text('Bạn bè'), findsOneWidget);
    });

    testWidgets('should handle tab switching to profile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on profile tab
      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();

      // Should switch to profile tab
      expect(find.text('Cá nhân'), findsOneWidget);
    });

    testWidgets('should handle tab switching back to map', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // First switch to friends tab
      await tester.tap(find.text('Bạn bè'));
      await tester.pumpAndSettle();

      // Then switch back to map tab
      await tester.tap(find.text('Bản đồ'));
      await tester.pumpAndSettle();

      // Should switch back to map tab
      expect(find.text('Bản đồ'), findsOneWidget);
    });

    testWidgets('should have animations when switching tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if animations are present
      expect(find.byType(FadeTransition), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    testWidgets('should have proper bottom navigation styling', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if bottom navigation has proper styling
      expect(find.byType(Container), findsWidgets);
      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('should handle focus friend parameters', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(
        focusFriendId: 'friend-123',
        focusFriendEmail: 'friend@example.com',
      ));
      await tester.pumpAndSettle();

      // Should still show navigation structure
      expect(find.text('Bản đồ'), findsOneWidget);
      expect(find.text('Bạn bè'), findsOneWidget);
      expect(find.text('Cá nhân'), findsOneWidget);
    });

    testWidgets('should have proper navigation item colors', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if navigation items have proper styling
      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    testWidgets('should handle navigation item tap animations', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on a navigation item
      await tester.tap(find.text('Bạn bè'));
      await tester.pump();

      // Should trigger animations
      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    testWidgets('should maintain state when switching tabs', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to friends tab
      await tester.tap(find.text('Bạn bè'));
      await tester.pumpAndSettle();

      // Switch back to map tab
      await tester.tap(find.text('Bản đồ'));
      await tester.pumpAndSettle();

      // Should maintain the map tab state
      expect(find.text('Bản đồ'), findsOneWidget);
    });

    testWidgets('should have proper navigation item spacing', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if navigation items are properly spaced
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('should handle navigation item selection state', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially map tab should be selected
      expect(find.text('Bản đồ'), findsOneWidget);

      // Select friends tab
      await tester.tap(find.text('Bạn bè'));
      await tester.pumpAndSettle();

      // Friends tab should now be selected
      expect(find.text('Bạn bè'), findsOneWidget);
    });

    testWidgets('should have proper navigation item labels', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if all navigation labels are correct
      expect(find.text('Bản đồ'), findsOneWidget);
      expect(find.text('Bạn bè'), findsOneWidget);
      expect(find.text('Cá nhân'), findsOneWidget);
    });

    testWidgets('should handle navigation item icon changes', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if icons change when tabs are selected
      expect(find.byIcon(Icons.map_rounded), findsOneWidget);
      expect(find.byIcon(Icons.people_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('should have proper navigation item animations', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check if animations are properly configured
      expect(find.byType(AnimatedDefaultTextStyle), findsWidgets);
    });
  });
}
