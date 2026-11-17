import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// DODO Universe "Nordic Forest & Pine" Design System & Theme Foundation.
///
/// Palette:
/// - Primary canvas: Crisp Soft Cream (#FBF9F5)
/// - Surface elements: Pure White (#FFFFFF) & Sandstone Tint (#F3EFE6)
/// - Primary brand: Forest Pine Green (#2D6A4F)
/// - Deep contrast / Headings: Deep Forest Slate (#1B2D2A)
/// - Secondary text: Muted Slate (#52605D)
/// - Borders and dividers: Hairline warm neutral (#EAE5DB)
/// - Sage Accent: Soft Sage (#EAEFE9) / Warm Ochre (#D48B38)
class AppTheme {
  // Canvas & Surfaces
  static const Color canvasColor = Color(0xFFFBF9F5);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3EFE6);
  static const Color surfaceSage = Color(0xFFEAEFE9);
  static const Color backgroundLight = Color(0xFFFBF9F5);

  // Brand Accents - Rich Pine & Forest Theme
  static const Color pineGreen = Color(0xFF2D6A4F);
  static const Color pineGreenDark = Color(0xFF1B4332);
  static const Color pineGreenLight = Color(0xFFE8F3EE);

  // Primary brand is now the deep, elegant Pine Green
  static const Color terracotta = Color(0xFF2D6A4F);
  static const Color terracottaDark = Color(0xFF1B4332);
  static const Color terracottaLight = Color(0xFFE8F3EE);

  static const Color forestSlate = Color(0xFF1B2D2A);
  static const Color forestSlateLight = Color(0xFF2C4440);

  static const Color warmOchre = Color(0xFFD48B38);
  static const Color warmOchreLight = Color(0xFFFDF4E7);

  static const Color rustRed = Color(0xFFC94A29);
  static const Color rustRedLight = Color(0xFFFCEEED);

  // Typography Colors
  static const Color textPrimary = Color(0xFF1B2D2A);
  static const Color textSecondary = Color(0xFF52605D);
  static const Color textMuted = Color(0xFF7A8885);
  static const Color textSubtle = Color(0xFFA5B0AD);

  // Borders & Dividers
  static const Color borderSubtle = Color(0xFFEAE5DB);
  static const Color borderFocused = Color(0xFF2D6A4F);
  static const Color dividerColor = Color(0xFFEAE5DB);

  // Backward-compatibility aliases
  static const Color pureWhite = surfaceWhite;
  static const Color pureBlack = forestSlate;
  static const Color darkGrey = forestSlate;
  static const Color lightGrey = surfaceMuted;
  static const Color primaryGreen = pineGreen;
  static const Color primaryGreenDark = pineGreenDark;
  static const Color primaryGreenLight = pineGreenLight;
  static const Color accentOrange = warmOchre;
  static const Color accentOrangeDark = pineGreen;
  static const Color accentOrangeLight = warmOchreLight;
  static const Color errorRed = rustRed;
  static const Color errorRedLight = rustRedLight;

  // Status colors
  static const Color statusPending = warmOchre;
  static const Color statusActive = pineGreen;
  static const Color statusSuccess = pineGreen;

  // Radii
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 18.0;
  static const double radiusXLarge = 24.0;
  static const double radiusPill = 999.0;

  // Elevation & Shadows
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF1B2D2A).withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: const Color(0xFF1B2D2A).withValues(alpha: 0.07),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get subtleShadow => softShadow;
  static List<BoxShadow> get cardShadow => elevatedShadow;

  /// Main Theme Generator
  static ThemeData get lightTheme {
    final baseTextTheme = Typography.material2021().black;

    // Body font: Plus Jakarta Sans
    final textTheme =
        GoogleFonts.plusJakartaSansTextTheme(baseTextTheme).copyWith(
      displayLarge: GoogleFonts.outfit(
        color: textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 32,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.outfit(
        color: textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 26,
        letterSpacing: -0.3,
      ),
      displaySmall: GoogleFonts.outfit(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 22,
      ),
      titleLarge: GoogleFonts.outfit(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        color: textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        color: textPrimary,
        fontSize: 15,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        color: textSecondary,
        fontSize: 14,
        height: 1.45,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        color: textMuted,
        fontSize: 12,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        color: surfaceWhite,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: 0.2,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        color: textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: pineGreen,
      scaffoldBackgroundColor: canvasColor,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: pineGreen,
        onPrimary: surfaceWhite,
        secondary: forestSlate,
        onSecondary: surfaceWhite,
        tertiary: warmOchre,
        onTertiary: surfaceWhite,
        error: rustRed,
        onError: surfaceWhite,
        surface: surfaceWhite,
        onSurface: textPrimary,
        surfaceContainerHighest: surfaceMuted,
      ),
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 24,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvasColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: forestSlate),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: pineGreen,
          foregroundColor: surfaceWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: forestSlate,
          backgroundColor: surfaceWhite,
          side: const BorderSide(color: borderSubtle, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: pineGreen,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: borderSubtle, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: borderSubtle, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: pineGreen, width: 1.5),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: textSubtle,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceWhite,
        selectedItemColor: pineGreen,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        elevation: 0,
      ),
    );
  }

  static ThemeData get minimalistTheme => lightTheme;
}
