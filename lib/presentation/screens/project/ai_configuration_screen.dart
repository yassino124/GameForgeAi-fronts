import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/app_notifier.dart';
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
              color: (color ?? cs.surfaceContainerHighest),
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
  double _cameraZoom = 1.0;
  double _gravityY = 0.0;
  double _jumpForce = 0.0;

  final TextEditingController _primaryColorCtrl = TextEditingController(text: '#22C55E');
  final TextEditingController _secondaryColorCtrl = TextEditingController(text: '#3B82F6');
  final TextEditingController _accentColorCtrl = TextEditingController(text: '#F59E0B');
  final TextEditingController _playerColorCtrl = TextEditingController(text: '#F59E0B');

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
    if (patch is Map) return Map<String, dynamic>.from(patch);
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

    double cameraZoom = 1.0;
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
                patch = Map<String, dynamic>.from(decoded);
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

  Future<void> _pickColor({required String label, required TextEditingController controller}) async {
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
                color: c ?? cs.surfaceContainerHighest,
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
                                    color: _parseHexToColor(hex) ?? cs.surfaceContainerHighest,
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
      final res = await ProjectsService.createFromAi(
        token: token,
        prompt: prompt,
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
      AppNotifier.showError(_error ?? 'Failed to create project');
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _error = e.toString();
      });
      AppNotifier.showError(_friendlyError(_error ?? e.toString()));
    } finally {
      if (!context.mounted) return;
      setState(() {
        _creating = false;
      });
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
                  initialValue: _buildTarget,
                  decoration: const InputDecoration(),
                  items: const [
                    DropdownMenuItem(value: 'webgl', child: Text('Web (WebGL)')),
                    DropdownMenuItem(value: 'android_apk', child: Text('Android (APK)')),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Look'),
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
                Text('Palette presets', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _PalettePresetChip(
                        label: 'Neon',
                        colors: const ['#22C55E', '#3B82F6', '#F59E0B'],
                        enabled: !_creating,
                        onTap: () {
                          setState(() {
                            _primaryColorCtrl.text = '#22C55E';
                            _secondaryColorCtrl.text = '#3B82F6';
                            _accentColorCtrl.text = '#F59E0B';
                            _playerColorCtrl.text = '#F59E0B';
                          });
                        },
                      ),
                      _PalettePresetChip(
                        label: 'Cyber',
                        colors: const ['#00E5FF', '#7C4DFF', '#FF1744'],
                        enabled: !_creating,
                        onTap: () {
                          setState(() {
                            _primaryColorCtrl.text = '#00E5FF';
                            _secondaryColorCtrl.text = '#7C4DFF';
                            _accentColorCtrl.text = '#FF1744';
                            _playerColorCtrl.text = '#FF1744';
                          });
                        },
                      ),
                      _PalettePresetChip(
                        label: 'Pastel',
                        colors: const ['#A7F3D0', '#BFDBFE', '#FBCFE8'],
                        enabled: !_creating,
                        onTap: () {
                          setState(() {
                            _primaryColorCtrl.text = '#A7F3D0';
                            _secondaryColorCtrl.text = '#BFDBFE';
                            _accentColorCtrl.text = '#FBCFE8';
                            _playerColorCtrl.text = '#FBCFE8';
                          });
                        },
                      ),
                      _PalettePresetChip(
                        label: 'Dark',
                        colors: const ['#0EA5E9', '#A78BFA', '#22C55E'],
                        enabled: !_creating,
                        onTap: () {
                          setState(() {
                            _primaryColorCtrl.text = '#0EA5E9';
                            _secondaryColorCtrl.text = '#A78BFA';
                            _accentColorCtrl.text = '#22C55E';
                            _playerColorCtrl.text = '#22C55E';
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
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

  @override
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
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: AppSpacing.paddingLarge,
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
                    return _buildAdvancedTab();
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
            activeThumbColor: cs.primary,
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
