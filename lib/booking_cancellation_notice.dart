import 'package:flutter/material.dart';

import 'app_design_system.dart';
import 'app_text.dart';

class BookingCancellationNotice extends StatelessWidget {
  const BookingCancellationNotice({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.softSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 19, color: AppColors.navy),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'Cancellation and refund information',
                style: TextStyle(fontWeight: FontWeight.w800),
                localize: true,
              ),
              SizedBox(height: 4),
              AppText(
                'Your booking starts within 24 hours. You may cancel at any '
                'time, but refund eligibility depends on when you cancel. '
                'Cancel at least 6 hours before the start time to request a '
                'refund for an online payment. If you cancel within 6 hours '
                'of the start time or after the booking begins, your online '
                'payment is non-refundable. Any cash already collected must '
                'be returned by the venue outside the app.',
                style: TextStyle(height: 1.35),
                localize: true,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
