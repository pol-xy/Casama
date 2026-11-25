import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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
import '../household/add_housemate_dialog.dart';
import 'widgets/chat_thread_components.dart';
import 'widgets/create_meetup_sheet.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key});

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
    if (text.isEmpty) return;
    ref.read(repositoryProvider).sendChatMessage(text);
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

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        ref
            .read(repositoryProvider)
            .sendChatMessage('📷 Photo shared', mediaUrl: base64String);
        _scrollToBottom();
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
    final meetup = repo.activeMeetUp;
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
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: CasamaSpacing.md,
                  vertical: CasamaSpacing.md,
                ),
                children: [
                  const CasamaChatDatePill(label: 'Today'),
                  ...messages.map(
                    (m) => CasamaMessageBubble(
                      message: m,
                      timeLabel: DateFormat('h:mm a').format(m.createdAt),
                      onJoinSpaceCode: (code) {
                        final space = ref
                            .read(repositoryProvider)
                            .joinChatSpaceByCode(code);
                        if (space != null) {
                          GoRouter.maybeOf(
                            context,
                          )?.push('/space-chat?id=${space.id}');
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: CasamaSpacing.sm),
                  _buildMeetupCard(context, meetup, pal),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: CasamaChatComposer(
                controller: _msgController,
                hintText: 'Message ${repo.currentHousehold.name}...',
                attachIcon: Icons.attach_file_rounded,
                attachTooltip: 'Attach or propose activity',
                onAttach: () => _showAttachmentModal(context),
                onSend: _send,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetupCard(
    BuildContext context,
    MeetUpInvitation meetup,
    CasamaPalette pal,
  ) {
    final theme = Theme.of(context);

    return CasamaCard(
      padding: const EdgeInsets.all(14),
      borderSide: BorderSide(color: pal.forestTeal, width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: pal.softSage,
                  borderRadius: CasamaSpacing.roundedPill,
                ),
                child: Text(
                  'MEET-UP INVITATION',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: pal.forestTeal,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.chevron_right_rounded, color: pal.textSecondary),
                tooltip: 'RSVP options',
                onPressed: () => _showRsvpDialog(context, meetup),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: pal.softSage,
                  borderRadius: CasamaSpacing.roundedMd,
                ),
                child: Icon(
                  Icons.event_rounded,
                  color: pal.forestTeal,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meetup.activity,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Today • 7:00 PM • ${meetup.location}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pal.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RsvpChipButton(
                  label: 'Going (${meetup.goingCount})',
                  selected: meetup.currentUserResponse == 'going',
                  activeBg: pal.successFg,
                  onTap: () => ref.read(repositoryProvider).respondMeetUp('going'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _RsvpChipButton(
                  label: 'Maybe (${meetup.maybeCount})',
                  selected: meetup.currentUserResponse == 'maybe',
                  activeBg: pal.amberFg,
                  onTap: () => ref.read(repositoryProvider).respondMeetUp('maybe'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _RsvpChipButton(
                  label: "Can't (${meetup.cantMakeCount})",
                  selected: meetup.currentUserResponse == 'cant_make_it',
                  activeBg: pal.neutralFg,
                  onTap: () =>
                      ref.read(repositoryProvider).respondMeetUp('cant_make_it'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRsvpDialog(BuildContext context, MeetUpInvitation meetup) {
    showCasamaSheet<void>(
      context,
      icon: Icons.event_available_rounded,
      title: meetup.activity,
      subtitle: 'Location: ${meetup.location}',
      builder: (ctx) {
        final pal = ctx.palette;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'YOUR RESPONSE',
              style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                color: pal.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: CasamaSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _RsvpChipButton(
                    label: 'Going 🎉',
                    selected: meetup.currentUserResponse == 'going',
                    activeBg: pal.successFg,
                    onTap: () {
                      ref.read(repositoryProvider).respondMeetUp('going');
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RsvpChipButton(
                    label: 'Maybe 🤔',
                    selected: meetup.currentUserResponse == 'maybe',
                    activeBg: pal.amberFg,
                    onTap: () {
                      ref.read(repositoryProvider).respondMeetUp('maybe');
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RsvpChipButton(
                    label: "Can't 😅",
                    selected: meetup.currentUserResponse == 'cant_make_it',
                    activeBg: pal.neutralFg,
                    onTap: () {
                      ref
                          .read(repositoryProvider)
                          .respondMeetUp('cant_make_it');
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showAttachmentModal(BuildContext context) {
    final pal = context.palette;

    showCasamaSheet<void>(
      context,
      icon: Icons.attach_file_rounded,
      title: 'Share in Chat',
      subtitle: 'Attach photos, codes, or coordinate a household plan',
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
              _pickAndSendImage(ImageSource.camera);
            },
          ),
          CasamaSheetActionRow(
            icon: Icons.photo_library_outlined,
            iconColor: pal.infoFg,
            iconBg: pal.infoBg,
            title: 'Choose from Gallery',
            onTap: () {
              Navigator.pop(ctx);
              _pickAndSendImage(ImageSource.gallery);
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
          if (ref.read(repositoryProvider).chatSpaces.isNotEmpty)
            CasamaSheetActionRow(
              icon: Icons.groups_outlined,
              iconColor: pal.primaryCoral,
              iconBg: pal.softBlush,
              title: 'Share Space Code...',
              subtitle: 'Post a custom space code to invite housemates',
              onTap: () {
                Navigator.pop(ctx);
                _showSelectSpaceToShareSheet(context);
              },
            ),
          Divider(height: 16, color: pal.divider),
          CasamaSheetActionRow(
            icon: Icons.celebration_outlined,
            iconColor: pal.primaryCoral,
            iconBg: pal.softBlush,
            title: 'Propose Meet-up Activity',
            onTap: () {
              Navigator.pop(ctx);
              showCreateMeetupSheet(context);
            },
          ),
          CasamaSheetActionRow(
            icon: Icons.casino_outlined,
            iconColor: pal.forestTeal,
            iconBg: pal.softSage,
            title: 'Spin Chore Roulette',
            onTap: () {
              Navigator.pop(ctx);
              GoRouter.maybeOf(context)?.push('/roulette');
            },
          ),
        ],
      ),
    );
  }

  void _showSelectSpaceToShareSheet(BuildContext context) {
    final spaces = ref.read(repositoryProvider).chatSpaces;
    showCasamaSheet<void>(
      context,
      icon: Icons.groups_outlined,
      title: 'Select a Space to Share',
      subtitle: 'Post an instant join card in group chat',
      builder: (ctx) {
        final pal = ctx.palette;
        final theme = Theme.of(ctx);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: spaces.map((s) {
            return CasamaPressable(
              onTap: () {
                Navigator.pop(ctx);
                ref.read(repositoryProvider).shareInviteCodeToGroupChat(
                  code: s.inviteCode,
                  title: '${s.iconEmoji} ${s.name}',
                );
                _scrollToBottom();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(s.iconEmoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: pal.textPrimary,
                            ),
                          ),
                          Text(
                            'Code: ${s.inviteCode} • ${s.memberNames.length} members',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11.5,
                              color: pal.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.send_rounded, size: 18, color: pal.primaryCoral),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
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
                      name: m.profile.displayName,
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
                                  m.profile.displayName,
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
                        label: 'Direct message ${m.profile.displayName}',
                        child: CasamaPressable(
                          onTap: () {
                            Navigator.pop(ctx);
                            final contactKey =
                                m.profile.displayName.toLowerCase();
                            GoRouter.maybeOf(context)?.push(
                              '/direct-chat?contact=$contactKey&name=${Uri.encodeComponent(m.profile.displayName)}',
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

class _RsvpChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color activeBg;
  final VoidCallback onTap;

  const _RsvpChipButton({
    required this.label,
    required this.selected,
    required this.activeBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final reduced = CasamaMotion.reduceMotion(context);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: CasamaPressable(
        onTap: onTap,
        enableHaptic: true,
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : CasamaMotion.press,
          curve: CasamaMotion.easeOut,
          height: CasamaSpacing.minTouchTarget,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? activeBg : pal.surface,
            borderRadius: CasamaSpacing.roundedPill,
            border: Border.all(
              color: selected ? activeBg : pal.border,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? Colors.white : pal.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
