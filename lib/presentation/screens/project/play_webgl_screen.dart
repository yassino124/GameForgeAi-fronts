import 'dart:async';
import 'dart:convert';
import 'dart:ui';

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

class _PlayWebglScreenState extends State<PlayWebglScreen> with SingleTickerProviderStateMixin {
  late final WebViewController _controller;

  bool _loading = true;
  String? _error;

  String? _projectId;
  static const _kPrefFpsControlsPrefix = 'gameforge.fpsControlsEnabled.';
  bool _fpsControlsEnabled = false;
  bool _openingSettings = false;
  bool _isFullscreen = false;

  static const _kPrefControllerSkinPrefix = 'gameforge.controllerSkin.';
  _ControllerSkin _controllerSkin = _ControllerSkin.arcade;

  late final AnimationController _hudPulseCtrl;

  bool _liveApplying = false;
  bool _bridgeChecked = false;

  int _lastJsErrAtMs = 0;

  Timer? _liveApplyDebounce;
  Timer? _liveApplyingClear;

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

  Future<void> _loadControllerSkinPref() async {
    final pid = _projectId;
    final k = (pid == null || pid.trim().isEmpty) ? '${_kPrefControllerSkinPrefix}global' : '$_kPrefControllerSkinPrefix$pid';
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(k) ?? '').trim();
      final v = _ControllerSkin.values.where((e) => e.name == raw).cast<_ControllerSkin?>().firstWhere((e) => e != null, orElse: () => null);
      if (!mounted) return;
      setState(() => _controllerSkin = v ?? _ControllerSkin.arcade);
    } catch (_) {}
  }

  Future<void> _saveControllerSkinPref(_ControllerSkin skin) async {
    final pid = _projectId;
    final k = (pid == null || pid.trim().isEmpty) ? '${_kPrefControllerSkinPrefix}global' : '$_kPrefControllerSkinPrefix$pid';
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
        Widget glass({required Widget child}) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
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
              ),
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
                    cs.surfaceContainerHighest.withOpacity(selected ? 0.42 : 0.26),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: selected ? accent.withOpacity(0.70) : cs.outlineVariant.withOpacity(0.50),
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
                        colors: [accent.withOpacity(0.90), accent.withOpacity(0.55)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(color: accent.withOpacity(0.20), blurRadius: 18, offset: const Offset(0, 10)),
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
                                style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            if (selected)
                              Icon(Icons.check_circle_rounded, color: accent, size: 20)
                            else
                              Icon(Icons.circle_outlined, color: cs.onSurface.withOpacity(0.22), size: 20),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800),
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
                          child: Text('Controller', style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w900)),
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
                      style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    card(_ControllerSkin.arcade, Icons.sports_esports_rounded, 'Clean glass + minimal labels'),
                    const SizedBox(height: 12),
                    card(_ControllerSkin.xbox, Icons.gamepad_rounded, 'Neon green — A/B/X/Y vibe'),
                    const SizedBox(height: 12),
                    card(_ControllerSkin.playstation, Icons.videogame_asset_rounded, 'Deep blue — cross/circle vibe'),
                    const SizedBox(height: 12),
                    card(_ControllerSkin.nintendo, Icons.toys_rounded, 'Punchy red — classic handheld vibe'),
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
    final res = await ProjectsService.getProjectRuntimeConfig(token: token, projectId: pid);
    final data = res['data'];
    if (res['success'] == true && data is Map) {
      return Map<String, dynamic>.from(data as Map);
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
    double cameraZoom = (cfg?['cameraZoom'] is num) ? (cfg!['cameraZoom'] as num).toDouble() : 0.0;
    double gravityY = (cfg?['gravityY'] is num) ? (cfg!['gravityY'] as num).toDouble() : 0.0;
    double jumpForce = (cfg?['jumpForce'] is num) ? (cfg!['jumpForce'] as num).toDouble() : 0.0;

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
        playerSkinId = (prefs.getString('$_kPrefPlayerSkinPrefix$pid') ?? playerSkinId).trim();
        spriteUrlCtrl.text = (prefs.getString('$_kPrefPlayerSpriteUrlPrefix$pid') ?? '').trim();
        forceReloadGameplay = prefs.getBool('$_kPrefForceReloadPrefix$pid') ?? true;
        fpsControlsEnabled = prefs.getBool('$_kPrefFpsControlsPrefix$pid') ?? _fpsControlsEnabled;
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
                                              child: Text(
                                                'FPS controls (WASD + mouse click)',
                                                style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800),
                                              ),
                                            ),
                                            Switch(
                                              value: fpsControlsEnabled,
                                              onChanged: saving
                                                  ? null
                                                  : (v) async {
                                                      setSheetState(() => fpsControlsEnabled = v);
                                                      if (!mounted) return;
                                                      setState(() => _fpsControlsEnabled = v);
                                                      final pid = _projectId;
                                                      if (pid != null && pid.trim().isNotEmpty) {
                                                        try {
                                                          final prefs = await SharedPreferences.getInstance();
                                                          await prefs.setBool('$_kPrefFpsControlsPrefix$pid', v);
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
                                            SizedBox(
                                              width: 96,
                                              child: TextField(
                                                controller: speedCtrl,
                                                enabled: !saving,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
                                                ],
                                                decoration: const InputDecoration(
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                ),
                                                onChanged: saving
                                                    ? null
                                                    : (txt) {
                                                        final v = double.tryParse(txt.trim());
                                                        if (v == null) return;
                                                        setSheetState(() => speed = v.clamp(0.0, 20.0));
                                                        scheduleLiveApply(reload: true);
                                                      },
                                                onSubmitted: saving
                                                    ? null
                                                    : (_) {
                                                        pushHistorySnapshot();
                                                        syncSpeedText();
                                                        scheduleLiveApply(reload: true);
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
                                                setSheetState(() => speed = v);
                                                syncSpeedText();
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
    AppNotifier.showError(msg);
  }

  Future<void> _installJsErrorBridge() async {
    await _runJs(
      """
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
      """,
    );
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

  Future<void> _sendKey({required String key, required String code, required bool down}) async {
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
    await _runJs(
      """
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
      """,
    );
  }

  Future<void> _sendMousePrimary({required bool down}) async {
    final mouseType = down ? 'mousedown' : 'mouseup';
    final pointerType = down ? 'pointerdown' : 'pointerup';
    await _runJs(
      """
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
    await _sendKey(key: 'f', code: 'KeyF', down: false);
    await _sendMousePrimary(down: false);
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
    _loadFpsControlsPref();
    _loadControllerSkinPref();

    _hudPulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat(reverse: true);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'GameForgeLog',
        onMessageReceived: (msg) {
          final text = msg.message.trim();
          if (text.isEmpty) return;
          _notifyJsError(text);
        },
      )
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
                await _installJsErrorBridge();
                final pid = _projectId;
                if (pid == null || pid.isEmpty) {
                  await _checkBridgeSupportOnce();
                  return;
                }
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
    _hudPulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
              context.go('/dashboard?tab=projects');
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
            onPressed: _openControllerSkinSheet,
            icon: const Icon(Icons.sports_esports_rounded),
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
          if (!_loading && _error == null && _fpsControlsEnabled)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: IgnorePointer(
                ignoring: false,
                child: SafeArea(
                  top: false,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) {
                      final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
                      final slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(fade);
                      return FadeTransition(
                        opacity: fade,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: Container(
                      key: ValueKey<String>(_controllerSkin.name),
                      child: _ControllerShell(
                        accent: skinAccent(_controllerSkin),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: panelDecoration(),
                              child: AnimatedBuilder(
                                animation: _hudPulseCtrl,
                                builder: (context, _) {
                                  final a = skinAccent(_controllerSkin);
                                  final t = _hudPulseCtrl.value;
                                  final glow = (0.06 + t * 0.10).clamp(0.06, 0.18);

                                  if (_controllerSkin == _ControllerSkin.arcade) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _TouchKey(
                                          label: 'Fwd',
                                          child: const Icon(Icons.keyboard_arrow_up_rounded, size: 26),
                                          size: 58,
                                          haptic: true,
                                          skin: _controllerSkin,
                                          onDown: () async {
                                            await _ensureGameFocus();
                                            await _sendKey(key: 'w', code: 'KeyW', down: true);
                                            await _sendKey(key: 'ArrowUp', code: 'ArrowUp', down: true);
                                          },
                                          onUp: () async {
                                            await _sendKey(key: 'w', code: 'KeyW', down: false);
                                            await _sendKey(key: 'ArrowUp', code: 'ArrowUp', down: false);
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _TouchKey(
                                              label: 'Left',
                                              child: const Icon(Icons.chevron_left_rounded, size: 26),
                                              size: 58,
                                              haptic: true,
                                              skin: _controllerSkin,
                                              onDown: () async {
                                                await _ensureGameFocus();
                                                await _sendKey(key: 'a', code: 'KeyA', down: true);
                                                await _sendKey(key: 'ArrowLeft', code: 'ArrowLeft', down: true);
                                              },
                                              onUp: () async {
                                                await _sendKey(key: 'a', code: 'KeyA', down: false);
                                                await _sendKey(key: 'ArrowLeft', code: 'ArrowLeft', down: false);
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            _TouchKey(
                                              label: 'Back',
                                              child: const Icon(Icons.keyboard_arrow_down_rounded, size: 26),
                                              size: 58,
                                              haptic: true,
                                              skin: _controllerSkin,
                                              onDown: () async {
                                                await _ensureGameFocus();
                                                await _sendKey(key: 's', code: 'KeyS', down: true);
                                                await _sendKey(key: 'ArrowDown', code: 'ArrowDown', down: true);
                                              },
                                              onUp: () async {
                                                await _sendKey(key: 's', code: 'KeyS', down: false);
                                                await _sendKey(key: 'ArrowDown', code: 'ArrowDown', down: false);
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            _TouchKey(
                                              label: 'Right',
                                              child: const Icon(Icons.chevron_right_rounded, size: 26),
                                              size: 58,
                                              haptic: true,
                                              skin: _controllerSkin,
                                              onDown: () async {
                                                await _ensureGameFocus();
                                                await _sendKey(key: 'd', code: 'KeyD', down: true);
                                                await _sendKey(key: 'ArrowRight', code: 'ArrowRight', down: true);
                                              },
                                              onUp: () async {
                                                await _sendKey(key: 'd', code: 'KeyD', down: false);
                                                await _sendKey(key: 'ArrowRight', code: 'ArrowRight', down: false);
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  }

                                  return _DpadCross(
                                    accent: a,
                                    glow: glow,
                                    skin: _controllerSkin,
                                    onUpDown: () async {
                                      await _ensureGameFocus();
                                      await _sendKey(key: 'w', code: 'KeyW', down: true);
                                      await _sendKey(key: 'ArrowUp', code: 'ArrowUp', down: true);
                                    },
                                    onUpUp: () async {
                                      await _sendKey(key: 'w', code: 'KeyW', down: false);
                                      await _sendKey(key: 'ArrowUp', code: 'ArrowUp', down: false);
                                    },
                                    onLeftDown: () async {
                                      await _ensureGameFocus();
                                      await _sendKey(key: 'a', code: 'KeyA', down: true);
                                      await _sendKey(key: 'ArrowLeft', code: 'ArrowLeft', down: true);
                                    },
                                    onLeftUp: () async {
                                      await _sendKey(key: 'a', code: 'KeyA', down: false);
                                      await _sendKey(key: 'ArrowLeft', code: 'ArrowLeft', down: false);
                                    },
                                    onDownDown: () async {
                                      await _ensureGameFocus();
                                      await _sendKey(key: 's', code: 'KeyS', down: true);
                                      await _sendKey(key: 'ArrowDown', code: 'ArrowDown', down: true);
                                    },
                                    onDownUp: () async {
                                      await _sendKey(key: 's', code: 'KeyS', down: false);
                                      await _sendKey(key: 'ArrowDown', code: 'ArrowDown', down: false);
                                    },
                                    onRightDown: () async {
                                      await _ensureGameFocus();
                                      await _sendKey(key: 'd', code: 'KeyD', down: true);
                                      await _sendKey(key: 'ArrowRight', code: 'ArrowRight', down: true);
                                    },
                                    onRightUp: () async {
                                      await _sendKey(key: 'd', code: 'KeyD', down: false);
                                      await _sendKey(key: 'ArrowRight', code: 'ArrowRight', down: false);
                                    },
                                  );
                                },
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: panelDecoration(),
                              child: _controllerSkin == _ControllerSkin.arcade
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _TouchKey(
                                          label: 'Jump',
                                          child: actionGlyph(primary: true),
                                          size: 58,
                                          haptic: true,
                                          skin: _controllerSkin,
                                          onDown: () async {
                                            await _ensureGameFocus();
                                            await _sendKey(key: ' ', code: 'Space', down: true);
                                          },
                                          onUp: () async {
                                            await _sendKey(key: ' ', code: 'Space', down: false);
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        _TouchKey(
                                          label: 'Fire',
                                          child: actionGlyph(primary: false),
                                          size: 58,
                                          haptic: true,
                                          skin: _controllerSkin,
                                          onDown: () async {
                                            await _ensureGameFocus();
                                            await _sendMousePrimary(down: true);
                                          },
                                          onUp: () async {
                                            await _sendMousePrimary(down: false);
                                          },
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _TouchKey(
                                              label: 'Jump',
                                              child: _FaceButtonFace(spec: faceSpec(primary: true), pressedT: _hudPulseCtrl.value),
                                              size: 58,
                                              haptic: true,
                                              skin: _controllerSkin,
                                              forceShape: _TouchKeyShape.circle,
                                              onDown: () async {
                                                await _ensureGameFocus();
                                                await _sendKey(key: ' ', code: 'Space', down: true);
                                              },
                                              onUp: () async {
                                                await _sendKey(key: ' ', code: 'Space', down: false);
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            _TouchKey(
                                              label: 'Fire',
                                              child: _FaceButtonFace(spec: faceSpec(primary: false), pressedT: _hudPulseCtrl.value),
                                              size: 58,
                                              haptic: true,
                                              skin: _controllerSkin,
                                              forceShape: _TouchKeyShape.circle,
                                              onDown: () async {
                                                await _ensureGameFocus();
                                                await _sendMousePrimary(down: true);
                                              },
                                              onUp: () async {
                                                await _sendMousePrimary(down: false);
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        IgnorePointer(
                                          child: Opacity(
                                            opacity: 0.55,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _FaceButtonFace(spec: faceSpec(primary: true).copyWith(labelOverride: 'X'), pressedT: _hudPulseCtrl.value),
                                                const SizedBox(width: 8),
                                                _FaceButtonFace(spec: faceSpec(primary: true).copyWith(labelOverride: 'Y'), pressedT: _hudPulseCtrl.value),
                                              ],
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
                ),
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
                    final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
                    final slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(fade);
                    return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: child));
                  },
                  child: Container(
                    key: ValueKey<String>('2d.${_controllerSkin.name}'),
                    child: (_controllerSkin == _ControllerSkin.arcade)
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            decoration: panelDecoration().copyWith(borderRadius: BorderRadius.circular(999)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _TouchKey(
                                  label: 'Left',
                                  child: const Icon(Icons.chevron_left_rounded, size: 28),
                                  size: 62,
                                  haptic: true,
                                  skin: _controllerSkin,
                                  onDown: () async {
                                    await _ensureGameFocus();
                                    await _sendKey(key: 'ArrowLeft', code: 'ArrowLeft', down: true);
                                    await _sendKey(key: 'a', code: 'KeyA', down: true);
                                  },
                                  onUp: () async {
                                    await _sendKey(key: 'ArrowLeft', code: 'ArrowLeft', down: false);
                                    await _sendKey(key: 'a', code: 'KeyA', down: false);
                                  },
                                ),
                                const SizedBox(width: 10),
                                _TouchKey(
                                  label: 'Jump',
                                  child: const Icon(Icons.keyboard_arrow_up_rounded, size: 28),
                                  size: 62,
                                  haptic: true,
                                  skin: _controllerSkin,
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
                                ),
                                const SizedBox(width: 10),
                                _TouchKey(
                                  label: 'Right',
                                  child: const Icon(Icons.chevron_right_rounded, size: 28),
                                  size: 62,
                                  haptic: true,
                                  skin: _controllerSkin,
                                  onDown: () async {
                                    await _ensureGameFocus();
                                    await _sendKey(key: 'ArrowRight', code: 'ArrowRight', down: true);
                                    await _sendKey(key: 'd', code: 'KeyD', down: true);
                                  },
                                  onUp: () async {
                                    await _sendKey(key: 'ArrowRight', code: 'ArrowRight', down: false);
                                    await _sendKey(key: 'd', code: 'KeyD', down: false);
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
                                  await _sendKey(key: 'w', code: 'KeyW', down: true);
                                  await _sendKey(key: 'ArrowUp', code: 'ArrowUp', down: true);
                                },
                                onUpUp: () async {
                                  await _sendKey(key: 'w', code: 'KeyW', down: false);
                                  await _sendKey(key: 'ArrowUp', code: 'ArrowUp', down: false);
                                },
                                onLeftDown: () async {
                                  await _ensureGameFocus();
                                  await _sendKey(key: 'a', code: 'KeyA', down: true);
                                  await _sendKey(key: 'ArrowLeft', code: 'ArrowLeft', down: true);
                                },
                                onLeftUp: () async {
                                  await _sendKey(key: 'a', code: 'KeyA', down: false);
                                  await _sendKey(key: 'ArrowLeft', code: 'ArrowLeft', down: false);
                                },
                                onDownDown: () async {
                                  await _ensureGameFocus();
                                  await _sendKey(key: 's', code: 'KeyS', down: true);
                                  await _sendKey(key: 'ArrowDown', code: 'ArrowDown', down: true);
                                },
                                onDownUp: () async {
                                  await _sendKey(key: 's', code: 'KeyS', down: false);
                                  await _sendKey(key: 'ArrowDown', code: 'ArrowDown', down: false);
                                },
                                onRightDown: () async {
                                  await _ensureGameFocus();
                                  await _sendKey(key: 'd', code: 'KeyD', down: true);
                                  await _sendKey(key: 'ArrowRight', code: 'ArrowRight', down: true);
                                },
                                onRightUp: () async {
                                  await _sendKey(key: 'd', code: 'KeyD', down: false);
                                  await _sendKey(key: 'ArrowRight', code: 'ArrowRight', down: false);
                                },
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: panelDecoration(),
                                child: _TouchKey(
                                  label: 'Jump',
                                  child: _FaceButtonFace(spec: faceSpec(primary: true), pressedT: _hudPulseCtrl.value),
                                  size: 62,
                                  haptic: true,
                                  skin: _controllerSkin,
                                  forceShape: _TouchKeyShape.circle,
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
                                ),
                              ),
                            ],
                          ),
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
    final autoShape = (widget.skin == _ControllerSkin.arcade) ? BoxShape.circle : BoxShape.rectangle;
    final shape = (widget.forceShape == _TouchKeyShape.auto)
        ? autoShape
        : (widget.forceShape == _TouchKeyShape.circle ? BoxShape.circle : BoxShape.rectangle);
    final radius = (shape == BoxShape.circle) ? null : BorderRadius.circular(widget.forceShape == _TouchKeyShape.roundedRect ? 22 : 18);
    final borderColor = _pressed ? a.withOpacity(0.55) : cs.onSurface.withOpacity(0.12);

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
          borderRadius: (shape == BoxShape.circle) ? BorderRadius.circular(999) : (radius ?? BorderRadius.circular(18)),
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
                        colors: [Colors.white.withOpacity(0.22), Colors.white.withOpacity(0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: IconTheme(
                    data: IconThemeData(color: cs.onSurface),
                    child: widget.child ?? Text(widget.label, style: AppTypography.subtitle1.copyWith(color: cs.onSurface)),
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

  const _ControllerShell({
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
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
              BoxShadow(color: Colors.black.withOpacity(0.24), blurRadius: 26, offset: const Offset(0, 18)),
              BoxShadow(color: accent.withOpacity(0.10), blurRadius: 40, offset: const Offset(0, 22)),
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
                          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 18, offset: const Offset(0, 10)),
                          BoxShadow(color: accent.withOpacity(0.12), blurRadius: 28, offset: const Offset(0, 14)),
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
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
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
        ),
      ),
    );
  }
}

enum _TouchKeyShape {
  auto,
  circle,
  roundedRect,
}

class _FaceSpec {
  final String label;
  final Color fillA;
  final Color fillB;

  const _FaceSpec({
    required this.label,
    required this.fillA,
    required this.fillB,
  });

  _FaceSpec copyWith({
    String? labelOverride,
    Color? fillA,
    Color? fillB,
  }) {
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

  const _FaceButtonFace({
    required this.spec,
    required this.pressedT,
  });

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
          BoxShadow(color: spec.fillA.withOpacity(0.24), blurRadius: 20, offset: const Offset(0, 12)),
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
          BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 10)),
          BoxShadow(color: accent.withOpacity(glow), blurRadius: 30, offset: const Offset(0, 16)),
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

enum _ControllerSkin {
  arcade,
  xbox,
  playstation,
  nintendo,
}
