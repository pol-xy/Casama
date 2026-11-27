import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_wave_header.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxW = CasamaBreakpoints.isTablet(context)
        ? CasamaBreakpoints.maxContentWidth
        : double.infinity;

    final standings = repo.leaderboardStandings;
    const medals = ['🥇', '🥈', '🥉'];
    final entries = [
      for (var i = 0; i < standings.length; i++)
        _LeaderboardEntry(
          repo.resolveHousemateName(
            standings[i].userId,
            fallback: standings[i].displayName,
          ),
          standings[i].handle,
          standings[i].points,
          i < medals.length ? medals[i] : '🎖️',
          standings[i].avatarUrl,
          isCurrentUser: standings[i].isCurrentUser,
        ),
    ];

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      body: CasamaAmbientCanvas(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomInset + CasamaSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CasamaWaveHeader(
                title: 'Casama Leaderboard',
                subtitle: '${repo.currentHousehold.name} • November 2026',
                compact: true,
                onBackTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    GoRouter.maybeOf(context)?.pop();
                  }
                },
              ),

              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Celebration Split Hero (Transparent PNG Mascot + Rank Card)
                      Transform.translate(
                        offset: const Offset(0, -16),
                        child: CasamaSplitHero(
                          mascotPose: CasPose.roulette,
                          kicker: 'November 2026',
                          kickerDotColor: pal.amberFg,
                          headline: 'Good Kasama Rank',
                          subtitle:
                              'Every helpful deed builds a warmer household.',
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CasamaSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Household Standings',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: pal.textSecondary,
                              ),
                            ),
                            const SizedBox(height: CasamaSpacing.xs),

                            ...entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: CasamaSpacing.xs,
                                ),
                                child: CasamaCard(
                                  padding: const EdgeInsets.all(14),
                                  borderSide: entry.isCurrentUser
                                      ? BorderSide(
                                          color: pal.forestTeal,
                                          width: 1.5,
                                        )
                                      : null,
                                  child: Row(
                                    children: [
                                      Text(
                                        entry.medal,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      CasamaAvatar(
                                        radius: 20,
                                        avatarUrl: entry.avatarUrl,
                                        name: entry.name,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    entry.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              pal.textPrimary,
                                                        ),
                                                  ),
                                                ),
                                                if (entry.isCurrentUser) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 7,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: pal.softSage,
                                                      borderRadius:
                                                          CasamaSpacing
                                                              .roundedPill,
                                                    ),
                                                    child: Text(
                                                      'You',
                                                      style: theme
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color:
                                                                pal.forestTeal,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            Text(
                                              entry.handle,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    fontSize: 12,
                                                    color: pal.textSecondary,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: pal.softBlush,
                                          borderRadius:
                                              CasamaSpacing.roundedPill,
                                        ),
                                        child: Text(
                                          '${entry.points} pts',
                                          style: theme
                                              .textTheme
                                              .titleSmall
                                              ?.tabular
                                              .copyWith(
                                                color: pal.primaryCoral,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),

                            const SizedBox(height: CasamaSpacing.md),

                            CasamaCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'How to Earn Points',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: pal.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: CasamaSpacing.sm),
                                  const _PointRuleRow(
                                    label: 'Receive & confirm a delivery',
                                    points: '+5 pts',
                                  ),
                                  const _PointRuleRow(
                                    label: 'Complete cleaning or restock task',
                                    points: '+7 to +11 pts',
                                  ),
                                  const _PointRuleRow(
                                    label: 'Complete repair or personal request',
                                    points: '+10 to +14 pts',
                                  ),
                                  const _PointRuleRow(
                                    label: 'Task Roulette bonus (chosen housemate)',
                                    points: '+4 bonus pts',
                                  ),
                                  const _PointRuleRow(
                                    label:
                                        "Find & return a housemate's lost item",
                                    points: '+5 pts',
                                  ),
                                  const _PointRuleRow(
                                    label:
                                        'Post a found item claimed by a housemate',
                                    points: '+2 pts',
                                    isLast: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointRuleRow extends StatelessWidget {
  final String label;
  final String points;
  final bool isLast;

  const _PointRuleRow({
    required this.label,
    required this.points,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: pal.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: pal.successBg,
              borderRadius: CasamaSpacing.roundedPill,
            ),
            child: Text(
              points,
              style: theme.textTheme.labelSmall?.tabular.copyWith(
                color: pal.successFg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardEntry {
  final String name;
  final String handle;
  final int points;
  final String medal;
  final String? avatarUrl;
  final bool isCurrentUser;

  const _LeaderboardEntry(
    this.name,
    this.handle,
    this.points,
    this.medal,
    this.avatarUrl, {
    this.isCurrentUser = false,
  });
}
