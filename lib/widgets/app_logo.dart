import 'package:flutter/material.dart';

/// A reusable logo component for CleanTrack.
/// Matches the branding icon in assets/logo/app_icon.png:
/// A dark navy circular container with a white concentric ring and rounded checkmark.
class AppLogo extends StatelessWidget {
  /// Diameter of the circular container.
  final double size;

  /// Size of the inner icon. If null, defaults to ~44% of [size].
  final double? iconSize;

  /// Background color of the logo circle.
  final Color backgroundColor;

  /// Icon to display in the center (used in vector fallback).
  final IconData icon;

  /// Color of the inner icon/ring.
  final Color iconColor;

  const AppLogo({
    super.key,
    this.size = 56.0,
    this.iconSize,
    this.backgroundColor = const Color(0xFF0F172A),
    this.icon = Icons.check_rounded,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/logo/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Pixel-accurate vector recreation of app_icon.png if assets are not loaded
          final ringMargin = size * 0.12;
          final effectiveCheckSize = iconSize ?? (size * 0.44);
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: size - (ringMargin * 2),
                height: size - (ringMargin * 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: iconColor,
                    width: size * 0.065,
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: effectiveCheckSize,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
