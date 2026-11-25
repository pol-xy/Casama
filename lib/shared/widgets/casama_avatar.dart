import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';

class CasamaAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double radius;
  final String? name;
  final VoidCallback? onTap;
  final bool showEditBadge;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final String? semanticLabel;

  // Bounded LRU cache to prevent synchronous base64Decode inside scroll frames.
  static final LinkedHashMap<String, Uint8List> _base64Cache =
      LinkedHashMap<String, Uint8List>();
  static const int _maxCacheEntries = 48;

  const CasamaAvatar({
    super.key,
    this.avatarUrl,
    this.radius = 24,
    this.name,
    this.onTap,
    this.showEditBadge = false,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0,
    this.semanticLabel,
  });

  static Uint8List? _decodeBase64Cached(String dataUrl) {
    final existing = _base64Cache.remove(dataUrl);
    if (existing != null) {
      _base64Cache[dataUrl] = existing;
      return existing;
    }
    try {
      final commaIndex = dataUrl.indexOf(',');
      final base64Str = commaIndex != -1
          ? dataUrl.substring(commaIndex + 1)
          : dataUrl;
      final bytes = base64Decode(base64Str);
      if (_base64Cache.length >= _maxCacheEntries) {
        _base64Cache.remove(_base64Cache.keys.first);
      }
      _base64Cache[dataUrl] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final effectiveBg = backgroundColor ?? pal.forestTeal;
    final size = radius * 2;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (size * dpr).round().clamp(32, 512);

    Widget avatarContent;
    final url = avatarUrl?.trim();

    if (url != null && url.isNotEmpty) {
      if (url.startsWith('data:image')) {
        final bytes = _decodeBase64Cached(url);
        if (bytes != null) {
          avatarContent = Image.memory(
            bytes,
            width: size,
            height: size,
            cacheWidth: cachePx,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallback(context),
          );
        } else {
          avatarContent = _buildFallback(context);
        }
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        avatarContent = Image.network(
          url,
          width: size,
          height: size,
          cacheWidth: cachePx,
          fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return _buildFallback(context);
          },
          errorBuilder: (_, _, _) => _buildFallback(context),
        );
      } else if (!kIsWeb && (url.startsWith('/') || url.startsWith('file:'))) {
        try {
          final filePath = url.startsWith('file://')
              ? url.replaceFirst('file://', '')
              : url;
          final file = File(filePath);
          avatarContent = Image.file(
            file,
            width: size,
            height: size,
            cacheWidth: cachePx,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallback(context),
          );
        } catch (_) {
          avatarContent = _buildFallback(context);
        }
      } else {
        avatarContent = _buildFallback(context);
      }
    } else {
      avatarContent = _buildFallback(context);
    }

    Widget mainAvatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBg,
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(color: borderColor ?? pal.surface, width: borderWidth)
            : null,
      ),
      child: ClipOval(child: avatarContent),
    );

    if (showEditBadge) {
      mainAvatar = Stack(
        clipBehavior: Clip.none,
        children: [
          mainAvatar,
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: pal.primaryCoral,
                shape: BoxShape.circle,
                border: Border.all(color: pal.surface, width: 2),
              ),
              child: Icon(
                Icons.photo_camera_rounded,
                color: pal.onPrimaryCoral,
                size: 15,
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return Semantics(
        button: true,
        label: semanticLabel ?? (name != null ? '$name avatar' : 'Change photo'),
        child: CasamaPressable(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: CasamaSpacing.minTouchTarget,
              minHeight: CasamaSpacing.minTouchTarget,
            ),
            child: Center(child: mainAvatar),
          ),
        ),
      );
    }

    return mainAvatar;
  }

  Widget _buildFallback(BuildContext context) {
    final trimmed = name?.trim() ?? '';
    final letter = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';

    return Center(
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Text(
              letter,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.85,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
