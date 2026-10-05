import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/activity_log/domain/activity_log_entry.dart';
import 'package:myapp/features/activity_log/presentation/activity_log_controller.dart';
import 'package:myapp/features/activity_log/data/activity_log_repository.dart';

void main() {
  test('controller filters by text and groups activity by venue', () async {
    final controller = ActivityLogController(
      repository: _FakeActivityLogDataSource([
        _entry(
          id: 1,
          title: 'Booking approved',
          createdAt: '2026-09-29T08:15:34',
          venueId: '42',
          venueName: 'Riverside Court',
        ),
        _entry(
          id: 2,
          title: 'Booking requested',
          createdAt: '2026-09-28T11:02:07',
          venueId: '42',
          venueName: 'Riverside Court',
        ),
        _entry(
          id: 3,
          title: 'Profile updated',
          createdAt: '2026-09-27T09:00:00',
        ),
      ]),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state, ActivityLogLoadState.loaded);
    expect(controller.visibleGroups, hasLength(2));
    expect(controller.visibleGroups.first.activities, hasLength(2));

    controller.search('profile');

    expect(controller.visibleGroups, hasLength(1));
    expect(
      controller.visibleGroups.single.activities.single.title,
      'Profile updated',
    );
  });

  test('controller applies and clears a date filter', () async {
    final controller = ActivityLogController(
      repository: _FakeActivityLogDataSource([
        _entry(id: 1, title: 'Today', createdAt: '2026-09-29T08:15:34'),
        _entry(id: 2, title: 'Yesterday', createdAt: '2026-09-28T11:02:07'),
      ]),
    );
    addTearDown(controller.dispose);

    await controller.load();
    controller.selectDate(DateTime(2026, 9, 29));

    expect(controller.visibleGroups.single.activities.single.title, 'Today');

    controller.selectDate(null);

    expect(controller.visibleGroups, hasLength(2));
  });
}

ActivityLogEntry _entry({
  required int id,
  required String title,
  required String createdAt,
  String? venueId,
  String? venueName,
}) => ActivityLogEntry.fromJson({
  'id': id,
  'title': title,
  'activityType': 'booking_requested',
  'createdAt': createdAt,
  'venueId': venueId,
  'venueName': venueName,
  'details': const {},
});

class _FakeActivityLogDataSource implements ActivityLogDataSource {
  _FakeActivityLogDataSource(this.activities);

  final List<ActivityLogEntry> activities;

  @override
  Future<List<ActivityLogEntry>> loadActivities() async => activities;
}
