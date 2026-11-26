import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/casama_repository.dart';
import '../../data/models.dart';

/// Dynamically resolves a user's live [avatarUrl] and [displayName] from
/// the active household members or current signed-in user profile.
({String? avatarUrl, String displayName}) resolveProfileByUserId(
  CasamaRepository repo,
  String userId,
  String fallbackName,
) {
  if (userId == repo.currentUser.id) {
    final name = repo.currentUser.displayName.trim().isNotEmpty
        ? repo.currentUser.displayName
        : fallbackName;
    return (avatarUrl: repo.currentUser.avatarUrl, displayName: name);
  }
  for (final member in repo.members) {
    if (member.profile.id == userId) {
      final rawName = member.profile.displayName.trim();
      final name = rawName.isNotEmpty && rawName != 'You'
          ? rawName
          : fallbackName;
      return (avatarUrl: member.profile.avatarUrl, displayName: name);
    }
  }
  return (avatarUrl: null, displayName: fallbackName);
}

/// Dynamically resolves the creator's live [avatarUrl] and [displayName] from
/// the active household members or current signed-in user profile.
({String? avatarUrl, String displayName}) resolveSnapCreatorProfile(
  CasamaRepository repo,
  QuickSnap snap,
) {
  return resolveProfileByUserId(repo, snap.creatorId, snap.creatorName);
}

class QuickSnapImageView extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;

  const QuickSnapImageView({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    if (!kIsWeb) {
      try {
        final file = File(imageUrl);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          );
        }
      } catch (_) {
        // Fallback to network or placeholder
      }
    }

    return Image.network(
      imageUrl,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade900,
      child: const Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: Colors.white54,
          size: 38,
        ),
      ),
    );
  }
}
