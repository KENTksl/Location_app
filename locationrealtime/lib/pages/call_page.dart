import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../theme.dart';
import '../services/call_service.dart';
import 'dart:async';

class CallPage extends StatefulWidget {
  final String friendId;
  final String friendEmail;
  final String? callId; // Add callId parameter for existing calls

  const CallPage({
    super.key,
    required this.friendId,
    required this.friendEmail,
    this.callId, // Optional callId for joining existing calls
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> with TickerProviderStateMixin {
  bool _isCallActive = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoOn = false;
  bool _isOfferProcessed = false; // Add flag to prevent duplicate offer processing
  bool _isVoiceActive = false; // Add voice activity state
  Timer? _callTimer;
  int _callDuration = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _voiceActivityController; // Add voice activity animation controller
  late Animation<double> _voiceActivityAnimation;

  final CallService _callService = CallService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupCallService();
    _initializeCall();
  }

  void _setupCallService() {
    _callService.onLocalStream = (MediaStream stream) {
      _localRenderer.srcObject = stream;
    };

    _callService.onRemoteStream = (MediaStream stream) {
      _remoteRenderer.srcObject = stream;
      setState(() {
        _isCallActive = true;
      });
      // Timer will be started when call status changes to 'accepted'
    };

    _callService.onCallEnded = () {
      // Use post-frame callback to ensure safe execution
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _endCall();
        }
      });
    };
    
    // Voice activity callback
    _callService.onVoiceActivity = (bool isActive) {
      if (mounted) {
        setState(() {
          _isVoiceActive = isActive;
        });
        
        if (isActive) {
          _voiceActivityController.forward();
        } else {
          _voiceActivityController.reverse();
        }
      }
    };
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
    
    // Voice activity animation
    _voiceActivityController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _voiceActivityAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _voiceActivityController, curve: Curves.easeInOut),
    );
  }

  void _initializeCall() async {
    print('📞 CallPage: Initializing call for ${widget.friendEmail}');
    
    // Initialize WebRTC renderers
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    
    print('📞 CallPage: Renderers initialized');

    if (widget.callId != null) {
      // Join existing call (when accepting incoming call)
      print('📞 CallPage: Joining existing call ${widget.callId}');
      await _joinExistingCall(widget.callId!);
    } else {
      // Start new call
      print('📞 CallPage: Starting new call');
      final callId = await CallService.startCall(widget.friendId, widget.friendEmail);
      if (callId != null) {
        print('✅ CallPage: Call started successfully with ID: $callId');
        // Listen for receiver's response
        _listenForAnswer(callId);
      } else {
        print('❌ CallPage: Failed to start call');
      }
    }
  }

  Future<void> _joinExistingCall(String callId) async {
    try {
      print('📞 CallPage: Getting call data from Firebase');
      final callRef = FirebaseDatabase.instance.ref('calls/$callId');
      final snapshot = await callRef.get();
      
      if (snapshot.exists) {
        final callData = snapshot.value as Map<dynamic, dynamic>;
        print('📞 CallPage: Call data retrieved: ${callData.keys}');
        
        // Check if this is the receiver accepting the call
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && callData['receiverId'] == currentUser.uid) {
          print('📞 CallPage: This user is the receiver - waiting for offer from caller');
          
          // Listen for offer from caller
          _listenForOffer(callId);
          
          setState(() {
            _isCallActive = true;
          });
          _startCallTimer(); // Receiver starts timer immediately
          print('✅ CallPage: Successfully joined call as receiver');
        } else if (callData['offer'] != null) {
          // This is the caller or offer already exists
          final offer = Map<String, dynamic>.from(callData['offer'] as Map<dynamic, dynamic>);
          print('📞 CallPage: Answering call with existing offer');
          await _callService.answerCall(callId, offer);
          
          setState(() {
            _isCallActive = true;
          });
          _startCallTimer(); // Receiver starts timer immediately
          print('✅ CallPage: Successfully joined call with existing offer');
        } else {
          print('📞 CallPage: No offer found, creating offer as caller');
          await _createOfferForCall(callId);
        }
      } else {
        print('❌ CallPage: Call data not found');
      }
    } catch (e) {
      print('❌ CallPage: Error joining call: $e');
    }
  }

  void _listenForOffer(String callId) {
    print('📞 CallPage: Listening for offer from caller');
    final callRef = FirebaseDatabase.instance.ref('calls/$callId');
    
    callRef.onValue.listen((event) async {
      if (event.snapshot.exists) {
        final callData = event.snapshot.value as Map<dynamic, dynamic>;
        
        if (callData['offer'] != null && !_isOfferProcessed) {
          _isOfferProcessed = true;
          print('📞 CallPage: Offer received from caller');
          
          final offer = Map<String, dynamic>.from(callData['offer'] as Map<dynamic, dynamic>);
          await _callService.answerCall(callId, offer);
          print('✅ CallPage: Successfully answered call');
        }
      }
    });
  }

  Future<void> _createOfferForCall(String callId) async {
    try {
      print('📞 CallPage: Creating offer for call');
      
      // Use CallService to create offer
      await _callService.createOffer(callId);
      
      // Listen for answer from receiver
      _listenForAnswer(callId);
      
      setState(() {
        _isCallActive = false; // Caller is not active until receiver accepts
      });
      // Don't start timer here - wait for receiver to accept
      print('✅ CallPage: Offer creation completed, waiting for receiver to accept');
    } catch (e) {
      print('❌ CallPage: Error creating offer: $e');
    }
  }

  void _listenForAnswer(String callId) {
    print('📞 CallPage: Listening for answer from receiver');
    final callRef = FirebaseDatabase.instance.ref('calls/$callId');
    
    callRef.onValue.listen((event) async {
      if (event.snapshot.exists) {
        final callData = event.snapshot.value as Map<dynamic, dynamic>;
        
        // Check if call was accepted (status changed to 'accepted')
         if (callData['status'] == 'accepted') {
           print('📞 CallPage: Call accepted by receiver, updating UI');
           
           // Update UI to show call is connected
           if (mounted) {
             setState(() {
               _isCallActive = true;
             });
             // Start timer when call becomes active
             _startCallTimer();
           }
           
           // If answer is available, process it
           if (callData['answer'] != null) {
             print('📞 CallPage: Answer received from receiver');
             
             final answer = Map<String, dynamic>.from(callData['answer'] as Map<dynamic, dynamic>);
             await _callService.handleCallAnswer(answer);
             print('✅ CallPage: Successfully processed answer');
           }
         }
        
        // Also listen for answered status (backup)
        if (callData['answer'] != null && callData['status'] == 'answered') {
          print('📞 CallPage: Answer received from receiver (answered status)');
          
          final answer = Map<String, dynamic>.from(callData['answer'] as Map<dynamic, dynamic>);
          await _callService.handleCallAnswer(answer);
          print('✅ CallPage: Successfully processed answer');
        }
      }
    });
  }

  void _startCallTimer() {
    // Only start timer if call is active
    if (!_isCallActive) return;
    
    _callTimer?.cancel(); // Cancel existing timer if any
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isCallActive) {
        setState(() {
          _callDuration++;
        });
      } else {
        timer.cancel();
      }
    });
    print('⏰ CallPage: Call timer started');
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _endCall() {
    _callTimer?.cancel();
    // Check if controller is still active before stopping
    if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
    _callService.endCall();
    
    // Use post-frame callback for safe navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _callService.toggleMute();
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    _callService.toggleSpeaker();
  }

  void _toggleVideo() {
    setState(() {
      _isVideoOn = !_isVideoOn;
    });
  }

  Widget _buildCallButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    Color iconColor = Colors.white,
    double size = 60,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: onPressed,
          child: Icon(icon, color: iconColor, size: size * 0.4),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return AnimatedBuilder(
      animation: _voiceActivityAnimation,
      builder: (context, child) {
        return Container(
          width: 150 * _voiceActivityAnimation.value,
          height: 150 * _voiceActivityAnimation.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.primaryGradient,
            border: _isVoiceActive 
                ? Border.all(
                    color: Colors.green,
                    width: 4.0,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              if (_isVoiceActive)
                BoxShadow(
                  color: Colors.green.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
            ],
          ),
          child: Center(
            child: Text(
              widget.friendEmail.isNotEmpty
                  ? widget.friendEmail[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
            ),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _endCall,
                    ),
                    const Spacer(),
                    Text(
                      _isCallActive ? 'Trong cuộc gọi' : 'Đang kết nối...',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),

              const Spacer(),

              // Avatar and info
              Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isCallActive ? 1.0 : _pulseAnimation.value,
                        child: _buildAvatar(),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  Text(
                    widget.friendEmail,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isCallActive
                        ? _formatDuration(_callDuration)
                        : 'Đang gọi...',
                    style: TextStyle(
                      color: _isCallActive ? Colors.green : Colors.white70, 
                      fontSize: 18,
                      fontWeight: _isCallActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Call controls
              Padding(
                padding: const EdgeInsets.all(40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCallButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      onPressed: _toggleMute,
                      backgroundColor: _isMuted
                          ? Colors.red.withOpacity(0.8)
                          : Colors.white.withOpacity(0.2),
                      size: 60,
                    ),
                    _buildCallButton(
                      icon: Icons.call_end,
                      onPressed: _endCall,
                      backgroundColor: Colors.red,
                      size: 70,
                    ),
                    _buildCallButton(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                      onPressed: _toggleSpeaker,
                      backgroundColor: _isSpeakerOn
                          ? AppTheme.primaryColor
                          : Colors.white.withOpacity(0.2),
                      size: 60,
                    ),
                  ],
                ),
              ),

              // Additional controls
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCallButton(
                      icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
                      onPressed: _toggleVideo,
                      backgroundColor: _isVideoOn
                          ? AppTheme.accentColor
                          : Colors.white.withOpacity(0.2),
                      size: 50,
                    ),
                    _buildCallButton(
                      icon: Icons.message,
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      backgroundColor: Colors.white.withOpacity(0.2),
                      size: 50,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    // Stop animation before disposing if it's still running
    if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
    _pulseController.dispose();
    
    // Dispose voice activity controller
    if (_voiceActivityController.isAnimating) {
      _voiceActivityController.stop();
    }
    _voiceActivityController.dispose();
    
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _callService.dispose();
    super.dispose();
  }
}