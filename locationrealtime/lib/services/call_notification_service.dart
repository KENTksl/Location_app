import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../pages/incoming_call_page.dart';
import '../main.dart';

class CallNotificationService {
  static final CallNotificationService _instance = CallNotificationService._internal();
  factory CallNotificationService() => _instance;
  CallNotificationService._internal();

  StreamSubscription<DatabaseEvent>? _callSubscription;
  StreamSubscription<DatabaseEvent>? _callAddedSubscription;
  StreamSubscription<DatabaseEvent>? _callRemovedSubscription;
  BuildContext? _context;
  String? _currentCallId;
  bool _isNavigating = false;

  void initialize(BuildContext context) {
    _context = context;
    print('🔔 CallNotificationService: Initializing...');
    _listenForIncomingCalls();
    print('🔔 CallNotificationService: Initialized and listening for calls');
  }

  void _listenForIncomingCalls() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ CallNotificationService: No authenticated user found');
      return;
    }

    print('🔔 CallNotificationService: Setting up listener for user: ${user.uid}');
    
    _callAddedSubscription = FirebaseDatabase.instance
        .ref('calls')
        .onChildAdded
        .listen((event) {
      print('🔔 CallNotificationService: New call detected - ${event.snapshot.key}');
      
      final callData = event.snapshot.value as Map<dynamic, dynamic>?;
      if (callData == null) {
        print('❌ CallNotificationService: Call data is null');
        return;
      }

      print('🔔 CallNotificationService: Call data: $callData');
      
      final receiverId = callData['receiverId'] as String?;
      final currentUserId = user.uid;
      final status = callData['status'] as String?;

      print('🔔 CallNotificationService: receiverId=$receiverId, currentUserId=$currentUserId, status=$status');

      if (receiverId == currentUserId && status == 'ringing') {
        print('🔔 CallNotificationService: Incoming call for current user - navigating to IncomingCallPage');
        
        if (_context != null) {
          Navigator.of(_context!).pushNamed(
            '/incoming_call',
            arguments: {
              'callId': event.snapshot.key,
              'callData': callData,
            },
          );
          print('🔔 CallNotificationService: Navigation completed');
        } else {
          print('❌ CallNotificationService: Context is null, cannot navigate');
        }
      } else {
        print('🔔 CallNotificationService: Call not for current user or not ringing');
      }
    }, onError: (error) {
      print('❌ CallNotificationService: Error listening for calls: $error');
    });

    // Listen for call removals (when caller cancels)
    _callRemovedSubscription = FirebaseDatabase.instance
        .ref('calls')
        .onChildRemoved
        .listen((event) {
      final callId = event.snapshot.key;
      if (callId != null && callId == _currentCallId) {
        // Clear the current call ID when call is removed
        _currentCallId = null;
        // Don't navigate here - let IncomingCallPage handle its own navigation
      }
    });
  }

  void dispose() {
    _callSubscription?.cancel();
    _callRemovedSubscription?.cancel();
    _callSubscription = null;
    _callRemovedSubscription = null;
    _context = null;
    _currentCallId = null;
    _isNavigating = false;
  }

  // Method to check for missed calls or existing calls when app starts
  Future<void> checkForActiveCalls() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _isNavigating) return;

    try {
      final callsRef = FirebaseDatabase.instance.ref('calls');
      final snapshot = await callsRef.get();

      if (snapshot.exists) {
        final calls = snapshot.value as Map<dynamic, dynamic>;
        
        for (final entry in calls.entries) {
          final callId = entry.key as String;
          final callData = entry.value as Map<dynamic, dynamic>;
          
          final receiverId = callData['receiverId'] as String?;
          final callerId = callData['callerId'] as String?;
          final callerEmail = callData['callerEmail'] as String?;
          final status = callData['status'] as String?;
          
          // If there's an active call for this user
          if (receiverId == currentUser.uid && 
              status == 'ringing' &&
              callerId != null &&
              callerEmail != null &&
              !_isNavigating) {
            
            _isNavigating = true;
            
            // Use post-frame callback for safe navigation
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final navigatorState = MyApp.navigatorKey.currentState;
              if (navigatorState != null) {
                navigatorState.push(
                  MaterialPageRoute(
                    builder: (context) => IncomingCallPage(
                      callId: callId,
                      callerEmail: callerEmail,
                      callerId: callerId,
                    ),
                  ),
                ).then((_) {
                  _isNavigating = false;
                });
              } else {
                _isNavigating = false;
              }
            });
            break; // Only handle one call at a time
          }
        }
      }
    } catch (e) {
      print('Error checking for active calls: $e');
      _isNavigating = false;
    }
  }
}