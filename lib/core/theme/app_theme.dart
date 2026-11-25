import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/colors.dart';
import '../constants/dimensions.dart';

/// Typography convenience helpers enforcing tabular numerals where aligned
/// numbers appear (currency, presence metrics, timers, points).
extension CasamaTextStyleX on TextStyle {
  TextStyle get tabular =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

class CasamaTheme {
  static ThemeData? _cachedLight;
  static ThemeData? _cachedDark;

  static ThemeData get lightTheme => _cachedLight ??= _buildLightTheme();
  static ThemeData get darkTheme => _cachedDark ??= _buildDarkTheme();

  static TextTheme _buildTextTheme(
    TextTheme base, {
    required Color primary,
    required Color secondary,
  }) {
    final interBase = GoogleFonts.interTextTheme(base);

    return interBase.copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        color: primary,
        fontSize: 28,
        height: 34 / 28,
        letterSpacing: -0.5,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        color: primary,
        fontSize: 24,
        height: 30 / 24,
        letterSpacing: -0.4,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        color: primary,
        fontSize: 22,
        height: 28 / 22,
        letterSpacing: -0.25,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        color: primary,
        fontSize: 20,
        height: 26 / 20,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        color: primary,
        fontSize: 18,
        height: 24 / 18,
        letterSpacing: -0.15,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        color: primary,
        fontSize: 16,
        height: 22 / 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        color: primary,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.inter(
        color: primary,
        fontSize: 15,
        height: 22 / 15,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.inter(
        color: secondary,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: GoogleFonts.inter(
        color: secondary,
        fontSize: 12.5,
        height: 18 / 12.5,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.inter(
        color: primary,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: GoogleFonts.inter(
        color: secondary,
        fontSize: 12,
        height: 16 / 12,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: GoogleFonts.inter(
        color: secondary,
        fontSize: 11,
        height: 14 / 11,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static ThemeData _buildLightTheme() {
    const pal = CasamaPalette.light;
    final textTheme = _buildTextTheme(
      ThemeData.light().textTheme,
      primary: pal.textPrimary,
      secondary: pal.textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: pal.scaffoldBg,
      extensions: const [pal],
      colorScheme: ColorScheme.light(
        primary: pal.primaryCoral,
        secondary: pal.forestTeal,
        surface: pal.surface,
        error: pal.dangerFg,
        onPrimary: pal.onPrimaryCoral,
        onSecondary: pal.onForestTeal,
        onSurface: pal.textPrimary,
        onSurfaceVariant: pal.textSecondary,
        outline: pal.inputBorder,
        outlineVariant: pal.border,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: pal.textPrimary),
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: pal.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: CasamaSpacing.roundedCard,
          side: BorderSide(color: pal.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: pal.divider,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: pal.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: CasamaSpacing.roundedSheetTop,
        ),
        showDragHandle: true,
        dragHandleColor: pal.border,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: pal.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: CasamaSpacing.roundedXl),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: CasamaColors.midnightNavy,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: CasamaSpacing.roundedPill,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pal.track,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: CasamaSpacing.roundedInput,
          borderSide: BorderSide(color: pal.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: CasamaSpacing.roundedInput,
          borderSide: BorderSide(color: Colors.transparent, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: CasamaSpacing.roundedInput,
          borderSide: BorderSide(color: pal.forestTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: CasamaSpacing.roundedInput,
          borderSide: BorderSide(color: pal.dangerFg, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: CasamaSpacing.roundedInput,
          borderSide: BorderSide(color: pal.dangerFg, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: CasamaSpacing.roundedInput,
          borderSide: BorderSide(color: pal.border, width: 1),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: pal.textMuted),
        labelStyle: textTheme.labelMedium?.copyWith(color: pal.textSecondary),
        errorStyle: textTheme.labelMedium?.copyWith(color: pal.dangerFg),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: pal.primaryCoral,
          foregroundColor: pal.onPrimaryCoral,
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: pal.primaryCoral,
          foregroundColor: pal.onPrimaryCoral,
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: pal.textPrimary,
          side: BorderSide(color: pal.border, width: 1),
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: pal.primaryCoral,
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    const pal = CasamaPalette.dark;
    final textTheme = _buildTextTheme(
      ThemeData.dark().textTheme,
      primary: pal.textPrimary,
      secondary: pal.textSecondary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: pal.scaffoldBg,
      extensions: const [pal],
      colorScheme: ColorScheme.dark(
        primary: pal.primaryCoral,
        secondary: pal.forestTeal,
        surface: pal.surface,
        error: pal.dangerFg,
        onPrimary: pal.onPrimaryCoral,
        onSecondary: pal.onForestTeal,
        onSurface: pal.textPrimary,
        onSurfaceVariant: pal.textSecondary,
        outline: pal.inputBorder,
        outlineVariant: pal.border,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: pal.textPrimary),
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: pal.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: CasamaSpacing.roundedCard,
          side: BorderSide(color: pal.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: pal.divider,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: pal.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: CasamaSpacing.roundedSheetTop,
        ),
        showDragHandle: true,
        dragHandleColor: pal.border,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: pal.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: CasamaSpacing.roundedXl),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: pal.card,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: pal.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: CasamaSpacing.roundedPill,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pal.track,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: CasamaSpacing.roundedInput,
          borderSide: BorderSide(color: pal.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: CasamaSpacing.roundedInput,
          borderSide: BorderSide(color: pal.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: CasamaSpacing.roundedInput,
          borderSide: BorderSide(color: pal.forestTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: CasamaSpacing.roundedInput,
          borderSide: BorderSide(color: pal.dangerFg, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: CasamaSpacing.roundedInput,
          borderSide: BorderSide(color: pal.dangerFg, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: CasamaSpacing.roundedInput,
          borderSide: BorderSide(color: pal.border, width: 1),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: pal.textMuted),
        labelStyle: textTheme.labelMedium?.copyWith(color: pal.textSecondary),
        errorStyle: textTheme.labelMedium?.copyWith(color: pal.dangerFg),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: pal.primaryCoral,
          foregroundColor: pal.onPrimaryCoral,
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: pal.primaryCoral,
          foregroundColor: pal.onPrimaryCoral,
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: pal.textPrimary,
          side: BorderSide(color: pal.border, width: 1),
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: pal.primaryCoral,
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),
    );
  }
}
