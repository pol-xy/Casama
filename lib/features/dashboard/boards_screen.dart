import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../bills/bills_dashboard_screen.dart';
import '../bills/widgets/edit_billings_sheet.dart';
import '../chore_roulette/widgets/task_roulette_sheet.dart';
import '../items/lost_found_screen.dart';
import '../items/widgets/report_item_sheet.dart';
import '../parcels/parcels_screen.dart';
import '../parcels/widgets/add_parcel_sheet.dart';
import '../tasks/maintenance_screen.dart';
import '../tasks/widgets/add_task_sheet.dart';
import 'main_navigation_shell.dart';
import 'widgets/casama_household_drawer.dart';

/// Unified 4-tab Household Boards hub (`Parcels`, `Tasks`, `Bills`, `Items`)
/// with horizontal swipe navigation synced with [CasamaShellScope],
/// `CasamaPeekingSummaryBar`, and contextual [CasamaMorphingFab].
class BoardsScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const BoardsScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<BoardsScreen> createState() => _BoardsScreenState();
}

class _BoardsScreenState extends ConsumerState<BoardsScreen> {
  late final PageController _pageController;
  late int _activeTab;
  ValueListenable<int>? _shellBoardListenable;

  static const _tabs = [
    _BoardTabMeta(
      headerTitle: 'Parcels & Deliveries',
      headerSubtitle: 'Coordinate arrivals & COD',
      pillLabel: 'Parcels',
      pillIcon: Icons.inventory_2_outlined,
      fabLabel: 'Add parcel',
      fabIcon: Icons.add_box_outlined,
    ),
    _BoardTabMeta(
      headerTitle: 'Household Tasks',
      headerSubtitle: 'Repairs, chores & restocks',
      pillLabel: 'Tasks',
      pillIcon: Icons.checklist_rounded,
      fabLabel: 'Add task',
      fabIcon: Icons.add_task_rounded,
    ),
    _BoardTabMeta(
      headerTitle: 'Bills & Payments',
      headerSubtitle: 'Shared utilities & due dates',
      pillLabel: 'Bills',
      pillIcon: Icons.receipt_long_outlined,
      fabLabel: 'Edit billings',
      fabIcon: Icons.edit_note_rounded,
    ),
    _BoardTabMeta(
      headerTitle: 'Lost & Found',
      headerSubtitle: 'Missing, found & shared items',
      pillLabel: 'Items',
      pillIcon: Icons.sell_outlined,
      fabLabel: 'Report item',
      fabIcon: Icons.sell_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab.clamp(0, 3);
    _pageController = PageController(initialPage: _activeTab);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = CasamaShellScope.maybeOf(context);
    final nextListenable = scope?.boardTabListenable;
    if (nextListenable != _shellBoardListenable) {
      _shellBoardListenable?.removeListener(_handleExternalBoardChange);
      _shellBoardListenable = nextListenable;
      _shellBoardListenable?.addListener(_handleExternalBoardChange);
      if (nextListenable != null && nextListenable.value != _activeTab) {
        _activeTab = nextListenable.value.clamp(0, 3);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(_activeTab);
          }
        });
      }
    }
  }

  void _handleExternalBoardChange() {
    final target = _shellBoardListenable?.value ?? 0;
    if (target == _activeTab || !mounted) return;
    setState(() => _activeTab = target.clamp(0, 3));
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_activeTab);
    }
  }

  @override
  void dispose() {
    _shellBoardListenable?.removeListener(_handleExternalBoardChange);
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    final target = index.clamp(0, 3);
    final scope = CasamaShellScope.maybeOf(context);
    if (scope != null &&
        scope.boardTabListenable is ValueNotifier<int> &&
        (scope.boardTabListenable as ValueNotifier<int>).value != target) {
      scope.openBoardTab(target);
    }
    setState(() => _activeTab = target);
    if (_pageController.hasClients) {
      final reduced = CasamaMotion.reduceMotion(context);
      if (reduced) {
        _pageController.jumpToPage(target);
      } else {
        _pageController.animateToPage(
          target,
          duration: CasamaMotion.boardSlide,
          curve: CasamaMotion.easeOut,
        );
      }
    }
  }

  void _onPageChanged(int index) {
    if (_activeTab == index) return;
    setState(() => _activeTab = index);
    final scope = CasamaShellScope.maybeOf(context);
    if (scope != null && scope.boardTabListenable is ValueNotifier<int>) {
      (scope.boardTabListenable as ValueNotifier<int>).value = index;
    }
  }

  void _onContextualFabPressed() {
    switch (_activeTab) {
      case 0:
        showAddParcelSheet(context);
      case 1:
        showNewTaskSheet(context);
      case 2:
        showEditBillingsSheet(context);
      case 3:
        showReportItemSheet(context);
    }
  }

  void _openDrawer() {
    final scope = CasamaShellScope.maybeOf(context);
    if (scope != null) {
      scope.openDrawer();
    } else {
      showCasamaHouseholdDrawer(
        context,
        onSelectBoardTab: _selectTab,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final repo = ref.watch(repositoryProvider);
    final meta = _tabs[_activeTab];
    final inShell = CasamaShellScope.maybeOf(context) != null;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final fabBottomOffset = inShell ? 84.0 + bottomInset : 20.0 + bottomInset;
    final bodyBottomPadding = inShell ? 156.0 + bottomInset : 96.0 + bottomInset;

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      body: CasamaAmbientCanvas(
        child: Stack(
          children: [
            Column(
              children: [
                CasamaWaveHeader(
                  title: meta.headerTitle,
                  subtitle:
                      '${repo.currentHousehold.name} • ${meta.headerSubtitle}',
                  compact: true,
                  unreadNotificationCount: repo.unreadNotificationCount,
                  onMenuTap: _openDrawer,
                  onNotificationTap: () {
                    ref.read(repositoryProvider).markAllNotificationsAsRead();
                    showCasamaToast(
                      context,
                      'All notifications caught up',
                      icon: Icons.done_all_rounded,
                    );
                  },
                  rightActions: [
                    if (_activeTab == 1)
                      CasamaHeaderActionPill(
                        icon: Icons.casino_outlined,
                        label: 'Spin Roulette',
                        onTap: () => showTaskRouletteSheet(context),
                      ),
                  ],
                  embeddedTabBar: _BoardsHeaderSwitcher(
                    tabs: _tabs,
                    activeIndex: _activeTab,
                    onSelected: _selectTab,
                  ),
                ),

                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: _onPageChanged,
                    children: [
                      ParcelsBoardView(bottomPadding: bodyBottomPadding),
                      TasksBoardView(bottomPadding: bodyBottomPadding),
                      BillsBoardView(bottomPadding: bodyBottomPadding),
                      ItemsBoardView(bottomPadding: bodyBottomPadding),
                    ],
                  ),
                ),
              ],
            ),

            // Contextual Morphing Board FAB (320ms spring overshoot)
            Positioned(
              right: 16,
              bottom: fabBottomOffset,
              child: CasamaMorphingFab(
                visible: true,
                icon: meta.fabIcon,
                label: meta.fabLabel,
                onPressed: _onContextualFabPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardsHeaderSwitcher extends StatelessWidget {
  final List<_BoardTabMeta> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelected;

  const _BoardsHeaderSwitcher({
    required this.tabs,
    required this.activeIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final reduced = CasamaMotion.reduceMotion(context);

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: CasamaSpacing.roundedPill,
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = i == activeIndex;
          final t = tabs[i];
          return Expanded(
            child: Semantics(
              button: true,
              container: true,
              excludeSemantics: true,
              selected: selected,
              label: '${t.pillLabel} board',
              child: CasamaPressable(
                onTap: () => onSelected(i),
                enableHaptic: true,
                child: AnimatedContainer(
                  duration: reduced ? Duration.zero : CasamaMotion.press,
                  curve: CasamaMotion.easeOut,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: CasamaSpacing.roundedPill,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        t.pillIcon,
                        size: 15,
                        color: selected
                            ? pal.forestTeal
                            : Colors.white.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          t.pillLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? pal.forestTeal
                                : Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BoardTabMeta {
  final String headerTitle;
  final String headerSubtitle;
  final String pillLabel;
  final IconData pillIcon;
  final String fabLabel;
  final IconData fabIcon;

  const _BoardTabMeta({
    required this.headerTitle,
    required this.headerSubtitle,
    required this.pillLabel,
    required this.pillIcon,
    required this.fabLabel,
    required this.fabIcon,
  });
}
