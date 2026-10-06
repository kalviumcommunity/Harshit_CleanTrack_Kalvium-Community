import 'package:flutter/material.dart';

/// A reusable circular logo component for CleanTrack.
/// Matches the branding emblem used across Register, Login, and Splash screens.
class AppLogo extends StatelessWidget {
  /// Diameter of the circular container.
  final double size;

  /// Size of the inner icon. If null, defaults to ~58% of [size].
  final double? iconSize;

  /// Background color of the logo circle.
  final Color backgroundColor;

  /// Icon to display in the center.
  final IconData icon;

  /// Color of the inner icon.
  final Color iconColor;

  const AppLogo({
    super.key,
    this.size = 56.0,
    this.iconSize,
    this.backgroundColor = const Color(0xFF0F172A),
    this.icon = Icons.check_circle_outline,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconSize = iconSize ?? (size * 0.57);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          icon,
          color: iconColor,
          size: effectiveIconSize,
        ),
      ),
    );
  }
}
