import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../pages/incoming_call_page.dart';

class CallNotificationService {
  static final CallNotificationService _instance = CallNotificationService._internal();
  factory CallNotificationService() => _instance;
  CallNotificationService._internal();

  StreamSubscription<DatabaseEvent>? _callSubscription;
  BuildContext? _context;

  void initialize(BuildContext context) {
    _context = context;
    _listenForIncomingCalls();
  }

  void _listenForIncomingCalls() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final callsRef = FirebaseDatabase.instance.ref('calls');
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
          _context != null &&
          callerId != null &&
          callerEmail != null) {
        
        // Navigate to incoming call page
        Navigator.of(_context!).push(
          MaterialPageRoute(
            builder: (context) => IncomingCallPage(
              callId: event.snapshot.key!,
              callerEmail: callerEmail,
              callerId: callerId,
            ),
          ),
        );
      }
    });
  }

  void dispose() {
    _callSubscription?.cancel();
    _callSubscription = null;
    _context = null;
  }

  // Method to check for missed calls or existing calls when app starts
  Future<void> checkForActiveCalls() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _context == null) return;

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
              callerEmail != null) {
            
            Navigator.of(_context!).push(
              MaterialPageRoute(
                builder: (context) => IncomingCallPage(
                  callId: callId,
                  callerEmail: callerEmail,
                  callerId: callerId,
                ),
              ),
            );
            break; // Only handle one call at a time
          }
        }
      }
    } catch (e) {
      print('Error checking for active calls: $e');
    }
  }
}