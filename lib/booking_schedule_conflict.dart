import 'package:flutter/material.dart';

import 'app_text.dart';
import 'auth_api.dart';
import 'app_design_system.dart';

Future<bool> confirmBookingScheduleConflict({
  required BuildContext context,
  required AuthApi api,
  required String token,
  required int venueId,
  required String venueName,
  required DateTime startsAt,
  required double durationHours,
}) async {
  final bookings = await api.customerBookings(token);
  final conflicts = findBookingScheduleConflicts(
    bookings: bookings,
    venueId: venueId,
    startsAt: startsAt,
    durationHours: durationHours,
  );
  if (conflicts.isEmpty) return true;
  if (!context.mounted) return false;

  final dateLabel = MaterialLocalizations.of(context)
      .formatMediumDate(startsAt);
  final candidateEnd = startsAt.add(
    Duration(minutes: (durationHours * 60).round()),
  );
  final candidateTime =
      '${TimeOfDay.fromDateTime(startsAt).format(context)}–'
      '${TimeOfDay.fromDateTime(candidateEnd).format(context)}';
  final conflictDetails = conflicts
      .map((booking) {
        final conflictDate = _localDate(booking['date']);
        final conflictStart = _minutesSinceMidnight(booking['startTime']);
        final conflictDuration = _number(booking['durationHours']);
        if (conflictDate == null ||
            conflictStart == null ||
            conflictDuration <= 0) {
          return '${booking['venueName'] ?? 'Another venue'}';
        }
        final startsAtConflict = DateTime(
          conflictDate.year,
          conflictDate.month,
          conflictDate.day,
          conflictStart ~/ 60,
          conflictStart % 60,
        );
        final endsAtConflict = startsAtConflict.add(
          Duration(minutes: (conflictDuration * 60).round()),
        );
        final timeLabel =
            '${TimeOfDay.fromDateTime(startsAtConflict).format(context)}–'
            '${TimeOfDay.fromDateTime(endsAtConflict).format(context)}';
        return '${booking['venueName'] ?? 'Another venue'} · '
            '${MaterialLocalizations.of(context).formatMediumDate(startsAtConflict)} · '
            '$timeLabel';
      })
      .join('\n');

  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const AppText(
            'You already have a booking at this time',
            localize: true,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Your existing booking overlaps the schedule you selected.',
                  style: TextStyle(color: AppColors.muted),
                  localize: true,
                ),
                const SizedBox(height: 12),
                AppText(
                  conflictDetails,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                AppText(
                  'New booking: $venueName · $dateLabel · $candidateTime',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                const AppText(
                  'Would you like to continue with this booking?',
                  localize: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Choose another time', localize: true),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const AppText('Continue booking', localize: true),
            ),
          ],
        ),
      ) ??
      false;
}

List<Map<String, dynamic>> findBookingScheduleConflicts({
  required List<Map<String, dynamic>> bookings,
  required int venueId,
  required DateTime startsAt,
  required double durationHours,
}) {
  final proposedStart = DateTime(
    startsAt.year,
    startsAt.month,
    startsAt.day,
    startsAt.hour,
    startsAt.minute,
  );
  final proposedEnd = proposedStart.add(
    Duration(minutes: (durationHours * 60).round()),
  );
  if (durationHours <= 0 || proposedEnd == proposedStart) {
    return const [];
  }

  return bookings
      .where((booking) {
        final bookedVenueId = _number(booking['venueId']).toInt();
        final status = '${booking['status'] ?? ''}'.trim().toLowerCase();
        if (bookedVenueId == venueId ||
            (status != 'pending' && status != 'approved')) {
          return false;
        }
        final date = _localDate(booking['date']);
        final startMinutes = _minutesSinceMidnight(booking['startTime']);
        final bookedDuration = _number(booking['durationHours']);
        if (date == null ||
            startMinutes == null ||
            !bookedDuration.isFinite ||
            bookedDuration <= 0) {
          return false;
        }
        final bookedStart = DateTime(
          date.year,
          date.month,
          date.day,
          startMinutes ~/ 60,
          startMinutes % 60,
        );
        final bookedEnd = bookedStart.add(
          Duration(minutes: (bookedDuration * 60).round()),
        );
        return bookedStart.isBefore(proposedEnd) &&
            bookedEnd.isAfter(proposedStart);
      })
      .toList(growable: false);
}

double _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

DateTime? _localDate(Object? value) {
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

int? _minutesSinceMidnight(Object? value) {
  final text = '$value'.trim();
  final twelveHour = RegExp(
    r'^(\d{1,2}):([0-5]\d)(?::[0-5]\d)?\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(text);
  if (twelveHour != null) {
    final hour = int.parse(twelveHour.group(1)!);
    final minute = int.parse(twelveHour.group(2)!);
    if (hour < 1 || hour > 12) return null;
    final period = twelveHour.group(3)!.toUpperCase();
    return ((hour % 12) + (period == 'PM' ? 12 : 0)) * 60 + minute;
  }
  final twentyFourHour = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)(?::[0-5]\d)?$')
      .firstMatch(text);
  if (twentyFourHour == null) return null;
  return int.parse(twentyFourHour.group(1)!) * 60 +
      int.parse(twentyFourHour.group(2)!);
}
