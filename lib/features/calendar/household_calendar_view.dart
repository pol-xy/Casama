import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../data/casama_repository.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/casama_filter_controls.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../dashboard/main_navigation_shell.dart';

class HouseholdCalendarView extends ConsumerStatefulWidget {
  const HouseholdCalendarView({super.key});

  @override
  ConsumerState<HouseholdCalendarView> createState() =>
      _HouseholdCalendarViewState();
}

class _HouseholdCalendarViewState extends ConsumerState<HouseholdCalendarView> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;
  String _selectedFilter = 'All';
  bool _isMonthExpanded = false;

  static const List<CasamaFilterOption<String>> _filterOptions = [
    CasamaFilterOption(value: 'All', label: 'All'),
    CasamaFilterOption(value: 'Parcels', label: 'Parcels'),
    CasamaFilterOption(value: 'Tasks', label: 'Tasks'),
    CasamaFilterOption(value: 'Bills', label: 'Bills'),
    CasamaFilterOption(value: 'Meetups', label: 'Meetups'),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final events = _getEventsForDate(repo, _selectedDate);
    final filteredEvents = events.where((e) {
      return switch (_selectedFilter) {
        'All' => true,
        'Parcels' => e.type == _CalendarEventType.parcel,
        'Tasks' => e.type == _CalendarEventType.task,
        'Bills' => e.type == _CalendarEventType.bill,
        'Meetups' => e.type == _CalendarEventType.meetup,
        _ => true,
      };
    }).toList();

    return CasamaCard(
      padding: const EdgeInsets.all(CasamaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Live Dot + Casa Schedule + Month Controls
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: pal.successFg,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Casa Schedule',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: pal.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${_getMonthName(_focusedMonth.month)} ${_focusedMonth.year}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pal.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Jump calendar to today',
                child: TextButton(
                  onPressed: _goToToday,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    foregroundColor: pal.primaryCoral,
                  ),
                  child: const Text(
                    'Today',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Previous month',
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: pal.textPrimary,
                ),
                onPressed: _previousMonth,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                tooltip: 'Next month',
                icon: Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: pal.textPrimary,
                ),
                onPressed: _nextMonth,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                tooltip: _isMonthExpanded
                    ? 'Switch to compact week strip'
                    : 'Expand full month calendar',
                icon: Icon(
                  _isMonthExpanded
                      ? Icons.view_week_outlined
                      : Icons.calendar_view_month_outlined,
                  size: 20,
                  color: pal.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _isMonthExpanded = !_isMonthExpanded),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
                padding: EdgeInsets.zero,
              ),
            ],
          ),

          const SizedBox(height: CasamaSpacing.xs),

          // Days of the week headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map(
                  (day) => Expanded(
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),

          // Compact Week Strip or Expanded Month Grid
          if (_isMonthExpanded)
            _buildMonthGrid(context, repo)
          else
            _buildWeekStrip(context, repo),

          const SizedBox(height: CasamaSpacing.md),
          Divider(height: 1, color: pal.border),
          const SizedBox(height: CasamaSpacing.sm),

          // Selected Date Schedule Sub-header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.event_note_rounded,
                    size: 16,
                    color: pal.primaryCoral,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isSameDay(_selectedDate, DateTime.now())
                        ? "Today's Schedule"
                        : '${_getMonthName(_selectedDate.month).substring(0, 3)} ${_selectedDate.day}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: pal.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: pal.track,
                  borderRadius: CasamaSpacing.roundedPill,
                ),
                child: Text(
                  '${filteredEvents.length} ${filteredEvents.length == 1 ? 'activity' : 'activities'}',
                  style: theme.textTheme.labelSmall?.tabular.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: pal.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CasamaSpacing.xs),

          // Unified Pill Filter Rail (All, Parcels, Tasks, Bills, Meetups)
          CasamaPillFilterRail<String>(
            padding: EdgeInsets.zero,
            options: _filterOptions,
            selectedValue: _selectedFilter,
            onSelected: (val) => setState(() => _selectedFilter = val),
          ),
          const SizedBox(height: CasamaSpacing.xs),

          // Events List
          if (filteredEvents.isEmpty)
            _buildEmptyState(context, pal, theme)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredEvents.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _buildEventTile(context, filteredEvents[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(BuildContext context, CasamaRepository repo) {
    final firstDayOfMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
      1,
    );
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    final startingWeekday = firstDayOfMonth.weekday;
    final leadingDays = startingWeekday - 1;
    final prevMonthLastDay = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
      0,
    ).day;
    final totalSlots = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalSlots,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        final DateTime day;
        final bool isCurrentMonth;

        if (index < leadingDays) {
          final prevDay = prevMonthLastDay - leadingDays + index + 1;
          day = DateTime(_focusedMonth.year, _focusedMonth.month - 1, prevDay);
          isCurrentMonth = false;
        } else if (index >= leadingDays + daysInMonth) {
          final nextDay = index - (leadingDays + daysInMonth) + 1;
          day = DateTime(_focusedMonth.year, _focusedMonth.month + 1, nextDay);
          isCurrentMonth = false;
        } else {
          final monthDay = index - leadingDays + 1;
          day = DateTime(_focusedMonth.year, _focusedMonth.month, monthDay);
          isCurrentMonth = true;
        }

        return _buildDayCell(context, repo, day, isCurrentMonth);
      },
    );
  }

  Widget _buildWeekStrip(BuildContext context, CasamaRepository repo) {
    final weekDays = List.generate(7, (i) {
      return DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day - 3 + i,
      );
    });

    return Row(
      children: weekDays
          .map(
            (day) => Expanded(
              child: _buildDayCell(
                context,
                repo,
                day,
                day.month == _focusedMonth.month,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    CasamaRepository repo,
    DateTime day,
    bool isCurrentMonth,
  ) {
    final pal = context.palette;
    final reduced = CasamaMotion.reduceMotion(context);
    final isSelected = _isSameDay(day, _selectedDate);
    final isToday = _isSameDay(day, DateTime.now());
    final hasEvents = _hasEventsOnDate(repo, day);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${_getMonthName(day.month)} ${day.day}',
      child: CasamaPressable(
        onTap: () {
          setState(() {
            _selectedDate = day;
            if (day.month != _focusedMonth.month) {
              _focusedMonth = DateTime(day.year, day.month, 1);
            }
          });
        },
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : CasamaMotion.press,
          curve: CasamaMotion.easeOut,
          constraints: const BoxConstraints(minHeight: 48),
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? pal.forestTeal
                : (isToday ? pal.softBlush : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: isToday && !isSelected
                ? Border.all(color: pal.primaryCoral, width: 1.4)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${day.day}',
                style: Theme.of(context).textTheme.labelMedium?.tabular.copyWith(
                  fontSize: 13,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (!isCurrentMonth
                            ? pal.textMuted.withValues(alpha: 0.45)
                            : pal.textPrimary),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: hasEvents
                      ? (isSelected ? Colors.white : pal.primaryCoral)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventTile(BuildContext context, _CalendarEventItem event) {
    final pal = context.palette;
    final theme = Theme.of(context);

    final Color iconBg;
    final Color iconColor;
    final IconData icon;
    final String badgeText;
    final VoidCallback onTap;

    switch (event.type) {
      case _CalendarEventType.parcel:
        iconBg = pal.softBlush;
        iconColor = pal.primaryCoral;
        icon = Icons.local_shipping_outlined;
        badgeText = 'Parcel';
        onTap = () => _navigateBoardOrRoute(context, 0, '/parcels');
      case _CalendarEventType.task:
        iconBg = pal.softSage;
        iconColor = pal.forestTeal;
        icon = Icons.checklist_rounded;
        badgeText = 'Task';
        onTap = () => _navigateBoardOrRoute(context, 1, '/maintenance');
      case _CalendarEventType.bill:
        iconBg = pal.amberBg;
        iconColor = pal.amberFg;
        icon = Icons.receipt_long_outlined;
        badgeText = 'Bill';
        onTap = () => _navigateBoardOrRoute(context, 2, '/bills');
      case _CalendarEventType.meetup:
        iconBg = pal.infoBg;
        iconColor = pal.infoFg;
        icon = Icons.people_outline_rounded;
        badgeText = 'Meet-up';
        onTap = () {
          if (GoRouter.maybeOf(context) != null) {
            context.push('/group-chat');
          } else {
            CasamaShellScope.maybeOf(context)?.selectTab(3);
          }
        };
    }

    return Semantics(
      button: true,
      label: '$badgeText: ${event.title}, ${event.subtitle}',
      child: CasamaPressable.card(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: CasamaSpacing.roundedLg,
            border: Border.all(color: pal.border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: CasamaSpacing.roundedPill,
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: iconColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          event.timeLabel,
                          style: theme.textTheme.labelSmall?.tabular.copyWith(
                            fontSize: 11,
                            color: pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    Text(
                      event.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: pal.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateBoardOrRoute(
    BuildContext context,
    int boardIndex,
    String routePath,
  ) {
    final shell = CasamaShellScope.maybeOf(context);
    if (shell != null) {
      shell.openBoardTab(boardIndex);
      return;
    }
    if (GoRouter.maybeOf(context) != null) {
      context.push(routePath);
    }
  }

  Widget _buildEmptyState(
    BuildContext context,
    CasamaPalette pal,
    ThemeData theme,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: CasamaSpacing.roundedLg,
        border: Border.all(color: pal.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 28,
            color: pal.textMuted.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 6),
          Text(
            'No activities scheduled for this date',
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: pal.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Enjoy the calm day with your housemates.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: pal.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  bool _hasEventsOnDate(CasamaRepository repo, DateTime date) =>
      _getEventsForDate(repo, date).isNotEmpty;

  List<_CalendarEventItem> _getEventsForDate(
    CasamaRepository repo,
    DateTime date,
  ) {
    final list = <_CalendarEventItem>[];

    for (final p in repo.parcels) {
      if (_isSameDay(p.expectedArrival, date)) {
        list.add(
          _CalendarEventItem(
            title: "${p.buyerName}'s ${p.courier} Package",
            subtitle:
                p.paymentType == ParcelPaymentType.cod && p.codAmount != null
                ? 'COD: ₱${p.codAmount!.toStringAsFixed(2)} • ${p.status.label}'
                : 'Prepaid delivery • Status: ${p.status.label}',
            timeLabel: '4:00 PM',
            type: _CalendarEventType.parcel,
          ),
        );
      }
    }

    for (final b in repo.bills) {
      if (_isSameDay(b.deadline, date)) {
        final statusLabel = b.effectiveStatus == BillStatus.paid
            ? 'Paid'
            : (b.effectiveStatus == BillStatus.overdue ? 'Overdue' : 'Due');
        list.add(
          _CalendarEventItem(
            title: '${b.effectiveBillName} ($statusLabel)',
            subtitle: b.amount != null
                ? '₱${b.amount!.toStringAsFixed(2)} • ${b.responsibleMember ?? b.creatorName}'
                : 'Assigned to ${b.responsibleMember ?? b.creatorName}',
            timeLabel: statusLabel,
            type: _CalendarEventType.bill,
          ),
        );
      }
    }

    final m = repo.activeMeetUp;
    if (m.hasValidData && m.isActive && _isSameDay(m.scheduledTime, date)) {
      list.add(
        _CalendarEventItem(
          title: m.activity,
          subtitle: '${m.location} • ${m.goingCount} housemates going',
          timeLabel:
              '${m.scheduledTime.hour}:${m.scheduledTime.minute.toString().padLeft(2, '0')}',
          type: _CalendarEventType.meetup,
        ),
      );
    }

    for (final t in repo.tasks) {
      final taskDate = t.dueDate ?? t.createdAt;
      if (_isSameDay(taskDate, date)) {
        list.add(
          _CalendarEventItem(
            title: t.title,
            subtitle:
                '${t.category.label} • By ${t.createdByName} • ${t.urgency.label}',
            timeLabel: t.status == TaskStatus.done ? 'Completed' : 'Due Today',
            type: _CalendarEventType.task,
          ),
        );
      }
    }

    return list;
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}

enum _CalendarEventType { parcel, task, bill, meetup }

class _CalendarEventItem {
  final String title;
  final String subtitle;
  final String timeLabel;
  final _CalendarEventType type;

  const _CalendarEventItem({
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.type,
  });
}
