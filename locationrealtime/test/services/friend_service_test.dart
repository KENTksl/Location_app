import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:locationrealtime/services/friend_service.dart';
import 'package:locationrealtime/models/friend.dart';
import 'package:locationrealtime/models/friend_request.dart';
import 'package:locationrealtime/services/geolocator_wrapper.dart';

import '../services/mock.mocks.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseDatabase mockDatabase;
  late MockGeolocatorWrapper mockGeolocator;
  late FriendService friendService;

  late MockUser mockUser;
  late MockDatabaseReference mockRef;
  late MockDataSnapshot mockSnapshot;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockDatabase = MockFirebaseDatabase();
    mockGeolocator = MockGeolocatorWrapper();
    mockUser = MockUser();
    mockRef = MockDatabaseReference();
    mockSnapshot = MockDataSnapshot();

    friendService = FriendService(
      auth: mockAuth,
      database: mockDatabase,
      geolocator: mockGeolocator,
    );
  });

  group('FriendService', () {
    test('getFriends returns list of friends when exists', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('uid1');

      // friends list
      when(mockDatabase.ref(any)).thenReturn(mockRef);
      when(mockRef.get()).thenAnswer((_) async => mockSnapshot);
      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.value).thenReturn({'uid2': true});

      // friend data
      final friendSnapshot = MockDataSnapshot();
      when(mockDatabase.ref('users/uid2')).thenReturn(mockRef);
      when(mockRef.get()).thenAnswer((_) async => friendSnapshot);
      when(friendSnapshot.exists).thenReturn(true);
      when(friendSnapshot.value).thenReturn({'email': 'test@example.com'});

      final result = await friendService.getFriends();
      expect(result, isA<List<Friend>>());
      expect(result.length, 1);
    });

    test('addFriend calls database set for both users', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('uid1');
      when(mockDatabase.ref(any)).thenReturn(mockRef);
      when(mockRef.set(any)).thenAnswer((_) async {});

      await friendService.addFriend('uid2');
      verify(mockDatabase.ref('users/uid1/friends/uid2')).called(1);
      verify(mockDatabase.ref('users/uid2/friends/uid1')).called(1);
    });

    test('removeFriend calls database remove for both users', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('uid1');
      when(mockDatabase.ref(any)).thenReturn(mockRef);
      when(mockRef.remove()).thenAnswer((_) async {});

      await friendService.removeFriend('uid2');
      verify(mockDatabase.ref('users/uid1/friends/uid2')).called(1);
      verify(mockDatabase.ref('users/uid2/friends/uid1')).called(1);
    });

    test('sendFriendRequest writes to database', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('uid1');
      when(mockUser.email).thenReturn('me@example.com');
      when(mockDatabase.ref(any)).thenReturn(mockRef);
      when(mockRef.set(any)).thenAnswer((_) async {});

      await friendService.sendFriendRequest('uid2');
      verify(mockDatabase.ref('friend_requests/uid2/uid1')).called(1);
    });

    test('getFriendRequests returns list when exists', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('uid1');

      // Mock requests snapshot
      final mockRequestsRef = MockDatabaseReference();
      final mockRequestsSnap = MockDataSnapshot();

      when(
        mockDatabase.ref('friend_requests/uid1'),
      ).thenReturn(mockRequestsRef);
      when(mockRequestsRef.get()).thenAnswer((_) async => mockRequestsSnap);
      when(mockRequestsSnap.exists).thenReturn(true);
      when(mockRequestsSnap.value).thenReturn({
        'uid2': {
          'from': 'uid2',
          'email': 'friend@example.com',
          'timestamp': 123456,
        },
      });

      // Mock sender snapshot
      final mockSenderRef = MockDatabaseReference();
      final mockSenderSnap = MockDataSnapshot();

      when(mockDatabase.ref('users/uid2')).thenReturn(mockSenderRef);
      when(mockSenderRef.get()).thenAnswer((_) async => mockSenderSnap);
      when(mockSenderSnap.exists).thenReturn(true);
      when(
        mockSenderSnap.value,
      ).thenReturn({'email': 'friend@example.com', 'avatarUrl': 'avatar.png'});

      final result = await friendService.getFriendRequests();

      expect(result, isA<List<FriendRequest>>());
      expect(result.length, 1);
      expect(result.first.id, 'uid2');
      expect(result.first.email, 'friend@example.com');
    });

    test('acceptFriendRequest adds friends and removes request', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('uid1');
      when(mockDatabase.ref(any)).thenReturn(mockRef);
      when(mockRef.set(any)).thenAnswer((_) async {});
      when(mockRef.remove()).thenAnswer((_) async {});

      await friendService.acceptFriendRequest('uid2');
      verify(mockDatabase.ref('users/uid1/friends/uid2')).called(1);
      verify(mockDatabase.ref('users/uid2/friends/uid1')).called(1);
      verify(mockDatabase.ref('friend_requests/uid1/uid2')).called(1);
    });

    test('rejectFriendRequest removes request', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('uid1');
      when(mockDatabase.ref(any)).thenReturn(mockRef);
      when(mockRef.remove()).thenAnswer((_) async {});

      await friendService.rejectFriendRequest('uid2');
      verify(mockDatabase.ref('friend_requests/uid1/uid2')).called(1);
    });

    test('calculateDistance returns correct value', () {
      when(
        mockGeolocator.distanceBetween(0, 0, 0, 1),
      ).thenReturn(1000.0); // meters
      final distance = friendService.calculateDistance(0, 0, 0, 1);
      expect(distance, 1.0); // km
    });
  });
}
