import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:locationrealtime/services/auth_service.dart';
import 'package:locationrealtime/models/user.dart' as app_user;

import '../services/mock.mocks.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseDatabase mockDatabase;
  late AuthService authService;

  late MockUser mockUser;
  late MockUserCredential mockUserCredential;
  late MockDatabaseReference mockRef;
  late MockDataSnapshot mockSnapshot;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockDatabase = MockFirebaseDatabase();
    mockUser = MockUser();
    mockUserCredential = MockUserCredential();
    mockRef = MockDatabaseReference();
    mockSnapshot = MockDataSnapshot();

    authService = AuthService(auth: mockAuth, database: mockDatabase);
  });

  group('AuthService', () {
    test('signUp returns app_user.User when successful', () async {
      when(mockAuth.createUserWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockUserCredential);

      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('123');
      when(mockUser.email).thenReturn('test@example.com');

      when(mockDatabase.ref(any)).thenReturn(mockRef);
      when(mockRef.set(any)).thenAnswer((_) async {});

      final result = await authService.signUp('test@example.com', 'password');

      expect(result, isA<app_user.User>());
      expect(result?.id, '123');
      expect(result?.email, 'test@example.com');
    });

    test('signIn returns user from database if exists', () async {
      when(mockAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => mockUserCredential);

      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('123');
      when(mockUser.email).thenReturn('test@example.com');

      when(mockDatabase.ref(any)).thenReturn(mockRef);
      when(mockRef.get()).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.value).thenReturn({
        'email': 'test@example.com',
        'createdAt': DateTime.now().toIso8601String(),
      });

      final result = await authService.signIn('test@example.com', 'password');

      expect(result, isA<app_user.User>());
      expect(result?.id, '123');
    });

    test('signOut calls FirebaseAuth.signOut', () async {
      when(mockAuth.signOut()).thenAnswer((_) async {});
      await authService.signOut();
      verify(mockAuth.signOut()).called(1);
    });

    test('forgotPassword calls sendPasswordResetEmail', () async {
      when(mockAuth.sendPasswordResetEmail(email: anyNamed('email')))
          .thenAnswer((_) async {});
      await authService.forgotPassword('test@example.com');
      verify(mockAuth.sendPasswordResetEmail(email: 'test@example.com'))
          .called(1);
    });

    test('getCurrentUser returns app_user.User if signed in', () {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('123');
      when(mockUser.email).thenReturn('test@example.com');

      final result = authService.getCurrentUser();
      expect(result, isA<app_user.User>());
    });

    test('isSignedIn returns true if currentUser is not null', () {
      when(mockAuth.currentUser).thenReturn(mockUser);
      expect(authService.isSignedIn, true);
    });
  });
}
