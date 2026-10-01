import 'package:flutter/material.dart';

DateTime fitnessPlanEndDate(DateTime startDate, String planType) {
  final start = DateUtils.dateOnly(startDate);
  final months = switch (planType.trim().toLowerCase()) {
    'monthly' || 'month' => 1,
    'yearly' || 'annual' || 'annually' || 'year' => 12,
    _ => 0,
  };
  if (months == 0) return start;

  final targetMonth = DateTime(start.year, start.month + months, 1);
  final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
  return DateTime(
    targetMonth.year,
    targetMonth.month,
    start.day.clamp(1, lastDay),
  );
}

String fitnessPlanDurationLabel(String planType) =>
    switch (planType.trim().toLowerCase()) {
      'monthly' || 'month' => '1 month',
      'yearly' || 'annual' || 'annually' || 'year' => '1 year',
      'session' || '' => '1 session',
      _ => planType,
    };

DateTime? fitnessBookingEndDate(Map<String, dynamic> booking) {
  final start = DateTime.tryParse('${booking['date'] ?? ''}');
  if (start == null) return null;
  return fitnessPlanEndDate(start, '${booking['fitnessPlanType'] ?? ''}');
}

bool isFitnessBookingActive(Map<String, dynamic> booking, {DateTime? onDate}) {
  final end = fitnessBookingEndDate(booking);
  return end != null &&
      !end.isBefore(DateUtils.dateOnly(onDate ?? DateTime.now()));
}

bool fitnessVenueClosesSunday(String hours) => RegExp(
  r'\bsundays?\b[^.\n]*(?:closed|close|off)\b',
  caseSensitive: false,
).hasMatch(hours);

Set<int>? fitnessAvailableWeekdays(String availability) {
  final normalized = availability.trim().toLowerCase();
  if (normalized.isEmpty || normalized == 'any') return null;
  const weekdayNumbers = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };
  const abbreviations = {
    'mon': DateTime.monday,
    'tue': DateTime.tuesday,
    'tues': DateTime.tuesday,
    'wed': DateTime.wednesday,
    'thu': DateTime.thursday,
    'thur': DateTime.thursday,
    'thurs': DateTime.thursday,
    'fri': DateTime.friday,
    'sat': DateTime.saturday,
    'sun': DateTime.sunday,
  };
  final days = normalized
      .split(RegExp(r'[,;]'))
      .map((day) => day.trim())
      .map((day) => weekdayNumbers[day] ?? abbreviations[day])
      .whereType<int>()
      .toSet();
  return days.isEmpty ? null : days;
}

String fitnessDateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class FitnessBookingCalendar extends StatefulWidget {
  const FitnessBookingCalendar({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.hours,
    this.availability = '',
    this.attendance = const {},
    this.onAttendanceChanged,
  });

  final DateTime startDate;
  final DateTime endDate;
  final String hours;
  final String availability;
  final Map<String, String> attendance;
  final Future<void> Function(DateTime date, String? status)?
  onAttendanceChanged;

  @override
  State<FitnessBookingCalendar> createState() => _FitnessBookingCalendarState();
}

class _FitnessBookingCalendarState extends State<FitnessBookingCalendar> {
  late DateTime _visibleMonth;
  DateTime? _selectedDate;
  final Map<String, String> _attendance = {};
  bool _savingAttendance = false;

  static const _weekdayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    final start = DateUtils.dateOnly(widget.startDate);
    final end = DateUtils.dateOnly(widget.endDate);
    final initialDate = !today.isBefore(start) && !today.isAfter(end)
        ? today
        : start;
    _visibleMonth = DateTime(initialDate.year, initialDate.month);
    _selectedDate = initialDate;
    _attendance.addAll(widget.attendance);
  }

  @override
  void didUpdateWidget(covariant FitnessBookingCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attendance != widget.attendance) {
      _attendance
        ..clear()
        ..addAll(widget.attendance);
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final dayCount = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final leadingDays = firstDay.weekday - DateTime.monday;
    final cellCount = ((leadingDays + dayCount + 6) ~/ 7) * 7;
    final closesSunday = fitnessVenueClosesSunday(widget.hours);
    final availableWeekdays = fitnessAvailableWeekdays(widget.availability);
    final sundayUnavailable =
        closesSunday ||
        (availableWeekdays != null &&
            !availableWeekdays.contains(DateTime.sunday));
    final today = DateUtils.dateOnly(DateTime.now());
    final presentCount = _attendance.values
        .where((status) => status == 'present')
        .length;
    final absentCount = _attendance.values
        .where((status) => status == 'absent')
        .length;
    final unrecordedCount = _unrecordedPastDays(today, closesSunday);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('fitness-calendar-previous-month'),
              tooltip: 'Previous month',
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                _monthTitle(_visibleMonth),
                key: const ValueKey('fitness-calendar-visible-month'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF192B50),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('fitness-calendar-next-month'),
              tooltip: 'Next month',
              onPressed: () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        Row(
          children: [
            for (final weekday in _weekdayNames)
              Expanded(
                child: Center(
                  child: Text(
                    weekday,
                    style: TextStyle(
                      color: sundayUnavailable && weekday == 'Sun'
                          ? const Color(0xFF8993A2)
                          : const Color(0xFF68748A),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          key: const ValueKey('fitness-booking-calendar-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cellCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - leadingDays + 1;
            if (dayNumber < 1 || dayNumber > dayCount) {
              return const SizedBox.shrink();
            }

            final date = DateTime(
              _visibleMonth.year,
              _visibleMonth.month,
              dayNumber,
            );
            final isInPlan =
                !date.isBefore(DateUtils.dateOnly(widget.startDate)) &&
                !date.isAfter(DateUtils.dateOnly(widget.endDate));
            final isUnavailable =
                isInPlan &&
                ((availableWeekdays != null &&
                        !availableWeekdays.contains(date.weekday)) ||
                    (closesSunday && date.weekday == DateTime.sunday));
            final isPassed = isInPlan && date.isBefore(today);
            final isActive = isInPlan && !isPassed && !isUnavailable;
            final status = _attendance[fitnessDateKey(date)];
            final isStartDate = date == DateUtils.dateOnly(widget.startDate);
            final isEndDate = date == DateUtils.dateOnly(widget.endDate);
            final isSelected = date == _selectedDate;
            final highlightColor = status == 'present'
                ? const Color(0xFF21865A)
                : status == 'absent'
                ? const Color(0xFFD94A4A)
                : isStartDate
                ? const Color(0xFF22845A)
                : isEndDate
                ? const Color(0xFF8A55B8)
                : isActive
                ? const Color(0xFFFF8200)
                : const Color(0xFF263247);
            final foreground = isPassed || isUnavailable
                ? const Color(0xFF8993A2)
                : highlightColor;
            final borderColor = status != null
                ? highlightColor
                : isSelected
                ? const Color(0xFF192B50)
                : isInPlan && (isActive || isStartDate || isEndDate)
                ? highlightColor
                : Colors.transparent;
            final dayKey =
                'fitness-calendar-day-${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

            return Tooltip(
              message: _dayDescription(
                date,
                isInPlan: isInPlan,
                isPassed: isPassed,
                isSundayClosed: isUnavailable,
                status: status,
                isStartDate: isStartDate,
                isEndDate: isEndDate,
              ),
              child: GestureDetector(
                onTap: isInPlan && !isUnavailable
                    ? () => setState(() => _selectedDate = date)
                    : null,
                child: Container(
                  key: ValueKey(dayKey),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: borderColor,
                      width: isSelected ? 2 : 1.4,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              color: foreground,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              decoration: isPassed && status == null
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          if (status != null)
                            Text(
                              status == 'present' ? 'P' : 'A',
                              style: TextStyle(
                                color: highlightColor,
                                fontSize: 8,
                                height: 1,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          else if (isUnavailable)
                            const Text(
                              'Closed',
                              style: TextStyle(
                                color: Color(0xFF68748A),
                                fontSize: 7,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      if (isStartDate || isEndDate)
                        Positioned(
                          top: 2,
                          child: Text(
                            isStartDate && isEndDate
                                ? 'START/END'
                                : isStartDate
                                ? 'START'
                                : 'END',
                            style: TextStyle(
                              color: status != null
                                  ? highlightColor
                                  : (isStartDate
                                        ? const Color(0xFF17613F)
                                        : const Color(0xFF74419D)),
                              fontSize: 5.5,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        if (widget.onAttendanceChanged != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _attendanceCount(
                'Present',
                presentCount,
                const Color(0xFF21865A),
              ),
              _attendanceCount('Absent', absentCount, const Color(0xFFD94A4A)),
              _attendanceCount(
                'Not recorded',
                unrecordedCount,
                const Color(0xFF8993A2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _attendanceEditor(today, closesSunday),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _legend(const Color(0xFFFF8200), 'Active'),
            _legend(const Color(0xFFE8EBF0), 'Passed'),
            if (widget.onAttendanceChanged != null) ...[
              _legend(const Color(0xFF21865A), 'Present'),
              _legend(const Color(0xFFD94A4A), 'Absent'),
            ],
            _legend(const Color(0xFF22845A), 'Start'),
            _legend(const Color(0xFF8A55B8), 'End'),
            if (closesSunday)
              _legend(const Color(0xFFE8EBF0), 'Sunday · Closed')
            else if (availableWeekdays != null)
              _legend(const Color(0xFFE8EBF0), 'Venue closed'),
          ],
        ),
      ],
    );
  }

  int _unrecordedPastDays(DateTime today, bool closesSunday) {
    final start = DateUtils.dateOnly(widget.startDate);
    final bookingEnd = DateUtils.dateOnly(widget.endDate);
    final lastDay = bookingEnd.isBefore(today) ? bookingEnd : today;
    final availableWeekdays = fitnessAvailableWeekdays(widget.availability);
    var count = 0;
    for (
      var date = start;
      !date.isAfter(lastDay);
      date = date.add(const Duration(days: 1))
    ) {
      if ((availableWeekdays != null &&
              !availableWeekdays.contains(date.weekday)) ||
          (closesSunday && date.weekday == DateTime.sunday)) {
        continue;
      }
      if (!_attendance.containsKey(fitnessDateKey(date))) count++;
    }
    return count;
  }

  Widget _attendanceCount(String label, int count, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$label · $count',
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );

  Widget _attendanceEditor(DateTime today, bool closesSunday) {
    final date = _selectedDate;
    if (date == null) {
      return const Text('Select a booking date to record attendance.');
    }
    final status = _attendance[fitnessDateKey(date)];
    final availableWeekdays = fitnessAvailableWeekdays(widget.availability);
    final isClosed =
        (availableWeekdays != null &&
            !availableWeekdays.contains(date.weekday)) ||
        (closesSunday && date.weekday == DateTime.sunday);
    final canMarkPresent = !date.isAfter(today) && !isClosed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_monthTitle(date)} ${date.day} · '
            '${status == null
                ? 'Not recorded'
                : status == 'present'
                ? 'Present'
                : 'Absent'}',
            style: const TextStyle(
              color: Color(0xFF192B50),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (isClosed)
            const Text(
              'This venue is closed on this day.',
              style: TextStyle(color: Color(0xFF68748A), fontSize: 11),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('fitness-attendance-mark-present'),
                  onPressed: canMarkPresent && !_savingAttendance
                      ? () => _saveAttendance(date, 'present')
                      : null,
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                  ),
                  label: const Text('Present'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('fitness-attendance-mark-absent'),
                  onPressed: !_savingAttendance
                      ? () => _saveAttendance(date, 'absent')
                      : null,
                  icon: const Icon(Icons.event_busy_outlined, size: 16),
                  label: const Text('Absent'),
                ),
                if (status != null)
                  TextButton(
                    key: const ValueKey('fitness-attendance-clear'),
                    onPressed: _savingAttendance
                        ? null
                        : () => _saveAttendance(date, null),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          if (date.isAfter(today) && !isClosed)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Future dates can be marked absent, but not present.',
                style: TextStyle(color: Color(0xFF68748A), fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _saveAttendance(DateTime date, String? status) async {
    final onAttendanceChanged = widget.onAttendanceChanged;
    if (onAttendanceChanged == null) return;
    setState(() => _savingAttendance = true);
    try {
      await onAttendanceChanged(date, status);
      if (!mounted) return;
      setState(() {
        final key = fitnessDateKey(date);
        if (status == null) {
          _attendance.remove(key);
        } else {
          _attendance[key] = status;
        }
      });
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save attendance: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingAttendance = false);
    }
  }

  Widget _legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(color: Color(0xFF68748A), fontSize: 10),
      ),
    ],
  );

  String _monthTitle(DateTime date) {
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
    return '${months[date.month - 1]} ${date.year}';
  }

  String _dayDescription(
    DateTime date, {
    required bool isInPlan,
    required bool isPassed,
    required bool isSundayClosed,
    required String? status,
    required bool isStartDate,
    required bool isEndDate,
  }) {
    if (isSundayClosed) {
      return date.weekday == DateTime.sunday
          ? 'Sunday · Closed'
          : 'Venue closed';
    }
    if (!isInPlan) return 'Outside booking period';
    if (isStartDate && isEndDate) return 'Booking starts and ends';
    if (isStartDate) return 'Booking start date';
    if (isEndDate) return 'Booking end date';
    if (status == 'present') return 'Attendance marked present';
    if (status == 'absent') return 'Attendance marked absent';
    if (isPassed) return 'Booking period · Passed';
    return 'Active booking day';
  }
}
