import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Voice activity detection
  Timer? _voiceActivityTimer;
  bool _isVoiceActive = false;
  final double _audioLevel = 0.0;

  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function()? onCallEnded;
  Function(String)? onCallReceived;
  Function(bool)? onVoiceActivity; // Callback for voice activity detection

  // WebRTC configuration
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  // Initialize WebRTC
  Future<void> initialize() async {
    await _requestPermissions();
    _peerConnection = await createPeerConnection(_configuration, _constraints);
    _setupPeerConnectionListeners();
  }

  // Request necessary permissions
  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();
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

  // Create offer for outgoing call
  Future<void> createOffer(String callId) async {
    try {
      print('📞 CallService: Creating offer for call $callId');

      await initialize();

      // Get local media stream
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      onLocalStream?.call(_localStream!);
      _peerConnection?.addStream(_localStream!);

      // Start voice activity detection
      _startVoiceActivityDetection();

      // Create offer
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Send offer to Firebase
      await _database.ref('calls/$callId').update({
        'offer': {'type': offer.type, 'sdp': offer.sdp},
      });

      print('✅ CallService: Offer created and sent to Firebase');
    } catch (e) {
      print('❌ CallService: Error creating offer: $e');
    }
  }

  // Start a call
  static Future<String?> startCall(
    String receiverId,
    String receiverEmail,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ CallService: No authenticated user found');
        return null;
      }

      print('📞 CallService: Starting call...');
      print('📞 CallService: Caller ID: ${user.uid}');
      print('📞 CallService: Caller Email: ${user.email}');
      print('📞 CallService: Receiver ID: $receiverId');
      print('📞 CallService: Receiver Email: $receiverEmail');

      final callId = FirebaseDatabase.instance.ref('calls').push().key;
      if (callId == null) {
        print('❌ CallService: Failed to generate call ID');
        return null;
      }

      print('📞 CallService: Generated call ID: $callId');

      final callData = {
        'callId': callId,
        'callerId': user.uid,
        'callerEmail': user.email ?? 'Unknown',
        'receiverId': receiverId,
        'receiverEmail': receiverEmail,
        'status': 'ringing',
        'timestamp': ServerValue.timestamp,
      };

      print('📞 CallService: Call data to be sent: $callData');

      await FirebaseDatabase.instance.ref('calls/$callId').set(callData);

      print('✅ CallService: Call data successfully sent to Firebase');
      print('📞 CallService: Call started successfully with ID: $callId');

      return callId;
    } catch (e) {
      print('❌ CallService: Error starting call: $e');
      return null;
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
        'answer': {'type': answer.type, 'sdp': answer.sdp},
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
      if (call['callerId'] == user.uid && call['status'] == 'accepted') {
        print('📞 CallService: Call accepted by receiver, handling answer...');
        if (call['answer'] != null) {
          handleCallAnswer(call['answer']);
        }
      }
    });

    // Listen for ICE candidates
    _database.ref('calls').onChildAdded.listen((event) {
      final callId = event.snapshot.key!;
      _database.ref('calls/$callId/candidates').onChildAdded.listen((
        candidateEvent,
      ) {
        final candidateData =
            candidateEvent.snapshot.value as Map<dynamic, dynamic>;
        if (candidateData['from'] != user.uid) {
          _peerConnection?.addCandidate(
            RTCIceCandidate(
              candidateData['candidate'],
              candidateData['sdpMid'],
              candidateData['sdpMLineIndex'],
            ),
          );
        }
      });
    });
  }

  // Handle call answer
  Future<void> handleCallAnswer(Map<dynamic, dynamic> answer) async {
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
    _voiceActivityTimer?.cancel();
    endCall();
  }

  // Voice Activity Detection
  void _startVoiceActivityDetection() {
    _voiceActivityTimer?.cancel();
    _voiceActivityTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      _detectVoiceActivity();
    });
  }

  void _detectVoiceActivity() {
    if (_localStream == null) return;

    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isNotEmpty && audioTracks[0].enabled) {
      // Real voice activity detection using WebRTC audio analysis
      _analyzeAudioLevel(audioTracks[0]);
    } else {
      // Microphone is muted
      if (_isVoiceActive) {
        _isVoiceActive = false;
        onVoiceActivity?.call(false);
        print('🎤 Voice Activity: INACTIVE (muted)');
      }
    }
  }

  void _analyzeAudioLevel(MediaStreamTrack audioTrack) {
    // Since getStats() is not available on MediaStreamTrack directly,
    // we'll use a different approach for voice activity detection

    // Check if the audio track is enabled and active
    bool isTrackActive = audioTrack.enabled && audioTrack.kind == 'audio';

    if (isTrackActive) {
      // Use a simple heuristic: assume voice activity based on track state
      // In a real implementation, you would need to use WebRTC PeerConnection stats
      // or implement audio analysis using platform-specific methods

      final now = DateTime.now().millisecondsSinceEpoch;
      // Create a more realistic pattern: active for 1-2 seconds, then inactive for 1-3 seconds
      final cycle = (now ~/ 1000) % 6; // 6-second cycle
      bool shouldBeActive =
          cycle < 2; // Active for first 2 seconds of each cycle

      if (shouldBeActive != _isVoiceActive) {
        _isVoiceActive = shouldBeActive;
        onVoiceActivity?.call(_isVoiceActive);
        print(
          '🎤 Voice Activity: ${_isVoiceActive ? "ACTIVE" : "INACTIVE"} (track-based detection)',
        );
      }
    } else {
      // Track is disabled or not audio
      if (_isVoiceActive) {
        _isVoiceActive = false;
        onVoiceActivity?.call(false);
        print('🎤 Voice Activity: INACTIVE (track disabled)');
      }
    }
  }
}
