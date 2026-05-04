import 'package:flutter/material.dart';

/// Design tokens — primary, surfaces, semantic colors for light and dark.
abstract final class AppColors {
  static const Color primary = Color(0xFF5865F2);
  static const Color accent = Color(0xFFFF6B6B);

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF8FAFC);
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);

  static const Color sentBubbleLight = primary;
  static const Color sentBubbleDark = Color(0xFF4752C4);
  static const Color receivedBubbleLight = Color(0xFFE2E8F0);
  static const Color receivedBubbleDark = Color(0xFF334155);

  static const Color online = Color(0xFF22C55E);
  static const Color offline = Color(0xFF94A3B8);
}
