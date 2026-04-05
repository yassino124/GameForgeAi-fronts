import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/services/multiplayer_controller.dart';
import '../../../core/services/projects_service.dart';
import '../../../core/services/trailers_service.dart';
import '../../widgets/widgets.dart';

class PlayWebglScreen extends StatefulWidget {
  final String url;
  final String? projectId;
  final String? mpRoomId;
  final String? mpSessionId;
  final bool mpIsHost;

  const PlayWebglScreen({
    super.key,
    required this.url,
    this.projectId,
    this.mpRoomId,
    this.mpSessionId,
    this.mpIsHost = false,
  });

  @override
  State<PlayWebglScreen> createState() => _PlayWebglScreenState();
}

class _PlayWebglScreenState extends State<PlayWebglScreen>
    with TickerProviderStateMixin {
  late final WebViewController _controller;
  Widget? _webView;

  late final String _resolvedUrl;

  final _mp = MultiplayerController();
  String? _mpRoomId;
  String? _mpSessionId;
  bool _mpIsHost = false;
  int _lastMpStatePushAtMs = 0;
  bool _unitySplitEnabled = false;
  int _lastUnitySplitAttemptAtMs = 0;

  final TextEditingController _mpText = TextEditingController();
  final ScrollController _mpScroll = ScrollController();

  final Map<String, _GhostPlayer> _ghosts = <String, _GhostPlayer>{};
  int _lastProcessedInputTs = 0;
  Timer? _ghostTick;

  final List<_MpFeedItem> _mpFeed = <_MpFeedItem>[];

  bool _loading = true;
  String? _error;

  Timer? _blankWatchdog;
  int _blankWatchdogTries = 0;

  Timer? _healthMonitor;
  bool _recovering = false;
  int _recoverTries = 0;

  String? _projectId;
  bool _autoTrailerMode = false;
  bool _autoTrailerSubmitting = false;
  String _autoTrailerStatus = 'idle';
  String? _autoTrailerId;
  String? _autoTrailerStage;
  String? _autoTrailerVideoUrl;
  int? _autoTrailerEtaSec;
  int? _autoTrailerEstimatedTotalSec;
  int? _autoTrailerElapsedSec;
  String _autoTrailerStyle = 'energetic';
  String _autoTrailerTarget = 'reels';
  bool _autoTrailerAutoPublishEnabled = true;
  Timer? _autoTrailerPoll;
  Timer? _autoTrailerEtaTicker;
  Timer? _autoTrailerCaptureTick;
  final List<Map<String, dynamic>> _autoTrailerEvents =
      <Map<String, dynamic>>[];
  int _autoTrailerCaptureStartMs = 0;
  int _autoTrailerLastScore = 0;
  int _autoTrailerLastCoins = 0;
  bool _autoTrailerFinalized = false;
  bool _autoTrailerPublishedToFeed = false;
  bool _autoTrailerFinishing = false;
  bool _autoTrailerRecorderBooted = false;
  bool _autoTrailerRecorderActive = false;
  String? _autoTrailerRecordedSourceUrl;
  static const int _autoTrailerMinRecordMs = 2600;
  static const int _autoTrailerMinBlobBytes = 8192;

  static const _kPrefFpsControlsPrefix = 'gameforge.fpsControlsEnabled.';
  bool _fpsControlsEnabled = false;
  bool _openingSettings = false;
  bool _isFullscreen = false;

  static const _kPrefAutoBalanceNextRunPrefix = 'gameforge.autoBalanceNextRun.';
  static const _kPrefAutoBalancePendingPrefix = 'gameforge.autoBalancePending.';
  bool _autoBalanceNextRun = false;
  Map<String, dynamic>? _autoBalancePending;
  bool _autoBalanceAppliedForPending = false;

  // Post-game coach telemetry
  late final int _sessionStartAtMs;
  int _telemetryReloads = 0;
  int _telemetryJsErrors = 0;
  int _telemetryWebglContextLost = 0;
  final List<String> _telemetryErrorSamples = <String>[];
  bool _coachReportShown = false;
  bool _coachReportInFlight = false;

  static const _kPrefControllerSkinPrefix = 'gameforge.controllerSkin.';
  _ControllerSkin _controllerSkin = _ControllerSkin.arcade;

  late final AnimationController _hudPulseCtrl;

  bool _liveApplying = false;
  bool _bridgeChecked = false;

  int _lastJsErrAtMs = 0;

  final Map<String, bool> _keyDown = <String, bool>{};
  final List<String> _batchedJs = <String>[];
  Timer? _batchedJsFlush;

  Timer? _liveApplyDebounce;
  Timer? _liveApplyingClear;

  Map<String, dynamic>? _lastRuntimeConfig;

  final _speech = stt.SpeechToText();
  bool _voiceListening = false;
  String _voiceLast = '';
  Timer? _voicePersistDebounce;

  static const _kPrefPlayerSkinPrefix = 'gameforge.playerSkin.';
  static const _kPrefPlayerSpriteUrlPrefix = 'gameforge.playerSpriteUrl.';
  static const _kPrefForceReloadPrefix = 'gameforge.forceReloadGameplay.';

  Future<void> _loadAutoBalancePref() async {
    final pid = _projectId;
    if (pid == null || pid.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool('$_kPrefAutoBalanceNextRunPrefix$pid') ?? false;
      if (!mounted) return;
      setState(() => _autoBalanceNextRun = v);
    } catch (_) {}
  }

  Future<void> _saveAutoBalancePref(bool v) async {
    final pid = _projectId;
    if (pid == null || pid.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_kPrefAutoBalanceNextRunPrefix$pid', v);
    } catch (_) {}
  }

  Future<void> _loadAutoBalancePending() async {
    final pid = _projectId;
    if (pid == null || pid.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString('$_kPrefAutoBalancePendingPrefix$pid') ?? '')
          .trim();
      if (raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _autoBalancePending = Map<String, dynamic>.from(decoded as Map);
    } catch (_) {}
  }

  Future<void> _setAutoBalancePending({
    required String outcome,
    int? coins,
    int? scoreTotal,
  }) async {
    final pid = _projectId;
    if (pid == null || pid.trim().isEmpty) return;
    final next = <String, dynamic>{
      'outcome': outcome.trim().toLowerCase(),
      if (coins != null) 'coins': coins,
      if (scoreTotal != null) 'scoreTotal': scoreTotal,
      'tsMs': DateTime.now().millisecondsSinceEpoch,
    };
    _autoBalancePending = next;
    _autoBalanceAppliedForPending = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_kPrefAutoBalancePendingPrefix$pid',
        jsonEncode(next),
      );
    } catch (_) {}
  }

  Future<void> _clearAutoBalancePending() async {
    final pid = _projectId;
    if (pid == null || pid.trim().isEmpty) return;
    _autoBalancePending = null;
    _autoBalanceAppliedForPending = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_kPrefAutoBalancePendingPrefix$pid');
    } catch (_) {}
  }

  Future<void> _applySystemFullscreen(bool enabled) async {
    try {
      if (enabled) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }

      if (!mounted) return;
      final next = _fpsControlsEnabled;
      if (next != _fpsControlsEnabled) {
        setState(() => _fpsControlsEnabled = next);
      }
      await _ensureGameFocus();
    } catch (_) {}
  }

  void _cancelBlankWatchdog() {
    _blankWatchdog?.cancel();
    _blankWatchdog = null;
  }

  void _cancelHealthMonitor() {
    _healthMonitor?.cancel();
    _healthMonitor = null;
  }

  Future<void> _runJsBatched(String js) async {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    if (!isIos) {
      await _runJs(js);
      return;
    }

    _batchedJs.add(js);
    _batchedJsFlush ??= Timer(const Duration(milliseconds: 16), () async {
      final payload = _batchedJs.join('\n');
      _batchedJs.clear();
      _batchedJsFlush = null;
      await _runJs(payload);
    });
  }

  Future<bool> _isWebglHealthy() async {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    if (!isIos) return true;
    try {
      return await _runJsReturningBool('''
(function(){
  try {
    if (document.hidden) return true;
    var canvas = document.querySelector('canvas');
    if (!canvas) return false;
    var r = canvas.getBoundingClientRect();
    if (!r || r.width < 8 || r.height < 8) return false;
    if (window.__gfWebglContextLost === true) return false;
    // Some builds will lose the context silently; probe if possible.
    try {
      var gl = canvas.getContext('webgl2') || canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
      if (gl && typeof gl.isContextLost === 'function' && gl.isContextLost()) return false;
    } catch(e) {}
    return true;
  } catch(e) {
    return false;
  }
})();
''');
    } catch (_) {
      return true;
    }
  }

  Future<void> _attemptRecover(String reason) async {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    if (!isIos) return;
    if (!mounted) return;
    if (_recovering) return;
    if (_error != null) return;
    _recovering = true;
    try {
      _recoverTries += 1;
      if (_recoverTries <= 2) {
        setState(() {
          _loading = true;
        });
        try {
          _telemetryReloads++;
          await _controller.loadRequest(
            Uri.parse(_withCacheBuster(_resolvedUrl)),
          );
        } catch (_) {}
        return;
      }

      setState(() {
        _loading = false;
        _error =
            'WebGL became unstable on iOS ($reason). Opening in Safari (more stable)…';
      });
      try {
        await _openInSafari();
      } catch (_) {}
    } finally {
      _recovering = false;
    }
  }

  void _startHealthMonitor() {
    _cancelHealthMonitor();
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    if (!isIos) return;
    // On iOS Simulator with localhost assets, WebGL can temporarily report 0-sized canvas
    // and trigger false recoveries. Only enable the monitor for non-local URLs.
    try {
      final u = Uri.parse(_resolvedUrl);
      final h = u.host.toLowerCase();
      if (h == 'localhost' || h == '127.0.0.1') return;
    } catch (_) {}
    _healthMonitor = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!mounted) return;
      if (_loading) return;
      if (_error != null) return;
      final ok = await _isWebglHealthy();
      if (!ok) {
        await _attemptRecover('screen went black');
      }
    });
  }

  void _scheduleBlankWatchdog() {
    _cancelBlankWatchdog();
    _blankWatchdog = Timer(const Duration(seconds: 7), () async {
      if (!mounted) return;
      if (_error != null) return;

      final isIos = defaultTargetPlatform == TargetPlatform.iOS;
      if (!isIos) return;

      // Disable this iOS-specific watchdog for local simulator URLs to avoid false positives.
      try {
        final u = Uri.parse(_resolvedUrl);
        final h = u.host.toLowerCase();
        if (h == 'localhost' || h == '127.0.0.1') return;
      } catch (_) {}

      final ok = await _runJsReturningBool('''
(function(){
  try {
    var canvas = document.querySelector('canvas');
    if (!canvas) return false;
    try {
      var r = canvas.getBoundingClientRect();
      if (!r || r.width < 8 || r.height < 8) return false;
    } catch(e) {}
    // Unity may expose instance later; consider page OK if loader exists.
    if (window.unityInstance && typeof window.unityInstance.SendMessage === 'function') return true;
    if (typeof window.createUnityInstance === 'function') return true;
    if (typeof window.UnityLoader !== 'undefined') return true;
    return false;
  } catch(e) { return false; }
})();
''');

      if (ok) {
        _blankWatchdogTries = 0;
        return;
      }

      _blankWatchdogTries += 1;
      if (_blankWatchdogTries <= 2) {
        try {
          setState(() {
            _loading = true;
          });
          _telemetryReloads++;
          await _controller.loadRequest(
            Uri.parse(_withCacheBuster(_resolvedUrl)),
          );
        } catch (_) {}
        return;
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'WebGL failed to render on iOS. Opening in Safari (more stable)…';
      });

      try {
        await _openInSafari();
      } catch (_) {}
    });
  }

  Future<void> _openInSafari() async {
    try {
      final uri = Uri.parse(_resolvedUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      AppNotifier.showError('Failed to open link');
    }
  }

  Color? _parseHexToColor(String? input) {
    final v = _normHex(input);
    if (v == null) return null;
    try {
      final n = int.tryParse(v.substring(1), radix: 16);
      if (n == null) return null;
      return Color(0xFF000000 | n);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadControllerSkinPref() async {
    final pid = _projectId;
    final k = (pid == null || pid.trim().isEmpty)
        ? '${_kPrefControllerSkinPrefix}global'
        : '$_kPrefControllerSkinPrefix$pid';
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(k) ?? '').trim();
      final v = _ControllerSkin.values
          .where((e) => e.name == raw)
          .cast<_ControllerSkin?>()
          .firstWhere((e) => e != null, orElse: () => null);
      if (!mounted) return;
      setState(() => _controllerSkin = v ?? _ControllerSkin.arcade);
    } catch (_) {}
  }

  Future<void> _saveControllerSkinPref(_ControllerSkin skin) async {
    final pid = _projectId;
    final k = (pid == null || pid.trim().isEmpty)
        ? '${_kPrefControllerSkinPrefix}global'
        : '$_kPrefControllerSkinPrefix$pid';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(k, skin.name);
    } catch (_) {}
  }

  Future<void> _openControllerSkinSheet() async {
    final cs = Theme.of(context).colorScheme;
    final current = _controllerSkin;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final shouldAvoidBlur = defaultTargetPlatform == TargetPlatform.iOS;
        Widget glass({required Widget child}) {
          final content = Container(
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.84),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.24),
                  blurRadius: 24,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: child,
          );

          return ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: shouldAvoidBlur
                ? content
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: content,
                  ),
          );
        }

        Color accentFor(_ControllerSkin s) {
          switch (s) {
            case _ControllerSkin.xbox:
              return const Color(0xFF22C55E);
            case _ControllerSkin.playstation:
              return const Color(0xFF3B82F6);
            case _ControllerSkin.nintendo:
              return const Color(0xFFEF4444);
            case _ControllerSkin.arcade:
              return cs.primary;
          }
        }

        String titleFor(_ControllerSkin s) {
          switch (s) {
            case _ControllerSkin.xbox:
              return 'Xbox';
            case _ControllerSkin.playstation:
              return 'PlayStation';
            case _ControllerSkin.nintendo:
              return 'Nintendo';
            case _ControllerSkin.arcade:
              return 'Arcade';
          }
        }

        Widget card(_ControllerSkin s, IconData icon, String subtitle) {
          final selected = current == s;
          final accent = accentFor(s);
          return GestureDetector(
            onTap: () async {
              if (!mounted) return;
              setState(() => _controllerSkin = s);
              await _saveControllerSkinPref(s);
              if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
              try {
                await HapticFeedback.selectionClick();
              } catch (_) {}
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    accent.withOpacity(selected ? 0.26 : 0.14),
                    cs.surfaceContainerHighest.withOpacity(
                      selected ? 0.42 : 0.26,
                    ),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: selected
                      ? accent.withOpacity(0.70)
                      : cs.outlineVariant.withOpacity(0.50),
                  width: selected ? 1.6 : 1.0,
                ),
                boxShadow: [
                  if (selected)
                    BoxShadow(
                      color: accent.withOpacity(0.22),
                      blurRadius: 26,
                      offset: const Offset(0, 16),
                    ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          accent.withOpacity(0.90),
                          accent.withOpacity(0.55),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.20),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                titleFor(s),
                                style: AppTypography.subtitle2.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (selected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: accent,
                                size: 20,
                              )
                            else
                              Icon(
                                Icons.circle_outlined,
                                color: cs.onSurface.withOpacity(0.22),
                                size: 20,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: AppTypography.caption.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: glass(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Controller',
                            style: AppTypography.subtitle1.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose your on-screen controller skin',
                      style: AppTypography.body2.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    card(
                      _ControllerSkin.arcade,
                      Icons.sports_esports_rounded,
                      'Clean glass + minimal labels',
                    ),
                    const SizedBox(height: 12),
                    card(
                      _ControllerSkin.xbox,
                      Icons.gamepad_rounded,
                      'Neon green — A/B/X/Y vibe',
                    ),
                    const SizedBox(height: 12),
                    card(
                      _ControllerSkin.playstation,
                      Icons.videogame_asset_rounded,
                      'Deep blue — cross/circle vibe',
                    ),
                    const SizedBox(height: 12),
                    card(
                      _ControllerSkin.nintendo,
                      Icons.toys_rounded,
                      'Punchy red — classic handheld vibe',
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _probeGameResultTelemetry() async {
    final res = await _runJsResult("""
      (function(){
        try {
          function pick(obj, key){
            try { if (!obj) return null; if (typeof obj[key] === 'undefined') return null; return obj[key]; } catch(e){ return null; }
          }

          function isObj(x){
            return x && typeof x === 'object';
          }

          function toNum(x){
            if (x === null || typeof x === 'undefined') return null;
            var n = Number(x);
            if (!isFinite(n)) return null;
            return n;
          }

          function normOutcome(x){
            var s = (x === null || typeof x === 'undefined') ? '' : String(x);
            s = s.trim().toLowerCase();
            if (s === 'win' || s === 'won' || s === 'victory' || s === 'success') return 'win';
            if (s === 'loss' || s === 'lose' || s === 'lost' || s === 'defeat' || s === 'failed') return 'loss';
            return 'unknown';
          }

          function toInt(x){
            var n = toNum(x);
            if (n === null) return null;
            return Math.round(n);
          }

          function maybeOutcomeFromBool(v){
            if (v === true) return 'win';
            if (v === false) return 'loss';
            return null;
          }

          function deepFind(root, maxDepth){
            var visited = [];

            function seen(x){
              for (var i = 0; i < visited.length; i++) if (visited[i] === x) return true;
              return false;
            }

            function walk(node, depth){
              if (!isObj(node)) return { outcome: null, coins: null, scoreTotal: null };
              if (seen(node)) return { outcome: null, coins: null, scoreTotal: null };
              visited.push(node);
              if (visited.length > 800) return { outcome: null, coins: null, scoreTotal: null };

              var out = { outcome: null, coins: null, scoreTotal: null };

              // Direct keys
              var o = pick(node, 'outcome') || pick(node, 'result') || pick(node, 'winLoss') || pick(node, 'status') || pick(node, 'gameStatus') || pick(node, 'endState');
              if (o && !out.outcome) out.outcome = normOutcome(o);

              // Common booleans
              if (!out.outcome || out.outcome === 'unknown') {
                var b = null;
                b = (b === null) ? pick(node, 'isWin') : b;
                b = (b === null) ? pick(node, 'win') : b;
                b = (b === null) ? pick(node, 'won') : b;
                b = (b === null) ? pick(node, 'victory') : b;
                b = (b === null) ? pick(node, 'isVictory') : b;
                b = (b === null) ? pick(node, 'isGameOver') : b;
                b = (b === null) ? pick(node, 'gameOver') : b;
                var bo = maybeOutcomeFromBool(b);
                if (bo) out.outcome = bo;
              }

              if (out.coins === null) {
                out.coins = toInt(pick(node, 'coins') ?? pick(node, 'coin') ?? pick(node, 'coinsTotal') ?? pick(node, 'coinCount') ?? pick(node, 'gold') ?? pick(node, 'currency'));
              }
              if (out.scoreTotal === null) {
                out.scoreTotal = toInt(pick(node, 'scoreTotal') ?? pick(node, 'score') ?? pick(node, 'points') ?? pick(node, 'totalScore') ?? pick(node, 'finalScore'));
              }

              if (depth <= 0) return out;

              // Walk a few likely nested keys first
              var candidates = [
                pick(node, 'state'),
                pick(node, 'data'),
                pick(node, 'game'),
                pick(node, 'session'),
                pick(node, 'player'),
                pick(node, 'stats'),
                pick(node, 'runtime'),
                pick(node, 'telemetry'),
                pick(node, 'metrics'),
              ];

              for (var i = 0; i < candidates.length; i++) {
                var c = candidates[i];
                if (!isObj(c)) continue;
                var found = walk(c, depth - 1);
                if ((!out.outcome || out.outcome === 'unknown') && found.outcome && found.outcome !== 'unknown') out.outcome = found.outcome;
                if (out.coins === null && found.coins !== null) out.coins = found.coins;
                if (out.scoreTotal === null && found.scoreTotal !== null) out.scoreTotal = found.scoreTotal;
                if (out.outcome && out.outcome !== 'unknown' && out.coins !== null && out.scoreTotal !== null) return out;
              }

              // Last resort: iterate object keys (limited)
              try {
                var keys = Object.keys(node);
                for (var k = 0; k < keys.length && k < 60; k++) {
                  var key = keys[k];
                  var v = null;
                  try { v = node[key]; } catch(e) { v = null; }
                  if (!isObj(v)) continue;
                  var found2 = walk(v, depth - 1);
                  if ((!out.outcome || out.outcome === 'unknown') && found2.outcome && found2.outcome !== 'unknown') out.outcome = found2.outcome;
                  if (out.coins === null && found2.coins !== null) out.coins = found2.coins;
                  if (out.scoreTotal === null && found2.scoreTotal !== null) out.scoreTotal = found2.scoreTotal;
                  if (out.outcome && out.outcome !== 'unknown' && out.coins !== null && out.scoreTotal !== null) return out;
                }
              } catch(e) {}

              return out;
            }

            return walk(root, maxDepth);
          }

          var roots = [
            window.GF_GAME,
            window.GameForgeGame,
            window.gameforgeGame,
            window.gameState,
            window.__gfState,
            window.GF_STATE,
            window.__GF_STATE,
            window.__GF_TELEMETRY,
            window.telemetry,
            window.metrics,
          ];

          var best = { outcome: 'unknown', coins: null, scoreTotal: null };

          // First pass: deep search common roots
          for (var i = 0; i < roots.length; i++) {
            var r = roots[i];
            if (!r) continue;
            var found = deepFind(r, 3);
            if (found && found.outcome && found.outcome !== 'unknown') best.outcome = found.outcome;
            if (best.coins === null && found && found.coins !== null) best.coins = found.coins;
            if (best.scoreTotal === null && found && found.scoreTotal !== null) best.scoreTotal = found.scoreTotal;
            if (best.outcome !== 'unknown' && best.coins !== null && best.scoreTotal !== null) break;
          }

          // Second pass: direct window variables
          if (best.coins === null && typeof window.coins !== 'undefined') best.coins = toInt(window.coins);
          if (best.scoreTotal === null && typeof window.score !== 'undefined') best.scoreTotal = toInt(window.score);
          if (best.scoreTotal === null && typeof window.totalScore !== 'undefined') best.scoreTotal = toInt(window.totalScore);

          if (best.outcome === 'unknown') {
            var bo = null;
            try {
              if (typeof window.isWin !== 'undefined') bo = maybeOutcomeFromBool(window.isWin);
              if (!bo && typeof window.win !== 'undefined') bo = maybeOutcomeFromBool(window.win);
              if (!bo && typeof window.won !== 'undefined') bo = maybeOutcomeFromBool(window.won);
              if (!bo && typeof window.victory !== 'undefined') bo = maybeOutcomeFromBool(window.victory);
            } catch(e) {}
            if (bo) best.outcome = bo;
          }

          // Last resort: infer from DOM text
          if (best.outcome === 'unknown') {
            try {
              var txt = '';
              try { txt = (document && document.body && document.body.innerText) ? String(document.body.innerText) : ''; } catch(e) { txt = ''; }
              txt = txt.toLowerCase();
              if (txt.indexOf('you win') >= 0 || txt.indexOf('victory') >= 0 || txt.indexOf('win') >= 0) best.outcome = 'win';
              if (txt.indexOf('game over') >= 0 || txt.indexOf('you lose') >= 0 || txt.indexOf('defeat') >= 0 || txt.indexOf('loss') >= 0) {
                if (best.outcome === 'unknown') best.outcome = 'loss';
              }
            } catch(e) {}
          }

          return JSON.stringify({ outcome: best.outcome, coins: best.coins, scoreTotal: best.scoreTotal });
        } catch(e) {
          return JSON.stringify({ outcome: 'unknown', coins: null, scoreTotal: null });
        }
      })();
      """);

    String? s;
    if (res is String) {
      s = res;
    } else if (res != null) {
      s = res.toString();
    }

    try {
      if (s == null) return <String, dynamic>{};
      final decoded = jsonDecode(s);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      if (decoded is String) {
        final decoded2 = jsonDecode(decoded);
        if (decoded2 is Map) return Map<String, dynamic>.from(decoded2);
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _maybeShowPostGameCoachReport() async {
    if (!mounted) return;
    if (_coachReportShown) return;
    if (_coachReportInFlight) return;

    final pid = (_projectId ?? '').trim();
    if (pid.isEmpty) return;

    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    final durationSec =
        (DateTime.now().millisecondsSinceEpoch - _sessionStartAtMs) / 1000.0;

    Map<String, dynamic> gameMetrics = <String, dynamic>{};
    try {
      gameMetrics = await _probeGameResultTelemetry();
    } catch (_) {
      gameMetrics = <String, dynamic>{};
    }

    Map<String, dynamic> res;
    _coachReportInFlight = true;

    Map<String, dynamic> fallbackReport(String reason) {
      final raw = reason.toString().trim();
      final msg = raw.isEmpty
          ? 'Coach report failed'
          : (raw.contains('Request timed out')
                ? 'Coach report took too long. Please try again.'
                : raw.split('\n').first);
      return <String, dynamic>{
        'projectId': pid,
        'provider': 'fallback',
        'score': 50,
        'outcome': (gameMetrics['outcome'] ?? 'unknown'),
        'coins': gameMetrics['coins'],
        'scoreTotal': gameMetrics['scoreTotal'],
        'summary': 'Session analyzed with limited data.',
        'insights': <String>[msg],
        'tips': const <String>['Try again after fixing server configuration.'],
        'nextActions': const <Map<String, dynamic>>[],
        'goalNextRun': 'Retry after fixing server configuration.',
        'suggestedPreset': const <String, dynamic>{
          'difficulty': 0.5,
          'speed': 7.0,
          'timeScale': 1.0,
        },
        'note': msg,
      };
    }

    try {
      res = await ApiService.post(
        '/coach/report',
        token: token,
        timeout: const Duration(seconds: 120),
        data: {
          'projectId': pid,
          'telemetry': {
            'durationSec': durationSec,
            'reloads': _telemetryReloads,
            'jsErrors': _telemetryJsErrors,
            'contextLost': _telemetryWebglContextLost,
            'errorSamples': _telemetryErrorSamples,
            'outcome': gameMetrics['outcome'],
            'coins': gameMetrics['coins'],
            'scoreTotal': gameMetrics['scoreTotal'],
          },
          'locale': Localizations.localeOf(context).toLanguageTag(),
        },
      );
    } catch (e) {
      if (!mounted) return;
      _coachReportShown = true;
      AppNotifier.showError(e.toString());
      await _showCoachReportSheet(fallbackReport(e.toString()));
      return;
    } finally {
      _coachReportInFlight = false;
    }

    if (!mounted) return;
    if (res['success'] != true) {
      final msg = (res['message'] ?? 'Coach report failed').toString();
      _coachReportShown = true;
      AppNotifier.showError(msg);
      await _showCoachReportSheet(fallbackReport(msg));
      return;
    }
    final data = res['data'];
    if (data is! Map) return;
    final report = Map<String, dynamic>.from(data as Map);

    if (_autoBalanceNextRun) {
      final outcome = (report['outcome'] ?? 'unknown')
          .toString()
          .trim()
          .toLowerCase();
      final coins = (report['coins'] is num)
          ? (report['coins'] as num).toInt()
          : null;
      final scoreTotal = (report['scoreTotal'] is num)
          ? (report['scoreTotal'] as num).toInt()
          : null;
      if (outcome == 'win' || outcome == 'loss') {
        await _setAutoBalancePending(
          outcome: outcome,
          coins: coins,
          scoreTotal: scoreTotal,
        );
      }
    }

    _coachReportShown = true;
    await _showCoachReportSheet(report);
  }

  Future<void> _showCoachReportSheet(Map<String, dynamic> report) async {
    if (!mounted) return;
    final rootContext = context;
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final shouldAvoidBlur = defaultTargetPlatform == TargetPlatform.iOS;
        final score = (report['score'] is num)
            ? (report['score'] as num).toDouble()
            : 0.0;
        final outcome = (report['outcome'] ?? 'unknown')
            .toString()
            .trim()
            .toLowerCase();
        final coins = (report['coins'] is num)
            ? (report['coins'] as num).toInt()
            : null;
        final scoreTotal = (report['scoreTotal'] is num)
            ? (report['scoreTotal'] as num).toInt()
            : null;
        final summary = (report['summary'] ?? '').toString();
        final insights = (report['insights'] is List)
            ? List<String>.from(
                (report['insights'] as List).map((e) => e.toString()),
              )
            : const <String>[];
        final tips = (report['tips'] is List)
            ? List<String>.from(
                (report['tips'] as List).map((e) => e.toString()),
              )
            : const <String>[];
        final nextActions = (report['nextActions'] is List)
            ? List<Map<String, dynamic>>.from(
                (report['nextActions'] as List)
                    .where((e) => e is Map)
                    .map((e) => Map<String, dynamic>.from(e as Map)),
              )
            : const <Map<String, dynamic>>[];
        final playerDna = (report['playerDna'] is Map)
            ? Map<String, dynamic>.from(report['playerDna'] as Map)
            : null;
        final suggestedPreset = (report['suggestedPreset'] is Map)
            ? Map<String, dynamic>.from(report['suggestedPreset'] as Map)
            : null;
        final tuningPresets = (report['tuningPresets'] is List)
            ? List<Map<String, dynamic>>.from(
                (report['tuningPresets'] as List)
                    .where((e) => e is Map)
                    .map((e) => Map<String, dynamic>.from(e as Map)),
              )
            : const <Map<String, dynamic>>[];

        String fmtNum(dynamic v) {
          if (v is num) {
            final x = v.toDouble();
            if ((x - x.round()).abs() < 0.0001) return x.round().toString();
            return x.toStringAsFixed(2);
          }
          return (v ?? '').toString();
        }

        Widget chip(String text) {
          return Container(
            margin: const EdgeInsets.only(right: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.55),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
            ),
            child: Text(
              text,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.0),
                Colors.black.withOpacity(0.55),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.55,
            maxChildSize: 0.94,
            builder: (context, scrollController) {
              final content = Container(
                color: cs.surface.withOpacity(0.72),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'AI Coach Report',
                            style: AppTypography.subtitle1.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        SizedBox(
                          width: 74,
                          height: 74,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: (score.clamp(0.0, 100.0)) / 100.0,
                                strokeWidth: 8,
                              ),
                              Text(
                                score.toStringAsFixed(0),
                                style: AppTypography.subtitle1.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            summary.isEmpty
                                ? 'Here is how you can improve your next run.'
                                : summary,
                            style: AppTypography.body2.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      children: [
                        chip(
                          outcome == 'win'
                              ? 'Result: WIN'
                              : (outcome == 'loss'
                                    ? 'Result: LOSS'
                                    : 'Result: —'),
                        ),
                        if (coins != null) chip('Coins: $coins'),
                        if (scoreTotal != null) chip('Score: $scoreTotal'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      children: [
                        chip('Reloads: $_telemetryReloads'),
                        chip('JS errors: $_telemetryJsErrors'),
                        chip('Context lost: $_telemetryWebglContextLost'),
                      ],
                    ),
                    if (insights.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Insights',
                        style: AppTypography.subtitle2.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final i in insights.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.auto_awesome_rounded, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(i, style: AppTypography.body2),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (tips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Tips',
                        style: AppTypography.subtitle2.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final t in tips.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.tips_and_updates_rounded,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(t, style: AppTypography.body2),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (nextActions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Top next actions',
                        style: AppTypography.subtitle2.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final entry
                          in nextActions.take(5).toList().asMap().entries)
                        Builder(
                          builder: (context) {
                            final idx = entry.key;
                            final a = entry.value;
                            final title = (a['title'] ?? '').toString().trim();
                            final why = (a['why'] ?? '').toString().trim();
                            final how = (a['how'] ?? '').toString().trim();
                            final impactRaw = (a['impact'] ?? '')
                                .toString()
                                .trim();
                            final impact = impactRaw.length > 10
                                ? (impactRaw.substring(0, 9) + '…')
                                : impactRaw;
                            if (title.isEmpty) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.surface.withOpacity(0.60),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: cs.outlineVariant.withOpacity(0.55),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.task_alt_rounded,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${idx + 1}. $title',
                                          style: AppTypography.body2.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      if (impact.isNotEmpty)
                                        chip('Impact: ${impact.toUpperCase()}'),
                                    ],
                                  ),
                                  if (why.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Why: $why',
                                      style: AppTypography.body2,
                                    ),
                                  ],
                                  if (how.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'How: $how',
                                      style: AppTypography.body2.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                    if (playerDna != null && playerDna.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Your Player DNA',
                        style: AppTypography.subtitle2.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final style =
                              (playerDna['style'] ??
                                      playerDna['playerStyle'] ??
                                      playerDna['archetype'])
                                  ?.toString()
                                  .trim();
                          final strengths = (playerDna['strengths'] is List)
                              ? List<String>.from(
                                  (playerDna['strengths'] as List).map(
                                    (e) => e.toString(),
                                  ),
                                )
                              : const <String>[];
                          final weaknesses = (playerDna['weaknesses'] is List)
                              ? List<String>.from(
                                  (playerDna['weaknesses'] as List).map(
                                    (e) => e.toString(),
                                  ),
                                )
                              : const <String>[];
                          final focusAreas = (playerDna['focusAreas'] is List)
                              ? List<String>.from(
                                  (playerDna['focusAreas'] as List).map(
                                    (e) => e.toString(),
                                  ),
                                )
                              : const <String>[];
                          final tagline = (playerDna['tagline'] ?? '')
                              .toString()
                              .trim();
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.surface.withOpacity(0.60),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: cs.outlineVariant.withOpacity(0.55),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (style != null && style.isNotEmpty)
                                  Text(
                                    'Style: $style',
                                    style: AppTypography.body2.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                if (tagline.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    tagline,
                                    style: AppTypography.caption.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                                if (strengths.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Strengths',
                                    style: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  for (final s in strengths.take(3))
                                    Text(
                                      '- ${s.trim()}',
                                      style: AppTypography.body2,
                                    ),
                                ],
                                if (weaknesses.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Weaknesses',
                                    style: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  for (final w in weaknesses.take(3))
                                    Text(
                                      '- ${w.trim()}',
                                      style: AppTypography.body2,
                                    ),
                                ],
                                if (focusAreas.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Focus next',
                                    style: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  for (final f in focusAreas.take(3))
                                    Text(
                                      '- ${f.trim()}',
                                      style: AppTypography.body2,
                                    ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    if (suggestedPreset != null &&
                        suggestedPreset.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Recommended tuning',
                        style: AppTypography.subtitle2.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final hint = outcome == 'loss'
                              ? 'You lost → we can make it easier (lower difficulty / timeScale)'
                              : (outcome == 'win'
                                    ? 'You won → we can make it harder (higher difficulty / speed)'
                                    : 'You can apply a tuning preset for your next run');
                          return Text(
                            hint,
                            style: AppTypography.caption.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        children: [
                          if (suggestedPreset['speed'] != null)
                            chip(
                              'Vitesse: ${fmtNum(suggestedPreset['speed'])}',
                            ),
                          if (suggestedPreset['difficulty'] != null)
                            chip(
                              'Difficulté: ${fmtNum(suggestedPreset['difficulty'])}',
                            ),
                          if (suggestedPreset['timeScale'] != null)
                            chip(
                              'TimeScale: ${fmtNum(suggestedPreset['timeScale'])}',
                            ),
                          if (suggestedPreset['cameraZoom'] != null)
                            chip(
                              'Zoom: ${fmtNum(suggestedPreset['cameraZoom'])}',
                            ),
                          if (suggestedPreset['gravityY'] != null)
                            chip(
                              'GravityY: ${fmtNum(suggestedPreset['gravityY'])}',
                            ),
                          if (suggestedPreset['jumpForce'] != null)
                            chip(
                              'Jump: ${fmtNum(suggestedPreset['jumpForce'])}',
                            ),
                          chip(
                            'Enemies: ${((suggestedPreset['difficulty'] is num) && (suggestedPreset['difficulty'] as num) > 0.7) ? 'More' : (((suggestedPreset['difficulty'] is num) && (suggestedPreset['difficulty'] as num) < 0.4) ? 'Less' : 'Normal')}',
                          ),
                        ],
                      ),
                      if (tuningPresets.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'One-click presets',
                          style: AppTypography.caption.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            return StatefulBuilder(
                              builder: (context, setLocal) {
                                final items = tuningPresets.take(3).toList();
                                int pressedIndex = -1;

                                IconData iconFor(String k) {
                                  final key = k.trim().toLowerCase();
                                  if (key == 'easy') return Icons.spa_rounded;
                                  if (key == 'hardcore')
                                    return Icons.local_fire_department_rounded;
                                  return Icons.tune_rounded;
                                }

                                String subtitleFor(String k) {
                                  final key = k.trim().toLowerCase();
                                  if (key == 'easy')
                                    return 'Smoother, safer run';
                                  if (key == 'hardcore')
                                    return 'Faster, tougher run';
                                  return 'Default balance';
                                }

                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.10),
                                        ),
                                        gradient: LinearGradient(
                                          colors: [
                                            cs.surface.withOpacity(0.55),
                                            cs.surface.withOpacity(0.28),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.12,
                                            ),
                                            blurRadius: 18,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      cs.primary.withOpacity(
                                                        0.95,
                                                      ),
                                                      cs.primaryContainer
                                                          .withOpacity(0.65),
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.auto_fix_high_rounded,
                                                  color: cs.onPrimary,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'One-click presets',
                                                      style: AppTypography.body2
                                                          .copyWith(
                                                            fontWeight:
                                                                FontWeight.w900,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Apply and instantly restart with new tuning',
                                                      style: AppTypography
                                                          .caption
                                                          .copyWith(
                                                            color: cs
                                                                .onSurfaceVariant,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: List.generate(items.length, (
                                              i,
                                            ) {
                                              final it = items[i];
                                              final label =
                                                  (it['label'] ??
                                                          it['key'] ??
                                                          '')
                                                      .toString()
                                                      .trim();
                                              final key = (it['key'] ?? '')
                                                  .toString()
                                                  .trim()
                                                  .toLowerCase();
                                              final preset =
                                                  (it['preset'] is Map)
                                                  ? Map<String, dynamic>.from(
                                                      it['preset'] as Map,
                                                    )
                                                  : <String, dynamic>{};

                                              return Expanded(
                                                child: Padding(
                                                  padding: EdgeInsets.only(
                                                    right: i == items.length - 1
                                                        ? 0
                                                        : 8,
                                                  ),
                                                  child: GestureDetector(
                                                    onTapDown: (_) => setLocal(
                                                      () => pressedIndex = i,
                                                    ),
                                                    onTapUp: (_) => setLocal(
                                                      () => pressedIndex = -1,
                                                    ),
                                                    onTapCancel: () => setLocal(
                                                      () => pressedIndex = -1,
                                                    ),
                                                    child: AnimatedScale(
                                                      duration: const Duration(
                                                        milliseconds: 140,
                                                      ),
                                                      scale: (pressedIndex == i)
                                                          ? 0.98
                                                          : 1.0,
                                                      child: AnimatedContainer(
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 200,
                                                            ),
                                                        curve: Curves.easeOut,
                                                        decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                14,
                                                              ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color:
                                                                  (key == 'hardcore'
                                                                          ? Colors.orange
                                                                          : cs.primary)
                                                                      .withOpacity(
                                                                        pressedIndex ==
                                                                                i
                                                                            ? 0.18
                                                                            : 0.10,
                                                                      ),
                                                              blurRadius:
                                                                  pressedIndex ==
                                                                      i
                                                                  ? 26
                                                                  : 18,
                                                              offset:
                                                                  const Offset(
                                                                    0,
                                                                    12,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        child: CustomButton(
                                                          text: label.isEmpty
                                                              ? (key.isEmpty
                                                                    ? 'Preset'
                                                                    : key)
                                                              : label,
                                                          subText: subtitleFor(
                                                            key,
                                                          ),
                                                          onPressed: () async {
                                                            Navigator.of(
                                                              ctx,
                                                            ).pop();
                                                            await _applyRuntimeConfigPatch(
                                                              preset,
                                                            );
                                                            await _reloadWebViewWithCacheBuster();
                                                          },
                                                          type: ButtonType
                                                              .secondary,
                                                          size:
                                                              ButtonSize.small,
                                                          icon: Icon(
                                                            iconFor(key),
                                                            size: 16,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 10),
                      CustomButton(
                        text: 'Apply recommended tuning',
                        onPressed: () async {
                          if (suggestedPreset == null ||
                              suggestedPreset.isEmpty)
                            return;
                          Navigator.of(ctx).pop();
                          try {
                            await _applySuggestedPreset(suggestedPreset);
                            if (!mounted) return;
                            AppNotifier.showSuccess('Tuning applied');
                            _setLiveApplying();
                          } catch (_) {
                            if (!mounted) return;
                            AppNotifier.showError('Failed to apply tuning');
                          }
                        },
                        type: ButtonType.primary,
                        icon: const Icon(Icons.bolt_rounded),
                      ),
                    ],

                    const SizedBox(height: 10),
                    StatefulBuilder(
                      builder: (context, setLocal) {
                        double asDouble(dynamic v, double fallback) {
                          if (v is num) return v.toDouble();
                          final s = (v ?? '').toString().trim();
                          final p = double.tryParse(s);
                          return p ?? fallback;
                        }

                        double clamp(double v, double min, double max) {
                          if (v < min) return min;
                          if (v > max) return max;
                          return v;
                        }

                        final base = _lastRuntimeConfig ?? <String, dynamic>{};
                        final baseSpeed = asDouble(base['speed'], 7.0);
                        final baseTimeScale = asDouble(base['timeScale'], 1.0);
                        final baseDifficulty = asDouble(
                          base['difficulty'],
                          0.5,
                        );

                        final nextSpeed = outcome == 'loss'
                            ? clamp(baseSpeed * 0.95, 1.0, 30.0)
                            : (outcome == 'win'
                                  ? clamp(baseSpeed * 1.05, 1.0, 30.0)
                                  : baseSpeed);
                        final nextTimeScale = outcome == 'loss'
                            ? clamp(baseTimeScale * 0.95, 0.5, 2.0)
                            : (outcome == 'win'
                                  ? clamp(baseTimeScale * 1.03, 0.5, 2.0)
                                  : baseTimeScale);
                        final nextDifficulty = outcome == 'loss'
                            ? clamp(baseDifficulty * 0.9, 0.1, 1.0)
                            : (outcome == 'win'
                                  ? clamp(baseDifficulty * 1.1, 0.1, 1.0)
                                  : baseDifficulty);

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surface.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: cs.outlineVariant.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Auto-balance next run',
                                      style: AppTypography.body2.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'After each run, we will automatically tune the game easier/harder for your next attempt.',
                                      style: AppTypography.caption.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (_autoBalanceNextRun &&
                                        (outcome == 'win' ||
                                            outcome == 'loss')) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        outcome == 'loss'
                                            ? 'Next run preview: easier → speed ${nextSpeed.toStringAsFixed(2)}, difficulty ${nextDifficulty.toStringAsFixed(2)}, timeScale ${nextTimeScale.toStringAsFixed(2)}'
                                            : 'Next run preview: harder → speed ${nextSpeed.toStringAsFixed(2)}, difficulty ${nextDifficulty.toStringAsFixed(2)}, timeScale ${nextTimeScale.toStringAsFixed(2)}',
                                        style: AppTypography.caption.copyWith(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Switch(
                                value: _autoBalanceNextRun,
                                onChanged: (v) async {
                                  setLocal(() {});
                                  if (!mounted) return;
                                  setState(() => _autoBalanceNextRun = v);
                                  await _saveAutoBalancePref(v);
                                  if (!v) {
                                    await _clearAutoBalancePending();
                                  } else {
                                    if (outcome == 'win' || outcome == 'loss') {
                                      await _setAutoBalancePending(
                                        outcome: outcome,
                                        coins: coins,
                                        scoreTotal: scoreTotal,
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Try again',
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              try {
                                _telemetryReloads++;
                                _controller.loadRequest(
                                  Uri.parse(_withCacheBuster(_resolvedUrl)),
                                );
                              } catch (_) {}
                            },
                            type: ButtonType.primary,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomButton(
                            text: 'Open Coach',
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              final pid = (_projectId ?? '').trim();
                              if (pid.isEmpty) return;
                              Future.microtask(() {
                                if (!mounted) return;
                                rootContext.push(
                                  '/ai-coach',
                                  extra: {
                                    'projectId': pid,
                                    'projectName':
                                        widget.url.contains('projectName=')
                                        ? Uri.parse(
                                            widget.url,
                                          ).queryParameters['projectName']
                                        : 'Game Session',
                                    if (playerDna != null)
                                      'playerDna': playerDna,
                                    if (suggestedPreset != null)
                                      'suggestedPreset': suggestedPreset,
                                    if (nextActions.isNotEmpty)
                                      'nextActions': nextActions,
                                  },
                                );
                              });
                            },
                            type: ButtonType.secondary,
                            icon: const Icon(Icons.chat_bubble_rounded),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              return ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppBorderRadius.large),
                ),
                child: shouldAvoidBlur
                    ? content
                    : BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: content,
                      ),
              );
            },
          ),
        );
      },
    );
  }

  String _withCacheBuster(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      final qp = Map<String, String>.from(uri.queryParameters);
      qp['cb'] = DateTime.now().millisecondsSinceEpoch.toString();
      return uri.replace(queryParameters: qp).toString();
    } catch (_) {
      final sep = rawUrl.contains('?') ? '&' : '?';
      return '$rawUrl${sep}cb=${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  String _normalizePlayUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    final u = Uri.tryParse(trimmed);
    if (u == null) return trimmed;

    final host = u.host.toLowerCase();
    final isLocalHost =
        host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
    if (!isLocalHost) return trimmed;

    Uri? base;
    try {
      final baseOrigin = ApiService.baseUrl.replaceAll('/api', '');
      base = Uri.tryParse(baseOrigin);
    } catch (_) {
      base = null;
    }
    if (base == null) return trimmed;

    final baseHost = base.host.toLowerCase();
    final baseIsLocal =
        baseHost == 'localhost' ||
        baseHost == '127.0.0.1' ||
        baseHost == '10.0.2.2';
    if (baseIsLocal) return trimmed;

    final nextPort = base.hasPort ? base.port : (u.hasPort ? u.port : null);
    return u
        .replace(scheme: base.scheme, host: base.host, port: nextPort)
        .toString();
  }

  void _setLiveApplying() {
    if (!mounted) return;
    setState(() => _liveApplying = true);
    _liveApplyingClear?.cancel();
    _liveApplyingClear = Timer(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      setState(() => _liveApplying = false);
    });
  }

  Future<void> _applyRuntimeConfigPatch(Map<String, dynamic> patch) async {
    await _applyVoiceRuntimePatch(patch: patch);
  }

  Future<void> _reloadWebViewWithCacheBuster() async {
    try {
      _telemetryReloads++;
      await _controller.loadRequest(Uri.parse(_withCacheBuster(_resolvedUrl)));
    } catch (_) {}
  }

  Future<void> _toggleFullscreen() async {
    final next = !_isFullscreen;
    await _applySystemFullscreen(next);

    final js = _isFullscreen
        ? """
          (function(){
            try { if (document.fullscreenElement) document.exitFullscreen(); } catch(e){}
          })();
        """
        : """
          (function(){
            try {
              var el = document.querySelector('canvas') || document.documentElement;
              if (el && el.requestFullscreen) el.requestFullscreen();
            } catch(e){}
          })();
        """;
    await _runJs(js);
    if (!mounted) return;
    setState(() {
      _isFullscreen = next;
    });
  }

  String? _extractProjectId(String rawUrl) {
    try {
      final u = Uri.parse(rawUrl);
      final pid = (u.queryParameters['projectId'] ?? '').trim();
      return pid.isEmpty ? null : pid;
    } catch (_) {
      return null;
    }
  }

  bool _isAutoTrailerEnabled(String rawUrl) {
    try {
      final u = Uri.parse(rawUrl);
      final raw = (u.queryParameters['gfAutoTrailer'] ?? '')
          .trim()
          .toLowerCase();
      return raw == '1' || raw == 'true' || raw == 'yes';
    } catch (_) {
      return false;
    }
  }

  String _readAutoTrailerStyleFromUrl(String rawUrl) {
    try {
      final u = Uri.parse(rawUrl);
      final style = (u.queryParameters['gfTrailerStyle'] ?? '')
          .trim()
          .toLowerCase();
      if (style == 'energetic' || style == 'cinematic' || style == 'funny') {
        return style;
      }
    } catch (_) {}
    return 'energetic';
  }

  String _readAutoTrailerTargetFromUrl(String rawUrl) {
    try {
      final u = Uri.parse(rawUrl);
      final target = (u.queryParameters['gfTrailerTarget'] ?? '')
          .trim()
          .toLowerCase();
      if (target == 'tiktok' || target == 'reels' || target == 'short') {
        return target;
      }
    } catch (_) {}
    return 'reels';
  }

  bool _readAutoTrailerAutoPublishFromUrl(String rawUrl) {
    try {
      final u = Uri.parse(rawUrl);
      final raw = (u.queryParameters['gfTrailerAutoPublish'] ?? '')
          .trim()
          .toLowerCase();
      if (raw == '0' || raw == 'false' || raw == 'no') return false;
      if (raw == '1' || raw == 'true' || raw == 'yes') return true;
    } catch (_) {}
    return true;
  }

  int _fallbackAutoTrailerEtaByStatus() {
    final s = _autoTrailerStatus.trim().toLowerCase();
    if (s == 'recording') {
      final startedMs = _autoTrailerCaptureStartMs;
      if (startedMs > 0) {
        final elapsed = ((DateTime.now().millisecondsSinceEpoch - startedMs) /
                1000)
            .floor()
            .clamp(0, 240);
        return (75 - elapsed).clamp(8, 75);
      }
      return 60;
    }
    if (s == 'queued') return 35;
    if (s == 'processing') return 28;
    if (s == 'submitting') return 22;
    if (s == 'ready') return 0;
    return 30;
  }

  int _effectiveAutoTrailerEtaSec() {
    final direct = _autoTrailerEtaSec;
    if (direct != null && direct >= 0) return direct;
    final total = _autoTrailerEstimatedTotalSec;
    final elapsed = _autoTrailerElapsedSec;
    if (total != null && elapsed != null) {
      return (total - elapsed).clamp(0, 3600);
    }
    return _fallbackAutoTrailerEtaByStatus();
  }

  String _fmtAutoTrailerEta(int? sec) {
    final value = (sec ?? _effectiveAutoTrailerEtaSec()).clamp(0, 3600);
    final m = value ~/ 60;
    final s = value % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _fmtAutoTrailerTotalEstimate() {
    final total = (_autoTrailerEstimatedTotalSec ??
            ((_autoTrailerElapsedSec ?? 0) + _effectiveAutoTrailerEtaSec()))
        .clamp(0, 3600);
    final m = total ~/ 60;
    final s = total % 60;
    return '~${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _startAutoTrailerEtaTicker() {
    _autoTrailerEtaTicker?.cancel();
    _autoTrailerEtaTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_autoTrailerStatus == 'ready' || _autoTrailerStatus == 'failed') {
        return;
      }
      final cur = _autoTrailerEtaSec;
      if (cur != null && cur > 0) {
        setState(() => _autoTrailerEtaSec = cur - 1);
        return;
      }

      final fallback = _fallbackAutoTrailerEtaByStatus();
      if (fallback > 0) {
        setState(() => _autoTrailerEtaSec = fallback);
      }
    });
  }

  void _startAutoTrailerPolling() {
    _autoTrailerPoll?.cancel();
    _autoTrailerPoll = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _checkAutoTrailerStatus(notifyOnReady: false);
    });
  }

  Future<Map<String, dynamic>> _readAutoTrailerRecorderState() async {
    final res = await _runJsResult("""
      (function(){
        try {
          var rec = window.__gfTrailerRecorder;
          if (!rec) {
            return JSON.stringify({ state: 'missing', uploadedUrl: '', error: '' });
          }
          return JSON.stringify({
            state: String(rec.state || ''),
            uploadedUrl: String(rec.uploadedUrl || ''),
            error: String(rec.error || ''),
            supportReason: String(rec.supportReason || ''),
            hasBlob: !!rec.blob,
            mime: String(rec.mime || ''),
            blobSize: Number(rec.blob && rec.blob.size ? rec.blob.size : 0),
            recordedMs: Number(rec.recordedMs || 0)
          });
        } catch(e) {
          return JSON.stringify({ state: 'error', uploadedUrl: '', error: String(e && e.message ? e.message : e) });
        }
      })();
      """);

    String? s;
    if (res is String) {
      s = res;
    } else if (res != null) {
      s = res.toString();
    }

    try {
      if (s == null) return <String, dynamic>{};
      final decoded = jsonDecode(s);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      if (decoded is String) {
        final decoded2 = jsonDecode(decoded);
        if (decoded2 is Map) return Map<String, dynamic>.from(decoded2);
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _startAutoTrailerCanvasRecorder() async {
    if (!_autoTrailerMode) return;
    if (_autoTrailerRecorderActive) return;

    final js = """
      (function(){
        try {
          var rec = window.__gfTrailerRecorder || (window.__gfTrailerRecorder = {});
          if (rec.state === 'recording') return true;

          var canvas = document.querySelector('canvas');
          if (!canvas || !canvas.captureStream) {
            rec.state = 'unsupported';
            rec.supportReason = !canvas ? 'canvas-not-found' : 'capture-stream-not-supported';
            return false;
          }

          var mime = '';
          try {
            if (window.MediaRecorder && MediaRecorder.isTypeSupported && MediaRecorder.isTypeSupported('video/mp4;codecs="avc1.42E01E,mp4a.40.2"')) {
              mime = 'video/mp4;codecs="avc1.42E01E,mp4a.40.2"';
            } else if (window.MediaRecorder && MediaRecorder.isTypeSupported && MediaRecorder.isTypeSupported('video/mp4')) {
              mime = 'video/mp4';
            } else if (window.MediaRecorder && MediaRecorder.isTypeSupported && MediaRecorder.isTypeSupported('video/webm;codecs=vp9')) {
              mime = 'video/webm;codecs=vp9';
            } else if (window.MediaRecorder && MediaRecorder.isTypeSupported && MediaRecorder.isTypeSupported('video/webm;codecs=vp8')) {
              mime = 'video/webm;codecs=vp8';
            } else {
              mime = 'video/webm';
            }
          } catch(_) {
            mime = 'video/webm';
          }

          var stream = canvas.captureStream(24);
          var opts = { videoBitsPerSecond: 1200000 };
          if (mime) opts.mimeType = mime;
          var mr = new MediaRecorder(stream, opts);
          var chunks = [];

          mr.ondataavailable = function(ev){
            try {
              if (ev && ev.data && ev.data.size > 0) chunks.push(ev.data);
            } catch(_) {}
          };

          mr.onstop = function(){
            try {
              rec.blob = new Blob(chunks, { type: mime || 'video/webm' });
              rec.recordedMs = Math.max(0, Date.now() - Number(rec.startedAt || Date.now()));
              rec.state = 'recorded';
            } catch (e) {
              rec.state = 'failed';
              rec.error = String(e && e.message ? e.message : e);
            }
          };

          rec.uploadedUrl = '';
          rec.error = '';
          rec.mime = mime;
          rec.startedAt = Date.now();
          rec.chunks = chunks;
          rec.stream = stream;
          rec.mediaRecorder = mr;
          rec.state = 'recording';
          mr.start(350);
          return true;
        } catch(e) {
          try {
            var rec2 = window.__gfTrailerRecorder || (window.__gfTrailerRecorder = {});
            rec2.state = 'failed';
            rec2.error = String(e && e.message ? e.message : e);
          } catch(_) {}
          return false;
        }
      })();
      """;

    var ok = false;
    String support = '';
    for (var i = 0; i < 10; i++) {
      ok = await _runJsReturningBool(js);
      if (ok) break;
      final st = await _readAutoTrailerRecorderState();
      support = (st['supportReason'] ?? '').toString().trim();
      if (support == 'canvas-not-found') {
        await Future.delayed(const Duration(milliseconds: 450));
        continue;
      }
      break;
    }

    if (!ok) {
      if (support.isNotEmpty) {
        AppNotifier.showError('Gameplay recorder unavailable: $support');
      }
      return;
    }
    _autoTrailerRecorderBooted = true;
    _autoTrailerRecorderActive = true;
  }

  Future<void> _stopAndUploadAutoTrailerCanvasRecorder() async {
    if (!_autoTrailerMode) return;
    if (!_autoTrailerRecorderBooted) return;

    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    final pid = (_projectId ?? '').trim();
    final apiBase = ApiService.baseUrl;
    final tokenJs = jsonEncode(token.trim());
    final apiBaseJs = jsonEncode(apiBase);
    final pidJs = jsonEncode(pid.isEmpty ? 'unknown' : pid);
  const minRecordMs = _autoTrailerMinRecordMs;
  const minBlobBytes = _autoTrailerMinBlobBytes;

    await _runJs("""
      (function(){
        try {
          var rec = window.__gfTrailerRecorder;
          if (!rec) return;
          if (rec.state === 'uploaded') return;
          if (rec.state === 'uploading') return;

          var token = $tokenJs;
          var apiBase = $apiBaseJs;
          var projectId = $pidJs;

          function finalizeUpload(){
            try {
              if (!rec.blob) {
                rec.state = 'failed';
                rec.error = rec.error || 'Missing recorded blob';
                return;
              }

              var recordedMs = Number(rec.recordedMs || (Date.now() - Number(rec.startedAt || Date.now())));
              var blobSize = Number(rec.blob.size || 0);
              if (!isFinite(blobSize) || blobSize < $minBlobBytes) {
                rec.state = 'failed';
                rec.error = 'Recorded clip too small';
                return;
              }
              if (!isFinite(recordedMs) || recordedMs < $minRecordMs) {
                rec.state = 'failed';
                rec.error = 'Recorded clip too short';
                return;
              }

              rec.state = 'uploading';
              var baseNoSlash = String(apiBase || '');
              if (baseNoSlash.endsWith('/')) {
                baseNoSlash = baseNoSlash.slice(0, -1);
              }
              var ext = 'webm';
              var blobType = String(rec.blob.type || '').toLowerCase();
              if (blobType.indexOf('mp4') >= 0) ext = 'mp4';
              var filename = 'gf_trailer_' + Date.now() + '.' + ext;
              var form = new FormData();
              form.append('file', rec.blob, filename);
              form.append('type', 'other');
              form.append('name', 'Gameplay trailer clip');
              form.append('tags', 'trailer,gameplay,autocapture,' + projectId);

              fetch(baseNoSlash + '/assets/upload', {
                method: 'POST',
                headers: {
                  'Authorization': 'Bearer ' + token,
                  'Accept': 'application/json'
                },
                body: form,
              }).then(function(resp){
                return resp.text().then(function(txt){
                  var payload = null;
                  try { payload = JSON.parse(txt); } catch(_) { payload = null; }
                  if (!resp.ok || !payload || payload.success !== true || !payload.data) {
                    var msg = (payload && payload.message) ? String(payload.message) : ('Upload failed (' + resp.status + ')');
                    throw new Error(msg);
                  }
                  var key = String((payload.data && payload.data.storageKey) || '').trim();
                  if (!key) throw new Error('Missing storage key');
                  var url = baseNoSlash + '/assets/files/' + encodeURIComponent(key);
                  rec.uploadedUrl = url;
                  rec.mime = String(rec.blob && rec.blob.type ? rec.blob.type : rec.mime || '');
                  rec.state = 'uploaded';
                  rec.error = '';
                });
              }).catch(function(e){
                rec.state = 'failed';
                rec.error = String(e && e.message ? e.message : e);
              });
            } catch (e) {
              rec.state = 'failed';
              rec.error = String(e && e.message ? e.message : e);
            }
          }

          try {
            if (rec.mediaRecorder && rec.mediaRecorder.state === 'recording') {
              var elapsed = Math.max(0, Date.now() - Number(rec.startedAt || Date.now()));
              var waitMs = Math.max(0, $minRecordMs - elapsed);
              var doStop = function(){
                try {
                  rec.mediaRecorder.onstop = function(){
                    try {
                      rec.blob = new Blob(rec.chunks || [], { type: rec.mime || 'video/webm' });
                      rec.recordedMs = Math.max(0, Date.now() - Number(rec.startedAt || Date.now()));
                    } catch(_) {}
                    finalizeUpload();
                  };
                  rec.state = 'stopping';
                  rec.mediaRecorder.stop();
                } catch (e) {
                  rec.state = 'failed';
                  rec.error = String(e && e.message ? e.message : e);
                }
              };
              if (waitMs > 0) {
                rec.state = 'recording-min-buffer';
                setTimeout(doStop, waitMs);
              } else {
                doStop();
              }
            } else {
              if (!rec.blob && rec.chunks && rec.chunks.length > 0) {
                try { rec.blob = new Blob(rec.chunks, { type: rec.mime || 'video/webm' }); } catch(_) {}
              }
              finalizeUpload();
            }
          } catch (e) {
            rec.state = 'failed';
            rec.error = String(e && e.message ? e.message : e);
          }
        } catch(_) {}
      })();
      """);

    for (var i = 0; i < 30; i++) {
      final st = await _readAutoTrailerRecorderState();
      final state = (st['state'] ?? '').toString().trim().toLowerCase();
      final url = (st['uploadedUrl'] ?? '').toString().trim();
      if (state == 'uploaded' && url.isNotEmpty) {
        final mime = (st['mime'] ?? '').toString().trim().toLowerCase();
        final blobSize = (st['blobSize'] is num)
            ? (st['blobSize'] as num).toInt()
            : int.tryParse((st['blobSize'] ?? '').toString()) ??
                  0;
        final recMs = (st['recordedMs'] is num)
            ? (st['recordedMs'] as num).toInt()
            : int.tryParse((st['recordedMs'] ?? '').toString()) ??
                  0;

        if (blobSize < _autoTrailerMinBlobBytes ||
            recMs < _autoTrailerMinRecordMs) {
          _autoTrailerRecordedSourceUrl = null;
          _autoTrailerRecorderActive = false;
          if (mounted) {
            setState(() {
              _autoTrailerStage = 'live capture failed • fallback source';
            });
          }
          AppNotifier.showError(
            'Gameplay clip invalid (too short/small), fallback source will be used.',
          );
          return;
        }

        if (defaultTargetPlatform == TargetPlatform.iOS && mime.contains('webm')) {
          if (mounted) {
            setState(() {
              _autoTrailerStage = 'webm captured on iOS • using source';
            });
          }
        }

        _autoTrailerRecordedSourceUrl = url;
        _autoTrailerRecorderActive = false;
        return;
      }
      if (state == 'failed') {
        _autoTrailerRecorderActive = false;
        final err = (st['error'] ?? '').toString().trim();
        if (mounted) {
          setState(() {
            _autoTrailerStage = 'live capture failed • fallback source';
          });
        }
        if (err.isNotEmpty) {
          AppNotifier.showError('Gameplay capture upload failed: $err');
        }
        return;
      }
      await Future.delayed(const Duration(milliseconds: 400));
    }

    _autoTrailerRecorderActive = false;
  }

  void _pushAutoTrailerEvent(String type, {int? scoreDelta}) {
    final normalizedType = type.trim().toLowerCase();
    if (normalizedType.isEmpty) return;
    if (_autoTrailerCaptureStartMs <= 0) {
      _autoTrailerCaptureStartMs = DateTime.now().millisecondsSinceEpoch;
    }

    final tSec =
        ((DateTime.now().millisecondsSinceEpoch - _autoTrailerCaptureStartMs)
            .clamp(0, 3600 * 1000)) /
        1000.0;

    if (_autoTrailerEvents.isNotEmpty) {
      final last = _autoTrailerEvents.last;
      final lastType = (last['type'] ?? '').toString().trim().toLowerCase();
      final lastT = (last['t'] is num) ? (last['t'] as num).toDouble() : 0.0;
      if (lastType == normalizedType && (tSec - lastT).abs() < 1.2) {
        return;
      }
    }

    _autoTrailerEvents.add(<String, dynamic>{
      't': double.parse(tSec.toStringAsFixed(2)),
      'type': normalizedType,
      if (scoreDelta != null) 'scoreDelta': scoreDelta,
    });

    if (_autoTrailerEvents.length > 64) {
      _autoTrailerEvents.removeAt(0);
    }
  }

  Future<void> _captureAutoTrailerMoment({String? forceType}) async {
    if (!_autoTrailerMode) return;

    Map<String, dynamic> metrics = <String, dynamic>{};
    try {
      metrics = await _probeGameResultTelemetry();
    } catch (_) {
      metrics = <String, dynamic>{};
    }

    int intVal(dynamic v) {
      if (v is num) return v.toInt();
      final parsed = int.tryParse((v ?? '').toString().trim());
      return parsed ?? 0;
    }

    final scoreTotal = intVal(metrics['scoreTotal']);
    final coins = intVal(metrics['coins']);
    final outcome = (metrics['outcome'] ?? '').toString().trim().toLowerCase();

    if (forceType != null && forceType.trim().isNotEmpty) {
      _pushAutoTrailerEvent(forceType, scoreDelta: scoreTotal);
    }

    if (scoreTotal > _autoTrailerLastScore) {
      final delta = scoreTotal - _autoTrailerLastScore;
      _autoTrailerLastScore = scoreTotal;
      final eventType = delta >= 120
          ? 'combo'
          : delta >= 45
          ? 'kill'
          : 'score';
      _pushAutoTrailerEvent(eventType, scoreDelta: delta);
    }

    if (coins > _autoTrailerLastCoins) {
      final coinDelta = coins - _autoTrailerLastCoins;
      _autoTrailerLastCoins = coins;
      _pushAutoTrailerEvent('coin', scoreDelta: coinDelta * 5);
    }

    if (outcome == 'win' || outcome == 'loss') {
      _pushAutoTrailerEvent(outcome, scoreDelta: scoreTotal);
    }
  }

  void _startAutoTrailerCapture() {
    _autoTrailerCaptureTick?.cancel();
    _autoTrailerCaptureStartMs = DateTime.now().millisecondsSinceEpoch;
    _autoTrailerLastScore = 0;
    _autoTrailerLastCoins = 0;
    _autoTrailerEvents.clear();
    _autoTrailerFinalized = false;
    _autoTrailerPublishedToFeed = false;
    _autoTrailerRecordedSourceUrl = null;
    _autoTrailerRecorderBooted = false;
    _autoTrailerRecorderActive = false;

    if (mounted) {
      setState(() {
        _autoTrailerStatus = 'recording';
        _autoTrailerStage =
            'capturing live gameplay + best moments (${_autoTrailerStyle.toUpperCase()})';
        _autoTrailerEstimatedTotalSec = 75;
        _autoTrailerElapsedSec = 0;
        _autoTrailerEtaSec = 75;
      });
    }

    _autoTrailerCaptureTick = Timer.periodic(const Duration(seconds: 4), (_) {
      _captureAutoTrailerMoment();
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      _captureAutoTrailerMoment();
    });
  }

  Future<void> _bootAutoTrailerJob({List<Map<String, dynamic>>? events}) async {
    if (!_autoTrailerMode) return;
    if (_autoTrailerSubmitting) return;
    if ((_autoTrailerId ?? '').trim().isNotEmpty) return;
    final pid = (_projectId ?? '').trim();
    if (pid.isEmpty) return;
    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    _autoTrailerSubmitting = true;
    try {
      final createRes = await TrailersService.createTrailer(
        token: token,
        projectId: pid,
        sourceVideoUrl: (_autoTrailerRecordedSourceUrl ?? '').trim().isNotEmpty
            ? _autoTrailerRecordedSourceUrl!.trim()
            : null,
        style: _autoTrailerStyle,
        target: _autoTrailerTarget,
        events: (events != null && events.isNotEmpty) ? events : null,
      );
      if (createRes['success'] != true || createRes['data'] is! Map) {
        throw Exception(
          createRes['message']?.toString() ?? 'Failed to start reel generation',
        );
      }

      final data = Map<String, dynamic>.from(createRes['data'] as Map);
      final trailerId = (data['trailerId'] ?? '').toString().trim();
      if (trailerId.isEmpty) throw Exception('Missing trailer id');

      if (mounted) {
        setState(() {
          _autoTrailerId = trailerId;
          _autoTrailerStatus = (data['status'] ?? 'queued')
              .toString()
              .trim()
              .toLowerCase();
          _autoTrailerStage = (data['stage'] ?? 'queued').toString().trim();
          _autoTrailerEtaSec = (data['etaSec'] is num)
              ? (data['etaSec'] as num).toInt()
              : _autoTrailerEtaSec;
      _autoTrailerEstimatedTotalSec = (data['estimatedTotalSec'] is num)
        ? (data['estimatedTotalSec'] as num).toInt()
        : _autoTrailerEstimatedTotalSec;
      _autoTrailerElapsedSec = (data['elapsedSec'] is num)
        ? (data['elapsedSec'] as num).toInt()
        : _autoTrailerElapsedSec;
        });
      }

      _startAutoTrailerEtaTicker();
      _startAutoTrailerPolling();
      await _checkAutoTrailerStatus(notifyOnReady: false);
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(e.toString());
    } finally {
      _autoTrailerSubmitting = false;
    }
  }

  Future<void> _autoPublishTrailerToFeedIfNeeded() async {
    if (!_autoTrailerAutoPublishEnabled) return;
    if (_autoTrailerPublishedToFeed) return;
    final trailerId = (_autoTrailerId ?? '').trim();
    if (trailerId.isEmpty) return;

    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    final pub = await TrailersService.publishTrailerToFeed(
      token: token,
      trailerId: trailerId,
    );
    if (pub['success'] == true) {
      _autoTrailerPublishedToFeed = true;
      AppNotifier.showSuccess('🚀 Reel published to Arcade feed');
      return;
    }

    AppNotifier.showError(
      pub['message']?.toString() ?? 'Could not publish reel to feed',
    );
  }

  Future<void> _checkAutoTrailerStatus({
    bool notifyOnReady = true,
    bool publishOnReady = false,
  }) async {
    final trailerId = (_autoTrailerId ?? '').trim();
    if (trailerId.isEmpty) {
      final status = _autoTrailerStatus.trim().toLowerCase();
      if (status == 'recording' && !_autoTrailerFinalized) {
        return;
      }
      if (_autoTrailerEvents.isNotEmpty) {
        await _bootAutoTrailerJob(
          events: List<Map<String, dynamic>>.from(_autoTrailerEvents),
        );
      }
      return;
    }
    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    try {
      final stRes = await TrailersService.getTrailerStatus(
        token: token,
        trailerId: trailerId,
      );
      if (stRes['success'] != true || stRes['data'] is! Map) return;

      final st = Map<String, dynamic>.from(stRes['data'] as Map);
      final status = (st['status'] ?? '').toString().trim().toLowerCase();
      final stage = (st['stage'] ?? '').toString().trim();
      final etaSec = (st['etaSec'] is num)
          ? (st['etaSec'] as num).toInt()
          : null;
      final estimatedTotalSec = (st['estimatedTotalSec'] is num)
          ? (st['estimatedTotalSec'] as num).toInt()
          : null;
      final elapsedSec = (st['elapsedSec'] is num)
          ? (st['elapsedSec'] as num).toInt()
          : null;

      if (mounted) {
        setState(() {
          _autoTrailerStatus = status;
          _autoTrailerStage = stage.isEmpty ? _autoTrailerStage : stage;
          _autoTrailerEtaSec = etaSec ?? _autoTrailerEtaSec;
          _autoTrailerEstimatedTotalSec =
              estimatedTotalSec ?? _autoTrailerEstimatedTotalSec;
          _autoTrailerElapsedSec = elapsedSec ?? _autoTrailerElapsedSec;
        });
      }

      if (status == 'failed') {
        _autoTrailerPoll?.cancel();
        _autoTrailerEtaTicker?.cancel();
        AppNotifier.showError(
          st['error']?.toString() ?? 'Reel generation failed',
        );
        return;
      }

      if (status == 'ready') {
        _autoTrailerPoll?.cancel();
        _autoTrailerEtaTicker?.cancel();
        final resultRes = await TrailersService.getTrailerResult(
          token: token,
          trailerId: trailerId,
        );
        if (resultRes['success'] == true && resultRes['data'] is Map) {
          final result = Map<String, dynamic>.from(resultRes['data'] as Map);
          final videoUrl = (result['videoUrl'] ?? '').toString().trim();
          if (mounted) {
            setState(() {
              _autoTrailerVideoUrl = videoUrl.isEmpty
                  ? _autoTrailerVideoUrl
                  : videoUrl;
              _autoTrailerEtaSec = 0;
              _autoTrailerElapsedSec = _autoTrailerEstimatedTotalSec;
              _autoTrailerStage = 'ready';
            });
          }
        }
        if (notifyOnReady) {
          AppNotifier.showSuccess(
            '🎬 Reel is ready, tap Check Reel to open it',
          );
        }
        if (publishOnReady) {
          await _autoPublishTrailerToFeedIfNeeded();
        }
        return;
      }

      if (status == 'queued' || status == 'processing') {
        _startAutoTrailerEtaTicker();
      }
    } catch (_) {}
  }

  Future<void> _finalizeAutoTrailerPipeline() async {
    if (!_autoTrailerMode) return;
    if (_autoTrailerFinishing) return;
    if (_autoTrailerFinalized) return;

    if (mounted) {
      setState(() {
        _autoTrailerFinishing = true;
      });
    } else {
      _autoTrailerFinishing = true;
    }
    try {
      _autoTrailerCaptureTick?.cancel();
      await _stopAndUploadAutoTrailerCanvasRecorder();
      await _captureAutoTrailerMoment(forceType: 'session_end');
      _autoTrailerFinalized = true;

      if ((_autoTrailerId ?? '').trim().isEmpty) {
        await _bootAutoTrailerJob(
          events: List<Map<String, dynamic>>.from(_autoTrailerEvents),
        );
      }

      if ((_autoTrailerId ?? '').trim().isEmpty) {
        AppNotifier.showError('Could not start reel generation');
        return;
      }

      if (mounted) {
        setState(() {
          _autoTrailerStatus = 'processing';
          _autoTrailerStage =
              'building wow reel (${_autoTrailerStyle.toUpperCase()})';
          _autoTrailerEtaSec = _autoTrailerEtaSec ?? 35;
        });
      }

      for (var i = 0; i < 10; i++) {
        await _checkAutoTrailerStatus(
          notifyOnReady: i == 9,
          publishOnReady: _autoTrailerAutoPublishEnabled,
        );
        if (_autoTrailerStatus == 'ready' || _autoTrailerStatus == 'failed') {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 900));
      }

      if (_autoTrailerStatus != 'ready') {
        AppNotifier.showSuccess(
          '🎬 Reel is processing in background. Use Check Reel to follow progress.',
        );
      } else if (!_autoTrailerAutoPublishEnabled) {
        AppNotifier.showSuccess(
          '🎬 Reel ready. Publish manually from Check Reel.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _autoTrailerFinishing = false;
        });
      } else {
        _autoTrailerFinishing = false;
      }
    }
  }

  Future<void> _openAutoTrailerOptionsSheet() async {
    var style = _autoTrailerStyle;
    var target = _autoTrailerTarget;
    var autoPublish = _autoTrailerAutoPublishEnabled;

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Trailer Options',
                    style: AppTypography.subtitle1.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Customize reel style and publishing mode.',
                    style: AppTypography.caption.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Style', style: AppTypography.body2),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in const ['energetic', 'cinematic', 'funny'])
                        ChoiceChip(
                          selected: style == s,
                          label: Text(s),
                          onSelected: (_) => setModal(() => style = s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Target', style: AppTypography.body2),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final t in const ['reels', 'tiktok', 'short'])
                        ChoiceChip(
                          selected: target == t,
                          label: Text(t),
                          onSelected: (_) => setModal(() => target = t),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: autoPublish,
                    onChanged: (v) => setModal(() => autoPublish = v),
                    title: const Text('Auto publish to feed'),
                    subtitle: Text(
                      autoPublish
                          ? 'When reel is ready, publish automatically to Arcade.'
                          : 'Reel will be generated only, then you publish manually.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (!mounted) return;
                        setState(() {
                          _autoTrailerStyle = style;
                          _autoTrailerTarget = target;
                          _autoTrailerAutoPublishEnabled = autoPublish;
                        });
                        Navigator.of(ctx).pop();
                        AppNotifier.showSuccess(
                          'Trailer options updated: $style • $target • ${autoPublish ? 'auto-publish ON' : 'auto-publish OFF'}',
                        );
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadFpsControlsPref() async {
    final pid = _projectId;
    if (pid == null || pid.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool('$_kPrefFpsControlsPrefix$pid') ?? false;
      if (!mounted) return;
      setState(() => _fpsControlsEnabled = v);
    } catch (_) {}
  }

  String? _normHex(String? v) {
    if (v == null) return null;
    var s = v.trim();
    if (s.isEmpty) return null;
    if (!s.startsWith('#') && s.length == 6) s = '#$s';
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(s)) return null;
    return s.toUpperCase();
  }

  Future<Map<String, dynamic>?> _fetchRuntimeConfig() async {
    final pid = _projectId;
    if (pid == null || pid.isEmpty) return null;
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) return null;
    final res = await ProjectsService.getProjectRuntimeConfig(
      token: token,
      projectId: pid,
    );
    final data = res['data'];
    if (res['success'] == true && data is Map) {
      final cfg = Map<String, dynamic>.from(data as Map);
      _lastRuntimeConfig = cfg;
      return cfg;
    }
    return null;
  }

  Future<void> _applySuggestedPreset(Map<String, dynamic> preset) async {
    final base =
        _lastRuntimeConfig ??
        (await _fetchRuntimeConfig()) ??
        <String, dynamic>{};

    double numOr(double fallback, dynamic v) {
      if (v is num) return v.toDouble();
      final s = (v ?? '').toString().trim();
      final p = double.tryParse(s);
      return p ?? fallback;
    }

    final speed = numOr(
      (base['speed'] is num) ? (base['speed'] as num).toDouble() : 7.0,
      preset['speed'],
    );
    final timeScale = numOr(
      (base['timeScale'] is num) ? (base['timeScale'] as num).toDouble() : 1.0,
      preset['timeScale'],
    );
    final difficulty = numOr(
      (base['difficulty'] is num)
          ? (base['difficulty'] as num).toDouble()
          : 0.5,
      preset['difficulty'],
    );

    await _applyRuntimeConfig(
      speed: speed,
      timeScale: timeScale,
      difficulty: difficulty,
      theme: (base['theme']?.toString() ?? 'default'),
      notes: (base['notes']?.toString() ?? ''),
      genre: (base['genre']?.toString() ?? 'platformer'),
      assetsType: (base['assetsType']?.toString() ?? 'lowpoly'),
      mechanics: (base['mechanics'] is List)
          ? (base['mechanics'] as List)
                .map((e) => e?.toString() ?? '')
                .where((e) => e.trim().isNotEmpty)
                .toList()
          : const <String>[],
      primaryColor: (base['primaryColor']?.toString() ?? '#22C55E'),
      secondaryColor: (base['secondaryColor']?.toString() ?? '#3B82F6'),
      accentColor: (base['accentColor']?.toString() ?? '#F59E0B'),
      playerColor:
          (base['playerColor']?.toString() ??
          (base['accentColor']?.toString() ?? '#F59E0B')),
      fogEnabled: (base['fogEnabled'] is bool)
          ? (base['fogEnabled'] as bool)
          : false,
      fogDensity: (base['fogDensity'] is num)
          ? (base['fogDensity'] as num).toDouble()
          : 0.0,
      cameraZoom: (base['cameraZoom'] is num)
          ? (base['cameraZoom'] as num).toDouble()
          : 0.0,
      gravityY: (base['gravityY'] is num)
          ? (base['gravityY'] as num).toDouble()
          : 0.0,
      jumpForce: (base['jumpForce'] is num)
          ? (base['jumpForce'] as num).toDouble()
          : 0.0,
      playerSkinId: base['playerSkinId']?.toString(),
      playerSpriteUrl: base['playerSpriteUrl']?.toString(),
      reloadWebView: false,
    );
  }

  ({Map<String, dynamic> patch, bool? autoBalance}) _parseVoiceCommand(
    String text,
  ) {
    String normalizeSpokenNumbers(String input) {
      var s = input.toLowerCase();

      final multiWord = <String, String>{
        // English
        'zero': '0',
        'one': '1',
        'two': '2',
        'three': '3',
        'four': '4',
        'five': '5',
        'six': '6',
        'seven': '7',
        'eight': '8',
        'nine': '9',
        'ten': '10',
        'eleven': '11',
        'twelve': '12',
        'thirteen': '13',
        'fourteen': '14',
        'fifteen': '15',
        'sixteen': '16',
        'seventeen': '17',
        'eighteen': '18',
        'nineteen': '19',
        'twenty': '20',
        // French (common)
        'zéro': '0',
        'zero': '0',
        'un': '1',
        'deux': '2',
        'trois': '3',
        'quatre': '4',
        'cinq': '5',
        'six': '6',
        'sept': '7',
        'huit': '8',
        'neuf': '9',
        'dix': '10',
        'onze': '11',
        'douze': '12',
        'treize': '13',
        'quatorze': '14',
        'quinze': '15',
        'seize': '16',
        'vingt': '20',
      };

      // Replace whole words only (prevents five->fiver issues).
      multiWord.forEach((k, v) {
        s = s.replaceAllMapped(
          RegExp('\\b' + RegExp.escape(k) + '\\b'),
          (_) => v,
        );
      });

      return s;
    }

    final t = normalizeSpokenNumbers(text.trim());

    bool? matchAutoBalance() {
      final m = RegExp(
        r'(?:auto\s*-?\s*balance|autobalance)\s*(on|off|true|false|enable|disable)',
      ).firstMatch(t);
      if (m == null) return null;
      final v = (m.group(1) ?? '').trim();
      if (v == 'on' || v == 'true' || v == 'enable') return true;
      if (v == 'off' || v == 'false' || v == 'disable') return false;
      return null;
    }

    double? matchNum(RegExp r) {
      final m = r.firstMatch(t);
      if (m == null) return null;
      final raw = (m.group(1) ?? '').replaceAll(',', '.');
      return double.tryParse(raw);
    }

    bool? matchBool(RegExp r) {
      final m = r.firstMatch(t);
      if (m == null) return null;
      final raw = (m.group(1) ?? '').trim().toLowerCase();
      if (raw == 'on' || raw == 'true' || raw == 'enable' || raw == 'enabled')
        return true;
      if (raw == 'off' ||
          raw == 'false' ||
          raw == 'disable' ||
          raw == 'disabled')
        return false;
      return null;
    }

    String? matchHexColor(RegExp r) {
      final m = r.firstMatch(t);
      if (m == null) return null;
      final raw = (m.group(1) ?? '').trim();
      final h = _normHex(raw);
      return h;
    }

    String? matchNamedColor(RegExp r) {
      final m = r.firstMatch(t);
      if (m == null) return null;
      final raw = (m.group(1) ?? '').trim().toLowerCase();
      if (raw.isEmpty) return null;

      final colors = <String, String>{
        'red': '#EF4444',
        'rouge': '#EF4444',
        'blue': '#3B82F6',
        'bleu': '#3B82F6',
        'green': '#22C55E',
        'vert': '#22C55E',
        'yellow': '#F59E0B',
        'jaune': '#F59E0B',
        'orange': '#F97316',
        'purple': '#7C3AED',
        'violet': '#7C3AED',
        'pink': '#EC4899',
        'rose': '#EC4899',
        'black': '#111827',
        'noir': '#111827',
        'white': '#F8FAFC',
        'blanc': '#F8FAFC',
        'cyan': '#06B6D4',
        'teal': '#14B8A6',
        'gray': '#94A3B8',
        'grey': '#94A3B8',
        'gris': '#94A3B8',
        // common combos
        'neon': '#F59E0B',
        'neon pink': '#F0ABFC',
        'magenta': '#DB2777',
      };

      final v = colors[raw];
      return v == null ? null : _normHex(v);
    }

    String? matchWordAfter(RegExp r) {
      final m = r.firstMatch(t);
      if (m == null) return null;
      final raw = (m.group(1) ?? '').trim();
      if (raw.isEmpty) return null;
      return raw;
    }

    final patch = <String, dynamic>{};

    final speed = matchNum(
      RegExp(r'(?:speed|vitesse)\s*([0-9]+(?:[\.,][0-9]+)?)'),
    );
    final difficulty = matchNum(
      RegExp(
        r'(?:difficulty|difficulte|difficulté)\s*([0-9]+(?:[\.,][0-9]+)?)',
      ),
    );
    final timeScale = matchNum(
      RegExp(r'(?:timescale|time\s*scale)\s*([0-9]+(?:[\.,][0-9]+)?)'),
    );
    final cameraZoom = matchNum(
      RegExp(r'(?:camera\s*zoom|zoom)\s*([0-9]+(?:[\.,][0-9]+)?)'),
    );
    final gravityY = matchNum(
      RegExp(r'(?:gravity\s*y|gravity)\s*([\-]?[0-9]+(?:[\.,][0-9]+)?)'),
    );
    final jumpForce = matchNum(
      RegExp(r'(?:jump\s*force|jump)\s*([0-9]+(?:[\.,][0-9]+)?)'),
    );
    final fogDensity = matchNum(
      RegExp(r'(?:fog\s*density)\s*([0-9]+(?:[\.,][0-9]+)?)'),
    );
    final fogEnabled = matchBool(
      RegExp(r'(?:fog)\s*(on|off|true|false|enable|disable|enabled|disabled)'),
    );

    final primaryColor =
        matchHexColor(
          RegExp(r'(?:primary\s*color|primary)\s*(#[0-9a-f]{6}|[0-9a-f]{6})'),
        ) ??
        matchNamedColor(
          RegExp(r'(?:primary\s*color|primary)\s*([a-z\s]{3,20})'),
        );
    final secondaryColor =
        matchHexColor(
          RegExp(
            r'(?:secondary\s*color|secondary)\s*(#[0-9a-f]{6}|[0-9a-f]{6})',
          ),
        ) ??
        matchNamedColor(
          RegExp(r'(?:secondary\s*color|secondary)\s*([a-z\s]{3,20})'),
        );
    final accentColor =
        matchHexColor(
          RegExp(r'(?:accent\s*color|accent)\s*(#[0-9a-f]{6}|[0-9a-f]{6})'),
        ) ??
        matchNamedColor(RegExp(r'(?:accent\s*color|accent)\s*([a-z\s]{3,20})'));
    final playerColor =
        matchHexColor(
          RegExp(r'(?:player\s*color|player)\s*(#[0-9a-f]{6}|[0-9a-f]{6})'),
        ) ??
        matchNamedColor(RegExp(r'(?:player\s*color|player)\s*([a-z\s]{3,20})'));

    final theme = matchWordAfter(RegExp(r'(?:theme)\s+([a-z0-9_\- ]{2,40})'));
    final genre = matchWordAfter(RegExp(r'(?:genre)\s+([a-z0-9_\- ]{2,40})'));
    final assetsType = matchWordAfter(
      RegExp(r'(?:assets\s*type|asset\s*type|assets)\s+([a-z0-9_\- ]{2,40})'),
    );

    if (speed != null) patch['speed'] = speed;
    if (difficulty != null) patch['difficulty'] = difficulty;
    if (timeScale != null) patch['timeScale'] = timeScale;
    if (cameraZoom != null) patch['cameraZoom'] = cameraZoom;
    if (gravityY != null) patch['gravityY'] = gravityY;
    if (jumpForce != null) patch['jumpForce'] = jumpForce;
    if (fogDensity != null) patch['fogDensity'] = fogDensity;
    if (fogEnabled != null) patch['fogEnabled'] = fogEnabled;
    if (primaryColor != null) patch['primaryColor'] = primaryColor;
    if (secondaryColor != null) patch['secondaryColor'] = secondaryColor;
    if (accentColor != null) patch['accentColor'] = accentColor;
    if (playerColor != null) patch['playerColor'] = playerColor;
    if (theme != null) patch['theme'] = theme.trim();
    if (genre != null) patch['genre'] = genre.trim();
    if (assetsType != null) patch['assetsType'] = assetsType.trim();

    return (patch: patch, autoBalance: matchAutoBalance());
  }

  Future<void> _applyVoiceRuntimePatch({
    required Map<String, dynamic> patch,
  }) async {
    if (patch.isEmpty) return;
    final base =
        _lastRuntimeConfig ??
        (await _fetchRuntimeConfig()) ??
        <String, dynamic>{};

    double asDouble(dynamic v, double fallback) {
      if (v is num) return v.toDouble();
      final s = (v ?? '').toString().trim();
      final p = double.tryParse(s);
      return p ?? fallback;
    }

    final next = <String, dynamic>{...base, ...patch};
    _lastRuntimeConfig = next;

    await _pushRuntimeConfigToWebView(
      speed: asDouble(next['speed'], 7.0),
      timeScale: asDouble(next['timeScale'], 1.0),
      difficulty: asDouble(next['difficulty'], 0.5),
      theme: (next['theme']?.toString() ?? 'default'),
      notes: (next['notes']?.toString() ?? ''),
      genre: (next['genre']?.toString() ?? 'platformer'),
      assetsType: (next['assetsType']?.toString() ?? 'lowpoly'),
      mechanics: (next['mechanics'] is List)
          ? (next['mechanics'] as List)
                .map((e) => e?.toString() ?? '')
                .where((e) => e.trim().isNotEmpty)
                .toList()
          : const <String>[],
      primaryColor: (next['primaryColor']?.toString() ?? '#22C55E'),
      secondaryColor: (next['secondaryColor']?.toString() ?? '#3B82F6'),
      accentColor: (next['accentColor']?.toString() ?? '#F59E0B'),
      playerColor:
          (next['playerColor']?.toString() ??
          (next['accentColor']?.toString() ?? '#F59E0B')),
      fogEnabled: (next['fogEnabled'] is bool)
          ? (next['fogEnabled'] as bool)
          : false,
      fogDensity: (next['fogDensity'] is num)
          ? (next['fogDensity'] as num).toDouble()
          : 0.0,
      cameraZoom: (next['cameraZoom'] is num)
          ? (next['cameraZoom'] as num).toDouble()
          : 0.0,
      gravityY: (next['gravityY'] is num)
          ? (next['gravityY'] as num).toDouble()
          : 0.0,
      jumpForce: (next['jumpForce'] is num)
          ? (next['jumpForce'] as num).toDouble()
          : 0.0,
      playerSkinId: next['playerSkinId']?.toString(),
      playerSpriteUrl: next['playerSpriteUrl']?.toString(),
    );

    final pid = _projectId;
    final token = context.read<AuthProvider>().token;
    if (pid == null || pid.isEmpty) return;
    if (token == null || token.isEmpty) return;
    _voicePersistDebounce?.cancel();
    _voicePersistDebounce = Timer(const Duration(milliseconds: 650), () async {
      try {
        await ProjectsService.updateProject(
          token: token,
          projectId: pid,
          speed: asDouble(next['speed'], 7.0),
          timeScale: asDouble(next['timeScale'], 1.0),
          difficulty: asDouble(next['difficulty'], 0.5),
          theme: next['theme']?.toString(),
          genre: next['genre']?.toString(),
          assetsType: next['assetsType']?.toString(),
          primaryColor: next['primaryColor']?.toString(),
          secondaryColor: next['secondaryColor']?.toString(),
          accentColor: next['accentColor']?.toString(),
          playerColor: next['playerColor']?.toString(),
          fogEnabled: (next['fogEnabled'] is bool)
              ? (next['fogEnabled'] as bool)
              : null,
          fogDensity: (next['fogDensity'] is num)
              ? (next['fogDensity'] as num).toDouble()
              : null,
          cameraZoom: (next['cameraZoom'] is num)
              ? (next['cameraZoom'] as num).toDouble()
              : null,
          gravityY: (next['gravityY'] is num)
              ? (next['gravityY'] as num).toDouble()
              : null,
          jumpForce: (next['jumpForce'] is num)
              ? (next['jumpForce'] as num).toDouble()
              : null,
        );
      } catch (_) {}
    });
  }

  Future<void> _toggleVoice() async {
    if (_voiceListening) {
      try {
        await _speech.stop();
      } catch (_) {}
      if (!mounted) return;
      setState(() => _voiceListening = false);
      return;
    }

    final ok = await _speech.initialize().catchError((_) => false);
    if (ok != true) {
      if (!mounted) return;
      AppNotifier.showError('Voice unavailable');
      return;
    }

    if (!mounted) return;
    setState(() {
      _voiceListening = true;
      _voiceLast = '';
    });

    await _speech.listen(
      onResult: (res) async {
        final words = (res.recognizedWords).trim();
        if (words.isEmpty) return;
        if (!mounted) return;
        setState(() => _voiceLast = words);
        final parsed = _parseVoiceCommand(words);
        if (parsed.autoBalance != null) {
          final v = parsed.autoBalance!;
          if (!mounted) return;
          setState(() => _autoBalanceNextRun = v);
          await _saveAutoBalancePref(v);
          if (!v) {
            await _clearAutoBalancePending();
            if (!mounted) return;
            AppNotifier.showSuccess('Auto-balance OFF');
          } else {
            if (!mounted) return;
            AppNotifier.showSuccess('Auto-balance ON');
          }
        }

        await _applyVoiceRuntimePatch(patch: parsed.patch);
      },
      listenMode: stt.ListenMode.confirmation,
      partialResults: true,
    );
  }

  Future<void> _applyRuntimeConfig({
    required double speed,
    required double timeScale,
    required double difficulty,
    required String theme,
    required String notes,
    required String genre,
    required String assetsType,
    required List<String> mechanics,
    required String primaryColor,
    required String secondaryColor,
    required String accentColor,
    required String playerColor,
    required bool fogEnabled,
    required double fogDensity,
    required double cameraZoom,
    required double gravityY,
    required double jumpForce,
    String? playerSkinId,
    String? playerSpriteUrl,
    bool reloadWebView = true,
  }) async {
    final pid = _projectId;
    if (pid == null || pid.isEmpty) {
      return;
    }
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      AppNotifier.showError('Session expired. Please sign in again.');
      return;
    }

    await ProjectsService.updateProject(
      token: token,
      projectId: pid,
      speed: speed,
      timeScale: timeScale,
      difficulty: difficulty,
      theme: theme,
      notes: notes,
      genre: genre,
      assetsType: assetsType,
      mechanics: mechanics,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      accentColor: accentColor,
      playerColor: playerColor,
      fogEnabled: fogEnabled,
      fogDensity: fogDensity,
      cameraZoom: cameraZoom,
      gravityY: gravityY,
      jumpForce: jumpForce,
    );

    await _pushRuntimeConfigToWebView(
      speed: speed,
      timeScale: timeScale,
      difficulty: difficulty,
      theme: theme,
      notes: notes,
      genre: genre,
      assetsType: assetsType,
      mechanics: mechanics,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      accentColor: accentColor,
      playerColor: playerColor,
      fogEnabled: fogEnabled,
      fogDensity: fogDensity,
      cameraZoom: cameraZoom,
      gravityY: gravityY,
      jumpForce: jumpForce,
      playerSkinId: playerSkinId,
      playerSpriteUrl: playerSpriteUrl,
    );

    if (reloadWebView) {
      // Force WebView to refresh (use cb) while runtime polling should also pick it up.
      try {
        _telemetryReloads++;
        await _controller.loadRequest(Uri.parse(_withCacheBuster(widget.url)));
      } catch (_) {}
    }
  }

  Future<void> _pushRuntimeConfigToWebView({
    required double speed,
    required double timeScale,
    required double difficulty,
    required String theme,
    required String notes,
    required String genre,
    required String assetsType,
    required List<String> mechanics,
    required String primaryColor,
    required String secondaryColor,
    required String accentColor,
    required String playerColor,
    required bool fogEnabled,
    required double fogDensity,
    required double cameraZoom,
    required double gravityY,
    required double jumpForce,
    String? playerSkinId,
    String? playerSpriteUrl,
  }) async {
    final payload = <String, dynamic>{
      'speed': speed,
      'playerSpeed': speed,
      'gameSpeed': speed,
      'speedMultiplier': speed,
      'timeScale': timeScale,
      'difficulty': difficulty,
      'theme': theme,
      'notes': notes,
      'genre': genre,
      'assetsType': assetsType,
      'mechanics': mechanics,
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'accentColor': accentColor,
      'playerColor': playerColor,
      'fogEnabled': fogEnabled,
      'fogDensity': fogDensity,
      'cameraZoom': cameraZoom,
      'gravityY': gravityY,
      'jumpForce': jumpForce,
      if (playerSkinId != null && playerSkinId.trim().isNotEmpty)
        'playerSkinId': playerSkinId.trim(),
      if (playerSpriteUrl != null && playerSpriteUrl.trim().isNotEmpty)
        'playerSpriteUrl': playerSpriteUrl.trim(),
      'ts': DateTime.now().millisecondsSinceEpoch,
    };

    final json = jsonEncode(payload);
    await _runJs("""
      (function(){
        try {
          // Ensure Unity instance is exposed on window when it becomes ready.
          try {
            if (!window.__GF_UNITY_WRAPPED__ && typeof window.createUnityInstance === 'function') {
              window.__GF_UNITY_WRAPPED__ = true;
              var __origCreateUnityInstance = window.createUnityInstance;
              window.createUnityInstance = function(canvas, config, onProgress){
                try {
                  var p = __origCreateUnityInstance(canvas, config, onProgress);
                  if (p && typeof p.then === 'function') {
                    p.then(function(inst){ try { window.unityInstance = inst; } catch(e){} return inst; });
                  }
                  return p;
                } catch(e) {
                  return __origCreateUnityInstance(canvas, config, onProgress);
                }
              };
            }
          } catch(e) {}

          window.__GAMEFORGE_RUNTIME_CONFIG__ = $json;
          window.__GF_PENDING_RUNTIME_CONFIG__ = window.__GAMEFORGE_RUNTIME_CONFIG__;
          try { localStorage.setItem('gameforge.runtimeConfig', JSON.stringify(window.__GAMEFORGE_RUNTIME_CONFIG__)); } catch(e) {}

          try {
            window.dispatchEvent(new CustomEvent('gameforge:runtimeConfig', { detail: window.__GAMEFORGE_RUNTIME_CONFIG__ }));
          } catch(e) {}

          try {
            window.postMessage({ type: 'gameforge:runtimeConfig', payload: window.__GAMEFORGE_RUNTIME_CONFIG__ }, '*');
          } catch(e) {}

          try {
            var cfg = window.__GAMEFORGE_RUNTIME_CONFIG__;
            var f = window.gameforgeApplyRuntimeConfig || window.applyRuntimeConfig || window.setRuntimeConfig;
            if (typeof f === 'function') {
              try { f(cfg); } catch(e) {}
            }
          } catch(e) {}

          try {
            var cfg2 = window.__GAMEFORGE_RUNTIME_CONFIG__;
            if (typeof window.unityInstance !== 'undefined' && window.unityInstance && typeof window.unityInstance.SendMessage === 'function') {
              try {
                var targets = ['GameForgeBridge','RuntimeConfigBridge','RuntimeBridge','Bridge','GameManager','GameController','Game','Manager'];
                var methods = ['ApplyRuntimeConfig','SetRuntimeConfig','OnRuntimeConfig','ReceiveRuntimeConfig','ApplyConfig','SetConfig'];
                var msg = JSON.stringify(cfg2);
                for (var ti = 0; ti < targets.length; ti++) {
                  for (var mi = 0; mi < methods.length; mi++) {
                    try { window.unityInstance.SendMessage(targets[ti], methods[mi], msg); } catch(e) {}
                  }
                }
              } catch(e) {}
            }
          } catch(e) {}

          // Try applying high-impact fields via dedicated messages (safer than expanding JSON schema).
          try {
            var inst = (typeof window.unityInstance !== 'undefined') ? window.unityInstance : null;
            if (inst && typeof inst.SendMessage === 'function') {
              var skinId = ${jsonEncode(playerSkinId?.trim() ?? '')};
              var spriteUrl = ${jsonEncode(playerSpriteUrl?.trim() ?? '')};
              var pcol = ${jsonEncode(playerColor)};
              var fpsEnabled = ${_fpsControlsEnabled ? 'true' : 'false'};

              function sendMany(targets, methods, arg){
                try {
                  for (var ti = 0; ti < targets.length; ti++) {
                    for (var mi = 0; mi < methods.length; mi++) {
                      try { inst.SendMessage(targets[ti], methods[mi], String(arg)); } catch(e) {}
                    }
                  }
                } catch(e) {}
              }

              var tCommon = ['GameForgeBridge','RuntimeConfigBridge','RuntimeBridge','Bridge','GameManager','GameController','Game','Manager','Player','PlayerController','Character','CharacterController'];

              if (pcol && String(pcol).length >= 6) {
                sendMany(tCommon, ['SetPlayerColor','SetPlayerTint','SetTintColor','ApplyPlayerColor','ApplyTint','OnPlayerColor'], pcol);
              }
              if (skinId && String(skinId).length > 0) {
                sendMany(tCommon, ['SetPlayerSkin','SetSkin','ApplyPlayerSkin','SetCharacterStyle','ApplyCharacterStyle','OnPlayerSkin'], skinId);
              }
              if (spriteUrl && String(spriteUrl).length > 0) {
                sendMany(tCommon, ['SetPlayerSpriteUrl','SetSpriteUrl','ApplyPlayerSprite','OnPlayerSpriteUrl'], spriteUrl);
              }

              sendMany(tCommon, ['SetFpsControlsEnabled','EnableFpsControls','SetControlsMode','OnControlsMode','SetInputMode'], fpsEnabled ? 'fps' : 'touch');
              sendMany(tCommon, ['SetFpsControls','OnFpsControls','SetMouseLook'], fpsEnabled ? '1' : '0');
            }
          } catch(e) {}

          // Retry applying a few times because Unity often initializes after page load.
          try {
            if (!window.__GF_APPLY_RETRY_SET__) {
              window.__GF_APPLY_RETRY_SET__ = true;
              window.__gfTryApplyRuntimeConfig = function(){
                try {
                  var cfg = window.__GF_PENDING_RUNTIME_CONFIG__ || window.__GAMEFORGE_RUNTIME_CONFIG__;
                  if (!cfg) return;

                  var f = window.gameforgeApplyRuntimeConfig || window.applyRuntimeConfig || window.setRuntimeConfig;
                  if (typeof f === 'function') {
                    try { f(cfg); } catch(e) {}
                  }

                  if (typeof window.unityInstance !== 'undefined' && window.unityInstance && typeof window.unityInstance.SendMessage === 'function') {
                    try {
                      var targets = ['GameForgeBridge','RuntimeConfigBridge','RuntimeBridge','Bridge','GameManager','GameController','Game','Manager'];
                      var methods = ['ApplyRuntimeConfig','SetRuntimeConfig','OnRuntimeConfig','ReceiveRuntimeConfig','ApplyConfig','SetConfig'];
                      var msg = JSON.stringify(cfg);
                      for (var ti = 0; ti < targets.length; ti++) {
                        for (var mi = 0; mi < methods.length; mi++) {
                          try { window.unityInstance.SendMessage(targets[ti], methods[mi], msg); } catch(e) {}
                        }
                      }
                    } catch(e) {}
                  }
                } catch(e) {}
              };

              var tries = 0;
              var iv = setInterval(function(){
                tries++;
                try { window.__gfTryApplyRuntimeConfig(); } catch(e) {}
                if (tries >= 12) { try { clearInterval(iv); } catch(e) {} }
              }, 500);
            } else {
              try { window.__gfTryApplyRuntimeConfig && window.__gfTryApplyRuntimeConfig(); } catch(e) {}
            }
          } catch(e) {}
        } catch (err) {}
      })();
      """);
  }

  Future<void> _bootMultiplayer() async {
    final rid = (_mpRoomId ?? '').trim();
    final sid = (_mpSessionId ?? '').trim();
    if (rid.isEmpty || sid.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final token = (auth.token ?? '').trim();
    String username = '';
    final u = auth.user;
    if (u is Map) {
      final m = u as Map;
      username = (m['username'] ?? m['name'] ?? '').toString().trim();
    } else {
      try {
        username = ((u as dynamic)?.username ?? (u as dynamic)?.name ?? '')
            .toString()
            .trim();
      } catch (_) {
        username = '';
      }
    }
    if (token.isEmpty) return;

    await _mp.connect(
      token: token,
      username: username.isEmpty ? null : username,
    );
    await _mp.joinRoom(roomId: rid);
    _mp.addListener(_onMpUpdate);

    await _maybeEnableUnitySplitScreen(force: true);

    try {
      if (!_mp.voiceJoined) {
        await _mp.voiceJoin(roomId: rid);
      }
    } catch (_) {}

    if (mounted) setState(() {});
  }

  void _onMpUpdate() {
    final st = _mp.lastGameState;
    if (st == null) return;
    if ((_mpSessionId ?? '') != st.sessionId) return;

    _maybeEnableUnitySplitScreen();

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMpStatePushAtMs < 30) return;
    _lastMpStatePushAtMs = now;
    _pushMpStateToWebView(st.state, st.ts);
  }

  Future<void> _maybeEnableUnitySplitScreen({bool force = false}) async {
    if (_unitySplitEnabled && !force) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _lastUnitySplitAttemptAtMs < 1200) return;
    _lastUnitySplitAttemptAtMs = now;

    try {
      final members = _mp.room?.members ?? const [];
      if (members.length < 2) return;

      final ok = await _runJsReturningBool('''
(function(){
  try {
    try { if (window.GameForgeLog && window.GameForgeLog.postMessage) window.GameForgeLog.postMessage('[MP] split: attempting enable'); } catch(e) {}
    function findUnity(){
      try {
        if (window.unityInstance && typeof window.unityInstance.SendMessage === 'function') return window.unityInstance;
      } catch(e) {}
      try {
        if (window.gameInstance && typeof window.gameInstance.SendMessage === 'function') return window.gameInstance;
      } catch(e) {}

      try {
        for (var k in window) {
          if (!Object.prototype.hasOwnProperty.call(window, k)) continue;
          var v = window[k];
          if (!v) continue;
          if (typeof v === 'object' && typeof v.SendMessage === 'function') return v;
        }
      } catch(e) {}
      return null;
    }

    var inst = findUnity();
    if (!inst) return false;
    try {
      var payload = JSON.stringify({ enabled: true, layout: 'top_bottom' });
      var targets = ['GameForgeMPBridge','GF_MP','MPBridge','MultiplayerBridge','Bridge','GameController','GameManager','Game'];
      for (var i = 0; i < targets.length; i++) {
        try {
          inst.SendMessage(targets[i], 'EnableSplitScreen', payload);
          try { if (window.GameForgeLog && window.GameForgeLog.postMessage) window.GameForgeLog.postMessage('[MP] split: enabled via ' + targets[i]); } catch(e) {}
          return true;
        } catch(e) {}
      }
      try { if (window.GameForgeLog && window.GameForgeLog.postMessage) window.GameForgeLog.postMessage('[MP] split: SendMessage failed for all targets'); } catch(e) {}
      return false;
    } catch(e) {}
    return false;
  } catch(e) { return false; }
})();
''');

      if (ok) {
        _unitySplitEnabled = true;
      }
    } catch (_) {}
  }

  Future<bool> _runJsReturningBool(String code) async {
    try {
      final raw = await _controller.runJavaScriptReturningResult(code);
      if (raw == null) return false;
      if (raw is bool) return raw;
      final s = raw.toString().toLowerCase();
      return s == 'true' || s == '1';
    } catch (_) {
      return false;
    }
  }

  Future<void> _installMpBridge() async {
    final sid = (_mpSessionId ?? '').trim();
    final rid = (_mpRoomId ?? '').trim();
    if (sid.isEmpty || rid.isEmpty) return;

    await _runJs('''
(function(){
  try {
    if (window.__GF_MP_BRIDGE_INSTALLED) return;
    window.__GF_MP_BRIDGE_INSTALLED = true;

    function sendToUnity(method, msg){
      try {
        if (typeof window.unityInstance === 'undefined' || !window.unityInstance) return false;
        if (typeof window.unityInstance.SendMessage !== 'function') return false;
        var targets = [
          'GameForgeMPBridge','MPBridge','MultiplayerBridge','NetcodeBridge','Bridge','GameForgeBridge',
          'GameManager','GameController','Game','Manager'
        ];
        for (var i = 0; i < targets.length; i++) {
          try { window.unityInstance.SendMessage(targets[i], method, msg); return true; } catch(e) {}
        }
      } catch(e) {}
      return false;
    }

    function forwardStateToUnity(payload){
      try {
        var msg = JSON.stringify(payload);
        var methods = [
          'OnMultiplayerState','ReceiveMultiplayerState','OnMPState','ReceiveMPState','ApplyMPState',
          'OnGameForgeMPState','OnRemoteState'
        ];
        for (var i = 0; i < methods.length; i++) {
          if (sendToUnity(methods[i], msg)) return;
        }
      } catch(e) {}
    }

    window.GF_MP = window.GF_MP || {};
    window.GF_MP.sessionId = '${sid.replaceAll("'", "\\'")}';
    window.GF_MP.roomId = '${rid.replaceAll("'", "\\'")}';

    window.GF_MP.receiveState = function(msg){
      try { window.dispatchEvent(new CustomEvent('gameforge:mp:state', { detail: msg })); } catch(e) {}
      try { forwardStateToUnity(msg); } catch(e) {}
    };

    window.GF_MP.receiveInput = function(input){
      try { window.dispatchEvent(new CustomEvent('gameforge:mp:input', { detail: input })); } catch(e) {}
      try {
        var msg = JSON.stringify(input);
        var methods = ['OnMultiplayerInput','ReceiveMultiplayerInput','OnMPInput','ReceiveMPInput','OnRemoteInput'];
        for (var i = 0; i < methods.length; i++) {
          if (sendToUnity(methods[i], msg)) break;
        }
      } catch(e) {}
    };

    window.GF_MP.sendState = function(state){
      try {
        var payload = { type: 'state', state: state, ts: Date.now() };
        if (window.GameForgeMP && window.GameForgeMP.postMessage) window.GameForgeMP.postMessage(JSON.stringify(payload));
      } catch(e) {}
    };

    window.GF_MP.sendInput = function(type, payload){
      try {
        var msg = { type: 'input', inputType: String(type || 'input'), payload: payload || {}, ts: Date.now() };
        if (window.GameForgeMP && window.GameForgeMP.postMessage) window.GameForgeMP.postMessage(JSON.stringify(msg));
      } catch(e) {}
    };
  } catch(e) {}
})();
''');
  }

  Future<void> _pushMpStateToWebView(Map<String, dynamic> state, int ts) async {
    final sid = (_mpSessionId ?? '').trim();
    if (sid.isEmpty) return;
    final json = jsonEncode({'sessionId': sid, 'state': state, 'ts': ts});
    await _runJs('''
(function(){
  try {
    var msg = $json;
    if (window.GF_MP && typeof window.GF_MP.receiveState === 'function') {
      window.GF_MP.receiveState(msg);
      return;
    }
    try { window.dispatchEvent(new CustomEvent('gameforge:mp:state', { detail: msg })); } catch(e) {}
  } catch(e) {}
})();
''');
  }

  Future<void> _openSettingsDrawer() async {
    if (_openingSettings) return;
    setState(() => _openingSettings = true);

    Map<String, dynamic>? cfg;
    try {
      cfg = await _fetchRuntimeConfig();
    } catch (_) {
      cfg = null;
    }

    if (!mounted) return;
    setState(() => _openingSettings = false);

    final cs = Theme.of(context).colorScheme;
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    double speed = (cfg?['speed'] is num)
        ? (cfg!['speed'] as num).toDouble()
        : 7.0;
    double timeScale = (cfg?['timeScale'] is num)
        ? (cfg!['timeScale'] as num).toDouble()
        : 1.0;
    double difficulty = (cfg?['difficulty'] is num)
        ? (cfg!['difficulty'] as num).toDouble()
        : 0.5;
    final themeCtrl = TextEditingController(
      text: (cfg?['theme']?.toString() ?? 'default'),
    );
    final notesCtrl = TextEditingController(
      text: (cfg?['notes']?.toString() ?? ''),
    );
    final genreCtrl = TextEditingController(
      text: (cfg?['genre']?.toString() ?? 'platformer'),
    );
    final assetsTypeCtrl = TextEditingController(
      text: (cfg?['assetsType']?.toString() ?? 'lowpoly'),
    );
    final mechanicsCtrl = TextEditingController(
      text: (cfg?['mechanics'] is List)
          ? (cfg!['mechanics'] as List)
                .map((e) => e?.toString() ?? '')
                .where((e) => e.trim().isNotEmpty)
                .join(', ')
          : '',
    );
    String primary = (cfg?['primaryColor']?.toString() ?? '#22C55E');
    String secondary = (cfg?['secondaryColor']?.toString() ?? '#3B82F6');
    String accent = (cfg?['accentColor']?.toString() ?? '#F59E0B');
    String playerColor = (cfg?['playerColor']?.toString() ?? accent);

    bool fogEnabled = (cfg?['fogEnabled'] is bool)
        ? (cfg!['fogEnabled'] as bool)
        : false;
    double fogDensity = (cfg?['fogDensity'] is num)
        ? (cfg!['fogDensity'] as num).toDouble()
        : 0.0;
    double cameraZoom = (cfg?['cameraZoom'] is num)
        ? (cfg!['cameraZoom'] as num).toDouble()
        : 0.0;
    double gravityY = (cfg?['gravityY'] is num)
        ? (cfg!['gravityY'] as num).toDouble()
        : 0.0;
    double jumpForce = (cfg?['jumpForce'] is num)
        ? (cfg!['jumpForce'] as num).toDouble()
        : 0.0;

    final primaryCtrl = TextEditingController(text: primary);
    final secondaryCtrl = TextEditingController(text: secondary);
    final accentCtrl = TextEditingController(text: accent);
    final playerCtrl = TextEditingController(text: playerColor);

    String playerSkinId = 'default';
    final spriteUrlCtrl = TextEditingController();

    final speedCtrl = TextEditingController(text: speed.toStringAsFixed(1));

    bool forceReloadGameplay = true;
    bool fpsControlsEnabled = _fpsControlsEnabled;

    final pid = _projectId;
    if (pid != null && pid.trim().isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        playerSkinId =
            (prefs.getString('$_kPrefPlayerSkinPrefix$pid') ?? playerSkinId)
                .trim();
        spriteUrlCtrl.text =
            (prefs.getString('$_kPrefPlayerSpriteUrlPrefix$pid') ?? '').trim();
        forceReloadGameplay =
            prefs.getBool('$_kPrefForceReloadPrefix$pid') ?? true;
        fpsControlsEnabled =
            prefs.getBool('$_kPrefFpsControlsPrefix$pid') ??
            _fpsControlsEnabled;
        if (playerSkinId.isEmpty) playerSkinId = 'default';
      } catch (_) {}
    }

    int tabIndex = 0;
    final history = <Map<String, dynamic>>[];

    try {
      final sheetRes = await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppBorderRadius.large),
          ),
        ),
        builder: (context) {
          bool saving = false;

          String toHex(Color c) {
            final rgb = c.value & 0x00FFFFFF;
            return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
          }

          Future<void> pasteHexInto(TextEditingController ctrl) async {
            final d = await Clipboard.getData('text/plain');
            final raw = d?.text;
            if (raw == null) return;
            var s = raw.trim();
            if (s.isEmpty) return;
            if (!s.startsWith('#')) s = '#$s';
            if (s.length != 7) return;
            if (_parseHexToColor(s) == null) return;
            ctrl.text = s.toUpperCase();
          }

          Future<void> pickColorFor(TextEditingController ctrl) async {
            final initial =
                _parseHexToColor(ctrl.text) ??
                Theme.of(context).colorScheme.primary;
            Color temp = initial;
            final picked = await showDialog<Color>(
              context: context,
              builder: (ctx) {
                final cs = Theme.of(ctx).colorScheme;
                return AlertDialog(
                  backgroundColor: cs.surface,
                  title: const Text('Pick color'),
                  content: SingleChildScrollView(
                    child: ColorPicker(
                      pickerColor: initial,
                      onColorChanged: (c) => temp = c,
                      enableAlpha: false,
                      labelTypes: const [],
                      pickerAreaHeightPercent: 0.7,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(null),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(temp),
                      child: const Text('Use'),
                    ),
                  ],
                );
              },
            );
            if (picked == null) return;
            ctrl.text = toHex(picked);
          }

          final gameplayPresets = <Map<String, dynamic>>[
            {
              'name': 'Chill',
              'speed': 4.0,
              'difficulty': 0.30,
              'timeScale': 0.90,
            },
            {
              'name': 'Normal',
              'speed': 7.0,
              'difficulty': 0.50,
              'timeScale': 1.00,
            },
            {
              'name': 'Hardcore',
              'speed': 12.0,
              'difficulty': 0.85,
              'timeScale': 1.10,
            },
          ];
          final colorPresets = <Map<String, String>>[
            {
              'name': '⚡ Neon',
              'primary': '#22C55E',
              'secondary': '#3B82F6',
              'accent': '#F59E0B',
              'player': '#F59E0B',
            },
            {
              'name': '🌐 Cyber',
              'primary': '#00E5FF',
              'secondary': '#7C4DFF',
              'accent': '#FF1744',
              'player': '#FF1744',
            },
            {
              'name': '🍬 Pastel',
              'primary': '#A7F3D0',
              'secondary': '#BFDBFE',
              'accent': '#FBCFE8',
              'player': '#FBCFE8',
            },
            {
              'name': '🌑 Dark',
              'primary': '#0EA5E9',
              'secondary': '#A78BFA',
              'accent': '#22C55E',
              'player': '#22C55E',
            },
            {
              'name': '🌊 Ocean',
              'primary': '#0369A1',
              'secondary': '#06B6D4',
              'accent': '#67E8F9',
              'player': '#67E8F9',
            },
            {
              'name': '🌅 Sunset',
              'primary': '#F97316',
              'secondary': '#EF4444',
              'accent': '#FBBF24',
              'player': '#FBBF24',
            },
            {
              'name': '🌌 Galaxy',
              'primary': '#4F46E5',
              'secondary': '#7C3AED',
              'accent': '#C084FC',
              'player': '#C084FC',
            },
            {
              'name': '🌿 Forest',
              'primary': '#16A34A',
              'secondary': '#15803D',
              'accent': '#BEF264',
              'player': '#BEF264',
            },
            {
              'name': '❄️ Arctic',
              'primary': '#BAE6FD',
              'secondary': '#E0F2FE',
              'accent': '#38BDF8',
              'player': '#38BDF8',
            },
            {
              'name': '🔥 Inferno',
              'primary': '#DC2626',
              'secondary': '#EA580C',
              'accent': '#FDE047',
              'player': '#FDE047',
            },
            {
              'name': '🎮 Retro',
              'primary': '#A3E635',
              'secondary': '#4ADE80',
              'accent': '#FACC15',
              'player': '#FACC15',
            },
            {
              'name': '🌸 Sakura',
              'primary': '#F9A8D4',
              'secondary': '#FBCFE8',
              'accent': '#FDF2F8',
              'player': '#FDF2F8',
            },
            {
              'name': '💎 Diamond',
              'primary': '#E2E8F0',
              'secondary': '#94A3B8',
              'accent': '#38BDF8',
              'player': '#38BDF8',
            },
            {
              'name': '🌙 Midnight',
              'primary': '#1E3A5F',
              'secondary': '#2D4A6F',
              'accent': '#F59E0B',
              'player': '#F59E0B',
            },
            {
              'name': '🍊 Citrus',
              'primary': '#84CC16',
              'secondary': '#F97316',
              'accent': '#EAB308',
              'player': '#EAB308',
            },
            {
              'name': '🎭 Vapor',
              'primary': '#F472B6',
              'secondary': '#818CF8',
              'accent': '#34D399',
              'player': '#34D399',
            },
            {
              'name': '🩸 Crimson',
              'primary': '#9F1239',
              'secondary': '#BE123C',
              'accent': '#FB7185',
              'player': '#FB7185',
            },
            {
              'name': '🏜️ Desert',
              'primary': '#D97706',
              'secondary': '#B45309',
              'accent': '#FEF3C7',
              'player': '#FEF3C7',
            },
            {
              'name': '🟣 Neon Pink',
              'primary': '#DB2777',
              'secondary': '#9333EA',
              'accent': '#F0ABFC',
              'player': '#F0ABFC',
            },
            {
              'name': '🌈 Rainbow',
              'primary': '#EF4444',
              'secondary': '#3B82F6',
              'accent': '#22C55E',
              'player': '#A78BFA',
            },
          ];

          final characterStylePresets = <Map<String, String>>[
            {'id': 'default', 'name': 'Default', 'player': playerColor},
            {'id': 'ninja', 'name': 'Ninja', 'player': '#111827'},
            {'id': 'alien', 'name': 'Alien', 'player': '#22C55E'},
            {'id': 'neon', 'name': 'Neon', 'player': '#00E5FF'},
            {'id': 'fire', 'name': 'Fire', 'player': '#FF1744'},
            {'id': 'ice', 'name': 'Ice', 'player': '#7C4DFF'},
            {'id': 'gold', 'name': 'Gold', 'player': '#F59E0B'},
          ];

          Widget sectionTitle(String t) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                t,
                style: AppTypography.subtitle2.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }

          Widget valuePill(String t) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.35),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
              ),
              child: Text(
                t,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }

          Widget colorDot(String hex) {
            Color? c;
            try {
              final v = _normHex(hex);
              if (v != null) {
                final n = int.tryParse(v.substring(1), radix: 16);
                if (n != null) c = Color(0xFF000000 | n);
              }
            } catch (_) {}
            return Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c ?? cs.onSurface.withOpacity(0.10),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
              ),
            );
          }

          return StatefulBuilder(
            builder: (context, setSheetState) {
              final originalPlayerColor =
                  (cfg?['playerColor']?.toString() ?? accent).trim();

              void pushHistorySnapshot() {
                history.add({
                  'speed': speed,
                  'primary': primaryCtrl.text,
                  'secondary': secondaryCtrl.text,
                  'accent': accentCtrl.text,
                  'player': playerCtrl.text,
                  'fogEnabled': fogEnabled,
                  'fogDensity': fogDensity,
                  'cameraZoom': cameraZoom,
                  'gravityY': gravityY,
                  'jumpForce': jumpForce,
                });
                if (history.length > 12) {
                  history.removeAt(0);
                }
              }

              Future<void> scheduleLiveApply({bool reload = false}) async {
                if (saving) return;
                _liveApplyDebounce?.cancel();
                _liveApplyDebounce = Timer(
                  const Duration(milliseconds: 220),
                  () async {
                    _setLiveApplying();
                    try {
                      await _applyRuntimeConfig(
                        speed: speed.clamp(0.0, 20.0),
                        timeScale: timeScale.clamp(0.5, 2.0),
                        difficulty: difficulty.clamp(0.0, 1.0),
                        theme: themeCtrl.text.trim(),
                        notes: notesCtrl.text.trim(),
                        genre: genreCtrl.text.trim(),
                        assetsType: assetsTypeCtrl.text.trim(),
                        mechanics: mechanicsCtrl.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList(),
                        primaryColor: _normHex(primaryCtrl.text) ?? '#22C55E',
                        secondaryColor:
                            _normHex(secondaryCtrl.text) ?? '#3B82F6',
                        accentColor: _normHex(accentCtrl.text) ?? '#F59E0B',
                        playerColor:
                            _normHex(playerCtrl.text) ??
                            (_normHex(accentCtrl.text) ?? '#F59E0B'),
                        fogEnabled: fogEnabled,
                        fogDensity: fogDensity.clamp(0.0, 0.1),
                        cameraZoom: cameraZoom.clamp(0.0, 30.0),
                        gravityY: gravityY.clamp(-50.0, 0.0),
                        jumpForce: jumpForce.clamp(0.0, 50.0),
                        playerSkinId: playerSkinId,
                        playerSpriteUrl: spriteUrlCtrl.text.trim(),
                        reloadWebView: reload && forceReloadGameplay && !isIos,
                      );
                    } catch (_) {}
                  },
                );
              }

              void syncSpeedText() {
                final t = speed.clamp(0.0, 20.0).toStringAsFixed(1);
                if (speedCtrl.text == t) return;
                speedCtrl.value = TextEditingValue(
                  text: t,
                  selection: TextSelection.collapsed(offset: t.length),
                );
              }

              Future<void> doUndo() async {
                if (saving) return;
                if (history.isEmpty) return;
                final last = history.removeLast();
                setSheetState(() {
                  speed = (last['speed'] as num?)?.toDouble() ?? speed;
                  primaryCtrl.text =
                      (last['primary']?.toString() ?? primaryCtrl.text);
                  secondaryCtrl.text =
                      (last['secondary']?.toString() ?? secondaryCtrl.text);
                  accentCtrl.text =
                      (last['accent']?.toString() ?? accentCtrl.text);
                  playerCtrl.text =
                      (last['player']?.toString() ?? playerCtrl.text);
                  fogEnabled = (last['fogEnabled'] as bool?) ?? fogEnabled;
                  fogDensity =
                      (last['fogDensity'] as num?)?.toDouble() ?? fogDensity;
                  cameraZoom =
                      (last['cameraZoom'] as num?)?.toDouble() ?? cameraZoom;
                  gravityY = (last['gravityY'] as num?)?.toDouble() ?? gravityY;
                  jumpForce =
                      (last['jumpForce'] as num?)?.toDouble() ?? jumpForce;
                });
                await scheduleLiveApply(reload: false);
              }

              Future<void> doReset() async {
                if (saving) return;
                pushHistorySnapshot();
                setSheetState(() {
                  speed = (cfg?['speed'] is num)
                      ? (cfg!['speed'] as num).toDouble()
                      : 7.0;
                  timeScale = (cfg?['timeScale'] is num)
                      ? (cfg!['timeScale'] as num).toDouble()
                      : 1.0;
                  difficulty = (cfg?['difficulty'] is num)
                      ? (cfg!['difficulty'] as num).toDouble()
                      : 0.5;
                  themeCtrl.text = (cfg?['theme']?.toString() ?? 'default');
                  notesCtrl.text = (cfg?['notes']?.toString() ?? '');
                  genreCtrl.text = (cfg?['genre']?.toString() ?? 'platformer');
                  assetsTypeCtrl.text =
                      (cfg?['assetsType']?.toString() ?? 'lowpoly');
                  mechanicsCtrl.text = (cfg?['mechanics'] is List)
                      ? (cfg!['mechanics'] as List)
                            .map((e) => e?.toString() ?? '')
                            .where((e) => e.trim().isNotEmpty)
                            .join(', ')
                      : '';
                  primaryCtrl.text =
                      (cfg?['primaryColor']?.toString() ?? '#22C55E');
                  secondaryCtrl.text =
                      (cfg?['secondaryColor']?.toString() ?? '#3B82F6');
                  accentCtrl.text =
                      (cfg?['accentColor']?.toString() ?? '#F59E0B');
                  playerCtrl.text =
                      (cfg?['playerColor']?.toString() ?? accentCtrl.text);
                  fogEnabled = (cfg?['fogEnabled'] is bool)
                      ? (cfg!['fogEnabled'] as bool)
                      : false;
                  fogDensity = (cfg?['fogDensity'] is num)
                      ? (cfg!['fogDensity'] as num).toDouble()
                      : 0.0;
                  cameraZoom = (cfg?['cameraZoom'] is num)
                      ? (cfg!['cameraZoom'] as num).toDouble()
                      : 0.0;
                  gravityY = (cfg?['gravityY'] is num)
                      ? (cfg!['gravityY'] as num).toDouble()
                      : 0.0;
                  jumpForce = (cfg?['jumpForce'] is num)
                      ? (cfg!['jumpForce'] as num).toDouble()
                      : 0.0;
                });
                await scheduleLiveApply(reload: false);
              }

              Widget sectionCard({required Widget child}) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.55),
                    ),
                    boxShadow: AppShadows.boxShadowSmall,
                  ),
                  child: child,
                );
              }

              Future<void> previewPlayerStyle(String hex) async {
                if (saving) return;
                final v = _normHex(hex);
                if (v == null) return;

                pushHistorySnapshot();

                setSheetState(() {
                  playerCtrl.text = v;
                  playerColor = v;
                });

                try {
                  await _applyRuntimeConfig(
                    speed: speed.clamp(0.0, 20.0),
                    timeScale: timeScale.clamp(0.5, 2.0),
                    difficulty: difficulty.clamp(0.0, 1.0),
                    theme: themeCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                    genre: genreCtrl.text.trim(),
                    assetsType: assetsTypeCtrl.text.trim(),
                    mechanics: mechanicsCtrl.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                    primaryColor: _normHex(primary) ?? '#22C55E',
                    secondaryColor: _normHex(secondary) ?? '#3B82F6',
                    accentColor: _normHex(accent) ?? '#F59E0B',
                    playerColor: v,
                    fogEnabled: fogEnabled,
                    fogDensity: fogDensity.clamp(0.0, 0.1),
                    cameraZoom: cameraZoom.clamp(0.0, 30.0),
                    gravityY: gravityY.clamp(-50.0, 0.0),
                    jumpForce: jumpForce.clamp(0.0, 50.0),
                    playerSkinId: playerSkinId,
                    playerSpriteUrl: spriteUrlCtrl.text,
                    reloadWebView: false,
                  );
                } catch (_) {}
              }

              Future<void> previewPlayerAssets({String? nextSkinId}) async {
                if (saving) return;
                final next = (nextSkinId ?? playerSkinId).trim();
                if (next.isEmpty) return;
                pushHistorySnapshot();
                setSheetState(() {
                  playerSkinId = next;
                });

                final pid = _projectId;
                if (pid != null && pid.trim().isNotEmpty) {
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(
                      '$_kPrefPlayerSkinPrefix$pid',
                      playerSkinId,
                    );
                    await prefs.setString(
                      '$_kPrefPlayerSpriteUrlPrefix$pid',
                      spriteUrlCtrl.text.trim(),
                    );
                  } catch (_) {}
                }

                try {
                  await _pushRuntimeConfigToWebView(
                    speed: speed.clamp(0.0, 20.0),
                    timeScale: timeScale.clamp(0.5, 2.0),
                    difficulty: difficulty.clamp(0.0, 1.0),
                    theme: themeCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                    genre: genreCtrl.text.trim(),
                    assetsType: assetsTypeCtrl.text.trim(),
                    mechanics: mechanicsCtrl.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                    primaryColor: _normHex(primaryCtrl.text) ?? '#22C55E',
                    secondaryColor: _normHex(secondaryCtrl.text) ?? '#3B82F6',
                    accentColor: _normHex(accentCtrl.text) ?? '#F59E0B',
                    playerColor:
                        _normHex(playerCtrl.text) ??
                        (_normHex(accentCtrl.text) ?? '#F59E0B'),
                    fogEnabled: fogEnabled,
                    fogDensity: fogDensity.clamp(0.0, 0.1),
                    cameraZoom: cameraZoom.clamp(0.0, 30.0),
                    gravityY: gravityY.clamp(-50.0, 0.0),
                    jumpForce: jumpForce.clamp(0.0, 50.0),
                    playerSkinId: playerSkinId,
                    playerSpriteUrl: spriteUrlCtrl.text.trim(),
                  );
                } catch (_) {}
              }

              Future<void> doApply() async {
                if (saving) return;
                setSheetState(() => saving = true);
                bool closing = false;
                try {
                  pushHistorySnapshot();
                  primary = primaryCtrl.text;
                  secondary = secondaryCtrl.text;
                  accent = accentCtrl.text;
                  playerColor = playerCtrl.text;
                  await _applyRuntimeConfig(
                    speed: speed.clamp(0.0, 20.0),
                    timeScale: timeScale.clamp(0.5, 2.0),
                    difficulty: difficulty.clamp(0.0, 1.0),
                    theme: themeCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                    genre: genreCtrl.text.trim(),
                    assetsType: assetsTypeCtrl.text.trim(),
                    mechanics: mechanicsCtrl.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                    primaryColor: _normHex(primary) ?? '#22C55E',
                    secondaryColor: _normHex(secondary) ?? '#3B82F6',
                    accentColor: _normHex(accent) ?? '#F59E0B',
                    playerColor:
                        _normHex(playerColor) ??
                        (_normHex(accent) ?? '#F59E0B'),
                    fogEnabled: fogEnabled,
                    fogDensity: fogDensity.clamp(0.0, 0.1),
                    cameraZoom: cameraZoom.clamp(0.0, 30.0),
                    gravityY: gravityY.clamp(-50.0, 0.0),
                    jumpForce: jumpForce.clamp(0.0, 50.0),
                    playerSkinId: playerSkinId,
                    playerSpriteUrl: spriteUrlCtrl.text,
                    reloadWebView: forceReloadGameplay && !isIos,
                  );
                  if (context.mounted) {
                    AppNotifier.showSuccess('Applied');
                    setSheetState(() => saving = false);
                    closing = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    });
                  }
                  await _ensureGameFocus();
                } catch (e) {
                  if (context.mounted) AppNotifier.showError(e.toString());
                } finally {
                  if (!closing && context.mounted)
                    setSheetState(() => saving = false);
                }
              }

              return SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    top: AppSpacing.lg,
                    bottom:
                        MediaQuery.of(context).viewInsets.bottom +
                        AppSpacing.lg,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: cs.onSurface.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Game Controls',
                                style: AppTypography.subtitle1.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (_liveApplying)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest.withOpacity(
                                    0.35,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: cs.outlineVariant.withOpacity(0.55),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              cs.primary,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Applying…',
                                      style: AppTypography.caption.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Undo',
                              onPressed: (saving || history.isEmpty)
                                  ? null
                                  : () => doUndo(),
                              icon: const Icon(Icons.undo_rounded),
                            ),
                            IconButton(
                              tooltip: 'Reset',
                              onPressed: saving ? null : () => doReset(),
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                            IconButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'These values update the runtime-config. Rebuild is needed only the first time after adding new bootstrap changes.',
                          style: AppTypography.caption.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ChoiceChip(
                                  selected: tabIndex == 0,
                                  label: const Text('Character'),
                                  onSelected: saving
                                      ? null
                                      : (_) =>
                                            setSheetState(() => tabIndex = 0),
                                ),
                                const SizedBox(width: 10),
                                ChoiceChip(
                                  selected: tabIndex == 1,
                                  label: const Text('Gameplay'),
                                  onSelected: saving
                                      ? null
                                      : (_) =>
                                            setSheetState(() => tabIndex = 1),
                                ),
                                const SizedBox(width: 10),
                                ChoiceChip(
                                  selected: tabIndex == 2,
                                  label: const Text('Look'),
                                  onSelected: saving
                                      ? null
                                      : (_) =>
                                            setSheetState(() => tabIndex = 2),
                                ),
                                const SizedBox(width: 10),
                                ChoiceChip(
                                  selected: tabIndex == 3,
                                  label: const Text('World'),
                                  onSelected: saving
                                      ? null
                                      : (_) =>
                                            setSheetState(() => tabIndex = 3),
                                ),
                                const SizedBox(width: 10),
                                ChoiceChip(
                                  selected: tabIndex == 4,
                                  label: const Text('Physics'),
                                  onSelected: saving
                                      ? null
                                      : (_) =>
                                            setSheetState(() => tabIndex = 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, anim) {
                            return FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.02),
                                  end: Offset.zero,
                                ).animate(anim),
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey<int>(tabIndex),
                            child: () {
                              if (tabIndex == 0) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    sectionTitle('Character styles'),
                                    sectionCard(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: characterStylePresets.map((
                                            p,
                                          ) {
                                            final id =
                                                (p['id']?.toString() ?? '')
                                                    .trim();
                                            final name =
                                                p['name']?.toString() ??
                                                'Style';
                                            final hex =
                                                p['player']?.toString() ?? '';
                                            final selected = playerSkinId == id;
                                            return ChoiceChip(
                                              selected: selected,
                                              label: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  colorDot(hex),
                                                  const SizedBox(width: 8),
                                                  Text(name),
                                                ],
                                              ),
                                              onSelected: saving
                                                  ? null
                                                  : (_) async {
                                                      await previewPlayerAssets(
                                                        nextSkinId: id,
                                                      );
                                                      await previewPlayerStyle(
                                                        hex,
                                                      );
                                                    },
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    sectionTitle('Custom sprite URL'),
                                    sectionCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Optional: provide a hosted image/spritesheet URL. The game runtime must support reading playerSpriteUrl.',
                                            style: AppTypography.caption
                                                .copyWith(
                                                  color: cs.onSurfaceVariant,
                                                  height: 1.35,
                                                ),
                                          ),
                                          const SizedBox(height: 10),
                                          TextField(
                                            controller: spriteUrlCtrl,
                                            enabled: !saving,
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              hintText:
                                                  'https://.../player.png',
                                            ),
                                            onChanged: saving
                                                ? null
                                                : (_) {
                                                    scheduleLiveApply(
                                                      reload: false,
                                                    );
                                                    previewPlayerAssets();
                                                  },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }
                              if (tabIndex == 1) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    sectionTitle('Gameplay'),
                                    sectionCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Force reload for gameplay changes',
                                                  style: AppTypography.body2
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                              ),
                                              Switch(
                                                value: forceReloadGameplay,
                                                onChanged: saving
                                                    ? null
                                                    : (v) async {
                                                        setSheetState(
                                                          () =>
                                                              forceReloadGameplay =
                                                                  v,
                                                        );
                                                        final pid = _projectId;
                                                        if (pid != null &&
                                                            pid
                                                                .trim()
                                                                .isNotEmpty) {
                                                          try {
                                                            final prefs =
                                                                await SharedPreferences.getInstance();
                                                            await prefs.setBool(
                                                              '$_kPrefForceReloadPrefix$pid',
                                                              v,
                                                            );
                                                          } catch (_) {}
                                                        }
                                                      },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'FPS controls (WASD + mouse click)',
                                                  style: AppTypography.body2
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                              ),
                                              Switch(
                                                value: fpsControlsEnabled,
                                                onChanged: saving
                                                    ? null
                                                    : (v) async {
                                                        setSheetState(
                                                          () =>
                                                              fpsControlsEnabled =
                                                                  v,
                                                        );
                                                        if (mounted) {
                                                          setState(
                                                            () =>
                                                                _fpsControlsEnabled =
                                                                    v,
                                                          );
                                                        }
                                                        final pid = _projectId;
                                                        if (pid != null &&
                                                            pid
                                                                .trim()
                                                                .isNotEmpty) {
                                                          try {
                                                            final prefs =
                                                                await SharedPreferences.getInstance();
                                                            await prefs.setBool(
                                                              '$_kPrefFpsControlsPrefix$pid',
                                                              v,
                                                            );
                                                          } catch (_) {}
                                                        }

                                                        try {
                                                          await _pushRuntimeConfigToWebView(
                                                            speed: speed.clamp(
                                                              0.0,
                                                              20.0,
                                                            ),
                                                            timeScale: timeScale
                                                                .clamp(
                                                                  0.5,
                                                                  2.0,
                                                                ),
                                                            difficulty:
                                                                difficulty
                                                                    .clamp(
                                                                      0.0,
                                                                      1.0,
                                                                    ),
                                                            theme: themeCtrl
                                                                .text
                                                                .trim(),
                                                            notes: notesCtrl
                                                                .text
                                                                .trim(),
                                                            genre: genreCtrl
                                                                .text
                                                                .trim(),
                                                            assetsType:
                                                                assetsTypeCtrl
                                                                    .text
                                                                    .trim(),
                                                            mechanics: mechanicsCtrl
                                                                .text
                                                                .split(',')
                                                                .map(
                                                                  (e) =>
                                                                      e.trim(),
                                                                )
                                                                .where(
                                                                  (e) => e
                                                                      .isNotEmpty,
                                                                )
                                                                .toList(),
                                                            primaryColor:
                                                                _normHex(
                                                                  primaryCtrl
                                                                      .text,
                                                                ) ??
                                                                '#22C55E',
                                                            secondaryColor:
                                                                _normHex(
                                                                  secondaryCtrl
                                                                      .text,
                                                                ) ??
                                                                '#3B82F6',
                                                            accentColor:
                                                                _normHex(
                                                                  accentCtrl
                                                                      .text,
                                                                ) ??
                                                                '#F59E0B',
                                                            playerColor:
                                                                _normHex(
                                                                  playerCtrl
                                                                      .text,
                                                                ) ??
                                                                (_normHex(
                                                                      accentCtrl
                                                                          .text,
                                                                    ) ??
                                                                    '#F59E0B'),
                                                            fogEnabled:
                                                                fogEnabled,
                                                            fogDensity:
                                                                fogDensity
                                                                    .clamp(
                                                                      0.0,
                                                                      0.1,
                                                                    ),
                                                            cameraZoom:
                                                                cameraZoom
                                                                    .clamp(
                                                                      0.0,
                                                                      30.0,
                                                                    ),
                                                            gravityY: gravityY
                                                                .clamp(
                                                                  -50.0,
                                                                  0.0,
                                                                ),
                                                            jumpForce: jumpForce
                                                                .clamp(
                                                                  0.0,
                                                                  50.0,
                                                                ),
                                                            playerSkinId:
                                                                playerSkinId,
                                                            playerSpriteUrl:
                                                                spriteUrlCtrl
                                                                    .text
                                                                    .trim(),
                                                          );
                                                        } catch (_) {}
                                                      },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: playerCtrl,
                                                  enabled: !saving,
                                                  decoration: const InputDecoration(
                                                    labelText:
                                                        'Player color (#RRGGBB)',
                                                    isDense: true,
                                                  ),
                                                  onChanged: saving
                                                      ? null
                                                      : (v) {
                                                          pushHistorySnapshot();
                                                          setSheetState(
                                                            () =>
                                                                playerColor = v,
                                                          );
                                                          scheduleLiveApply(
                                                            reload: true,
                                                          );
                                                        },
                                                ),
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.sm,
                                              ),
                                              colorDot(playerCtrl.text),
                                              const SizedBox(width: 6),
                                              IconButton(
                                                tooltip: 'Paste',
                                                onPressed: saving
                                                    ? null
                                                    : () async {
                                                        pushHistorySnapshot();
                                                        await pasteHexInto(
                                                          playerCtrl,
                                                        );
                                                        setSheetState(
                                                          () => playerColor =
                                                              playerCtrl.text,
                                                        );
                                                        scheduleLiveApply(
                                                          reload: true,
                                                        );
                                                      },
                                                icon: const Icon(
                                                  Icons.content_paste_rounded,
                                                  size: 18,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Pick',
                                                onPressed: saving
                                                    ? null
                                                    : () async {
                                                        pushHistorySnapshot();
                                                        await pickColorFor(
                                                          playerCtrl,
                                                        );
                                                        setSheetState(
                                                          () => playerColor =
                                                              playerCtrl.text,
                                                        );
                                                        scheduleLiveApply(
                                                          reload: true,
                                                        );
                                                      },
                                                icon: const Icon(
                                                  Icons.color_lens_rounded,
                                                  size: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Speed',
                                                  style: AppTypography.body2
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 96,
                                                child: TextField(
                                                  controller: speedCtrl,
                                                  enabled: !saving,
                                                  keyboardType:
                                                      const TextInputType.numberWithOptions(
                                                        decimal: true,
                                                        signed: false,
                                                      ),
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter.allow(
                                                      RegExp(r'[0-9\.]'),
                                                    ),
                                                  ],
                                                  decoration:
                                                      const InputDecoration(
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 10,
                                                            ),
                                                      ),
                                                  onChanged: saving
                                                      ? null
                                                      : (txt) {
                                                          final v =
                                                              double.tryParse(
                                                                txt.trim(),
                                                              );
                                                          if (v == null) return;
                                                          setSheetState(
                                                            () =>
                                                                speed = v.clamp(
                                                                  0.0,
                                                                  20.0,
                                                                ),
                                                          );
                                                          scheduleLiveApply(
                                                            reload: true,
                                                          );
                                                        },
                                                  onSubmitted: saving
                                                      ? null
                                                      : (_) {
                                                          pushHistorySnapshot();
                                                          syncSpeedText();
                                                          scheduleLiveApply(
                                                            reload: true,
                                                          );
                                                        },
                                                ),
                                              ),
                                            ],
                                          ),
                                          Slider(
                                            value: speed.clamp(0.0, 20.0),
                                            min: 0.0,
                                            max: 20.0,
                                            divisions: 200,
                                            onChanged: saving
                                                ? null
                                                : (v) {
                                                    pushHistorySnapshot();
                                                    setSheetState(
                                                      () => speed = v,
                                                    );
                                                    syncSpeedText();
                                                    scheduleLiveApply(
                                                      reload: true,
                                                    );
                                                  },
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Time scale',
                                                  style: AppTypography.body2
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                              ),
                                              valuePill(
                                                timeScale.toStringAsFixed(2),
                                              ),
                                            ],
                                          ),
                                          Slider(
                                            value: timeScale.clamp(0.5, 2.0),
                                            min: 0.5,
                                            max: 2.0,
                                            divisions: 150,
                                            onChanged: saving
                                                ? null
                                                : (v) {
                                                    pushHistorySnapshot();
                                                    setSheetState(
                                                      () => timeScale = v,
                                                    );
                                                    scheduleLiveApply(
                                                      reload: true,
                                                    );
                                                  },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }
                              if (tabIndex == 2) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    sectionTitle('Look'),
                                    sectionCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: colorPresets.map((p) {
                                                final name =
                                                    p['name'] ?? 'Preset';
                                                final selected =
                                                    _normHex(
                                                          primaryCtrl.text,
                                                        ) ==
                                                        _normHex(
                                                          p['primary'],
                                                        ) &&
                                                    _normHex(
                                                          secondaryCtrl.text,
                                                        ) ==
                                                        _normHex(
                                                          p['secondary'],
                                                        ) &&
                                                    _normHex(accentCtrl.text) ==
                                                        _normHex(p['accent']);
                                                return GestureDetector(
                                                  onTap: saving
                                                      ? null
                                                      : () {
                                                          pushHistorySnapshot();
                                                          setSheetState(() {
                                                            primaryCtrl.text =
                                                                p['primary'] ??
                                                                primaryCtrl
                                                                    .text;
                                                            secondaryCtrl.text =
                                                                p['secondary'] ??
                                                                secondaryCtrl
                                                                    .text;
                                                            accentCtrl.text =
                                                                p['accent'] ??
                                                                accentCtrl.text;
                                                            if (p['player'] !=
                                                                null) {
                                                              playerCtrl.text =
                                                                  p['player']!;
                                                              playerColor =
                                                                  p['player']!;
                                                            }
                                                          });
                                                          scheduleLiveApply(
                                                            reload: false,
                                                          );
                                                        },
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 160,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 8,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: selected
                                                          ? cs.primary
                                                                .withOpacity(
                                                                  0.15,
                                                                )
                                                          : cs.surfaceContainerHighest
                                                                .withOpacity(
                                                                  0.35,
                                                                ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                      border: Border.all(
                                                        color: selected
                                                            ? cs.primary
                                                                  .withOpacity(
                                                                    0.7,
                                                                  )
                                                            : cs.outlineVariant
                                                                  .withOpacity(
                                                                    0.55,
                                                                  ),
                                                        width: selected
                                                            ? 1.5
                                                            : 1.0,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        colorDot(
                                                          p['primary'] ?? '',
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        colorDot(
                                                          p['secondary'] ?? '',
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        colorDot(
                                                          p['accent'] ?? '',
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          name,
                                                          style: AppTypography
                                                              .caption
                                                              .copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                color: selected
                                                                    ? cs.primary
                                                                    : cs.onSurface,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Primary',
                                                  style: AppTypography.body2
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                              ),
                                              colorDot(primaryCtrl.text),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                flex: 2,
                                                child: TextField(
                                                  controller: primaryCtrl,
                                                  onChanged: saving
                                                      ? null
                                                      : (_) {
                                                          pushHistorySnapshot();
                                                          setSheetState(() {});
                                                          scheduleLiveApply(
                                                            reload: false,
                                                          );
                                                        },
                                                  decoration:
                                                      const InputDecoration(
                                                        isDense: true,
                                                        hintText: '#RRGGBB',
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              IconButton(
                                                tooltip: 'Paste',
                                                onPressed: saving
                                                    ? null
                                                    : () async {
                                                        pushHistorySnapshot();
                                                        await pasteHexInto(
                                                          primaryCtrl,
                                                        );
                                                        setSheetState(() {});
                                                        scheduleLiveApply(
                                                          reload: false,
                                                        );
                                                      },
                                                icon: const Icon(
                                                  Icons.content_paste_rounded,
                                                  size: 18,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Pick',
                                                onPressed: saving
                                                    ? null
                                                    : () async {
                                                        pushHistorySnapshot();
                                                        await pickColorFor(
                                                          primaryCtrl,
                                                        );
                                                        setSheetState(() {});
                                                        scheduleLiveApply(
                                                          reload: false,
                                                        );
                                                      },
                                                icon: const Icon(
                                                  Icons.color_lens_rounded,
                                                  size: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Secondary',
                                                  style: AppTypography.body2
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                              ),
                                              colorDot(secondaryCtrl.text),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                flex: 2,
                                                child: TextField(
                                                  controller: secondaryCtrl,
                                                  onChanged: saving
                                                      ? null
                                                      : (_) {
                                                          pushHistorySnapshot();
                                                          setSheetState(() {});
                                                          scheduleLiveApply(
                                                            reload: false,
                                                          );
                                                        },
                                                  decoration:
                                                      const InputDecoration(
                                                        isDense: true,
                                                        hintText: '#RRGGBB',
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              IconButton(
                                                tooltip: 'Paste',
                                                onPressed: saving
                                                    ? null
                                                    : () async {
                                                        pushHistorySnapshot();
                                                        await pasteHexInto(
                                                          secondaryCtrl,
                                                        );
                                                        setSheetState(() {});
                                                        scheduleLiveApply(
                                                          reload: false,
                                                        );
                                                      },
                                                icon: const Icon(
                                                  Icons.content_paste_rounded,
                                                  size: 18,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Pick',
                                                onPressed: saving
                                                    ? null
                                                    : () async {
                                                        pushHistorySnapshot();
                                                        await pickColorFor(
                                                          secondaryCtrl,
                                                        );
                                                        setSheetState(() {});
                                                        scheduleLiveApply(
                                                          reload: false,
                                                        );
                                                      },
                                                icon: const Icon(
                                                  Icons.color_lens_rounded,
                                                  size: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Accent',
                                                  style: AppTypography.body2
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                              ),
                                              colorDot(accentCtrl.text),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                flex: 2,
                                                child: TextField(
                                                  controller: accentCtrl,
                                                  onChanged: saving
                                                      ? null
                                                      : (_) {
                                                          pushHistorySnapshot();
                                                          setSheetState(() {});
                                                          scheduleLiveApply(
                                                            reload: false,
                                                          );
                                                        },
                                                  decoration:
                                                      const InputDecoration(
                                                        isDense: true,
                                                        hintText: '#RRGGBB',
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              IconButton(
                                                tooltip: 'Paste',
                                                onPressed: saving
                                                    ? null
                                                    : () async {
                                                        pushHistorySnapshot();
                                                        await pasteHexInto(
                                                          accentCtrl,
                                                        );
                                                        setSheetState(() {});
                                                        scheduleLiveApply(
                                                          reload: false,
                                                        );
                                                      },
                                                icon: const Icon(
                                                  Icons.content_paste_rounded,
                                                  size: 18,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Pick',
                                                onPressed: saving
                                                    ? null
                                                    : () async {
                                                        pushHistorySnapshot();
                                                        await pickColorFor(
                                                          accentCtrl,
                                                        );
                                                        setSheetState(() {});
                                                        scheduleLiveApply(
                                                          reload: false,
                                                        );
                                                      },
                                                icon: const Icon(
                                                  Icons.color_lens_rounded,
                                                  size: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }
                              if (tabIndex == 3) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    sectionTitle('Environment'),
                                    sectionCard(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Fog',
                                                  style: AppTypography.body2
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                              ),
                                              Switch(
                                                value: fogEnabled,
                                                onChanged: saving
                                                    ? null
                                                    : (v) {
                                                        pushHistorySnapshot();
                                                        setSheetState(
                                                          () => fogEnabled = v,
                                                        );
                                                        scheduleLiveApply(
                                                          reload: false,
                                                        );
                                                      },
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Fog density',
                                                  style: AppTypography.body2
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                              ),
                                              valuePill(
                                                fogDensity.toStringAsFixed(4),
                                              ),
                                            ],
                                          ),
                                          Slider(
                                            value: fogDensity.clamp(0.0, 0.1),
                                            min: 0.0,
                                            max: 0.1,
                                            divisions: 100,
                                            onChanged: saving
                                                ? null
                                                : (v) {
                                                    pushHistorySnapshot();
                                                    setSheetState(
                                                      () => fogDensity = v,
                                                    );
                                                    scheduleLiveApply(
                                                      reload: false,
                                                    );
                                                  },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  sectionTitle('Camera & Physics'),
                                  sectionCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Camera zoom',
                                                style: AppTypography.body2
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                            ),
                                            valuePill(
                                              cameraZoom <= 0
                                                  ? 'auto'
                                                  : cameraZoom.toStringAsFixed(
                                                      1,
                                                    ),
                                            ),
                                          ],
                                        ),
                                        Slider(
                                          value: cameraZoom.clamp(0.0, 30.0),
                                          min: 0.0,
                                          max: 30.0,
                                          divisions: 300,
                                          onChanged: saving
                                              ? null
                                              : (v) {
                                                  pushHistorySnapshot();
                                                  setSheetState(
                                                    () => cameraZoom = v,
                                                  );
                                                  scheduleLiveApply(
                                                    reload: false,
                                                  );
                                                },
                                        ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Gravity Y',
                                                style: AppTypography.body2
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                            ),
                                            valuePill(
                                              gravityY == 0
                                                  ? 'default'
                                                  : gravityY.toStringAsFixed(1),
                                            ),
                                          ],
                                        ),
                                        Slider(
                                          value: gravityY.clamp(-50.0, 0.0),
                                          min: -50.0,
                                          max: 0.0,
                                          divisions: 200,
                                          onChanged: saving
                                              ? null
                                              : (v) {
                                                  pushHistorySnapshot();
                                                  setSheetState(
                                                    () => gravityY = v,
                                                  );
                                                  scheduleLiveApply(
                                                    reload: false,
                                                  );
                                                },
                                        ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Jump force',
                                                style: AppTypography.body2
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                            ),
                                            valuePill(
                                              jumpForce == 0
                                                  ? 'default'
                                                  : jumpForce.toStringAsFixed(
                                                      1,
                                                    ),
                                            ),
                                          ],
                                        ),
                                        Slider(
                                          value: jumpForce.clamp(0.0, 50.0),
                                          min: 0.0,
                                          max: 50.0,
                                          divisions: 250,
                                          onChanged: saving
                                              ? null
                                              : (v) {
                                                  pushHistorySnapshot();
                                                  setSheetState(
                                                    () => jumpForce = v,
                                                  );
                                                  scheduleLiveApply(
                                                    reload: false,
                                                  );
                                                },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }(),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: CustomButton(
                                text: saving ? 'Applying…' : 'Apply',
                                onPressed: saving ? null : doApply,
                                type: ButtonType.primary,
                                icon: const Icon(Icons.check_rounded),
                                isFullWidth: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      // The bottom sheet route can still be animating out even after the Future completes.
      // Defer disposal to the next frame to avoid "used after being disposed" during teardown.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          primaryCtrl.dispose();
        } catch (_) {}
        try {
          secondaryCtrl.dispose();
        } catch (_) {}
        try {
          accentCtrl.dispose();
        } catch (_) {}
        try {
          playerCtrl.dispose();
        } catch (_) {}
        try {
          spriteUrlCtrl.dispose();
        } catch (_) {}
        try {
          speedCtrl.dispose();
        } catch (_) {}
      });
    }
  }

  Future<void> _runJs(String js) async {
    try {
      await _controller.runJavaScript(js);
    } catch (_) {}
  }

  void _notifyJsError(String msg) {
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastJsErrAtMs < 1500) return;
    _lastJsErrAtMs = now;
    _telemetryJsErrors++;
    final s = msg.trim();
    if (s.isNotEmpty && _telemetryErrorSamples.length < 6) {
      _telemetryErrorSamples.add(s.length > 180 ? s.substring(0, 180) : s);
    }

    if (s == 'webglcontextlost') {
      _telemetryWebglContextLost++;
    }
    AppNotifier.showError(msg);
  }

  Future<void> _installJsErrorBridge() async {
    await _runJs("""
      (function(){
        try {
          if (window.__gameforgeErrBridgeInstalled) return;
          window.__gameforgeErrBridgeInstalled = true;
          function post(msg){
            try { if (window.GameForgeLog && window.GameForgeLog.postMessage) window.GameForgeLog.postMessage(String(msg)); } catch(e) {}
          }
          window.addEventListener('error', function(ev){
            try {
              var m = (ev && ev.message) ? ev.message : 'JS error';
              var f = (ev && ev.filename) ? ev.filename : '';
              var l = (ev && ev.lineno) ? ev.lineno : '';
              var c = (ev && ev.colno) ? ev.colno : '';
              post('[JS] ' + m + (f ? (' @ ' + f + ':' + l + ':' + c) : ''));
            } catch(e) {}
          });
          window.addEventListener('unhandledrejection', function(ev){
            try {
              var r = (ev && ev.reason) ? (ev.reason.message || ev.reason.toString()) : 'Unhandled rejection';
              post('[Promise] ' + r);
            } catch(e) {}
          });
          try {
            var origErr = console.error;
            console.error = function(){
              try { post('[console.error] ' + Array.prototype.slice.call(arguments).join(' ')); } catch(e) {}
              try { if (origErr) origErr.apply(console, arguments); } catch(e) {}
            };
          } catch(e) {}
        } catch(e) {}
      })();
      """);
  }

  Future<Object?> _runJsResult(String js) async {
    try {
      return await _controller.runJavaScriptReturningResult(js);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _detectBridgeSupport() async {
    final res = await _runJsResult("""
      (function(){
        try {
          var hasApplyFn = (typeof window.gameforgeApplyRuntimeConfig === 'function')
            || (typeof window.applyRuntimeConfig === 'function')
            || (typeof window.setRuntimeConfig === 'function')
            || (typeof window.__gfTryApplyRuntimeConfig === 'function');

          var hasUnity = (typeof window.unityInstance !== 'undefined')
            && window.unityInstance
            && (typeof window.unityInstance.SendMessage === 'function');

          return JSON.stringify({ hasApplyFn: hasApplyFn, hasUnity: hasUnity });
        } catch (e) {
          return JSON.stringify({ hasApplyFn: false, hasUnity: false });
        }
      })();
      """);

    String? s;
    if (res is String) {
      s = res;
    } else if (res != null) {
      s = res.toString();
    }

    try {
      if (s == null) return null;
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkBridgeSupportOnce() async {
    if (_bridgeChecked) return;
    _bridgeChecked = true;

    final pid = _projectId;
    if (pid == null || pid.isEmpty) return;

    // Unity instance can appear after a few seconds. Poll a few times before warning.
    for (var i = 0; i < 8; i++) {
      final data = await _detectBridgeSupport();
      final hasApplyFn = (data?['hasApplyFn'] == true);
      final hasUnity = (data?['hasUnity'] == true);
      if (hasApplyFn || hasUnity) return;
      await Future.delayed(const Duration(milliseconds: 700));
    }

    if (!mounted) return;
    AppNotifier.showError(
      'This WebGL template may not support live gameplay changes (speed/physics). Only visual changes may apply unless the template adds a runtime config listener.',
    );
  }

  Future<void> _sendKey({
    required String key,
    required String code,
    required bool down,
  }) async {
    final prev = _keyDown[code] ?? false;
    if (down == prev) return;
    _keyDown[code] = down;
    final type = down ? 'keydown' : 'keyup';
    int keyCodeFor(String k) {
      switch (k) {
        case 'ArrowLeft':
          return 37;
        case 'ArrowUp':
          return 38;
        case 'ArrowRight':
          return 39;
        case 'ArrowDown':
          return 40;
        case ' ':
          return 32;
      }
      if (k.length == 1) {
        final u = k.toUpperCase();
        final c = u.codeUnitAt(0);
        if (c >= 65 && c <= 90) return c;
      }
      return 0;
    }

    final kc = keyCodeFor(key);

    final rid = (_mpRoomId ?? '').trim();
    final sid = (_mpSessionId ?? '').trim();
    if (rid.isNotEmpty && sid.isNotEmpty) {
      _mp.sendGameInput(
        sessionId: sid,
        roomId: rid,
        type: down ? 'keydown' : 'keyup',
        payload: {'key': key, 'code': code, 'down': down, 'keyCode': kc},
      );
    }

    await _runJsBatched("""
      (function(){
        try {
          var target = document.activeElement || document.querySelector('canvas') || document.body;
          var e = new KeyboardEvent('$type', {
            key: '$key',
            code: '$code',
            bubbles: true,
            cancelable: true,
            keyCode: $kc,
            which: $kc
          });
          try {
            if ($kc) {
              Object.defineProperty(e, 'keyCode', { get: function(){ return $kc; } });
              Object.defineProperty(e, 'which', { get: function(){ return $kc; } });
            }
          } catch (e) {}

          try { if (target && target.dispatchEvent) target.dispatchEvent(e); } catch (e) {}
          try { if (document && document.dispatchEvent) document.dispatchEvent(e); } catch (e) {}
          try { if (document.body && document.body.dispatchEvent) document.body.dispatchEvent(e); } catch (e) {}
          try { if (window && window.dispatchEvent) window.dispatchEvent(e); } catch (e) {}
        } catch (e) {}
      })();
      """);
  }

  Future<void> _sendMousePrimary({required bool down}) async {
    final mouseType = down ? 'mousedown' : 'mouseup';
    final pointerType = down ? 'pointerdown' : 'pointerup';
    await _runJsBatched("""
      (function(){
        try {
          var canvas = document.querySelector('canvas');
          var el = canvas || document.elementFromPoint(window.innerWidth/2, window.innerHeight/2) || document.body;
          try { if (canvas && canvas.focus) canvas.focus(); } catch(e) {}
          var rect = (el && el.getBoundingClientRect) ? el.getBoundingClientRect() : { left: 0, top: 0, width: window.innerWidth, height: window.innerHeight };
          var x = rect.left + rect.width / 2;
          var y = rect.top + rect.height / 2;
          var pev = new PointerEvent('$pointerType', { pointerId: 1, pointerType: 'mouse', isPrimary: true, bubbles: true, cancelable: true, button: 0, buttons: ${down ? 1 : 0}, clientX: x, clientY: y });
          var mev = new MouseEvent('$mouseType', { bubbles: true, cancelable: true, button: 0, buttons: ${down ? 1 : 0}, clientX: x, clientY: y });
          el.dispatchEvent(pev);
          el.dispatchEvent(mev);
          if (!${down ? 'true' : 'false'}) {
            try {
              var cev = new MouseEvent('click', { bubbles: true, cancelable: true, button: 0, clientX: x, clientY: y });
              el.dispatchEvent(cev);
            } catch (e) {}
          }
        } catch (e) {}
      })();
      """);
  }

  Future<void> _releaseAllKeys() async {
    _keyDown.clear();
    await _sendKey(key: 'ArrowLeft', code: 'ArrowLeft', down: false);
    await _sendKey(key: 'a', code: 'KeyA', down: false);
    await _sendKey(key: 'ArrowRight', code: 'ArrowRight', down: false);
    await _sendKey(key: 'd', code: 'KeyD', down: false);
    await _sendKey(key: ' ', code: 'Space', down: false);
    await _sendKey(key: 'w', code: 'KeyW', down: false);
    await _sendKey(key: 'ArrowUp', code: 'ArrowUp', down: false);
    await _sendKey(key: 'f', code: 'KeyF', down: false);
    await _sendMousePrimary(down: false);
  }

  Future<void> _ensureGameFocus() async {
    await _runJs("""
      (function(){
        try {
          document.body.style.webkitUserSelect = 'none';
          document.body.style.userSelect = 'none';
          document.body.tabIndex = 0;
          document.body.focus();
          var canvas = document.querySelector('canvas');
          if (canvas) {
            canvas.tabIndex = 0;
            canvas.focus();
          }
        } catch (err) {}
      })();
      """);
  }

  @override
  void initState() {
    super.initState();

    _sessionStartAtMs = DateTime.now().millisecondsSinceEpoch;

    _resolvedUrl = _normalizePlayUrl(widget.url);

    _mpRoomId = (widget.mpRoomId ?? '').trim().isEmpty
        ? null
        : widget.mpRoomId!.trim();
    _mpSessionId = (widget.mpSessionId ?? '').trim().isEmpty
        ? null
        : widget.mpSessionId!.trim();
    _mpIsHost = widget.mpIsHost;

    _projectId = (widget.projectId ?? '').trim().isNotEmpty
        ? widget.projectId!.trim()
        : _extractProjectId(_resolvedUrl);
    _autoTrailerMode = _isAutoTrailerEnabled(_resolvedUrl);
    _autoTrailerStyle = _readAutoTrailerStyleFromUrl(_resolvedUrl);
    _autoTrailerTarget = _readAutoTrailerTargetFromUrl(_resolvedUrl);
    _autoTrailerAutoPublishEnabled = _readAutoTrailerAutoPublishFromUrl(
      _resolvedUrl,
    );
    _loadFpsControlsPref();
    _loadControllerSkinPref();
    _loadAutoBalancePref();
    _loadAutoBalancePending();

    _hudPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);

    if (_autoTrailerMode) {
      _startAutoTrailerCapture();
    }

    final isIos = defaultTargetPlatform == TargetPlatform.iOS;

    _controller = WebViewController();
    _webView = WebViewWidget(controller: _controller);

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
        isIos
            ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'
            : null,
      )
      ..addJavaScriptChannel(
        'GameForgeLog',
        onMessageReceived: (msg) {
          final text = msg.message.trim();
          if (text.isEmpty) return;
          _notifyJsError(text);
        },
      )
      ..addJavaScriptChannel(
        'GameForgeMP',
        onMessageReceived: (msg) {
          final text = msg.message.trim();
          if (text.isEmpty) return;
          final rid = (_mpRoomId ?? '').trim();
          final sid = (_mpSessionId ?? '').trim();
          if (rid.isEmpty || sid.isEmpty) return;
          if (!_mpIsHost) return;

          try {
            final decoded = jsonDecode(text);
            if (decoded is! Map) return;
            final type = (decoded['type'] ?? '').toString();
            if (type != 'state') return;
            final stRaw = decoded['state'];
            final st = stRaw is Map
                ? Map<String, dynamic>.from(stRaw)
                : <String, dynamic>{};
            _mp.sendGameState(sessionId: sid, roomId: rid, state: st);
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            _cancelBlankWatchdog();
            _cancelHealthMonitor();
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _loading = false;
            });
            _ensureGameFocus();
            _scheduleBlankWatchdog();
            _startHealthMonitor();
            () async {
              try {
                if (isIos) {
                  await _runJs('''
(function(){
  try {
    document.documentElement.style.height = '100%';
    document.body.style.height = '100%';
    document.body.style.margin = '0';
    document.body.style.padding = '0';
    document.body.style.background = '#000';
    var canvas = document.querySelector('canvas');
    if (canvas) {
      canvas.style.width = '100%';
      canvas.style.height = '100%';
      canvas.style.display = 'block';
      canvas.style.background = '#000';
    }
    var meta = document.querySelector('meta[name=viewport]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.setAttribute('name','viewport');
      document.head.appendChild(meta);
    }
    meta.setAttribute('content','width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
  } catch(e) {}
})();
''');

                  await _runJs('''
(function(){
  try {
    window.__gfWebglContextLost = false;
    var canvas = document.querySelector('canvas');
    if (!canvas) return;
    canvas.addEventListener('webglcontextlost', function(e){
      try { e.preventDefault(); } catch(_) {}
      window.__gfWebglContextLost = true;
      try { if (window.GameForgeLog && GameForgeLog.postMessage) GameForgeLog.postMessage('webglcontextlost'); } catch(_) {}
    }, { passive: false });
    canvas.addEventListener('webglcontextrestored', function(){
      window.__gfWebglContextLost = false;
      try { if (window.GameForgeLog && GameForgeLog.postMessage) GameForgeLog.postMessage('webglcontextrestored'); } catch(_) {}
    });
  } catch(e) {}
})();
''');
                }
                await _installJsErrorBridge();
                await _installMpBridge();
                if (_autoTrailerMode) {
                  await _startAutoTrailerCanvasRecorder();
                }
                await _bootMultiplayer();
                _startGhostOverlay();
                final pid = _projectId;
                if (pid == null || pid.isEmpty) {
                  await _checkBridgeSupportOnce();
                  return;
                }
                final cfg = await _fetchRuntimeConfig();
                if (cfg == null) return;
                _lastRuntimeConfig = cfg;
                final appliedCfg = await _maybeAutoBalanceRuntimeConfig(cfg);
                await _pushRuntimeConfigToWebView(
                  speed: (appliedCfg['speed'] is num)
                      ? (appliedCfg['speed'] as num).toDouble()
                      : 7.0,
                  timeScale: (appliedCfg['timeScale'] is num)
                      ? (appliedCfg['timeScale'] as num).toDouble()
                      : 1.0,
                  difficulty: (appliedCfg['difficulty'] is num)
                      ? (appliedCfg['difficulty'] as num).toDouble()
                      : 0.5,
                  theme: (appliedCfg['theme']?.toString() ?? 'default'),
                  notes: (appliedCfg['notes']?.toString() ?? ''),
                  genre: (appliedCfg['genre']?.toString() ?? 'platformer'),
                  assetsType:
                      (appliedCfg['assetsType']?.toString() ?? 'lowpoly'),
                  mechanics: (appliedCfg['mechanics'] is List)
                      ? (appliedCfg['mechanics'] as List)
                            .map((e) => e?.toString() ?? '')
                            .where((e) => e.trim().isNotEmpty)
                            .toList()
                      : const <String>[],
                  primaryColor:
                      (appliedCfg['primaryColor']?.toString() ?? '#22C55E'),
                  secondaryColor:
                      (appliedCfg['secondaryColor']?.toString() ?? '#3B82F6'),
                  accentColor:
                      (appliedCfg['accentColor']?.toString() ?? '#F59E0B'),
                  playerColor:
                      (appliedCfg['playerColor']?.toString() ??
                      (appliedCfg['accentColor']?.toString() ?? '#F59E0B')),
                  fogEnabled: (appliedCfg['fogEnabled'] is bool)
                      ? (appliedCfg['fogEnabled'] as bool)
                      : false,
                  fogDensity: (appliedCfg['fogDensity'] is num)
                      ? (appliedCfg['fogDensity'] as num).toDouble()
                      : 0.0,
                  cameraZoom: (appliedCfg['cameraZoom'] is num)
                      ? (appliedCfg['cameraZoom'] as num).toDouble()
                      : 0.0,
                  gravityY: (appliedCfg['gravityY'] is num)
                      ? (appliedCfg['gravityY'] as num).toDouble()
                      : 0.0,
                  jumpForce: (appliedCfg['jumpForce'] is num)
                      ? (appliedCfg['jumpForce'] as num).toDouble()
                      : 0.0,
                  playerSkinId: appliedCfg['playerSkinId']?.toString(),
                  playerSpriteUrl: appliedCfg['playerSpriteUrl']?.toString(),
                );
                await _checkBridgeSupportOnce();
              } catch (_) {}
            }();
          },
          onWebResourceError: (err) {
            _cancelBlankWatchdog();
            _cancelHealthMonitor();
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = err.description;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(_withCacheBuster(_resolvedUrl)));
  }

  @override
  void dispose() {
    _cancelBlankWatchdog();
    _cancelHealthMonitor();
    _releaseAllKeys();
    _applySystemFullscreen(false);
    _mp.removeListener(_onMpUpdate);
    _mp.disconnect();
    _mpText.dispose();
    _mpScroll.dispose();
    _ghostTick?.cancel();
    _hudPulseCtrl.dispose();
    _voicePersistDebounce?.cancel();
    _autoTrailerPoll?.cancel();
    _autoTrailerEtaTicker?.cancel();
    _autoTrailerCaptureTick?.cancel();
    try {
      _speech.stop();
    } catch (_) {}
    super.dispose();
  }

  Future<Map<String, dynamic>> _maybeAutoBalanceRuntimeConfig(
    Map<String, dynamic> cfg,
  ) async {
    if (!_autoBalanceNextRun) return cfg;
    if (_autoBalanceAppliedForPending) return cfg;
    final pending = _autoBalancePending;
    if (pending == null || pending.isEmpty) return cfg;
    final outcome = (pending['outcome'] ?? '').toString().trim().toLowerCase();
    if (outcome != 'win' && outcome != 'loss') return cfg;

    double asDouble(dynamic v, double fallback) {
      if (v is num) return v.toDouble();
      final s = (v ?? '').toString().trim();
      final p = double.tryParse(s);
      return p ?? fallback;
    }

    double clamp(double v, double min, double max) {
      if (v < min) return min;
      if (v > max) return max;
      return v;
    }

    final baseSpeed = asDouble(cfg['speed'], 7.0);
    final baseTimeScale = asDouble(cfg['timeScale'], 1.0);
    final baseDifficulty = asDouble(cfg['difficulty'], 0.5);

    final next = <String, dynamic>{...cfg};
    if (outcome == 'loss') {
      next['difficulty'] = clamp(baseDifficulty * 0.9, 0.1, 1.0);
      next['timeScale'] = clamp(baseTimeScale * 0.95, 0.5, 2.0);
      next['speed'] = clamp(baseSpeed * 0.95, 1.0, 30.0);
    } else {
      next['difficulty'] = clamp(baseDifficulty * 1.1, 0.1, 1.0);
      next['timeScale'] = clamp(baseTimeScale * 1.03, 0.5, 2.0);
      next['speed'] = clamp(baseSpeed * 1.05, 1.0, 30.0);
    }

    final pid = _projectId;
    final token = context.read<AuthProvider>().token;
    if (pid != null && pid.isNotEmpty && token != null && token.isNotEmpty) {
      try {
        await ProjectsService.updateProject(
          token: token,
          projectId: pid,
          speed: asDouble(next['speed'], baseSpeed),
          timeScale: asDouble(next['timeScale'], baseTimeScale),
          difficulty: asDouble(next['difficulty'], baseDifficulty),
        );
      } catch (_) {}
    }

    _lastRuntimeConfig = next;
    _autoBalanceAppliedForPending = true;
    await _clearAutoBalancePending();
    if (!mounted) return next;
    AppNotifier.showSuccess(
      outcome == 'loss'
          ? 'Auto-balance: easier next run'
          : 'Auto-balance: harder next run',
    );
    _setLiveApplying();
    return next;
  }

  void _startGhostOverlay() {
    _ghostTick?.cancel();
    final rid = (_mpRoomId ?? '').trim();
    final sid = (_mpSessionId ?? '').trim();
    if (rid.isEmpty || sid.isEmpty) return;

    void pushFeed(String text) {
      final t = text.trim();
      if (t.isEmpty) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      _mpFeed.add(_MpFeedItem(text: t, tsMs: now));
      if (_mpFeed.length > 8) {
        _mpFeed.removeRange(0, _mpFeed.length - 8);
      }
    }

    _ghostTick = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      final now = DateTime.now().millisecondsSinceEpoch;

      final inputs = _mp.gameInputs;
      for (final i in inputs) {
        if (i.ts <= _lastProcessedInputTs) continue;
        _lastProcessedInputTs = i.ts;
        final uid = i.userId.trim();
        if (uid.isEmpty) continue;

        final me = (_mp.myUserId ?? '').trim();
        if (me.isNotEmpty && uid == me) continue;

        final existed = _ghosts.containsKey(uid);
        final gp = _ghosts.putIfAbsent(uid, () {
          final seed = uid.hashCode;
          final c = [
            const Color(0xFF00E5FF),
            const Color(0xFF7C3AED),
            const Color(0xFFFFD54F),
            const Color(0xFF22C55E),
            const Color(0xFFEF4444),
          ][seed.abs() % 5];
          final x = 0.15 + ((seed.abs() % 70) / 100.0);
          final y = 0.35 + (((seed.abs() ~/ 7) % 45) / 100.0);
          return _GhostPlayer(userId: uid, color: c, pos: Offset(x, y));
        });

        if (!existed) {
          pushFeed('Player joined');
        }

        gp.lastInputAtMs = now;
        if (i.type == 'keydown' || i.type == 'keyup') {
          final down = i.payload['down'] == true;
          final key = (i.payload['key'] ?? '').toString();
          if (key == 'a' || key == 'ArrowLeft') gp.left = down;
          if (key == 'd' || key == 'ArrowRight') gp.right = down;
          if (key == 'w' || key == 'ArrowUp' || key == ' ') {
            if (down) gp.jumpQueued = true;
          }
        } else if (i.type == 'emote') {
          final emoji = (i.payload['emoji'] ?? '').toString().trim();
          if (emoji.isNotEmpty) {
            gp.pushEmote(emoji);
            pushFeed('$emoji');
          }
        }
      }

      var anyChanged = false;
      final dt = 16 / 1000.0;
      for (final gp in _ghosts.values) {
        final before = gp.renderPos;
        gp.step(dt);
        if ((gp.renderPos - before).distance > 0.0001) anyChanged = true;
      }

      _ghosts.removeWhere((_, gp) => now - gp.lastInputAtMs > 12000);
      _mpFeed.removeWhere((e) => now - e.tsMs > 4200);

      if (anyChanged) {
        setState(() {});
      }
    });
  }

  Widget _ghostOverlay() {
    if ((_mpRoomId ?? '').trim().isEmpty || (_mpSessionId ?? '').trim().isEmpty)
      return const SizedBox.shrink();
    if (_ghosts.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GhostTrailPainter(
                    players: _ghosts.values.toList(),
                    sizePx: Size(w, h),
                  ),
                ),
              ),
              for (final gp in _ghosts.values)
                Positioned(
                  left: (gp.renderPos.dx.clamp(0.05, 0.95) * w) - 16,
                  top: (gp.renderPos.dy.clamp(0.10, 0.95) * h) - 16,
                  child: _GhostAvatar(
                    color: gp.color,
                    label: gp.shortLabel,
                    emotes: gp.emotes,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _mpFeedOverlay() {
    if ((_mpRoomId ?? '').trim().isEmpty || (_mpSessionId ?? '').trim().isEmpty)
      return const SizedBox.shrink();
    if (_mpFeed.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topLeft,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 10, top: 54),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in _mpFeed.reversed)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.40),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: Text(
                        e.text,
                        style: AppTypography.caption.copyWith(
                          color: cs.onSurface.withOpacity(0.90),
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _mpAutoscroll() {
    if (!_mpScroll.hasClients) return;
    Future.microtask(() {
      if (!_mpScroll.hasClients) return;
      _mpScroll.animateTo(
        _mpScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _openMpOverlay() {
    final rid = (_mpRoomId ?? '').trim();
    if (rid.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final shouldAvoidBlur = defaultTargetPlatform == TargetPlatform.iOS;
        Widget glass({required Widget child}) {
          final content = Container(
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.86),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
            ),
            child: child,
          );

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: shouldAvoidBlur
                ? content
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: content,
                  ),
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: glass(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.55,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Multiplayer',
                              style: AppTypography.subtitle1.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _mp,
                            builder: (context, _) {
                              final connected = _mp.connected;
                              final joining = _mp.connecting;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: connected
                                      ? cs.tertiaryContainer
                                      : cs.surfaceContainerHighest,
                                ),
                                child: Text(
                                  connected
                                      ? 'LIVE'
                                      : (joining ? 'CONNECTING' : 'OFFLINE'),
                                  style: AppTypography.caption.copyWith(
                                    color: connected
                                        ? cs.onTertiaryContainer
                                        : cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: AnimatedBuilder(
                        animation: _mp,
                        builder: (context, _) {
                          final members = _mp.room?.members ?? const [];
                          return SizedBox(
                            height: 52,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, i) {
                                final m = members[i];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: cs.surface,
                                    border: Border.all(
                                      color: cs.outlineVariant.withOpacity(
                                        0.55,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: m.isOnline
                                              ? const Color(0xFF22C55E)
                                              : cs.outlineVariant,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        m.username,
                                        style: AppTypography.caption.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemCount: members.length,
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: AnimatedBuilder(
                        animation: _mp,
                        builder: (context, _) {
                          return Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    final rid = (_mpRoomId ?? '').trim();
                                    if (rid.isEmpty) return;
                                    if (_mp.voiceJoined) {
                                      _mp.voiceStop();
                                    } else {
                                      _mp.voiceJoin(roomId: rid);
                                    }
                                  },
                                  icon: Icon(
                                    _mp.voiceJoined
                                        ? (_mp.voiceMuted
                                              ? Icons.mic_off_rounded
                                              : Icons.mic_rounded)
                                        : Icons.mic_none_rounded,
                                  ),
                                  label: Text(
                                    _mp.voiceJoined
                                        ? (_mp.voiceMuted
                                              ? 'Muted'
                                              : 'Voice Live')
                                        : 'Join Voice',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _mp.voiceJoined
                                        ? cs.tertiaryContainer
                                        : cs.surface,
                                    foregroundColor: _mp.voiceJoined
                                        ? cs.onTertiaryContainer
                                        : cs.onSurface,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    side: BorderSide(
                                      color: cs.outlineVariant.withOpacity(
                                        0.55,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                tooltip: _mp.voiceJoined
                                    ? 'Toggle mute'
                                    : 'Self test (long-press to stop)',
                                onPressed: () {
                                  if (_mp.voiceJoined) {
                                    _mp.voiceToggleMute();
                                  } else {
                                    if (_mp.voiceLoopback) {
                                      _mp.voiceSelfTestStop();
                                    } else {
                                      _mp.voiceSelfTestStart();
                                    }
                                  }
                                },
                                icon: Icon(
                                  _mp.voiceLoopback
                                      ? Icons.hearing_rounded
                                      : Icons.settings_voice_rounded,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Row(
                        children: [
                          for (final e in const ['🔥', '😂', '💀', '⚡️'])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  final rid = (_mpRoomId ?? '').trim();
                                  final sid = (_mpSessionId ?? '').trim();
                                  if (rid.isEmpty || sid.isEmpty) return;
                                  _mp.sendGameInput(
                                    sessionId: sid,
                                    roomId: rid,
                                    type: 'emote',
                                    payload: {'emoji': e},
                                  );
                                  final me = (_mp.myUserId ?? '').trim();
                                  if (me.isNotEmpty) {
                                    final gp = _ghosts.putIfAbsent(me, () {
                                      final seed = me.hashCode;
                                      final c = [
                                        const Color(0xFF00E5FF),
                                        const Color(0xFF7C3AED),
                                        const Color(0xFFFFD54F),
                                        const Color(0xFF22C55E),
                                        const Color(0xFFEF4444),
                                      ][seed.abs() % 5];
                                      return _GhostPlayer(
                                        userId: me,
                                        color: c,
                                        pos: const Offset(0.50, 0.85),
                                      );
                                    });
                                    gp.pushEmote(e);
                                  }
                                  setState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: cs.outlineVariant.withOpacity(
                                        0.55,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    e,
                                    style: AppTypography.subtitle1.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const Spacer(),
                        ],
                      ),
                    ),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _mp,
                        builder: (context, _) {
                          final msgs = _mp.messages;
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _mpAutoscroll(),
                          );
                          return ListView.builder(
                            controller: _mpScroll,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: msgs.length,
                            itemBuilder: (context, i) {
                              final m = msgs[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cs.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: cs.outlineVariant.withOpacity(0.55),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.username,
                                      style: AppTypography.caption.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(m.text, style: AppTypography.body2),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _mpText,
                              minLines: 1,
                              maxLines: 3,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) async {
                                final msg = _mpText.text.trim();
                                if (msg.isEmpty) return;
                                final rid = (_mpRoomId ?? '').trim();
                                await _mp.sendChat(
                                  text: msg,
                                  roomId: rid.isEmpty ? null : rid,
                                );
                                _mpText.clear();
                              },
                              decoration: InputDecoration(
                                hintText: 'Message…',
                                filled: true,
                                fillColor: cs.surfaceContainerHighest
                                    .withOpacity(0.55),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: IconButton(
                              onPressed: () async {
                                final msg = _mpText.text.trim();
                                if (msg.isEmpty) return;
                                final rid = (_mpRoomId ?? '').trim();
                                await _mp.sendChat(
                                  text: msg,
                                  roomId: rid.isEmpty ? null : rid,
                                );
                                _mpText.clear();
                              },
                              icon: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;

    Color skinAccent(_ControllerSkin s) {
      switch (s) {
        case _ControllerSkin.xbox:
          return const Color(0xFF22C55E);
        case _ControllerSkin.playstation:
          return const Color(0xFF3B82F6);
        case _ControllerSkin.nintendo:
          return const Color(0xFFEF4444);
        case _ControllerSkin.arcade:
          return cs.primary;
      }
    }

    BoxDecoration panelDecoration() {
      final accent = skinAccent(_controllerSkin);
      final base = cs.surface.withOpacity(0.38);
      final border = accent.withOpacity(0.22);
      return BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: accent.withOpacity(0.10),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      );
    }

    Widget glyph({required String text, required Color color}) {
      return Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.14),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(
          text,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w900,
            color: color,
            height: 1.0,
          ),
        ),
      );
    }

    Widget actionGlyph({required bool primary}) {
      final a = skinAccent(_controllerSkin);
      switch (_controllerSkin) {
        case _ControllerSkin.xbox:
          return glyph(text: primary ? 'A' : 'B', color: a);
        case _ControllerSkin.playstation:
          return glyph(text: primary ? '△' : '○', color: a);
        case _ControllerSkin.nintendo:
          return glyph(text: primary ? 'A' : 'B', color: a);
        case _ControllerSkin.arcade:
          return primary
              ? const Icon(Icons.arrow_upward_rounded, size: 22)
              : const Icon(Icons.local_fire_department_rounded, size: 22);
      }
    }

    _FaceSpec faceSpec({required bool primary}) {
      switch (_controllerSkin) {
        case _ControllerSkin.xbox:
          return _FaceSpec(
            label: primary ? 'A' : 'B',
            fillA: primary ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            fillB: primary ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
          );
        case _ControllerSkin.playstation:
          return _FaceSpec(
            label: primary ? '△' : '○',
            fillA: primary ? const Color(0xFF2563EB) : const Color(0xFF7C3AED),
            fillB: primary ? const Color(0xFF60A5FA) : const Color(0xFFA78BFA),
          );
        case _ControllerSkin.nintendo:
          return _FaceSpec(
            label: primary ? 'A' : 'B',
            fillA: primary ? const Color(0xFFEF4444) : const Color(0xFF111827),
            fillB: primary ? const Color(0xFFF87171) : const Color(0xFF374151),
          );
        case _ControllerSkin.arcade:
          return _FaceSpec(
            label: primary ? '↑' : '🔥',
            fillA: cs.primary,
            fillB: cs.primaryContainer,
          );
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _finalizeAutoTrailerPipeline();
        await _maybeShowPostGameCoachReport();
        if (!context.mounted) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard?tab=projects');
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBodyBehindAppBar: _isFullscreen,
        appBar: _isFullscreen
            ? null
            : AppBar(
                backgroundColor: cs.surface,
                elevation: 0,
                leading: IconButton(
                  onPressed: () async {
                    _releaseAllKeys();
                    await _finalizeAutoTrailerPipeline();
                    await _maybeShowPostGameCoachReport();
                    if (!context.mounted) return;
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/dashboard?tab=projects');
                    }
                  },
                  icon: Icon(Icons.arrow_back, color: cs.onSurface),
                ),
                title: Text('Play', style: AppTypography.subtitle1),
                actions: [
                  if (isIos)
                    IconButton(
                      tooltip: 'Open in Safari',
                      onPressed: _openInSafari,
                      icon: const Icon(Icons.open_in_new_rounded),
                    ),
                  IconButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _resolvedUrl),
                      );
                      if (!context.mounted) return;
                      AppNotifier.showSuccess('Link copied');
                    },
                    icon: const Icon(Icons.link_rounded),
                  ),
                  if (_autoTrailerMode)
                    IconButton(
                      tooltip: (_autoTrailerVideoUrl ?? '').trim().isNotEmpty
                          ? 'Open Reel'
                          : 'Check Reel • ETA ${_fmtAutoTrailerEta(_autoTrailerEtaSec)} / ${_fmtAutoTrailerTotalEstimate()}',
                      onPressed: () async {
                        final readyUrl = (_autoTrailerVideoUrl ?? '').trim();
                        if (readyUrl.isNotEmpty) {
                          final ok = await launchUrl(
                            Uri.parse(readyUrl),
                            mode: LaunchMode.externalApplication,
                          );
                          if (!ok)
                            AppNotifier.showError('Could not open reel link');
                          return;
                        }
                        await _checkAutoTrailerStatus();
                        AppNotifier.showSuccess(
                          'Reel: ${(_autoTrailerStage ?? _autoTrailerStatus).trim()} • ETA ${_fmtAutoTrailerEta(_autoTrailerEtaSec)} / ${_fmtAutoTrailerTotalEstimate()}',
                        );
                      },
                      icon: Icon(
                        (_autoTrailerVideoUrl ?? '').trim().isNotEmpty
                            ? Icons.movie_creation_rounded
                            : Icons.hourglass_bottom_rounded,
                      ),
                    ),
                  if (_autoTrailerMode)
                    IconButton(
                      tooltip: 'Trailer options',
                      onPressed: _openAutoTrailerOptionsSheet,
                      icon: const Icon(Icons.movie_filter_rounded),
                    ),
                  IconButton(
                    onPressed: _openControllerSkinSheet,
                    icon: const Icon(Icons.sports_esports_rounded),
                  ),
                  IconButton(
                    onPressed: _openingSettings ? null : _openSettingsDrawer,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                  IconButton(
                    onPressed: _toggleVoice,
                    icon: Icon(
                      _voiceListening
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleFullscreen,
                    icon: Icon(
                      _isFullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                    ),
                  ),
                ],
              ),
        body: Stack(
          children: [
            Positioned.fill(
              child: _webView ?? WebViewWidget(controller: _controller),
            ),

            _ghostOverlay(),

            _mpFeedOverlay(),

            if (_autoTrailerMode && !_isFullscreen)
              Positioned(
                top: kToolbarHeight + 8,
                left: 12,
                right: 12,
                child: IgnorePointer(
                  ignoring: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.52),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          (_autoTrailerVideoUrl ?? '').trim().isNotEmpty
                              ? Icons.check_circle_rounded
                              : Icons.timelapse_rounded,
                          color: (_autoTrailerVideoUrl ?? '').trim().isNotEmpty
                              ? Colors.greenAccent
                              : Colors.amberAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (_autoTrailerVideoUrl ?? '').trim().isNotEmpty
                                ? 'Reel ready • tap 🎬 to open'
                                : 'Reel ${(_autoTrailerStage ?? _autoTrailerStatus).trim().isEmpty ? 'processing' : (_autoTrailerStage ?? _autoTrailerStatus).trim()} • ${_autoTrailerStyle.toUpperCase()} • ETA ${_fmtAutoTrailerEta(_autoTrailerEtaSec)} / ${_fmtAutoTrailerTotalEstimate()}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final readyUrl = (_autoTrailerVideoUrl ?? '')
                                .trim();
                            if (readyUrl.isNotEmpty) {
                              final ok = await launchUrl(
                                Uri.parse(readyUrl),
                                mode: LaunchMode.externalApplication,
                              );
                              if (!ok)
                                AppNotifier.showError(
                                  'Could not open reel link',
                                );
                              return;
                            }
                            await _checkAutoTrailerStatus();
                          },
                          child: Text(
                            (_autoTrailerVideoUrl ?? '').trim().isNotEmpty
                                ? 'Open'
                                : 'Check Reel',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (_autoTrailerFinishing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.55),
                  alignment: Alignment.center,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121722),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Generating WOW Reel…',
                          style: AppTypography.subtitle2.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Capturing best moments, adding music + captions, and ${_autoTrailerAutoPublishEnabled ? 'publishing to feed' : 'preparing for manual publish'}.',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if ((_mpRoomId ?? '').trim().isNotEmpty &&
                (_mpSessionId ?? '').trim().isNotEmpty)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: AnimatedBuilder(
                  animation: _mp,
                  builder: (context, _) {
                    final room = _mp.room;
                    final members = room?.members ?? const [];

                    Widget pill(String t, {IconData? icon}) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.10),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, size: 14, color: Colors.white70),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              t,
                              style: AppTypography.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Row(
                      children: [
                        pill(
                          _mp.connected
                              ? 'MP LIVE'
                              : (_mp.connecting ? 'MP…' : 'MP OFF'),
                          icon: _mp.connected ? Icons.wifi : Icons.wifi_off,
                        ),
                        const SizedBox(width: 8),
                        pill('Players ${members.length}', icon: Icons.people),
                        const Spacer(),
                        pill(_mpIsHost ? 'HOST' : 'CLIENT', icon: Icons.shield),
                      ],
                    );
                  },
                ),
              ),

            if ((_mpRoomId ?? '').trim().isNotEmpty &&
                (_mpSessionId ?? '').trim().isNotEmpty)
              Positioned(
                right: 12,
                bottom: 12,
                child: FloatingActionButton(
                  heroTag: 'mp_overlay',
                  backgroundColor: cs.primary,
                  onPressed: _openMpOverlay,
                  child: const Icon(Icons.forum_rounded, color: Colors.white),
                ),
              ),
            if (!_loading && _error == null && !_fpsControlsEnabled)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  minimum: const EdgeInsets.all(AppSpacing.md),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) {
                      final fade = CurvedAnimation(
                        parent: anim,
                        curve: Curves.easeOut,
                      );
                      final slide = Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(fade);
                      return FadeTransition(
                        opacity: fade,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: Container(
                      key: ValueKey<String>('2d.${_controllerSkin.name}'),
                      child: (_controllerSkin == _ControllerSkin.arcade)
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: panelDecoration().copyWith(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _TouchKey(
                                    label: 'Left',
                                    child: const Icon(
                                      Icons.chevron_left_rounded,
                                      size: 28,
                                    ),
                                    size: 62,
                                    haptic: true,
                                    skin: _controllerSkin,
                                    onDown: () async {
                                      await _ensureGameFocus();
                                      await _sendKey(
                                        key: 'ArrowLeft',
                                        code: 'ArrowLeft',
                                        down: true,
                                      );
                                      await _sendKey(
                                        key: 'a',
                                        code: 'KeyA',
                                        down: true,
                                      );
                                    },
                                    onUp: () async {
                                      await _sendKey(
                                        key: 'ArrowLeft',
                                        code: 'ArrowLeft',
                                        down: false,
                                      );
                                      await _sendKey(
                                        key: 'a',
                                        code: 'KeyA',
                                        down: false,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _TouchKey(
                                    label: 'Jump',
                                    child: const Icon(
                                      Icons.keyboard_arrow_up_rounded,
                                      size: 28,
                                    ),
                                    size: 62,
                                    haptic: true,
                                    skin: _controllerSkin,
                                    onDown: () async {
                                      await _ensureGameFocus();
                                      await _sendKey(
                                        key: ' ',
                                        code: 'Space',
                                        down: true,
                                      );
                                      await _sendKey(
                                        key: 'w',
                                        code: 'KeyW',
                                        down: true,
                                      );
                                      await _sendKey(
                                        key: 'ArrowUp',
                                        code: 'ArrowUp',
                                        down: true,
                                      );
                                    },
                                    onUp: () async {
                                      await _sendKey(
                                        key: ' ',
                                        code: 'Space',
                                        down: false,
                                      );
                                      await _sendKey(
                                        key: 'w',
                                        code: 'KeyW',
                                        down: false,
                                      );
                                      await _sendKey(
                                        key: 'ArrowUp',
                                        code: 'ArrowUp',
                                        down: false,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  _TouchKey(
                                    label: 'Right',
                                    child: const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 28,
                                    ),
                                    size: 62,
                                    haptic: true,
                                    skin: _controllerSkin,
                                    onDown: () async {
                                      await _ensureGameFocus();
                                      await _sendKey(
                                        key: 'ArrowRight',
                                        code: 'ArrowRight',
                                        down: true,
                                      );
                                      await _sendKey(
                                        key: 'd',
                                        code: 'KeyD',
                                        down: true,
                                      );
                                    },
                                    onUp: () async {
                                      await _sendKey(
                                        key: 'ArrowRight',
                                        code: 'ArrowRight',
                                        down: false,
                                      );
                                      await _sendKey(
                                        key: 'd',
                                        code: 'KeyD',
                                        down: false,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _DpadCross(
                                  accent: skinAccent(_controllerSkin),
                                  glow: 0.12,
                                  skin: _controllerSkin,
                                  onUpDown: () async {
                                    await _ensureGameFocus();
                                    await _sendKey(
                                      key: 'w',
                                      code: 'KeyW',
                                      down: true,
                                    );
                                    await _sendKey(
                                      key: 'ArrowUp',
                                      code: 'ArrowUp',
                                      down: true,
                                    );
                                  },
                                  onUpUp: () async {
                                    await _sendKey(
                                      key: 'w',
                                      code: 'KeyW',
                                      down: false,
                                    );
                                    await _sendKey(
                                      key: 'ArrowUp',
                                      code: 'ArrowUp',
                                      down: false,
                                    );
                                  },
                                  onLeftDown: () async {
                                    await _ensureGameFocus();
                                    await _sendKey(
                                      key: 'a',
                                      code: 'KeyA',
                                      down: true,
                                    );
                                    await _sendKey(
                                      key: 'ArrowLeft',
                                      code: 'ArrowLeft',
                                      down: true,
                                    );
                                  },
                                  onLeftUp: () async {
                                    await _sendKey(
                                      key: 'a',
                                      code: 'KeyA',
                                      down: false,
                                    );
                                    await _sendKey(
                                      key: 'ArrowLeft',
                                      code: 'ArrowLeft',
                                      down: false,
                                    );
                                  },
                                  onDownDown: () async {
                                    await _ensureGameFocus();
                                    await _sendKey(
                                      key: 's',
                                      code: 'KeyS',
                                      down: true,
                                    );
                                    await _sendKey(
                                      key: 'ArrowDown',
                                      code: 'ArrowDown',
                                      down: true,
                                    );
                                  },
                                  onDownUp: () async {
                                    await _sendKey(
                                      key: 's',
                                      code: 'KeyS',
                                      down: false,
                                    );
                                    await _sendKey(
                                      key: 'ArrowDown',
                                      code: 'ArrowDown',
                                      down: false,
                                    );
                                  },
                                  onRightDown: () async {
                                    await _ensureGameFocus();
                                    await _sendKey(
                                      key: 'd',
                                      code: 'KeyD',
                                      down: true,
                                    );
                                    await _sendKey(
                                      key: 'ArrowRight',
                                      code: 'ArrowRight',
                                      down: true,
                                    );
                                  },
                                  onRightUp: () async {
                                    await _sendKey(
                                      key: 'd',
                                      code: 'KeyD',
                                      down: false,
                                    );
                                    await _sendKey(
                                      key: 'ArrowRight',
                                      code: 'ArrowRight',
                                      down: false,
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: panelDecoration(),
                                  child: _TouchKey(
                                    label: 'Jump',
                                    child: _FaceButtonFace(
                                      spec: faceSpec(primary: true),
                                      pressedT: _hudPulseCtrl.value,
                                    ),
                                    size: 62,
                                    haptic: true,
                                    skin: _controllerSkin,
                                    forceShape: _TouchKeyShape.circle,
                                    onDown: () async {
                                      await _ensureGameFocus();
                                      await _sendKey(
                                        key: ' ',
                                        code: 'Space',
                                        down: true,
                                      );
                                      await _sendKey(
                                        key: 'w',
                                        code: 'KeyW',
                                        down: true,
                                      );
                                      await _sendKey(
                                        key: 'ArrowUp',
                                        code: 'ArrowUp',
                                        down: true,
                                      );
                                    },
                                    onUp: () async {
                                      await _sendKey(
                                        key: ' ',
                                        code: 'Space',
                                        down: false,
                                      );
                                      await _sendKey(
                                        key: 'w',
                                        code: 'KeyW',
                                        down: false,
                                      );
                                      await _sendKey(
                                        key: 'ArrowUp',
                                        code: 'ArrowUp',
                                        down: false,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  margin: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppTypography.body2.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (isIos) ...[
                        OutlinedButton.icon(
                          onPressed: _openInSafari,
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Safari'),
                        ),
                        const SizedBox(width: 10),
                      ],
                      ElevatedButton.icon(
                        onPressed: () async {
                          setState(() {
                            _error = null;
                            _loading = true;
                            _blankWatchdogTries = 0;
                          });
                          try {
                            _telemetryReloads++;
                            await _controller.loadRequest(
                              Uri.parse(_withCacheBuster(_resolvedUrl)),
                            );
                          } catch (_) {}
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),

            if (_voiceListening)
              Positioned(
                top: _isFullscreen ? 16 : (kToolbarHeight + 12),
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.mic_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _voiceLast.isEmpty
                              ? 'Say: speed 15, difficulty 0.8, timescale 1.2'
                              : _voiceLast,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _toggleVoice,
                        child: Text(
                          'Stop',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TouchKey extends StatefulWidget {
  final String label;
  final Widget? child;
  final Future<void> Function() onDown;
  final Future<void> Function() onUp;
  final double size;
  final bool haptic;
  final _ControllerSkin skin;
  final _TouchKeyShape forceShape;

  const _TouchKey({
    super.key,
    required this.label,
    this.child,
    required this.onDown,
    required this.onUp,
    this.size = 62,
    this.haptic = false,
    this.skin = _ControllerSkin.arcade,
    this.forceShape = _TouchKeyShape.auto,
  });

  @override
  State<_TouchKey> createState() => _TouchKeyState();
}

class _TouchKeyState extends State<_TouchKey> {
  bool _pressed = false;

  Future<void> _setPressed(bool v) async {
    if (!mounted) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color accent() {
      switch (widget.skin) {
        case _ControllerSkin.xbox:
          return const Color(0xFF22C55E);
        case _ControllerSkin.playstation:
          return const Color(0xFF3B82F6);
        case _ControllerSkin.nintendo:
          return const Color(0xFFEF4444);
        case _ControllerSkin.arcade:
          return cs.primary;
      }
    }

    final a = accent();
    final bg = cs.surface.withOpacity(_pressed ? 0.96 : 0.84);
    final autoShape = (widget.skin == _ControllerSkin.arcade)
        ? BoxShape.circle
        : BoxShape.rectangle;
    final shape = (widget.forceShape == _TouchKeyShape.auto)
        ? autoShape
        : (widget.forceShape == _TouchKeyShape.circle
              ? BoxShape.circle
              : BoxShape.rectangle);
    final radius = (shape == BoxShape.circle)
        ? null
        : BorderRadius.circular(
            widget.forceShape == _TouchKeyShape.roundedRect ? 22 : 18,
          );
    final borderColor = _pressed
        ? a.withOpacity(0.55)
        : cs.onSurface.withOpacity(0.12);

    return Listener(
      onPointerDown: (_) async {
        if (_pressed) return;
        await _setPressed(true);
        if (widget.haptic) {
          try {
            if (widget.skin == _ControllerSkin.arcade) {
              await HapticFeedback.selectionClick();
            } else {
              await HapticFeedback.mediumImpact();
            }
          } catch (_) {}
        }
        await widget.onDown();
      },
      onPointerUp: (_) async {
        if (!_pressed) return;
        await widget.onUp();
        await _setPressed(false);
      },
      onPointerCancel: (_) async {
        if (!_pressed) return;
        await widget.onUp();
        await _setPressed(false);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: (shape == BoxShape.circle)
              ? BorderRadius.circular(999)
              : (radius ?? BorderRadius.circular(18)),
          child: Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              shape: shape,
              borderRadius: radius,
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
                if (_pressed)
                  BoxShadow(
                    color: a.withOpacity(0.20),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(_pressed ? 0.08 : 0.14),
                          Colors.transparent,
                          Colors.black.withOpacity(_pressed ? 0.16 : 0.22),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  right: 6,
                  height: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.22),
                          Colors.white.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: IconTheme(
                    data: IconThemeData(color: cs.onSurface),
                    child:
                        widget.child ??
                        Text(
                          widget.label,
                          style: AppTypography.subtitle1.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControllerShell extends StatelessWidget {
  final Color accent;
  final Widget child;

  const _ControllerShell({required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shell = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            cs.surface.withOpacity(0.52),
            cs.surfaceContainerHighest.withOpacity(0.38),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 26,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: accent.withOpacity(0.10),
            blurRadius: 40,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          Widget stick({required Alignment a, required double size}) {
            return Align(
              alignment: a,
              child: IgnorePointer(
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.18),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: accent.withOpacity(0.12),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: size * 0.42,
                      height: size * 0.42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.14),
                            Colors.black.withOpacity(0.22),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [accent.withOpacity(0.10), Colors.transparent],
                        radius: 1.1,
                        center: const Alignment(0.65, -0.65),
                      ),
                    ),
                  ),
                ),
              ),
              stick(a: const Alignment(-0.82, 0.70), size: 40),
              stick(a: const Alignment(0.82, 0.70), size: 40),
              Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: c.maxWidth),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Transform.scale(
                      scale: 0.92,
                      child: Opacity(opacity: 0.94, child: child),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    final shouldAvoidBlur = defaultTargetPlatform == TargetPlatform.iOS;
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: shouldAvoidBlur
          ? shell
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: shell,
            ),
    );
  }
}

enum _TouchKeyShape { auto, circle, roundedRect }

class _FaceSpec {
  final String label;
  final Color fillA;
  final Color fillB;

  const _FaceSpec({
    required this.label,
    required this.fillA,
    required this.fillB,
  });

  _FaceSpec copyWith({String? labelOverride, Color? fillA, Color? fillB}) {
    return _FaceSpec(
      label: (labelOverride ?? label),
      fillA: fillA ?? this.fillA,
      fillB: fillB ?? this.fillB,
    );
  }
}

class _FaceButtonFace extends StatelessWidget {
  final _FaceSpec spec;
  final double pressedT;

  const _FaceButtonFace({required this.spec, required this.pressedT});

  @override
  Widget build(BuildContext context) {
    final t = pressedT.clamp(0.0, 1.0);
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Color.lerp(spec.fillA, Colors.white, 0.06 + t * 0.04)!,
            Color.lerp(spec.fillB, Colors.black, 0.10 + t * 0.06)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: spec.fillA.withOpacity(0.24),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Text(
        spec.label,
        style: AppTypography.subtitle1.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }
}

class _DpadCross extends StatelessWidget {
  final Color accent;
  final double glow;
  final _ControllerSkin skin;
  final Future<void> Function() onUpDown;
  final Future<void> Function() onUpUp;
  final Future<void> Function() onLeftDown;
  final Future<void> Function() onLeftUp;
  final Future<void> Function() onDownDown;
  final Future<void> Function() onDownUp;
  final Future<void> Function() onRightDown;
  final Future<void> Function() onRightUp;

  const _DpadCross({
    required this.accent,
    required this.glow,
    required this.skin,
    required this.onUpDown,
    required this.onUpUp,
    required this.onLeftDown,
    required this.onLeftUp,
    required this.onDownDown,
    required this.onDownUp,
    required this.onRightDown,
    required this.onRightUp,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final plate = cs.surface.withOpacity(0.58);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [plate, cs.surface.withOpacity(0.42)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withOpacity(0.26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: accent.withOpacity(glow),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TouchKey(
            label: 'Up',
            child: const Icon(Icons.keyboard_arrow_up_rounded, size: 26),
            size: 56,
            haptic: true,
            skin: skin,
            forceShape: _TouchKeyShape.roundedRect,
            onDown: onUpDown,
            onUp: onUpUp,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TouchKey(
                label: 'Left',
                child: const Icon(Icons.chevron_left_rounded, size: 26),
                size: 56,
                haptic: true,
                skin: skin,
                forceShape: _TouchKeyShape.roundedRect,
                onDown: onLeftDown,
                onUp: onLeftUp,
              ),
              const SizedBox(width: 8),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.onSurface.withOpacity(0.12),
                  border: Border.all(color: accent.withOpacity(0.18)),
                ),
              ),
              const SizedBox(width: 8),
              _TouchKey(
                label: 'Right',
                child: const Icon(Icons.chevron_right_rounded, size: 26),
                size: 56,
                haptic: true,
                skin: skin,
                forceShape: _TouchKeyShape.roundedRect,
                onDown: onRightDown,
                onUp: onRightUp,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _TouchKey(
            label: 'Down',
            child: const Icon(Icons.keyboard_arrow_down_rounded, size: 26),
            size: 56,
            haptic: true,
            skin: skin,
            forceShape: _TouchKeyShape.roundedRect,
            onDown: onDownDown,
            onUp: onDownUp,
          ),
        ],
      ),
    );
  }
}

class _GhostPlayer {
  final String userId;
  final Color color;
  Offset pos;
  Offset renderPos = Offset.zero;
  Offset vel = Offset.zero;
  bool left = false;
  bool right = false;
  bool jumpQueued = false;
  int lastInputAtMs = 0;
  final List<Offset> trail = <Offset>[];

  final List<_GhostEmote> emotes = <_GhostEmote>[];

  _GhostPlayer({required this.userId, required this.color, required this.pos}) {
    lastInputAtMs = DateTime.now().millisecondsSinceEpoch;
    trail.add(pos);
    renderPos = pos;
  }

  String get shortLabel {
    final t = userId.trim();
    if (t.isEmpty) return '?';
    return (t.length <= 2 ? t : t.substring(0, 2)).toUpperCase();
  }

  void step(double dt) {
    final speed = 0.55;
    final gravity = 1.65;
    final jump = 0.85;
    final friction = 0.90;

    var vx = vel.dx;
    var vy = vel.dy;

    if (left && !right) vx = -speed;
    if (right && !left) vx = speed;
    if (!left && !right) vx *= friction;

    vy += gravity * dt;

    if (jumpQueued) {
      jumpQueued = false;
      if (pos.dy >= 0.88) {
        vy = -jump;
      }
    }

    var nx = (pos.dx + vx * dt).clamp(0.05, 0.95).toDouble();
    var ny = (pos.dy + vy * dt).clamp(0.10, 0.92).toDouble();

    if (ny >= 0.92) {
      ny = 0.92;
      if (vy > 0) vy = 0;
    }

    pos = Offset(nx, ny);
    vel = Offset(vx, vy);

    final lerpT = (dt * 14).clamp(0.0, 1.0);
    renderPos = Offset(
      renderPos.dx + (pos.dx - renderPos.dx) * lerpT,
      renderPos.dy + (pos.dy - renderPos.dy) * lerpT,
    );

    trail.add(pos);
    if (trail.length > 22) {
      trail.removeRange(0, trail.length - 22);
    }

    emotes.removeWhere(
      (e) => DateTime.now().millisecondsSinceEpoch - e.tsMs > 1600,
    );
  }

  void pushEmote(String emoji) {
    final e = emoji.trim();
    if (e.isEmpty) return;
    emotes.add(
      _GhostEmote(emoji: e, tsMs: DateTime.now().millisecondsSinceEpoch),
    );
    if (emotes.length > 3) {
      emotes.removeRange(0, emotes.length - 3);
    }
  }
}

class _GhostAvatar extends StatelessWidget {
  final Color color;
  final String label;
  final List<_GhostEmote> emotes;

  const _GhostAvatar({
    required this.color,
    required this.label,
    required this.emotes,
  });

  @override
  Widget build(BuildContext context) {
    final last = emotes.isNotEmpty ? emotes.last.emoji : '';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withOpacity(0.95),
                color.withOpacity(0.35),
                color.withOpacity(0.10),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.55),
                blurRadius: 18,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
        if (last.isNotEmpty)
          Positioned(
            top: -18,
            left: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.38),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Text(
                last,
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GhostEmote {
  final String emoji;
  final int tsMs;
  const _GhostEmote({required this.emoji, required this.tsMs});
}

class _MpFeedItem {
  final String text;
  final int tsMs;
  const _MpFeedItem({required this.text, required this.tsMs});
}

class _GhostTrailPainter extends CustomPainter {
  final List<_GhostPlayer> players;
  final Size sizePx;

  _GhostTrailPainter({required this.players, required this.sizePx});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in players) {
      final pts = p.trail;
      if (pts.length < 2) continue;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      for (var i = 1; i < pts.length; i++) {
        final a = pts[i - 1];
        final b = pts[i];
        final t = i / pts.length;
        paint
          ..strokeWidth = (2.5 + t * 3.5)
          ..color = p.color.withOpacity(0.08 + t * 0.22);

        final ax = a.dx * size.width;
        final ay = a.dy * size.height;
        final bx = b.dx * size.width;
        final by = b.dy * size.height;
        canvas.drawLine(Offset(ax, ay), Offset(bx, by), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GhostTrailPainter oldDelegate) {
    return true;
  }
}

enum _ControllerSkin { arcade, xbox, playstation, nintendo }
