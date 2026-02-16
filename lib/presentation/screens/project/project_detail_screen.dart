import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/build_monitor_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/projects_service.dart';
import '../../../core/services/app_notifier.dart';
import '../../widgets/widgets.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const ProjectDetailScreen({
    super.key,
    required this.data,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _project;
  bool _loading = false;
  String? _error;

  bool _savingEdits = false;
  bool _loadingPreviewUrl = false;
  bool _loadingDownloadUrl = false;

  late final AnimationController _heroGlow;

  @override
  void initState() {
    super.initState();
    _heroGlow = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
    _heroGlow.repeat();
    _project = widget.data['project'] is Map
        ? Map<String, dynamic>.from(widget.data['project'] as Map)
        : null;
    _loadIfNeeded();
  }

  String? _resolveMediaUrl(String? url) {
    if (url == null) return null;
    final raw = url.trim();
    if (raw.isEmpty) return null;

    try {
      final base = Uri.parse(ApiService.baseUrl);
      final baseOrigin = Uri(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null);

      if (raw.startsWith('/')) {
        return baseOrigin.resolve(raw).toString();
      }

      final u = Uri.parse(raw);
      if (!u.hasScheme) {
        return baseOrigin.resolve('/$raw').toString();
      }

      return baseOrigin.replace(path: u.path, query: u.query).toString();
    } catch (_) {
      return raw;
    }
  }

  @override
  void dispose() {
    _heroGlow.dispose();
    super.dispose();
  }

  Future<void> _downloadArtifact({required String label}) async {
    if (_loadingDownloadUrl) return;
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Session expired. Please sign in again.';
      });
      AppNotifier.showError(_error ?? 'Session expired');
      return;
    }
    final id = _projectId();
    if (id == null || id.isEmpty) {
      setState(() => _error = 'Missing project id');
      AppNotifier.showError(_error ?? 'Missing project id');
      return;
    }

    setState(() {
      _loadingDownloadUrl = true;
      _error = null;
    });

    try {
      final res = await ProjectsService.getProjectDownloadUrl(token: token, projectId: id);
      if (!mounted) return;
      final url = (res['data'] is Map) ? res['data']['url']?.toString() : null;
      if (res['success'] == true && url != null && url.trim().isNotEmpty) {
        final uri = Uri.parse(url);
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok) {
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        }
        AppNotifier.showSuccess('$label started');
        return;
      }
      setState(() {
        _error = res['message']?.toString() ?? 'Download not ready';
      });
      AppNotifier.showError(_error ?? 'Download not ready');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
      AppNotifier.showError(_error ?? e.toString());
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingDownloadUrl = false;
      });
    }
  }

  Widget _buildPlayCta(
    BuildContext context, {
    required String? statusRaw,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isReady = (statusRaw ?? '').toLowerCase() == 'ready';

    final btn = CustomButton(
      text: loading ? 'Loading…' : 'Play WebGL',
      onPressed: onPressed,
      type: ButtonType.primary,
      icon: const Icon(Icons.play_arrow_rounded),
      isFullWidth: true,
    );

    if (!isReady) return btn;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeInOut,
      builder: (context, t, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.32 * t),
                blurRadius: 28 * t,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: cs.secondary.withOpacity(0.18 * t),
                blurRadius: 46 * t,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        );
      },
      child: btn,
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget box({required double h, double? w, BorderRadius? r}) {
      return Container(
        height: h,
        width: w,
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.9),
          borderRadius: r ?? BorderRadius.circular(AppBorderRadius.large),
        ),
      );
    }

    return ShimmerLoading(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          box(h: 200),
          const SizedBox(height: AppSpacing.xxl),
          box(h: 24, w: 180, r: BorderRadius.circular(10)),
          const SizedBox(height: 10),
          box(h: 16, w: 260, r: BorderRadius.circular(10)),
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: [
              Expanded(child: box(h: 48, r: BorderRadius.circular(AppBorderRadius.medium))),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: box(h: 48, r: BorderRadius.circular(AppBorderRadius.medium))),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          box(h: 54, r: BorderRadius.circular(AppBorderRadius.medium)),
          const SizedBox(height: AppSpacing.xxl),
          box(h: 140),
          const SizedBox(height: AppSpacing.xxl),
          box(h: 160),
        ],
      ),
    );
  }

  Future<void> _rebuildProject() async {
    final id = _projectId();
    if (id == null || id.trim().isEmpty) {
      AppNotifier.showError('Missing project id');
      return;
    }

    context.go(
      '/build-configuration',
      extra: {
        'projectId': id,
      },
    );
  }

  Future<void> _playWebgl() async {
    if (_loadingPreviewUrl) return;
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Session expired. Please sign in again.';
      });
      AppNotifier.showError(_error ?? 'Session expired');
      return;
    }
    final id = _projectId();
    if (id == null || id.isEmpty) {
      setState(() => _error = 'Missing project id');
      AppNotifier.showError(_error ?? 'Missing project id');
      return;
    }

    setState(() {
      _loadingPreviewUrl = true;
      _error = null;
    });

    try {
      final res = await ProjectsService.getProjectPreviewUrl(token: token, projectId: id);
      if (!mounted) return;
      final url = (res['data'] is Map) ? res['data']['url']?.toString() : null;
      if (res['success'] == true && url != null && url.trim().isNotEmpty) {
        // Debug/validation: ensure URL contains projectId+token so Unity can fetch runtime-config.
        try {
          final u = Uri.parse(url);
          final qp = u.queryParameters;
          final hasPid = (qp['projectId'] ?? '').trim().isNotEmpty;
          final hasTok = (qp['token'] ?? '').trim().isNotEmpty;
          if (!hasPid || !hasTok) {
            AppNotifier.showError('Preview URL missing token/projectId. Rebuild project or restart backend.');
          }
        } catch (_) {}

        // Prefetch runtime config to confirm backend has the latest values.
        try {
          final cfgRes = await ProjectsService.getProjectRuntimeConfig(token: token, projectId: id);
          final cfg = (cfgRes['data'] is Map) ? Map<String, dynamic>.from(cfgRes['data'] as Map) : null;
          if (cfgRes['success'] == true && cfg != null) {
            final sp = cfg['speed']?.toString();
            final pc = cfg['primaryColor']?.toString();
            if (sp != null || pc != null) {
              AppNotifier.showSuccess('Runtime config: speed=${sp ?? '-'} color=${pc ?? '-'}');
            }
          }
        } catch (_) {}

        if (!mounted) return;
        context.go('/play-webgl', extra: {'url': url});
        return;
      }
      setState(() {
        _error = res['message']?.toString() ?? 'Preview not ready';
      });
      AppNotifier.showError(_error ?? 'Preview not ready');
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingPreviewUrl = false;
      });
    }
  }

  Future<void> _openEditProjectDialog() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Session expired. Please sign in again.');
      return;
    }

    final id = _projectId();
    if (id == null || id.isEmpty) {
      setState(() => _error = 'Missing project id');
      return;
    }

    final p = _project ?? <String, dynamic>{};
    final name = (p['name'] ?? widget.data['name'] ?? '').toString();
    final description = (p['description'] ?? widget.data['description'] ?? '').toString();

    final cfg = (p['aiUnityConfig'] is Map) ? Map<String, dynamic>.from(p['aiUnityConfig'] as Map) : <String, dynamic>{};
    final initialTimeScale = (cfg['timeScale'] is num) ? (cfg['timeScale'] as num).toDouble() : 1.0;
    final initialDifficulty = (cfg['difficulty'] is num) ? (cfg['difficulty'] as num).toDouble() : 0.5;
    final initialTheme = (cfg['theme'] ?? 'default').toString();
    final initialNotes = (cfg['notes'] ?? '').toString();

    final initialSpeed = (cfg['speed'] is num) ? (cfg['speed'] as num).toDouble() : 5.0;
    final initialGenre = (cfg['genre'] ?? 'platformer').toString();
    final initialAssetsType = (cfg['assetsType'] ?? 'lowpoly').toString();
    final initialMechanics = (cfg['mechanics'] is List)
        ? (cfg['mechanics'] as List).map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
        : <String>[];
    final initialPrimaryColor = (cfg['primaryColor'] ?? '#22C55E').toString();
    final initialSecondaryColor = (cfg['secondaryColor'] ?? '#3B82F6').toString();
    final initialAccentColor = (cfg['accentColor'] ?? '#F59E0B').toString();
    final initialPlayerColor = (cfg['playerColor'] ?? initialAccentColor).toString();

    final initialFogEnabled = (cfg['fogEnabled'] is bool) ? (cfg['fogEnabled'] as bool) : false;
    final initialFogDensity = (cfg['fogDensity'] is num) ? (cfg['fogDensity'] as num).toDouble() : 0.0;
    final initialCameraZoom = (cfg['cameraZoom'] is num) ? (cfg['cameraZoom'] as num).toDouble() : 0.0;
    final initialGravityY = (cfg['gravityY'] is num) ? (cfg['gravityY'] as num).toDouble() : 0.0;
    final initialJumpForce = (cfg['jumpForce'] is num) ? (cfg['jumpForce'] as num).toDouble() : 0.0;

    final nameCtrl = TextEditingController(text: name);
    final descCtrl = TextEditingController(text: description);

    double dialogTimeScale = initialTimeScale.clamp(0.5, 2.0);
    double dialogDifficulty = initialDifficulty.clamp(0.0, 1.0);
    double dialogSpeed = initialSpeed.clamp(0.0, 20.0);

    bool dialogFogEnabled = initialFogEnabled;
    double dialogFogDensity = initialFogDensity.clamp(0.0, 0.1);
    double dialogCameraZoom = initialCameraZoom.clamp(0.0, 30.0);
    double dialogGravityY = initialGravityY.clamp(-50.0, 0.0);
    double dialogJumpForce = initialJumpForce.clamp(0.0, 50.0);
    final themeCtrl = TextEditingController(text: initialTheme);
    final runtimeNotesCtrl = TextEditingController(text: initialNotes);

    final genreCtrl = TextEditingController(text: initialGenre);
    final assetsTypeCtrl = TextEditingController(text: initialAssetsType);
    final mechanicsCtrl = TextEditingController(text: initialMechanics.join(', '));
    final primaryColorCtrl = TextEditingController(text: initialPrimaryColor);
    final secondaryColorCtrl = TextEditingController(text: initialSecondaryColor);
    final accentColorCtrl = TextEditingController(text: initialAccentColor);
    final playerColorCtrl = TextEditingController(text: initialPlayerColor);

    File? dialogPreviewImage;
    List<File> dialogScreenshots = [];
    File? dialogPreviewVideo;

    final aiNotesCtrl = TextEditingController();
    bool aiOverwrite = false;
    bool generatingAi = false;
    Map<String, dynamic>? aiPreview;

    try {
      final res = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          final cs = Theme.of(context).colorScheme;

          final colorPresets = <Map<String, String>>[
            {
              'name': 'Neon',
              'primary': '#22C55E',
              'secondary': '#3B82F6',
              'accent': '#F59E0B',
            },
            {
              'name': 'Cyber',
              'primary': '#00E5FF',
              'secondary': '#7C4DFF',
              'accent': '#FF1744',
            },
            {
              'name': 'Pastel',
              'primary': '#A7F3D0',
              'secondary': '#BFDBFE',
              'accent': '#FBCFE8',
            },
            {
              'name': 'Dark',
              'primary': '#111827',
              'secondary': '#1F2937',
              'accent': '#F59E0B',
            },
          ];

          final gameplayPresets = <Map<String, dynamic>>[
            {'name': 'Chill', 'speed': 4.0, 'difficulty': 0.30, 'timeScale': 0.90},
            {'name': 'Normal', 'speed': 7.0, 'difficulty': 0.50, 'timeScale': 1.00},
            {'name': 'Hardcore', 'speed': 12.0, 'difficulty': 0.85, 'timeScale': 1.10},
          ];

          void applyColorPreset(Map<String, String> p) {
            primaryColorCtrl.text = p['primary'] ?? primaryColorCtrl.text;
            secondaryColorCtrl.text = p['secondary'] ?? secondaryColorCtrl.text;
            accentColorCtrl.text = p['accent'] ?? accentColorCtrl.text;
            playerColorCtrl.text = p['player'] ?? (p['accent'] ?? playerColorCtrl.text);
          }

          String _toHex(Color c) {
            final rgb = c.value & 0x00FFFFFF;
            return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
          }

          Future<void> _pasteHexInto(TextEditingController ctrl) async {
            final d = await Clipboard.getData('text/plain');
            final raw = d?.text;
            if (raw == null) return;
            var s = raw.trim();
            if (s.isEmpty) return;
            if (!s.startsWith('#')) s = '#$s';
            if (s.length != 7) return;
            if (_ColorDot.parseHex(s) == null) return;
            ctrl.text = s.toUpperCase();
          }

          Future<void> _pickColorFor(TextEditingController ctrl) async {
            final initial = _ColorDot.parseHex(ctrl.text) ?? Theme.of(context).colorScheme.primary;
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
            ctrl.text = _toHex(picked);
          }

          final neonSliderTheme = SliderThemeData(
            trackHeight: 4,
            activeTrackColor: cs.secondary,
            inactiveTrackColor: cs.outlineVariant.withOpacity(0.55),
            thumbColor: cs.primary,
            overlayColor: cs.secondary.withOpacity(0.18),
            valueIndicatorColor: cs.surface,
            valueIndicatorTextStyle: AppTypography.caption.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800),
          );

          Widget tabScaffold({required List<Widget> children}) {
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SliderTheme(
                data: neonSliderTheme,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: children,
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 440,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.82,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.surface.withOpacity(0.86),
                        cs.surfaceVariant.withOpacity(0.78),
                      ],
                    ),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.22),
                        blurRadius: 26,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: DefaultTabController(
                    length: (auth.isAdmin || auth.isDevl) ? 5 : 4,
                    child: StatefulBuilder(
                      builder: (context, setDialogState) {
                        final tabLabels = <Tab>[
                          const Tab(text: 'Gameplay'),
                          const Tab(text: 'Look'),
                          const Tab(text: 'Physics'),
                          const Tab(text: 'Media'),
                          if (auth.isAdmin || auth.isDevl) const Tab(text: 'AI'),
                        ];

                        final tabs = <Widget>[
                          tabScaffold(
                            children: [
                            TextField(
                              controller: nameCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(labelText: 'Name'),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextField(
                              controller: descCtrl,
                              minLines: 2,
                              maxLines: 5,
                              decoration: const InputDecoration(labelText: 'Description'),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: gameplayPresets
                                  .map(
                                    (p) => ActionChip(
                                      label: Text(p['name']?.toString() ?? 'Preset'),
                                      onPressed: _savingEdits
                                          ? null
                                          : () {
                                              setDialogState(() {
                                                dialogSpeed = (p['speed'] as num).toDouble().clamp(0.0, 20.0);
                                                dialogDifficulty = (p['difficulty'] as num).toDouble().clamp(0.0, 1.0);
                                                dialogTimeScale = (p['timeScale'] as num).toDouble().clamp(0.5, 2.0);
                                              });
                                            },
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Speed',
                                  style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                dialogSpeed.toStringAsFixed(1),
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                          Slider(
                            value: dialogSpeed,
                            min: 0,
                            max: 20,
                            divisions: 200,
                            onChanged: _savingEdits
                                ? null
                                : (v) {
                                    setDialogState(() {
                                      dialogSpeed = v;
                                    });
                                  },
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Difficulty',
                                  style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                dialogDifficulty.toStringAsFixed(2),
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                          Slider(
                            value: dialogDifficulty,
                            min: 0,
                            max: 1,
                            divisions: 100,
                            onChanged: _savingEdits
                                ? null
                                : (v) {
                                    setDialogState(() {
                                      dialogDifficulty = v;
                                    });
                                  },
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Time scale',
                                  style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                dialogTimeScale.toStringAsFixed(2),
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                          Slider(
                            value: dialogTimeScale,
                            min: 0.5,
                            max: 2.0,
                            divisions: 150,
                            onChanged: _savingEdits
                                ? null
                                : (v) {
                                    setDialogState(() {
                                      dialogTimeScale = v;
                                    });
                                  },
                          ),
                          TextField(
                            controller: themeCtrl,
                            decoration: const InputDecoration(labelText: 'Theme'),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: genreCtrl,
                            decoration: const InputDecoration(labelText: 'Genre'),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: assetsTypeCtrl,
                            decoration: const InputDecoration(labelText: 'Assets type'),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: mechanicsCtrl,
                            decoration: const InputDecoration(labelText: 'Mechanics (comma separated)'),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: runtimeNotesCtrl,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(labelText: 'Runtime notes (optional)'),
                          ),
                            ],
                          ),
                          tabScaffold(
                            children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: colorPresets
                                    .map(
                                      (p) => ActionChip(
                                        label: Text(p['name'] ?? 'Preset'),
                                        onPressed: _savingEdits
                                            ? null
                                            : () {
                                                setDialogState(() {
                                                  applyColorPreset(p);
                                                });
                                              },
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: primaryColorCtrl,
                                    decoration: const InputDecoration(labelText: 'Primary (#RRGGBB)'),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                _ColorDot(valueListenable: primaryColorCtrl),
                                const SizedBox(width: 6),
                                IconButton(
                                  tooltip: 'Paste',
                                  onPressed: _savingEdits ? null : () => _pasteHexInto(primaryColorCtrl),
                                  icon: const Icon(Icons.content_paste_rounded, size: 18),
                                ),
                                IconButton(
                                  tooltip: 'Pick',
                                  onPressed: _savingEdits ? null : () => _pickColorFor(primaryColorCtrl),
                                  icon: const Icon(Icons.color_lens_rounded, size: 18),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: secondaryColorCtrl,
                                    decoration: const InputDecoration(labelText: 'Secondary (#RRGGBB)'),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                _ColorDot(valueListenable: secondaryColorCtrl),
                                const SizedBox(width: 6),
                                IconButton(
                                  tooltip: 'Paste',
                                  onPressed: _savingEdits ? null : () => _pasteHexInto(secondaryColorCtrl),
                                  icon: const Icon(Icons.content_paste_rounded, size: 18),
                                ),
                                IconButton(
                                  tooltip: 'Pick',
                                  onPressed: _savingEdits ? null : () => _pickColorFor(secondaryColorCtrl),
                                  icon: const Icon(Icons.color_lens_rounded, size: 18),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: accentColorCtrl,
                                    decoration: const InputDecoration(labelText: 'Accent (#RRGGBB)'),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                _ColorDot(valueListenable: accentColorCtrl),
                                const SizedBox(width: 6),
                                IconButton(
                                  tooltip: 'Paste',
                                  onPressed: _savingEdits ? null : () => _pasteHexInto(accentColorCtrl),
                                  icon: const Icon(Icons.content_paste_rounded, size: 18),
                                ),
                                IconButton(
                                  tooltip: 'Pick',
                                  onPressed: _savingEdits ? null : () => _pickColorFor(accentColorCtrl),
                                  icon: const Icon(Icons.color_lens_rounded, size: 18),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: playerColorCtrl,
                                    decoration: const InputDecoration(labelText: 'Player color (#RRGGBB)'),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                _ColorDot(valueListenable: playerColorCtrl),
                                const SizedBox(width: 6),
                                IconButton(
                                  tooltip: 'Paste',
                                  onPressed: _savingEdits ? null : () => _pasteHexInto(playerColorCtrl),
                                  icon: const Icon(Icons.content_paste_rounded, size: 18),
                                ),
                                IconButton(
                                  tooltip: 'Pick',
                                  onPressed: _savingEdits ? null : () => _pickColorFor(playerColorCtrl),
                                  icon: const Icon(Icons.color_lens_rounded, size: 18),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Fog',
                                    style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Switch(
                                  value: dialogFogEnabled,
                                  onChanged: _savingEdits
                                      ? null
                                      : (v) {
                                          setDialogState(() {
                                            dialogFogEnabled = v;
                                          });
                                        },
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Fog density',
                                    style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(dialogFogDensity.toStringAsFixed(4), style: AppTypography.caption),
                              ],
                            ),
                            Slider(
                              value: dialogFogDensity,
                              min: 0.0,
                              max: 0.1,
                              divisions: 100,
                              onChanged: _savingEdits
                                  ? null
                                  : (v) {
                                      setDialogState(() {
                                        dialogFogDensity = v;
                                      });
                                    },
                            ),
                            ],
                          ),
                          tabScaffold(
                            children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Zoom (orthographic size)',
                                    style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  dialogCameraZoom <= 0 ? 'auto' : dialogCameraZoom.toStringAsFixed(1),
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                            Slider(
                              value: dialogCameraZoom,
                              min: 0.0,
                              max: 30.0,
                              divisions: 300,
                              onChanged: _savingEdits
                                  ? null
                                  : (v) {
                                      setDialogState(() {
                                        dialogCameraZoom = v;
                                      });
                                    },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Gravity Y',
                                    style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  dialogGravityY == 0 ? 'default' : dialogGravityY.toStringAsFixed(1),
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                            Slider(
                              value: dialogGravityY,
                              min: -50.0,
                              max: 0.0,
                              divisions: 200,
                              onChanged: _savingEdits
                                  ? null
                                  : (v) {
                                      setDialogState(() {
                                        dialogGravityY = v;
                                      });
                                    },
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Jump force',
                                    style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  dialogJumpForce == 0 ? 'default' : dialogJumpForce.toStringAsFixed(1),
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                            Slider(
                              value: dialogJumpForce,
                              min: 0.0,
                              max: 50.0,
                              divisions: 250,
                              onChanged: _savingEdits
                                  ? null
                                  : (v) {
                                      setDialogState(() {
                                        dialogJumpForce = v;
                                      });
                                    },
                            ),
                            ],
                          ),
                          tabScaffold(
                            children: [
                            Builder(
                              builder: (_) {
                                String fileName(File? f) {
                                  if (f == null) return '';
                                  final p = f.path;
                                  final parts = p.split('/');
                                  return parts.isNotEmpty ? parts.last : p;
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            dialogPreviewImage == null ? 'No new preview image' : fileName(dialogPreviewImage),
                                            style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        CustomButton(
                                          text: 'Image',
                                          onPressed: _savingEdits
                                              ? null
                                              : () async {
                                                  final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
                                                  if (r == null || r.files.isEmpty) return;
                                                  final p = r.files.single.path;
                                                  if (p == null || p.isEmpty) return;
                                                  setDialogState(() {
                                                    dialogPreviewImage = File(p);
                                                  });
                                                },
                                          isFullWidth: false,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            dialogScreenshots.isEmpty ? 'No new screenshots' : '${dialogScreenshots.length} screenshot(s) selected',
                                            style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        CustomButton(
                                          text: 'Shots',
                                          onPressed: _savingEdits
                                              ? null
                                              : () async {
                                                  final r = await FilePicker.platform.pickFiles(
                                                    type: FileType.image,
                                                    allowMultiple: true,
                                                    withData: true,
                                                  );
                                                  if (r == null || r.files.isEmpty) return;
                                                  final files = r.files
                                                      .map((f) => f.path)
                                                      .whereType<String>()
                                                      .where((p) => p.isNotEmpty)
                                                      .map((p) => File(p))
                                                      .toList();
                                                  if (files.isEmpty) return;
                                                  setDialogState(() {
                                                    dialogScreenshots = files;
                                                  });
                                                },
                                          isFullWidth: false,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            dialogPreviewVideo == null ? 'No new preview video' : fileName(dialogPreviewVideo),
                                            style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        CustomButton(
                                          text: 'Video',
                                          onPressed: _savingEdits
                                              ? null
                                              : () async {
                                                  final r = await FilePicker.platform.pickFiles(type: FileType.video, withData: true);
                                                  if (r == null || r.files.isEmpty) return;
                                                  final p = r.files.single.path;
                                                  if (p == null || p.isEmpty) return;
                                                  setDialogState(() {
                                                    dialogPreviewVideo = File(p);
                                                  });
                                                },
                                          isFullWidth: false,
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                            ],
                          ),
                        ];

                        if (auth.isAdmin || auth.isDevl) {
                          tabs.add(
                            tabScaffold(
                              children: [
                              TextField(
                                controller: aiNotesCtrl,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Overwrite project description',
                                      style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Switch(
                                    value: aiOverwrite,
                                    onChanged: (generatingAi || _savingEdits)
                                        ? null
                                        : (v) {
                                            setDialogState(() {
                                              aiOverwrite = v;
                                            });
                                          },
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              CustomButton(
                                text: generatingAi ? 'Generating…' : 'Generate with Gemini',
                                onPressed: (generatingAi || _savingEdits)
                                    ? null
                                    : () async {
                                        if (token.isEmpty) return;
                                        setDialogState(() {
                                          generatingAi = true;
                                        });
                                        try {
                                          final notes = aiNotesCtrl.text.trim();
                                          final aiRes = await ProjectsService.generateProjectAiMetadata(
                                            token: token,
                                            projectId: id,
                                            notes: notes.isEmpty ? null : notes,
                                            overwrite: aiOverwrite,
                                          );

                                          final data = aiRes['data'];
                                          if (aiRes['success'] == true && data is Map) {
                                            setDialogState(() {
                                              aiPreview = Map<String, dynamic>.from(data);
                                              if (aiOverwrite) {
                                                final newDesc = data['description']?.toString();
                                                if (newDesc != null) {
                                                  descCtrl.text = newDesc;
                                                }
                                              }
                                            });
                                          }
                                        } finally {
                                          if (context.mounted) {
                                            setDialogState(() {
                                              generatingAi = false;
                                            });
                                          }
                                        }
                                      },
                                isFullWidth: true,
                              ),
                              if (aiPreview != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Builder(
                                  builder: (_) {
                                    final ai = (aiPreview?['aiMetadata'] is Map)
                                        ? Map<String, dynamic>.from(aiPreview?['aiMetadata'] as Map)
                                        : null;
                                    if (ai == null) return const SizedBox.shrink();
                                    final tags = (ai['tags'] is List)
                                        ? (ai['tags'] as List).map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
                                        : <String>[];

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if ((ai['description']?.toString() ?? '').trim().isNotEmpty)
                                          Text(
                                            ai['description'].toString(),
                                            style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                                          ),
                                        if (tags.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tags: ${tags.join(', ')}',
                                            style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ],
                              ],
                            ),
                          );
                        }

                        void popIfValid(String action) {
                          final newName = nameCtrl.text.trim();
                          if (newName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Name is required'),
                                backgroundColor: cs.error,
                              ),
                            );
                            return;
                          }
                          Navigator.of(context).pop(action);
                        }

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Edit Project',
                                      style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w900),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _savingEdits ? null : () => Navigator.of(context).pop(null),
                                    icon: Icon(Icons.close_rounded, color: cs.onSurface),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: LinearGradient(
                                    colors: [
                                      cs.primary.withOpacity(0.18),
                                      cs.secondary.withOpacity(0.10),
                                    ],
                                  ),
                                  border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
                                ),
                                child: TabBar(
                                  tabs: tabLabels,
                                  isScrollable: true,
                                  indicator: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    gradient: AppColors.primaryGradient,
                                    boxShadow: [
                                      BoxShadow(
                                        color: cs.primary.withOpacity(0.22),
                                        blurRadius: 16,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  labelColor: cs.onPrimary,
                                  unselectedLabelColor: cs.onSurfaceVariant,
                                  labelStyle: AppTypography.caption.copyWith(fontWeight: FontWeight.w900),
                                  dividerColor: Colors.transparent,
                                  indicatorPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                child: TabBarView(children: tabs),
                              ),
                            ),
                            SafeArea(
                              top: false,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: _savingEdits ? null : () => Navigator.of(context).pop(null),
                                            child: const Text('Cancel'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _savingEdits ? null : () => popIfValid('save'),
                                            icon: const Icon(Icons.save),
                                            label: const Text('Save'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _savingEdits ? null : () => popIfValid('save_rebuild'),
                                        icon: const Icon(Icons.rocket_launch_rounded),
                                        label: const Text('Save & Rebuild'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

      if (res == null || res.trim().isEmpty) return;
      if (!mounted) return;
      setState(() {
        _savingEdits = true;
        _error = null;
      });

      final updateRes = await ProjectsService.updateProject(
        token: token,
        projectId: id,
        name: nameCtrl.text,
        description: descCtrl.text,
        timeScale: dialogTimeScale,
        difficulty: dialogDifficulty,
        theme: themeCtrl.text,
        notes: runtimeNotesCtrl.text,
        speed: dialogSpeed,
        genre: genreCtrl.text,
        assetsType: assetsTypeCtrl.text,
        mechanics: mechanicsCtrl.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        primaryColor: primaryColorCtrl.text,
        secondaryColor: secondaryColorCtrl.text,
        accentColor: accentColorCtrl.text,
        playerColor: playerColorCtrl.text,
        fogEnabled: dialogFogEnabled,
        fogDensity: dialogFogDensity,
        cameraZoom: dialogCameraZoom,
        gravityY: dialogGravityY,
        jumpForce: dialogJumpForce,
      );
      if (!mounted) return;
      final data = updateRes['data'];
      if (updateRes['success'] == true && data is Map) {
        setState(() {
          _project = Map<String, dynamic>.from(data);
        });

        // Upload media if provided
        if (dialogPreviewImage != null || dialogScreenshots.isNotEmpty || dialogPreviewVideo != null) {
          try {
            final mediaRes = await ProjectsService.uploadProjectMedia(
              token: token,
              projectId: id,
              previewImage: dialogPreviewImage,
              screenshots: dialogScreenshots,
              previewVideo: dialogPreviewVideo,
            );
            if (!mounted) return;
            final mData = mediaRes['data'];
            if (mediaRes['success'] == true && mData is Map) {
              setState(() {
                _project = Map<String, dynamic>.from(mData);
              });
            } else {
              setState(() {
                _error = mediaRes['message']?.toString() ?? 'Media upload failed';
              });
              AppNotifier.showError(_error ?? 'Media upload failed');
            }
          } catch (e) {
            if (!mounted) return;
            setState(() {
              _error = e.toString();
            });
            AppNotifier.showError(_error ?? e.toString());
          }
        }

        if (res == 'save_rebuild') {
          try {
            await ProjectsService.rebuildProject(token: token, projectId: id);
          } catch (_) {}
          if (!mounted) return;
          try {
            context.read<BuildMonitorProvider>().startMonitoring(token: token, projectId: id);
          } catch (_) {}
          context.go(
            '/build-progress',
            extra: {
              'projectId': id,
              'buildQueue': const <String>['webgl'],
              'buildIndex': 0,
            },
          );
        }
      } else {
        setState(() {
          _error = updateRes['message']?.toString() ?? 'Update failed';
        });
        AppNotifier.showError(_error ?? 'Update failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
      AppNotifier.showError(_error ?? e.toString());
    } finally {
      // The dialog route can still be animating out even after showDialog completes.
      // Defer controller disposal to avoid "used after being disposed" during teardown.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          nameCtrl.dispose();
        } catch (_) {}
        try {
          descCtrl.dispose();
        } catch (_) {}
        try {
          aiNotesCtrl.dispose();
        } catch (_) {}
        try {
          themeCtrl.dispose();
        } catch (_) {}
        try {
          runtimeNotesCtrl.dispose();
        } catch (_) {}
        try {
          genreCtrl.dispose();
        } catch (_) {}
        try {
          assetsTypeCtrl.dispose();
        } catch (_) {}
        try {
          mechanicsCtrl.dispose();
        } catch (_) {}
        try {
          primaryColorCtrl.dispose();
        } catch (_) {}
        try {
          secondaryColorCtrl.dispose();
        } catch (_) {}
        try {
          accentColorCtrl.dispose();
        } catch (_) {}
        try {
          playerColorCtrl.dispose();
        } catch (_) {}
      });
      if (!mounted) return;
      setState(() {
        _savingEdits = false;
      });
    }
  }

  Future<void> _openVideoPlayer(String url) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _VideoPlayerDialog(url: url),
    );
  }

  String? _projectId() {
    final fromRoute = widget.data['projectId']?.toString();
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;
    final p = _project;
    final id = p?['_id']?.toString() ?? p?['id']?.toString();
    return (id != null && id.isNotEmpty) ? id : null;
  }

  Future<void> _loadIfNeeded({bool force = false}) async {
    final projectId = widget.data['projectId']?.toString();
    if (projectId == null || projectId.isEmpty) return;
    if (!force &&
        _project != null &&
        (_project?['_id']?.toString() == projectId || _project?['id']?.toString() == projectId)) {
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ProjectsService.getProject(token: token, projectId: projectId);
      final data = res['data'];
      if (!mounted) return;
      setState(() {
        _project = data is Map ? Map<String, dynamic>.from(data as Map) : <String, dynamic>{};
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    context.watch<AuthProvider>();

    final p = _project ?? <String, dynamic>{};
    final cfg = (p['aiUnityConfig'] is Map) ? Map<String, dynamic>.from(p['aiUnityConfig'] as Map) : <String, dynamic>{};
    final buildTimings = (p['buildTimings'] is Map) ? Map<String, dynamic>.from(p['buildTimings'] as Map) : null;
    final buildTarget = (p['buildTarget']?.toString() ?? 'webgl').toLowerCase();
    final isAndroidApk = buildTarget == 'android_apk' || buildTarget == 'android';
    final name = (p['name'] ?? widget.data['name'] ?? 'Project').toString();
    final description = (p['description'] ?? widget.data['description'] ?? '').toString();
    final statusRaw = p['status']?.toString().toLowerCase();
    final statusText = statusRaw == null || statusRaw.isEmpty
        ? 'Unknown'
        : (statusRaw == 'ready'
            ? 'Completed'
            : (statusRaw == 'running' || statusRaw == 'queued')
                ? 'In Progress'
                : statusRaw == 'failed'
                    ? 'Failed'
                    : statusRaw);
    final statusColor = statusRaw == 'ready'
        ? AppColors.success
        : statusRaw == 'failed'
            ? AppColors.error
            : (statusRaw == 'running' || statusRaw == 'queued')
                ? AppColors.warning
                : cs.onSurfaceVariant;

    final previewImageUrl = _resolveMediaUrl(p['previewImageUrl']?.toString());
    final screenshotUrlsRaw = p['screenshotUrls'];
    final screenshotUrls = (screenshotUrlsRaw is List)
        ? screenshotUrlsRaw
            .map((e) => _resolveMediaUrl(e?.toString()) ?? '')
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];
    final previewVideoUrl = _resolveMediaUrl(p['previewVideoUrl']?.toString());

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          name,
          style: AppTypography.subtitle1,
        ),
        leading: IconButton(
          onPressed: () => context.go('/dashboard'),
          icon: Icon(
            Icons.arrow_back,
            color: cs.onSurface,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              final id = _projectId();
              final p = _project ?? <String, dynamic>{};
              final name = (p['name'] ?? widget.data['name'] ?? '').toString();
              if (id == null || id.isEmpty) {
                AppNotifier.showError('Missing project id');
                return;
              }
              context.push(
                '/ai-coach',
                extra: {
                  'projectId': id,
                  'projectName': name,
                },
              );
            },
            icon: Icon(
              Icons.mic_rounded,
              color: cs.onSurface,
            ),
          ),
          IconButton(
            onPressed: () {
              _openEditProjectDialog();
            },
            icon: Icon(
              Icons.edit,
              color: cs.onSurface,
            ),
          ),
          IconButton(
            onPressed: () {
              // TODO: Share project
              final id = _projectId();
              final p = _project ?? <String, dynamic>{};
              final name = (p['name'] ?? widget.data['name'] ?? 'Project').toString();
              final description = (p['description'] ?? widget.data['description'] ?? '').toString();
              final text = [
                name,
                if (description.trim().isNotEmpty) description.trim(),
                if (id != null && id.isNotEmpty) 'Project ID: $id',
              ].join('\n\n');
              Share.share(text);
            },
            icon: Icon(
              Icons.share,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
      
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading) ...[
              _buildLoadingSkeleton(context),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
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
              const SizedBox(height: AppSpacing.lg),
            ],
            // Hero image/preview
            AnimatedCard(
              delay: const Duration(milliseconds: 40),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  gradient: AppColors.primaryGradient,
                  boxShadow: AppShadows.boxShadowLarge,
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _heroGlow,
                          builder: (context, _) {
                            final phase = _heroGlow.value;
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-1 + phase * 2, -1),
                                  end: Alignment(1 - phase * 2, 1),
                                  colors: [
                                    cs.primary.withOpacity(0.18),
                                    Colors.transparent,
                                    cs.secondary.withOpacity(0.14),
                                  ],
                                  stops: const [0.0, 0.55, 1.0],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (previewImageUrl != null && previewImageUrl.trim().isNotEmpty)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppBorderRadius.large),
                          child: Image.network(
                            previewImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: cs.onPrimary.withOpacity(0.12),
                                  ),
                                  child: Icon(
                                    Icons.games,
                                    size: 50,
                                    color: cs.onPrimary,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    else
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.onPrimary.withOpacity(0.12),
                          ),
                          child: Icon(
                            Icons.games,
                            size: 50,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),

                    // Play button overlay
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: CustomButton(
                        text: 'Play',
                        onPressed: (previewVideoUrl == null || previewVideoUrl.trim().isEmpty)
                            ? null
                            : () async {
                                await _openVideoPlayer(previewVideoUrl);
                              },
                        type: ButtonType.primary,
                        size: ButtonSize.small,
                        icon: const Icon(Icons.play_arrow),
                      ),
                    ),

                    Positioned(
                      top: 16,
                      left: 16,
                      child: AnimatedBuilder(
                        animation: _heroGlow,
                        builder: (context, _) {
                          final ready = statusRaw == 'ready';
                          final t = ready ? (0.75 + 0.25 * (0.5 + 0.5 * math.sin(_heroGlow.value * 2 * math.pi))) : 1.0;
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, anim) {
                              return FadeTransition(
                                opacity: anim,
                                child: SizeTransition(
                                  sizeFactor: anim,
                                  axis: Axis.horizontal,
                                  axisAlignment: -1,
                                  child: child,
                                ),
                              );
                            },
                            child: Container(
                              key: ValueKey('${statusText}_${statusColor.value}'),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: cs.surface.withOpacity(0.78),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
                                boxShadow: [
                                  ...AppShadows.boxShadowSmall,
                                  if (ready)
                                    BoxShadow(
                                      color: cs.primary.withOpacity(0.22 * t),
                                      blurRadius: 26 * t,
                                      offset: const Offset(0, 12),
                                    ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    statusText,
                                    style: AppTypography.caption.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
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
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxl),

            Text(
              name,
              style: AppTypography.h2,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description.isEmpty ? 'No description yet' : description,
              style: AppTypography.body1.copyWith(color: cs.onSurfaceVariant, height: 1.5),
            ),
            
            const SizedBox(height: AppSpacing.xxl),

            Text('Quick actions', style: AppTypography.subtitle1),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Edit',
                    onPressed: _openEditProjectDialog,
                    type: ButtonType.secondary,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: CustomButton(
                    text: 'Rebuild',
                    onPressed: _rebuildProject,
                    type: ButtonType.secondary,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (isAndroidApk) ...[
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.75, end: 1.0),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeInOut,
                builder: (context, t, child) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withOpacity(0.22 * t),
                          blurRadius: 26 * t,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: cs.secondary.withOpacity(0.14 * t),
                          blurRadius: 44 * t,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: CustomButton(
                  text: _loadingDownloadUrl ? 'Loading…' : 'Download APK',
                  onPressed: _loadingDownloadUrl ? null : () => _downloadArtifact(label: 'Download'),
                  type: ButtonType.primary,
                  icon: const Icon(Icons.download_rounded),
                  isFullWidth: true,
                ),
              ),
            ] else ...[
              _buildPlayCta(
                context,
                statusRaw: statusRaw,
                loading: _loadingPreviewUrl,
                onPressed: _loadingPreviewUrl ? null : _playWebgl,
              ),
              const SizedBox(height: AppSpacing.md),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.75, end: 1.0),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeInOut,
                builder: (context, t, child) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withOpacity(0.14 * t),
                          blurRadius: 22 * t,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: cs.secondary.withOpacity(0.10 * t),
                          blurRadius: 36 * t,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: CustomButton(
                  text: _loadingDownloadUrl ? 'Loading…' : 'Download ZIP',
                  onPressed: _loadingDownloadUrl ? null : () => _downloadArtifact(label: 'Download'),
                  type: ButtonType.secondary,
                  icon: const Icon(Icons.download_rounded),
                  isFullWidth: true,
                ),
              ),
            ],
            
            const SizedBox(height: AppSpacing.xxl),

            Text('Runtime tuning', style: AppTypography.subtitle1),
            const SizedBox(height: AppSpacing.md),
            AnimatedCard(
              delay: const Duration(milliseconds: 90),
              child: _buildInfoCard(
                context,
                title: 'Live parameters',
                subtitle: 'Update from Edit → save → rebuild (first time) → play',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildValueChip(context, label: 'Speed', value: cfg['speed']?.toString()),
                    _buildValueChip(context, label: 'Difficulty', value: cfg['difficulty']?.toString()),
                    _buildValueChip(context, label: 'Time', value: cfg['timeScale']?.toString()),
                    _buildValueChip(context, label: 'Fog', value: (cfg['fogEnabled'] == true) ? 'on' : 'off'),
                    _buildValueChip(context, label: 'Fog density', value: cfg['fogDensity']?.toString()),
                    _buildValueChip(context, label: 'Zoom', value: cfg['cameraZoom']?.toString()),
                    _buildValueChip(context, label: 'Gravity', value: cfg['gravityY']?.toString()),
                    _buildValueChip(context, label: 'Jump', value: cfg['jumpForce']?.toString()),
                    _buildColorChip(context, label: 'Primary', hex: cfg['primaryColor']?.toString()),
                    _buildColorChip(context, label: 'Secondary', hex: cfg['secondaryColor']?.toString()),
                    _buildColorChip(context, label: 'Accent', hex: cfg['accentColor']?.toString()),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxl),

            Text('Build', style: AppTypography.subtitle1),
            const SizedBox(height: AppSpacing.md),
            AnimatedCard(
              delay: const Duration(milliseconds: 140),
              child: _buildInfoCard(
                context,
                title: 'Build status',
                subtitle: statusText,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusRaw ?? 'unknown',
                    style: AppTypography.caption.copyWith(color: statusColor, fontWeight: FontWeight.w800),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (statusRaw == 'failed' && (p['error']?.toString().trim().isNotEmpty ?? false)) ...[
                      Text(
                        p['error']?.toString() ?? '',
                        style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant, height: 1.4),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (buildTimings != null) ...[
                      _buildKeyValueRow(context, 'Started', buildTimings['startedAt']?.toString()),
                      _buildKeyValueRow(context, 'Finished', buildTimings['finishedAt']?.toString()),
                      _buildKeyValueRow(context, 'Duration', buildTimings['durationMs']?.toString()),
                      if (buildTimings['steps'] is Map) ...[
                        const SizedBox(height: AppSpacing.sm),
                        ...Map<String, dynamic>.from(buildTimings['steps'] as Map).entries.map(
                          (e) => _buildKeyValueRow(context, e.key, '${e.value}ms'),
                        ),
                      ],
                    ] else ...[
                      Text(
                        'No build timings yet.',
                        style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            
            // Screenshots
            Text(
              'Screenshots',
              style: AppTypography.subtitle1,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (screenshotUrls.isEmpty)
              Text(
                'No screenshots',
                style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: screenshotUrls.length,
                  itemBuilder: (context, index) {
                    final url = screenshotUrls[index];
                    return Container(
                      width: 300,
                      margin: const EdgeInsets.only(right: AppSpacing.lg),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                        color: cs.surface,
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(Icons.image, size: 48, color: cs.onSurfaceVariant),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
        boxShadow: AppShadows.boxShadowSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w800)),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subtitle, style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }

  Widget _buildValueChip(BuildContext context, {required String label, String? value}) {
    final cs = Theme.of(context).colorScheme;
    final v = (value == null || value.trim().isEmpty) ? '—' : value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text(v, style: AppTypography.caption.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildColorChip(BuildContext context, {required String label, String? hex}) {
    final cs = Theme.of(context).colorScheme;
    final v = (hex == null || hex.trim().isEmpty) ? '—' : hex.trim();
    final c = _ColorDot.parseHex(v);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c ?? cs.onSurface.withOpacity(0.12),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.8)),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text(v, style: AppTypography.caption.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildKeyValueRow(BuildContext context, String k, String? v) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              (v == null || v.trim().isEmpty) ? '—' : v,
              style: AppTypography.caption.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.subtitle1.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final TextEditingController valueListenable;

  const _ColorDot({required this.valueListenable});

  static Color? parseHex(String s) {
    var v = s.trim();
    if (v.isEmpty) return null;
    if (!v.startsWith('#')) v = '#$v';
    if (v.length != 7) return null;
    final hex = v.substring(1);
    final n = int.tryParse(hex, radix: 16);
    if (n == null) return null;
    return Color(0xFF000000 | n);
  }

  Color? _parse(String s) {
    return parseHex(s);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: valueListenable,
      builder: (context, _) {
        final c = _parse(valueListenable.text);
        final cs = Theme.of(context).colorScheme;
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: c ?? cs.onSurface.withOpacity(0.08),
            shape: BoxShape.circle,
            border: Border.all(color: cs.onSurface.withOpacity(0.12)),
          ),
        );
      },
    );
  }
}

class _VideoPlayerDialog extends StatefulWidget {
  final String url;

  const _VideoPlayerDialog({
    required this.url,
  });

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late final VideoPlayerController _controller;
  late final Future<void> _init;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _init = _controller.initialize().then((_) {
      _controller.setLooping(true);
      _controller.play();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.black,
      child: SafeArea(
        child: FutureBuilder<void>(
          future: _init,
          builder: (context, snapshot) {
            final ready = snapshot.connectionState == ConnectionState.done && _controller.value.isInitialized;
            return Stack(
              children: [
                Positioned.fill(
                  child: ready
                      ? Center(
                          child: AspectRatio(
                            aspectRatio: _controller.value.aspectRatio == 0
                                ? 16 / 9
                                : _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          ),
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
                if (ready)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          colors: VideoProgressColors(
                            playedColor: cs.primary,
                            bufferedColor: Colors.white24,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  if (_controller.value.isPlaying) {
                                    _controller.pause();
                                  } else {
                                    _controller.play();
                                  }
                                });
                              },
                              icon: Icon(
                                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${(_controller.value.position.inSeconds).toString()}s',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
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
}
