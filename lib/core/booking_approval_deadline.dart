DateTime? parseBookingApprovalDeadline(Object? value) {
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

String formatBookingApprovalDeadline(DateTime deadline) {
  final hour = deadline.hour % 12 == 0 ? 12 : deadline.hour % 12;
  final minute = deadline.minute.toString().padLeft(2, '0');
  final period = deadline.hour < 12 ? 'AM' : 'PM';
  return '${deadline.year}-${deadline.month.toString().padLeft(2, '0')}-'
      '${deadline.day.toString().padLeft(2, '0')} · '
      '$hour:$minute $period';
}
