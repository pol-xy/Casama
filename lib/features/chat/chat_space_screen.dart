import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  void _shareSpaceCode(ChatSpace space) {
    ref
        .read(repositoryProvider)
        .sendSpaceMessage(
          widget.spaceId,
          '🔑 Space Invitation Code: ${space.inviteCode}',
          inviteCode: space.inviteCode,
          inviteSpaceName: space.name,
        );
    _scrollToBottom();
  }

  void _showAttachmentMenu(BuildContext context, ChatSpace space) {
    final pal = context.palette;

    showCasamaSheet<void>(
      context,
      icon: Icons.add_circle_outline_rounded,
      title: 'Share in ${space.name}',
      subtitle: 'Attach photos or post this space invite code',
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
          Divider(height: 16, color: pal.divider),
          CasamaSheetActionRow(
            icon: Icons.vpn_key_rounded,
            iconColor: pal.successFg,
            iconBg: pal.successBg,
            title: 'Share Space Invite Code (${space.inviteCode})',
            subtitle:
                'Share into this space so members can invite other housemates',
            onTap: () {
              Navigator.pop(ctx);
              _shareSpaceCode(space);
            },
          ),
        ],
      ),
    );
  }

  void _showSpaceInfoSheet(BuildContext context, ChatSpace space) {
    final allHouseholdMembers = ref
        .read(repositoryProvider)
        .members
        .map((m) => m.profile.displayName)
        .toList();

    showCasamaSheet<void>(
      context,
      icon: Icons.forum_rounded,
      title: '${space.iconEmoji} ${space.name}',
      subtitle:
          'Created by ${space.creatorName} • ${space.memberNames.length} members',
      builder: (ctx) => StatefulBuilder(
        builder: (innerCtx, setModalState) {
          final pal = innerCtx.palette;
          final theme = Theme.of(innerCtx);
          final currentSpace = ref
              .watch(repositoryProvider)
              .chatSpaces
              .firstWhere((s) => s.id == widget.spaceId, orElse: () => space);
          final nonMembers = allHouseholdMembers
              .where((name) => !currentSpace.memberNames.contains(name))
              .toList();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (currentSpace.description.isNotEmpty) ...[
                Text(
                  currentSpace.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: pal.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: CasamaSpacing.md),
              ],
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: pal.track,
                  borderRadius: CasamaSpacing.roundedCard,
                  border: Border.all(color: pal.border),
                ),
                child: Column(
                  children: [
                    Text(
                      'SPACE INVITATION CODE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                        color: pal.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currentSpace.inviteCode,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                            color: pal.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Semantics(
                          button: true,
                          label: 'Copy space code',
                          child: CasamaPressable(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: currentSpace.inviteCode),
                              );
                              showCasamaToast(
                                context,
                                'Copied space code "${currentSpace.inviteCode}"!',
                                icon: Icons.copy_rounded,
                              );
                            },
                            child: Container(
                              width: CasamaSpacing.minTouchTarget,
                              height: CasamaSpacing.minTouchTarget,
                              decoration: BoxDecoration(
                                color: pal.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: pal.border),
                              ),
                              child: Icon(
                                Icons.copy_rounded,
                                color: pal.primaryCoral,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Housemates can enter this code in Chat to join instantly.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: CasamaSpacing.md),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Space Members (${currentSpace.memberNames.length})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    if (nonMembers.isNotEmpty)
                      Text(
                        '${nonMembers.length} available to add',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: pal.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: CasamaSpacing.xs),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: currentSpace.memberNames.map((name) {
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
                        CasamaAvatar(radius: 12, name: name),
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
              if (nonMembers.isNotEmpty) ...[
                const SizedBox(height: CasamaSpacing.md),
                Text(
                  'Add Housemates Directly:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
                const SizedBox(height: CasamaSpacing.xs),
                ...nonMembers.map((name) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        CasamaAvatar(radius: 16, name: name),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: pal.textPrimary,
                            ),
                          ),
                        ),
                        CasamaPressable(
                          onTap: () {
                            ref
                                .read(repositoryProvider)
                                .addMemberToSpace(currentSpace.id, name);
                            setModalState(() {});
                            showCasamaToast(
                              context,
                              'Added $name to ${currentSpace.name}!',
                              icon: Icons.check_circle_outline_rounded,
                            );
                          },
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: pal.forestTeal,
                              borderRadius: CasamaSpacing.roundedPill,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: pal.onForestTeal,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Add',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: pal.onForestTeal,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          );
        },
      ),
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

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      body: CasamaAmbientCanvas(
        child: Column(
          children: [
            CasamaChatThreadHeader(
              title: space.name,
              subtitle:
                  '${space.memberNames.length} members • Code: ${space.inviteCode}',
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
                  semanticLabel: 'Space Details & Code',
                  onTap: () => _showSpaceInfoSheet(context, space),
                ),
              ],
            ),
            Expanded(
              child: space.messages.isEmpty
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
                                'Share updates or invite housemates using code ${space.inviteCode}',
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
                      itemCount: space.messages.length,
                      itemBuilder: (context, index) {
                        final msg = space.messages[index];
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
