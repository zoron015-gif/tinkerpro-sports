import 'package:flutter/material.dart';

import 'package:myapp/app_design_system.dart';
import '../../../../app_preferences.dart';

class ActivityLogSearchField extends StatelessWidget {
  const ActivityLogSearchField({
    super.key,
    required this.controller,
    required this.isEmpty,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool isEmpty;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
    child: TextField(
      key: const ValueKey('activity-log-search'),
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: appLanguageText('Search activity...', 'Search activity...'),
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: isEmpty
            ? null
            : IconButton(
                tooltip: appLanguageText('Clear search', 'Clear search'),
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:  BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:  BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.accent),
        ),
      ),
    ),
  );
}

class ActivityLogDateFilter extends StatelessWidget {
  const ActivityLogDateFilter({
    super.key,
    required this.selectedDate,
    required this.onSelected,
    required this.onClear,
  });

  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onClear;

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Show activity from',
    );
    if (selected == null || !context.mounted) return;
    onSelected(selected);
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        key: const ValueKey('activity-log-date-filter'),
        tooltip: selectedDate == null
            ? 'Filter by date'
            : 'Date: ${_formatDate(selectedDate!)}',
        onPressed: () => _selectDate(context),
        icon: const Icon(Icons.calendar_month_rounded),
      ),
      if (selectedDate != null)
        IconButton(
          key: const ValueKey('activity-log-clear-date'),
          tooltip: appLanguageText('Clear date filter', 'Clear date filter'),
          onPressed: onClear,
          icon: const Icon(Icons.event_busy_rounded),
        ),
    ],
  );

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';
}

class ActivityLogMessage extends StatelessWidget {
  const ActivityLogMessage({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.supportRequestId,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? supportRequestId;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.muted, size: 42),
          const SizedBox(height: 12),
          AppText(
            message,
            textAlign: TextAlign.center,
            style:  TextStyle(color: AppColors.muted),
          ),
          if (supportRequestId != null &&
              supportRequestId!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              'Support reference: $supportRequestId',
              textAlign: TextAlign.center,
              style:  TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: AppText(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
