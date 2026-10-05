import 'package:flutter/foundation.dart';

import '../../../auth_api.dart';
import '../data/activity_log_repository.dart';
import '../domain/activity_log_entry.dart';

enum ActivityLogLoadState { loading, loaded, failed }

class ActivityLogGroup {
  const ActivityLogGroup({
    required this.key,
    required this.activities,
    this.venueName,
    this.sportType,
  });

  final String key;
  final String? venueName;
  final String? sportType;
  final List<ActivityLogEntry> activities;
}

class ActivityLogController extends ChangeNotifier {
  ActivityLogController({required this.repository});

  final ActivityLogDataSource repository;
  List<ActivityLogEntry> _activities = const [];
  ActivityLogLoadState _state = ActivityLogLoadState.loading;
  Object? _error;
  DateTime? _selectedDate;
  String _searchQuery = '';
  bool _disposed = false;

  ActivityLogLoadState get state => _state;
  String? get supportRequestId {
    final failure = _error;
    return failure is AuthApiException ? failure.requestId : null;
  }

  String get userErrorMessage {
    final failure = _error;
    if (failure is AuthApiException) {
      if (failure.statusCode == 401) {
        return 'Your session may have expired. Please sign in and try again.';
      }
      return failure.userMessage;
    }
    return 'We could not load your activity. Please try again.';
  }

  DateTime? get selectedDate => _selectedDate;
  String get searchQuery => _searchQuery;
  bool get isSearchEmpty => _searchQuery.trim().isEmpty;
  bool get hasActivities => _activities.isNotEmpty;

  List<ActivityLogGroup> get visibleGroups {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _activities.where((activity) {
      final createdAt = activity.createdAt?.toLocal();
      final matchesDate =
          _selectedDate == null ||
          (createdAt != null &&
              createdAt.year == _selectedDate!.year &&
              createdAt.month == _selectedDate!.month &&
              createdAt.day == _selectedDate!.day);
      final searchableText = [
        activity.title ?? '',
        activity.description ?? '',
        activity.activityType ?? '',
        activity.venueName ?? '',
        activity.sportType ?? '',
        activity.actorRole ?? '',
        activity.requestId ?? '',
        ...activity.details.values.map((value) => value.toString()),
      ].join(' ').toLowerCase();
      return matchesDate && (query.isEmpty || searchableText.contains(query));
    });

    final groups = <String, ActivityLogGroup>{};
    var standaloneIndex = 0;
    for (final activity in filtered) {
      final venueName = activity.venueName?.trim();
      if (venueName == null || venueName.isEmpty) {
        final key = 'activity-${standaloneIndex++}';
        groups[key] = ActivityLogGroup(key: key, activities: [activity]);
        continue;
      }
      final venueId = activity.venueId;
      final key = venueId == null || venueId.isEmpty
          ? 'name:${venueName.toLowerCase()}'
          : 'id:$venueId';
      final existing = groups[key];
      if (existing == null) {
        groups[key] = ActivityLogGroup(
          key: key,
          venueName: venueName,
          sportType: activity.sportType,
          activities: [activity],
        );
      } else {
        groups[key] = ActivityLogGroup(
          key: existing.key,
          venueName: existing.venueName,
          sportType: existing.sportType,
          activities: [...existing.activities, activity],
        );
      }
    }
    return groups.values.toList();
  }

  Future<void> load() async {
    _state = ActivityLogLoadState.loading;
    _error = null;
    _notifyListenersIfActive();
    try {
      _activities = await repository.loadActivities();
      _state = ActivityLogLoadState.loaded;
    } catch (error) {
      _error = error;
      _state = ActivityLogLoadState.failed;
    }
    _notifyListenersIfActive();
  }

  void search(String value) {
    if (_searchQuery == value) return;
    _searchQuery = value;
    notifyListeners();
  }

  void selectDate(DateTime? value) {
    _selectedDate = value == null
        ? null
        : DateTime(value.year, value.month, value.day);
    notifyListeners();
  }

  void _notifyListenersIfActive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
