import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/services/projects_service.dart';

class AiCoachScreen extends StatefulWidget {
  final String? projectId;
  final String? projectName;

  const AiCoachScreen({
    super.key,
    this.projectId,
    this.projectName,
  });

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

typedef _ChatMsg = ({String role, String text});

typedef _CoachAction = ({String id, String label, Map<String, dynamic> payload});

class _AiCoachScreenState extends State<AiCoachScreen> with SingleTickerProviderStateMixin {
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();

  io.Socket? _socket;

  String _lang = 'tn';

  late final AnimationController _pulse;

  final List<_ChatMsg> _messages = [];
  String _draftAssistant = '';
  String _draftUser = '';

  bool _connecting = false;
  bool _connected = false;
  bool _listening = false;
  bool _speaking = false;
  bool _waitingReply = false;
  bool _handsFree = false;

  List<_CoachAction> _nextActions = const [];

  Timer? _projectPoll;
  String? _projectStatus;
  String? _projectBuildTarget;
  bool _hasWebgl = false;
  bool _hasApk = false;
  String? _previewUrl;

  Timer? _silenceTimer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _initTts();
    _connectSocket();
    _refreshProject();
    _projectPoll = Timer.periodic(const Duration(seconds: 6), (_) {
      _refreshProject();
    });
  }

  List<_CoachAction> _inferNextActions(String assistantText) {
    final t = assistantText.trim();
    if (t.isEmpty) return const [];

    // Optional structured payload:
    // {"actions":[{"id":"rebuild","label":"Rebuild WebGL","payload":{...}}]}
    try {
      final j = jsonDecode(t);
      if (j is Map && j['actions'] is List) {
        final actions = <_CoachAction>[];
        for (final a in (j['actions'] as List)) {
          if (a is! Map) continue;
          final id = a['id']?.toString() ?? '';
          final label = a['label']?.toString() ?? '';
          final payloadRaw = a['payload'];
          if (id.trim().isEmpty || label.trim().isEmpty) continue;
          final payload = (payloadRaw is Map) ? Map<String, dynamic>.from(payloadRaw) : <String, dynamic>{};
          actions.add((id: id.trim(), label: label.trim(), payload: payload));
          if (actions.length >= 3) break;
        }
        if (actions.isNotEmpty) return actions;
      }
    } catch (_) {
      // ignore
    }

    final lower = t.toLowerCase();
    final out = <_CoachAction>[];
    final hasProject = widget.projectId != null && widget.projectId!.trim().isNotEmpty;

    void add(String id, String label, Map<String, dynamic> payload) {
      if (out.any((x) => x.id == id)) return;
      out.add((id: id, label: label, payload: payload));
    }

    if (hasProject && (lower.contains('rebuild') || lower.contains('build'))) {
      if (lower.contains('apk') || lower.contains('android')) {
        add('build_apk', 'Build APK', {'target': 'android_apk'});
      }
      if (lower.contains('webgl') || lower.contains('web')) {
        add('build_webgl', 'Rebuild WebGL', {'target': 'webgl'});
      }
      if (out.isEmpty) {
        add('build_webgl', 'Rebuild WebGL', {'target': 'webgl'});
      }
    }

    if (hasProject && (lower.contains('preset') || lower.contains('arcade') || lower.contains('speed') || lower.contains('hard'))) {
      add('preset_arcade_fast', 'Apply: Arcade Fast', {'preset': 'arcade_fast'});
    }

    if (hasProject && (lower.contains('results') || lower.contains('download') || lower.contains('lien') || lower.contains('link'))) {
      add('open_results', 'Open Build Results', {});
    }

    if (out.length < 3 && hasProject) {
      add('open_build', 'Open Build', {});
    }

    return (out.length <= 3) ? out : out.sublist(0, 3);
  }

  Future<void> _runCoachAction(_CoachAction a) async {
    final pid = widget.projectId?.trim();
    if (pid == null || pid.isEmpty) {
      AppNotifier.showError('Missing projectId');
      return;
    }
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      AppNotifier.showError('Session expired. Please sign in again.');
      return;
    }

    try {
      if (a.id == 'open_results') {
        if (!mounted) return;
        context.go('/build-results', extra: {'projectId': pid});
        return;
      }

      if (a.id == 'open_build') {
        if (!mounted) return;
        context.go('/build-configuration', extra: {'projectId': pid});
        return;
      }

      if (a.id == 'open_progress') {
        if (!mounted) return;
        context.go('/build-progress', extra: {'projectId': pid});
        return;
      }

      if (a.id == 'play_webgl') {
        final url = _previewUrl;
        if (url == null || url.trim().isEmpty) {
          AppNotifier.showError('Preview URL not available yet');
          return;
        }
        if (!mounted) return;
        context.go('/play-webgl', extra: {'url': url});
        return;
      }

      if (a.id == 'cancel_build') {
        await ProjectsService.cancelBuild(token: token, projectId: pid);
        if (!mounted) return;
        AppNotifier.showSuccess('Build cancelled');
        _refreshProject();
        return;
      }

      if (a.id == 'preset_arcade_fast') {
        await ProjectsService.updateProject(
          token: token,
          projectId: pid,
          speed: 10.5,
          difficulty: 0.75,
          timeScale: 1.12,
          fogEnabled: false,
          cameraZoom: 0.18,
          gravityY: -9.8,
          jumpForce: 6.8,
        );
        AppNotifier.showSuccess('Preset applied');
        _refreshProject();
        return;
      }

      if (a.id == 'build_webgl' || a.id == 'build_apk') {
        final target = a.payload['target']?.toString() ?? 'webgl';
        await ProjectsService.updateProject(token: token, projectId: pid, buildTarget: target);
        await ProjectsService.rebuildProject(token: token, projectId: pid);
        if (!mounted) return;
        AppNotifier.showSuccess('Build started');
        _refreshProject();
        context.go('/build-progress', extra: {'projectId': pid});
        return;
      }
    } catch (e) {
      AppNotifier.showError(e.toString());
    }
  }

  List<_CoachAction> _contextActions() {
    final pid = widget.projectId?.trim();
    if (pid == null || pid.isEmpty) return const [];

    final status = (_projectStatus ?? '').toLowerCase();
    final out = <_CoachAction>[];

    void add(String id, String label, Map<String, dynamic> payload) {
      if (out.any((x) => x.id == id)) return;
      out.add((id: id, label: label, payload: payload));
    }

    if (status == 'queued' || status == 'running') {
      add('open_progress', 'View build progress', {});
      add('cancel_build', 'Cancel build', {});
      return out;
    }

    if (status == 'failed') {
      final t = (_projectBuildTarget ?? 'webgl').trim();
      add(t == 'android_apk' || t == 'android' ? 'build_apk' : 'build_webgl', 'Retry build', {'target': t.isEmpty ? 'webgl' : t});
      add('open_progress', 'Open build progress', {});
      return out;
    }

    if (status == 'ready') {
      add('open_results', 'Open results', {});
      if (_previewUrl != null && _previewUrl!.trim().isNotEmpty) {
        add('play_webgl', 'Play WebGL', {});
      }
      if (!_hasWebgl) add('build_webgl', 'Build WebGL', {'target': 'webgl'});
      if (!_hasApk) add('build_apk', 'Build APK', {'target': 'android_apk'});
      if (out.length > 3) return out.sublist(0, 3);
      return out;
    }

    // Unknown / initial state
    add('preset_arcade_fast', 'Apply: Arcade Fast', {'preset': 'arcade_fast'});
    add('build_webgl', 'Build WebGL', {'target': 'webgl'});
    add('build_apk', 'Build APK', {'target': 'android_apk'});
    return out;
  }

  Widget _nextActionsBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_nextActions.isEmpty || _waitingReply) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
        boxShadow: AppShadows.boxShadowSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Next best actions', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900, color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _nextActions
                .map(
                  (a) => ActionChip(
                    label: Text(a.label, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900)),
                    onPressed: () => _runCoachAction(a),
                    backgroundColor: cs.surfaceContainerHighest.withOpacity(0.65),
                    side: BorderSide(color: cs.outlineVariant.withOpacity(0.55)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _contextActionsBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_waitingReply) return const SizedBox.shrink();
    final actions = _contextActions();
    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
        boxShadow: AppShadows.boxShadowSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recommended now', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900, color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actions
                .map(
                  (a) => ActionChip(
                    label: Text(a.label, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900)),
                    onPressed: () => _runCoachAction(a),
                    backgroundColor: cs.surfaceContainerHighest.withOpacity(0.65),
                    side: BorderSide(color: cs.outlineVariant.withOpacity(0.55)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _projectPoll?.cancel();
    _pulse.dispose();
    try {
      if (_speech.isListening) {
        _speech.stop();
      }
    } catch (_) {}
    try {
      _tts.stop();
    } catch (_) {}
    try {
      _socket?.dispose();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _refreshProject() async {
    final pid = widget.projectId?.trim();
    if (pid == null || pid.isEmpty) return;
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) return;

    try {
      final res = await ProjectsService.getProject(token: token, projectId: pid);
      if (!mounted) return;
      final data = res['data'];
      if (res['success'] != true || data is! Map) return;
      final status = (data['status']?.toString() ?? '').trim().toLowerCase();
      final buildTarget = (data['buildTarget']?.toString() ?? '').trim().toLowerCase();

      final hasWebgl = (data['webglZipStorageKey']?.toString().trim().isNotEmpty == true) ||
          (data['webglIndexStorageKey']?.toString().trim().isNotEmpty == true) ||
          (data['resultStorageKey']?.toString().trim().isNotEmpty == true && buildTarget == 'webgl');
      final hasApk = (data['androidApkStorageKey']?.toString().trim().isNotEmpty == true) ||
          (data['resultStorageKey']?.toString().trim().isNotEmpty == true && (buildTarget == 'android_apk' || buildTarget == 'android'));

      String? preview;
      try {
        final p = await ProjectsService.getProjectPreviewUrl(token: token, projectId: pid);
        if (p['success'] == true && p['data'] is Map) {
          preview = (p['data'] as Map)['url']?.toString();
        }
      } catch (_) {}

      setState(() {
        _projectStatus = status.isEmpty ? null : status;
        _projectBuildTarget = buildTarget.isEmpty ? null : buildTarget;
        _hasWebgl = hasWebgl;
        _hasApk = hasApk;
        _previewUrl = (preview?.trim().isNotEmpty == true) ? preview!.trim() : _previewUrl;
      });
    } catch (_) {}
  }

  Future<void> _initTts() async {
    try {
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _tts.setStartHandler(() {
        if (!mounted) return;
        setState(() => _speaking = true);
      });
      _tts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() => _speaking = false);
        if (_handsFree && !_waitingReply && !_listening) {
          Future.microtask(() async {
            if (!mounted) return;
            await _startListening();
          });
        }
      });
      _tts.setCancelHandler(() {
        if (!mounted) return;
        setState(() => _speaking = false);
        if (_handsFree && !_waitingReply && !_listening) {
          Future.microtask(() async {
            if (!mounted) return;
            await _startListening();
          });
        }
      });
    } catch (_) {}
  }

  Uri _socketBaseUri() {
    final api = Uri.parse(ApiService.baseUrl);
    return Uri(
      scheme: api.scheme,
      host: api.host,
      port: api.hasPort ? api.port : null,
    );
  }

  Widget _handsFreeChip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text('LIVE'),
      selected: _handsFree,
      onSelected: _waitingReply
          ? null
          : (v) async {
              setState(() => _handsFree = v);
              if (!mounted) return;
              if (v) {
                if (!_listening && !_speaking) {
                  await _startListening();
                }
              } else {
                try {
                  await _speech.stop();
                } catch (_) {}
                if (!mounted) return;
                setState(() => _listening = false);
              }
            },
      selectedColor: cs.primary.withOpacity(0.18),
      backgroundColor: cs.surface.withOpacity(0.8),
      labelStyle: AppTypography.caption.copyWith(
        fontWeight: FontWeight.w900,
        color: _handsFree ? cs.primary : cs.onSurfaceVariant,
      ),
      side: BorderSide(color: (_handsFree ? cs.primary : cs.outlineVariant).withOpacity(0.55)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  Future<void> _connectSocket() async {
    if (_connecting || _connected) return;
    setState(() {
      _connecting = true;
      _connected = false;
    });

    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      AppNotifier.showError('Session expired. Please sign in again.');
      setState(() {
        _connecting = false;
        _connected = false;
      });
      return;
    }

    final base = _socketBaseUri();
    final url = base.toString();
    final coachNsUrl = Uri.parse(url).resolve('/coach').toString();

    final socket = io.io(
      coachNsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setPath('/socket.io')
          .setAuth({'token': token})
          .build(),
    );

    socket.onConnect((_) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connected = true;
      });
    });

    socket.onDisconnect((_) {
      if (!mounted) return;
      setState(() {
        _connected = false;
        _connecting = false;
      });
    });

    socket.onConnectError((err) {
      if (!mounted) return;
      setState(() {
        _connected = false;
        _connecting = false;
      });
      AppNotifier.showError('Coach connection failed');
    });

    socket.on('coach:started', (_) {
      if (!mounted) return;
      setState(() {
        _waitingReply = true;
        _draftAssistant = '';
      });
    });

    socket.on('coach:token', (data) {
      final t = (data is Map ? data['t'] : null)?.toString() ?? '';
      if (t.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _draftAssistant += t;
      });
    });

    socket.on('coach:done', (_) async {
      if (!mounted) return;
      final text = _draftAssistant.trim();
      setState(() {
        _waitingReply = false;
        if (text.isNotEmpty) {
          _messages.add((role: 'assistant', text: text));
        }
        _draftAssistant = '';
        _nextActions = _inferNextActions(text);
      });

      if (text.isNotEmpty) {
        await _speak(text);
      }
    });

    socket.on('coach:error', (data) {
      final msg = (data is Map ? data['message'] : null)?.toString() ?? 'Coach error';
      if (!mounted) return;
      setState(() {
        _waitingReply = false;
        _draftAssistant = '';
      });
      AppNotifier.showError(msg);
    });

    _socket = socket;

    try {
      socket.connect();
    } catch (_) {
      setState(() {
        _connecting = false;
        _connected = false;
      });
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();
    } catch (_) {}
    try {
      if (_lang == 'fr') {
        await _tts.setLanguage('fr-FR');
      } else if (_lang == 'en') {
        await _tts.setLanguage('en-US');
      } else {
        await _tts.setLanguage('ar-SA');
      }
    } catch (_) {
      // ignore
    }

    try {
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> _startListening() async {
    if (_listening) return;

    try {
      await _tts.stop();
    } catch (_) {}

    final available = await _speech.initialize(
      onError: (_) {
        if (!mounted) return;
        setState(() => _listening = false);
      },
      onStatus: (s) {
        if (!mounted) return;
        if (s == 'notListening' || s == 'done') {
          setState(() => _listening = false);
        }
      },
    );

    if (!available) {
      AppNotifier.showError('Speech recognition not available');
      return;
    }

    setState(() {
      _listening = true;
      _draftUser = '';
    });

    final localeId = _lang == 'fr'
        ? 'fr_FR'
        : _lang == 'en'
            ? 'en_US'
            : 'ar_SA';

    _silenceTimer?.cancel();

    await _speech.listen(
      localeId: localeId,
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 2),
      onResult: (r) {
        if (!mounted) return;
        setState(() => _draftUser = r.recognizedWords);
        _silenceTimer?.cancel();
        _silenceTimer = Timer(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          _stopListeningAndSend();
        });
      },
    );
  }

  Future<void> _stopListeningAndSend() async {
    _silenceTimer?.cancel();
    if (!_listening && _draftUser.trim().isEmpty) return;

    try {
      await _speech.stop();
    } catch (_) {}

    if (!mounted) return;
    setState(() => _listening = false);

    final text = _draftUser.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add((role: 'user', text: text));
      _draftUser = '';
    });

    await _sendToCoach(text);
  }

  Future<void> _sendToCoach(String text) async {
    final socket = _socket;
    if (socket == null || !_connected) {
      await _connectSocket();
    }

    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      AppNotifier.showError('Session expired. Please sign in again.');
      return;
    }

    if (_socket == null || !_connected) {
      AppNotifier.showError('Coach is not connected');
      return;
    }

    setState(() {
      _waitingReply = true;
      _draftAssistant = '';
      _nextActions = const [];
    });

    _socket!.emit('coach:start', {
      'token': token,
      'text': text,
      if (widget.projectId != null && widget.projectId!.trim().isNotEmpty) 'projectId': widget.projectId,
      'locale': _lang,
    });
  }

  Widget _bubble(BuildContext context, {required String role, required String text}) {
    final cs = Theme.of(context).colorScheme;
    final isUser = role == 'user';
    final bg = isUser ? null : cs.surfaceContainerHighest.withOpacity(0.55);
    final fg = isUser ? cs.onPrimary : cs.onSurface;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 360),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: isUser ? AppColors.primaryGradient : null,
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: isUser ? null : Border.all(color: cs.outlineVariant.withOpacity(0.35)),
        boxShadow: isUser ? AppShadows.boxShadowSmall : null,
      ),
      child: Text(
        text,
        style: AppTypography.body2.copyWith(color: fg, height: 1.35),
      ),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withOpacity(0.90),
                    cs.secondary.withOpacity(0.80),
                  ],
                ),
              ),
              child: Icon(Icons.auto_awesome_rounded, size: 14, color: cs.onPrimary),
            ),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }

  Widget _langChip(BuildContext context, {required String value, required String label}) {
    final cs = Theme.of(context).colorScheme;
    final selected = _lang == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _waitingReply
          ? null
          : (v) {
              if (!v) return;
              setState(() => _lang = value);
            },
      selectedColor: cs.primary.withOpacity(0.18),
      backgroundColor: cs.surface.withOpacity(0.8),
      labelStyle: AppTypography.caption.copyWith(
        fontWeight: FontWeight.w900,
        color: selected ? cs.primary : cs.onSurfaceVariant,
      ),
      side: BorderSide(color: (selected ? cs.primary : cs.outlineVariant).withOpacity(0.55)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  Widget _statusPill(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = _connected
        ? (_listening ? 'Listening' : (_speaking ? 'Speaking' : (_waitingReply ? 'Thinking' : 'Ready')))
        : (_connecting ? 'Connecting' : 'Offline');
    final bg = _connected ? cs.surface.withOpacity(0.65) : AppColors.warning.withOpacity(0.14);
    final border = _connected ? cs.outlineVariant.withOpacity(0.55) : AppColors.warning.withOpacity(0.45);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _connected ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface)),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, {required String title}) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppBorderRadius.large)),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primary.withOpacity(0.20),
                    cs.secondary.withOpacity(0.12),
                    cs.surface,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: const SizedBox(),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 14, AppSpacing.lg, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: AppColors.primaryGradient,
                          boxShadow: AppShadows.boxShadowSmall,
                        ),
                        child: Icon(Icons.mic_rounded, color: cs.onPrimary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(
                              'Coach Guide • voice + live suggestions',
                              style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _waitingReply
                            ? null
                            : () {
                                _socket?.emit('coach:reset');
                                setState(() {
                                  _messages.clear();
                                  _draftAssistant = '';
                                  _draftUser = '';
                                });
                              },
                        icon: Icon(Icons.refresh_rounded, color: cs.onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _statusPill(context),
                        const SizedBox(width: 10),
                        _handsFreeChip(context),
                        const SizedBox(width: 8),
                        _langChip(context, value: 'tn', label: 'TN'),
                        const SizedBox(width: 8),
                        _langChip(context, value: 'fr', label: 'FR'),
                        const SizedBox(width: 8),
                        _langChip(context, value: 'en', label: 'EN'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendQuick(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    if (_waitingReply) return;
    setState(() {
      _messages.add((role: 'user', text: t));
    });
    await _sendToCoach(t);
  }

  Widget _quickPrompts(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final prompts = <String>[
      'Give me 3 best runtime presets for my GameForge project (Chill/Normal/Hardcore)',
      'What should I do next in GameForge to publish/play faster?',
      'Suggest a color palette (primary/secondary/accent) + playerColor for a neon style',
      'Make it cinematic: enable fog + set camera zoom + recommend values',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: prompts
          .map(
            (p) => ActionChip(
              label: Text(p, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w800)),
              onPressed: _waitingReply ? null : () => _sendQuick(p),
              backgroundColor: cs.surface,
              side: BorderSide(color: cs.outlineVariant.withOpacity(0.55)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
          )
          .toList(),
    );
  }

  Widget _micButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = !_waitingReply;

    final core = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _listening
            ? LinearGradient(colors: [cs.error.withOpacity(0.95), cs.error.withOpacity(0.75)])
            : AppColors.primaryGradient,
        boxShadow: _listening ? AppShadows.boxShadowLarge : AppShadows.boxShadowSmall,
      ),
      child: Icon(
        _listening ? Icons.stop_rounded : Icons.mic_rounded,
        color: cs.onPrimary,
        size: 28,
      ),
    );

    return GestureDetector(
      onTap: !enabled
          ? null
          : () async {
              if (_listening) {
                await _stopListeningAndSend();
              } else {
                await _startListening();
              }
            },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1 : 0.55,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_listening)
              ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.18).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.error.withOpacity(0.12),
                    border: Border.all(color: cs.error.withOpacity(0.35)),
                  ),
                ),
              ),
            core,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final header = widget.projectName?.trim().isNotEmpty == true
        ? 'Coach • ${widget.projectName!.trim()}'
        : 'Coach';

    final list = <Widget>[];
    for (final m in _messages) {
      list.add(_bubble(context, role: m.role, text: m.text));
    }

    if (_draftAssistant.trim().isNotEmpty) {
      list.add(_bubble(context, role: 'assistant', text: _draftAssistant));
    }

    if (_draftUser.trim().isNotEmpty) {
      list.add(_bubble(context, role: 'user', text: _draftUser));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _header(context, title: header),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (_messages.isEmpty && _draftAssistant.isEmpty && _draftUser.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(AppBorderRadius.large),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                      boxShadow: AppShadows.boxShadowSmall,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Coach Guide', style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(
                          'Ask anything about GameForge: create flow, AI configuration, runtime tuning (speed/colors/fog/camera/physics), rebuild and Play WebGL.',
                          style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        _quickPrompts(context),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                ...list,
                _contextActionsBar(context),
                _nextActionsBar(context),
                if (_waitingReply)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                          ),
                          child: Icon(Icons.auto_awesome_rounded, size: 11, color: cs.onPrimary),
                        ),
                        const SizedBox(width: 10),
                        Text('Thinking…', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                const SizedBox(height: 84),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, AppSpacing.lg),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant.withOpacity(0.35))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? Text(
                          'Tip: ask for “best settings” or “make it harder”.',
                          style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800),
                        )
                      : _quickPrompts(context),
                ),
                const SizedBox(width: 12),
                _micButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
