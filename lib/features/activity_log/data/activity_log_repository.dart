import 'package:myapp/app_session.dart';
import 'package:myapp/auth_api.dart';

import '../domain/activity_log_entry.dart';

abstract interface class ActivityLogDataSource {
  Future<List<ActivityLogEntry>> loadActivities();
}

class ActivityLogRepository implements ActivityLogDataSource {
  ActivityLogRepository({
    required this.api,
    Future<AppSession> Function()? loadSession,
  }) : _loadSession = loadSession ?? AppSession.load;

  final AuthApi api;
  final Future<AppSession> Function() _loadSession;

  @override
  Future<List<ActivityLogEntry>> loadActivities() async {
    final session = await _loadSession();
    final token = session.apiToken;
    if (token == null || token.isEmpty) {
      throw const AuthApiException(
        'Please sign in to view your activity log.',
        401,
      );
    }
    final activities = await api.activityLogs(token);
    return activities.map(ActivityLogEntry.fromJson).toList();
  }
}
