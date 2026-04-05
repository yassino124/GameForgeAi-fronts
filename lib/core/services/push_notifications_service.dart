import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_service.dart';
import 'local_notifications_service.dart';

class PushNotificationsService {
  static bool _initialized = false;
  static String? _lastRegisteredToken;
  static String? _lastRegisteredAuthToken;
  static StreamSubscription<String>? _tokenRefreshSub;

  static final StreamController<String> _tapController = StreamController<String>.broadcast();
  static Stream<String> get onNotificationTap => _tapController.stream;

  static Future<void> init() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      if (kDebugMode) {
        // ignore: avoid_print
        print('PushNotificationsService: Firebase.initializeApp OK');
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('PushNotificationsService: Firebase initialize failed: $e');
      }
      _initialized = true;
      return;
    }

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      if (kDebugMode) {
        // ignore: avoid_print
        print('PushNotificationsService: permission status=${settings.authorizationStatus}');
      }
    } catch (_) {}

    String? toPayload(RemoteMessage message) {
      try {
        final kind = message.data['kind']?.toString();
        if (kind == 'creator_wallet') {
          return 'creator_wallet';
        }
        if (kind == 'template_new') {
          final tid = message.data['templateId']?.toString();
          if (tid != null && tid.trim().isNotEmpty) {
            return 'template:$tid';
          }
        }
      } catch (_) {}
      return null;
    }

    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      final p = initial == null ? null : toPayload(initial);
      if (p != null && p.trim().isNotEmpty) {
        Future.microtask(() => _tapController.add(p));
      }
    } catch (_) {}

    try {
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final p = toPayload(message);
        if (p == null || p.trim().isEmpty) return;
        _tapController.add(p);
      });
    } catch (_) {}

    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final n = message.notification;
        final title = (n?.title ?? message.data['title']?.toString() ?? 'GameForge AI').toString();
        final body = (n?.body ?? message.data['body']?.toString() ?? '').toString();
        if (body.trim().isEmpty) return;

        String? payload;
        payload = toPayload(message);

        await LocalNotificationsService.showRemoteNotification(title: title, body: body, payload: payload);
      });
    } catch (_) {}

    try {
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((_) async {
        if (_lastRegisteredAuthToken != null && _lastRegisteredAuthToken!.trim().isNotEmpty) {
          await syncWithBackend(authToken: _lastRegisteredAuthToken);
        }
      });
    } catch (_) {}

    _initialized = true;
  }

  static Future<void> syncWithBackend({String? authToken}) async {
    final t = (authToken ?? '').trim();
    _lastRegisteredAuthToken = t;

    if (!_initialized) {
      try {
        await init();
      } catch (_) {}
    }

    if (t.isEmpty) return;

    String? token;
    try {
      token = await FirebaseMessaging.instance.getToken();
    } catch (_) {
      token = null;
    }

    final ft = (token ?? '').trim();
    if (kDebugMode) {
      // ignore: avoid_print
      print('PushNotificationsService: getToken() => ${ft.isEmpty ? '(empty)' : ft.substring(0, ft.length > 16 ? 16 : ft.length)}...');
    }
    if (ft.isEmpty) return;

    if (_lastRegisteredToken == ft && _lastRegisteredAuthToken == t) return;

    try {
      final res = await ApiService.post(
        '/users/me/fcm-token',
        token: t,
        data: {'token': ft},
      );
      if (kDebugMode) {
        // ignore: avoid_print
        print('PushNotificationsService: register token response=$res');
      }
      _lastRegisteredToken = ft;
      _lastRegisteredAuthToken = t;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('PushNotificationsService: register token failed: $e');
      }
    }
  }

  static Future<void> dispose() async {
    try {
      await _tokenRefreshSub?.cancel();
    } catch (_) {}
    _tokenRefreshSub = null;

    try {
      await _tapController.close();
    } catch (_) {}
  }
}
