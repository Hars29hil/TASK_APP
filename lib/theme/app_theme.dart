import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_typography.dart';

/// Design Tokens for the Light Mode UI/UX Overhaul
class AppColors {
  // Brand Colors
  static const Color background = Color(0xFFF8F9FA); // Clean light grey
  static const Color ink = Color(0xFF111110); // Very dark grey/black
  static const Color electricBlue = Color(0xFF2563EB); // Modern standard blue (Tailwind blue-600)
  static const Color emerald = Color(0xFF10B981); // Modern emerald
  static const Color highlight = Color(0xFF8B5CF6); // Modern purple
  static const Color warning = Color(0xFFF59E0B); // Modern amber/orange
  static const Color danger = Color(0xFFEF4444); // Modern red

  // Dim Accents
  static const Color blueDim = Color(0xFFEFF6FF);
  static const Color emeraldDim = Color(0xFFECFDF5);
  static const Color purpleDim = Color(0xFFF5F3FF);
  static const Color orangeDim = Color(0xFFFFFBEB);

  // Chat-specific
  static const Color bubbleSent = electricBlue;
  static const Color bubbleReceived = Colors.white;
  static const Color bubbleSystem = background;
  static const Color bubbleStatus = emeraldDim;

  // Backgrounds & Surfaces
  static const Color bg = background;
  static const Color surfaceWhite = Colors.white;
  static const Color surfaceGrey = Color(0xFFF1F5F9); // Very light slate
  static const Color border = Color(0xFFE2E8F0); // Subtle border color
  static const Color surfaceDark = ink;

  // Text
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textTertiary = Color(0xFF94A3B8); // Slate 400
  static const Color textInverse = Colors.white;

  // Status mapping
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return emerald;
      case 'in_progress':
      case 'active':
      case 'ready':
        return electricBlue;
      case 'blocked':
        return danger;
      case 'extended':
        return warning;
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
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.02),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];
  
  static final List<BoxShadow> medium = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.25),
      blurRadius: 12,
      offset: const Offset(0, 4),
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
      ),
    ),
    useMaterial3: true,
  );
}
