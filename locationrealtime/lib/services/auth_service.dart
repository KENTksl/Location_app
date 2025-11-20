import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user.dart' as app_user;

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseDatabase _database;

  AuthService({FirebaseAuth? auth, FirebaseDatabase? database})
    : _auth = auth ?? FirebaseAuth.instance,
      _database = database ?? FirebaseDatabase.instance;

  // Đăng ký
  Future<app_user.User?> signUp(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        final appUser = app_user.User(
          id: user.uid,
          email: user.email ?? '',
          createdAt: DateTime.now(),
          proActive: false,
        );

        // Lưu thông tin user vào Realtime Database
        await _database.ref('users/${user.uid}').set(appUser.toJson());

        return appUser;
      }
      return null;
    } catch (e) {
      print('Error signing up: $e');
      return null;
    }
  }

  // Đăng nhập
  Future<app_user.User?> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        // Kiểm tra xem user đã có trong database chưa
        final userRef = _database.ref('users/${user.uid}');
        final snap = await userRef.get();

        if (!snap.exists) {
          // Tạo user mới nếu chưa có
          final appUser = app_user.User(
            id: user.uid,
            email: user.email ?? '',
            createdAt: DateTime.now(),
            proActive: false,
          );
          await userRef.set(appUser.toJson());
          return appUser;
        } else {
          // Lấy thông tin user từ database
          final data = snap.value as Map<dynamic, dynamic>;
          return app_user.User.fromJson({'id': user.uid, ...data});
        }
      }
      return null;
    } catch (e) {
      print('Error signing in: $e');
      return null;
    }
  }

  // Đăng xuất
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // Quên mật khẩu
  Future<void> forgotPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error sending password reset email: $e');
      rethrow;
    }
  }

  // Lấy user hiện tại
  app_user.User? getCurrentUser() {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    return app_user.User(id: firebaseUser.uid, email: firebaseUser.email ?? '');
  }

  // Stream user hiện tại
  Stream<app_user.User?> get currentUserStream {
    return _auth.authStateChanges().map((firebaseUser) {
      if (firebaseUser == null) return null;

      return app_user.User(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
      );
    });
  }

  // Kiểm tra user đã đăng nhập
  bool get isSignedIn => _auth.currentUser != null;

  // Lấy user ID hiện tại
  String? get currentUserId => _auth.currentUser?.uid;
}
