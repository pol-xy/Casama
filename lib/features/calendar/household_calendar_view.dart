import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../data/casama_repository.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';

class HouseholdCalendarView extends ConsumerStatefulWidget {
  const HouseholdCalendarView({super.key});

  @override
  ConsumerState<HouseholdCalendarView> createState() =>
      _HouseholdCalendarViewState();
}

class _HouseholdCalendarViewState extends ConsumerState<HouseholdCalendarView> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;
  String _selectedFilter = 'All'; // 'All', 'Parcels', 'Tasks', 'Meetups'
  bool _isMonthExpanded = true;

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
    final repo = ref.watch(repositoryProvider);
    final events = _getEventsForDate(repo, _selectedDate);
    final filteredEvents = events.where((e) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Parcels' && e.type == _CalendarEventType.parcel) {
        return true;
      }
      if (_selectedFilter == 'Tasks' && e.type == _CalendarEventType.task) {
        return true;
      }
      if (_selectedFilter == 'Meetups' && e.type == _CalendarEventType.meetup) {
        return true;
      }
      return false;
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CasamaSpacing.md),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: CasamaSpacing.roundedXl,
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header with Month Navigation (< >)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.isDark
                          ? CasamaColors.darkTileParcels
                          : CasamaColors.tileParcels,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: CasamaColors.primaryCoral,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_getMonthName(_focusedMonth.month)} ${_focusedMonth.year}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.textColor,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Jump to Today button
                  TextButton(
                    onPressed: _goToToday,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: CasamaColors.primaryCoral,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Month Navigator Arrow Left
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      size: 22,
                      color: context.textColor,
                    ),
                    onPressed: _previousMonth,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  // Month Navigator Arrow Right
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: context.textColor,
                    ),
                    onPressed: _nextMonth,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  // Toggle View Icon (Month Grid vs Compact Week)
                  IconButton(
                    icon: Icon(
                      _isMonthExpanded
                          ? Icons.view_week_outlined
                          : Icons.calendar_view_month_outlined,
                      size: 20,
                      color: context.textSecondaryColor,
                    ),
                    onPressed: () =>
                        setState(() => _isMonthExpanded = !_isMonthExpanded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: CasamaSpacing.sm),

          // Days of the Week Headers (Mon .. Sun)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((
                day,
              ) {
                return SizedBox(
                  width: 36,
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.textMutedColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 2),

          // Calendar Grid (Month or Week)
          if (_isMonthExpanded)
            _buildMonthGrid(repo)
          else
            _buildWeekStrip(repo),

          const SizedBox(height: CasamaSpacing.md),
          Divider(height: 1, color: context.borderColor),
          const SizedBox(height: CasamaSpacing.sm),

          // Filter Chips & Selected Date Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.event_note_rounded,
                    size: 16,
                    color: CasamaColors.primaryCoral,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isSameDay(_selectedDate, DateTime.now())
                        ? "Today's Schedule"
                        : '${_getMonthName(_selectedDate.month).substring(0, 3)} ${_selectedDate.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: context.textColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.isDark
                      ? CasamaColors.darkSurface
                      : CasamaColors.softNeutral,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${filteredEvents.length} ${filteredEvents.length == 1 ? "activity" : "activities"}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Horizontally scrollable Category filter pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Parcels', 'Tasks', 'Meetups'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (context.isDark
                                  ? CasamaColors.primaryCoral
                                  : CasamaColors.midnightNavy)
                            : (context.isDark
                                  ? context.surfaceColor
                                  : CasamaColors.softNeutral),
                        borderRadius: BorderRadius.circular(14),
                        border: isSelected
                            ? null
                            : Border.all(color: context.borderColor),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : context.textSecondaryColor,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: CasamaSpacing.sm),

          // Events List on Selected Date
          if (filteredEvents.isEmpty)
            _buildEmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredEvents.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final event = filteredEvents[index];
                return _buildEventTile(event);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(CasamaRepository repo) {
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

    // Weekday of 1st day (1 = Mon .. 7 = Sun)
    final startingWeekday = firstDayOfMonth.weekday;
    final leadingDays = startingWeekday - 1; // Days from previous month

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
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        DateTime day;
        bool isCurrentMonth = true;

        if (index < leadingDays) {
          // Day in previous month
          final prevDay = prevMonthLastDay - leadingDays + index + 1;
          day = DateTime(_focusedMonth.year, _focusedMonth.month - 1, prevDay);
          isCurrentMonth = false;
        } else if (index >= leadingDays + daysInMonth) {
          // Day in next month
          final nextDay = index - (leadingDays + daysInMonth) + 1;
          day = DateTime(_focusedMonth.year, _focusedMonth.month + 1, nextDay);
          isCurrentMonth = false;
        } else {
          // Day in current month
          final monthDay = index - leadingDays + 1;
          day = DateTime(_focusedMonth.year, _focusedMonth.month, monthDay);
        }

        return _buildDayCell(repo, day, isCurrentMonth);
      },
    );
  }

  Widget _buildWeekStrip(CasamaRepository repo) {
    // 7 days centered on selected date
    final weekDays = List.generate(7, (i) {
      return DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day - 3 + i,
      );
    });

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekDays.map((day) {
        return _buildDayCell(repo, day, day.month == _focusedMonth.month);
      }).toList(),
    );
  }

  Widget _buildDayCell(CasamaRepository repo, DateTime day, bool isCurrentMonth) {
    final isSelected = _isSameDay(day, _selectedDate);
    final isToday = _isSameDay(day, DateTime.now());
    final hasEvents = _hasEventsOnDate(repo, day);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = day;
          if (day.month != _focusedMonth.month) {
            _focusedMonth = DateTime(day.year, day.month, 1);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? CasamaColors.primaryCoral
              : (isToday
                    ? (context.isDark
                          ? CasamaColors.darkTileParcels
                          : CasamaColors.tileParcels)
                    : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          border: isToday && !isSelected
              ? Border.all(color: CasamaColors.primaryCoral, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected || isToday
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (!isCurrentMonth
                          ? context.textMutedColor.withValues(alpha: 0.4)
                          : context.textColor),
              ),
            ),
            const SizedBox(height: 2),
            // Event dot indicator
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: hasEvents
                    ? (isSelected ? Colors.white : CasamaColors.primaryCoral)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTile(_CalendarEventItem event) {
    Color iconBg;
    Color iconColor;
    IconData icon;
    String badgeText;
    VoidCallback onTap;

    switch (event.type) {
      case _CalendarEventType.parcel:
        iconBg = context.isDark
            ? CasamaColors.darkTileParcels
            : CasamaColors.tileParcels;
        iconColor = CasamaColors.primaryCoral;
        icon = Icons.local_shipping_outlined;
        badgeText = 'Parcel';
        onTap = () => context.push('/parcels');
        break;
      case _CalendarEventType.task:
        iconBg = context.isDark
            ? CasamaColors.darkTileMaintenance
            : CasamaColors.tileMaintenance;
        iconColor = const Color(0xFF1E88E5);
        icon = Icons.checklist_rounded;
        badgeText = 'Task';
        onTap = () => context.push('/maintenance');
        break;
      case _CalendarEventType.meetup:
        iconBg = context.isDark
            ? CasamaColors.darkTileChat
            : CasamaColors.tileChat;
        iconColor = CasamaColors.deepTeal;
        icon = Icons.people_outline_rounded;
        badgeText = 'Meet-up';
        onTap = () => context.push('/group-chat');
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.isDark
              ? context.surfaceColor
              : CasamaColors.softNeutral,
          borderRadius: CasamaSpacing.roundedMd,
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 18),
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
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: iconColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        event.timeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    event.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: context.textMutedColor),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: context.isDark
            ? context.surfaceColor
            : CasamaColors.softNeutral.withValues(alpha: 0.6),
        borderRadius: CasamaSpacing.roundedMd,
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 32,
            color: context.textMutedColor.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 6),
          Text(
            'No activities scheduled for this date',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Enjoy the peaceful day with your housemates!',
            style: TextStyle(fontSize: 11, color: context.textMutedColor),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _hasEventsOnDate(CasamaRepository repo, DateTime date) {
    return _getEventsForDate(repo, date).isNotEmpty;
  }

  List<_CalendarEventItem> _getEventsForDate(
    CasamaRepository repo,
    DateTime date,
  ) {
    final List<_CalendarEventItem> list = [];

    // 1. Parcels expected on this date
    for (final p in repo.parcels) {
      if (_isSameDay(p.expectedArrival, date)) {
        list.add(
          _CalendarEventItem(
            title: '${p.buyerName}\'s ${p.courier} Package',
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

    // 2. Meet-up invitations scheduled on this date
    final m = repo.activeMeetUp;
    if (_isSameDay(m.scheduledTime, date)) {
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

    // 3. Maintenance tasks due on this date
    for (final t in repo.tasks) {
      final taskDate = t.dueDate ?? t.createdAt;
      if (_isSameDay(taskDate, date)) {
        list.add(
          _CalendarEventItem(
            title: t.title,
            subtitle:
                'Assigned: ${t.assigneeName ?? "Unassigned"} • Urgency: ${t.urgency.label}',
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

enum _CalendarEventType { parcel, task, meetup }

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
