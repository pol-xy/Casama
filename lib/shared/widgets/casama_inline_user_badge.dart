import 'package:flutter/material.dart';

import 'casama_avatar.dart';

/// Compact, overflow-safe inline user attribution rendering an optional
/// [prefix], a tiny circular [CasamaAvatar], [displayName] (e.g. `'You'` or
/// `preferredName`), and an optional [suffix].
class CasamaInlineUserBadge extends StatelessWidget {
  final String? prefix;
  final String displayName;
  final String? avatarName;
  final String? avatarUrl;
  final String? suffix;
  final double avatarSize;
  final TextStyle? baseStyle;
  final TextStyle? nameStyle;
  final int maxLines;
  final TextOverflow overflow;
  final Key? avatarKey;

  const CasamaInlineUserBadge({
    super.key,
    this.prefix,
    required this.displayName,
    this.avatarName,
    this.avatarUrl,
    this.suffix,
    this.avatarSize = 18,
    this.baseStyle,
    this.nameStyle,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.avatarKey,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBase = baseStyle ?? DefaultTextStyle.of(context).style;
    final effectiveNameStyle =
        nameStyle ?? effectiveBase.copyWith(fontWeight: FontWeight.w600);
    final semanticLabel = '${prefix ?? ''}$displayName${suffix ?? ''}';

    return Semantics(
      label: semanticLabel,
      child: Text.rich(
        TextSpan(
          style: effectiveBase,
          children: [
            if (prefix != null && prefix!.isNotEmpty) TextSpan(text: prefix),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: CasamaAvatar(
                  key: avatarKey,
                  radius: avatarSize / 2,
                  avatarUrl: avatarUrl,
                  name: avatarName ?? displayName,
                ),
              ),
            ),
            TextSpan(text: displayName, style: effectiveNameStyle),
            if (suffix != null && suffix!.isNotEmpty) TextSpan(text: suffix),
          ],
        ),
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}
