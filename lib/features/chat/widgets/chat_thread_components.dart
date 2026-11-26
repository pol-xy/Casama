import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/motion/casama_motion.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/casama_avatar.dart';
import '../../../shared/widgets/casama_wave_header.dart';

class _InlineMeetupCard extends StatelessWidget {
  final MeetUpInvitation meetup;
  final bool isMe;
  final ValueChanged<String>? onRespond;

  const _InlineMeetupCard({
    required this.meetup,
    required this.isMe,
    this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final isCompleted = !meetup.isActive;
    final textPrimary = isMe ? Colors.white : pal.textPrimary;
    final textSecondary =
        isMe ? Colors.white.withValues(alpha: 0.8) : pal.textSecondary;
    final timeStr =
        DateFormat('EEE, MMM d • h:mm a').format(meetup.scheduledTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 16,
              color: isMe ? Colors.white : pal.forestTeal,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                meetup.activity,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isCompleted) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.2)
                      : pal.neutralBg,
                  borderRadius: CasamaSpacing.roundedPill,
                ),
                child: Text(
                  'Completed',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isMe ? Colors.white : pal.neutralFg,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$timeStr • ${meetup.location}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _InlineRsvpButton(
              label: 'Going (${meetup.goingCount})',
              selected: meetup.currentUserResponse == 'going',
              disabled: isCompleted || onRespond == null,
              onTap: (isCompleted || onRespond == null)
                  ? null
                  : () => onRespond!('going'),
            ),
            const SizedBox(width: 6),
            _InlineRsvpButton(
              label: 'Maybe (${meetup.maybeCount})',
              selected: meetup.currentUserResponse == 'maybe',
              disabled: isCompleted || onRespond == null,
              onTap: (isCompleted || onRespond == null)
                  ? null
                  : () => onRespond!('maybe'),
            ),
            const SizedBox(width: 6),
            _InlineRsvpButton(
              label: "Can't (${meetup.cantMakeCount})",
              selected: meetup.currentUserResponse == 'cant_make_it',
              disabled: isCompleted || onRespond == null,
              onTap: (isCompleted || onRespond == null)
                  ? null
                  : () => onRespond!('cant_make_it'),
            ),
          ],
        ),
      ],
    );
  }
}

class _InlineRsvpButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  const _InlineRsvpButton({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final bg = selected
        ? (disabled ? pal.forestTeal.withValues(alpha: 0.45) : pal.forestTeal)
        : (disabled ? pal.surface.withValues(alpha: 0.6) : pal.surface);
    final fg = selected
        ? Colors.white.withValues(alpha: disabled ? 0.75 : 1.0)
        : pal.textPrimary.withValues(alpha: disabled ? 0.45 : 1.0);

    return Expanded(
      child: Semantics(
        button: true,
        enabled: !disabled,
        selected: selected,
        label: label,
        child: CasamaPressable(
          onTap: disabled ? null : onTap,
          enableHaptic: !disabled,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: CasamaSpacing.roundedPill,
              border: Border.all(
                color: selected
                    ? bg
                    : pal.border.withValues(alpha: disabled ? 0.5 : 1.0),
              ),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  final VoidCallback? onRetry;
  final ValueChanged<String>? onRespondMeetUp;

  const CasamaMessageBubble({
    super.key,
    required this.message,
    required this.timeLabel,
    this.showSenderName = true,
    this.fallbackAvatarUrl,
    this.showReadCheck = true,
    this.onRetry,
    this.onRespondMeetUp,
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
                    if (message.hasAttachment) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _buildAttachmentWidget(context, pal),
                      ),
                      if (message.content.trim().isNotEmpty ||
                          message.inviteCode != null)
                        const SizedBox(height: 6),
                    ],
                    if (message.inviteCode != null)
                      _InviteCodeCard(
                        code: message.inviteCode!,
                        spaceName: message.inviteSpaceName ?? 'Invite Code',
                        isMe: isMe,
                      )
                    else if (message.meetUpInvitation != null)
                      _InlineMeetupCard(
                        meetup: message.meetUpInvitation!,
                        isMe: isMe,
                        onRespond: onRespondMeetUp,
                      )
                    else if (message.content.trim().isNotEmpty)
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
                          _DeliveryStatusIndicator(
                            message: message,
                            pal: pal,
                          ),
                        ],
                      ],
                    ),
                    if (isMe &&
                        message.deliveryStatus == MessageDeliveryStatus.failed) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: onRetry,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                size: 12,
                                color: pal.coralFab,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Failed to send · Tap to retry',
                                  softWrap: true,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: pal.coralFab,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentWidget(BuildContext context, CasamaPalette pal) {
    final isSending = message.deliveryStatus == MessageDeliveryStatus.sending;
    final canOpenLightbox =
        message.deliveryStatus == MessageDeliveryStatus.delivered;
    final reduced = CasamaMotion.reduceMotion(context);

    final Widget image = _buildRawAttachmentImage(pal);
    final Widget framed = Stack(
      alignment: Alignment.center,
      children: [
        image,
        if (isSending)
          Container(
            width: 230,
            height: 170,
            color: Colors.black.withValues(alpha: 0.35),
            alignment: Alignment.center,
            child: reduced
                ? const Icon(
                    Icons.schedule_rounded,
                    color: Colors.white,
                    size: 26,
                  )
                : const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
          ),
      ],
    );

    if (!canOpenLightbox) return framed;

    return Semantics(
      button: true,
      label: 'View attached photo',
      child: GestureDetector(
        onTap: () => _showAttachmentLightbox(context),
        child: framed,
      ),
    );
  }

  Widget _buildRawAttachmentImage(CasamaPalette pal) {
    const double w = 230;
    const double h = 170;

    final localPath = message.localAttachmentPath;
    if (localPath != null && localPath.isNotEmpty) {
      if (!kIsWeb && File(localPath).existsSync()) {
        return Image.file(
          File(localPath),
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _brokenAttachmentBox(pal, w, h),
        );
      }
      if (kIsWeb) {
        return Image.network(
          localPath,
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _brokenAttachmentBox(pal, w, h),
        );
      }
    }

    final url = message.attachmentUrl ?? '';
    if (url.startsWith('data:image')) {
      return Image.memory(
        base64Decode(url.split(',').last),
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _brokenAttachmentBox(pal, w, h),
      );
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        width: w,
        height: h,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: w,
            height: h,
            color: pal.track,
            alignment: Alignment.center,
            child: Icon(Icons.image_outlined, color: pal.textMuted, size: 28),
          );
        },
        errorBuilder: (_, _, _) => _brokenAttachmentBox(pal, w, h),
      );
    }

    if (!kIsWeb && url.isNotEmpty && File(url).existsSync()) {
      return Image.file(
        File(url),
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _brokenAttachmentBox(pal, w, h),
      );
    }

    return _brokenAttachmentBox(pal, w, h);
  }

  Widget _brokenAttachmentBox(CasamaPalette pal, double w, double h) {
    return Container(
      width: w,
      height: h,
      color: pal.track,
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_outlined, color: pal.textMuted, size: 28),
    );
  }

  void _showAttachmentLightbox(BuildContext context) {
    final reduced = CasamaMotion.reduceMotion(context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close photo preview',
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration:
          reduced ? Duration.zero : const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, _) {
        return Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: _buildLightboxImage(),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Semantics(
                    button: true,
                    label: 'Close photo preview',
                    child: IconButton(
                      iconSize: 28,
                      constraints: const BoxConstraints(
                        minWidth: CasamaSpacing.minTouchTarget,
                        minHeight: CasamaSpacing.minTouchTarget,
                      ),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        if (reduced) return child;
        return FadeTransition(opacity: anim, child: child);
      },
    );
  }

  Widget _buildLightboxImage() {
    final localPath = message.localAttachmentPath;
    if (localPath != null &&
        localPath.isNotEmpty &&
        !kIsWeb &&
        File(localPath).existsSync()) {
      return Image.file(
        File(localPath),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(
          Icons.broken_image_outlined,
          color: Colors.white70,
          size: 48,
        ),
      );
    }
    final url = message.attachmentUrl ?? '';
    if (url.startsWith('data:image')) {
      return Image.memory(
        base64Decode(url.split(',').last),
        fit: BoxFit.contain,
      );
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(
          Icons.broken_image_outlined,
          color: Colors.white70,
          size: 48,
        ),
      );
    }
    return const Icon(
      Icons.image_outlined,
      color: Colors.white70,
      size: 48,
    );
  }
}

class _DeliveryStatusIndicator extends StatelessWidget {
  final ChatMessage message;
  final CasamaPalette pal;

  const _DeliveryStatusIndicator({
    required this.message,
    required this.pal,
  });

  @override
  Widget build(BuildContext context) {
    final mutedWhite = Colors.white.withValues(alpha: 0.78);
    switch (message.deliveryStatus) {
      case MessageDeliveryStatus.sending:
        if (CasamaMotion.reduceMotion(context)) {
          return Icon(
            Icons.schedule_rounded,
            size: 13,
            color: mutedWhite,
          );
        }
        return SizedBox(
          width: 11,
          height: 11,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            valueColor: AlwaysStoppedAnimation<Color>(mutedWhite),
          ),
        );
      case MessageDeliveryStatus.failed:
        return Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: pal.coralFab,
        );
      case MessageDeliveryStatus.delivered:
        return Icon(
          Icons.done_all_rounded,
          size: 14,
          color: message.isRead ? pal.coralFab : mutedWhite,
        );
    }
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
/// optional single-slot attachment preview, pill input, circular coral `48dp` send button).
class CasamaChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData attachIcon;
  final String attachTooltip;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final XFile? pendingAttachment;
  final VoidCallback? onRemoveAttachment;
  final VoidCallback? onReplaceAttachment;

  const CasamaChatComposer({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onAttach,
    required this.onSend,
    this.attachIcon = Icons.add_circle_outline_rounded,
    this.attachTooltip = 'Attach or share',
    this.pendingAttachment,
    this.onRemoveAttachment,
    this.onReplaceAttachment,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CasamaSpacing.sm,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border(top: BorderSide(color: pal.divider, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pendingAttachment != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 68,
                      height: 68,
                      child: _buildPendingThumbnail(pendingAttachment!, pal),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1 photo attached',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: pal.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (onReplaceAttachment != null)
                          CasamaPressable(
                            onTap: onReplaceAttachment,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: pal.track,
                                borderRadius: CasamaSpacing.roundedPill,
                                border: Border.all(color: pal.border),
                              ),
                              child: Text(
                                'Replace',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: pal.forestTeal,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Remove attachment',
                    child: IconButton(
                      constraints: const BoxConstraints(
                        minWidth: CasamaSpacing.minTouchTarget,
                        minHeight: CasamaSpacing.minTouchTarget,
                      ),
                      icon: Icon(
                        Icons.close_rounded,
                        color: pal.textSecondary,
                        size: 20,
                      ),
                      onPressed: onRemoveAttachment,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
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
                    hintText: pendingAttachment != null
                        ? 'Add a caption (optional)...'
                        : hintText,
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
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final canSend =
                      value.text.trim().isNotEmpty || pendingAttachment != null;
                  return Semantics(
                    button: true,
                    enabled: canSend,
                    label: 'Send message',
                    child: CasamaPressable(
                      onTap: onSend,
                      enableHaptic: canSend,
                      child: Container(
                        width: CasamaSpacing.minTouchTarget,
                        height: CasamaSpacing.minTouchTarget,
                        decoration: BoxDecoration(
                          color: canSend ? pal.coralFab : pal.track,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          color: canSend ? Colors.white : pal.textMuted,
                          size: 20,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingThumbnail(XFile file, CasamaPalette pal) {
    if (!kIsWeb && File(file.path).existsSync()) {
      return Image.file(
        File(file.path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: pal.track,
          alignment: Alignment.center,
          child: Icon(Icons.image_outlined, color: pal.textMuted),
        ),
      );
    }
    if (kIsWeb && file.path.isNotEmpty) {
      return Image.network(
        file.path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: pal.track,
          alignment: Alignment.center,
          child: Icon(Icons.image_outlined, color: pal.textMuted),
        ),
      );
    }
    return Container(
      color: pal.track,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: pal.textMuted),
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
