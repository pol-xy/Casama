import 'package:flutter/material.dart';

/// Casama Spacing, Radii & Responsive Tokens (4pt base / 8pt rhythm)
class CasamaSpacing {
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double huge = 40.0;

  // Corner Radii
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusInput = 14.0;
  static const double radiusLg = 16.0;
  static const double radiusSummary = 18.0;
  static const double radiusCard = 20.0;
  static const double radiusXl = 24.0;
  static const double radiusSheet = 28.0;
  static const double radiusPill = 999.0;

  static const BorderRadius roundedSm = BorderRadius.all(
    Radius.circular(radiusSm),
  );
  static const BorderRadius roundedMd = BorderRadius.all(
    Radius.circular(radiusMd),
  );
  static const BorderRadius roundedInput = BorderRadius.all(
    Radius.circular(radiusInput),
  );
  static const BorderRadius roundedLg = BorderRadius.all(
    Radius.circular(radiusLg),
  );
  static const BorderRadius roundedSummary = BorderRadius.all(
    Radius.circular(radiusSummary),
  );
  static const BorderRadius roundedCard = BorderRadius.all(
    Radius.circular(radiusCard),
  );
  static const BorderRadius roundedXl = BorderRadius.all(
    Radius.circular(radiusXl),
  );
  static const BorderRadius roundedSheetTop = BorderRadius.vertical(
    top: Radius.circular(radiusSheet),
  );
  static const BorderRadius roundedPill = BorderRadius.all(
    Radius.circular(radiusPill),
  );

  // Common Touch Target
  static const double minTouchTarget = 48.0;
}

/// Responsive layout breakpoints matching phone, compact, and tablet viewports
class CasamaBreakpoints {
  static const double compact = 360.0;
  static const double tablet = 600.0;
  static const double expanded = 840.0;

  static const double maxContentWidth = 600.0;
  static const double maxSheetWidth = 560.0;
  static const double maxProseWidth = 680.0;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  static double horizontalMargin(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact
          ? CasamaSpacing.sm
          : CasamaSpacing.md;
}
