import 'package:casama/core/motion/casama_motion.dart';
import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/shared/widgets/avatar_chip.dart';
import 'package:casama/shared/widgets/cas_mascot_view.dart';
import 'package:casama/shared/widgets/casama_avatar.dart';
import 'package:casama/shared/widgets/casama_button.dart';
import 'package:casama/shared/widgets/casama_filter_controls.dart';
import 'package:casama/shared/widgets/casama_sheet_scaffold.dart';
import 'package:casama/shared/widgets/casama_text_field.dart';
import 'package:casama/shared/widgets/casama_wave_header.dart';
import 'package:casama/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 1 Design System, Motion & Mascot Tests', () {
    testWidgets('CasMascotView maps poses to transparent PNGs cleanly', (
      tester,
    ) async {
      final expected = {
        CasPose.hero: 'assets/images/cas/together_cards.png',
        CasPose.waving: 'assets/images/cas/migo_chat.png',
        CasPose.deliveries: 'assets/images/cas/migo_deliveries.png',
        CasPose.tasks: 'assets/images/cas/migo_tasks.png',
        CasPose.roulette: 'assets/images/cas/migo_roulette.png',
        CasPose.chores: 'assets/images/cas/migo_chores.png',
      };

      for (final entry in expected.entries) {
        await tester.pumpWidget(
          MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: Scaffold(
              body: CasMascotView(pose: entry.key, width: 96, height: 96),
            ),
          ),
        );
        final image = tester.widget<Image>(find.byType(Image));
        final asset = image.image as AssetImage;
        expect(asset.assetName, entry.value);
        // Ensure no decorative Container wrapper is painted around the PNG.
        expect(
          find.ancestor(
            of: find.byType(Image),
            matching: find.byType(Container),
          ),
          findsNothing,
        );
      }
    });

    testWidgets(
      'Wave header, peeking summary bar, filters, and Dark Mode parity render cleanly',
      (tester) async {
        var selectedFilter = 'all';
        var selectedSegment = 'up';

        for (final theme in [CasamaTheme.lightTheme, CasamaTheme.darkTheme]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: CasamaAmbientCanvas(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        CasamaWaveHeader(
                          title: 'Parcels & Deliveries',
                          subtitle: 'Casa 204 • Coordinate arrivals',
                          onMenuTap: () {},
                          onNotificationTap: () {},
                          unreadNotificationCount: 2,
                        ),
                        const CasamaPeekingSummaryBar(
                          mascotPose: CasPose.deliveries,
                          leftTitle: '2 Expected',
                          leftSubtitle: '1 arriving today',
                          rightTitle: '₱350.00 COD',
                          rightSubtitle: 'Cash needed today',
                        ),
                        CasamaSegmentedTrack<String>(
                          segments: const [
                            CasamaFilterOption(
                              value: 'up',
                              label: 'Upcoming (2)',
                            ),
                            CasamaFilterOption(
                              value: 'hist',
                              label: 'History (4)',
                            ),
                          ],
                          selectedValue: selectedSegment,
                          onSelected: (v) => selectedSegment = v,
                        ),
                        CasamaPillFilterRail<String>(
                          options: const [
                            CasamaFilterOption(value: 'all', label: 'All (4)'),
                            CasamaFilterOption(
                              value: 'overdue',
                              label: 'Overdue (1)',
                              isUrgent: true,
                            ),
                          ],
                          selectedValue: selectedFilter,
                          onSelected: (v) => selectedFilter = v,
                        ),
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              CasamaTextField(
                                label: 'Password',
                                isPassword: true,
                                hint: 'Enter password',
                              ),
                              SizedBox(height: 12),
                              StatusChip(label: 'COD', variant: ChipVariant.cod),
                              SizedBox(height: 12),
                              AvatarChip(
                                name: 'Maria Santos',
                                isHome: true,
                                isCurrentUser: false,
                              ),
                              SizedBox(height: 12),
                              CasamaAvatar(name: 'Jon Paul', showEditBadge: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(find.text('Parcels & Deliveries'), findsOneWidget);
          expect(find.text('₱350.00 COD'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'CasamaMorphingFab, CasamaPressable, and showCasamaSheet respect reduced motion',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Builder(
                builder: (ctx) => Scaffold(
                  floatingActionButton: CasamaMorphingFab(
                    visible: true,
                    icon: Icons.add_box_outlined,
                    label: 'Add parcel',
                    onPressed: () {
                      tapped = true;
                      showCasamaSheet<void>(
                        ctx,
                        icon: Icons.inventory_2_outlined,
                        title: 'Add Parcel',
                        subtitle: 'Tell housemates what is arriving',
                        builder: (_) => CasamaButton(
                          label: 'Save Parcel',
                          onPressed: () {},
                        ),
                      );
                    },
                  ),
                  body: const Center(child: Text('Body')),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Add parcel'));
        await tester.pump();
        expect(tapped, isTrue);
        expect(find.text('Add Parcel'), findsOneWidget);
        expect(find.text('Save Parcel'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        expect(find.text('Add Parcel'), findsNothing);
      },
    );
  });
}
