import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/main_navigation_page.dart';
import 'pages/incoming_call_page.dart';
import 'pages/onboarding_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'theme.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    print('✅ Firebase initialized successfully');
    
    // Test Firebase connection
    final database = FirebaseDatabase.instance;
    final testRef = database.ref('test_connection');
    await testRef.set({'timestamp': DateTime.now().millisecondsSinceEpoch});
    print('✅ Firebase Database connection test successful');
    
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSub;
  String? _currentUid;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchAuthChanges();
    _setupPresence();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _setOnlineStatus(false);
    super.dispose();
  }

  void _setOnlineStatus(bool isOnline) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseDatabase.instance.ref('online/${user.uid}').set(isOnline);
        if (!isOnline) {
          await FirebaseDatabase.instance
              .ref('lastSeen/${user.uid}')
              .set(ServerValue.timestamp);
        }
        print('✅ Set online status: $isOnline for user: ${user.uid}');
      } else {
        print('⚠️ No authenticated user found');
      }
    } catch (e) {
      print('❌ Error setting online status: $e');
    }
  }

  void _setupPresence() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final onlineRef = FirebaseDatabase.instance.ref('online/${user.uid}');
    final lastSeenRef = FirebaseDatabase.instance.ref('lastSeen/${user.uid}');

    // Mark online now
    await onlineRef.set(true);
    await lastSeenRef.set(ServerValue.timestamp);

    // Ensure cleanup when connection drops
    await onlineRef.onDisconnect().set(false);
    await lastSeenRef.onDisconnect().set(ServerValue.timestamp);
  }

  void _watchAuthChanges() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      final previousUid = _currentUid;
      if (user != null) {
        // If switching accounts without an explicit sign out, mark previous offline
        if (previousUid != null && previousUid != user.uid) {
          await FirebaseDatabase.instance.ref('online/$previousUid').set(false);
          await FirebaseDatabase.instance.ref('lastSeen/$previousUid').set(ServerValue.timestamp);
        }

        _currentUid = user.uid;
        final onlineRef = FirebaseDatabase.instance.ref('online/${user.uid}');
        final lastSeenRef = FirebaseDatabase.instance.ref('lastSeen/${user.uid}');
        await onlineRef.set(true);
        // Keep lastSeen updated on connect to ensure a valid timestamp exists
        await lastSeenRef.set(ServerValue.timestamp);
        await onlineRef.onDisconnect().set(false);
        await lastSeenRef.onDisconnect().set(ServerValue.timestamp);
      } else {
        if (previousUid != null) {
          await FirebaseDatabase.instance.ref('online/$previousUid').set(false);
          await FirebaseDatabase.instance.ref('lastSeen/$previousUid').set(ServerValue.timestamp);
        }
        _currentUid = null;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _setOnlineStatus(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: MyApp.navigatorKey,
      title: 'Lyn',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.light,
      home: _initialHome(),
      routes: {
        '/incoming_call': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            final callId = args['callId'] as String;
            final callData = args['callData'] as Map<dynamic, dynamic>;
            return IncomingCallPage(
              callId: callId,
              callerEmail: callData['callerEmail'] as String,
              callerId: callData['callerId'] as String,
            );
          }
          return const Scaffold(
            body: Center(child: Text('Invalid call data')),
          );
        },
      },
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppTheme.primaryColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppTheme.backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFF1e293b),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Color(0xFF1e293b)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        ),
        color: AppTheme.surfaceColor,
        shadowColor: AppTheme.primaryColor.withValues(alpha: 0.1),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
          ),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Color(0xFF94a3b8),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppTheme.primaryColor,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0f172a),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        ),
        color: const Color(0xFF1e293b),
        shadowColor: AppTheme.primaryColor.withValues(alpha: 0.1),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
          ),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1e293b),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1e293b),
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Color(0xFF64748b),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  Widget _initialHome() {
    return FutureBuilder<bool>(
      future: _shouldShowOnboarding(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final showOnboarding = snapshot.data ?? false;
        if (showOnboarding) {
          return const OnboardingPage();
        }
        final user = FirebaseAuth.instance.currentUser;
        return user != null ? const MainNavigationPage() : const LoginPage();
      },
    );
  }

  Future<bool> _shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('has_seen_onboarding') ?? false;
    return !seen;
  }
}
