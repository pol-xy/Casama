import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';

/// Maps a courier name (trimmed, case-insensitive) to its PNG logo asset path.
String resolveCourierLogoAsset(String courier) {
  final normalized = courier.trim().toLowerCase();
  if (normalized.contains('j&t') || normalized.contains('jnt')) {
    return 'assets/images/couriers/jnt_express.png';
  }
  if (normalized.contains('flash')) {
    return 'assets/images/couriers/flash_express.png';
  }
  if (normalized.contains('ninja')) {
    return 'assets/images/couriers/ninja_van.png';
  }
  if (normalized.contains('lbc')) {
    return 'assets/images/couriers/lbc.png';
  }
  if (normalized.contains('2go')) {
    return 'assets/images/couriers/2go_express.png';
  }
  if (normalized.contains('lalamove')) {
    return 'assets/images/couriers/lalamove.png';
  }
  if (normalized.contains('spx') || normalized.contains('shopee express')) {
    return 'assets/images/couriers/spx.png';
  }
  return 'assets/images/couriers/other.png';
}

/// Renders a courier PNG brand logo inside a soft light container with a
/// hairline border so dark and colored marks stay legible in Light & Dark mode.
class CasamaCourierLogo extends StatelessWidget {
  final String courier;
  final double size;
  final double borderRadius;
  final double padding;

  const CasamaCourierLogo({
    super.key,
    required this.courier,
    this.size = 46,
    this.borderRadius = 12,
    this.padding = 5,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final bg = context.isDark ? const Color(0xFFF7F5F0) : Colors.white;
    final assetPath = resolveCourierLogoAsset(courier);

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: pal.border, width: 1),
      ),
      alignment: Alignment.center,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(
          Icons.local_shipping_outlined,
          size: size * 0.52,
          color: pal.forestTeal,
        ),
      ),
    );
  }
}
