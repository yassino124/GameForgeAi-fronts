import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../core/services/templates_service.dart';

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

class _SiriWaveRing extends StatelessWidget {
  final double t;
  final Color color;
  final double intensity;

  const _SiriWaveRing({
    required this.t,
    required this.color,
    required this.intensity,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SiriWaveRingPainter(
        t: t,
        color: color,
        intensity: intensity,
      ),
    );
  }
}

class _SiriWaveRingPainter extends CustomPainter {
  final double t;
  final Color color;
  final double intensity;

  _SiriWaveRingPainter({
    required this.t,
    required this.color,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final baseR = size.shortestSide * 0.33;

    double wave(double ang, {required double speed, required double f1, required double f2, required double a1, required double a2}) {
      final p = t * math.pi * 2;
      return math.sin(ang * f1 + p * speed) * a1 + math.sin(ang * f2 - p * (speed * 0.72)) * a2;
    }

    void ring({required double r, required double alpha, required double amp, required double stroke}) {
      final path = Path();
      const steps = 260;
      for (var i = 0; i <= steps; i++) {
        final u = i / steps;
        final ang = u * math.pi * 2;
        final wobble = wave(
              ang,
              speed: 1.0,
              f1: 3.0,
              f2: 7.0,
              a1: amp * 0.75,
              a2: amp * 0.45,
            ) +
            wave(
              ang,
              speed: 1.7,
              f1: 2.0,
              f2: 9.0,
              a1: amp * 0.28,
              a2: amp * 0.20,
            );

        final rr = r + wobble;
        final p = Offset(
          c.dx + math.cos(ang) * rr,
          c.dy + math.sin(ang) * rr,
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [
            color.withOpacity(0.0),
            color.withOpacity(alpha),
            color.withOpacity(0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: GradientRotation(t * math.pi * 2),
        ).createShader(Offset.zero & size);

      canvas.drawPath(path, paint);
    }

    final amp = (size.shortestSide * 0.018) * intensity;
    ring(r: baseR * 1.03, alpha: 0.55, amp: amp * 1.25, stroke: 2.6);
    ring(r: baseR * 1.15, alpha: 0.28, amp: amp * 0.90, stroke: 2.0);
    ring(r: baseR * 1.28, alpha: 0.16, amp: amp * 0.70, stroke: 1.7);
  }

  @override
  bool shouldRepaint(covariant _SiriWaveRingPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.color != color || oldDelegate.intensity != intensity;
  }
}

class _AiCoachScreenState extends State<AiCoachScreen> with SingleTickerProviderStateMixin {
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();
  final _textController = TextEditingController();

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

  String _lastPrompt = '';

  Timer? _suggestDebounce;
  bool _loadingSuggestions = false;
  List<Map<String, dynamic>> _suggestions = const [];
  Map<String, dynamic>? _selectedTemplate;

  List<_CoachAction> _nextActions = const [];

  Timer? _projectPoll;
  String? _projectStatus;
  String? _projectBuildTarget;
  bool _hasWebgl = false;
  bool _hasApk = false;
  String? _previewUrl;

  Timer? _silenceTimer;

  Timer? _streamSpeakDebounce;
  int _spokenIdx = 0;
  bool _streamTtsBusy = false;
  bool _bargeIn = false;

  Timer? _focusTimer;
  bool _focusRunning = false;
  bool _focusOnBreak = false;
  int _focusRemainingSec = 0;

  static const int _focusWorkSec = 25 * 60;
  static const int _focusBreakSec = 5 * 60;

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
    _handsFree = true;
    Future.microtask(() async {
      if (!mounted) return;
      try {
        await _startListening();
      } catch (_) {}
    });
    _projectPoll = Timer.periodic(const Duration(seconds: 6), (_) {
      _refreshProject();
    });
  }

  Future<void> _loadTemplateSuggestions(String q) async {
    final query = q.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadingSuggestions = false;
        _suggestions = const [];
        _selectedTemplate = null;
      });
      return;
    }

    setState(() {
      _loadingSuggestions = true;
    });

    try {
      final res = await TemplatesService.listPublicTemplates(q: query);
      final raw = (res['success'] == true && res['data'] is List) ? (res['data'] as List) : const [];
      final items = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => ((e['_id'] ?? e['id'])?.toString() ?? '').trim().isNotEmpty)
          .take(6)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _suggestions = items;
        _loadingSuggestions = false;
        if (_selectedTemplate != null) {
          final sid = (_selectedTemplate!['_id'] ?? _selectedTemplate!['id'])?.toString() ?? '';
          final stillExists = _suggestions.any((t) => ((t['_id'] ?? t['id'])?.toString() ?? '') == sid);
          if (!stillExists) _selectedTemplate = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSuggestions = false;
      });
    }
  }

  Future<void> _sendTyped() async {
    if (_waitingReply) return;
    final raw = _textController.text.trim();
    if (raw.isEmpty) return;

    final text = raw;

    _textController.clear();
    _suggestDebounce?.cancel();
    if (!mounted) return;
    setState(() {
      _messages.add((role: 'user', text: text));
      _lastPrompt = text;
      _suggestions = const [];
      _loadingSuggestions = false;
    });

    await _sendToCoach(text);
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

    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
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
        if (url == null || url.isEmpty) {
          AppNotifier.showError('Missing preview url');
          return;
        }
        if (!mounted) return;
        context.push('/play-webgl', extra: {'url': url});
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

  Widget _powerActionsPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_waitingReply) return const SizedBox.shrink();

    final actions = _contextActions();
    final hasProject = widget.projectId != null && widget.projectId!.trim().isNotEmpty;
    if (!hasProject && actions.isEmpty) return const SizedBox.shrink();

    _CoachAction? byId(String id) {
      for (final a in actions) {
        if (a.id == id) return a;
      }
      return null;
    }

    Widget bigBtn({
      required IconData icon,
      required String label,
      required VoidCallback? onPressed,
      bool primary = false,
    }) {
      return AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final p = _pulse.value;
          final bg = primary ? cs.primary.withOpacity(0.16) : cs.surfaceContainerHighest.withOpacity(0.65);
          final border = primary
              ? cs.primary.withOpacity(0.55 + p * 0.18)
              : cs.outlineVariant.withOpacity(0.55);
          final fg = primary ? cs.primary : cs.onSurface;
          return FilledButton.tonal(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              backgroundColor: bg,
              foregroundColor: fg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: LinearGradient(
                      colors: [AppColors.accent.withOpacity(0.95), cs.primary.withOpacity(0.92)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      ...AppShadows.boxShadowSmall,
                      BoxShadow(
                        color: (primary ? cs.primary : AppColors.accent).withOpacity(0.10 + p * 0.10),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 18, color: cs.onPrimary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900, height: 1.1),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    final aPlay = byId('play_webgl');
    final aProgress = byId('open_progress');
    final aResults = byId('open_results');
    final aBuildWeb = byId('build_webgl');
    final aBuildApk = byId('build_apk');
    final aPreset = byId('preset_arcade_fast');

    final items = <Widget>[];
    if (aPlay != null) {
      items.add(bigBtn(icon: Icons.play_arrow_rounded, label: 'Play WebGL', onPressed: () => _runCoachAction(aPlay), primary: true));
    }
    if (aProgress != null) {
      items.add(bigBtn(icon: Icons.insights_rounded, label: 'Build progress', onPressed: () => _runCoachAction(aProgress)));
    }
    if (aResults != null) {
      items.add(bigBtn(icon: Icons.folder_open_rounded, label: 'Open results', onPressed: () => _runCoachAction(aResults)));
    }
    if (aBuildWeb != null) {
      items.add(bigBtn(icon: Icons.public_rounded, label: 'Build WebGL', onPressed: () => _runCoachAction(aBuildWeb)));
    }
    if (aBuildApk != null) {
      items.add(bigBtn(icon: Icons.android_rounded, label: 'Build APK', onPressed: () => _runCoachAction(aBuildApk)));
    }
    if (aPreset != null) {
      items.add(bigBtn(icon: Icons.bolt_rounded, label: 'Apply: Arcade Fast', onPressed: () => _runCoachAction(aPreset)));
    }
    items.add(
      bigBtn(
        icon: Icons.auto_awesome_rounded,
        label: 'Next 5 improvements',
        onPressed: _waitingReply
            ? null
            : () => _sendQuick('Review my project status and tell me the next 5 improvements to ship faster'),
      ),
    );
    items.add(
      bigBtn(
        icon: Icons.tune_rounded,
        label: 'Best runtime presets',
        onPressed: _waitingReply
            ? null
            : () => _sendQuick('Give me 3 best runtime presets for my GameForge project (Chill/Normal/Hardcore)'),
      ),
    );

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
          Text('Quick Actions', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900, color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final crossAxisCount = w >= 520 ? 3 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.65,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: items,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _glassPill({required Widget child, EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10)}) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.62),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _siriTopBar(BuildContext context, {required String title}) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final p = _pulse.value;
            return Stack(
              children: [
                _glassPill(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Icon(Icons.arrow_back_rounded, color: cs.onSurface, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [cs.primary.withOpacity(0.92), AppColors.accent.withOpacity(0.85)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(Icons.mic_rounded, color: cs.onPrimary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(
                              'Coach Guide • voice + live suggestions',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _waitingReply
                            ? null
                            : () {
                                _socket?.emit('coach:reset');
                                setState(() {
                                  _messages.clear();
                                  _draftAssistant = '';
                                  _draftUser = '';
                                });
                              },
                        child: Icon(
                          Icons.refresh_rounded,
                          color: _waitingReply ? cs.onSurface.withOpacity(0.35) : cs.onSurface,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.22,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Transform.translate(
                          offset: Offset((p * 2 - 1) * 80, 0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  cs.onSurface.withOpacity(0.12),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  int _lastSentenceBoundary(String s) {
    for (var i = s.length - 1; i >= 0; i--) {
      final c = s[i];
      if (c == '.' || c == '!' || c == '?' || c == '\n') return i + 1;
    }
    return -1;
  }

  int _lastWordBoundary(String s, {required int minIndexExclusive}) {
    for (var i = s.length - 1; i > minIndexExclusive; i--) {
      final c = s[i];
      if (c == ' ' || c == '\n' || c == '\t') return i + 1;
    }
    return -1;
  }

  void _scheduleStreamSpeak() {
    if (!_handsFree) return;
    if (!_waitingReply) return;
    if (_bargeIn) return;
    _streamSpeakDebounce?.cancel();
    _streamSpeakDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      if (!_waitingReply) return;
      if (_bargeIn) return;
      if (_streamTtsBusy || _speaking) return;

      final cur = _draftAssistant;
      if (cur.length <= _spokenIdx) return;

      var boundary = _lastSentenceBoundary(cur);
      if (boundary <= _spokenIdx + 18) {
        boundary = _lastWordBoundary(cur, minIndexExclusive: _spokenIdx + 26);
      }
      if (boundary <= _spokenIdx + 18) {
        final enoughUnspoken = (cur.length - _spokenIdx) >= 64;
        if (enoughUnspoken) {
          boundary = cur.length;
        }
      }
      if (boundary <= _spokenIdx + 18) return;

      final chunk = cur.substring(_spokenIdx, boundary).trim();
      if (chunk.isEmpty) {
        _spokenIdx = boundary;
        return;
      }

      _streamTtsBusy = true;
      _speak(chunk).whenComplete(() {
        if (!mounted) return;
        _spokenIdx = boundary;
        _streamTtsBusy = false;
        if (_waitingReply) {
          _scheduleStreamSpeak();
        }
      });
    });
  }

  Future<void> _bargeInListenNow() async {
    _bargeIn = true;
    _streamSpeakDebounce?.cancel();
    try {
      await _tts.stop();
    } catch (_) {}
    await _startListening();
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
    _suggestDebounce?.cancel();
    _streamSpeakDebounce?.cancel();
    _textController.dispose();
    _silenceTimer?.cancel();
    _projectPoll?.cancel();
    _focusTimer?.cancel();
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

  void _startFocus({required bool breakMode}) {
    _focusTimer?.cancel();
    setState(() {
      _focusRunning = true;
      _focusOnBreak = breakMode;
      _focusRemainingSec = breakMode ? _focusBreakSec : _focusWorkSec;
    });

    _focusTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (!_focusRunning) {
        t.cancel();
        return;
      }

      final next = _focusRemainingSec - 1;
      if (next <= 0) {
        t.cancel();
        setState(() {
          _focusRunning = true;
          _focusOnBreak = !_focusOnBreak;
          _focusRemainingSec = _focusOnBreak ? _focusBreakSec : _focusWorkSec;
        });
        if (_focusOnBreak) {
          AppNotifier.showSuccess('Break time (5 min)');
        } else {
          AppNotifier.showSuccess('Focus time (25 min)');
        }
        _startFocus(breakMode: _focusOnBreak);
        return;
      }

      setState(() => _focusRemainingSec = next);
    });
  }

  void _stopFocus() {
    _focusTimer?.cancel();
    setState(() {
      _focusRunning = false;
      _focusOnBreak = false;
      _focusRemainingSec = 0;
    });
  }

  String _fmtClock(int sec) {
    final s = sec.clamp(0, 1 << 30);
    final m = (s / 60).floor();
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  Widget _focusChip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = _focusRunning
        ? (_focusOnBreak ? 'BREAK ${_fmtClock(_focusRemainingSec)}' : 'FOCUS ${_fmtClock(_focusRemainingSec)}')
        : 'POMO 25/5';
    final selected = _focusRunning;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _waitingReply
          ? null
          : (_) {
              if (_focusRunning) {
                _stopFocus();
              } else {
                _startFocus(breakMode: false);
                AppNotifier.showSuccess('Focus time (25 min)');
              }
            },
      selectedColor: (_focusOnBreak ? AppColors.warning : cs.primary).withOpacity(0.18),
      backgroundColor: cs.surface.withOpacity(0.8),
      labelStyle: AppTypography.caption.copyWith(
        fontWeight: FontWeight.w900,
        color: selected ? (_focusOnBreak ? AppColors.warning : cs.primary) : cs.onSurfaceVariant,
      ),
      side: BorderSide(color: (selected ? (_focusOnBreak ? AppColors.warning : cs.primary) : cs.outlineVariant).withOpacity(0.55)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  List<String> _insights() {
    final status = (_projectStatus ?? '').trim().toLowerCase();
    final hasProject = widget.projectId != null && widget.projectId!.trim().isNotEmpty;
    if (!hasProject) {
      return const [
        'Link your project to unlock build-aware recommendations (WebGL/APK/Presets).',
        'Ask: “give me 3 presets (chill/normal/hardcore) for my game”.',
      ];
    }

    final out = <String>[];
    if (status == 'queued' || status == 'running') {
      out.add('While building: prepare 1 gameplay loop upgrade (combo, dash, double-jump, new enemy).');
      out.add('After build: publish to Arcade + add a short description + 3 tags for discovery.');
      return out;
    }
    if (status == 'failed') {
      out.add('Open build progress and copy the last error. Ask me: “fix this build error”.');
      out.add('Try switching build target (WebGL vs APK) to isolate platform-specific issues.');
      return out;
    }

    if (!_hasWebgl) out.add('Build WebGL so you can instantly play-test and share.' );
    if (!_hasApk) out.add('Build APK to test performance and controls on Android.' );
    out.add('Improve feel: tune speed + cameraZoom + jumpForce, then test 3 difficulties (Easy/Medium/Hard).');
    out.add('Polish: add neon palette (primary/secondary/accent) + stronger contrast for UI readability.');
    out.add('Retention: add daily challenge or “endless mode” with score + leaderboard later.');
    return out.take(4).toList(growable: false);
  }

  Widget _insightsCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tips = _insights();
    if (tips.isEmpty) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final p = _pulse.value;
        final glow = (0.14 + p * 0.10).clamp(0.0, 1.0);
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            border: Border.all(color: cs.primary.withOpacity(0.22 + p * 0.18)),
            boxShadow: [
              ...AppShadows.boxShadowSmall,
              BoxShadow(
                color: cs.primary.withOpacity(glow),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: AppColors.accent.withOpacity(0.10 + p * 0.10),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.95), cs.primary.withOpacity(0.92)]),
                      boxShadow: AppShadows.boxShadowSmall,
                    ),
                    child: Icon(Icons.auto_awesome_rounded, size: 16, color: cs.onPrimary),
                  ),
                  const SizedBox(width: 10),
                  Text('Improve next', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900, color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 10),
              ...tips.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [AppColors.accent, cs.primary]),
                        ),
                        child: Icon(Icons.bolt_rounded, size: 11, color: cs.onPrimary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(t, style: AppTypography.body2.copyWith(color: cs.onSurface, height: 1.35))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bgBlob({
    required Alignment alignment,
    required double size,
    required List<Color> colors,
    double dx = 0,
    double dy = 0,
  }) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final p = _pulse.value;
        final ox = dx * (p - 0.5) * 2;
        final oy = dy * (0.5 - p) * 2;
        return Align(
          alignment: alignment,
          child: Transform.translate(
            offset: Offset(ox, oy),
            child: IgnorePointer(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors[0].withOpacity(0.22 + p * 0.12),
                      colors[1].withOpacity(0.10 + p * 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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
      _spokenIdx = 0;
      _bargeIn = false;
      _streamSpeakDebounce?.cancel();
    });

    socket.on('coach:token', (data) {
      final t = (data is Map ? data['t'] : null)?.toString() ?? '';
      if (t.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _draftAssistant += t;
      });
      if (!_bargeIn) {
        _scheduleStreamSpeak();
      }
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

      _streamSpeakDebounce?.cancel();
      _bargeIn = false;
      if (text.isNotEmpty && _spokenIdx < text.length) {
        final rest = text.substring(_spokenIdx).trim();
        if (rest.isNotEmpty) {
          await _speak(rest);
        }
      }
      _spokenIdx = 0;
    });

    socket.on('coach:error', (data) {
      final msg = (data is Map ? data['message'] : null)?.toString() ?? 'Coach error';
      if (!mounted) return;
      setState(() {
        _waitingReply = false;
        _draftAssistant = '';
      });
      _bargeIn = false;
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
      pauseFor: const Duration(milliseconds: 900),
      onResult: (r) {
        if (!mounted) return;
        if (_waitingReply) return;
        setState(() => _draftUser = r.recognizedWords);
        _silenceTimer?.cancel();

        final text = r.recognizedWords.trim();
        final fast = r.finalResult && text.isNotEmpty;
        final delayMs = fast ? 150 : 600;

        _silenceTimer = Timer(Duration(milliseconds: delayMs), () {
          if (!mounted) return;
          if (_waitingReply) return;
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

    _lastPrompt = text;

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

    final tpl = _selectedTemplate;
    final templateId = tpl == null ? '' : ((tpl['_id'] ?? tpl['id'])?.toString() ?? '');
    final templateName = tpl == null ? '' : ((tpl['name'] ?? '').toString());

    _socket!.emit('coach:start', {
      'token': token,
      'text': text,
      if (widget.projectId != null && widget.projectId!.trim().isNotEmpty) 'projectId': widget.projectId,
      'locale': _lang,
      if (templateId.trim().isNotEmpty) 'templateId': templateId.trim(),
      if (templateName.trim().isNotEmpty) 'templateName': templateName.trim(),
    });
  }

  Widget _bubble(BuildContext context, {required String role, required String text}) {
    final cs = Theme.of(context).colorScheme;
    final isUser = role == 'user';
    final bg = isUser ? null : cs.surfaceContainerHighest.withOpacity(0.55);
    final fg = isUser ? cs.onPrimary : cs.onSurface;

    final bubble = AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final p = _pulse.value;
        final dy = isUser ? 0.0 : (-1.2 + p * 2.4);
        final glow = isUser ? 0.0 : (0.10 + p * 0.12);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: isUser ? AppColors.primaryGradient : null,
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: isUser ? null : Border.all(color: cs.primary.withOpacity(0.16 + p * 0.14)),
              boxShadow: isUser
                  ? AppShadows.boxShadowSmall
                  : [
                      ...AppShadows.boxShadowSmall,
                      BoxShadow(
                        color: cs.primary.withOpacity(glow),
                        blurRadius: 26,
                        offset: const Offset(0, 16),
                      ),
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.06 + p * 0.08),
                        blurRadius: 34,
                        offset: const Offset(0, 18),
                      ),
                    ],
            ),
            child: Text(
              text,
              style: AppTypography.body2.copyWith(color: fg, height: 1.35),
            ),
          ),
        );
      },
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
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    setState(() {
      _messages.add((role: 'user', text: t));
      _lastPrompt = t;
    });
    await _sendToCoach(t);
  }

  Widget _siriOverlay(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final show = _listening || _waitingReply;
    final label = _listening ? 'Listening…' : (_waitingReply ? 'Thinking…' : '');
    final prompt = _lastPrompt.trim();

    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: show ? 1 : 0,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final p = _pulse.value;
            final orbSize = 300.0 + p * 70.0;
            final glow = 0.22 + p * 0.35;
            final ringSize = orbSize + 46.0 + p * 28.0;
            final waveColor = _listening ? cs.primary : cs.secondary;
            final waveIntensity = _listening ? 1.0 : 0.65;

            Future<void> onTapOrb() async {
              if (_waitingReply) return;
              if (_speaking) {
                await _bargeInListenNow();
                return;
              }
              if (_listening) {
                await _stopListeningAndSend();
              } else {
                await _startListening();
              }
            }

            return Stack(
              children: [
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(color: Colors.black.withOpacity(0.22)),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: onTapOrb,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            IgnorePointer(
                              child: SizedBox(
                                width: ringSize,
                                height: ringSize,
                                child: _SiriWaveRing(
                                  t: p,
                                  color: waveColor,
                                  intensity: waveIntensity,
                                ),
                              ),
                            ),
                            Container(
                              width: ringSize,
                              height: ringSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    cs.primary.withOpacity(0.0),
                                    cs.primary.withOpacity(0.10 + p * 0.10),
                                    cs.secondary.withOpacity(0.06 + p * 0.10),
                                    cs.secondary.withOpacity(0.0),
                                  ],
                                  stops: const [0.0, 0.55, 0.80, 1.0],
                                  radius: 0.95,
                                ),
                              ),
                            ),
                            Container(
                              width: orbSize,
                              height: orbSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.accent.withOpacity(0.80),
                                    cs.primary.withOpacity(0.62),
                                    cs.secondary.withOpacity(0.52),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.34, 0.62, 1.0],
                                  radius: 0.92,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.primary.withOpacity(glow),
                                    blurRadius: 64,
                                    spreadRadius: 6,
                                    offset: const Offset(0, 22),
                                  ),
                                  BoxShadow(
                                    color: AppColors.accent.withOpacity(0.16 + p * 0.16),
                                    blurRadius: 88,
                                    spreadRadius: 8,
                                    offset: const Offset(0, 26),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 108,
                                  height: 108,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: cs.surface.withOpacity(0.26),
                                    border: Border.all(color: cs.onSurface.withOpacity(0.10 + p * 0.10)),
                                  ),
                                  child: Icon(
                                    _listening ? Icons.stop_rounded : Icons.mic_rounded,
                                    color: cs.onSurface,
                                    size: 44,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        label,
                        style: AppTypography.subtitle1.copyWith(
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                        ),
                      ),
                      if (prompt.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            prompt,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppTypography.body2.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _typingIndicator(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final p = _pulse.value;
        final a1 = (p).clamp(0.0, 1.0);
        final a2 = ((p + 0.33) % 1.0).clamp(0.0, 1.0);
        final a3 = ((p + 0.66) % 1.0).clamp(0.0, 1.0);

        Widget dot(double a) {
          final s = 6.0 + a * 3.0;
          return Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.onSurfaceVariant.withOpacity(0.55 + a * 0.35),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.accent, cs.primary]),
                ),
                child: Icon(Icons.auto_awesome_rounded, size: 11, color: cs.onPrimary),
              ),
              const SizedBox(width: 10),
              dot(a1),
              const SizedBox(width: 6),
              dot(a2),
              const SizedBox(width: 6),
              dot(a3),
              const SizedBox(width: 10),
              Text('Coach typing', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w900)),
            ],
          ),
        );
      },
    );
  }

  Widget _quickPrompts(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final prompts = <String>[
      'Give me 3 best runtime presets for my GameForge project (Chill/Normal/Hardcore)',
      'What should I do next in GameForge to publish/play faster?',
      'Review my project status and tell me the next 5 improvements to ship faster',
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
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _listening
            ? LinearGradient(colors: [cs.error.withOpacity(0.92), cs.error.withOpacity(0.68)])
            : LinearGradient(
                colors: [AppColors.accent.withOpacity(0.95), cs.primary.withOpacity(0.92)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: [
          BoxShadow(
            color: (_listening ? cs.error : cs.primary).withOpacity(0.24),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: AppColors.accent.withOpacity(_listening ? 0.10 : 0.18),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Icon(
        _listening ? Icons.stop_rounded : Icons.mic_rounded,
        color: cs.onPrimary,
        size: 30,
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
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final p = _pulse.value;
                final ring = _listening ? cs.error : cs.primary;
                final t = _waitingReply ? 0.35 : 1.0;
                return IgnorePointer(
                  child: Opacity(
                    opacity: t,
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [ring.withOpacity(0.16 + p * 0.10), Colors.transparent],
                          radius: 0.9,
                        ),
                        border: Border.all(color: ring.withOpacity(0.20 + p * 0.20)),
                      ),
                    ),
                  ),
                );
              },
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
    final topPad = MediaQuery.of(context).padding.top + 128;

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
      body: Stack(
        children: [
          Positioned.fill(
            child: Stack(
              children: [
                _bgBlob(
                  alignment: Alignment.topLeft,
                  size: 520,
                  colors: [cs.primary, AppColors.accent],
                  dx: 26,
                  dy: 22,
                ),
                _bgBlob(
                  alignment: Alignment.bottomRight,
                  size: 640,
                  colors: [AppColors.accent, cs.secondary],
                  dx: 30,
                  dy: 28,
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withOpacity(0.10),
                    Colors.transparent,
                    Colors.black.withOpacity(0.10),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeIn,
                    child: (_listening || _waitingReply)
                        ? const SizedBox.shrink()
                        : ListView(
                            padding: EdgeInsets.fromLTRB(AppSpacing.lg, topPad, AppSpacing.lg, 140),
                            children: [
                              if (_messages.isEmpty && _draftAssistant.isEmpty && _draftUser.isEmpty) ...[
                                _glassPill(
                                  padding: const EdgeInsets.all(16),
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
                              _insightsCard(context),
                              _powerActionsPanel(context),
                              _contextActionsBar(context),
                              _nextActionsBar(context),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(child: _siriOverlay(context)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              children: [
                _siriTopBar(context, title: header),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _statusPill(context),
                        const SizedBox(width: 10),
                        _handsFreeChip(context),
                        const SizedBox(width: 8),
                        _focusChip(context),
                        const SizedBox(width: 8),
                        _langChip(context, value: 'tn', label: 'TN'),
                        const SizedBox(width: 8),
                        _langChip(context, value: 'fr', label: 'FR'),
                        const SizedBox(width: 8),
                        _langChip(context, value: 'en', label: 'EN'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _listening
                            ? 'Listening…'
                            : (_waitingReply
                                ? 'Thinking…'
                                : (_handsFree ? 'LIVE • Talk to Coach' : 'Tap mic to talk')),
                        style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 14),
                    _micButton(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
