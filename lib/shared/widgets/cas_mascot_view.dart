import 'package:flutter/material.dart';

enum CasPose {
  hero,
  waving,
  jumping,
  standing,
  deliveries,
  deliveriesEmpty,
  tasks,
  tasksEmpty,
  roulette,
  together,
  chatting,
  chores,
  home,
  leaderboard,
  about,
  lostFound,
  lostFoundEmpty,
  drawer,
  inviteKey,
  cameraBehindCasnaps,
  settings,
  permissions,
  terms,
}

typedef CasMascotPose = CasPose;

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

  String get assetPath => _assetPath;

  String get _assetPath {
    switch (pose) {
      case CasPose.hero:
      case CasPose.standing:
      case CasPose.together:
        return 'assets/images/cas/together_cards.png';
      case CasPose.waving:
      case CasPose.chatting:
        return 'assets/images/cas/migo_chat.png';
      case CasPose.roulette:
        return 'assets/images/cas/migo_roulette.png';
      case CasPose.jumping:
      case CasPose.leaderboard:
        return 'assets/images/cas/migo_leaderboard.png';
      case CasPose.deliveries:
        return 'assets/images/cas/migo_deliveries.png';
      case CasPose.deliveriesEmpty:
        return 'assets/images/cas/migo_deliveries_empty.png';
      case CasPose.tasks:
        return 'assets/images/cas/migo_tasks.png';
      case CasPose.tasksEmpty:
        return 'assets/images/cas/migo_tasks_empty.png';
      case CasPose.chores:
        return 'assets/images/cas/migo_chores.png';
      case CasPose.home:
        return 'assets/images/cas/migo_home.png';
      case CasPose.about:
        return 'assets/images/cas/migo_about.png';
      case CasPose.lostFound:
        return 'assets/images/cas/migo_lost_found.png';
      case CasPose.lostFoundEmpty:
        return 'assets/images/cas/migo_lost_found_empty.png';
      case CasPose.drawer:
        return 'assets/images/cas/migo_drawer.png';
      case CasPose.inviteKey:
        return 'assets/images/cas/migo_invite_key.png';
      case CasPose.cameraBehindCasnaps:
        return 'assets/images/cas/migo_camera_behind_CASnaps.png';
      case CasPose.settings:
        return 'assets/images/cas/migo_settings.png';
      case CasPose.permissions:
        return 'assets/images/cas/migo_permissions.png';
      case CasPose.terms:
        return 'assets/images/cas/migo_terms.png';
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
