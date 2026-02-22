import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/app_refresh_bus.dart';
import '../services/local_notifications_service.dart';
import '../services/projects_service.dart';

class BuildMonitorProvider extends ChangeNotifier {
  Timer? _timer;

  String? _token;
  String? _projectId;

  String status = 'idle'; // idle | queued | running | ready | failed
  String buildTarget = 'webgl';
  String? error;

  String? projectName;
  String? version;
  String? lastLogLine;

  DateTime? startedAt;
  DateTime? lastUpdatedAt;

  bool _completionNotified = false;

  String? get projectId => _projectId;
  bool get isMonitoring => _projectId != null;

  void startMonitoring({required String token, required String projectId}) {
    _token = token;
    _projectId = projectId;
    status = 'queued';
    buildTarget = 'webgl';
    error = null;
    projectName = null;
    version = null;
    lastLogLine = null;
    startedAt = DateTime.now();
    lastUpdatedAt = DateTime.now();
    _completionNotified = false;
    notifyListeners();

    _timer?.cancel();
    _pollOnce();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _pollOnce());
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
    _token = null;
    _projectId = null;
    status = 'idle';
    buildTarget = 'webgl';
    error = null;
    projectName = null;
    version = null;
    lastLogLine = null;
    startedAt = null;
    lastUpdatedAt = null;
    _completionNotified = false;
    notifyListeners();
  }

  Future<void> _pollOnce() async {
    final token = _token;
    final pid = _projectId;
    if (token == null || token.isEmpty || pid == null || pid.isEmpty) return;

    try {
      final res = await ProjectsService.getProject(token: token, projectId: pid);
      final data = res['data'];
      if (res['success'] != true || data is! Map) return;

      final s = (data['status']?.toString() ?? '').toLowerCase();
      final bt = (data['buildTarget']?.toString() ?? 'webgl').trim().toLowerCase();
      final err = data['error']?.toString();

      final nm = (data['name']?.toString() ?? data['title']?.toString() ?? '').trim();
      final ver = (data['version']?.toString() ?? '').trim();
      final logLine = (data['buildLogLastLine']?.toString() ?? '').trim();

      final previousStatus = status;
      status = s.isEmpty ? status : s;
      buildTarget = bt.isEmpty ? buildTarget : bt;
      error = (err != null && err.trim().isNotEmpty) ? err : null;
      projectName = nm.isEmpty ? projectName : nm;
      version = ver.isEmpty ? version : ver;
      lastLogLine = logLine.isEmpty ? lastLogLine : logLine;
      lastUpdatedAt = DateTime.now();

      if (status == 'ready' || status == 'failed') {
        _timer?.cancel();
        _timer = null;
      }

      if (!_completionNotified && previousStatus != status && (status == 'ready' || status == 'failed')) {
        _completionNotified = true;
        AppRefreshBus.bump();
        try {
          await LocalNotificationsService.addBuildFinishedInAppNotification(
            projectId: pid,
            success: status == 'ready',
            projectName: projectName,
            buildTarget: buildTarget,
          );
        } catch (_) {}

        try {
          await LocalNotificationsService.showBuildFinishedNotification(
            projectId: pid,
            success: status == 'ready',
            projectName: projectName,
            buildTarget: buildTarget,
          );
        } catch (_) {}
      }

      notifyListeners();
    } catch (_) {
      // ignore polling errors (screen will show its own errors when opened)
    }
  }
}
