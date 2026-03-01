import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/services/projects_service.dart';
import '../../widgets/widgets.dart';

class PlayWebglScreen extends StatefulWidget {
  final String url;

  const PlayWebglScreen({
    super.key,
    required this.url,
  });

  @override
  State<PlayWebglScreen> createState() => _PlayWebglScreenState();
}

class _PlayWebglScreenState extends State<PlayWebglScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  String? _projectId;
  bool _openingSettings = false;
  bool _isFullscreen = false;

  Timer? _liveApplyDebounce;
  Timer? _liveApplyingClear;
  bool _liveApplying = false;

  bool _bridgeChecked = false;

  static const _kPrefPlayerSkinPrefix = 'gameforge.playerSkin.';
  static const _kPrefPlayerSpriteUrlPrefix = 'gameforge.playerSpriteUrl.';
  static const _kPrefForceReloadPrefix = 'gameforge.forceReloadGameplay.';

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

  void _setLiveApplying() {
    if (!mounted) return;
    setState(() => _liveApplying = true);
    _liveApplyingClear?.cancel();
    _liveApplyingClear = Timer(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      setState(() => _liveApplying = false);
    });
  }

  Future<void> _toggleFullscreen() async {
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
      _isFullscreen = !_isFullscreen;
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
    final res = await ProjectsService.getProjectRuntimeConfig(token: token, projectId: pid);
    final data = res['data'];
    if (res['success'] == true && data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
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
      AppNotifier.showError('Missing projectId in WebGL URL');
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
      if (playerSkinId != null && playerSkinId.trim().isNotEmpty) 'playerSkinId': playerSkinId.trim(),
      if (playerSpriteUrl != null && playerSpriteUrl.trim().isNotEmpty) 'playerSpriteUrl': playerSpriteUrl.trim(),
      'ts': DateTime.now().millisecondsSinceEpoch,
    };

    final json = jsonEncode(payload);
    await _runJs(
      """
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
      """,
    );
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
    double speed = (cfg?['speed'] is num) ? (cfg!['speed'] as num).toDouble() : 7.0;
    double timeScale = (cfg?['timeScale'] is num) ? (cfg!['timeScale'] as num).toDouble() : 1.0;
    double difficulty = (cfg?['difficulty'] is num) ? (cfg!['difficulty'] as num).toDouble() : 0.5;
    final themeCtrl = TextEditingController(text: (cfg?['theme']?.toString() ?? 'default'));
    final notesCtrl = TextEditingController(text: (cfg?['notes']?.toString() ?? ''));
    final genreCtrl = TextEditingController(text: (cfg?['genre']?.toString() ?? 'platformer'));
    final assetsTypeCtrl = TextEditingController(text: (cfg?['assetsType']?.toString() ?? 'lowpoly'));
    final mechanicsCtrl = TextEditingController(
      text: (cfg?['mechanics'] is List) ? (cfg!['mechanics'] as List).map((e) => e?.toString() ?? '').where((e) => e.trim().isNotEmpty).join(', ') : '',
    );
    String primary = (cfg?['primaryColor']?.toString() ?? '#22C55E');
    String secondary = (cfg?['secondaryColor']?.toString() ?? '#3B82F6');
    String accent = (cfg?['accentColor']?.toString() ?? '#F59E0B');
    String playerColor = (cfg?['playerColor']?.toString() ?? accent);

    bool fogEnabled = (cfg?['fogEnabled'] is bool) ? (cfg!['fogEnabled'] as bool) : false;
    double fogDensity = (cfg?['fogDensity'] is num) ? (cfg!['fogDensity'] as num).toDouble() : 0.0;
    double cameraZoom = (cfg?['cameraZoom'] is num) ? (cfg!['cameraZoom'] as num).toDouble() : 1.0;
    double gravityY = (cfg?['gravityY'] is num) ? (cfg!['gravityY'] as num).toDouble() : 0.0;
    double jumpForce = (cfg?['jumpForce'] is num) ? (cfg!['jumpForce'] as num).toDouble() : 0.0;

    final primaryCtrl = TextEditingController(text: primary);
    final secondaryCtrl = TextEditingController(text: secondary);
    final accentCtrl = TextEditingController(text: accent);
    final playerCtrl = TextEditingController(text: playerColor);

    String playerSkinId = 'default';
    final spriteUrlCtrl = TextEditingController();

    bool forceReloadGameplay = true;

    final pid = _projectId;
    if (pid != null && pid.trim().isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        playerSkinId = (prefs.getString('$_kPrefPlayerSkinPrefix$pid') ?? playerSkinId).trim();
        spriteUrlCtrl.text = (prefs.getString('$_kPrefPlayerSpriteUrlPrefix$pid') ?? '').trim();
        forceReloadGameplay = prefs.getBool('$_kPrefForceReloadPrefix$pid') ?? true;
        if (playerSkinId.isEmpty) playerSkinId = 'default';
      } catch (_) {}
    }

    int tabIndex = 0;
    final history = <Map<String, dynamic>>[];

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.large)),
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
          final initial = _parseHexToColor(ctrl.text) ?? Theme.of(context).colorScheme.primary;
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
          {'name': 'Chill', 'speed': 4.0, 'difficulty': 0.30, 'timeScale': 0.90},
          {'name': 'Normal', 'speed': 7.0, 'difficulty': 0.50, 'timeScale': 1.00},
          {'name': 'Hardcore', 'speed': 12.0, 'difficulty': 0.85, 'timeScale': 1.10},
        ];
        final colorPresets = <Map<String, String>>[
          {'name': 'Neon', 'primary': '#22C55E', 'secondary': '#3B82F6', 'accent': '#F59E0B'},
          {'name': 'Cyber', 'primary': '#00E5FF', 'secondary': '#7C4DFF', 'accent': '#FF1744'},
          {'name': 'Pastel', 'primary': '#A7F3D0', 'secondary': '#BFDBFE', 'accent': '#FBCFE8'},
          {'name': 'Dark', 'primary': '#111827', 'secondary': '#1F2937', 'accent': '#F59E0B'},
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
            child: Text(t, style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w800)),
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
            child: Text(t, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w800)),
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
            final originalPlayerColor = (cfg?['playerColor']?.toString() ?? accent).trim();

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
              _liveApplyDebounce = Timer(const Duration(milliseconds: 220), () async {
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
                    secondaryColor: _normHex(secondaryCtrl.text) ?? '#3B82F6',
                    accentColor: _normHex(accentCtrl.text) ?? '#F59E0B',
                    playerColor: _normHex(playerCtrl.text) ?? (_normHex(accentCtrl.text) ?? '#F59E0B'),
                    fogEnabled: fogEnabled,
                    fogDensity: fogDensity.clamp(0.0, 0.1),
                    cameraZoom: cameraZoom.clamp(0.0, 30.0),
                    gravityY: gravityY.clamp(-50.0, 0.0),
                    jumpForce: jumpForce.clamp(0.0, 50.0),
                    playerSkinId: playerSkinId,
                    playerSpriteUrl: spriteUrlCtrl.text.trim(),
                    reloadWebView: reload,
                  );
                } catch (_) {}
              });
            }

            Future<void> doUndo() async {
              if (saving) return;
              if (history.isEmpty) return;
              final last = history.removeLast();
              setSheetState(() {
                speed = (last['speed'] as num?)?.toDouble() ?? speed;
                primaryCtrl.text = (last['primary']?.toString() ?? primaryCtrl.text);
                secondaryCtrl.text = (last['secondary']?.toString() ?? secondaryCtrl.text);
                accentCtrl.text = (last['accent']?.toString() ?? accentCtrl.text);
                playerCtrl.text = (last['player']?.toString() ?? playerCtrl.text);
                fogEnabled = (last['fogEnabled'] as bool?) ?? fogEnabled;
                fogDensity = (last['fogDensity'] as num?)?.toDouble() ?? fogDensity;
                cameraZoom = (last['cameraZoom'] as num?)?.toDouble() ?? cameraZoom;
                gravityY = (last['gravityY'] as num?)?.toDouble() ?? gravityY;
                jumpForce = (last['jumpForce'] as num?)?.toDouble() ?? jumpForce;
              });
              await scheduleLiveApply(reload: false);
            }

            Future<void> doReset() async {
              if (saving) return;
              pushHistorySnapshot();
              setSheetState(() {
                speed = (cfg?['speed'] is num) ? (cfg!['speed'] as num).toDouble() : 7.0;
                timeScale = (cfg?['timeScale'] is num) ? (cfg!['timeScale'] as num).toDouble() : 1.0;
                difficulty = (cfg?['difficulty'] is num) ? (cfg!['difficulty'] as num).toDouble() : 0.5;
                themeCtrl.text = (cfg?['theme']?.toString() ?? 'default');
                notesCtrl.text = (cfg?['notes']?.toString() ?? '');
                genreCtrl.text = (cfg?['genre']?.toString() ?? 'platformer');
                assetsTypeCtrl.text = (cfg?['assetsType']?.toString() ?? 'lowpoly');
                mechanicsCtrl.text = (cfg?['mechanics'] is List)
                    ? (cfg!['mechanics'] as List).map((e) => e?.toString() ?? '').where((e) => e.trim().isNotEmpty).join(', ')
                    : '';
                primaryCtrl.text = (cfg?['primaryColor']?.toString() ?? '#22C55E');
                secondaryCtrl.text = (cfg?['secondaryColor']?.toString() ?? '#3B82F6');
                accentCtrl.text = (cfg?['accentColor']?.toString() ?? '#F59E0B');
                playerCtrl.text = (cfg?['playerColor']?.toString() ?? accentCtrl.text);
                fogEnabled = (cfg?['fogEnabled'] is bool) ? (cfg!['fogEnabled'] as bool) : false;
                fogDensity = (cfg?['fogDensity'] is num) ? (cfg!['fogDensity'] as num).toDouble() : 0.0;
                cameraZoom = (cfg?['cameraZoom'] is num) ? (cfg!['cameraZoom'] as num).toDouble() : 0.0;
                gravityY = (cfg?['gravityY'] is num) ? (cfg!['gravityY'] as num).toDouble() : 0.0;
                jumpForce = (cfg?['jumpForce'] is num) ? (cfg!['jumpForce'] as num).toDouble() : 0.0;
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
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
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
                  await prefs.setString('$_kPrefPlayerSkinPrefix$pid', playerSkinId);
                  await prefs.setString('$_kPrefPlayerSpriteUrlPrefix$pid', spriteUrlCtrl.text.trim());
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
                  playerColor: _normHex(playerCtrl.text) ?? (_normHex(accentCtrl.text) ?? '#F59E0B'),
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
                  playerColor: _normHex(playerColor) ?? (_normHex(accent) ?? '#F59E0B'),
                  fogEnabled: fogEnabled,
                  fogDensity: fogDensity.clamp(0.0, 0.1),
                  cameraZoom: cameraZoom.clamp(0.0, 30.0),
                  gravityY: gravityY.clamp(-50.0, 0.0),
                  jumpForce: jumpForce.clamp(0.0, 50.0),
                  playerSkinId: playerSkinId,
                  playerSpriteUrl: spriteUrlCtrl.text,
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
                if (!closing && context.mounted) setSheetState(() => saving = false);
              }
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: AppSpacing.lg,
                  bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
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
                            child: Text('Game Controls', style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w900)),
                          ),
                          if (_liveApplying)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Applying…', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Undo',
                            onPressed: (saving || history.isEmpty) ? null : () => doUndo(),
                            icon: const Icon(Icons.undo_rounded),
                          ),
                          IconButton(
                            tooltip: 'Reset',
                            onPressed: saving ? null : () => doReset(),
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                          IconButton(
                            onPressed: saving ? null : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'These values update the runtime-config. Rebuild is needed only the first time after adding new bootstrap changes.',
                        style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, height: 1.35),
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
                                onSelected: saving ? null : (_) => setSheetState(() => tabIndex = 0),
                              ),
                              const SizedBox(width: 10),
                              ChoiceChip(
                                selected: tabIndex == 1,
                                label: const Text('Gameplay'),
                                onSelected: saving ? null : (_) => setSheetState(() => tabIndex = 1),
                              ),
                              const SizedBox(width: 10),
                              ChoiceChip(
                                selected: tabIndex == 2,
                                label: const Text('Look'),
                                onSelected: saving ? null : (_) => setSheetState(() => tabIndex = 2),
                              ),
                              const SizedBox(width: 10),
                              ChoiceChip(
                                selected: tabIndex == 3,
                                label: const Text('World'),
                                onSelected: saving ? null : (_) => setSheetState(() => tabIndex = 3),
                              ),
                              const SizedBox(width: 10),
                              ChoiceChip(
                                selected: tabIndex == 4,
                                label: const Text('Physics'),
                                onSelected: saving ? null : (_) => setSheetState(() => tabIndex = 4),
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
                              position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim),
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
                                        children: characterStylePresets
                                            .map((p) {
                                              final id = (p['id']?.toString() ?? '').trim();
                                              final name = p['name']?.toString() ?? 'Style';
                                              final hex = p['player']?.toString() ?? '';
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
                                                        await previewPlayerAssets(nextSkinId: id);
                                                        await previewPlayerStyle(hex);
                                                      },
                                              );
                                            })
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  sectionTitle('Custom sprite URL'),
                                  sectionCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Optional: provide a hosted image/spritesheet URL. The game runtime must support reading playerSpriteUrl.',
                                          style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, height: 1.35),
                                        ),
                                        const SizedBox(height: 10),
                                        TextField(
                                          controller: spriteUrlCtrl,
                                          enabled: !saving,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            hintText: 'https://.../player.png',
                                          ),
                                          onChanged: saving
                                              ? null
                                              : (_) {
                                                  scheduleLiveApply(reload: false);
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Force reload for gameplay changes',
                                                style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800),
                                              ),
                                            ),
                                            Switch(
                                              value: forceReloadGameplay,
                                              onChanged: saving
                                                  ? null
                                                  : (v) async {
                                                      setSheetState(() => forceReloadGameplay = v);
                                                      final pid = _projectId;
                                                      if (pid != null && pid.trim().isNotEmpty) {
                                                        try {
                                                          final prefs = await SharedPreferences.getInstance();
                                                          await prefs.setBool('$_kPrefForceReloadPrefix$pid', v);
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
                                              child: TextField(
                                                controller: playerCtrl,
                                                enabled: !saving,
                                                decoration: const InputDecoration(
                                                  labelText: 'Player color (#RRGGBB)',
                                                  isDense: true,
                                                ),
                                                onChanged: saving
                                                    ? null
                                                    : (v) {
                                                        pushHistorySnapshot();
                                                        setSheetState(() => playerColor = v);
                                                        scheduleLiveApply(reload: true);
                                                      },
                                              ),
                                            ),
                                            const SizedBox(width: AppSpacing.sm),
                                            colorDot(playerCtrl.text),
                                            const SizedBox(width: 6),
                                            IconButton(
                                              tooltip: 'Paste',
                                              onPressed: saving
                                                  ? null
                                                  : () async {
                                                      pushHistorySnapshot();
                                                      await pasteHexInto(playerCtrl);
                                                      setSheetState(() => playerColor = playerCtrl.text);
                                                      scheduleLiveApply(reload: true);
                                                    },
                                              icon: const Icon(Icons.content_paste_rounded, size: 18),
                                            ),
                                            IconButton(
                                              tooltip: 'Pick',
                                              onPressed: saving
                                                  ? null
                                                  : () async {
                                                      pushHistorySnapshot();
                                                      await pickColorFor(playerCtrl);
                                                      setSheetState(() => playerColor = playerCtrl.text);
                                                      scheduleLiveApply(reload: true);
                                                    },
                                              icon: const Icon(Icons.color_lens_rounded, size: 18),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(child: Text('Speed', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800))),
                                            valuePill(speed.toStringAsFixed(1)),
                                          ],
                                        ),
                                        Slider(
                                          value: speed.clamp(1.0, 2.0),
                                          min: 1.0,
                                          max: 2.0,
                                          divisions: 100,
                                          onChanged: saving
                                            ? null
                                            : (v) {
                                                pushHistorySnapshot();
                                                setSheetState(() => speed = v);
                                                scheduleLiveApply(reload: true);
                                              },
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Time scale',
                                                style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800),
                                              ),
                                            ),
                                            valuePill(timeScale.toStringAsFixed(2)),
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
                                                  setSheetState(() => timeScale = v);
                                                  scheduleLiveApply(reload: true);
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            children: colorPresets
                                                .map((p) {
                                                  final name = p['name'] ?? 'Preset';
                                                  final selected =
                                                      _normHex(primaryCtrl.text) == _normHex(p['primary']) &&
                                                      _normHex(secondaryCtrl.text) == _normHex(p['secondary']) &&
                                                      _normHex(accentCtrl.text) == _normHex(p['accent']);
                                                  return ChoiceChip(
                                                    selected: selected,
                                                    label: Text(name),
                                                    onSelected: saving
                                                        ? null
                                                        : (_) {
                                                            pushHistorySnapshot();
                                                            setSheetState(() {
                                                              primaryCtrl.text = p['primary'] ?? primaryCtrl.text;
                                                              secondaryCtrl.text = p['secondary'] ?? secondaryCtrl.text;
                                                              accentCtrl.text = p['accent'] ?? accentCtrl.text;
                                                            });
                                                            scheduleLiveApply(reload: false);
                                                          },
                                                  );
                                                })
                                                .toList(),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(child: Text('Primary', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800))),
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
                                                        scheduleLiveApply(reload: false);
                                                      },
                                                decoration: const InputDecoration(isDense: true, hintText: '#RRGGBB'),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            IconButton(
                                              tooltip: 'Paste',
                                              onPressed: saving
                                                  ? null
                                                  : () async {
                                                      pushHistorySnapshot();
                                                      await pasteHexInto(primaryCtrl);
                                                      setSheetState(() {});
                                                      scheduleLiveApply(reload: false);
                                                    },
                                              icon: const Icon(Icons.content_paste_rounded, size: 18),
                                            ),
                                            IconButton(
                                              tooltip: 'Pick',
                                              onPressed: saving
                                                  ? null
                                                  : () async {
                                                      pushHistorySnapshot();
                                                      await pickColorFor(primaryCtrl);
                                                      setSheetState(() {});
                                                      scheduleLiveApply(reload: false);
                                                    },
                                              icon: const Icon(Icons.color_lens_rounded, size: 18),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(child: Text('Secondary', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800))),
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
                                                        scheduleLiveApply(reload: false);
                                                      },
                                                decoration: const InputDecoration(isDense: true, hintText: '#RRGGBB'),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            IconButton(
                                              tooltip: 'Paste',
                                              onPressed: saving
                                                  ? null
                                                  : () async {
                                                      pushHistorySnapshot();
                                                      await pasteHexInto(secondaryCtrl);
                                                      setSheetState(() {});
                                                      scheduleLiveApply(reload: false);
                                                    },
                                              icon: const Icon(Icons.content_paste_rounded, size: 18),
                                            ),
                                            IconButton(
                                              tooltip: 'Pick',
                                              onPressed: saving
                                                  ? null
                                                  : () async {
                                                      pushHistorySnapshot();
                                                      await pickColorFor(secondaryCtrl);
                                                      setSheetState(() {});
                                                      scheduleLiveApply(reload: false);
                                                    },
                                              icon: const Icon(Icons.color_lens_rounded, size: 18),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(child: Text('Accent', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800))),
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
                                                        scheduleLiveApply(reload: false);
                                                      },
                                                decoration: const InputDecoration(isDense: true, hintText: '#RRGGBB'),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            IconButton(
                                              tooltip: 'Paste',
                                              onPressed: saving
                                                  ? null
                                                  : () async {
                                                      pushHistorySnapshot();
                                                      await pasteHexInto(accentCtrl);
                                                      setSheetState(() {});
                                                      scheduleLiveApply(reload: false);
                                                    },
                                              icon: const Icon(Icons.content_paste_rounded, size: 18),
                                            ),
                                            IconButton(
                                              tooltip: 'Pick',
                                              onPressed: saving
                                                  ? null
                                                  : () async {
                                                      pushHistorySnapshot();
                                                      await pickColorFor(accentCtrl);
                                                      setSheetState(() {});
                                                      scheduleLiveApply(reload: false);
                                                    },
                                              icon: const Icon(Icons.color_lens_rounded, size: 18),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(child: Text('Fog', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800))),
                                            Switch(
                                              value: fogEnabled,
                                              onChanged: saving
                                                  ? null
                                                  : (v) {
                                                      pushHistorySnapshot();
                                                      setSheetState(() => fogEnabled = v);
                                                      scheduleLiveApply(reload: false);
                                                    },
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Expanded(child: Text('Fog density', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800))),
                                            valuePill(fogDensity.toStringAsFixed(4)),
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
                                                  setSheetState(() => fogDensity = v);
                                                  scheduleLiveApply(reload: false);
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: Text('Camera zoom', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800))),
                                          valuePill(cameraZoom <= 0 ? 'auto' : cameraZoom.toStringAsFixed(1)),
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
                                                setSheetState(() => cameraZoom = v);
                                                scheduleLiveApply(reload: false);
                                              },
                                      ),
                                      Row(
                                        children: [
                                          Expanded(child: Text('Gravity Y', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800))),
                                          valuePill(gravityY == 0 ? 'default' : gravityY.toStringAsFixed(1)),
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
                                                setSheetState(() => gravityY = v);
                                                scheduleLiveApply(reload: false);
                                              },
                                      ),
                                      Row(
                                        children: [
                                          Expanded(child: Text('Jump force', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800))),
                                          valuePill(jumpForce == 0 ? 'default' : jumpForce.toStringAsFixed(1)),
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
                                                setSheetState(() => jumpForce = v);
                                                scheduleLiveApply(reload: false);
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
      });
    }
  }

  Future<void> _runJs(String js) async {
    try {
      await _controller.runJavaScript(js);
    } catch (_) {}
  }

  Future<Object?> _runJsResult(String js) async {
    try {
      return await _controller.runJavaScriptReturningResult(js);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _detectBridgeSupport() async {
    final res = await _runJsResult(
      """
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
      """,
    );

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

  Future<void> _sendKey({required String key, required String code, required bool down}) async {
    final type = down ? 'keydown' : 'keyup';
    await _runJs(
      """
      (function(){
        try {
          var e = new KeyboardEvent('$type', {key: '$key', code: '$code', keyCode: 0, which: 0, bubbles: true});
          (document.activeElement || document.body).dispatchEvent(e);
          window.dispatchEvent(e);
        } catch (err) {}
      })();
      """,
    );
  }

  Future<void> _releaseAllKeys() async {
    await _sendKey(key: 'ArrowLeft', code: 'ArrowLeft', down: false);
    await _sendKey(key: 'a', code: 'KeyA', down: false);
    await _sendKey(key: 'ArrowRight', code: 'ArrowRight', down: false);
    await _sendKey(key: 'd', code: 'KeyD', down: false);
    await _sendKey(key: ' ', code: 'Space', down: false);
    await _sendKey(key: 'w', code: 'KeyW', down: false);
    await _sendKey(key: 'ArrowUp', code: 'ArrowUp', down: false);
  }

  Future<void> _ensureGameFocus() async {
    await _runJs(
      """
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
      """,
    );
  }

  @override
  void initState() {
    super.initState();

    _projectId = _extractProjectId(widget.url);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
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
            () async {
              try {
                final cfg = await _fetchRuntimeConfig();
                if (cfg == null) return;
                await _pushRuntimeConfigToWebView(
                  speed: (cfg['speed'] is num) ? (cfg['speed'] as num).toDouble() : 7.0,
                  timeScale: (cfg['timeScale'] is num) ? (cfg['timeScale'] as num).toDouble() : 1.0,
                  difficulty: (cfg['difficulty'] is num) ? (cfg['difficulty'] as num).toDouble() : 0.5,
                  theme: (cfg['theme']?.toString() ?? 'default'),
                  notes: (cfg['notes']?.toString() ?? ''),
                  genre: (cfg['genre']?.toString() ?? 'platformer'),
                  assetsType: (cfg['assetsType']?.toString() ?? 'lowpoly'),
                  mechanics: (cfg['mechanics'] is List)
                      ? (cfg['mechanics'] as List).map((e) => e?.toString() ?? '').where((e) => e.trim().isNotEmpty).toList()
                      : const <String>[],
                  primaryColor: (cfg['primaryColor']?.toString() ?? '#22C55E'),
                  secondaryColor: (cfg['secondaryColor']?.toString() ?? '#3B82F6'),
                  accentColor: (cfg['accentColor']?.toString() ?? '#F59E0B'),
                  playerColor: (cfg['playerColor']?.toString() ?? (cfg['accentColor']?.toString() ?? '#F59E0B')),
                  fogEnabled: (cfg['fogEnabled'] is bool) ? (cfg['fogEnabled'] as bool) : false,
                  fogDensity: (cfg['fogDensity'] is num) ? (cfg['fogDensity'] as num).toDouble() : 0.0,
                  cameraZoom: (cfg['cameraZoom'] is num) ? (cfg['cameraZoom'] as num).toDouble() : 0.0,
                  gravityY: (cfg['gravityY'] is num) ? (cfg['gravityY'] as num).toDouble() : 0.0,
                  jumpForce: (cfg['jumpForce'] is num) ? (cfg['jumpForce'] as num).toDouble() : 0.0,
                  playerSkinId: cfg['playerSkinId']?.toString(),
                  playerSpriteUrl: cfg['playerSpriteUrl']?.toString(),
                );
                await _checkBridgeSupportOnce();
              } catch (_) {}
            }();
          },
          onWebResourceError: (err) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = err.description;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(_withCacheBuster(widget.url)));
  }

  @override
  void dispose() {
    _releaseAllKeys();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            _releaseAllKeys();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
        ),
        title: Text('Play', style: AppTypography.subtitle1),
        actions: [
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.url));
              if (!context.mounted) return;
              AppNotifier.showSuccess('Link copied');
            },
            icon: const Icon(Icons.link_rounded),
          ),
          IconButton(
            onPressed: _openingSettings ? null : _openSettingsDrawer,
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            onPressed: _toggleFullscreen,
            icon: Icon(_isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
          ),
          IconButton(
            onPressed: () async {
              try {
                await _controller.loadRequest(Uri.parse(_withCacheBuster(widget.url)));
              } catch (_) {}
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (!_loading && _error == null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                minimum: const EdgeInsets.all(AppSpacing.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: cs.surface.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.onSurface.withOpacity(0.10)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TouchKey(
                        label: 'Left',
                        size: 62,
                        haptic: true,
                        onDown: () async {
                          await _ensureGameFocus();
                          await _sendKey(key: 'ArrowLeft', code: 'ArrowLeft', down: true);
                          await _sendKey(key: 'a', code: 'KeyA', down: true);
                        },
                        onUp: () async {
                          await _sendKey(key: 'ArrowLeft', code: 'ArrowLeft', down: false);
                          await _sendKey(key: 'a', code: 'KeyA', down: false);
                        },
                        child: const Icon(Icons.chevron_left_rounded, size: 28),
                      ),
                      const SizedBox(width: 10),
                      _TouchKey(
                        label: 'Jump',
                        size: 62,
                        haptic: true,
                        onDown: () async {
                          await _ensureGameFocus();
                          await _sendKey(key: ' ', code: 'Space', down: true);
                          await _sendKey(key: 'w', code: 'KeyW', down: true);
                          await _sendKey(key: 'ArrowUp', code: 'ArrowUp', down: true);
                        },
                        onUp: () async {
                          await _sendKey(key: ' ', code: 'Space', down: false);
                          await _sendKey(key: 'w', code: 'KeyW', down: false);
                          await _sendKey(key: 'ArrowUp', code: 'ArrowUp', down: false);
                        },
                        child: const Icon(Icons.keyboard_arrow_up_rounded, size: 28),
                      ),
                      const SizedBox(width: 10),
                      _TouchKey(
                        label: 'Right',
                        size: 62,
                        haptic: true,
                        onDown: () async {
                          await _ensureGameFocus();
                          await _sendKey(key: 'ArrowRight', code: 'ArrowRight', down: true);
                          await _sendKey(key: 'd', code: 'KeyD', down: true);
                        },
                        onUp: () async {
                          await _sendKey(key: 'ArrowRight', code: 'ArrowRight', down: false);
                          await _sendKey(key: 'd', code: 'KeyD', down: false);
                        },
                        child: const Icon(Icons.chevron_right_rounded, size: 28),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(),
            ),
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
                  border: Border.all(color: AppColors.error.withOpacity(0.35)),
                ),
                child: Text(
                  _error!,
                  style: AppTypography.body2.copyWith(color: cs.onSurface),
                ),
              ),
            ),
        ],
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

  const _TouchKey({
    required this.label,
    this.child,
    required this.onDown,
    required this.onUp,
    this.size = 62,
    this.haptic = false,
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
    final bg = cs.surface.withOpacity(_pressed ? 0.96 : 0.84);

    return Listener(
      onPointerDown: (_) async {
        if (_pressed) return;
        await _setPressed(true);
        if (widget.haptic) {
          try {
            await HapticFeedback.selectionClick();
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
        child: Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: cs.onSurface.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: IconTheme(
            data: IconThemeData(color: cs.onSurface),
            child: widget.child ?? Text(widget.label, style: AppTypography.subtitle1.copyWith(color: cs.onSurface)),
          ),
        ),
      ),
    );
  }
}
