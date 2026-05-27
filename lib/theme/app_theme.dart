import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_typography.dart';

/// Design Tokens for the Light Mode UI/UX Overhaul
class AppColors {
  // Brand Colors
  static const Color warmWhite = Color(0xFFF5F4F0);
  static const Color ink = Color(0xFF111110);
  static const Color electricBlue = Color(0xFF1A6CFF);
  static const Color emerald = Color(0xFF00C27A);
  static const Color highlight = Color(0xFF7C3AED);
  static const Color warning = Color(0xFFF76F27);

  // Dim Accents
  static const Color blueDim = Color(0xFFE8F0FF);
  static const Color emeraldDim = Color(0xFFDCFAEE);
  static const Color purpleDim = Color(0xFFEDE9FF);
  static const Color orangeDim = Color(0xFFFFF0E8);

  // Chat-specific
  static const Color bubbleSent = electricBlue;
  static const Color bubbleReceived = Colors.white;
  static const Color bubbleSystem = warmWhite;
  static const Color bubbleStatus = emeraldDim;

  // Backgrounds & Surfaces
  static const Color bg = warmWhite;
  static const Color surfaceWhite = Colors.white;
  static const Color surfaceGrey = Color(0xFFEAEAEC);
  static const Color surfaceDark = ink;

  // Text
  static const Color textPrimary = ink;
  static const Color textSecondary = Color(0xFF6B6B70);
  static const Color textTertiary = Color(0xFFA0A0A5);
  static const Color textInverse = Colors.white;

  // Status mapping
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return emerald;
      case 'in_progress':
      case 'active':
      case 'ready':
        return electricBlue;
      case 'blocked':
        return warning;
      case 'extended':
        return highlight;
      default:
        return textTertiary;
    }
  }
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  static final BorderRadius borderSm = BorderRadius.circular(8);
  static final BorderRadius borderMd = BorderRadius.circular(16);
  static final BorderRadius borderLg = BorderRadius.circular(24);
  static final BorderRadius borderXl = BorderRadius.circular(32);
  static final BorderRadius borderPill = BorderRadius.circular(999);
}

class AppShadows {
  static final List<BoxShadow> soft = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.05),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  
  static final List<BoxShadow> medium = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.1),
      blurRadius: 30,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.3),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}

ThemeData buildLightTheme() {
  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    primaryColor: AppColors.electricBlue,
    colorScheme: const ColorScheme.light(
      primary: AppColors.electricBlue,
      secondary: AppColors.highlight,
      surface: AppColors.surfaceWhite,
      error: AppColors.warning,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimary,
      onError: Colors.white,
    ),
    textTheme: GoogleFonts.dmSansTextTheme().copyWith(
      displayLarge: AppTypography.h1,
      displayMedium: AppTypography.h2,
      displaySmall: AppTypography.h3,
      bodyLarge: AppTypography.bodyLarge,
      bodyMedium: AppTypography.bodyMedium,
      bodySmall: AppTypography.bodySmall,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.ink),
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: 'Syne',
      ),
    ),
    useMaterial3: true,
  );
}
