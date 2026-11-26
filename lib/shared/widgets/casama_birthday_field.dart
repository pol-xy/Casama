import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';

/// Returns the number of calendar days in [month] of [year] (defaults to 31
/// when [month] is unset, or leap-year 2000 when [year] is unset).
int daysInBirthMonth(int? year, int? month) {
  if (month == null) return 31;
  return DateTime(year ?? 2000, month + 1, 0).day;
}

/// Shared Birthday selector (`Month`, `Day`, `Year` dropdowns + calendar picker
/// button + live `Age: <N>` badge) used by both Onboarding and Edit Profile.
class CasamaBirthdayField extends StatelessWidget {
  final String label;
  final int? month;
  final int? day;
  final int? year;
  final int? computedAge;
  final String? errorText;
  final ValueChanged<int?> onMonthChanged;
  final ValueChanged<int?> onDayChanged;
  final ValueChanged<int?> onYearChanged;
  final VoidCallback onPickCalendar;

  const CasamaBirthdayField({
    super.key,
    this.label = 'Birthday',
    required this.month,
    required this.day,
    required this.year,
    required this.computedAge,
    this.errorText,
    required this.onMonthChanged,
    required this.onDayChanged,
    required this.onYearChanged,
    required this.onPickCalendar,
  });

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final maxDays = daysInBirthMonth(year, month);
    final safeDay = day != null && day! <= maxDays ? day : null;
    final currentYear = DateTime.now().year;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: pal.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (computedAge != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: pal.softSage,
                  borderRadius: CasamaSpacing.roundedPill,
                ),
                child: Text(
                  'Age: $computedAge',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: pal.forestTeal,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Select your birth month, day, and year',
          style: theme.textTheme.bodySmall?.copyWith(
            color: pal.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Month Dropdown
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: pal.track,
                  borderRadius: CasamaSpacing.roundedSm,
                  border: Border.all(
                    color: errorText != null ? pal.dangerFg : pal.border,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: month,
                    hint: Text(
                      'Month',
                      style: TextStyle(
                        color: pal.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    isExpanded: true,
                    dropdownColor: pal.surface,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: pal.textSecondary,
                    ),
                    items: List.generate(12, (i) {
                      final monthNum = i + 1;
                      return DropdownMenuItem<int>(
                        value: monthNum,
                        child: Text(
                          _monthNames[i],
                          style: TextStyle(
                            color: pal.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }),
                    onChanged: onMonthChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Day Dropdown
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: pal.track,
                  borderRadius: CasamaSpacing.roundedSm,
                  border: Border.all(
                    color: errorText != null ? pal.dangerFg : pal.border,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: safeDay,
                    hint: Text(
                      'Day',
                      style: TextStyle(
                        color: pal.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    isExpanded: true,
                    dropdownColor: pal.surface,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: pal.textSecondary,
                    ),
                    items: List.generate(maxDays, (i) {
                      final dayNum = i + 1;
                      return DropdownMenuItem<int>(
                        value: dayNum,
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            color: pal.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }),
                    onChanged: onDayChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Year Dropdown
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: pal.track,
                  borderRadius: CasamaSpacing.roundedSm,
                  border: Border.all(
                    color: errorText != null ? pal.dangerFg : pal.border,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: year,
                    hint: Text(
                      'Year',
                      style: TextStyle(
                        color: pal.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    isExpanded: true,
                    dropdownColor: pal.surface,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: pal.textSecondary,
                    ),
                    items: List.generate(
                      currentYear - 1920 + 1,
                      (i) {
                        final yr = currentYear - i;
                        return DropdownMenuItem<int>(
                          value: yr,
                          child: Text(
                            '$yr',
                            style: TextStyle(
                              color: pal.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        );
                      },
                    ),
                    onChanged: onYearChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              constraints: const BoxConstraints(
                minWidth: CasamaSpacing.minTouchTarget,
                minHeight: CasamaSpacing.minTouchTarget,
              ),
              icon: Icon(
                Icons.calendar_month_outlined,
                color: pal.forestTeal,
                size: 22,
              ),
              tooltip: 'Pick date from calendar',
              onPressed: onPickCalendar,
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: pal.dangerFg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
