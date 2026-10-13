import 'package:flutter/material.dart';

/// Computes initials dynamically from a user's full name without arbitrary fallback defaults.
String getUserInitials(String? name) {
  if (name == null || name.trim().isEmpty) return '';
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
    return parts[0][0].toUpperCase();
  }
  return '';
}

/// A reusable avatar widget displaying user initials in a stylized circle.
class UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color backgroundColor;
  final Color textColor;
  final double? fontSize;
  final FontWeight fontWeight;

  const UserAvatar({
    super.key,
    required this.name,
    this.size = 40.0,
    this.backgroundColor = const Color(0xFFF1F5F9),
    this.textColor = const Color(0xFF0F172A),
    this.fontSize,
    this.fontWeight = FontWeight.bold,
  });

  @override
  Widget build(BuildContext context) {
    final initials = getUserInitials(name);
    final calculatedFontSize = fontSize ?? (size * 0.38).clamp(10.0, 24.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: textColor,
          fontSize: calculatedFontSize,
          fontWeight: fontWeight,
        ),
      ),
    );
  }
}
