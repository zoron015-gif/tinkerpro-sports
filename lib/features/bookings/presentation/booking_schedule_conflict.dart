import 'package:flutter/material.dart';

import '../../../app_text.dart';
import '../../../app_design_system.dart';
import '../application/booking_schedule_controller.dart';

Future<bool> confirmBookingScheduleConflict({
  required BuildContext context,
  required BookingScheduleController controller,
  required int venueId,
  required String venueName,
  required DateTime startsAt,
  required double durationHours,
  bool requireCancelForPendingRequest = false,
}) async {
  final check = await controller.check(
    venueId: venueId,
    startsAt: startsAt,
    durationHours: durationHours,
    requireCancelForPendingRequest: requireCancelForPendingRequest,
  );
  final pendingRequests = check.pendingRequests;
  if (pendingRequests.isNotEmpty) {
    if (!context.mounted) return false;
    final shouldCancelAndContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText(
          'Pending booking request already exists',
          localize: true,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'You already have a request for this venue and date waiting for merchant approval. To make a new request, cancel the existing request first. The new booking will continue only after cancellation succeeds.',
                style: TextStyle(color: AppColors.muted),
                localize: true,
              ),
              const SizedBox(height: 12),
              AppText(
                pendingRequests.first.venueName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              AppText(
                MaterialLocalizations.of(context).formatMediumDate(startsAt),
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Keep existing request', localize: true),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('Cancel request and continue', localize: true),
          ),
        ],
      ),
    );
    if (shouldCancelAndContinue != true || !context.mounted) return false;

    await controller.cancelPendingRequests(pendingRequests);
  }

  final conflicts = check.conflicts;
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
        final startsAtConflict = booking.startAt;
        final endsAtConflict = booking.endAt;
        if (startsAtConflict == null || endsAtConflict == null) {
          return booking.venueName;
        }
        final timeLabel =
            '${TimeOfDay.fromDateTime(startsAtConflict).format(context)}–'
            '${TimeOfDay.fromDateTime(endsAtConflict).format(context)}';
        return '${booking.venueName} · '
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
