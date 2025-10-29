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
  StreamSubscription<DatabaseEvent>? _callRemovedSubscription;
  BuildContext? _context;
  String? _currentCallId;
  bool _isNavigating = false;

  void initialize(BuildContext context) {
    _context = context;
    _listenForIncomingCalls();
  }

  void _listenForIncomingCalls() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final callsRef = FirebaseDatabase.instance.ref('calls');
    
    // Listen for new calls
    _callSubscription = callsRef.onChildAdded.listen((event) {
      final callData = event.snapshot.value as Map<dynamic, dynamic>?;
      if (callData == null) return;

      final receiverId = callData['receiverId'] as String?;
      final callerId = callData['callerId'] as String?;
      final callerEmail = callData['callerEmail'] as String?;
      final status = callData['status'] as String?;

      // Check if this call is for the current user and is still ringing
      if (receiverId == currentUser.uid && 
          status == 'ringing' && 
          callerId != null &&
          callerEmail != null &&
          !_isNavigating) {
        
        // Store current call ID
        _currentCallId = event.snapshot.key!;
        _isNavigating = true;
        
        // Use post-frame callback for safe navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final navigatorState = MyApp.navigatorKey.currentState;
          if (navigatorState != null && navigatorState.canPop()) {
            navigatorState.push(
              MaterialPageRoute(
                builder: (context) => IncomingCallPage(
                  callId: event.snapshot.key!,
                  callerEmail: callerEmail,
                  callerId: callerId,
                ),
              ),
            ).then((_) {
              // Clear current call ID and navigation flag when page is dismissed
              _currentCallId = null;
              _isNavigating = false;
            });
          } else {
            // Reset navigation flag if we can't navigate
            _isNavigating = false;
          }
        });
      }
    });

    // Listen for call removals (when caller cancels)
    _callRemovedSubscription = callsRef.onChildRemoved.listen((event) {
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