import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_lost_found_icon.dart';
import '../../shared/widgets/casama_wave_background.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../items/lost_found_screen.dart';
import '../items/widgets/report_item_sheet.dart';
import '../parcels/parcels_screen.dart';
import '../parcels/widgets/add_parcel_sheet.dart';
import '../tasks/maintenance_screen.dart';
import '../tasks/widgets/add_task_sheet.dart';
import 'main_navigation_shell.dart';
import 'widgets/casama_household_drawer.dart';

/// Unified 3-tab Household Boards hub (`Parcels`, `Tasks`, `Items`)
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
  late final ScrollController _outerScrollController;
  late int _activeTab;
  ValueListenable<int>? _shellBoardListenable;
  CasamaWaveTabScope? _waveScope;
  double _heroHeaderHeight = 220.0;
  bool _showStickyBar = false;

  static const _tabs = [
    _BoardTabMeta(
      headerTitle: 'Parcels & Deliveries',
      headerSubtitle: 'Coordinate arrivals & COD',
      pillLabel: 'Parcels',
      pillIcon: Icons.inventory_2_outlined,
      fabLabel: 'Add parcel',
      fabIcon: Icons.add_box_outlined,
      mascotPose: CasPose.deliveries,
    ),
    _BoardTabMeta(
      headerTitle: 'Household Tasks',
      headerSubtitle: 'Repairs, chores & restocks',
      pillLabel: 'Tasks',
      pillIcon: Icons.checklist_rounded,
      fabLabel: 'Add task',
      fabIcon: Icons.add_task_rounded,
      mascotPose: CasPose.chores,
    ),
    _BoardTabMeta(
      headerTitle: 'Lost & Found',
      headerSubtitle: 'Missing & found items',
      pillLabel: 'Items',
      fabLabel: 'Report item',
      useLostFoundIcon: true,
      mascotPose: CasPose.lostFound,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab.clamp(0, 2);
    _pageController = PageController(initialPage: _activeTab);
    _outerScrollController = ScrollController();
    _outerScrollController.addListener(_handleScrollUpdate);
  }

  void _handleScrollUpdate() {
    if (!_outerScrollController.hasClients) return;
    final pos = _outerScrollController.position;
    final offset = pos.pixels;
    var waveOffset = offset;
    if (pos.hasContentDimensions &&
        pos.maxScrollExtent > 0 &&
        offset >= pos.maxScrollExtent - 0.5) {
      waveOffset += kBoardsCollapsedWaveExtra;
    }
    _waveScope?.reportScroll(waveOffset);
    final threshold = (_heroHeaderHeight - 48.0).clamp(0.0, double.infinity);
    final shouldShow = offset > threshold;
    if (shouldShow != _showStickyBar && mounted) {
      setState(() => _showStickyBar = shouldShow);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _waveScope = CasamaWaveTabScope.maybeOf(context);
    final scope = CasamaShellScope.maybeOf(context);
    final nextListenable = scope?.boardTabListenable;
    if (nextListenable != _shellBoardListenable) {
      _shellBoardListenable?.removeListener(_handleExternalBoardChange);
      _shellBoardListenable = nextListenable;
      _shellBoardListenable?.addListener(_handleExternalBoardChange);
      if (nextListenable != null && nextListenable.value != _activeTab) {
        _activeTab = nextListenable.value.clamp(0, 2);
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
    setState(() => _activeTab = target.clamp(0, 2));
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_activeTab);
    }
  }

  @override
  void dispose() {
    _outerScrollController.removeListener(_handleScrollUpdate);
    _outerScrollController.dispose();
    _shellBoardListenable?.removeListener(_handleExternalBoardChange);
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    final target = index.clamp(0, 2);
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
    final clamped = index.clamp(0, 2);
    if (_activeTab == clamped) return;
    setState(() => _activeTab = clamped);
    final scope = CasamaShellScope.maybeOf(context);
    if (scope != null && scope.boardTabListenable is ValueNotifier<int>) {
      (scope.boardTabListenable as ValueNotifier<int>).value = clamped;
    }
  }

  void _onContextualFabPressed() {
    switch (_activeTab) {
      case 0:
        showAddParcelSheet(context);
      case 1:
        showNewTaskSheet(context);
      case 2:
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
    final meta = _tabs[_activeTab.clamp(0, _tabs.length - 1)];
    final inShell = CasamaShellScope.maybeOf(context) != null;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;
    // When inside MainNavigationShell (extendBody: true), MediaQuery.paddingOf(context).bottom
    // already includes the docked bottom navigation bar height. Adding 84.0 on top of it
    // double-counts the nav bar and floats the FAB too high.
    final fabBottomOffset = inShell ? 12.0 + bottomInset : 20.0 + bottomInset;
    final bodyBottomPadding = inShell ? 80.0 + bottomInset : 104.0 + bottomInset;

    final inWaveShell = _waveScope != null;

    return Scaffold(
      backgroundColor: inWaveShell ? Colors.transparent : pal.scaffoldBg,
      body: CasamaAmbientCanvas(
        backgroundColor: inWaveShell ? Colors.transparent : null,
        child: Stack(
          children: [
            // Faint ambient board-icon watermark behind scrollable content
            _BoardsWatermarkIcon(
              activeTab: _activeTab,
              safeAreaTop: topInset,
            ),

            // Full-page smooth scroll: unpinned hero header + PageView body
            NestedScrollView(
              controller: _outerScrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: _MeasureSize(
                    onChange: (size) {
                      _waveScope?.reportHeaderHeight(size.height);
                      if (size.height > 0 &&
                          (_heroHeaderHeight - size.height).abs() > 0.5) {
                        setState(() {
                          _heroHeaderHeight = size.height;
                        });
                        _handleScrollUpdate();
                      }
                    },
                    child: CasamaWaveHeader(
                      title: meta.headerTitle,
                      subtitle: repo.hasActiveHousehold
                          ? '${repo.currentHousehold.name} • ${meta.headerSubtitle}'
                          : 'No household yet • ${meta.headerSubtitle}',
                      titleMascotPose: meta.mascotPose,
                      extendedWave: true,
                      compact: true,
                      showNotificationBell: true,
                      paintBackground: !inWaveShell,
                      onMenuTap: _openDrawer,
                      embeddedTabBar: _BoardsHeaderSwitcher(
                        tabs: _tabs,
                        activeIndex: _activeTab,
                        onSelected: _selectTab,
                      ),
                    ),
                  ),
                ),
              ],
              body: PageView(
                controller: _pageController,
                physics: const ClampingScrollPhysics(),
                onPageChanged: _onPageChanged,
                children: [
                  ParcelsBoardView(bottomPadding: bodyBottomPadding),
                  TasksBoardView(bottomPadding: bodyBottomPadding),
                  ItemsBoardView(bottomPadding: bodyBottomPadding),
                ],
              ),
            ),

            // Compact frosted sticky pill bar revealed after hero scrolls off-screen
            _BoardsStickyPillBar(
              visible: _showStickyBar,
              tabs: _tabs,
              activeIndex: _activeTab,
              onSelected: _selectTab,
            ),

            // Contextual Morphing Board FAB (320ms spring overshoot)
            Positioned(
              right: 16,
              bottom: fabBottomOffset,
              child: CasamaMorphingFab(
                visible: repo.hasActiveHousehold,
                icon: meta.useLostFoundIcon ? null : meta.fabIcon,
                iconWidget: meta.useLostFoundIcon
                    ? const CasamaLostFoundIcon(size: 20, color: Colors.white)
                    : null,
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
                      if (t.useLostFoundIcon)
                        CasamaLostFoundIcon(
                          size: 16,
                          color: selected
                              ? pal.forestTeal
                              : Colors.white.withValues(alpha: 0.85),
                        )
                      else
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
  final IconData? pillIcon;
  final String fabLabel;
  final IconData? fabIcon;
  final bool useLostFoundIcon;
  final CasPose mascotPose;

  const _BoardTabMeta({
    required this.headerTitle,
    required this.headerSubtitle,
    required this.pillLabel,
    this.pillIcon,
    required this.fabLabel,
    this.fabIcon,
    this.useLostFoundIcon = false,
    required this.mascotPose,
  });
}

class _BoardsStickyPillBar extends StatefulWidget {
  final bool visible;
  final List<_BoardTabMeta> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelected;

  const _BoardsStickyPillBar({
    required this.visible,
    required this.tabs,
    required this.activeIndex,
    required this.onSelected,
  });

  @override
  State<_BoardsStickyPillBar> createState() => _BoardsStickyPillBarState();
}

class _BoardsStickyPillBarState extends State<_BoardsStickyPillBar> {
  late bool _offstage;

  @override
  void initState() {
    super.initState();
    _offstage = !widget.visible;
  }

  @override
  void didUpdateWidget(covariant _BoardsStickyPillBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && _offstage) {
      _offstage = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final topPad = MediaQuery.paddingOf(context).top;
    final reduced = CasamaMotion.reduceMotion(context);
    final dur = reduced ? Duration.zero : const Duration(milliseconds: 250);
    final effectiveOffstage = reduced ? !widget.visible : _offstage;

    return Positioned(
      key: const Key('boards_sticky_pill_bar'),
      top: 0,
      left: 0,
      right: 0,
      child: Offstage(
        offstage: effectiveOffstage,
        child: IgnorePointer(
          ignoring: !widget.visible,
          child: AnimatedSlide(
            offset: widget.visible ? Offset.zero : const Offset(0, -1),
            duration: dur,
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: widget.visible ? 1.0 : 0.0,
              duration: dur,
              curve: Curves.easeOut,
              onEnd: () {
                if (!widget.visible && !_offstage && mounted) {
                  setState(() => _offstage = true);
                }
              },
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: pal.headerDeep.withValues(alpha: 0.94),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F000000),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 10),
                    child: _BoardsHeaderSwitcher(
                      tabs: widget.tabs,
                      activeIndex: widget.activeIndex,
                      onSelected: widget.onSelected,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardsWatermarkIcon extends StatelessWidget {
  final int activeTab;
  final double safeAreaTop;

  const _BoardsWatermarkIcon({
    required this.activeTab,
    required this.safeAreaTop,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final reduced = CasamaMotion.reduceMotion(context);
    final color = context.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : pal.headerDeep.withValues(alpha: 0.05);

    final Widget icon = switch (activeTab) {
      0 => Icon(Icons.inventory_2_outlined, size: 148, color: color),
      1 => Icon(Icons.checklist_rounded, size: 148, color: color),
      _ => CasamaLostFoundIcon(size: 148, color: color),
    };

    return Positioned(
      key: const Key('boards_watermark_icon'),
      top: 110 + safeAreaTop,
      right: -18,
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 250),
          child: KeyedSubtree(
            key: ValueKey('watermark_$activeTab'),
            child: icon,
          ),
        ),
      ),
    );
  }
}

class _MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onChange;

  const _MeasureSize({required this.child, required this.onChange});

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  void _notify() {
    final ctx = _key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      widget.onChange(box.size);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: KeyedSubtree(key: _key, child: widget.child),
      ),
    );
  }
}
