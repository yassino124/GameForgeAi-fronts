import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/services/assets_service.dart';
import '../../../core/services/projects_service.dart';
import '../../widgets/widgets.dart';

class AIConfigurationScreen extends StatefulWidget {
  const AIConfigurationScreen({super.key});

  @override
  State<AIConfigurationScreen> createState() => _AIConfigurationScreenState();
}

class _PalettePresetChip extends StatelessWidget {
  final String label;
  final List<String> colors;
  final bool enabled;
  final VoidCallback onTap;

  const _PalettePresetChip({
    required this.label,
    required this.colors,
    required this.enabled,
    required this.onTap,
  });

  Color? _parse(String s) {
    final v = s.trim();
    final hex = v.startsWith('#') ? v.substring(1) : v;
    if (hex.length != 6) return null;
    final n = int.tryParse('FF$hex', radix: 16);
    if (n == null) return null;
    return Color(n);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c1 = colors.isNotEmpty ? _parse(colors[0]) : null;
    final c2 = colors.length > 1 ? _parse(colors[1]) : null;
    final c3 = colors.length > 2 ? _parse(colors[2]) : null;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1.0 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
            boxShadow: AppShadows.boxShadowSmall,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ColorPreviewDot(color: c1),
              const SizedBox(width: 6),
              _ColorPreviewDot(color: c2),
              const SizedBox(width: 6),
              _ColorPreviewDot(color: c3),
              const SizedBox(width: 10),
              Text(
                label,
                style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorHexRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final Color? color;
  final VoidCallback onChanged;
  final VoidCallback? onPick;

  const _ColorHexRow({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.color,
    required this.onChanged,
    this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        InkWell(
          onTap: (enabled && onPick != null) ? onPick : null,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (color ?? cs.surfaceVariant),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
              boxShadow: AppShadows.boxShadowSmall,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            decoration: InputDecoration(
              hintText: '#RRGGBB',
              filled: true,
              fillColor: cs.surface.withOpacity(0.9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.8)),
              ),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    );
  }
}

class _AIConfigurationScreenState extends State<AIConfigurationScreen> with SingleTickerProviderStateMixin {
  String _selectedModel = 'GPT-4';
  double _creativityLevel = 0.7;
  bool _includeAIAssets = true;
  bool _optimizeForMobile = true;
  bool _enableMultiplayer = false;
  bool _useAdvancedPhysics = false;

  int _tabIndex = 0;

  String _buildTarget = 'webgl';

  double _timeScale = 1.0;
  double _difficulty = 0.5;
  double _speed = 7.0;
  bool _fogEnabled = false;
  double _fogDensity = 0.0;
  double _cameraZoom = 0.0;
  double _gravityY = 0.0;
  double _jumpForce = 0.0;

  // ── World / FX configs ────────────────────────────────────────────────────
  String _gameMode = 'endless';     // endless / timed / survival / puzzle / battle
  String _skyboxTheme = 'day';      // day / night / sunset / space / dungeon / underwater / volcano
  double _playerScale = 1.0;        // 0.25 → 3.0
  String _ambientLightColor = '#FFFFFF';
  bool _bloomEnabled = false;
  double _bloomIntensity = 0.5;
  bool _particlesEnabled = true;
  double _scoreMultiplier = 1.0;    // 0.5 → 5.0
  double _enemyMultiplier = 1.0;    // 0.25 → 4.0
  bool _godMode = false;
  bool _infiniteJump = false;
  int _timeLimit = 60;              // 10 → 300
  int _lives = 3;                   // 1 → 10
  final TextEditingController _musicUrlCtrl = TextEditingController();
  final TextEditingController _bgImageUrlCtrl = TextEditingController();

  final TextEditingController _primaryColorCtrl = TextEditingController(text: '#22C55E');
  final TextEditingController _secondaryColorCtrl = TextEditingController(text: '#3B82F6');
  final TextEditingController _accentColorCtrl = TextEditingController(text: '#F59E0B');
  final TextEditingController _playerColorCtrl = TextEditingController(text: '#F59E0B');

  // Asset uploads
  File? _playerSpriteFile;
  File? _backgroundImageFile;
  File? _soundFile;


  final List<String> _aiModels = [
    'GPT-4',
    'GPT-3.5',
    'Claude-3',
    'Gemini Pro',
  ];

  final _promptController = TextEditingController();
  bool _creating = false;
  bool _analyzing = false;
  String? _error;

  late final AnimationController _neonPulse;
  late final Animation<double> _neonT;

  @override
  void initState() {
    super.initState();
    _neonPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _neonT = Tween<double>(begin: 0.65, end: 1.0).animate(CurvedAnimation(parent: _neonPulse, curve: Curves.easeInOut));
    _neonPulse.repeat(reverse: true);
  }

  bool _isProAndroidGateMessage(String message) {
    final s = message.toLowerCase();
    return s.contains('android') && s.contains('pro') && s.contains('sub');
  }

  Future<void> _showProAndroidUpsellSheet({required String message}) async {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
              boxShadow: AppShadows.boxShadowLarge,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary.withOpacity(0.25)),
                      ),
                      child: Icon(Icons.workspace_premium_rounded, color: cs.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Upgrade required',
                        style: AppTypography.subtitle1.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Android (APK) export is available on Pro. Upgrade to unlock Android builds and higher limits.',
                  style: AppTypography.body2.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                if (message.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    message.trim(),
                    style: AppTypography.caption.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Not now',
                        onPressed: () => Navigator.of(ctx).pop(),
                        type: ButtonType.secondary,
                        isFullWidth: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: CustomButton(
                        text: 'Upgrade to Pro',
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          if (!context.mounted) return;
                          await context.push('/subscription');
                        },
                        type: ButtonType.primary,
                        isFullWidth: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _normHex(String? v) {
    if (v == null) return null;
    var s = v.trim();
    if (s.isEmpty) return null;
    if (!s.startsWith('#') && s.length == 6) s = '#$s';
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(s)) return null;
    return s.toUpperCase();
  }

  Color? _parseHexToColor(String? s) {
    final v = _normHex(s);
    if (v == null) return null;
    final n = int.tryParse(v.substring(1), radix: 16);
    if (n == null) return null;
    return Color(0xFF000000 | n);
  }

  Map<String, dynamic>? _extractPatchFromAiData(Map<String, dynamic> data) {
    dynamic patch = data['patch'] ?? data['tuning'] ?? data['runtimeConfig'] ?? data['config'];
    if (patch is String) {
      try {
        final decoded = jsonDecode(patch);
        if (decoded is Map) patch = decoded;
      } catch (_) {
        patch = null;
      }
    }
    if (patch is Map) return Map<String, dynamic>.from(patch as Map);
    return null;
  }

  String _lower(String s) => s.toLowerCase().trim();

  Map<String, dynamic> _heuristicPatch(String prompt) {
    final s = _lower(prompt);

    double speed = 7.0;
    double difficulty = 0.55;
    double timeScale = 1.0;

    if (s.contains('hard') || s.contains('hardcore') || s.contains('difficult') || s.contains('brutal')) {
      speed = 12.0;
      difficulty = 0.8;
      timeScale = 1.12;
    }
    if (s.contains('chill') || s.contains('relax') || s.contains('easy') || s.contains('casual')) {
      speed = 4.5;
      difficulty = 0.35;
      timeScale = 0.92;
    }
    if (s.contains('slow') || s.contains('cinematic')) {
      timeScale = 0.85;
      speed = speed.clamp(3.0, 9.0);
    }
    if (s.contains('fast') || s.contains('speed') || s.contains('runner')) {
      speed = speed < 9 ? 9.0 : speed;
    }

    bool fogEnabled = false;
    double fogDensity = 0.0;
    if (s.contains('fog') || s.contains('mist') || s.contains('atmosphere')) {
      fogEnabled = true;
      fogDensity = 0.02;
    }

    String primary = '#22C55E';
    String secondary = '#3B82F6';
    String accent = '#F59E0B';
    if (s.contains('cyber')) {
      primary = '#00E5FF';
      secondary = '#7C4DFF';
      accent = '#FF1744';
    } else if (s.contains('pastel')) {
      primary = '#A7F3D0';
      secondary = '#BFDBFE';
      accent = '#FBCFE8';
    } else if (s.contains('dark')) {
      primary = '#111827';
      secondary = '#1F2937';
      accent = '#F59E0B';
    } else if (s.contains('neon') || s.contains('sci-fi') || s.contains('scifi')) {
      primary = '#22C55E';
      secondary = '#3B82F6';
      accent = '#F59E0B';
    }

    double cameraZoom = 0.0;
    if (s.contains('close camera') || s.contains('zoom in')) cameraZoom = 18.0;
    if (s.contains('far camera') || s.contains('zoom out')) cameraZoom = 10.0;

    double gravityY = 0.0;
    if (s.contains('low gravity') || s.contains('moon')) gravityY = -14.0;
    if (s.contains('heavy gravity')) gravityY = -30.0;

    double jumpForce = 0.0;
    if (s.contains('double jump') || s.contains('high jump')) jumpForce = 18.0;

    return {
      'speed': speed,
      'difficulty': difficulty,
      'timeScale': timeScale,
      'primaryColor': primary,
      'secondaryColor': secondary,
      'accentColor': accent,
      'playerColor': accent,
      'fogEnabled': fogEnabled,
      'fogDensity': fogDensity,
      'cameraZoom': cameraZoom,
      'gravityY': gravityY,
      'jumpForce': jumpForce,
    };
  }

  Future<void> _analyzePromptAndApply({String? templateName}) async {
    if (_analyzing || _creating) return;
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Session expired. Please sign in again.';
      });
      return;
    }

    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _error = 'Please enter a prompt first.';
      });
      return;
    }

    setState(() {
      _analyzing = true;
      _error = null;
    });

    Map<String, dynamic>? patch;
    try {
      final notes = <String>[
        'Return ONLY a JSON object with tuning/style fields for a game generator UI.',
        'Supported keys:',
        '{"speed": number 0-20, "difficulty": number 0-1, "timeScale": number 0.5-2,',
        '"primaryColor": "#RRGGBB", "secondaryColor": "#RRGGBB", "accentColor": "#RRGGBB", "playerColor": "#RRGGBB",',
        '"fogEnabled": boolean, "fogDensity": number 0-0.1, "cameraZoom": number 0-30, "gravityY": number -50..0, "jumpForce": number 0-50}',
        'No markdown, no explanation.',
        if (templateName != null && templateName.trim().isNotEmpty) 'Template: $templateName',
      ].join('\n');

      final res = await AiService.generateProjectDraft(
        token: token,
        description: prompt,
        notes: notes,
      );

      if (res['success'] == true && res['data'] is Map) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        patch = _extractPatchFromAiData(data);

        if (patch == null && data.values.any((v) => v is String)) {
          for (final v in data.values) {
            if (v is! String) continue;
            final s = v.trim();
            if (!s.startsWith('{') || !s.endsWith('}')) continue;
            try {
              final decoded = jsonDecode(s);
              if (decoded is Map) {
                patch = Map<String, dynamic>.from(decoded as Map);
                break;
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {
      patch = null;
    }

    patch ??= _heuristicPatch(prompt);

    void applyNum(String key, void Function(double) set, {double? min, double? max}) {
      final v = patch![key];
      if (v is num) {
        var d = v.toDouble();
        if (min != null) d = d < min ? min : d;
        if (max != null) d = d > max ? max : d;
        set(d);
      }
    }

    void applyHex(String key, TextEditingController ctrl) {
      final v = patch![key]?.toString();
      final hex = _normHex(v);
      if (hex != null) ctrl.text = hex;
    }

    try {
      setState(() {
        applyNum('speed', (d) => _speed = d, min: 0, max: 20);
        applyNum('difficulty', (d) => _difficulty = d, min: 0, max: 1);
        applyNum('timeScale', (d) => _timeScale = d, min: 0.5, max: 2.0);

        applyHex('primaryColor', _primaryColorCtrl);
        applyHex('secondaryColor', _secondaryColorCtrl);
        applyHex('accentColor', _accentColorCtrl);
        applyHex('playerColor', _playerColorCtrl);

        final fog = patch!['fogEnabled'];
        if (fog is bool) _fogEnabled = fog;
        applyNum('fogDensity', (d) => _fogDensity = d, min: 0, max: 0.1);
        applyNum('cameraZoom', (d) => _cameraZoom = d, min: 0, max: 30);
        applyNum('gravityY', (d) => _gravityY = d, min: -50, max: 0);
        applyNum('jumpForce', (d) => _jumpForce = d, min: 0, max: 50);
      });

      AppNotifier.showSuccess('Applied AI patch');
    } catch (_) {
      setState(() {
        _error = 'Failed to apply AI patch.';
      });
      AppNotifier.showError(_error ?? 'Failed to apply AI patch');
    } finally {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
      });
    }
  }

  static const List<String> _pickerSwatches = [
    '#22C55E',
    '#3B82F6',
    '#F59E0B',
    '#EF4444',
    '#A78BFA',
    '#00E5FF',
    '#FF1744',
    '#111827',
    '#FFFFFF',
    '#000000',
  ];

  Future<void> _pickColor({required String label, required TextEditingController controller, void Function(String hex)? onPicked}) async {
    final cs = Theme.of(context).colorScheme;
    final tmp = TextEditingController(text: controller.text);
    try {
      final res = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          Color? preview = _parseHexToColor(tmp.text);
          Widget dot(Color? c) {
            return Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c ?? cs.surfaceVariant,
                border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: cs.surface,
            title: Text(label, style: AppTypography.subtitle1),
            content: StatefulBuilder(
              builder: (context, setD) {
                preview = _parseHexToColor(tmp.text);
                return SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _pickerSwatches
                            .map(
                              (hex) => InkWell(
                                onTap: () {
                                  tmp.text = hex;
                                  setD(() {});
                                },
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _parseHexToColor(hex) ?? cs.surfaceVariant,
                                    border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          dot(preview),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: tmp,
                              decoration: const InputDecoration(hintText: '#RRGGBB'),
                              onChanged: (_) => setD(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Tip: tap a swatch or paste a hex color.', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final v = _normHex(tmp.text);
                  if (v == null) {
                    Navigator.of(context).pop(null);
                    return;
                  }
                  Navigator.of(context).pop(v);
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      );

      if (res != null && res.trim().isNotEmpty) {
        controller.text = res.trim();
        onPicked?.call(res.trim());
        setState(() {});
      }
    } finally {
      tmp.dispose();
    }
  }

  void _applyPrompt(String value, {required bool append}) {
    final v = value.trim();
    if (v.isEmpty) return;
    final cur = _promptController.text;
    if (!append || cur.trim().isEmpty) {
      _promptController.text = v;
      _promptController.selection = TextSelection.collapsed(offset: _promptController.text.length);
      return;
    }
    final next = '${cur.trim()}\n\n$v';
    _promptController.text = next;
    _promptController.selection = TextSelection.collapsed(offset: _promptController.text.length);
  }

  Future<void> _submit({
    required String token,
    required String prompt,
    String? templateId,
    String? templateName,
  }) async {
    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      // ── Upload selected assets first ──────────────────────────────────────
      String? playerSpriteUrl;
      String? backgroundImageUrl;
      String? soundFileUrl;

      if (_playerSpriteFile != null) {
        AppNotifier.showSuccess('Uploading player sprite…');
        playerSpriteUrl = await _uploadAssetFile(
          token: token,
          file: _playerSpriteFile!,
          type: 'texture',
          name: 'player_sprite',
        );
      }
      if (_backgroundImageFile != null) {
        AppNotifier.showSuccess('Uploading background image…');
        backgroundImageUrl = await _uploadAssetFile(
          token: token,
          file: _backgroundImageFile!,
          type: 'texture',
          name: 'background_image',
        );
      }
      if (_soundFile != null) {
        AppNotifier.showSuccess('Uploading sound file…');
        soundFileUrl = await _uploadAssetFile(
          token: token,
          file: _soundFile!,
          type: 'audio',
          name: 'background_sound',
        );
      }

      // Append asset URLs to prompt so AI can embed them in game config
      var enrichedPrompt = prompt;
      if (playerSpriteUrl != null) {
        enrichedPrompt += '\n[playerSpriteUrl: $playerSpriteUrl]';
      }
      if (backgroundImageUrl != null) {
        enrichedPrompt += '\n[backgroundImageUrl: $backgroundImageUrl]';
      }
      if (soundFileUrl != null) {
        enrichedPrompt += '\n[soundFileUrl: $soundFileUrl]';
      }
      final res = await ProjectsService.createFromAi(
        token: token,
        prompt: enrichedPrompt,
        buildTarget: _buildTarget,
        templateId: (templateId != null && templateId.trim().isNotEmpty) ? templateId : null,
        timeScale: _timeScale,
        difficulty: _difficulty,
        speed: _speed,
        primaryColor: _primaryColorCtrl.text,
        secondaryColor: _secondaryColorCtrl.text,
        accentColor: _accentColorCtrl.text,
        playerColor: _playerColorCtrl.text,
        fogEnabled: _fogEnabled,
        fogDensity: _fogDensity,
        cameraZoom: _cameraZoom,
        gravityY: _gravityY,
        jumpForce: _jumpForce,
        playerSpriteUrl: playerSpriteUrl,
        backgroundImageUrl: backgroundImageUrl,
        soundFileUrl: soundFileUrl,
        scoreMultiplier: _scoreMultiplier,
        enemyMultiplier: _enemyMultiplier,
        bloomEnabled: _bloomEnabled,
        bloomIntensity: _bloomIntensity,
        godMode: _godMode,
        infiniteJump: _infiniteJump,
        timeLimit: _timeLimit,
        lives: _lives,
        playerScale: _playerScale,
        gameMode: _gameMode,
        skyboxTheme: _skyboxTheme,
        ambientLightColor: _ambientLightColor,
        bgMusicUrl: _musicUrlCtrl.text,
        bgImageUrl: _bgImageUrlCtrl.text,
      );
      if (!context.mounted) return;
      final data = res['data'];
      final projectId = (data is Map) ? data['projectId']?.toString() : null;
      if (res['success'] == true && projectId != null && projectId.trim().isNotEmpty) {
        AppNotifier.showSuccess('AI project created. Starting build…');
        context.go(
          '/build-progress',
          extra: {
            'projectId': projectId,
            if (templateId != null && templateId.trim().isNotEmpty) 'templateId': templateId,
            if (templateName != null && templateName.trim().isNotEmpty) 'templateName': templateName,
            'prompt': prompt,
          },
        );
        return;
      }
      setState(() {
        _error = (res['message']?.toString() ?? 'Failed to create project').trim();
      });
      final msg = (_error ?? 'Failed to create project').trim();
      if (_isProAndroidGateMessage(msg)) {
        await _showProAndroidUpsellSheet(message: msg);
      } else {
        AppNotifier.showError(msg);
      }
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _error = e.toString();
      });
      final msg = _friendlyError(_error ?? e.toString());
      if (_isProAndroidGateMessage(msg)) {
        await _showProAndroidUpsellSheet(message: msg);
      } else {
        AppNotifier.showError(msg);
      }
    } finally {
      if (!context.mounted) return;
      setState(() {
        _creating = false;
      });
    }
  }

  /// Uploads [file] to the assets API and returns the public download URL.
  /// Returns null if upload or URL fetch failed (non-blocking).
  Future<String?> _uploadAssetFile({
    required String token,
    required File file,
    required String type,
    String? name,
  }) async {
    try {
      final uploadRes = await AssetsService.uploadAsset(
        token: token,
        file: file,
        type: type,
        name: name,
      );
      if (uploadRes['success'] != true) return null;
      final assetData = uploadRes['data'];
      final assetId = (assetData is Map ? assetData['_id'] : null)?.toString();
      if (assetId == null || assetId.isEmpty) return null;

      final urlRes = await AssetsService.getDownloadUrl(token: token, assetId: assetId);
      if (urlRes['success'] != true) return null;
      final urlData = urlRes['data'];
      final rawUrl = (urlData is Map ? urlData['url'] : null)?.toString();
      if (rawUrl == null || rawUrl.isEmpty) return null;
      return ApiService.normalizeImageUrl(rawUrl);
    } catch (_) {
      return null;
    }
  }

  String _friendlyError(String raw) {
    final s = raw.trim();
    if (s.contains('TimeoutException') || s.contains('Future not completed')) {
      final base = ApiService.baseUrl;
      if (base.contains('127.0.0.1') || base.contains('localhost')) {
        return 'Request timed out. Your app is calling the backend at:\n$base\n\nOn a real iPhone, localhost points to the phone (not your Mac). Set API_BASE_URL to your Mac IP (e.g. http://192.168.x.x:3000/api) and try again.';
      }
      return 'Request timed out. Backend URL:\n$base\n\nMake sure the backend is running and reachable from the device, then try again.';
    }
    return s;
  }

  @override
  void dispose() {
    _promptController.dispose();
    _primaryColorCtrl.dispose();
    _secondaryColorCtrl.dispose();
    _accentColorCtrl.dispose();
    _playerColorCtrl.dispose();
    _neonPulse.dispose();
    super.dispose();
  }

  Widget _sectionTitle(String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
      ),
    );
  }

  Widget _tabChip({
    required String label,
    required int index,
    required IconData icon,
    bool enabled = true,
  }) {
    final cs = Theme.of(context).colorScheme;
    final selected = _tabIndex == index;
    return ChoiceChip(
      selected: selected,
      onSelected: (!enabled || _creating)
          ? null
          : (_) {
              HapticFeedback.selectionClick();
              setState(() => _tabIndex = index);
            },
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? cs.onPrimary : cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      labelStyle: AppTypography.caption.copyWith(
        fontWeight: FontWeight.w900,
        color: selected ? cs.onPrimary : cs.onSurface,
      ),
      backgroundColor: cs.surface,
      selectedColor: cs.primary,
      side: BorderSide(color: cs.outlineVariant.withOpacity(0.7)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _buildPromptTab({
    required String? templateId,
    required String? templateName,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              border: Border.all(color: AppColors.error.withOpacity(0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.wifi_off, color: AppColors.error.withOpacity(0.9), size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _friendlyError(_error!),
                        style: AppTypography.body2.copyWith(color: cs.onSurface),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _creating
                                ? null
                                : () {
                                    setState(() {
                                      _error = null;
                                    });
                                  },
                            child: Text(
                              'Dismiss',
                              style: AppTypography.caption.copyWith(color: cs.primary),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          TextButton(
                            onPressed: _creating
                                ? null
                                : () {
                                    final p = _promptController.text.trim();
                                    if (p.isEmpty) return;
                                    final auth = context.read<AuthProvider>();
                                    final t = auth.token;
                                    if (t == null || t.isEmpty) return;
                                    _submit(token: t, prompt: p, templateId: templateId, templateName: templateName);
                                  },
                            child: Text(
                              'Retry',
                              style: AppTypography.caption.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _sectionTitle('Prompt'),
        Row(
          children: [
            Expanded(
              child: Text(
                'Let AI propose a patch for tuning + style.',
                style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            TextButton.icon(
              onPressed: (_creating || _analyzing)
                  ? null
                  : () => _analyzePromptAndApply(templateName: templateName),
              icon: _analyzing
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(cs.primary)),
                    )
                  : const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: Text(_analyzing ? 'Analyzing…' : 'AI Patch'),
            ),
          ],
        ),
        if (templateName != null && templateName.trim().isNotEmpty) ...[
          Text(
            'Template: $templateName',
            style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AnimatedCard(
          delay: const Duration(milliseconds: 40),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: cs.primary, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'AI Prompt Assistant',
                      style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Write 3 things: 1) game goal, 2) controls, 3) difficulty + visual style.',
                  style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ActionChip(
                      label: const Text('Arcade runner'),
                      onPressed: () {
                        _applyPrompt(
                          'Make an arcade runner. Goal: collect coins and avoid obstacles. Controls: left/right + jump. Difficulty: starts easy then increases. Visual: neon cyber style.',
                          append: false,
                        );
                      },
                    ),
                    ActionChip(
                      label: const Text('Platformer'),
                      onPressed: () {
                        _applyPrompt(
                          'Make a 2D platformer. Goal: reach the exit in each level. Controls: move + jump + double jump. Add moving platforms and spikes. Visual: cute cartoon style.',
                          append: false,
                        );
                      },
                    ),
                    ActionChip(
                      label: const Text('Endless shooter'),
                      onPressed: () {
                        _applyPrompt(
                          'Make an endless top-down shooter. Goal: survive waves as long as possible. Controls: move + shoot. Add upgrades every 30 seconds. Visual: sci-fi minimal.',
                          append: false,
                        );
                      },
                    ),
                    ActionChip(
                      label: const Text('Add story'),
                      onPressed: () {
                        _applyPrompt(
                          'Story: give the player a short backstory and a final boss objective.',
                          append: true,
                        );
                      },
                    ),
                    ActionChip(
                      label: const Text('Add UI hints'),
                      onPressed: () {
                        _applyPrompt(
                          'UI: show score at top, HP bar, and a small tutorial hint for controls at the start.',
                          append: true,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _promptController,
          minLines: 4,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Describe the game you want to generate...',
          ),
        ),
      ],
    );
  }

  Widget _buildTuningTab() {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Build Target'),
        AnimatedCard(
          delay: const Duration(milliseconds: 70),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
              boxShadow: AppShadows.boxShadowSmall,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose where to build your game',
                  style: AppTypography.body2.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: _buildTarget,
                  decoration: const InputDecoration(),
                  items: const [
                    DropdownMenuItem(value: 'webgl', child: Text('Web (WebGL)')),
                    DropdownMenuItem(value: 'android_apk', child: Text('Android (APK)')),
                    DropdownMenuItem(value: 'windows', child: Text('Desktop (Windows)')),
                    DropdownMenuItem(value: 'macos', child: Text('Desktop (macOS)')),
                  ],
                  onChanged: _creating
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() => _buildTarget = v);
                        },
                ),
                const SizedBox(height: 6),
                Text(
                  _buildTarget == 'android_apk'
                      ? 'You will get an APK file to install on Android devices.'
                      : _buildTarget == 'windows'
                          ? 'You will get a Windows desktop zip (exe + data folder).' 
                          : _buildTarget == 'macos'
                              ? 'You will get a macOS desktop zip (.app bundle).'
                              : 'You will get a playable WebGL build + downloadable zip.',
                  style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        _sectionTitle('Game tuning (guided)'),
        AnimatedCard(
          delay: const Duration(milliseconds: 90),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
              boxShadow: AppShadows.boxShadowSmall,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Presets',
                  style: AppTypography.caption.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Chill'),
                        onPressed: _creating
                            ? null
                            : () {
                                setState(() {
                                  _speed = 4.0;
                                  _difficulty = 0.35;
                                  _timeScale = 0.9;
                                });
                              },
                      ),
                      ActionChip(
                        label: const Text('Balanced'),
                        onPressed: _creating
                            ? null
                            : () {
                                setState(() {
                                  _speed = 7.0;
                                  _difficulty = 0.55;
                                  _timeScale = 1.0;
                                });
                              },
                      ),
                      ActionChip(
                        label: const Text('Hardcore'),
                        onPressed: _creating
                            ? null
                            : () {
                                setState(() {
                                  _speed = 12.0;
                                  _difficulty = 0.8;
                                  _timeScale = 1.15;
                                });
                              },
                      ),
                      ActionChip(
                        label: const Text('Atmosphere'),
                        onPressed: _creating
                            ? null
                            : () {
                                setState(() {
                                  _fogEnabled = true;
                                  _fogDensity = 0.02;
                                });
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Gameplay', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: Text('Speed', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w700))),
                    Text(_speed.toStringAsFixed(1), style: AppTypography.caption),
                  ],
                ),
                Slider(
                  value: _speed.clamp(0.0, 20.0),
                  min: 0.0,
                  max: 20.0,
                  divisions: 200,
                  onChanged: _creating ? null : (v) => setState(() => _speed = v),
                ),
                Row(
                  children: [
                    Expanded(child: Text('Difficulty', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w700))),
                    Text(_difficulty.toStringAsFixed(2), style: AppTypography.caption),
                  ],
                ),
                Slider(
                  value: _difficulty.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  divisions: 100,
                  onChanged: _creating ? null : (v) => setState(() => _difficulty = v),
                ),
                Row(
                  children: [
                    Expanded(child: Text('Time scale', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w700))),
                    Text(_timeScale.toStringAsFixed(2), style: AppTypography.caption),
                  ],
                ),
                Slider(
                  value: _timeScale.clamp(0.5, 2.0),
                  min: 0.5,
                  max: 2.0,
                  divisions: 150,
                  onChanged: _creating ? null : (v) => setState(() => _timeScale = v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStyleTab() {
    final cs = Theme.of(context).colorScheme;

    // 20 WOW palette presets
    final presets = [
      {'label': '⚡ Neon',      'p': '#22C55E', 's': '#3B82F6', 'a': '#F59E0B', 'pc': '#F59E0B'},
      {'label': '🌐 Cyber',     'p': '#00E5FF', 's': '#7C4DFF', 'a': '#FF1744', 'pc': '#FF1744'},
      {'label': '🍬 Pastel',    'p': '#A7F3D0', 's': '#BFDBFE', 'a': '#FBCFE8', 'pc': '#FBCFE8'},
      {'label': '🌑 Dark',      'p': '#0EA5E9', 's': '#A78BFA', 'a': '#22C55E', 'pc': '#22C55E'},
      {'label': '🌊 Ocean',     'p': '#0369A1', 's': '#06B6D4', 'a': '#67E8F9', 'pc': '#67E8F9'},
      {'label': '🌅 Sunset',    'p': '#F97316', 's': '#EF4444', 'a': '#FBBF24', 'pc': '#FBBF24'},
      {'label': '🌌 Galaxy',    'p': '#4F46E5', 's': '#7C3AED', 'a': '#C084FC', 'pc': '#C084FC'},
      {'label': '🌿 Forest',    'p': '#16A34A', 's': '#15803D', 'a': '#BEF264', 'pc': '#BEF264'},
      {'label': '❄️ Arctic',    'p': '#BAE6FD', 's': '#E0F2FE', 'a': '#38BDF8', 'pc': '#38BDF8'},
      {'label': '🔥 Inferno',   'p': '#DC2626', 's': '#EA580C', 'a': '#FDE047', 'pc': '#FDE047'},
      {'label': '🎮 Retro',     'p': '#A3E635', 's': '#4ADE80', 'a': '#FACC15', 'pc': '#FACC15'},
      {'label': '🌸 Sakura',    'p': '#F9A8D4', 's': '#FBCFE8', 'a': '#FDF2F8', 'pc': '#FDF2F8'},
      {'label': '💎 Diamond',   'p': '#E2E8F0', 's': '#94A3B8', 'a': '#38BDF8', 'pc': '#38BDF8'},
      {'label': '🌙 Midnight',  'p': '#1E3A5F', 's': '#2D4A6F', 'a': '#F59E0B', 'pc': '#F59E0B'},
      {'label': '🍊 Citrus',    'p': '#84CC16', 's': '#F97316', 'a': '#EAB308', 'pc': '#EAB308'},
      {'label': '🎭 Vapor',     'p': '#F472B6', 's': '#818CF8', 'a': '#34D399', 'pc': '#34D399'},
      {'label': '🩸 Crimson',   'p': '#9F1239', 's': '#BE123C', 'a': '#FB7185', 'pc': '#FB7185'},
      {'label': '🏜️ Desert',    'p': '#D97706', 's': '#B45309', 'a': '#FEF3C7', 'pc': '#FEF3C7'},
      {'label': '🟣 Neon Pink', 'p': '#DB2777', 's': '#9333EA', 'a': '#F0ABFC', 'pc': '#F0ABFC'},
      {'label': '🌈 Rainbow',   'p': '#EF4444', 's': '#3B82F6', 'a': '#22C55E', 'pc': '#A78BFA'},
    ];

    Color? _px(String? hex) => _parseHexToColor(hex ?? '');

    bool _isActive(Map<String, String> p) =>
        (_normHex(_primaryColorCtrl.text) == _normHex(p['p'])) &&
        (_normHex(_secondaryColorCtrl.text) == _normHex(p['s'])) &&
        (_normHex(_accentColorCtrl.text) == _normHex(p['a']));

    void _applyPreset(Map<String, String> p) {
      setState(() {
        _primaryColorCtrl.text   = p['p']!;
        _secondaryColorCtrl.text = p['s']!;
        _accentColorCtrl.text    = p['a']!;
        _playerColorCtrl.text    = p['pc']!;
      });
    }

    // Live palette preview card
    Widget _paletteBar() {
      final p1 = _px(_primaryColorCtrl.text);
      final p2 = _px(_secondaryColorCtrl.text);
      final p3 = _px(_accentColorCtrl.text);
      final p4 = _px(_playerColorCtrl.text);
      return Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          gradient: LinearGradient(
            colors: [
              p1 ?? cs.primary,
              p2 ?? cs.secondary,
              p3 ?? cs.tertiary,
              p4 ?? cs.primary,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: (p1 ?? cs.primary).withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _paletteLabel('Primary', p1),
            _paletteLabel('Secondary', p2),
            _paletteLabel('Accent', p3),
            _paletteLabel('Player', p4),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Live Preview'),
        AnimatedCard(
          delay: const Duration(milliseconds: 80),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
              boxShadow: AppShadows.boxShadowSmall,
            ),
            child: _paletteBar(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        _sectionTitle('Palette Presets'),
        AnimatedCard(
          delay: const Duration(milliseconds: 110),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
              boxShadow: AppShadows.boxShadowSmall,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '20 curated themes — tap to apply instantly',
                  style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.6,
                  children: presets.map((p) {
                    final active = _isActive(p);
                    final c1 = _px(p['p']);
                    final c2 = _px(p['s']);
                    final c3 = _px(p['a']);
                    return GestureDetector(
                      onTap: _creating ? null : () {
                        HapticFeedback.selectionClick();
                        _applyPreset(p);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: active ? (c1 ?? cs.primary).withOpacity(0.80) : cs.outlineVariant.withOpacity(0.5),
                            width: active ? 1.8 : 1.0,
                          ),
                          boxShadow: active
                              ? [BoxShadow(color: (c1 ?? cs.primary).withOpacity(0.30), blurRadius: 16, offset: const Offset(0, 6))]
                              : AppShadows.boxShadowSmall,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Gradient background strip
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                height: 7,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        c1 ?? cs.primary,
                                        c2 ?? cs.secondary,
                                        c3 ?? cs.tertiary,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Card body
                              Container(
                                color: active ? (c1 ?? cs.primary).withOpacity(0.13) : cs.surface,
                                padding: const EdgeInsets.fromLTRB(10, 0, 6, 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p['label']!,
                                        style: AppTypography.caption.copyWith(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                          color: active ? (c1 ?? cs.primary) : cs.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (active)
                                      Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: (c1 ?? cs.primary).withOpacity(0.2),
                                        ),
                                        child: Icon(Icons.check_rounded, size: 12, color: c1 ?? cs.primary),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        _sectionTitle('Custom Colors'),
        AnimatedCard(
          delay: const Duration(milliseconds: 130),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
              boxShadow: AppShadows.boxShadowSmall,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ColorHexRow(
                  label: 'Primary',
                  controller: _primaryColorCtrl,
                  enabled: !_creating,
                  color: _parseHexToColor(_primaryColorCtrl.text),
                  onChanged: () => setState(() {}),
                  onPick: () => _pickColor(label: 'Primary', controller: _primaryColorCtrl),
                ),
                const SizedBox(height: AppSpacing.md),
                _ColorHexRow(
                  label: 'Secondary',
                  controller: _secondaryColorCtrl,
                  enabled: !_creating,
                  color: _parseHexToColor(_secondaryColorCtrl.text),
                  onChanged: () => setState(() {}),
                  onPick: () => _pickColor(label: 'Secondary', controller: _secondaryColorCtrl),
                ),
                const SizedBox(height: AppSpacing.md),
                _ColorHexRow(
                  label: 'Accent',
                  controller: _accentColorCtrl,
                  enabled: !_creating,
                  color: _parseHexToColor(_accentColorCtrl.text),
                  onChanged: () => setState(() {}),
                  onPick: () => _pickColor(label: 'Accent', controller: _accentColorCtrl),
                ),
                const SizedBox(height: AppSpacing.md),
                _ColorHexRow(
                  label: 'Player color',
                  controller: _playerColorCtrl,
                  enabled: !_creating,
                  color: _parseHexToColor(_playerColorCtrl.text),
                  onChanged: () => setState(() {}),
                  onPick: () => _pickColor(label: 'Player color', controller: _playerColorCtrl),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _paletteLabel(String label, Color? color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color ?? Colors.white24,
            border: Border.all(color: Colors.white38, width: 1.5),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
          ),
        ),
      ],
    );
  }

  Widget _presetDot(Color? color) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color ?? Colors.white24,
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
    );
  }

  // ── Assets Tab ──────────────────────────────────────────────────────────────
  Widget _buildAssetsTab() {
    final cs = Theme.of(context).colorScheme;

    Widget assetCard({
      required String title,
      required String subtitle,
      required IconData icon,
      required Color iconColor,
      required File? file,
      required bool isImage,
      required VoidCallback onPick,
      required VoidCallback onClear,
      BoxFit fit = BoxFit.cover,
    }) {
      final hasFile = file != null;
      return AnimatedCard(
        delay: const Duration(milliseconds: 90),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            border: Border.all(
              color: hasFile
                  ? iconColor.withOpacity(0.5)
                  : cs.outlineVariant.withOpacity(0.7),
              width: hasFile ? 1.5 : 1.0,
            ),
            boxShadow: hasFile
                ? [BoxShadow(color: iconColor.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6))]
                : AppShadows.boxShadowSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: iconColor.withOpacity(0.25)),
                      ),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTypography.subtitle2.copyWith(
                              fontWeight: FontWeight.w900,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: AppTypography.caption.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasFile)
                      IconButton(
                        onPressed: _creating ? null : onClear,
                        icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant, size: 20),
                        tooltip: 'Remove',
                      ),
                  ],
                ),
              ),

              // Preview / pick area
              GestureDetector(
                onTap: _creating ? null : onPick,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                  height: hasFile && isImage ? 140 : 70,
                  decoration: BoxDecoration(
                    color: hasFile
                        ? Colors.transparent
                        : cs.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                    border: Border.all(
                      color: hasFile
                          ? iconColor.withOpacity(0.4)
                          : cs.outlineVariant.withOpacity(0.6),
                      style: hasFile ? BorderStyle.solid : BorderStyle.solid,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasFile && isImage
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(file!, fit: fit),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Tap to change',
                                  style: AppTypography.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                hasFile ? Icons.audio_file_rounded : Icons.add_photo_alternate_rounded,
                                color: hasFile ? iconColor : cs.onSurfaceVariant.withOpacity(0.5),
                                size: 28,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                hasFile
                                    ? file!.path.split('/').last
                                    : 'Tap to select from gallery',
                                style: AppTypography.caption.copyWith(
                                  color: hasFile ? iconColor : cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
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
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            border: Border.all(color: cs.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: cs.primary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Custom assets override the AI-generated defaults. Select images/sounds to personalize your game.',
                  style: AppTypography.caption.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        _sectionTitle('Player Sprite'),
        assetCard(
          title: 'Player Sprite',
          subtitle: 'PNG/JPG image used as your player character',
          icon: Icons.person_rounded,
          iconColor: const Color(0xFF3B82F6),
          file: _playerSpriteFile,
          isImage: true,
          fit: BoxFit.contain,
          onPick: () async {
            final picker = ImagePicker();
            final source = await _showImageSourceSheet();
            if (source == null) return;
            final picked = await picker.pickImage(source: source, imageQuality: 90);
            if (picked == null) return;
            setState(() => _playerSpriteFile = File(picked.path));
            AppNotifier.showSuccess('Player sprite selected');
          },
          onClear: () => setState(() => _playerSpriteFile = null),
        ),
        const SizedBox(height: AppSpacing.lg),

        _sectionTitle('Background Image'),
        assetCard(
          title: 'Background Image',
          subtitle: 'PNG/JPG used as the game world background/sky',
          icon: Icons.landscape_rounded,
          iconColor: const Color(0xFF22C55E),
          file: _backgroundImageFile,
          isImage: true,
          onPick: () async {
            final picker = ImagePicker();
            final source = await _showImageSourceSheet();
            if (source == null) return;
            final picked = await picker.pickImage(source: source, imageQuality: 90);
            if (picked == null) return;
            setState(() => _backgroundImageFile = File(picked.path));
            AppNotifier.showSuccess('Background image selected');
          },
          onClear: () => setState(() => _backgroundImageFile = null),
        ),
        const SizedBox(height: AppSpacing.lg),

        _sectionTitle('Background Music / Sound'),
        assetCard(
          title: 'Sound / Music',
          subtitle: 'MP3/WAV file for background music or sound effect',
          icon: Icons.music_note_rounded,
          iconColor: const Color(0xFFF59E0B),
          file: _soundFile,
          isImage: false,
          onPick: () async {
            final picker = ImagePicker();
            // Use video picker as proxy for media files (picks audio on Android)
            final picked = await picker.pickMedia();
            if (picked == null) {
              AppNotifier.showError('Audio file picker not available on this device. Use a URL in the Prompt instead.');
              return;
            }
            setState(() => _soundFile = File(picked.path));
            AppNotifier.showSuccess('Sound file selected');
          },
          onClear: () => setState(() => _soundFile = null),
        ),

        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: cs.onSurfaceVariant, size: 16),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Assets are embedded as metadata hints for the AI builder. The generated Unity game runtime must support reading custom assets via the GameForgeBridge.',
                  style: AppTypography.caption.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<ImageSource?> _showImageSourceSheet() async {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.large)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.photo_library_rounded, color: cs.primary),
              ),
              title: Text('Photo Library', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800)),
              subtitle: Text('Pick from your gallery', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.camera_alt_rounded, color: cs.secondary),
              ),
              title: Text('Camera', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800)),
              subtitle: Text('Take a new photo', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }


  Widget _buildAdvancedTab() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Environment & Physics'),
        AnimatedCard(
          delay: const Duration(milliseconds: 120),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
              boxShadow: AppShadows.boxShadowSmall,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Environment', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: Text('Fog', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w700))),
                    Switch(
                      value: _fogEnabled,
                      onChanged: _creating ? null : (v) => setState(() => _fogEnabled = v),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Text('Fog density', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w700))),
                    Text(_fogDensity.toStringAsFixed(4), style: AppTypography.caption),
                  ],
                ),
                Slider(
                  value: _fogDensity.clamp(0.0, 0.1),
                  min: 0.0,
                  max: 0.1,
                  divisions: 100,
                  onChanged: _creating ? null : (v) => setState(() => _fogDensity = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Camera & Physics', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: Text('Camera zoom', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w700))),
                    Text(_cameraZoom <= 0 ? 'auto' : _cameraZoom.toStringAsFixed(1), style: AppTypography.caption),
                  ],
                ),
                Slider(
                  value: _cameraZoom.clamp(0.0, 30.0),
                  min: 0.0,
                  max: 30.0,
                  divisions: 300,
                  onChanged: _creating ? null : (v) => setState(() => _cameraZoom = v),
                ),
                Row(
                  children: [
                    Expanded(child: Text('Gravity Y', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w700))),
                    Text(_gravityY == 0 ? 'default' : _gravityY.toStringAsFixed(1), style: AppTypography.caption),
                  ],
                ),
                Slider(
                  value: _gravityY.clamp(-50.0, 0.0),
                  min: -50.0,
                  max: 0.0,
                  divisions: 200,
                  onChanged: _creating ? null : (v) => setState(() => _gravityY = v),
                ),
                Row(
                  children: [
                    Expanded(child: Text('Jump force', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w700))),
                    Text(_jumpForce == 0 ? 'default' : _jumpForce.toStringAsFixed(1), style: AppTypography.caption),
                  ],
                ),
                Slider(
                  value: _jumpForce.clamp(0.0, 50.0),
                  min: 0.0,
                  max: 50.0,
                  divisions: 250,
                  onChanged: _creating ? null : (v) => setState(() => _jumpForce = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _sectionTitle('AI Model'),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            children: _aiModels.map((model) {
              final isSelected = model == _selectedModel;
              return _buildModelOption(model, isSelected);
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _sectionTitle('Creativity Level'),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Creativity', style: AppTypography.body2.copyWith(color: cs.onSurface)),
                  Text(
                    '${(_creativityLevel * 100).toInt()}%',
                    style: AppTypography.body2.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Slider(
                value: _creativityLevel,
                onChanged: (value) {
                  setState(() {
                    _creativityLevel = value;
                  });
                },
                min: 0.1,
                max: 1.0,
                activeColor: cs.primary,
                inactiveColor: cs.outlineVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Conservative', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                  Text('Creative', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _sectionTitle('Features'),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            children: [
              _buildFeatureToggle(
                'Include AI-generated assets',
                'Generate custom sprites, sounds, and textures',
                _includeAIAssets,
                (value) {
                  setState(() {
                    _includeAIAssets = value;
                  });
                },
                Icons.image,
              ),
              Divider(color: cs.outlineVariant),
              _buildFeatureToggle(
                'Optimize for mobile',
                'Ensure smooth performance on mobile devices',
                _optimizeForMobile,
                (value) {
                  setState(() {
                    _optimizeForMobile = value;
                  });
                },
                Icons.phone_android,
              ),
              Divider(color: cs.outlineVariant),
              _buildFeatureToggle(
                'Enable multiplayer',
                'Add online multiplayer functionality',
                _enableMultiplayer,
                (value) {
                  setState(() {
                    _enableMultiplayer = value;
                  });
                },
                Icons.people,
              ),
              Divider(color: cs.outlineVariant),
              _buildFeatureToggle(
                'Advanced physics',
                'Realistic physics simulation',
                _useAdvancedPhysics,
                (value) {
                  setState(() {
                    _useAdvancedPhysics = value;
                  });
                },
                Icons.science,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            border: Border.all(color: cs.primary.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: cs.primary),
                  const SizedBox(width: AppSpacing.md),
                  Text('AI Capabilities', style: AppTypography.subtitle2.copyWith(color: cs.primary)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ...[
                '• Generate game mechanics and rules',
                '• Create level designs and layouts',
                '• Design characters and story elements',
                '• Generate UI/UX components',
                '• Create sound effects and music',
              ].map(
                (capability) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    capability,
                    style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }

  // ── World & FX Tab ─────────────────────────────────────────────────────────
  Widget _buildWorldTab() {
    final cs = Theme.of(context).colorScheme;

    Widget _card({required Widget child, Duration delay = const Duration(milliseconds: 100)}) =>
        AnimatedCard(
          delay: delay,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
              boxShadow: AppShadows.boxShadowSmall,
            ),
            child: child,
          ),
        );

    Widget _sliderRow({
      required String label,
      required String value,
      required double sliderValue,
      required double min,
      required double max,
      required int divisions,
      required ValueChanged<double>? onChanged,
      Color? activeColor,
    }) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w700))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (activeColor ?? cs.primary).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(value,
                      style: AppTypography.caption
                          .copyWith(color: activeColor ?? cs.primary, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            Slider(
              value: sliderValue.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              activeColor: activeColor ?? cs.primary,
              inactiveColor: cs.outlineVariant,
              onChanged: _creating ? null : onChanged,
            ),
          ],
        );

    Widget _toggleRow(String label, String subtitle, bool value, ValueChanged<bool>? onChanged,
        {IconData icon = Icons.toggle_on_rounded, Color? color}) =>
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (color ?? cs.primary).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color ?? cs.primary, size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800)),
                  Text(subtitle,
                      style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: _creating ? null : onChanged,
              activeColor: color ?? cs.primary,
            ),
          ],
        );

    final gameModes = [
      {'id': 'endless',  'label': '♾️ Endless',   'sub': 'Never-ending run'},
      {'id': 'timed',    'label': '⏱️ Timed',     'sub': 'Beat the clock'},
      {'id': 'survival', 'label': '💀 Survival',  'sub': 'Last as long as possible'},
      {'id': 'puzzle',   'label': '🧩 Puzzle',    'sub': 'Solve to advance'},
      {'id': 'battle',   'label': '⚔️ Battle',    'sub': 'Defeat all enemies'},
    ];

    final skyboxThemes = [
      {'id': 'day',        'label': '☀️ Day',        'color': '#87CEEB'},
      {'id': 'night',      'label': '🌙 Night',      'color': '#0F172A'},
      {'id': 'sunset',     'label': '🌅 Sunset',     'color': '#F97316'},
      {'id': 'space',      'label': '🌌 Space',      'color': '#1E1B4B'},
      {'id': 'dungeon',    'label': '🏰 Dungeon',    'color': '#292524'},
      {'id': 'underwater', 'label': '🌊 Underwater', 'color': '#0369A1'},
      {'id': 'volcano',    'label': '🌋 Volcano',    'color': '#991B1B'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Game Mode ──────────────────────────────────────────────────────
        _sectionTitle('Game Mode'),
        _card(
          delay: const Duration(milliseconds: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose how the game is played',
                  style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.md),
              ...gameModes.map((m) {
                final selected = _gameMode == m['id'];
                return GestureDetector(
                  onTap: _creating ? null : () => setState(() => _gameMode = m['id']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: selected ? cs.primary.withOpacity(0.12) : cs.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      border: Border.all(
                        color: selected ? cs.primary.withOpacity(0.7) : cs.outlineVariant.withOpacity(0.5),
                        width: selected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['label']!,
                                  style: AppTypography.body2.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: selected ? cs.primary : cs.onSurface,
                                  )),
                              Text(m['sub']!,
                                  style: AppTypography.caption
                                      .copyWith(color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        if (selected) Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Skybox Theme ───────────────────────────────────────────────────
        _sectionTitle('Skybox / Environment'),
        _card(
          delay: const Duration(milliseconds: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Game world visual environment',
                  style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skyboxThemes.map((s) {
                  final selected = _skyboxTheme == s['id'];
                  final c = _parseHexToColor(s['color']!) ?? cs.primary;
                  return GestureDetector(
                    onTap: _creating ? null : () => setState(() => _skyboxTheme = s['id']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? c.withOpacity(0.18) : cs.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected ? c.withOpacity(0.8) : cs.outlineVariant.withOpacity(0.6),
                          width: selected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 14, height: 14,
                              decoration: BoxDecoration(
                                  color: c, shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black12, width: 0.5))),
                          const SizedBox(width: 8),
                          Text(s['label']!,
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w800,
                                color: selected ? c : cs.onSurface,
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Player & Camera ────────────────────────────────────────────────
        _sectionTitle('Player & Camera'),
        _card(
          delay: const Duration(milliseconds: 120),
          child: Column(
            children: [
              _sliderRow(
                label: 'Player Scale',
                value: '${_playerScale.toStringAsFixed(2)}×',
                sliderValue: _playerScale,
                min: 0.25, max: 3.0, divisions: 55,
                onChanged: (v) => setState(() => _playerScale = v),
                activeColor: const Color(0xFF3B82F6),
              ),
              const Divider(height: AppSpacing.lg),
              _sliderRow(
                label: 'Camera Zoom',
                value: _cameraZoom <= 0 ? 'auto' : _cameraZoom.toStringAsFixed(1),
                sliderValue: _cameraZoom.clamp(0, 30),
                min: 0, max: 30, divisions: 300,
                onChanged: (v) => setState(() => _cameraZoom = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Physics ────────────────────────────────────────────────────────
        _sectionTitle('Physics'),
        _card(
          delay: const Duration(milliseconds: 130),
          child: Column(
            children: [
              _sliderRow(
                label: 'Gravity Y',
                value: _gravityY == 0 ? 'default' : _gravityY.toStringAsFixed(1),
                sliderValue: _gravityY.clamp(-50, 0),
                min: -50, max: 0, divisions: 200,
                onChanged: (v) => setState(() => _gravityY = v),
                activeColor: const Color(0xFFF97316),
              ),
              const Divider(height: AppSpacing.lg),
              _sliderRow(
                label: 'Jump Force',
                value: _jumpForce == 0 ? 'default' : _jumpForce.toStringAsFixed(1),
                sliderValue: _jumpForce.clamp(0, 50),
                min: 0, max: 50, divisions: 250,
                onChanged: (v) => setState(() => _jumpForce = v),
                activeColor: const Color(0xFFA78BFA),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Gameplay Multipliers ───────────────────────────────────────────
        _sectionTitle('Gameplay Multipliers'),
        _card(
          delay: const Duration(milliseconds: 140),
          child: Column(
            children: [
              _sliderRow(
                label: '⚡ Score Multiplier',
                value: '${_scoreMultiplier.toStringAsFixed(1)}×',
                sliderValue: _scoreMultiplier,
                min: 0.5, max: 5.0, divisions: 45,
                onChanged: (v) => setState(() => _scoreMultiplier = v),
                activeColor: const Color(0xFFF59E0B),
              ),
              const Divider(height: AppSpacing.lg),
              _sliderRow(
                label: '👾 Enemy Multiplier',
                value: '${_enemyMultiplier.toStringAsFixed(2)}×',
                sliderValue: _enemyMultiplier,
                min: 0.25, max: 4.0, divisions: 60,
                onChanged: (v) => setState(() => _enemyMultiplier = v),
                activeColor: const Color(0xFFEF4444),
              ),
              const Divider(height: AppSpacing.lg),
              _sliderRow(
                label: '⏱️ Time Limit (Secs)',
                value: _timeLimit.toString(),
                sliderValue: _timeLimit.toDouble(),
                min: 10, max: 300, divisions: 290,
                onChanged: (v) => setState(() => _timeLimit = v.toInt()),
                activeColor: const Color(0xFF10B981),
              ),
              const Divider(height: AppSpacing.lg),
              _sliderRow(
                label: '❤️ Lives',
                value: _lives.toString(),
                sliderValue: _lives.toDouble(),
                min: 1, max: 10, divisions: 9,
                onChanged: (v) => setState(() => _lives = v.toInt()),
                activeColor: const Color(0xFFEC4899),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Visual FX ─────────────────────────────────────────────────────
        _sectionTitle('Visual FX'),
        _card(
          delay: const Duration(milliseconds: 150),
          child: Column(
            children: [
              _toggleRow('🌟 Bloom (Glow)', 'Post-process light bloom effect',
                  _bloomEnabled, (v) => setState(() => _bloomEnabled = v),
                  icon: Icons.flare_rounded, color: const Color(0xFFFBBF24)),
              if (_bloomEnabled) ...[
                const SizedBox(height: AppSpacing.sm),
                _sliderRow(
                  label: 'Bloom Intensity',
                  value: _bloomIntensity.toStringAsFixed(2),
                  sliderValue: _bloomIntensity,
                  min: 0.0, max: 2.0, divisions: 40,
                  onChanged: (v) => setState(() => _bloomIntensity = v),
                  activeColor: const Color(0xFFFBBF24),
                ),
              ],
              const Divider(height: AppSpacing.lg),
              _toggleRow('🎆 Particle Effects', 'Sparks, smoke, trail particles',
                  _particlesEnabled, (v) => setState(() => _particlesEnabled = v),
                  icon: Icons.auto_awesome_rounded, color: const Color(0xFF8B5CF6)),
              const Divider(height: AppSpacing.lg),
              _toggleRow('🌫️ Fog', 'Atmospheric fog effect',
                  _fogEnabled, (v) => setState(() => _fogEnabled = v),
                  icon: Icons.blur_on_rounded, color: const Color(0xFF64748B)),
              if (_fogEnabled) ...[
                const SizedBox(height: AppSpacing.sm),
                _sliderRow(
                  label: 'Fog Density',
                  value: _fogDensity.toStringAsFixed(4),
                  sliderValue: _fogDensity.clamp(0, 0.1),
                  min: 0, max: 0.1, divisions: 100,
                  onChanged: (v) => setState(() => _fogDensity = v),
                  activeColor: const Color(0xFF64748B),
                ),
              ],
              const Divider(height: AppSpacing.lg),
              _ColorHexRow(
                label: '💡 Ambient Light',
                controller: TextEditingController(text: _ambientLightColor),
                enabled: !_creating,
                color: _parseHexToColor(_ambientLightColor),
                onChanged: () {},
                onPick: () async {
                  final ctrl = TextEditingController(text: _ambientLightColor);
                  try {
                    await _pickColor(label: 'Ambient Light', controller: ctrl);
                    if (!mounted) return;
                    setState(() => _ambientLightColor = ctrl.text.trim());
                  } finally {
                    ctrl.dispose();
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Cheat Codes ───────────────────────────────────────────────────
        _sectionTitle('⚡ Power Settings'),
        _card(
          delay: const Duration(milliseconds: 160),
          child: Column(
            children: [
              _toggleRow('🛡️ God Mode', 'Player is invincible',
                  _godMode, (v) => setState(() => _godMode = v),
                  icon: Icons.shield_rounded, color: const Color(0xFFEF4444)),
              const Divider(height: AppSpacing.lg),
              _toggleRow('🪂 Infinite Jump', 'Jump as many times as you want',
                  _infiniteJump, (v) => setState(() => _infiniteJump = v),
                  icon: Icons.keyboard_double_arrow_up_rounded,
                  color: const Color(0xFF3B82F6)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Media URLs ────────────────────────────────────────────────────
        _sectionTitle('🎵 Media'),
        _card(
          delay: const Duration(milliseconds: 170),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Background Music URL',
                  style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _musicUrlCtrl,
                enabled: !_creating,
                style: AppTypography.body2,
                decoration: InputDecoration(
                  hintText: 'https://… (MP3/OGG)',
                  prefixIcon: const Icon(Icons.music_note_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Background Image URL',
                  style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _bgImageUrlCtrl,
                enabled: !_creating,
                style: AppTypography.body2,
                decoration: InputDecoration(
                  hintText: 'https://… (PNG/JPG)',
                  prefixIcon: const Icon(Icons.landscape_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }


  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final extra = GoRouterState.of(context).extra;
    final templateId = (extra is Map)
        ? (extra['templateId']?.toString() ?? (extra['template'] is Map ? (extra['template']['id']?.toString() ?? extra['template']['_id']?.toString()) : null))
        : null;
    final templateName = (extra is Map)
        ? (extra['templateName']?.toString() ?? (extra['template'] is Map ? (extra['template']['name']?.toString()) : null))
        : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          'AI Settings',
          style: AppTypography.subtitle1.copyWith(color: cs.onSurface),
        ),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
          icon: Icon(
            Icons.arrow_back,
            color: cs.onSurface,
          ),
        ),
        actions: [
          // Progress indicator (2/3)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Center(
              child: Text(
                '2/3',
                style: AppTypography.caption.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundGradient
              : AppTheme.backgroundGradientLight,
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) {
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 10),
                child: child,
              ),
            );
          },
          child: Column(
          children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary,
                  cs.primary.withOpacity(0.3),
                ],
              ),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.66,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _tabChip(label: 'Prompt', index: 0, icon: Icons.auto_awesome_rounded),
                    const SizedBox(width: 10),
                    _tabChip(label: 'Tuning', index: 1, icon: Icons.tune_rounded),
                    const SizedBox(width: 10),
                    _tabChip(label: 'Style', index: 2, icon: Icons.palette_rounded),
                    const SizedBox(width: 10),
                    _tabChip(label: 'Advanced', index: 3, icon: Icons.settings_suggest_rounded),
                    const SizedBox(width: 10),
                    _tabChip(label: 'Assets', index: 4, icon: Icons.photo_library_rounded),
                    const SizedBox(width: 10),
                    _tabChip(label: 'World', index: 5, icon: Icons.public_rounded),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
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
                  key: ValueKey<int>(_tabIndex),
                  child: () {
                    if (_tabIndex == 0) return _buildPromptTab(templateId: templateId, templateName: templateName);
                    if (_tabIndex == 1) return _buildTuningTab();
                    if (_tabIndex == 2) return _buildStyleTab();
                    if (_tabIndex == 3) return _buildAdvancedTab();
                    if (_tabIndex == 4) return _buildAssetsTab();
                    return _buildWorldTab();
                  }(),
                ),
              ),
            ),
          ),
          
          // Bottom button
          Container(
            padding: AppSpacing.paddingLarge,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(color: cs.outlineVariant),
              ),
            ),
            child: AnimatedBuilder(
              animation: _neonT,
              builder: (context, child) {
                final t = _neonT.value;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.20 * t),
                        blurRadius: 26 * t,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: cs.secondary.withOpacity(0.12 * t),
                        blurRadius: 42 * t,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: CustomButton(
                text: _creating ? 'Generating…' : 'Generate Game',
                onPressed: _creating
                    ? null
                    : () async {
                        final prompt = _promptController.text.trim();
                        if (prompt.isEmpty) {
                          setState(() {
                            _error = 'Please enter a prompt';
                          });
                          return;
                        }

                        final auth = context.read<AuthProvider>();
                        final token = auth.token;
                        if (token == null || token.isEmpty) {
                          setState(() {
                            _error = 'Session expired. Please sign in again.';
                          });
                          return;
                        }

                        await _submit(token: token, prompt: prompt, templateId: templateId, templateName: templateName);
                      },
                type: ButtonType.primary,
                size: ButtonSize.large,
                isFullWidth: true,
              ),
            ),
          ),
        ],
      ),
      ),
      ),
    );
  }

  Widget _buildModelOption(String model, bool isSelected) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedModel = model;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
            ),
            
            const SizedBox(width: AppSpacing.lg),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model,
                    style: AppTypography.body2.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xs),
                  
                  Text(
                    _getModelDescription(model),
                    style: AppTypography.caption.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: AppBorderRadius.allSmall,
                ),
                child: Text(
                  'Recommended',
                  style: AppTypography.caption.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureToggle(
    String title,
    String description,
    bool value,
    ValueChanged<bool> onChanged,
    IconData icon,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(
            icon,
            color: cs.primary,
            size: 20,
          ),
          
          const SizedBox(width: AppSpacing.lg),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body2.copyWith(color: cs.onSurface),
                ),
                
                const SizedBox(height: AppSpacing.xs),
                
                Text(
                  description,
                  style: AppTypography.caption.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: cs.primary,
          ),
        ],
      ),
    );
  }

  String _getModelDescription(String model) {
    switch (model) {
      case 'GPT-4':
        return 'Most advanced, best for complex games';
      case 'GPT-3.5':
        return 'Fast and efficient, good for simple games';
      case 'Claude-3':
        return 'Great for story-driven games';
      case 'Gemini Pro':
        return 'Excellent for visual and creative elements';
      default:
        return 'AI model for game generation';
    }
  }

  void _generateGame() {
    context.go('/generation-progress');
  }
}

class _ColorPreviewDot extends StatelessWidget {
  final Color? color;
  const _ColorPreviewDot({required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color ?? cs.onSurface.withOpacity(0.10),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.8)),
      ),
    );
  }
}
