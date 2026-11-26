import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_sheet_scaffold.dart';
import '../../shared/widgets/casama_wave_header.dart';
import 'widgets/chat_thread_components.dart';

class ChatSpaceScreen extends ConsumerStatefulWidget {
  final String spaceId;

  const ChatSpaceScreen({super.key, required this.spaceId});

  @override
  ConsumerState<ChatSpaceScreen> createState() => _ChatSpaceScreenState();
}

class _ChatSpaceScreenState extends ConsumerState<ChatSpaceScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(repositoryProvider).markSpaceChatAsRead(widget.spaceId);
      }
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    ref.read(repositoryProvider).sendSpaceMessage(widget.spaceId, text);
    _msgController.clear();
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

  Future<void> _pickAndSendPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        ref
            .read(repositoryProvider)
            .sendSpaceMessage(
              widget.spaceId,
              '📷 Photo shared',
              mediaUrl: base64String,
            );
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        showCasamaToast(
          context,
          'Could not attach image: $e',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  void _showAttachmentMenu(BuildContext context, ChatSpace space) {
    final pal = context.palette;

    showCasamaSheet<void>(
      context,
      icon: Icons.add_circle_outline_rounded,
      title: 'Share in ${space.name}',
      subtitle: 'Attach a photo from camera or gallery',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CasamaSheetActionRow(
            icon: Icons.camera_alt_outlined,
            iconColor: pal.primaryCoral,
            iconBg: pal.softBlush,
            title: 'Take Photo',
            onTap: () {
              Navigator.pop(ctx);
              _pickAndSendPhoto(ImageSource.camera);
            },
          ),
          CasamaSheetActionRow(
            icon: Icons.photo_library_outlined,
            iconColor: pal.infoFg,
            iconBg: pal.infoBg,
            title: 'Choose from Gallery',
            onTap: () {
              Navigator.pop(ctx);
              _pickAndSendPhoto(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  void _showSpaceInfoSheet(BuildContext context, ChatSpace space) {
    final repo = ref.read(repositoryProvider);
    final allHouseholdMembers = repo.members;

    showCasamaSheet<void>(
      context,
      icon: Icons.forum_rounded,
      title: '${space.iconEmoji} ${space.name}',
      subtitle: 'Created by ${space.creatorName}',
      builder: (ctx) {
        final pal = ctx.palette;
        final theme = Theme.of(ctx);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (space.description.isNotEmpty) ...[
              Text(
                space.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: pal.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: CasamaSpacing.md),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pal.softSage,
                borderRadius: CasamaSpacing.roundedMd,
                border: Border.all(
                  color: pal.forestTeal.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.groups_rounded, size: 18, color: pal.forestTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All ${repo.currentHousehold.name} housemates are automatically included in this space.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pal.textPrimary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CasamaSpacing.md),
            Text(
              'Household Members (${allHouseholdMembers.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: pal.textPrimary,
              ),
            ),
            const SizedBox(height: CasamaSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: allHouseholdMembers.map((member) {
                final name = member.profile.displayName;
                return Container(
                  padding: const EdgeInsets.only(
                    left: 5,
                    right: 12,
                    top: 5,
                    bottom: 5,
                  ),
                  decoration: BoxDecoration(
                    color: pal.card,
                    borderRadius: CasamaSpacing.roundedPill,
                    border: Border.all(color: pal.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CasamaAvatar(
                        avatarUrl: member.profile.avatarUrl,
                        radius: 12,
                        name: name,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: pal.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final space = repo.chatSpaces.firstWhere(
      (s) => s.id == widget.spaceId,
      orElse: () => repo.chatSpaces.isNotEmpty
          ? repo.chatSpaces.first
          : ChatSpace(
              id: 'none',
              householdId: '',
              name: 'Space',
              description: '',
              inviteCode: '',
              creatorId: '',
              creatorName: '',
              memberNames: const [],
              createdAt: DateTime(2026, 1, 1),
            ),
    );

    final visibleMessages = space.messages
        .where(
          (m) => !(m.inviteCode != null && m.inviteCode!.startsWith('SPC-')),
        )
        .toList();

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      body: CasamaAmbientCanvas(
        child: Column(
          children: [
            CasamaChatThreadHeader(
              title: space.name,
              subtitle:
                  '${repo.currentHousehold.name} • All ${repo.members.length} housemates',
              onBack: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              onTitleTap: () => _showSpaceInfoSheet(context, space),
              leadingBadge: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: CasamaSpacing.roundedMd,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  space.iconEmoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              rightActions: [
                CasamaCircleIconButton(
                  icon: Icons.info_outline_rounded,
                  semanticLabel: 'Space Details',
                  onTap: () => _showSpaceInfoSheet(context, space),
                ),
              ],
            ),
            Expanded(
              child: visibleMessages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(CasamaSpacing.lg),
                        child: CasamaCard(
                          padding: const EdgeInsets.all(CasamaSpacing.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                space.iconEmoji,
                                style: const TextStyle(fontSize: 44),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Welcome to ${space.name}!',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: pal.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Share updates and photos with your household',
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
                      itemCount: visibleMessages.length,
                      itemBuilder: (context, index) {
                        final msg = visibleMessages[index];
                        return CasamaMessageBubble(
                          message: msg,
                          timeLabel: DateFormat('h:mm a').format(msg.createdAt),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: CasamaChatComposer(
                controller: _msgController,
                hintText: 'Message in ${space.name}...',
                attachIcon: Icons.add_circle_outline_rounded,
                attachTooltip: 'Attach photo or Share code',
                onAttach: () => _showAttachmentMenu(context, space),
                onSend: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
