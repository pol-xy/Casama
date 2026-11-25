import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/casama_repository.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_sheet_scaffold.dart';

/// Shows the Add Housemate slide-up sheet with search, code sharing,
/// and pending invitation management.
Future<void> showAddHousemateDialog(BuildContext context) {
  return showCasamaSheet<void>(
    context,
    icon: Icons.person_add_alt_1_rounded,
    title: 'Add Housemate',
    subtitle: 'Invite or approve roommates for your household',
    builder: (sheetCtx) {
      final h = (MediaQuery.sizeOf(sheetCtx).height * 0.62).clamp(360.0, 560.0);
      return SizedBox(
        height: h,
        child: _AddHousemateSheetBody(hostContext: context),
      );
    },
  );
}

class _AddHousemateSheetBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;

  const _AddHousemateSheetBody({required this.hostContext});

  @override
  ConsumerState<_AddHousemateSheetBody> createState() =>
      _AddHousemateSheetBodyState();
}

class _AddHousemateSheetBodyState extends ConsumerState<_AddHousemateSheetBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final pendingInvites = repo.invitations
        .where((i) => i.status == InvitationStatus.pending)
        .toList();

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: pal.primaryCoral,
          indicatorWeight: 3,
          labelColor: pal.primaryCoral,
          unselectedLabelColor: pal.textSecondary,
          dividerColor: pal.divider,
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: [
            const Tab(text: 'Find User'),
            const Tab(text: 'Invite Code'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pending'),
                  if (pendingInvites.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: pal.primaryCoral,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${pendingInvites.length}',
                        style: TextStyle(
                          color: pal.onPrimaryCoral,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.sm),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSearchTab(context, pal, theme, repo),
              _buildCodeTab(context, pal, theme, repo),
              _buildPendingTab(context, pal, theme, repo, pendingInvites),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchTab(
    BuildContext context,
    CasamaPalette pal,
    ThemeData theme,
    CasamaRepository repo,
  ) {
    final searchResults = repo.searchUsers(_searchQuery);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          style: TextStyle(color: pal.textPrimary, fontSize: 14),
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search by username or handle (e.g. @miguel)...',
            hintStyle: TextStyle(fontSize: 13, color: pal.textMuted),
            prefixIcon: Icon(Icons.search_rounded, color: pal.textSecondary),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, size: 18, color: pal.textMuted),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: pal.track,
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: CasamaSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: pal.softSage,
            borderRadius: CasamaSpacing.roundedMd,
            border: Border.all(color: pal.forestTeal.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 15, color: pal.forestTeal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Household membership requires an invite. Search does not expose private room data.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    color: pal.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: CasamaSpacing.sm),
        Expanded(
          child: _searchQuery.trim().isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_search_outlined,
                        size: 40,
                        color: pal.textMuted,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Search for Housemates',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: pal.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try searching "@miguel", "@clara", or "@bea"',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: pal.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : searchResults.isEmpty
              ? Center(
                  child: Text(
                    'No Casama users found matching "$_searchQuery"',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: pal.textSecondary,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: searchResults.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: pal.divider),
                  itemBuilder: (context, index) {
                    final UserProfile user = searchResults[index];
                    final isAlreadyInvited = repo.invitations.any(
                      (inv) =>
                          inv.inviteeEmailOrHandle.toLowerCase() ==
                              user.handle.toLowerCase() &&
                          inv.status == InvitationStatus.pending,
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          CasamaAvatar(
                            avatarUrl: user.avatarUrl,
                            radius: 20,
                            name: user.displayName,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: pal.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  user.handle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: pal.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          isAlreadyInvited
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pal.track,
                                    borderRadius: CasamaSpacing.roundedPill,
                                  ),
                                  child: Text(
                                    'Invited',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: pal.textMuted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              : CasamaButton(
                                  label: 'Invite',
                                  icon: Icons.send_rounded,
                                  style: CasamaButtonStyle.navy,
                                  isFullWidth: false,
                                  height: 44,
                                  onPressed: () {
                                    final sent = repo.sendInvitation(
                                      inviteeEmailOrHandle: user.handle,
                                      inviteeName: user.displayName,
                                    );
                                    if (sent) {
                                      showCasamaToast(
                                        widget.hostContext,
                                        'Invitation sent to ${user.displayName} (${user.handle})!',
                                        icon: Icons.check_circle_outline_rounded,
                                      );
                                      setState(() {});
                                    }
                                  },
                                ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCodeTab(
    BuildContext context,
    CasamaPalette pal,
    ThemeData theme,
    CasamaRepository repo,
  ) {
    final inviteCode = repo.currentHousehold.inviteCode;
    final householdName = repo.currentHousehold.name;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: CasamaSpacing.sm),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: pal.softBlush,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.vpn_key_rounded,
              size: 28,
              color: pal.primaryCoral,
            ),
          ),
          const SizedBox(height: CasamaSpacing.sm),
          Text(
            'Join Code for $householdName',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Share this code with your housemates. They can enter it during setup to instantly join.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: pal.textSecondary,
            ),
          ),
          const SizedBox(height: CasamaSpacing.md),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: pal.track,
              borderRadius: CasamaSpacing.roundedCard,
              border: Border.all(color: pal.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  inviteCode,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: pal.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: 'Copy invite code',
                  child: CasamaPressable(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: inviteCode));
                      showCasamaToast(
                        widget.hostContext,
                        'Copied invite code "$inviteCode"!',
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
          ),
          const SizedBox(height: CasamaSpacing.lg),

          CasamaButton(
            label: 'Copy Invitation Message',
            icon: Icons.share_rounded,
            onPressed: () {
              final message =
                  'Hey! Join our household "$householdName" on Casama using invite code: $inviteCode. Download the app to coordinate deliveries, chores, and housemate plans!';
              Clipboard.setData(ClipboardData(text: message));
              showCasamaToast(
                widget.hostContext,
                'Invitation message copied to clipboard!',
                icon: Icons.check_circle_outline_rounded,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTab(
    BuildContext context,
    CasamaPalette pal,
    ThemeData theme,
    CasamaRepository repo,
    List<HouseholdInvitation> pendingInvites,
  ) {
    if (pendingInvites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mark_email_read_outlined,
              size: 40,
              color: pal.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              'No Pending Invitations',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: pal.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All household invites have been accepted or processed.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: pal.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: CasamaSpacing.xs),
      itemCount: pendingInvites.length,
      separatorBuilder: (_, _) => const SizedBox(height: CasamaSpacing.sm),
      itemBuilder: (context, index) {
        final inv = pendingInvites[index];
        final name = inv.inviteeName ?? inv.inviteeEmailOrHandle;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: CasamaSpacing.roundedCard,
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: pal.textPrimary,
                          ),
                        ),
                        Text(
                          '${inv.inviteeEmailOrHandle} • Invited by ${inv.inviterName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: pal.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: pal.softBlush,
                      borderRadius: CasamaSpacing.roundedPill,
                    ),
                    child: Text(
                      'Pending',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: pal.primaryCoral,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CasamaSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Accept $name',
                      child: CasamaPressable(
                        onTap: () {
                          repo.acceptInvitation(inv.id);
                          showCasamaToast(
                            widget.hostContext,
                            '$name joined the household! 🎉',
                            icon: Icons.check_circle_outline_rounded,
                          );
                          setState(() {});
                        },
                        child: Container(
                          height: CasamaSpacing.minTouchTarget,
                          decoration: BoxDecoration(
                            color: pal.successBg,
                            borderRadius: CasamaSpacing.roundedPill,
                            border: Border.all(
                              color: pal.successFg.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 17,
                                color: pal.successFg,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Accept',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: pal.successFg,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: CasamaSpacing.xs),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Decline $name',
                      child: CasamaPressable(
                        onTap: () {
                          repo.declineInvitation(inv.id);
                          showCasamaToast(
                            widget.hostContext,
                            'Declined invitation for ${inv.inviteeEmailOrHandle}.',
                            icon: Icons.cancel_outlined,
                          );
                          setState(() {});
                        },
                        child: Container(
                          height: CasamaSpacing.minTouchTarget,
                          decoration: BoxDecoration(
                            color: pal.surface,
                            borderRadius: CasamaSpacing.roundedPill,
                            border: Border.all(color: pal.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cancel_outlined,
                                size: 17,
                                color: pal.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Decline',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: pal.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
