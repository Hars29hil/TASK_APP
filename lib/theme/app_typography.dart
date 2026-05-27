import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// Typography System using Syne (Headers) and DM Sans (Body)
class AppTypography {
  static final TextStyle h1 = GoogleFonts.syne(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.1,
    letterSpacing: -0.5,
  );

  static final TextStyle h2 = GoogleFonts.syne(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static final TextStyle h3 = GoogleFonts.syne(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static final TextStyle bodyLarge = GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static final TextStyle bodyMedium = GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static final TextStyle bodySmall = GoogleFonts.dmSans(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static final TextStyle labelLarge = GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
  );

  static final TextStyle labelMedium = GoogleFonts.dmSans(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.2,
  );

  static final TextStyle labelSmall = GoogleFonts.dmSans(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
    letterSpacing: 0.3,
  );

  static final TextStyle button = GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static final TextStyle overline = GoogleFonts.dmSans(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    color: AppColors.textTertiary,
  );

  static final TextStyle chip = GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  // Chat Text Scale
  static final TextStyle textXs = GoogleFonts.dmSans(
    fontSize: 10,
    fontWeight: FontWeight.w400,
  );

  static final TextStyle textSm = GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static final TextStyle textBase = GoogleFonts.dmSans(
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  static final TextStyle textMd = GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static final TextStyle textLg = GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );
}
