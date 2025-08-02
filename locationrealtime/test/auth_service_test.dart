import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:locationrealtime/services/auth_service.dart';
import 'package:locationrealtime/models/user.dart' as app_user;

import 'auth_service_test.mocks.dart';

@GenerateMocks([FirebaseAuth, FirebaseDatabase, UserCredential, User, DatabaseReference, DatabaseEvent])
void main() {
  group('AuthService Tests', () {
    late AuthService authService;
    late MockFirebaseAuth mockFirebaseAuth;
    late MockFirebaseDatabase mockFirebaseDatabase;
    late MockUserCredential mockUserCredential;
    late MockUser mockUser;
    late MockDatabaseReference mockDatabaseRef;
    late MockDatabaseEvent mockDatabaseEvent;

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
      mockFirebaseDatabase = MockFirebaseDatabase();
      mockUserCredential = MockUserCredential();
      mockUser = MockUser();
      mockDatabaseRef = MockDatabaseReference();
      mockDatabaseEvent = MockDatabaseEvent();

      // Create AuthService with mocked dependencies
      authService = AuthService();
    });

    group('signUp', () {
      test('should create user successfully with valid credentials', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';
        const uid = 'user123';

        when(mockUser.uid).thenReturn(uid);
        when(mockUser.email).thenReturn(email);
        when(mockUserCredential.user).thenReturn(mockUser);
        when(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        )).thenAnswer((_) async => mockUserCredential);

        when(mockFirebaseDatabase.ref('users/$uid')).thenReturn(mockDatabaseRef);
        when(mockDatabaseRef.set(any)).thenAnswer((_) async => null);

        // Act
        final result = await authService.signUp(email, password);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, equals(uid));
        expect(result.email, equals(email));
        expect(result.createdAt, isNotNull);
      });

      test('should return null when Firebase throws exception', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';

        when(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

        // Act
        final result = await authService.signUp(email, password);

        // Assert
        expect(result, isNull);
      });

      test('should return null when user credential is null', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';

        when(mockUserCredential.user).thenReturn(null);
        when(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        )).thenAnswer((_) async => mockUserCredential);

        // Act
        final result = await authService.signUp(email, password);

        // Assert
        expect(result, isNull);
      });
    });

    group('signIn', () {
      test('should sign in successfully with valid credentials', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';
        const uid = 'user123';

        when(mockUser.uid).thenReturn(uid);
        when(mockUser.email).thenReturn(email);
        when(mockUserCredential.user).thenReturn(mockUser);
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenAnswer((_) async => mockUserCredential);

        when(mockFirebaseDatabase.ref('users/$uid')).thenReturn(mockDatabaseRef);
        when(mockDatabaseRef.get()).thenAnswer((_) async => mockDatabaseEvent);
        when(mockDatabaseEvent.exists).thenReturn(true);
        when(mockDatabaseEvent.value).thenReturn({
          'email': email,
          'createdAt': DateTime.now().toIso8601String(),
        });

        // Act
        final result = await authService.signIn(email, password);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, equals(uid));
        expect(result.email, equals(email));
      });

      test('should create new user in database if not exists', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';
        const uid = 'user123';

        when(mockUser.uid).thenReturn(uid);
        when(mockUser.email).thenReturn(email);
        when(mockUserCredential.user).thenReturn(mockUser);
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenAnswer((_) async => mockUserCredential);

        when(mockFirebaseDatabase.ref('users/$uid')).thenReturn(mockDatabaseRef);
        when(mockDatabaseRef.get()).thenAnswer((_) async => mockDatabaseEvent);
        when(mockDatabaseEvent.exists).thenReturn(false);
        when(mockDatabaseRef.set(any)).thenAnswer((_) async => null);

        // Act
        final result = await authService.signIn(email, password);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, equals(uid));
        expect(result.email, equals(email));
        verify(mockDatabaseRef.set(any)).called(1);
      });

      test('should return null when Firebase throws exception', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'wrongpassword';

        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(FirebaseAuthException(code: 'wrong-password'));

        // Act
        final result = await authService.signIn(email, password);

        // Assert
        expect(result, isNull);
      });
    });

    group('signOut', () {
      test('should sign out successfully', () async {
        // Arrange
        when(mockFirebaseAuth.signOut()).thenAnswer((_) async => null);

        // Act
        await authService.signOut();

        // Assert
        verify(mockFirebaseAuth.signOut()).called(1);
      });

      test('should handle sign out exception', () async {
        // Arrange
        when(mockFirebaseAuth.signOut()).thenThrow(Exception('Sign out failed'));

        // Act & Assert
        expect(() => authService.signOut(), returnsNormally);
      });
    });

    group('forgotPassword', () {
      test('should send password reset email successfully', () async {
        // Arrange
        const email = 'test@example.com';
        when(mockFirebaseAuth.sendPasswordResetEmail(email: email))
            .thenAnswer((_) async => null);

        // Act
        await authService.forgotPassword(email);

        // Assert
        verify(mockFirebaseAuth.sendPasswordResetEmail(email: email)).called(1);
      });

      test('should rethrow exception when password reset fails', () async {
        // Arrange
        const email = 'test@example.com';
        when(mockFirebaseAuth.sendPasswordResetEmail(email: email))
            .thenThrow(FirebaseAuthException(code: 'user-not-found'));

        // Act & Assert
        expect(
          () => authService.forgotPassword(email),
          throwsA(isA<FirebaseAuthException>()),
        );
      });
    });

    group('getCurrentUser', () {
      test('should return current user when signed in', () {
        // Arrange
        const uid = 'user123';
        const email = 'test@example.com';

        when(mockUser.uid).thenReturn(uid);
        when(mockUser.email).thenReturn(email);
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);

        // Act
        final result = authService.getCurrentUser();

        // Assert
        expect(result, isNotNull);
        expect(result!.id, equals(uid));
        expect(result.email, equals(email));
      });

      test('should return null when not signed in', () {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(null);

        // Act
        final result = authService.getCurrentUser();

        // Assert
        expect(result, isNull);
      });
    });

    group('isSignedIn', () {
      test('should return true when user is signed in', () {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);

        // Act
        final result = authService.isSignedIn;

        // Assert
        expect(result, isTrue);
      });

      test('should return false when user is not signed in', () {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(null);

        // Act
        final result = authService.isSignedIn;

        // Assert
        expect(result, isFalse);
      });
    });

    group('currentUserId', () {
      test('should return user ID when signed in', () {
        // Arrange
        const uid = 'user123';
        when(mockUser.uid).thenReturn(uid);
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);

        // Act
        final result = authService.currentUserId;

        // Assert
        expect(result, equals(uid));
      });

      test('should return null when not signed in', () {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(null);

        // Act
        final result = authService.currentUserId;

        // Assert
        expect(result, isNull);
      });
    });
  });
} 