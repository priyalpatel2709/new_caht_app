import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Text styles for heading / subheading / body / caption using Inter.
abstract final class AppTypography {
  static TextTheme textTheme(ColorScheme scheme, bool isDark) {
    final base = GoogleFonts.interTextTheme();
    final onSurface = scheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.65);

    return base.copyWith(
      displaySmall: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: onSurface,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: onSurface,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: onSurface,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: onSurface,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
    );
  }

  static TextStyle caption(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodySmall!.copyWith(
      fontSize: 12,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
    );
  }

  static TextStyle bubbleText(BuildContext context, {required bool isMine}) {
    final theme = Theme.of(context);
    final c = isMine ? Colors.white : theme.colorScheme.onSurface;
    return GoogleFonts.inter(
      fontSize: 15,
      height: 1.35,
      color: c,
    );
  }

  static TextStyle bubbleCaption(BuildContext context, {required bool isMine}) {
    return GoogleFonts.inter(
      fontSize: 11,
      height: 1.2,
      color: isMine
          ? Colors.white.withValues(alpha: 0.85)
          : AppColors.offline,
    );
  }
}
