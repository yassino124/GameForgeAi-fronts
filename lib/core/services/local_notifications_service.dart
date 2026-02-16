import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationsService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static final StreamController<String> _tapController = StreamController<String>.broadcast();
  static String? _launchPayload;

  static const int _dailyQuizId = 1101;
  static const String _kPrefQuizLastDate = 'quiz_last_date_ymd';
  static const String _kPrefQuizStreak = 'quiz_streak';
  static const String _kPrefFreezeUsedWeekKey = 'quiz_freeze_used_week_key';

  static const String kPrefQuizReminderEnabled = 'quiz_reminder_enabled';
  static const String kPrefQuizReminderHour = 'quiz_reminder_hour';
  static const String kPrefQuizReminderMinute = 'quiz_reminder_minute';

  static const String _kPrefInAppNotifications = 'in_app_notifications_v1';

  static bool _initialized = false;

  static Stream<String> get onNotificationTap => _tapController.stream;

  static String? consumeLaunchPayload() {
    final p = _launchPayload;
    _launchPayload = null;
    return p;
  }

  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    const settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    _launchPayload = launch?.notificationResponse?.payload;

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.trim().isEmpty) return;
        _tapController.add(payload);
      },
    );

    _initialized = true;
  }

  static Future<void> showBuildFinishedNotification({
    required String projectId,
    required bool success,
    String? projectName,
    String? buildTarget,
  }) async {
    if (!_initialized) {
      await init();
    }

    final ok = await requestPermissions();
    if (!ok) return;

    final title = success ? 'Build terminé' : 'Build échoué';
    final targetLabel = (buildTarget ?? '').trim().isEmpty ? null : buildTarget!.trim().toUpperCase();
    final name = (projectName ?? '').trim().isEmpty ? null : projectName!.trim();

    final bodyParts = <String>[];
    if (name != null) bodyParts.add(name);
    if (targetLabel != null) bodyParts.add(targetLabel);
    bodyParts.add(success ? 'Touchez pour voir les résultats.' : 'Touchez pour voir les détails.');
    final body = bodyParts.join(' • ');

    final payload = 'build_results:$projectId';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'build_updates',
        'Build Updates',
        channelDescription: 'Build progress and completion notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
    await _plugin.show(id, title, body, details, payload: payload);
  }

  static Future<List<Map<String, dynamic>>> listInAppNotifications() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPrefInAppNotifications);
    if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> _saveInAppNotifications(List<Map<String, dynamic>> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPrefInAppNotifications, jsonEncode(items));
  }

  static Future<void> addBuildFinishedInAppNotification({
    required String projectId,
    required bool success,
    String? projectName,
    String? buildTarget,
  }) async {
    final now = DateTime.now();
    final id = 'local_${now.microsecondsSinceEpoch}';

    final title = success ? 'Build terminé' : 'Build échoué';
    final targetLabel = (buildTarget ?? '').trim().isEmpty ? null : buildTarget!.trim().toUpperCase();
    final name = (projectName ?? '').trim().isEmpty ? null : projectName!.trim();

    final messageParts = <String>[];
    if (name != null) messageParts.add(name);
    if (targetLabel != null) messageParts.add(targetLabel);
    messageParts.add(success ? 'Touchez pour voir les résultats.' : 'Touchez pour voir les détails.');

    final item = <String, dynamic>{
      'id': id,
      'title': title,
      'message': messageParts.join(' • '),
      'timestamp': now.toUtc().toIso8601String(),
      'type': success ? 'success' : 'error',
      'isRead': false,
      'data': {
        'kind': 'build_finished',
        'projectId': projectId,
        'success': success,
        'buildTarget': (buildTarget ?? '').trim(),
        'projectName': (projectName ?? '').trim(),
      },
    };

    final items = await listInAppNotifications();
    items.insert(0, item);
    if (items.length > 80) {
      items.removeRange(80, items.length);
    }
    await _saveInAppNotifications(items);
  }

  static Future<void> markInAppNotificationRead(String id, bool isRead) async {
    final items = await listInAppNotifications();
    var changed = false;
    for (final it in items) {
      if (it['id']?.toString() == id) {
        it['isRead'] = isRead;
        changed = true;
        break;
      }
    }
    if (changed) {
      await _saveInAppNotifications(items);
    }
  }

  static Future<void> markAllInAppRead() async {
    final items = await listInAppNotifications();
    for (final it in items) {
      it['isRead'] = true;
    }
    await _saveInAppNotifications(items);
  }

  static Future<void> removeInAppNotification(String id) async {
    final items = await listInAppNotifications();
    final before = items.length;
    items.removeWhere((e) => e['id']?.toString() == id);
    if (items.length != before) {
      await _saveInAppNotifications(items);
    }
  }

  static Future<void> clearInAppNotifications() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kPrefInAppNotifications);
  }

  static Future<bool> requestPermissions() async {
    if (!_initialized) {
      await init();
    }

    var allowed = true;

    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final res = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      allowed = res ?? false;
    } else if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final res = await android?.requestNotificationsPermission();
      allowed = res ?? true;
    }

    return allowed;
  }

  static Future<void> scheduleDailyQuizReminder({
    int hour = 20,
    int minute = 0,
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await init();
    }

    final ok = await requestPermissions();
    if (!ok) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_quiz_reminder',
        'Daily Quiz Reminder',
        channelDescription: 'Daily reminder to play the Game Quiz',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final next = _nextInstanceOfTime(hour, minute);

    try {
      await _plugin.cancel(_dailyQuizId);
    } catch (_) {}

    await _plugin.zonedSchedule(
      _dailyQuizId,
      title,
      body,
      next,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static String _todayYmd() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _weekKey(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    return '${weekStart.year.toString().padLeft(4, '0')}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
  }

  static String _currentWeekKey() => _weekKey(DateTime.now());

  static Future<({String title, String body})> _buildDailyQuizMessage() async {
    final p = await SharedPreferences.getInstance();

    final lastDate = p.getString(_kPrefQuizLastDate);
    final streak = p.getInt(_kPrefQuizStreak) ?? 0;
    final playedToday = lastDate == _todayYmd();

    final freezeUsedWeekKey = p.getString(_kPrefFreezeUsedWeekKey);
    final freezeAvailable = freezeUsedWeekKey != _currentWeekKey();

    if (playedToday) {
      return (
        title: 'Daily Quiz completed',
        body: 'Nice! Come back tomorrow for a new quiz.',
      );
    }

    if (streak <= 0) {
      return (
        title: 'Daily Quiz is ready',
        body: 'Play now to start your streak.',
      );
    }

    return (
      title: 'Daily Quiz is ready',
      body: freezeAvailable
          ? 'Play now to keep your streak alive. Freeze is available this week.'
          : 'Play now to keep your streak alive.',
    );
  }

  static Future<void> showQuizTestNotification() async {
    if (!_initialized) {
      await init();
    }

    final ok = await requestPermissions();
    if (!ok) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_quiz_reminder',
        'Daily Quiz Reminder',
        channelDescription: 'Daily reminder to play the Game Quiz',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.show(
      2201,
      'Daily Quiz reminder (test)',
      'Open GameForge and play today\'s quiz.',
      details,
    );
  }

  static Future<void> setDailyQuizReminderEnabled(bool enabled) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(kPrefQuizReminderEnabled, enabled);
    if (!enabled) {
      await cancelDailyQuizReminder();
      return;
    }

    final hour = p.getInt(kPrefQuizReminderHour) ?? 20;
    final minute = p.getInt(kPrefQuizReminderMinute) ?? 0;
    final m = await _buildDailyQuizMessage();
    await scheduleDailyQuizReminder(hour: hour, minute: minute, title: m.title, body: m.body);
  }

  static Future<void> setDailyQuizReminderTime({required int hour, required int minute}) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(kPrefQuizReminderHour, hour);
    await p.setInt(kPrefQuizReminderMinute, minute);

    final enabled = p.getBool(kPrefQuizReminderEnabled);
    if (enabled == false) return;
    final m = await _buildDailyQuizMessage();
    await scheduleDailyQuizReminder(hour: hour, minute: minute, title: m.title, body: m.body);
  }

  static Future<void> bootstrapDailyQuizReminder() async {
    final p = await SharedPreferences.getInstance();
    final enabled = p.getBool(kPrefQuizReminderEnabled) ?? true;
    if (!enabled) {
      return;
    }

    final hour = p.getInt(kPrefQuizReminderHour) ?? 20;
    final minute = p.getInt(kPrefQuizReminderMinute) ?? 0;
    final m = await _buildDailyQuizMessage();
    await scheduleDailyQuizReminder(hour: hour, minute: minute, title: m.title, body: m.body);
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static Future<void> cancelDailyQuizReminder() async {
    if (!_initialized) {
      await init();
    }

    try {
      await _plugin.cancel(_dailyQuizId);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('cancelDailyQuizReminder failed: $e');
      }
    }
  }
}
