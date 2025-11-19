import 'package:flutter/material.dart';
import '../theme.dart';

enum AppToastType { success, warning, error }

class ToastService {
  static void show(
    BuildContext context, {
    required String message,
    required AppToastType type,
  }) {
    final colors = _colorsFor(type);
    final icon = _iconFor(type);
    final entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        background: colors.background,
        shadowColor: colors.shadow,
        icon: icon,
      ),
    );

    // Dùng root overlay để toast hiển thị kể cả khi route hiện tại bị pop ngay sau đó
    final overlay = Overlay.of(context, rootOverlay: true);
    overlay?.insert(entry);

    Future.delayed(const Duration(milliseconds: 2200), () {
      entry.remove();
    });
  }

  static _ToastColors _colorsFor(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return _ToastColors(
          backgroundGradient: AppTheme.primaryGradient,
          background: null,
          shadow: Colors.black.withOpacity(0.15),
        );
      case AppToastType.warning:
        return _ToastColors(
          background: const Color(0xFFFFF4CC),
          shadow: Colors.black.withOpacity(0.15),
        );
      case AppToastType.error:
        return _ToastColors(
          background: const Color(0xFFFFE5E5),
          shadow: Colors.black.withOpacity(0.15),
        );
    }
  }

  static IconData _iconFor(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return Icons.check_circle_rounded;
      case AppToastType.warning:
        return Icons.warning_amber_rounded;
      case AppToastType.error:
        return Icons.error_rounded;
    }
  }
}

class _ToastColors {
  final LinearGradient? backgroundGradient;
  final Color? background;
  final Color shadow;
  _ToastColors({this.backgroundGradient, this.background, required this.shadow});
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final LinearGradient? backgroundGradient;
  final Color? background;
  final Color shadowColor;
  final IconData icon;

  const _ToastWidget({
    super.key,
    required this.message,
    this.background,
    this.backgroundGradient,
    required this.shadowColor,
    required this.icon,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slide = Tween<double>(begin: -30, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fade.value,
            child: Transform.translate(
              offset: Offset(0, _slide.value),
              child: Container(
                margin: const EdgeInsets.only(top: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.background,
                  gradient: widget.backgroundGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: widget.shadowColor,
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: AppTheme.textPrimaryColor),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: AppTheme.bodyStyle
                            .copyWith(color: AppTheme.textPrimaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    return Positioned(
      top: MediaQuery.of(context).padding.top + 6,
      left: 12,
      right: 12,
      child: Center(child: content),
    );
  }
}