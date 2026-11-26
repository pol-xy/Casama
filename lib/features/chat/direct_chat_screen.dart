import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_sheet_scaffold.dart';
import '../../shared/widgets/casama_wave_header.dart';
import 'widgets/chat_thread_components.dart';

class DirectChatScreen extends ConsumerStatefulWidget {
  final String contactKey;
  final String? contactName;
  final String? avatarUrl;

  const DirectChatScreen({
    super.key,
    required this.contactKey,
    this.contactName,
    this.avatarUrl,
  });

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  XFile? _pendingAttachment;
  bool _markReadScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleMarkRead();
  }

  void _scheduleMarkRead() {
    if (_markReadScheduled) return;
    _markReadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markReadScheduled = false;
      if (mounted) {
        ref.read(repositoryProvider).markDirectChatAsRead(widget.contactKey);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    final attachment = _pendingAttachment;
    if (text.isEmpty && attachment == null) return;

    _messageController.clear();
    if (_pendingAttachment != null) {
      setState(() => _pendingAttachment = null);
    }
    ref
        .read(repositoryProvider)
        .sendDirectMessage(widget.contactKey, text, attachmentFile: attachment);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    final reduced = CasamaMotion.reduceMotion(context);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (reduced) {
        _scrollController.jumpTo(maxExtent);
      } else {
        _scrollController.animateTo(
          maxExtent,
          duration: CasamaMotion.sheet,
          curve: CasamaMotion.easeOut,
        );
      }
    });
  }

  Future<void> _pickAttachment(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1440,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        setState(() => _pendingAttachment = picked);
      }
    } catch (e) {
      if (mounted) {
        showCasamaToast(
          context,
          'Could not attach photo: $e',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  void _showMediaPickerSheet() {
    final contactName = widget.contactName ?? widget.contactKey;
    final pal = context.palette;

    showCasamaSheet<void>(
      context,
      icon: Icons.camera_alt_outlined,
      title: 'Send to $contactName',
      subtitle: 'Attach a photo or share a household invite code',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CasamaSheetActionRow(
            icon: Icons.camera_alt_outlined,
            iconColor: pal.primaryCoral,
            iconBg: pal.softBlush,
            title: _pendingAttachment != null
                ? 'Replace Photo (Camera)'
                : 'Take Photo',
            onTap: () {
              Navigator.pop(ctx);
              _pickAttachment(ImageSource.camera);
            },
          ),
          CasamaSheetActionRow(
            icon: Icons.photo_library_outlined,
            iconColor: pal.infoFg,
            iconBg: pal.infoBg,
            title: _pendingAttachment != null
                ? 'Replace Photo (Gallery)'
                : 'Choose from Gallery',
            onTap: () {
              Navigator.pop(ctx);
              _pickAttachment(ImageSource.gallery);
            },
          ),
          CasamaSheetActionRow(
            icon: Icons.vpn_key_rounded,
            iconColor: pal.successFg,
            iconBg: pal.successBg,
            title:
                'Share Household Invite Code (${ref.read(repositoryProvider).currentHousehold.inviteCode})',
            subtitle: 'Send household code card to $contactName',
            onTap: () {
              Navigator.pop(ctx);
              final household = ref.read(repositoryProvider).currentHousehold;
              ref
                  .read(repositoryProvider)
                  .shareInviteCodeToDirectChat(
                    contactKey: widget.contactKey,
                    code: household.inviteCode,
                    title: household.name,
                  );
              _scrollToBottom();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final isAuthorized = repo.isHousemateAuthorized(widget.contactKey);

    if (!isAuthorized) {
      return Scaffold(
        backgroundColor: pal.scaffoldBg,
        body: CasamaAmbientCanvas(
          child: Column(
            children: [
              CasamaWaveHeader(
                title: 'Access Restricted',
                subtitle: repo.currentHousehold.name,
                compact: true,
                onBackTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(CasamaSpacing.lg),
                    child: CasamaCard(
                      padding: const EdgeInsets.all(CasamaSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: pal.softBlush,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock_person_outlined,
                              size: 32,
                              color: pal.primaryCoral,
                            ),
                          ),
                          const SizedBox(height: CasamaSpacing.md),
                          Text(
                            'Unauthorized Conversation',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: pal.textPrimary,
                            ),
                          ),
                          const SizedBox(height: CasamaSpacing.xs),
                          Text(
                            'Private messaging is restricted to verified housemates of ${repo.currentHousehold.name}.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 13,
                              color: pal.textSecondary,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: CasamaSpacing.lg),
                          CasamaButton(
                            label: 'Return to Messages',
                            icon: Icons.arrow_back_rounded,
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final messages = repo.getDirectMessages(widget.contactKey);
    if (repo.getDirectUnreadCount(widget.contactKey) > 0) {
      _scheduleMarkRead();
    }
    final member = repo.members.firstWhere(
      (m) =>
          m.profile.displayName.toLowerCase().contains(
            widget.contactKey.toLowerCase(),
          ) ||
          m.profile.handle.toLowerCase().contains(
            widget.contactKey.toLowerCase(),
          ),
      orElse: () => repo.members.first,
    );

    final displayName = widget.contactName ?? member.profile.displayName;
    final avatar = widget.avatarUrl ?? member.profile.avatarUrl;
    final isHome = member.isHome;
    final note = member.note ?? (isHome ? 'At home' : 'Away');

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      body: CasamaAmbientCanvas(
        child: Column(
          children: [
            CasamaChatThreadHeader(
              title: displayName,
              subtitle: note,
              onBack: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              leadingBadge: Stack(
                children: [
                  CasamaAvatar(
                    radius: 20,
                    avatarUrl: avatar,
                    name: displayName,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: isHome ? pal.successFg : pal.neutralFg,
                        shape: BoxShape.circle,
                        border: Border.all(color: pal.headerDeep, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              rightActions: [
                CasamaCircleIconButton(
                  icon: Icons.phone_outlined,
                  semanticLabel: 'Call $displayName',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: pal.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: CasamaSpacing.roundedCard,
                        ),
                        title: Row(
                          children: [
                            Icon(
                              Icons.phone_in_talk_rounded,
                              color: pal.successFg,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Call $displayName',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: pal.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        content: Text(
                          'Calling $displayName ($note)...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: pal.textSecondary,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('End Call'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                PopupMenuButton<String>(
                  color: pal.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: CasamaSpacing.roundedMd,
                    side: BorderSide(color: pal.border),
                  ),
                  child: Container(
                    width: CasamaSpacing.minTouchTarget,
                    height: CasamaSpacing.minTouchTarget,
                    decoration: BoxDecoration(
                      color: pal.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: pal.border),
                    ),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: pal.textPrimary,
                      size: 21,
                    ),
                  ),
                  onSelected: (val) {
                    if (val == 'mute') {
                      showCasamaToast(
                        context,
                        'Notifications muted for $displayName',
                        icon: Icons.notifications_off_outlined,
                      );
                    } else if (val == 'clear') {
                      showCasamaToast(
                        context,
                        'Chat history cleared',
                        icon: Icons.delete_outline_rounded,
                      );
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'mute',
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 18,
                            color: pal.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Mute Notifications',
                            style: TextStyle(color: pal.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: pal.dangerFg,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Clear History',
                            style: TextStyle(color: pal.dangerFg),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(CasamaSpacing.lg),
                        child: CasamaCard(
                          padding: const EdgeInsets.all(CasamaSpacing.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 42,
                                color: pal.textMuted,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Say hi to $displayName! 👋',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: pal.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Keep your housemate coordination seamless.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: pal.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: CasamaSpacing.md,
                        vertical: CasamaSpacing.md,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final timeStr =
                            '${msg.createdAt.hour}:${msg.createdAt.minute.toString().padLeft(2, '0')}';
                        return CasamaMessageBubble(
                          message: msg,
                          timeLabel: timeStr,
                          showSenderName: false,
                          fallbackAvatarUrl: avatar,
                          onRetry: msg.deliveryStatus ==
                                  MessageDeliveryStatus.failed
                              ? () => repo.retryDirectMessage(
                                    widget.contactKey,
                                    msg.id,
                                  )
                              : null,
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: CasamaChatComposer(
                controller: _messageController,
                hintText: 'Message $displayName...',
                attachIcon: Icons.camera_alt_outlined,
                attachTooltip: 'Attach or Take Photo',
                onAttach: _showMediaPickerSheet,
                onSend: _sendMessage,
                pendingAttachment: _pendingAttachment,
                onRemoveAttachment: () =>
                    setState(() => _pendingAttachment = null),
                onReplaceAttachment: _showMediaPickerSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
