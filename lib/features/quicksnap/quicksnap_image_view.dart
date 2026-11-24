import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
