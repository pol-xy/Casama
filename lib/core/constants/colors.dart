import 'package:flutter/material.dart';

/// Casama Design System Color Tokens (WCAG 2.1 AA Light & Harmonized Dark Mode)
class CasamaColors {
  // Brand Core Colors
  /// AA-compliant interactive coral in Light Mode (`4.82:1` w/ white, `4.66:1` w/ cream)
  static const Color primaryCoral = Color(0xFFC44938);

  /// Warm coral accent reserved for raised FABs, camera shutter & large/dark highlights
  static const Color warmCoralFab = Color(0xFFE87461);

  /// Original coral brand fill (Dark Mode / decorative fills)
  static const Color coralSoft = Color(0xFFE87968);

  /// Forest Teal anchor (`5.13:1`–`6.28:1` w/ white)
  static const Color deepTeal = Color(0xFF37655E);
  static const Color sageTeal = Color(0xFF688C83);
  static const Color mistySage = Color(0xFFA5B9B0);
  static const Color softSage = Color(0xFFE0ECE7);

  static const Color midnightNavy = Color(0xFF1C2E4A);
  static const Color dustyBlue = Color(0xFF52677D);
  static const Color ivory = Color(0xFFBDC4D4);

  // Light Backgrounds & Surfaces (core_screens.html + starting.html)
  static const Color warmCream = Color(0xFFEAE4D7);
  static const Color authCream = Color(0xFFF9F4EC);
  static const Color softNeutral = Color(0xFFEAE6DF);
  static const Color authInputFill = Color(0xFFEAE4DC);
  static const Color white = Color(0xFFFFFFFF);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color borderGray = Color(0xFFDCE3E0);
  static const Color inputBorderLight = Color(0xFF7F8E96);
  static const Color dividerLight = Color(0xFFF0ECE1);
  static const Color blushSoft = Color(0xFFFFF0ED);

  // Light Typography
  static const Color ink = Color(0xFF1C2E4A);
  static const Color textSecondary = Color(0xFF54646C);
  static const Color textMuted = Color(0xFF5E6E76);

  // Accent & Semantic (Light WCAG AA verified)
  static const Color warmGold = Color(0xFFF4B544);
  static const Color amberText = Color(0xFF8D5500);
  static const Color amberBg = Color(0xFFFFF8E1);
  static const Color successGreen = Color(0xFF2E7D32);
  static const Color successBg = Color(0xFFE8F5E9);
  static const Color warningOrange = Color(0xFFB54708);
  static const Color warningBg = Color(0xFFFFF3E0);
  static const Color errorRed = Color(0xFFC62828);
  static const Color errorBg = Color(0xFFFFEBEE);
  static const Color infoBlue = Color(0xFF1565C0);
  static const Color infoBg = Color(0xFFE3F2FD);

  // Status Chips
  static const Color homeGreen = Color(0xFF2E7D32);
  static const Color homeBg = Color(0xFFE8F5E9);
  static const Color outGray = Color(0xFF595959);
  static const Color outBg = Color(0xFFEEEEEE);

  // Quick Action Tile Accents
  static const Color tileParcels = Color(0xFFFFF0ED);
  static const Color tileMaintenance = Color(0xFFE3F2FD);
  static const Color tileLostFound = Color(0xFFE0ECE7);
  static const Color tileChat = Color(0xFFEBF0FA);

  // Harmonized Nocturnal Dark Mode Tokens
  static const Color darkBackground = Color(0xFF0D171E);
  static const Color darkSurface = Color(0xFF14222B);
  static const Color darkCard = Color(0xFF1A2C37);
  static const Color darkTrack = Color(0xFF223846);
  static const Color darkBorder = Color(0xFF2C4654);
  static const Color darkInputBorder = Color(0xFF6C8896);
  static const Color darkText = Color(0xFFF2F5F7);
  static const Color darkTextSecondary = Color(0xFFA3B4BE);
  static const Color darkTextMuted = Color(0xFF8E9EB3);

  static const Color darkCoral = Color(0xFFF08B7B);
  static const Color darkTeal = Color(0xFF66B2A8);
  static const Color darkHeaderDeep = Color(0xFF1D3B36);
  static const Color darkHeaderMid = Color(0xFF264B45);
  static const Color darkHeaderLight = Color(0xFF162A2D);
  static const Color darkSoftSage = Color(0xFF1B3633);
  static const Color darkBlushSoft = Color(0xFF3A2220);

  // Dark Semantic Chips
  static const Color darkSuccessFg = Color(0xFF81C784);
  static const Color darkSuccessBg = Color(0xFF1B3626);
  static const Color darkNeutralFg = Color(0xFFCBD5E1);
  static const Color darkNeutralBg = Color(0xFF263440);
  static const Color darkDangerFg = Color(0xFFF28B82);
  static const Color darkDangerBg = Color(0xFF3D1F25);
  static const Color darkWarningFg = Color(0xFFFFB74D);
  static const Color darkWarningBg = Color(0xFF3B2B17);
  static const Color darkInfoFg = Color(0xFF90CAF9);
  static const Color darkInfoBg = Color(0xFF1B2E45);
  static const Color darkAmberFg = Color(0xFFFFD54F);
  static const Color darkAmberBg = Color(0xFF3A3016);

  // Dark Mode Quick Action Tile Accents
  static const Color darkTileParcels = Color(0xFF3A2220);
  static const Color darkTileMaintenance = Color(0xFF1B2E45);
  static const Color darkTileLostFound = Color(0xFF1B3633);
  static const Color darkTileChat = Color(0xFF202A3D);

  // Bills & Payments
  static const Color tileBills = Color(0xFFFFF3E0);
  static const Color tileBillsIcon = Color(0xFFB54708);
  static const Color darkTileBills = Color(0xFF3B2B17);
  static const Color tileChoreRoulette = Color(0xFFFFF0ED);
  static const Color darkTileChoreRoulette = Color(0xFF3A2220);
}

/// Animated ThemeExtension holding every surface, wave, ink, and semantic color.
@immutable
class CasamaPalette extends ThemeExtension<CasamaPalette> {
  final Color scaffoldBg;
  final Color authScaffoldBg;
  final Color surface;
  final Color card;
  final Color track;
  final Color border;
  final Color inputBorder;
  final Color divider;
  final Color softSage;
  final Color softBlush;

  final Color headerDeep;
  final Color headerMid;
  final Color headerLight;
  final Color headerSubtitle;
  final Color headerOrnament;
  final Color ambientWaveWeak;
  final Color ambientWaveStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color primaryCoral;
  final Color onPrimaryCoral;
  final Color coralFab;
  final Color forestTeal;
  final Color onForestTeal;
  final Color outgoingBubble;

  final Color successFg;
  final Color successBg;
  final Color neutralFg;
  final Color neutralBg;
  final Color dangerFg;
  final Color dangerBg;
  final Color warningFg;
  final Color warningBg;
  final Color infoFg;
  final Color infoBg;
  final Color amberFg;
  final Color amberBg;

  final Color scrim;

  const CasamaPalette({
    required this.scaffoldBg,
    required this.authScaffoldBg,
    required this.surface,
    required this.card,
    required this.track,
    required this.border,
    required this.inputBorder,
    required this.divider,
    required this.softSage,
    required this.softBlush,
    required this.headerDeep,
    required this.headerMid,
    required this.headerLight,
    required this.headerSubtitle,
    required this.headerOrnament,
    required this.ambientWaveWeak,
    required this.ambientWaveStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primaryCoral,
    required this.onPrimaryCoral,
    required this.coralFab,
    required this.forestTeal,
    required this.onForestTeal,
    required this.outgoingBubble,
    required this.successFg,
    required this.successBg,
    required this.neutralFg,
    required this.neutralBg,
    required this.dangerFg,
    required this.dangerBg,
    required this.warningFg,
    required this.warningBg,
    required this.infoFg,
    required this.infoBg,
    required this.amberFg,
    required this.amberBg,
    required this.scrim,
  });

  static const CasamaPalette light = CasamaPalette(
    scaffoldBg: CasamaColors.warmCream,
    authScaffoldBg: CasamaColors.authCream,
    surface: CasamaColors.white,
    card: CasamaColors.cardSurface,
    track: CasamaColors.softNeutral,
    border: CasamaColors.borderGray,
    inputBorder: CasamaColors.inputBorderLight,
    divider: CasamaColors.dividerLight,
    softSage: CasamaColors.softSage,
    softBlush: CasamaColors.blushSoft,
    headerDeep: CasamaColors.deepTeal,
    headerMid: CasamaColors.sageTeal,
    headerLight: CasamaColors.mistySage,
    headerSubtitle: CasamaColors.warmCream,
    headerOrnament: Color(0x73F4B544),
    ambientWaveWeak: Color(0x0F37655E),
    ambientWaveStrong: Color(0x1737655E),
    textPrimary: CasamaColors.ink,
    textSecondary: CasamaColors.textSecondary,
    textMuted: CasamaColors.textMuted,
    primaryCoral: CasamaColors.primaryCoral,
    onPrimaryCoral: CasamaColors.white,
    coralFab: CasamaColors.warmCoralFab,
    forestTeal: CasamaColors.deepTeal,
    onForestTeal: CasamaColors.white,
    outgoingBubble: CasamaColors.deepTeal,
    successFg: CasamaColors.successGreen,
    successBg: CasamaColors.successBg,
    neutralFg: CasamaColors.outGray,
    neutralBg: CasamaColors.outBg,
    dangerFg: CasamaColors.errorRed,
    dangerBg: CasamaColors.errorBg,
    warningFg: CasamaColors.warningOrange,
    warningBg: CasamaColors.warningBg,
    infoFg: CasamaColors.infoBlue,
    infoBg: CasamaColors.infoBg,
    amberFg: CasamaColors.amberText,
    amberBg: CasamaColors.amberBg,
    scrim: Color(0x731C2E4A),
  );

  static const CasamaPalette dark = CasamaPalette(
    scaffoldBg: CasamaColors.darkBackground,
    authScaffoldBg: CasamaColors.darkBackground,
    surface: CasamaColors.darkSurface,
    card: CasamaColors.darkCard,
    track: CasamaColors.darkTrack,
    border: CasamaColors.darkBorder,
    inputBorder: CasamaColors.darkInputBorder,
    divider: CasamaColors.darkTrack,
    softSage: CasamaColors.darkSoftSage,
    softBlush: CasamaColors.darkBlushSoft,
    headerDeep: CasamaColors.darkHeaderDeep,
    headerMid: CasamaColors.darkHeaderMid,
    headerLight: CasamaColors.darkHeaderLight,
    headerSubtitle: Color(0xFFB5C7C3),
    headerOrnament: Color(0x47F4B544),
    ambientWaveWeak: Color(0x0A5EB5AD),
    ambientWaveStrong: Color(0x0F5EB5AD),
    textPrimary: CasamaColors.darkText,
    textSecondary: CasamaColors.darkTextSecondary,
    textMuted: CasamaColors.darkTextMuted,
    primaryCoral: CasamaColors.darkCoral,
    onPrimaryCoral: CasamaColors.darkBackground,
    coralFab: CasamaColors.warmCoralFab,
    forestTeal: CasamaColors.darkTeal,
    onForestTeal: CasamaColors.darkBackground,
    outgoingBubble: Color(0xFF265652),
    successFg: CasamaColors.darkSuccessFg,
    successBg: CasamaColors.darkSuccessBg,
    neutralFg: CasamaColors.darkNeutralFg,
    neutralBg: CasamaColors.darkNeutralBg,
    dangerFg: CasamaColors.darkDangerFg,
    dangerBg: CasamaColors.darkDangerBg,
    warningFg: CasamaColors.darkWarningFg,
    warningBg: CasamaColors.darkWarningBg,
    infoFg: CasamaColors.darkInfoFg,
    infoBg: CasamaColors.darkInfoBg,
    amberFg: CasamaColors.darkAmberFg,
    amberBg: CasamaColors.darkAmberBg,
    scrim: Color(0xA6050A0F),
  );

  @override
  CasamaPalette copyWith({
    Color? scaffoldBg,
    Color? authScaffoldBg,
    Color? surface,
    Color? card,
    Color? track,
    Color? border,
    Color? inputBorder,
    Color? divider,
    Color? softSage,
    Color? softBlush,
    Color? headerDeep,
    Color? headerMid,
    Color? headerLight,
    Color? headerSubtitle,
    Color? headerOrnament,
    Color? ambientWaveWeak,
    Color? ambientWaveStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? primaryCoral,
    Color? onPrimaryCoral,
    Color? coralFab,
    Color? forestTeal,
    Color? onForestTeal,
    Color? outgoingBubble,
    Color? successFg,
    Color? successBg,
    Color? neutralFg,
    Color? neutralBg,
    Color? dangerFg,
    Color? dangerBg,
    Color? warningFg,
    Color? warningBg,
    Color? infoFg,
    Color? infoBg,
    Color? amberFg,
    Color? amberBg,
    Color? scrim,
  }) {
    return CasamaPalette(
      scaffoldBg: scaffoldBg ?? this.scaffoldBg,
      authScaffoldBg: authScaffoldBg ?? this.authScaffoldBg,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      track: track ?? this.track,
      border: border ?? this.border,
      inputBorder: inputBorder ?? this.inputBorder,
      divider: divider ?? this.divider,
      softSage: softSage ?? this.softSage,
      softBlush: softBlush ?? this.softBlush,
      headerDeep: headerDeep ?? this.headerDeep,
      headerMid: headerMid ?? this.headerMid,
      headerLight: headerLight ?? this.headerLight,
      headerSubtitle: headerSubtitle ?? this.headerSubtitle,
      headerOrnament: headerOrnament ?? this.headerOrnament,
      ambientWaveWeak: ambientWaveWeak ?? this.ambientWaveWeak,
      ambientWaveStrong: ambientWaveStrong ?? this.ambientWaveStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      primaryCoral: primaryCoral ?? this.primaryCoral,
      onPrimaryCoral: onPrimaryCoral ?? this.onPrimaryCoral,
      coralFab: coralFab ?? this.coralFab,
      forestTeal: forestTeal ?? this.forestTeal,
      onForestTeal: onForestTeal ?? this.onForestTeal,
      outgoingBubble: outgoingBubble ?? this.outgoingBubble,
      successFg: successFg ?? this.successFg,
      successBg: successBg ?? this.successBg,
      neutralFg: neutralFg ?? this.neutralFg,
      neutralBg: neutralBg ?? this.neutralBg,
      dangerFg: dangerFg ?? this.dangerFg,
      dangerBg: dangerBg ?? this.dangerBg,
      warningFg: warningFg ?? this.warningFg,
      warningBg: warningBg ?? this.warningBg,
      infoFg: infoFg ?? this.infoFg,
      infoBg: infoBg ?? this.infoBg,
      amberFg: amberFg ?? this.amberFg,
      amberBg: amberBg ?? this.amberBg,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  CasamaPalette lerp(covariant ThemeExtension<CasamaPalette>? other, double t) {
    if (other is! CasamaPalette) return this;
    return CasamaPalette(
      scaffoldBg: Color.lerp(scaffoldBg, other.scaffoldBg, t)!,
      authScaffoldBg: Color.lerp(authScaffoldBg, other.authScaffoldBg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      track: Color.lerp(track, other.track, t)!,
      border: Color.lerp(border, other.border, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      softSage: Color.lerp(softSage, other.softSage, t)!,
      softBlush: Color.lerp(softBlush, other.softBlush, t)!,
      headerDeep: Color.lerp(headerDeep, other.headerDeep, t)!,
      headerMid: Color.lerp(headerMid, other.headerMid, t)!,
      headerLight: Color.lerp(headerLight, other.headerLight, t)!,
      headerSubtitle: Color.lerp(headerSubtitle, other.headerSubtitle, t)!,
      headerOrnament: Color.lerp(headerOrnament, other.headerOrnament, t)!,
      ambientWaveWeak: Color.lerp(ambientWaveWeak, other.ambientWaveWeak, t)!,
      ambientWaveStrong: Color.lerp(
        ambientWaveStrong,
        other.ambientWaveStrong,
        t,
      )!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      primaryCoral: Color.lerp(primaryCoral, other.primaryCoral, t)!,
      onPrimaryCoral: Color.lerp(onPrimaryCoral, other.onPrimaryCoral, t)!,
      coralFab: Color.lerp(coralFab, other.coralFab, t)!,
      forestTeal: Color.lerp(forestTeal, other.forestTeal, t)!,
      onForestTeal: Color.lerp(onForestTeal, other.onForestTeal, t)!,
      outgoingBubble: Color.lerp(outgoingBubble, other.outgoingBubble, t)!,
      successFg: Color.lerp(successFg, other.successFg, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      neutralFg: Color.lerp(neutralFg, other.neutralFg, t)!,
      neutralBg: Color.lerp(neutralBg, other.neutralBg, t)!,
      dangerFg: Color.lerp(dangerFg, other.dangerFg, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      warningFg: Color.lerp(warningFg, other.warningFg, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      infoFg: Color.lerp(infoFg, other.infoFg, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      amberFg: Color.lerp(amberFg, other.amberFg, t)!,
      amberBg: Color.lerp(amberBg, other.amberBg, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// Convenience BuildContext extension for dynamic light/dark theming
extension CasamaThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  CasamaPalette get palette =>
      Theme.of(this).extension<CasamaPalette>() ??
      (isDark ? CasamaPalette.dark : CasamaPalette.light);

  Color get scaffoldBg => palette.scaffoldBg;
  Color get authScaffoldBg => palette.authScaffoldBg;
  Color get surfaceColor => palette.surface;
  Color get cardColor => palette.card;
  Color get trackColor => palette.track;
  Color get borderColor => palette.border;
  Color get inputBorderColor => palette.inputBorder;
  Color get dividerColor => palette.divider;
  Color get softSageColor => palette.softSage;
  Color get softBlushColor => palette.softBlush;

  Color get textColor => palette.textPrimary;
  Color get textSecondaryColor => palette.textSecondary;
  Color get textMutedColor => palette.textMuted;

  Color get primaryColor => palette.primaryCoral;
  Color get onPrimaryColor => palette.onPrimaryCoral;
  Color get fabColor => palette.coralFab;
  Color get tealColor => palette.forestTeal;
  Color get onTealColor => palette.onForestTeal;

  Color get tileParcelsColor =>
      isDark ? CasamaColors.darkTileParcels : CasamaColors.tileParcels;
  Color get tileMaintenanceColor =>
      isDark ? CasamaColors.darkTileMaintenance : CasamaColors.tileMaintenance;
  Color get tileLostFoundColor =>
      isDark ? CasamaColors.darkTileLostFound : CasamaColors.tileLostFound;
  Color get tileChatColor =>
      isDark ? CasamaColors.darkTileChat : CasamaColors.tileChat;
  Color get tileBillsColor =>
      isDark ? CasamaColors.darkTileBills : CasamaColors.tileBills;
  Color get tileRouletteColor =>
      isDark ? CasamaColors.darkTileChoreRoulette : CasamaColors.tileChoreRoulette;
}
