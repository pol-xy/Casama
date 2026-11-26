import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_text_field.dart';
import '../../shared/widgets/casama_wave_header.dart';

/// Standalone route view (`/create-meetup`) complementing [showCreateMeetupSheet].
class CreateMeetupScreen extends ConsumerStatefulWidget {
  const CreateMeetupScreen({super.key});

  @override
  ConsumerState<CreateMeetupScreen> createState() => _CreateMeetupScreenState();
}

class _CreateMeetupScreenState extends ConsumerState<CreateMeetupScreen> {
  final _activityController = TextEditingController(text: 'Study Session 🎓');
  final _locationController = TextEditingController(text: 'Dorm Common Area');
  final _timeController = TextEditingController(text: 'Today • 7:00 PM');

  @override
  void dispose() {
    _activityController.dispose();
    _locationController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _sendInvitation() {
    final activity = _activityController.text.trim();
    final location = _locationController.text.trim();

    ref.read(repositoryProvider).createMeetUp(
      activity: activity,
      location: location,
      scheduledTime: DateTime.now().add(const Duration(hours: 3)),
    );
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    showCasamaToast(
      context,
      'Meet-up invitation sent to housemates!',
      icon: Icons.check_circle_outline_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxW = CasamaBreakpoints.isTablet(context)
        ? CasamaBreakpoints.maxContentWidth
        : double.infinity;

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      body: CasamaAmbientCanvas(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomInset + CasamaSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CasamaWaveHeader(
                title: 'Create Meet-up',
                subtitle: 'Suggest a time & spot for ${repo.currentHousehold.name}',
                compact: true,
                onBackTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CasamaSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Transparent PNG Mascot Split Hero
                        Transform.translate(
                          offset: const Offset(0, -14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const SizedBox(
                                width: 104,
                                height: 104,
                                child: CasMascotView(
                                  pose: CasPose.together,
                                  width: 104,
                                  height: 104,
                                ),
                              ),
                              const SizedBox(width: CasamaSpacing.sm),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: CasamaCard(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'HOUSEHOLD HANGOUT',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: pal.textSecondary,
                                                letterSpacing: 0.5,
                                              ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Bring the household together',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                color: pal.textPrimary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        CasamaCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CasamaTextField(
                                controller: _activityController,
                                label: 'Activity',
                                prefixIcon: Icons.calendar_today_outlined,
                                textCapitalization:
                                    TextCapitalization.sentences,
                              ),
                              const SizedBox(height: CasamaSpacing.md),
                              CasamaTextField(
                                controller: _locationController,
                                label: 'Location',
                                prefixIcon: Icons.location_on_outlined,
                                textCapitalization: TextCapitalization.words,
                              ),
                              const SizedBox(height: CasamaSpacing.md),
                              CasamaTextField(
                                controller: _timeController,
                                label: 'Time',
                                prefixIcon: Icons.access_time_rounded,
                              ),
                              const SizedBox(height: CasamaSpacing.md),
                              Text(
                                'INVITEES (${repo.members.length})',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: pal.textSecondary,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: CasamaSpacing.xs),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: repo.members.map((m) {
                                  return Container(
                                    padding: const EdgeInsets.only(
                                      left: 4,
                                      right: 10,
                                      top: 4,
                                      bottom: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: pal.track,
                                      borderRadius: CasamaSpacing.roundedPill,
                                      border: Border.all(color: pal.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CasamaAvatar(
                                          radius: 13,
                                          avatarUrl: m.profile.avatarUrl,
                                          name: m.profile.displayName,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          m.profile.displayName,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color: pal.textPrimary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: CasamaSpacing.lg),

                        CasamaButton(
                          label: 'Send Invitation',
                          icon: Icons.send_rounded,
                          onPressed: _sendInvitation,
                          height: 52,
                        ),
                      ],
                    ),
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
