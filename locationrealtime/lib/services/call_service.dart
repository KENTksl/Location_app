import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function()? onCallEnded;
  Function(String)? onCallReceived;

  // WebRTC configuration
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ]
  };

  // Initialize WebRTC
  Future<void> initialize() async {
    await _requestPermissions();
    _peerConnection = await createPeerConnection(_configuration, _constraints);
    _setupPeerConnectionListeners();
  }

  // Request necessary permissions
  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  // Setup peer connection event listeners
  void _setupPeerConnectionListeners() {
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      _sendIceCandidate(candidate);
    };

    _peerConnection?.onAddStream = (MediaStream stream) {
      _remoteStream = stream;
      onRemoteStream?.call(stream);
    };

    _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        endCall();
      }
    };
  }

  // Start a call
  Future<void> startCall(String friendId) async {
    try {
      await initialize();
      
      // Get local media stream
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false, // Audio only for now
      });
      
      onLocalStream?.call(_localStream!);
      _peerConnection?.addStream(_localStream!);

      // Create offer
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Get caller info
      final user = _auth.currentUser;
      if (user != null) {
        // Get caller email from user profile
        final userSnapshot = await _database.ref('users/${user.uid}').get();
        final userData = userSnapshot.value as Map<dynamic, dynamic>?;
        final callerEmail = userData?['email'] ?? user.email ?? 'Unknown';

        // Send call invitation to Firebase with correct structure
        await _database.ref('calls/${user.uid}_$friendId').set({
          'callerId': user.uid,
          'receiverId': friendId,
          'callerEmail': callerEmail,
          'offer': {
            'type': offer.type,
            'sdp': offer.sdp,
          },
          'status': 'ringing',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      print('Error starting call: $e');
    }
  }

  // Answer a call
  Future<void> answerCall(String callId, Map<String, dynamic> offer) async {
    try {
      await initialize();
      
      // Get local media stream
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      
      onLocalStream?.call(_localStream!);
      _peerConnection?.addStream(_localStream!);

      // Set remote description
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );

      // Create answer
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Send answer to Firebase
      await _database.ref('calls/$callId').update({
        'answer': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
        'status': 'answered',
      });
    } catch (e) {
      print('Error answering call: $e');
    }
  }

  // Send ICE candidate
  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    final user = _auth.currentUser;
    if (user != null) {
      // Find active call
      final callsRef = _database.ref('calls');
      final snapshot = await callsRef.get();
      
      if (snapshot.exists) {
        final calls = snapshot.value as Map<dynamic, dynamic>;
        for (final callId in calls.keys) {
          final call = calls[callId] as Map<dynamic, dynamic>;
          if (call['callerId'] == user.uid || call['receiverId'] == user.uid) {
            await _database.ref('calls/$callId/candidates').push().set({
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
              'from': user.uid,
            });
            break;
          }
        }
      }
    }
  }

  // Listen for incoming calls
  void listenForCalls() {
    final user = _auth.currentUser;
    if (user == null) return;

    _database.ref('calls').onChildAdded.listen((event) {
      final call = event.snapshot.value as Map<dynamic, dynamic>;
      if (call['receiverId'] == user.uid && call['status'] == 'ringing') {
        onCallReceived?.call(event.snapshot.key!);
      }
    });

    // Listen for call answers
    _database.ref('calls').onChildChanged.listen((event) {
      final call = event.snapshot.value as Map<dynamic, dynamic>;
      if (call['callerId'] == user.uid && call['status'] == 'answered') {
        _handleCallAnswer(call['answer']);
      }
    });

    // Listen for ICE candidates
    _database.ref('calls').onChildAdded.listen((event) {
      final callId = event.snapshot.key!;
      _database.ref('calls/$callId/candidates').onChildAdded.listen((candidateEvent) {
        final candidateData = candidateEvent.snapshot.value as Map<dynamic, dynamic>;
        if (candidateData['from'] != user.uid) {
          _peerConnection?.addCandidate(RTCIceCandidate(
            candidateData['candidate'],
            candidateData['sdpMid'],
            candidateData['sdpMLineIndex'],
          ));
        }
      });
    });
  }

  // Handle call answer
  Future<void> _handleCallAnswer(Map<dynamic, dynamic> answer) async {
    await _peerConnection?.setRemoteDescription(
      RTCSessionDescription(answer['sdp'], answer['type']),
    );
  }

  // End call
  Future<void> endCall() async {
    // Close streams
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _remoteStream?.getTracks().forEach((track) {
      track.stop();
    });

    // Close peer connection
    await _peerConnection?.close();
    
    // Clean up
    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;

    // Remove call from Firebase
    final user = _auth.currentUser;
    if (user != null) {
      final callsRef = _database.ref('calls');
      final snapshot = await callsRef.get();
      
      if (snapshot.exists) {
        final calls = snapshot.value as Map<dynamic, dynamic>;
        for (final callId in calls.keys) {
          final call = calls[callId] as Map<dynamic, dynamic>;
          if (call['callerId'] == user.uid || call['receiverId'] == user.uid) {
            await _database.ref('calls/$callId').remove();
            break;
          }
        }
      }
    }

    onCallEnded?.call();
  }

  // Toggle mute
  void toggleMute() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        audioTracks[0].enabled = !audioTracks[0].enabled;
      }
    }
  }

  // Toggle speaker
  void toggleSpeaker() {
    // This would typically involve platform-specific code
    // For now, we'll just print a message
    print('Toggle speaker');
  }

  // Dispose
  void dispose() {
    endCall();
  }
}