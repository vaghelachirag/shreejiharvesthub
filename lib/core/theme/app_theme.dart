import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── COLOR TOKENS (mirroring CSS :root variables) ──────────────────────────────
class AppColors {
  // Greens
  static const greenDark = Color(0xFF2D5A0E);
  static const greenMid = Color(0xFF3B6D11);
  static const greenLight = Color(0xFF4F8A1A);
  static const greenPale = Color(0xFFEAF3DE);
  static const greenMuted = Color(0xFF97C459);

  // Semantic
  static const amber = Color(0xFFD97706);
  static const amberPale = Color(0xFFFEF3C7);
  static const red = Color(0xFFA32D2D);
  static const redPale = Color(0xFFFEE2E2);
  static const blue = Color(0xFF185FA5);
  static const bluePale = Color(0xFFEFF6FF);

  // Backgrounds & Surfaces
  static const bg = Color(0xFFF2F5EE);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFEFF3E8);

  // Borders
  static const border = Color(0x213C6414);
  static const border2 = Color(0x383C6414);

  // Text
  static const textPrimary = Color(0xFF1A2D0A);
  static const textSecondary = Color(0xFF5A6E45);
  static const textTertiary = Color(0xFF8A9E76);

  // Splash gradient
  static const splashStart = Color(0xFF1A3A06);
  static const splashEnd = Color(0xFF3B6D11);
}

// ── SHADOW HELPERS ────────────────────────────────────────────────────────────
class AppShadows {
  static const shadow = [
    BoxShadow(color: Color(0x142D5A0E), blurRadius: 4, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F2D5A0E), blurRadius: 18, offset: Offset(0, 4)),
  ];
  static const shadowLg = [
    BoxShadow(color: Color(0x242D5A0E), blurRadius: 28, offset: Offset(0, 6)),
  ];
}

// ── RADIUS ────────────────────────────────────────────────────────────────────
class AppRadius {
  static const radius = 10.0;
  static const radiusLg = 16.0;
  static const radiusBadge = 20.0;
}

// ── THEME ─────────────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.greenMid,
        primary: AppColors.greenMid,
        secondary: AppColors.greenMuted,
        surface: AppColors.surface,
        error: AppColors.red,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.bg,
    );

    final sora = GoogleFonts.soraTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.sora(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5),
      displayMedium: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      headlineMedium: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      titleLarge: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3),
      titleMedium: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleSmall: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      bodyLarge: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
      bodyMedium: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
      bodySmall: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
      labelLarge: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      labelMedium: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.05),
      labelSmall: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textTertiary),
    );

    return base.copyWith(
      textTheme: sora,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: sora.titleLarge,
      ),
    /*  cardTheme: const CardTheme(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.radiusLg)),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),*/
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border2, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border2, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.greenLight, width: 1.5),
        ),
        hintStyle: GoogleFonts.sora(fontSize: 13, color: AppColors.textTertiary),
        labelStyle: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.greenMid,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
     /* dialogTheme: DialogTheme(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        elevation: 8,
      ),*/
    );
  }
}
