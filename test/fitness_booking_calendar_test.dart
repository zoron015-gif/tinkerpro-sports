import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/fitness_booking_calendar.dart';

void main() {
  test('fitness plan end dates preserve the day and clip short months', () {
    expect(
      fitnessPlanEndDate(DateTime(2026, 9, 8), 'monthly'),
      DateTime(2026, 10, 8),
    );
    expect(
      fitnessPlanEndDate(DateTime(2026, 1, 31), 'monthly'),
      DateTime(2026, 2, 28),
    );
    expect(
      fitnessPlanEndDate(DateTime(2026, 9, 8), 'yearly'),
      DateTime(2027, 9, 8),
    );
    expect(
      fitnessPlanEndDate(DateTime(2026, 9, 8), 'session'),
      DateTime(2026, 9, 8),
    );
  });

  test('Sunday closure requires an explicit Sunday-closed hours entry', () {
    expect(
      fitnessVenueClosesSunday(
        'Monday-Saturday 7:00 AM-9:00 PM; Sunday Closed',
      ),
      isTrue,
    );
    expect(fitnessVenueClosesSunday('7:00 AM-9:00 PM'), isFalse);
    expect(fitnessVenueClosesSunday('Open every Sunday'), isFalse);
  });

  test('available weekdays identify days omitted from merchant schedule', () {
    expect(
      fitnessAvailableWeekdays(
        'Monday, Tuesday, Wednesday, Thursday, Friday, Saturday',
      ),
      {
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
      },
    );
    expect(fitnessAvailableWeekdays('Any'), isNull);
    expect(fitnessAvailableWeekdays(''), isNull);
  });

  test('active fitness booking lasts through its plan end date', () {
    final today = DateUtils.dateOnly(DateTime.now());
    final booking = {
      'date':
          '${today.year}-${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}',
      'fitnessPlanType': 'monthly',
    };
    final expiredBooking = {'date': '2020-01-01', 'fitnessPlanType': 'monthly'};

    expect(isFitnessBookingActive(booking, onDate: today), isTrue);
    expect(isFitnessBookingActive(expiredBooking, onDate: today), isFalse);
    expect(
      fitnessBookingEndDate(booking),
      fitnessPlanEndDate(today, 'monthly'),
    );
  });

  testWidgets('calendar distinguishes past, active, and closed Sundays', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = today.subtract(const Duration(days: 2));
    final end = today.add(const Duration(days: 25));
    DateTime nextDay = today.add(const Duration(days: 1));
    if (nextDay.weekday == DateTime.sunday) {
      nextDay = nextDay.add(const Duration(days: 1));
    }
    final startKey =
        'fitness-calendar-day-${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final nextDayKey =
        'fitness-calendar-day-${nextDay.year}-${nextDay.month.toString().padLeft(2, '0')}-${nextDay.day.toString().padLeft(2, '0')}';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FitnessBookingCalendar(
              startDate: start,
              endDate: end,
              hours: 'Monday-Saturday 7:00 AM-9:00 PM; Sunday Closed',
            ),
          ),
        ),
      ),
    );

    if (nextDay.month != today.month || nextDay.year != today.year) {
      await tester.tap(
        find.byKey(const ValueKey('fitness-calendar-next-month')),
      );
      await tester.pumpAndSettle();
    }

    final activeDay = tester.widget<Container>(
      find.byKey(ValueKey(nextDayKey)),
    );
    final activeMonth = DateTime(nextDay.year, nextDay.month, 1);
    final firstOfMonth = activeMonth;
    final sunday = DateTime(
      activeMonth.year,
      activeMonth.month,
      firstOfMonth.day + (DateTime.sunday - firstOfMonth.weekday) % 7,
    );
    final sundayKey =
        'fitness-calendar-day-${sunday.year}-${sunday.month.toString().padLeft(2, '0')}-${sunday.day.toString().padLeft(2, '0')}';
    final closedSunday = tester.widget<Container>(
      find.byKey(ValueKey(sundayKey)),
    );
    expect((activeDay.decoration! as BoxDecoration).color, isNull);
    expect(
      ((activeDay.decoration! as BoxDecoration).border! as Border).top.color,
      const Color(0xFFFF8200),
    );
    expect((closedSunday.decoration! as BoxDecoration).color, isNull);
    expect(find.text('Sunday · Closed'), findsOneWidget);

    if (start.month != today.month || start.year != today.year) {
      await tester.tap(
        find.byKey(const ValueKey('fitness-calendar-previous-month')),
      );
      await tester.pumpAndSettle();
    }
    final passedDay = tester.widget<Container>(find.byKey(ValueKey(startKey)));
    expect((passedDay.decoration! as BoxDecoration).color, isNull);
  });

  testWidgets('calendar identifies plan boundaries and records attendance', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = DateTime(today.year, today.month, 1);
    final end = DateTime(today.year, today.month + 1, 0);
    final attendance = <String, String>{};
    final todayKey =
        'fitness-calendar-day-${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final startKey =
        'fitness-calendar-day-${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endKey =
        'fitness-calendar-day-${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FitnessBookingCalendar(
              startDate: start,
              endDate: end,
              hours: '7:00 AM-9:00 PM',
              attendance: attendance,
              onAttendanceChanged: (date, status) async {
                final key = fitnessDateKey(date);
                if (status == null) {
                  attendance.remove(key);
                } else {
                  attendance[key] = status;
                }
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('START'), findsOneWidget);
    expect(find.text('END'), findsOneWidget);
    await tester.ensureVisible(find.byKey(ValueKey(todayKey)));
    await tester.tap(find.byKey(ValueKey(todayKey)));
    await tester.ensureVisible(
      find.byKey(const ValueKey('fitness-attendance-mark-present')),
    );
    await tester.tap(
      find.byKey(const ValueKey('fitness-attendance-mark-present')),
    );
    await tester.pumpAndSettle();
    expect(attendance[fitnessDateKey(today)], 'present');
    expect(find.text('Present · 1'), findsOneWidget);
    final presentDay = tester.widget<Container>(find.byKey(ValueKey(todayKey)));
    expect((presentDay.decoration! as BoxDecoration).color, isNull);
    expect(
      ((presentDay.decoration! as BoxDecoration).border! as Border).top.color,
      const Color(0xFF21865A),
    );
    final presentDayNumber = tester.widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey(todayKey)),
        matching: find.text('${today.day}'),
      ),
    );
    expect(presentDayNumber.style?.color, const Color(0xFF21865A));

    final absentDate = today.day == 1
        ? today.add(const Duration(days: 1))
        : today.subtract(const Duration(days: 1));
    final absentKey =
        'fitness-calendar-day-${absentDate.year}-${absentDate.month.toString().padLeft(2, '0')}-${absentDate.day.toString().padLeft(2, '0')}';
    await tester.ensureVisible(find.byKey(ValueKey(absentKey)));
    await tester.tap(find.byKey(ValueKey(absentKey)));
    await tester.pumpAndSettle();
    expect(find.textContaining('· Not recorded'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('fitness-attendance-mark-absent')),
    );
    await tester.tap(
      find.byKey(const ValueKey('fitness-attendance-mark-absent')),
    );
    await tester.pumpAndSettle();
    expect(attendance[fitnessDateKey(absentDate)], 'absent');
    expect(find.text('Absent · 1'), findsOneWidget);

    await tester.ensureVisible(find.byKey(ValueKey(startKey)));
    await tester.tap(find.byKey(ValueKey(startKey)));
    await tester.ensureVisible(
      find.byKey(const ValueKey('fitness-attendance-mark-absent')),
    );
    await tester.tap(
      find.byKey(const ValueKey('fitness-attendance-mark-absent')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey(startKey)), findsOneWidget);
    expect(find.byKey(ValueKey(endKey)), findsOneWidget);
  });

  testWidgets('calendar marks and disables weekdays omitted from schedule', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = DateTime(today.year, today.month, 1);
    final end = DateTime(today.year, today.month + 1, 0);
    final sunday = DateTime(
      today.year,
      today.month,
      1 + (DateTime.sunday - DateTime(today.year, today.month, 1).weekday) % 7,
    );
    final sundayKey =
        'fitness-calendar-day-${sunday.year}-${sunday.month.toString().padLeft(2, '0')}-${sunday.day.toString().padLeft(2, '0')}';
    var attendanceChanged = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FitnessBookingCalendar(
              startDate: start,
              endDate: end,
              hours: '10:00 AM-10:00 PM',
              availability:
                  'Monday, Tuesday, Wednesday, Thursday, Friday, Saturday',
              onAttendanceChanged: (_, _) async {
                attendanceChanged = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Venue closed'), findsOneWidget);
    final sundayCell = tester.widget<Container>(
      find.byKey(ValueKey(sundayKey)),
    );
    final sundayStyle = tester.widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey(sundayKey)),
        matching: find.text('${sunday.day}'),
      ),
    );
    expect(sundayCell.decoration, isA<BoxDecoration>());
    expect(sundayStyle.style?.color, const Color(0xFF8993A2));
    expect(find.byTooltip('Sunday · Closed'), findsWidgets);
    final sundayTapTarget = tester.widget<GestureDetector>(
      find
          .ancestor(
            of: find.byKey(ValueKey(sundayKey)),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    expect(sundayTapTarget.onTap, isNull);
    expect(attendanceChanged, isFalse);
  });
}
