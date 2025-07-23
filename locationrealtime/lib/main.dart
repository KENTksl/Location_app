import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'map_page.dart';
import 'signup_page.dart';
import 'main_navigation_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setOnlineStatus(true);
  }

  @override
  void dispose() {
    _setOnlineStatus(false);
    super.dispose();
  }

  void _setOnlineStatus(bool isOnline) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseDatabase.instance.ref('online/${user.uid}').set(isOnline);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: _getHomeWidget(),
    );
  }

  Widget _getHomeWidget() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return const MainNavigationPage();
    } else {
      return const LoginPage();
    }
  }
}
