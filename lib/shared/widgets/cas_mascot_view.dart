import 'package:flutter/material.dart';

enum CasPose {
  hero,
  waving,
  jumping,
  standing,
  deliveries,
  tasks,
  roulette,
  together,
  chatting,
  chores,
}

/// Renders transparent Cas/Migo mascot PNG illustrations cleanly over any
/// background (stepped wave headers, cards, or avatar rims) with no opaque
/// backdrop boxes, borders, or cast shadows.
class CasMascotView extends StatelessWidget {
  final CasPose pose;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? semanticLabel;

  const CasMascotView({
    super.key,
    this.pose = CasPose.hero,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  String get _assetPath {
    switch (pose) {
      case CasPose.hero:
      case CasPose.standing:
      case CasPose.together:
        return 'assets/images/cas/together_cards.png';
      case CasPose.waving:
      case CasPose.chatting:
        return 'assets/images/cas/migo_chat.png';
      case CasPose.jumping:
      case CasPose.roulette:
        return 'assets/images/cas/migo_roulette.png';
      case CasPose.deliveries:
        return 'assets/images/cas/migo_deliveries.png';
      case CasPose.tasks:
        return 'assets/images/cas/migo_chores.png';
      case CasPose.chores:
        return 'assets/images/cas/migo_chores.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      _assetPath,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: semanticLabel == null,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: width ?? 80,
          height: height ?? 80,
          child: const Center(
            child: Icon(
              Icons.cottage_rounded,
              size: 32,
              color: Color(0xFF37655E),
            ),
          ),
        );
      },
    );

    if (semanticLabel == null) {
      return ExcludeSemantics(child: image);
    }
    return image;
  }
}
