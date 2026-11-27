import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/casama_repository.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_sheet_scaffold.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../chore_roulette/widgets/task_roulette_sheet.dart';
import '../household/add_housemate_dialog.dart';
import 'widgets/chat_thread_components.dart';
import 'widgets/plan_housemates_agenda_sheet.dart';

String formatGroupChatWheelSpinMessage({
  required String question,
  required String winnerName,
  required bool landedOnSelf,
}) {
  final trimmedQuestion = question.trim();
  final outcomeLine = landedOnSelf
      ? '👉 Landed on: me! 😂'
      : '👉 Landed on: $winnerName! 🎉';
  return '🎡 Just spun the wheel!\n\n'
      '"$trimmedQuestion"\n'
      '$outcomeLine';
}

class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key});

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  XFile? _pendingAttachment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(repositoryProvider).markGroupChatAsRead();
      }
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _msgController.text.trim();
    final attachment = _pendingAttachment;
    if (text.isEmpty && attachment == null) return;
    _msgController.clear();
    if (_pendingAttachment != null) {
      setState(() => _pendingAttachment = null);
    }
    ref
        .read(repositoryProvider)
        .sendChatMessage(text, attachmentFile: attachment);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        scrollChatListToBottom(context, _scrollController);
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

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final repo = ref.watch(repositoryProvider);
    final messages = repo.groupMessages;
    final members = repo.members;
    final activeCount = members.where((m) => m.isHome).length;

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      body: CasamaAmbientCanvas(
        child: Column(
          children: [
            CasamaChatThreadHeader(
              title: repo.currentHousehold.name,
              subtitle: '${members.length} members • $activeCount Home',
              onBack: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              onTitleTap: () => _showHouseholdMembersSheet(context, repo),
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
                child: const Icon(
                  Icons.home_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              rightActions: [
                CasamaCircleIconButton(
                  icon: Icons.people_alt_outlined,
                  semanticLabel: 'View Members',
                  onTap: () => _showHouseholdMembersSheet(context, repo),
                ),
              ],
            ),
            Expanded(
              child: CasamaChatMessageList(
                controller: _scrollController,
                messages: messages,
                showTodayPillWhenEmpty: true,
                senderNameBuilder: (m) => repo.resolveHousemateName(
                  m.senderId,
                  fallback: m.senderName,
                ),
                onRetryBuilder: (m) =>
                    m.deliveryStatus == MessageDeliveryStatus.failed
                        ? () => repo.retryGroupMessage(m.id)
                        : null,
                onRespondHousematesAgenda:
                    repo.respondToHousematesAgendaInvitation,
              ),
            ),
            SafeArea(
              top: false,
              child: CasamaChatComposer(
                controller: _msgController,
                hintText: 'Message ${repo.currentHousehold.name}...',
                attachIcon: Icons.add_rounded,
                attachTooltip: 'Attach or propose activity',
                onAttach: () => _showAttachmentModal(context),
                onSend: _send,
                pendingAttachment: _pendingAttachment,
                onRemoveAttachment: () =>
                    setState(() => _pendingAttachment = null),
                onReplaceAttachment: () => _showAttachmentModal(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveRouletteName(UserProfile p) => p.preferredName;

  void _showAttachmentModal(BuildContext context) {
    final pal = context.palette;

    showCasamaSheet<void>(
      context,
      icon: Icons.add_rounded,
      title: 'Share in Chat',
      subtitle: 'Attach photos, codes, or coordinate a household plan',
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
            subtitle: 'Post code card to group chat for roommates to copy',
            onTap: () {
              Navigator.pop(ctx);
              final household = ref.read(repositoryProvider).currentHousehold;
              ref.read(repositoryProvider).shareInviteCodeToGroupChat(
                code: household.inviteCode,
                title: household.name,
              );
              _scrollToBottom();
            },
          ),
          Divider(height: 16, color: pal.divider),
          CasamaSheetActionRow(
            icon: Icons.celebration_outlined,
            iconColor: pal.primaryCoral,
            iconBg: pal.softBlush,
            title: 'Plan Housemates Agenda',
            onTap: () {
              Navigator.pop(ctx);
              showPlanHousematesAgendaSheet(context);
            },
          ),
          CasamaSheetActionRow(
            icon: Icons.casino_outlined,
            iconColor: pal.forestTeal,
            iconBg: pal.softSage,
            title: 'Ask the Wheel',
            onTap: () {
              Navigator.pop(ctx);
              showTaskRouletteSheet(
                context,
                mode: TaskRouletteMode.chatQuestion,
                onChatSpinSubmitted: (question, winner) async {
                  final repo = ref.read(repositoryProvider);
                  final messageText = formatGroupChatWheelSpinMessage(
                    question: question,
                    winnerName: _resolveRouletteName(winner.profile),
                    landedOnSelf: winner.profile.id == repo.currentUser.id,
                  );
                  repo.sendChatMessage(
                    messageText,
                    clientMessageId: const Uuid().v4(),
                  );
                  _scrollToBottom();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showHouseholdMembersSheet(BuildContext context, CasamaRepository repo) {
    final members = repo.members;

    showCasamaSheet<void>(
      context,
      icon: Icons.people_alt_rounded,
      title: '${repo.currentHousehold.name} Members (${members.length})',
      subtitle: 'Live household presence & direct messaging',
      builder: (ctx) {
        final pal = ctx.palette;
        final theme = Theme.of(ctx);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...members.map((m) {
              final isMe = m.profile.id == repo.currentUser.id;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CasamaAvatar(
                      radius: 20,
                      avatarUrl: m.profile.avatarUrl,
                      name: m.preferredName,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  m.preferredName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: pal.textPrimary,
                                  ),
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pal.track,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'You',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      color: pal.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            m.isHome
                                ? 'At home • ${m.note ?? "Present"}'
                                : 'Away • ${m.note ?? "Out"}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: m.isHome ? pal.successFg : pal.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isMe)
                      Semantics(
                        button: true,
                        label: 'Direct message ${m.preferredName}',
                        child: CasamaPressable(
                          onTap: () {
                            Navigator.pop(ctx);
                            final contactKey =
                                m.profile.displayName.toLowerCase();
                            GoRouter.maybeOf(context)?.push(
                              '/direct-chat?contact=$contactKey&name=${Uri.encodeComponent(m.preferredName)}',
                            );
                          },
                          child: Container(
                            width: CasamaSpacing.minTouchTarget,
                            height: CasamaSpacing.minTouchTarget,
                            decoration: BoxDecoration(
                              color: pal.softBlush,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 19,
                              color: pal.primaryCoral,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: CasamaSpacing.md),
            CasamaButton(
              label: 'Add Housemate',
              icon: Icons.person_add_alt_1_rounded,
              onPressed: () {
                Navigator.pop(ctx);
                showAddHousemateDialog(context);
              },
            ),
          ],
        );
      },
    );
  }
}
