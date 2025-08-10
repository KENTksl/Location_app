import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:locationrealtime/models/chat_message.dart';
import 'package:locationrealtime/services/chat_service.dart';

import '../services/mock.mocks.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseDatabase mockDatabase;
  late MockUser mockUser;
  late MockDatabaseReference mockRef;
  late MockDataSnapshot mockSnap;
  late ChatService chatService;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockDatabase = MockFirebaseDatabase();
    mockUser = MockUser();
    mockRef = MockDatabaseReference();
    mockSnap = MockDataSnapshot();

    chatService = ChatService(auth: mockAuth, database: mockDatabase);
  });

  group('ChatService', () {
    test('listenToMessages returns empty list if user null', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final result = await chatService.listenToMessages('friend1').first;
      expect(result, []);
    });

    test('listenToMessages returns mapped messages', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('u1');
      when(mockDatabase.ref(any)).thenReturn(mockRef);

      final mockEvent = MockDatabaseEvent();
      final mockSnapshot = MockDataSnapshot();

      when(mockRef.onValue).thenAnswer((_) => Stream.value(mockEvent));
      when(mockEvent.snapshot).thenReturn(mockSnapshot);
      when(mockSnapshot.value).thenReturn([
        {'from': 'u1', 'text': 'Hello', 'timestamp': 123456789},
      ]);

      final result = await chatService.listenToMessages('u2').first;
      expect(result, isA<List<ChatMessage>>());
      expect(result.first.text, 'Hello');
    });

    test('sendMessage adds message and limits to 30', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('u1');
      when(mockDatabase.ref(any)).thenReturn(mockRef);

      final existingMessages = List.generate(
        30,
        (i) => {'from': 'u1', 'text': 'msg$i', 'timestamp': 1000 + i},
      );

      when(mockRef.get()).thenAnswer((_) async {
        when(mockSnap.exists).thenReturn(true);
        when(mockSnap.value).thenReturn(existingMessages);
        return mockSnap;
      });

      await chatService.sendMessage('u2', 'new msg');

      verify(mockRef.set(argThat(hasLength(30)))).called(1);
    });

    test('getLastMessage returns last message when exists', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('u1');
      when(mockDatabase.ref(any)).thenReturn(mockRef);

      when(mockRef.get()).thenAnswer((_) async {
        when(mockSnap.exists).thenReturn(true);
        when(mockSnap.value).thenReturn([
          {'from': 'u1', 'text': 'old', 'timestamp': 1},
          {'from': 'u1', 'text': 'latest', 'timestamp': 2},
        ]);
        return mockSnap;
      });

      final msg = await chatService.getLastMessage('u2');
      expect(msg?.text, 'latest');
    });

    test('getChatList returns list with friend and last message', () async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('u1');

      final friendsMap = {'u2': true};

      // friends reference
      when(mockDatabase.ref('users/u1/friends')).thenReturn(mockRef);
      when(mockRef.get()).thenAnswer((_) async {
        when(mockSnap.exists).thenReturn(true);
        when(mockSnap.value).thenReturn(friendsMap);
        return mockSnap;
      });

      // friend info
      final mockUserRef = MockDatabaseReference();
      when(mockDatabase.ref('users/u2')).thenReturn(mockUserRef);
      when(mockUserRef.get()).thenAnswer((_) async {
        final snap = MockDataSnapshot();
        final mockEmailSnapshot = MockDataSnapshot();
        when(mockEmailSnapshot.value).thenReturn('friend@test.com');
        when(snap.child('email')).thenReturn(mockEmailSnapshot);
        return snap;
      });

      // last message
      final mockMsgRef = MockDatabaseReference();
      when(mockDatabase.ref('chats/u1_u2/messages')).thenReturn(mockMsgRef);
      when(mockMsgRef.get()).thenAnswer((_) async {
        final snap = MockDataSnapshot();
        when(snap.exists).thenReturn(true);
        when(snap.value).thenReturn([
          {
            'from': 'u1',
            'text': 'hi',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        ]);
        return snap;
      });

      final chats = await chatService.getChatList();
      expect(chats, isNotEmpty);
      expect(chats.first['friendId'], 'u2');
      expect(chats.first['friendEmail'], 'friend@test.com');
    });
  });
}
