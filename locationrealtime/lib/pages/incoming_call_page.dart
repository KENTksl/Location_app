import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme.dart';
import '../services/call_service.dart';
import 'call_page.dart';

class IncomingCallPage extends StatefulWidget {
  final String callId;
  final String callerEmail;
  final String callerId;

  const IncomingCallPage({
    super.key,
    required this.callId,
    required this.callerEmail,
    required this.callerId,
  });

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  final CallService _callService = CallService();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    // Pulse animation for avatar
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Slide animation for buttons
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );
    _slideController.forward();
  }

  Future<void> _acceptCall() async {
    try {
      // Get call data from Firebase
      final callRef = FirebaseDatabase.instance.ref('calls/${widget.callId}');
      final snapshot = await callRef.get();
      
      if (snapshot.exists) {
        final callData = snapshot.value as Map<dynamic, dynamic>;
        final offer = Map<String, dynamic>.from(callData['offer'] as Map<dynamic, dynamic>);
        
        // Answer the call
        await _callService.answerCall(widget.callId, offer);
        
        // Navigate to call page
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CallPage(
                friendId: widget.callerId,
                friendEmail: widget.callerEmail,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error accepting call: $e');
      _declineCall();
    }
  }

  Future<void> _declineCall() async {
    try {
      // Remove call from Firebase
      await FirebaseDatabase.instance.ref('calls/${widget.callId}').remove();
    } catch (e) {
      print('Error declining call: $e');
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Widget _buildAvatar() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          widget.callerEmail.isNotEmpty
              ? widget.callerEmail[0].toUpperCase()
              : '?',
          style: const TextStyle(
            fontSize: 50,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    Color iconColor = Colors.white,
    double size = 70,
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
            blurRadius: 10,
            offset: const Offset(0, 5),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),

              // Incoming call text
              const Text(
                'Cuộc gọi đến',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                ),
              ),

              const SizedBox(height: 40),

              // Avatar with pulse animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: _buildAvatar(),
                  );
                },
              ),

              const SizedBox(height: 30),

              // Caller name
              Text(
                widget.callerEmail,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              const Text(
                'Cuộc gọi thoại',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),

              const Spacer(),

              // Action buttons with slide animation
              SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Decline button
                      _buildActionButton(
                        icon: Icons.call_end,
                        onPressed: _declineCall,
                        backgroundColor: Colors.red,
                      ),

                      // Accept button
                      _buildActionButton(
                        icon: Icons.call,
                        onPressed: _acceptCall,
                        backgroundColor: Colors.green,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // Quick actions
              SlideTransition(
                position: _slideAnimation,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.message,
                      onPressed: () {
                        _declineCall();
                        // Could navigate to chat instead
                      },
                      backgroundColor: Colors.white.withOpacity(0.2),
                      size: 50,
                    ),
                    _buildActionButton(
                      icon: Icons.person_add_disabled,
                      onPressed: () {
                        // Block user functionality
                        _declineCall();
                      },
                      backgroundColor: Colors.white.withOpacity(0.2),
                      size: 50,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }
}
