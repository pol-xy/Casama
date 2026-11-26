import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/motion/casama_motion.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/casama_avatar.dart';
import '../../../shared/widgets/casama_wave_header.dart';

/// Shared Forest-Teal wave-ornament thread header used by [GroupChatScreen],
/// [ChatSpaceScreen], and [DirectChatScreen] so thread shells stay unified.
class CasamaChatThreadHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget leadingBadge;
  final VoidCallback onBack;
  final VoidCallback? onTitleTap;
  final List<Widget> rightActions;

  const CasamaChatThreadHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.leadingBadge,
    required this.onBack,
    this.onTitleTap,
    this.rightActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final topPad = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _ThreadHeaderPainter(
              deep: pal.headerDeep,
              mid: pal.headerMid,
              ornament: pal.headerOrnament,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            CasamaSpacing.md,
            topPad + 10,
            CasamaSpacing.md,
            16,
          ),
          child: Row(
            children: [
              CasamaCircleIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                semanticLabel: 'Back',
                onTap: onBack,
              ),
              const SizedBox(width: CasamaSpacing.sm),
              Expanded(
                child: CasamaPressable(
                  onTap: onTitleTap,
                  child: Row(
                    children: [
                      leadingBadge,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: pal.headerSubtitle,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              for (final action in rightActions) ...[
                const SizedBox(width: CasamaSpacing.xs),
                action,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ThreadHeaderPainter extends CustomPainter {
  final Color deep;
  final Color mid;
  final Color ornament;

  const _ThreadHeaderPainter({
    required this.deep,
    required this.mid,
    required this.ornament,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = deep,
    );

    final wave = Path()
      ..moveTo(0, size.height - 8)
      ..cubicTo(
        size.width * 0.35,
        size.height - 16,
        size.width * 0.7,
        size.height - 2,
        size.width,
        size.height - 10,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(wave, Paint()..color = mid.withValues(alpha: 0.45));

    final center = Offset(size.width - 30, size.height * 0.35);
    final ringPaint = Paint()
      ..color = ornament
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, 34, ringPaint);
    canvas.drawCircle(
      center,
      22,
      ringPaint..color = ornament.withValues(alpha: ornament.a * 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _ThreadHeaderPainter oldDelegate) =>
      oldDelegate.deep != deep ||
      oldDelegate.mid != mid ||
      oldDelegate.ornament != ornament;
}

/// Centered pill date divider (`Today`) inside chat threads.
class CasamaChatDatePill extends StatelessWidget {
  final String label;

  const CasamaChatDatePill({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: CasamaSpacing.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: CasamaSpacing.roundedPill,
            border: Border.all(color: pal.border),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: pal.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

/// Organic asymmetrical message bubble supporting text, media images, and
/// shareable invite code cards across Group, Space, and Direct chat threads.
class CasamaMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String timeLabel;
  final bool showSenderName;
  final String? fallbackAvatarUrl;
  final bool showReadCheck;

  const CasamaMessageBubble({
    super.key,
    required this.message,
    required this.timeLabel,
    this.showSenderName = true,
    this.fallbackAvatarUrl,
    this.showReadCheck = true,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final isMe = message.isCurrentUser;
    final avatarUrl = message.senderAvatar ?? fallbackAvatarUrl;

    final bubbleColor = isMe ? pal.outgoingBubble : pal.card;
    final bodyTextColor = isMe ? Colors.white : pal.textPrimary;
    final timeColor = isMe
        ? Colors.white.withValues(alpha: 0.75)
        : pal.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CasamaAvatar(
              avatarUrl: avatarUrl,
              radius: 17,
              name: message.senderName,
            ),
            const SizedBox(width: CasamaSpacing.xs),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.76,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  border: isMe
                      ? null
                      : Border.all(color: pal.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMe && showSenderName) ...[
                      Text(
                        message.senderName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: pal.forestTeal,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    if (message.mediaUrl != null &&
                        message.mediaUrl!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: CasamaSpacing.roundedMd,
                        child: _buildMediaPreview(message.mediaUrl!, pal),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (message.inviteCode != null)
                      _InviteCodeCard(
                        code: message.inviteCode!,
                        spaceName: message.inviteSpaceName ?? 'Invite Code',
                        isMe: isMe,
                      )
                    else
                      Text(
                        message.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: bodyTextColor,
                          fontSize: 14,
                          height: 1.42,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          timeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: timeColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isMe && showReadCheck) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.done_all_rounded,
                            size: 14,
                            color: message.isRead
                                ? pal.coralFab
                                : Colors.white.withValues(alpha: 0.78),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview(String mediaUrl, CasamaPalette pal) {
    if (mediaUrl.startsWith('data:image')) {
      return Image.memory(
        base64Decode(mediaUrl.split(',').last),
        width: 210,
        height: 150,
        fit: BoxFit.cover,
      );
    }
    return Image.network(
      mediaUrl,
      width: 210,
      height: 150,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: 210,
        height: 120,
        color: pal.track,
        child: Icon(Icons.broken_image_outlined, color: pal.textMuted),
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  final String code;
  final String spaceName;
  final bool isMe;

  const _InviteCodeCard({
    required this.code,
    required this.spaceName,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withValues(alpha: 0.14) : pal.track,
        borderRadius: CasamaSpacing.roundedMd,
        border: Border.all(
          color: isMe ? Colors.white.withValues(alpha: 0.28) : pal.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.vpn_key_rounded,
                size: 15,
                color: isMe ? Colors.white : pal.primaryCoral,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  spaceName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isMe ? Colors.white : pal.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            code,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: isMe ? Colors.white : pal.primaryCoral,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              CasamaPressable(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  showCasamaToast(
                    context,
                    'Copied code "$code"!',
                    icon: Icons.copy_rounded,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.16)
                        : pal.surface,
                    borderRadius: CasamaSpacing.roundedPill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.copy_rounded,
                        size: 13,
                        color: isMe ? Colors.white : pal.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Copy code',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isMe ? Colors.white : pal.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom message composer bar shared across chat threads (`48dp` attach,
/// pill input, circular coral `48dp` send button).
class CasamaChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData attachIcon;
  final String attachTooltip;
  final VoidCallback onAttach;
  final VoidCallback onSend;

  const CasamaChatComposer({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onAttach,
    required this.onSend,
    this.attachIcon = Icons.add_circle_outline_rounded,
    this.attachTooltip = 'Attach or share',
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CasamaSpacing.sm,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border(top: BorderSide(color: pal.divider, width: 1)),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: attachTooltip,
            child: CasamaPressable(
              onTap: onAttach,
              child: Container(
                width: CasamaSpacing.minTouchTarget,
                height: CasamaSpacing.minTouchTarget,
                decoration: BoxDecoration(
                  color: pal.track,
                  shape: BoxShape.circle,
                ),
                child: Icon(attachIcon, color: pal.textPrimary, size: 22),
              ),
            ),
          ),
          const SizedBox(width: CasamaSpacing.xs),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(color: pal.textPrimary, fontSize: 14.5),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(fontSize: 14, color: pal.textMuted),
                filled: true,
                fillColor: pal.track,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: CasamaSpacing.roundedPill,
                  borderSide: BorderSide(color: pal.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: CasamaSpacing.roundedPill,
                  borderSide: BorderSide(color: pal.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: CasamaSpacing.roundedPill,
                  borderSide: BorderSide(color: pal.forestTeal, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: CasamaSpacing.xs),
          Semantics(
            button: true,
            label: 'Send message',
            child: CasamaPressable(
              onTap: onSend,
              enableHaptic: true,
              child: Container(
                width: CasamaSpacing.minTouchTarget,
                height: CasamaSpacing.minTouchTarget,
                decoration: BoxDecoration(
                  color: pal.coralFab,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Consistent modal action option row used inside chat attachment sheets.
class CasamaSheetActionRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? iconBg;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const CasamaSheetActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
    this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return CasamaPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg ?? pal.softSage,
                borderRadius: CasamaSpacing.roundedMd,
              ),
              child: Icon(icon, color: iconColor ?? pal.forestTeal, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: pal.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pal.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: pal.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
