import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  // Revised palette to soft purple–blue pastel
  static const Color primaryColor = Color(0xFF7A6CF2); // soft purple
  static const Color secondaryColor = Color(0xFFA68CFF); // pastel blue-violet
  static const Color accentColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFE57373);
  static const Color warningColor = Color(0xFFFFB74D);
  static const Color successColor = Color(0xFF81C784);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimaryColor = Color(0xFF212121);
  static const Color textSecondaryColor = Color(0xFF757575);
  static const Color textLightColor = Color(0xFFBDBDBD);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, secondaryColor],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentColor, Color(0xFF66BB6A)],
  );

  // Text Styles
  static const TextStyle headingStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600, // semibold per typography system
    color: Colors.white,
  );

  static const TextStyle subheadingStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500, // medium
    color: Colors.white,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400, // regular
    color: textPrimaryColor,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 14,
    color: textSecondaryColor,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // Input Decoration
  static InputDecoration getInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    IconData? suffixIcon,
    VoidCallback? onSuffixPressed,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(prefixIcon, color: primaryColor),
      suffixIcon: suffixIcon != null
          ? IconButton(
              icon: Icon(suffixIcon, color: primaryColor),
              onPressed: onSuffixPressed,
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  // Button Styles
  static Widget primaryButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    double width = double.infinity,
    double height = 56,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10), // unified soft shadow
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isLoading ? null : onPressed,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(text, style: buttonTextStyle),
          ),
        ),
      ),
    );
  }

  static Widget secondaryButton({
    required String text,
    required VoidCallback onPressed,
    double width = double.infinity,
    double height = 56,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Card Styles
  static Widget card({
    required Widget child,
    EdgeInsetsGeometry? padding,
    double borderRadius = 20,
    Color? backgroundColor,
    List<BoxShadow>? boxShadow,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? surfaceColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow:
            boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      child: child,
    );
  }

  // App Bar Style
  static AppBar appBar({
    required String title,
    String? subtitle,
    List<Widget>? actions,
    bool centerTitle = true,
    Color? backgroundColor,
  }) {
    Widget titleWidget;
    if (subtitle == null || subtitle.isEmpty) {
      titleWidget = Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    } else {
      final isOnline = subtitle == 'Đang hoạt động';
      titleWidget = Column(
        crossAxisAlignment: centerTitle
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.greenAccent : Colors.white70,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return AppBar(
      title: titleWidget,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor ?? primaryColor,
      elevation: 0,
      actions: actions,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  // Loading Widget
  static Widget loadingWidget({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message, style: captionStyle, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  // Error Widget
  static Widget errorWidget({required String message, VoidCallback? onRetry}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: errorColor),
          const SizedBox(height: 16),
          Text(message, style: bodyStyle, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            primaryButton(text: 'Thử lại', onPressed: onRetry, width: 120),
          ],
        ],
      ),
    );
  }

  // Empty State Widget
  static Widget emptyStateWidget({
    required String message,
    IconData? icon,
    Widget? action,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon ?? Icons.inbox_outlined, size: 64, color: textLightColor),
          const SizedBox(height: 16),
          Text(message, style: captionStyle, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      ),
    );
  }

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0; // inside card padding baseline
  static const double spacingL = 20.0; // page horizontal padding
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;
  static const double verticalCardSpacing = 14.0; // between cards
  static const double cardPadding = 16.0; // inside card padding

  // Border Radius
  static const double borderRadiusS = 12.0;
  static const double borderRadiusM = 20.0; // for pills/buttons/cards
  static const double borderRadiusL = 22.0; // panels/cards

  // Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.10),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.10),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // Icon scheme
  static const double iconSize = 24.0; // consistent icon size
  static const Color iconInactive = Color(0xFF9AA0B5);
  static const Color iconActiveGlow = Colors.white; // used on gradient pills
}
