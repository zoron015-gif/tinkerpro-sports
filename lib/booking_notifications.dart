import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class BookingNotifications {
  BookingNotifications._();

  static final BookingNotifications instance = BookingNotifications._();

  static const _channelId = 'match_reminders';
  static const _channelName = 'Match reminders';
  static const _scheduledIdsKeyPrefix = 'scheduled_match_reminders_';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _initialize() async {
    if (!isSupported) {
      throw UnsupportedError(
        'Match notifications are supported on Android and iOS.',
      );
    }
    final initialization = _initialization ??= _initializePlugin();
    try {
      await initialization;
    } on Exception {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _initializePlugin() async {
    timezone_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    final location = timezone.getLocation(localTimezone.identifier);
    timezone.setLocalLocation(location);

    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    if (initialized != true) {
      throw Exception('The notification service could not be initialized.');
    }
  }

  Future<bool> requestPermissions() async {
    await _initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notificationsAllowed =
          await android?.requestNotificationsPermission() ?? false;
      if (!notificationsAllowed) return false;
      return await android?.requestExactAlarmsPermission() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: false,
          sound: true,
        ) ??
        false;
  }

  Future<bool> notificationsAllowed() async {
    await _initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notificationsAllowed =
          await android?.areNotificationsEnabled() ?? false;
      if (!notificationsAllowed) return false;
      return await android?.canScheduleExactNotifications() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final permissions = await ios?.checkPermissions();
    return permissions?.isEnabled == true ||
        permissions?.isProvisionalEnabled == true;
  }

  Future<bool?> openSystemNotificationSettings() async {
    await _initialize();
    return _plugin.openAppNotificationSettings();
  }

  Future<void> disableForAccount(String accountKey) async {
    await _initialize();
    final preferences = await SharedPreferences.getInstance();
    final storageKey = _storageKey(accountKey);
    final scheduled = _readScheduledNotifications(
      preferences.getString(storageKey),
    );
    for (final notification in scheduled) {
      await _plugin.cancel(id: notification.id);
    }
    await preferences.remove(storageKey);
  }

  Future<void> synchronizeApprovedBookings({
    required String accountKey,
    required List<Map<String, dynamic>> bookings,
  }) async {
    await _initialize();
    final preferences = await SharedPreferences.getInstance();
    final previous = _readScheduledNotifications(
      preferences.getString(_storageKey(accountKey)),
    );
    final notifications = <_ScheduledBookingNotification>[];
    final now = DateTime.now();

    for (final booking in bookings) {
      if ('${booking['status'] ?? ''}'.toLowerCase() != 'approved') continue;
      final start = _bookingStart(booking);
      if (start == null) {
        throw FormatException(
          'An approved booking has an invalid date or start time.',
        );
      }
      final durationHours = _durationHours(booking['durationHours']);
      if (durationHours <= 0) {
        throw FormatException(
          'An approved booking has an invalid match duration.',
        );
      }

      final venue = '${booking['venueName'] ?? 'your venue'}';
      final bookingKey =
          '${booking['id'] ?? booking['venueId'] ?? venue}_${booking['date']}_${booking['startTime']}';
      final end = start.add(
        Duration(seconds: (durationHours * Duration.secondsPerHour).round()),
      );
      if (start.isAfter(now)) {
        notifications.add(
          _ScheduledBookingNotification(
            id: _notificationId('$accountKey:$bookingKey:start'),
            date: start,
            title: 'Your match is starting',
            body: 'Your booking at $venue starts now.',
          ),
        );
      }
      if (end.isAfter(now)) {
        notifications.add(
          _ScheduledBookingNotification(
            id: _notificationId('$accountKey:$bookingKey:end'),
            date: end,
            title: 'Your match has ended',
            body: 'Your booking at $venue has ended.',
          ),
        );
      }
    }

    final nextIds = notifications
        .map((notification) => notification.id)
        .toSet();
    for (final old in previous) {
      if (!nextIds.contains(old.id) && old.date.isAfter(now)) {
        await _plugin.cancel(id: old.id);
      }
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Alerts when an approved match starts and ends.',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );
    final location = timezone.local;
    for (final notification in notifications) {
      final date = notification.date;
      await _plugin.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        scheduledDate: timezone.TZDateTime(
          location,
          date.year,
          date.month,
          date.day,
          date.hour,
          date.minute,
          date.second,
        ),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'booking:${notification.id}',
      );
    }

    await preferences.setString(
      _storageKey(accountKey),
      jsonEncode(
        notifications
            .map(
              (notification) => {
                'id': notification.id,
                'date': notification.date.millisecondsSinceEpoch,
              },
            )
            .toList(),
      ),
    );
  }

  DateTime? _bookingStart(Map<String, dynamic> booking) {
    final date = '${booking['date'] ?? ''}'.trim();
    final time = '${booking['startTime'] ?? ''}'.trim();
    if (date.isEmpty || time.isEmpty) return null;
    return DateTime.tryParse('$date $time');
  }

  double _durationHours(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  List<_ScheduledBookingNotification> _readScheduledNotifications(
    String? value,
  ) {
    if (value == null || value.isEmpty) return const [];
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw const FormatException('Invalid saved match notification data.');
    }
    return decoded.map((entry) {
      if (entry is! Map || entry['id'] is! num || entry['date'] is! num) {
        throw const FormatException('Invalid saved match notification entry.');
      }
      return _ScheduledBookingNotification(
        id: (entry['id'] as num).toInt(),
        date: DateTime.fromMillisecondsSinceEpoch(
          (entry['date'] as num).toInt(),
        ),
        title: '',
        body: '',
      );
    }).toList();
  }

  int _notificationId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(value)) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  String _storageKey(String accountKey) =>
      '$_scheduledIdsKeyPrefix${Uri.encodeComponent(accountKey)}';
}

class _ScheduledBookingNotification {
  const _ScheduledBookingNotification({
    required this.id,
    required this.date,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime date;
  final String title;
  final String body;
}
