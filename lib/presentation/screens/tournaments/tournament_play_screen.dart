import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/services/coach_tutor_service.dart';
import '../../../core/services/tournaments_service.dart';

class TournamentPlayScreen extends StatefulWidget {
  final String tournamentId;

  const TournamentPlayScreen({
    super.key,
    required this.tournamentId,
  });

  @override
  State<TournamentPlayScreen> createState() => _TournamentPlayScreenState();
}

class _PressScale extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _PressScale({
    required this.child,
    required this.enabled,
  });

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled;
    final scale = active ? (_down ? 0.98 : 1.0) : 1.0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapUp: active ? (_) => setState(() => _down = false) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _TournamentPlayScreenState extends State<TournamentPlayScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _detail;
  String? _playUrl;
  String _playerName = 'Falcon42';

  int? _lastScore;
  int? _lastDurationSec;
  bool _submitBusy = false;

  bool _tutorBusy = false;
  String? _activeTutorTip;
  final FlutterTts _tts = FlutterTts();
  Timer? _realtimeTutorTimer;
  Map<String, dynamic>? _lastTutorResponse;
  Map<String, bool> _completedChallenges = {};
  bool _autoReadTutor = true;
  Map<String, dynamic>? _previousConfig;
  final List<Map<String, dynamic>> _tutorLastRuns = <Map<String, dynamic>>[];

  Timer? _poll;

  WebViewController? _controller;

  bool _showFinishOverlay = false;
  bool _finishHapticsFired = false;

  late final AnimationController _fxCtrl;

  String? get _token {
    try {
      final t = context.read<AuthProvider>().token;
      if (t == null || t.trim().isEmpty) return null;
      return t;
    } catch (_) {
      return null;
    }
  }

  String get _authUserId {
    try {
      final u = context.read<AuthProvider>().user;
      return (u?['id'] ?? u?['_id'] ?? u?['sub'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  Map<String, dynamic>? _myTop3Row(Map<String, dynamic>? detail) {
    final me = _authUserId;
    if (me.isEmpty) return null;
    final top3 = detail?['top3'];
    if (top3 is! List) return null;
    for (final r in top3) {
      if (r is! Map) continue;
      final m = Map<String, dynamic>.from(r);
      final pid = (m['playerId'] ?? m['userId'] ?? '').toString().trim();
      if (pid == me) return m;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _fxCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _loadDetail(silent: true));
    _startRealtimeTutor();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _realtimeTutorTimer?.cancel();
    _fxCtrl.dispose();
    super.dispose();
  }

  int _asInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  Future<void> _bootstrap() async {
    final token = _token;
    if (token == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Please sign in first';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _loadDetail();

      final res = await TournamentsService.playUrl(token: token, tournamentId: widget.tournamentId);
      final data = res['data'] ?? res;
      final url = (data is Map ? (data['url'] ?? '') : '').toString().trim();
      if (url.isEmpty) throw Exception('Missing play url');

      if (!mounted) return;
      setState(() => _playUrl = url);

      await _initWebView(url);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to start tournament';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _initWebView(String url) async {
    final c = WebViewController();
    c
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'GFBridge',
        onMessageReceived: (msg) {
          _onBridgeMessage(msg.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() => _error = 'WebView error');
          },
        ),
      );

    await c.loadRequest(Uri.parse(url));

    await c.runJavaScript('''
      (function(){
        try {
          function safePost(payload){
            try { GFBridge.postMessage(JSON.stringify(payload)); } catch(e) {}
          }
          window.addEventListener('message', function(ev){
            var data = ev && ev.data;
            if (!data) return;
            if (typeof data === 'string') {
              try { data = JSON.parse(data); } catch(e) {}
            }
            safePost({ kind: 'window_message', data: data });
          });

          window.GameForgeMobile = {
            submitScore: function(score, durationSec){
              safePost({ kind: 'submit_score', score: score, durationSec: durationSec });
            },
            ping: function(v){ safePost({ kind: 'ping', v: v }); }
          };

          safePost({ kind: 'ready' });
        } catch(e) {}
      })();
    ''');

    if (!mounted) return;
    setState(() => _controller = c);
  }

  Future<void> _loadDetail({bool silent = false}) async {
    final token = _token;
    if (token == null) return;

    try {
      final res = await TournamentsService.getTournament(token: token, tournamentId: widget.tournamentId);
      final raw = res['data'] ?? res;
      final map = raw is Map ? Map<String, dynamic>.from(raw as Map) : null;
      if (!mounted) return;
      setState(() => _detail = map);

      final status = (map?['status'] ?? '').toString().toLowerCase().trim();
      if (status == 'finished' && !_showFinishOverlay) {
        setState(() {
          _showFinishOverlay = true;
          _finishHapticsFired = false;
        });
        _stopWebView();
      }
    } catch (_) {
      if (!mounted || silent) return;
      setState(() => _error = 'Failed to refresh tournament');
    }
  }

  Future<void> _stopWebView() async {
    try {
      await _controller?.loadHtmlString('<html><body style="background:#000"></body></html>');
    } catch (_) {}
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _tts.setLanguage("en-US");
      await _tts.setPitch(1.0);
      await _tts.speak(text);
    } catch (_) {}
  }

  void _recordTutorRun(Map<String, dynamic>? run) {
    if (run == null || run.isEmpty) return;
    final entry = <String, dynamic>{
      ...run,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    _tutorLastRuns.insert(0, entry);
    if (_tutorLastRuns.length > 8) {
      _tutorLastRuns.removeRange(8, _tutorLastRuns.length);
    }
  }

  void _applyTweak(Map<String, dynamic> tweak) {
    final key = (tweak['key'] ?? '').toString();
    final val = tweak['value'];
    if (key.isEmpty || val == null) return;

    // In Tournament, we apply via JS injection as there's no project config persistence
    final js = "window.runtimeConfig = window.runtimeConfig || {}; window.runtimeConfig['$key'] = $val;";
    _controller?.runJavaScript(js);
    AppNotifier.showSuccess('Coach applied: $key = $val');
  }

  void _startRealtimeTutor() {
    _realtimeTutorTimer?.cancel();
    _realtimeTutorTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted || _tutorBusy) return;
      final token = _token;
      if (token == null) return;

      final res = await CoachTutorService.tutor(
        token: token,
        gameId: widget.tournamentId,
        gameType: 'tournament',
        run: {
          if (_lastScore != null) 'currentScore': _lastScore,
          'tournamentId': widget.tournamentId,
        },
        lastRuns: List<dynamic>.from(_tutorLastRuns),
      );

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final tips = data['tips'] as List?;
        if (tips != null && tips.isNotEmpty) {
          final firstTip = tips.first['tip']?.toString();
          if (firstTip != null) {
            setState(() {
              _activeTutorTip = firstTip;
              _lastTutorResponse = data;
            });
            if (_autoReadTutor) _speak(firstTip);
          }
        }
      }
    });
  }

  Future<void> _openTutorSheet() async {
    if (_tutorBusy) return;
    final token = _token;
    if (token == null) {
      AppNotifier.showError('Sign in required');
      return;
    }

    setState(() => _tutorBusy = true);
    Map<String, dynamic> tutor;
    try {
      final res = await CoachTutorService.tutor(
        token: token,
        gameId: widget.tournamentId,
        gameType: 'tournament',
        userStyle: 'auto',
        run: {
          if (_lastScore != null) 'currentScore': _lastScore,
          if (_lastDurationSec != null) 'durationSec': _lastDurationSec,
          'tournamentId': widget.tournamentId,
        },
        currentConfig: const <String, dynamic>{},
        lastRuns: List<dynamic>.from(_tutorLastRuns),
        timeout: const Duration(seconds: 90),
      );

      if (res['success'] != true) {
        AppNotifier.showError(res['message']?.toString() ?? 'Tutor failed');
        return;
      }
      final data = res['data'];
      if (data is! Map) {
        AppNotifier.showError('Tutor failed');
        return;
      }
      tutor = Map<String, dynamic>.from(data as Map);
    } catch (e) {
      AppNotifier.showError(e.toString());
      return;
    } finally {
      if (mounted) setState(() => _tutorBusy = false);
    }

    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final tips = (tutor['tips'] is List)
            ? List<Map<String, dynamic>>.from(
                (tutor['tips'] as List)
                    .where((e) => e is Map)
                    .map((e) => Map<String, dynamic>.from(e as Map)),
              )
            : const <Map<String, dynamic>>[];
        final micro = (tutor['microChallenges'] is List)
            ? List<Map<String, dynamic>>.from(
                (tutor['microChallenges'] as List)
                    .where((e) => e is Map)
                    .map((e) => Map<String, dynamic>.from(e as Map)),
              )
            : const <Map<String, dynamic>>[];
        final tweaks = (tutor['controlTweaks'] is List)
            ? List<Map<String, dynamic>>.from(
                (tutor['controlTweaks'] as List)
                    .where((e) => e is Map)
                    .map((e) => Map<String, dynamic>.from(e as Map)),
              )
            : const <Map<String, dynamic>>[];

        Color accent() => cs.primary;

        IconData sectionIcon(String title) {
          final x = title.toLowerCase();
          if (x.contains('tip')) return Icons.lightbulb_rounded;
          if (x.contains('micro')) return Icons.flag_rounded;
          if (x.contains('tweak')) return Icons.tune_rounded;
          return Icons.auto_awesome_rounded;
        }

        Widget sectionTitle(String t) => Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          accent().withOpacity(0.22),
                          Colors.white.withOpacity(0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: accent().withOpacity(0.28),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      sectionIcon(t),
                      size: 18,
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t,
                      style: AppTypography.subtitle1.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withOpacity(0.96),
                      ),
                    ),
                  ),
                ],
              ),
            );

        Widget card({required Widget child}) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0B1220).withOpacity(0.82),
                    const Color(0xFF111B2E).withOpacity(0.76),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: accent().withOpacity(0.20),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: accent().withOpacity(0.14),
                    blurRadius: 44,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: child,
                  ),
                ),
              ),
            );

        Widget finalWhy(Map<String, dynamic> t) {
          final why = (t['why'] ?? '').toString().trim();
          if (why.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              why,
              style: AppTypography.caption.copyWith(
                color: Colors.white.withOpacity(0.70),
              ),
            ),
          );
        }

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF070A12).withOpacity(0.82),
                  const Color(0xFF0C1120).withOpacity(0.76),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: accent().withOpacity(0.28), width: 1.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Material(
                  color: Colors.transparent,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: 18 + MediaQuery.of(ctx).viewInsets.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Center(
                          child: Container(
                            width: 46,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: LinearGradient(
                                    colors: [
                                      accent().withOpacity(0.25),
                                      Colors.white.withOpacity(0.06),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: accent().withOpacity(0.28),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.psychology_rounded,
                                  color: Colors.white.withOpacity(0.94),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'AI Game Tutor',
                                  style: AppTypography.titleLarge.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white.withOpacity(0.84),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(
                                'Auto-read tips',
                                style: AppTypography.caption.copyWith(color: Colors.white70),
                              ),
                              const Spacer(),
                              Switch.adaptive(
                                value: _autoReadTutor,
                                onChanged: (v) => setState(() => _autoReadTutor = v),
                                activeColor: accent(),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            'Tournament-aware tips based on your latest attempt.',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white.withOpacity(0.70),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        if (_tutorLastRuns.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
                            child: Row(
                              children: [
                                Text(
                                  'Runs analyzed: ${_tutorLastRuns.length}',
                                  style: AppTypography.caption.copyWith(
                                    color: Colors.white.withOpacity(0.72),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Challenges done: ${_completedChallenges.values.where((v) => v == true).length}',
                                  style: AppTypography.caption.copyWith(
                                    color: Colors.white.withOpacity(0.72),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (tips.isNotEmpty) ...[
                          sectionTitle('Tips'),
                          for (final t in tips)
                            card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.bolt_rounded,
                                        color: accent().withOpacity(0.95),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          (t['title'] ?? '').toString(),
                                          style: AppTypography.subtitle2.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () =>
                                            _speak((t['tip'] ?? '').toString()),
                                        icon: Icon(
                                          Icons.volume_up_rounded,
                                          color: Colors.white.withOpacity(0.78),
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    (t['tip'] ?? '').toString(),
                                    style: AppTypography.body2.copyWith(
                                      color: Colors.white.withOpacity(0.92),
                                      height: 1.25,
                                    ),
                                  ),
                                  finalWhy(t),
                                ],
                              ),
                            ),
                        ],

                        if (micro.isNotEmpty) ...[
                          sectionTitle('Micro-challenges'),
                          for (final m in micro)
                            card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.emoji_events_rounded,
                                        color: Colors.amberAccent.withOpacity(0.95),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          (m['title'] ?? '').toString(),
                                          style: AppTypography.subtitle2.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    (m['objective'] ?? '').toString(),
                                    style: AppTypography.body2.copyWith(
                                      color: Colors.white.withOpacity(0.92),
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    (m['successMetric'] ?? '').toString(),
                                    style: AppTypography.caption.copyWith(
                                      color: Colors.white.withOpacity(0.72),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: _completedChallenges[m['title']] == true ? 1.0 : 0.3,
                                      backgroundColor: Colors.white10,
                                      color: _completedChallenges[m['title']] == true ? Colors.greenAccent : accent(),
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      if (_completedChallenges[m['title']] == true)
                                        const Text('Completed ✅', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
                                      else
                                        ElevatedButton(
                                          onPressed: () {
                                            setState(() => _completedChallenges[m['title'].toString()] = true);
                                            AppNotifier.showSuccess('Challenge marked as completed!');
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: accent().withOpacity(0.2),
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Complete'),
                                        ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: () => setState(() => _completedChallenges.remove(m['title'])),
                                        child: const Text('Reset', style: TextStyle(color: Colors.white54)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],

                        if (tweaks.isNotEmpty) ...[
                          sectionTitle('Suggested tweaks'),
                          for (final tw in tweaks)
                            card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.tune_rounded,
                                        color: Colors.cyanAccent.withOpacity(0.90),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          (tw['label'] ?? tw['key'] ?? '').toString(),
                                          style: AppTypography.subtitle2.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(999),
                                          color: Colors.white.withOpacity(0.08),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.12),
                                          ),
                                        ),
                                        child: Text(
                                          'Suggestion',
                                          style: AppTypography.caption.copyWith(
                                            color: Colors.white.withOpacity(0.75),
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '→ ${(tw['value'] ?? '').toString()}',
                                    style: AppTypography.body2.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white.withOpacity(0.92),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    (tw['reason'] ?? '').toString(),
                                    style: AppTypography.caption.copyWith(
                                      color: Colors.white.withOpacity(0.72),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => _applyTweak(tw),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accent().withOpacity(0.20),
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Apply'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],

                        if (tips.isEmpty && micro.isEmpty && tweaks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              'Tutor returned no suggestions for this run.',
                              style: AppTypography.body2.copyWith(
                                color: Colors.white.withOpacity(0.70),
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onBridgeMessage(String raw) {
    debugPrint('🎮 Bridge Message: $raw');
    try {
      final msg = jsonDecode(raw);
      if (msg is! Map) return;

       // Preferred bridge format from injected JS: { kind: 'submit_score', score, durationSec }
       final kind = (msg['kind'] ?? '').toString().trim().toLowerCase();
       if (kind == 'submit_score') {
         final s = _asInt(msg['score'] ?? msg['data']);
         final d = _asInt(msg['durationSec'] ?? msg['duration'] ?? 0);
         if (s > 0) {
           _submit(score: s, durationSec: d);
         }
         return;
       }

      final type = (msg['type'] ?? msg['event'] ?? '').toString().toUpperCase();
      if (type == 'SCORE_POST' || type == 'GAME_OVER' || type == 'FINISH') {
        final s = _asInt(msg['score'] ?? msg['data']);
        final d = _asInt(msg['durationSec'] ?? msg['duration'] ?? 0);
        if (s > 0) {
          _submit(score: s, durationSec: d);
        }
      }
    } catch (_) {}
  }

  void _injectControlEvent(String key, bool isDown) {
    if (_controller == null) return;
    final type = isDown ? 'keydown' : 'keyup';
    final js = """
      (function() {
        const e = new KeyboardEvent('$type', {
          key: '$key',
          keyCode: ${_getKeyCode(key)},
          which: ${_getKeyCode(key)},
          code: '${_getEventCode(key)}',
          bubbles: true
        });
        document.dispatchEvent(e);
      })();
    """;
    _controller!.runJavaScript(js);
    if (isDown) HapticFeedback.selectionClick();
  }

  int _getKeyCode(String key) {
    switch (key) {
      case 'ArrowUp': return 38;
      case 'ArrowDown': return 40;
      case 'ArrowLeft': return 37;
      case 'ArrowRight': return 39;
      case 'Space': return 32;
      case 'x': return 88;
      case 'z': return 90;
      default: return 0;
    }
  }

  String _getEventCode(String key) {
    switch (key) {
      case 'ArrowUp': return 'ArrowUp';
      case 'ArrowDown': return 'ArrowDown';
      case 'ArrowLeft': return 'ArrowLeft';
      case 'ArrowRight': return 'ArrowRight';
      case 'Space': return 'Space';
      case 'x': return 'KeyX';
      case 'z': return 'KeyZ';
      default: return '';
    }
  }

  Widget _gamepadButton(String key, IconData icon, {double size = 56, Color? color}) {
    return Listener(
      onPointerDown: (_) => _injectControlEvent(key, true),
      onPointerUp: (_) => _injectControlEvent(key, false),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (color ?? Colors.white).withOpacity(0.12),
          border: Border.all(color: (color ?? Colors.white).withOpacity(0.25)),
        ),
        child: Icon(icon, color: color ?? Colors.white, size: size * 0.5),
      ),
    );
  }

  Widget _buildGamepad() {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // D-Pad
          Column(
            children: [
              _gamepadButton('ArrowUp', Icons.keyboard_arrow_up_rounded),
              Row(
                children: [
                  _gamepadButton('ArrowLeft', Icons.keyboard_arrow_left_rounded),
                  const SizedBox(width: 40),
                  _gamepadButton('ArrowRight', Icons.keyboard_arrow_right_rounded),
                ],
              ),
              _gamepadButton('ArrowDown', Icons.keyboard_arrow_down_rounded),
            ],
          ),
          // Action Buttons
          Row(
            children: [
              _gamepadButton('z', Icons.abc, color: const Color(0xFF38BDF8)),
              const SizedBox(width: 20),
              _gamepadButton('Space', Icons.ads_click_rounded, color: const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit({required int score, required int durationSec}) async {
    final token = _token;
    if (token == null) return;

    final uid = _authUserId;
    if (uid.isEmpty) {
      AppNotifier.showError('Sign in required');
      return;
    }

    if (_submitBusy) return;

    setState(() {
      _submitBusy = true;
      _lastScore = score;
      _lastDurationSec = durationSec;
    });

    _recordTutorRun(<String, dynamic>{
      'currentScore': score,
      'durationSec': durationSec,
      'tournamentId': widget.tournamentId,
    });

    try {
      await TournamentsService.submitScore(
        token: token,
        tournamentId: widget.tournamentId,
        userId: uid,
        playerName: _playerName.trim().isEmpty ? uid : _playerName.trim(),
        score: score,
        durationSec: durationSec,
      );

      AppNotifier.showSuccess('Score submitted');
      await _loadDetail();
    } catch (_) {
      AppNotifier.showError('Submit failed');
    } finally {
      if (mounted) setState(() => _submitBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    final title = (d?['title'] ?? 'Tournament').toString();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final myTop3 = _myTop3Row(d);
    final myRank = myTop3 == null ? null : _asInt(myTop3['rank'], 0);
    final myCoinsWon = myTop3 == null ? null : myTop3['coinsWon'];
    final myCoinsWonInt = myCoinsWon is num ? myCoinsWon.toInt() : int.tryParse(myCoinsWon?.toString() ?? '');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/tournaments');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'AI Tutor',
            onPressed: _tutorBusy ? null : _openTutorSheet,
            icon: Icon(
              _tutorBusy
                  ? Icons.hourglass_top_rounded
                  : Icons.psychology_alt_rounded,
            ),
          ),
          IconButton(
            onPressed: _loading ? null : () => _loadDetail(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_playUrl != null && _controller != null)
            WebViewWidget(controller: _controller!)
          else if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error ?? 'Unable to load game',
                  style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          if (_activeTutorTip != null)
            Positioned(
              bottom: 120,
              left: 24,
              right: 24,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 500),
                tween: Tween(begin: 0, end: 1),
                builder: (context, val, child) {
                  return Opacity(
                    opacity: val,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - val)),
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _openTutorSheet,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0F172A).withOpacity(0.95),
                          const Color(0xFF1E293B).withOpacity(0.90),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.psychology_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _activeTutorTip!,
                            style: AppTypography.body2.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.volume_up_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                          onPressed: () => _speak(_activeTutorTip!),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _activeTutorTip = null),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Virtual Gamepad Controls
          if (_playUrl != null && _controller != null && !_showFinishOverlay)
            _buildGamepad(),

          if (_lastScore != null)
            Positioned(
              left: 14,
              top: 14,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(isDark ? 0.30 : 0.10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LAST SCORE', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        _AnimatedCount(
                          value: _lastScore ?? 0,
                          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900),
                          duration: const Duration(milliseconds: 520),
                        ),
                        if (_lastDurationSec != null)
                          Text(
                            '${_lastDurationSec}s',
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_submitBusy)
            Positioned(
              right: 14,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Text('Submitting…', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),

          if (_showFinishOverlay)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _fxCtrl,
                builder: (context, _) {
                  final t = _fxCtrl.value;

                  if (!_finishHapticsFired) {
                    _finishHapticsFired = true;
                    if (myRank != null && myRank > 0 && myRank <= 3) {
                      HapticFeedback.heavyImpact();
                    } else {
                      HapticFeedback.mediumImpact();
                    }
                  }

                  return GestureDetector(
                    onTap: () => setState(() => _showFinishOverlay = false),
                    child: Container(
                      color: Colors.black.withOpacity(0.80),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _ConfettiPainter(progress: t),
                              ),
                            ),
                          ),
                          Center(
                            child: TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 620),
                              tween: Tween(begin: 0, end: 1),
                              curve: Curves.easeOutBack,
                              builder: (context, v, child) {
                                final o = (v).clamp(0.0, 1.0);
                                return Opacity(
                                  opacity: o,
                                  child: Transform.scale(
                                    scale: 0.92 + 0.08 * o,
                                    child: child,
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.all(18),
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFF59E0B).withOpacity(0.20),
                                      const Color(0xFF38BDF8).withOpacity(0.14),
                                      Colors.black.withOpacity(0.55),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFF59E0B).withOpacity(0.14),
                                      blurRadius: 52,
                                      offset: const Offset(0, 28),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: Center(
                                          child: Transform.rotate(
                                            angle: t * 2 * math.pi,
                                            child: Container(
                                              width: 230,
                                              height: 230,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: RadialGradient(
                                                  colors: [
                                                    const Color(0xFF38BDF8).withOpacity(0.10),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(22),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 14,
                                              sigmaY: 14,
                                            ),
                                            child: Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(22),
                                                border: Border.all(
                                                  color: Colors.white.withOpacity(0.10),
                                                ),
                                                color: AppColors.surface.withOpacity(0.60),
                                              ),
                                              child: Column(
                                                children: [
                                                  Stack(
                                                    alignment: Alignment.center,
                                                    children: [
                                                      AnimatedBuilder(
                                                        animation: _fxCtrl,
                                                        builder: (context, _) {
                                                          final p = _fxCtrl.value;
                                                          final o = (0.10 + 0.20 * (1 - (p - 0.5).abs() * 2))
                                                              .clamp(0.0, 0.30);
                                                          return Container(
                                                            width: 110,
                                                            height: 110,
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              gradient: RadialGradient(
                                                                colors: [
                                                                  const Color(0xFFF59E0B).withOpacity(o),
                                                                  const Color(0xFF38BDF8).withOpacity(o * 0.55),
                                                                  Colors.transparent,
                                                                ],
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                      const Icon(
                                                        Icons.emoji_events_rounded,
                                                        size: 56,
                                                        color: Color(0xFFF59E0B),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Text(
                                                    myRank != null &&
                                                            myRank > 0 &&
                                                            myRank <= 3
                                                        ? 'Winner Confirmed'
                                                        : 'Tournament Finished',
                                                    style: AppTypography.titleLarge
                                                        .copyWith(
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        if (myRank != null && myRank > 0 && myRank <= 3) ...[
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(18),
                                              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.40)),
                                              gradient: LinearGradient(
                                                colors: [
                                                  const Color(0xFFF59E0B).withOpacity(0.22),
                                                  const Color(0xFF38BDF8).withOpacity(0.12),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 34,
                                                  height: 34,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: const Color(0xFFF59E0B).withOpacity(0.18),
                                                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.45)),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '#$myRank',
                                                      style: AppTypography.body2.copyWith(
                                                        fontWeight: FontWeight.w900,
                                                        color: const Color(0xFFF59E0B),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Prize credited',
                                                        style: AppTypography.caption.copyWith(
                                                          fontWeight: FontWeight.w900,
                                                          letterSpacing: 0.8,
                                                          color: AppColors.textPrimary,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        myCoinsWonInt == null ? 'Check details for payout' : '${myCoinsWonInt.toString()} coins → USD wallet',
                                                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'You finished in the top 3. Your USD payout is on the way to your Creator Wallet.',
                                            style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
                                            textAlign: TextAlign.center,
                                          ),
                                        ] else ...[
                                          Text(
                                            'Prizes are credited as USD in your Creator Wallet.',
                                            style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                        const SizedBox(height: 14),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _PressScale(
                                                enabled: true,
                                                child: OutlinedButton(
                                                  onPressed: () {
                                                    HapticFeedback.selectionClick();
                                                    setState(() => _showFinishOverlay = false);
                                                  },
                                                  child: const Text('Back'),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _PressScale(
                                                enabled: true,
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    HapticFeedback.lightImpact();
                                                    setState(() => _showFinishOverlay = false);
                                                    context.push('/tournaments/${widget.tournamentId}');
                                                  },
                                                  child: const Text('Details'),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border.withOpacity(0.8))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => _playerName = v,
                  decoration: InputDecoration(
                    hintText: 'Nickname',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: _PressScale(
                  enabled: !(_submitBusy || _lastScore == null),
                  child: ElevatedButton.icon(
                    onPressed: _submitBusy || _lastScore == null
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            _submit(score: _lastScore ?? 0, durationSec: _lastDurationSec ?? 0);
                          },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Send'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;

  _ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final count = 120;
    final colors = <Color>[
      const Color(0xFFF59E0B),
      const Color(0xFF38BDF8),
      const Color(0xFF10B981),
      const Color(0xFFA78BFA),
      const Color(0xFFF472B6),
    ];

    for (int i = 0; i < count; i++) {
      final seed = rnd.nextDouble();
      final x = rnd.nextDouble() * size.width;
      final baseY = rnd.nextDouble() * size.height;
      final drift = (rnd.nextDouble() - 0.5) * 80;
      final y = (baseY + (progress * 520) + i * 2) % (size.height + 120) - 60;
      final rot = (progress * 2 * math.pi) + seed * 6.0;
      final w = 6 + rnd.nextDouble() * 6;
      final h = 10 + rnd.nextDouble() * 14;
      final c = colors[i % colors.length].withOpacity(0.72);

      final paint = Paint()..color = c;
      canvas.save();
      canvas.translate(x + drift * math.sin(progress * 2 * math.pi + seed), y);
      canvas.rotate(rot);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(3),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle style;
  final Duration duration;

  const _AnimatedCount({
    required this.value,
    required this.style,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Text(v.round().toString(), style: style);
      },
    );
  }
}
