import 'package:flutter/material.dart';

import 'app_session.dart';
import 'auth_api.dart';

const _activityInk = Color(0xFF101B33);
const _activityMuted = Color(0xFF68748A);
const _activityOrange = Color(0xFFFF8200);
const _activityPage = Color(0xFFF7F9FC);

class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key, this.api});

  final AuthApi? api;

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  late final AuthApi _api = widget.api ?? AuthApi();
  late Future<List<Map<String, dynamic>>> _activities;
  final _searchController = TextEditingController();
  DateTime? _selectedDate;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _activities = _loadActivities();
  }

  Future<List<Map<String, dynamic>>> _loadActivities() async {
    final session = await AppSession.load();
    final token = session.apiToken;
    if (token == null || token.isEmpty) {
      throw const AuthApiException(
        'Please sign in to view your activity log.',
        401,
      );
    }
    return _api.activityLogs(token);
  }

  void _retry() {
    setState(() => _activities = _loadActivities());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Show activity from',
    );
    if (selected == null || !mounted) return;
    setState(
      () =>
          _selectedDate = DateTime(selected.year, selected.month, selected.day),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _activityPage,
    appBar: AppBar(
      backgroundColor: _activityPage,
      foregroundColor: _activityInk,
      title: const Text(
        'Activity log',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      actions: [
        IconButton(
          key: const ValueKey('activity-log-date-filter'),
          tooltip: _selectedDate == null
              ? 'Filter by date'
              : 'Date: ${_formatDate(_selectedDate!)}',
          onPressed: _selectDate,
          icon: const Icon(Icons.calendar_month_rounded),
        ),
        if (_selectedDate != null)
          IconButton(
            key: const ValueKey('activity-log-clear-date'),
            tooltip: 'Clear date filter',
            onPressed: () => setState(() => _selectedDate = null),
            icon: const Icon(Icons.event_busy_rounded),
          ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _activities,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ActivityMessage(
            icon: Icons.error_outline_rounded,
            message: 'Could not load your activity: ${snapshot.error}',
            actionLabel: 'Retry',
            onAction: _retry,
          );
        }
        final allActivities = snapshot.data ?? const [];
        final normalizedQuery = _searchQuery.trim().toLowerCase();
        final activities = allActivities.where((activity) {
          final createdAtValue = activity['createdAt']?.toString() ?? '';
          final createdAt = DateTime.tryParse(createdAtValue)?.toLocal();
          final matchesDate =
              _selectedDate == null ||
              (createdAt != null &&
                  createdAt.year == _selectedDate!.year &&
                  createdAt.month == _selectedDate!.month &&
                  createdAt.day == _selectedDate!.day);
          final details = _activityDetails(activity);
          final searchableText = [
            activity['title']?.toString() ?? '',
            activity['description']?.toString() ?? '',
            activity['activityType']?.toString() ?? '',
            activity['venueName']?.toString() ?? '',
            activity['sportType']?.toString() ?? '',
            ...details.values.map((value) => value.toString()),
          ].join(' ').toLowerCase();
          final matchesQuery =
              normalizedQuery.isEmpty ||
              searchableText.contains(normalizedQuery);
          return matchesDate && matchesQuery;
        }).toList();
        final listItems = _groupVenueActivities(activities);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: TextField(
                key: const ValueKey('activity-log-search'),
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search activity...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE6EAF0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE6EAF0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _activityOrange),
                  ),
                ),
              ),
            ),
            Expanded(
              child: listItems.isEmpty
                  ? _ActivityMessage(
                      icon: Icons.history_rounded,
                      message: allActivities.isEmpty
                          ? 'Your account activity will appear here.'
                          : _selectedDate != null
                          ? 'No activity found on ${_formatDate(_selectedDate!)}.'
                          : 'No activity matches your search.',
                    )
                  : ListView.separated(
                      key: const ValueKey('activity-log-list'),
                      padding: const EdgeInsets.all(16),
                      itemCount: listItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final group = listItems[index];
                        return group.venueName == null
                            ? _ActivityTile(activity: group.activities.first)
                            : _VenueActivityTile(
                                key: ValueKey(
                                  'activity-log-venue-${group.key}',
                                ),
                                venueName: group.venueName!,
                                sportType: group.sportType,
                                activities: group.activities,
                              );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  );
}

List<_ActivityGroup> _groupVenueActivities(
  List<Map<String, dynamic>> activities,
) {
  final groups = <String, _ActivityGroup>{};
  var standaloneIndex = 0;
  for (final activity in activities) {
    final venueName = activity['venueName']?.toString().trim();
    if (venueName == null || venueName.isEmpty) {
      final key = 'activity-${standaloneIndex++}';
      groups[key] = _ActivityGroup(
        key: key,
        activities: [activity],
      );
      continue;
    }

    final venueId = activity['venueId']?.toString();
    final key = venueId == null || venueId.isEmpty
        ? 'name:${venueName.toLowerCase()}'
        : 'id:$venueId';
    final group = groups.putIfAbsent(
      key,
      () => _ActivityGroup(
        key: key,
        venueName: venueName,
        sportType: activity['sportType']?.toString(),
      ),
    );
    group.activities.add(activity);
  }
  return groups.values.toList();
}

Map<String, dynamic> _activityDetails(Map<String, dynamic> activity) {
  final value = activity['details'];
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

class _ActivityGroup {
  _ActivityGroup({
    required this.key,
    this.venueName,
    this.sportType,
    List<Map<String, dynamic>>? activities,
  }) : activities = activities ?? [];

  final String key;
  final String? venueName;
  final String? sportType;
  final List<Map<String, dynamic>> activities;
}

String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

String _formatExactDateTime(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return 'Time unavailable';
  return '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)} '
      '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}:${_twoDigits(date.second)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

class _VenueActivityTile extends StatelessWidget {
  const _VenueActivityTile({
    super.key,
    required this.venueName,
    required this.activities,
    this.sportType,
  });

  final String venueName;
  final String? sportType;
  final List<Map<String, dynamic>> activities;

  @override
  Widget build(BuildContext context) {
    final mostRecent = activities.first['createdAt'];
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE6EAF0)),
      ),
      child: ListTile(
        key: const ValueKey('activity-log-venue-tile'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFF1E4),
          foregroundColor: _activityOrange,
          child: Icon(Icons.location_on_outlined),
        ),
        title: Text(
          venueName,
          style: const TextStyle(
            color: _activityInk,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sportType != null && sportType!.isNotEmpty)
                Text(sportType!, style: const TextStyle(color: _activityMuted)),
              Text(
                '${activities.length} ${activities.length == 1 ? 'activity' : 'activities'} · '
                'Last: ${_formatExactDateTime(mostRecent)}',
                style: const TextStyle(color: _activityMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _showVenueTimeline(context),
      ),
    );
  }

  Future<void> _showVenueTimeline(
    BuildContext context,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venueName,
                          style: const TextStyle(
                            color: _activityInk,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (sportType != null && sportType!.isNotEmpty)
                          Text(
                            sportType!,
                            style: const TextStyle(color: _activityMuted),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close venue activity',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: activities.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  final details = _activityDetails(activity);
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _activityPage,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${activity['title'] ?? 'Venue activity'}',
                          style: const TextStyle(
                            color: _activityInk,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatExactDateTime(activity['createdAt']),
                          style: const TextStyle(
                            color: _activityMuted,
                            fontSize: 12,
                          ),
                        ),
                        if (details['bookingDate'] != null ||
                            details['startTime'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Booking: ${details['bookingDate'] ?? 'Date unavailable'}'
                            '${details['startTime'] == null ? '' : ' at ${details['startTime']}'}',
                            style: const TextStyle(color: _activityMuted),
                          ),
                        ],
                        if (details['durationHours'] != null)
                          Text(
                            'Duration: ${details['durationHours']} hours',
                            style: const TextStyle(color: _activityMuted),
                          ),
                        if (details['players'] != null)
                          Text(
                            'Players: ${details['players']}',
                            style: const TextStyle(color: _activityMuted),
                          ),
                        if (details.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${activity['description'] ?? ''}',
                              style: const TextStyle(color: _activityMuted),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});

  final Map<String, dynamic> activity;

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse('${activity['createdAt'] ?? ''}');
    final dateLabel = createdAt == null
        ? ''
        : '${_twoDigits(createdAt.toLocal().month)}/${_twoDigits(createdAt.toLocal().day)}/${createdAt.toLocal().year} · '
              '${_twoDigits(createdAt.toLocal().hour)}:${_twoDigits(createdAt.toLocal().minute)}';

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE6EAF0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFF1E4),
          foregroundColor: _activityOrange,
          child: Icon(_activityIcon('${activity['activityType'] ?? ''}')),
        ),
        title: Text(
          '${activity['title'] ?? 'Account activity'}',
          style: const TextStyle(
            color: _activityInk,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${activity['description'] ?? ''}',
                style: const TextStyle(color: _activityMuted),
              ),
              if (dateLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  dateLabel,
                  style: const TextStyle(color: _activityMuted, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _activityIcon(String type) => switch (type) {
    'login' => Icons.login_rounded,
    'profile_updated' => Icons.person_outline_rounded,
    'item_saved' => Icons.bookmark_add_outlined,
    'item_removed' => Icons.bookmark_remove_outlined,
    'booking_requested' => Icons.event_available_outlined,
    'booking_approved' || 'booking_finished' => Icons.check_circle_outline,
    'review_submitted' => Icons.star_outline_rounded,
    'message_sent' => Icons.chat_bubble_outline_rounded,
    'account_registration' => Icons.person_add_alt_rounded,
    'email_verified' => Icons.mark_email_read_outlined,
    'password_changed' => Icons.password_rounded,
    'venue_hearted' => Icons.favorite_rounded,
    'venue_unhearted' => Icons.heart_broken_rounded,
    _ => Icons.history_rounded,
  };
}

class _ActivityMessage extends StatelessWidget {
  const _ActivityMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _activityMuted, size: 42),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _activityMuted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
