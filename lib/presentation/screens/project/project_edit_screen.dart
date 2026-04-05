import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/build_monitor_provider.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/services/projects_service.dart';
import '../../widgets/widgets.dart';

class ProjectEditScreen extends StatefulWidget {
  const ProjectEditScreen({super.key});

  @override
  State<ProjectEditScreen> createState() => _ProjectEditScreenState();
}

class _ProjectEditScreenState extends State<ProjectEditScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _projectId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  double _speed = 7.0;
  double _timeScale = 1.0;
  double _difficulty = 0.5;
  bool _fogEnabled = false;
  double _fogDensity = 0.0;
  double _cameraZoom = 0.0;
  double _gravityY = 0.0;
  double _jumpForce = 0.0;

  final TextEditingController _themeCtrl = TextEditingController(text: 'default');
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _genreCtrl = TextEditingController(text: 'platformer');
  final TextEditingController _assetsTypeCtrl = TextEditingController(text: 'lowpoly');
  final TextEditingController _mechanicsCtrl = TextEditingController();

  final TextEditingController _primaryCtrl = TextEditingController(text: '#22C55E');
  final TextEditingController _secondaryCtrl = TextEditingController(text: '#3B82F6');
  final TextEditingController _accentCtrl = TextEditingController(text: '#F59E0B');
  final TextEditingController _playerCtrl = TextEditingController(text: '#F59E0B');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    final pid = (extra is Map) ? extra['projectId']?.toString() : null;
    _projectId ??= (pid != null && pid.trim().isNotEmpty) ? pid.trim() : null;
    if (_loading) {
      Future.microtask(_load);
    }
  }

  @override
  void dispose() {
    _themeCtrl.dispose();
    _notesCtrl.dispose();
    _genreCtrl.dispose();
    _assetsTypeCtrl.dispose();
    _mechanicsCtrl.dispose();
    _primaryCtrl.dispose();
    _secondaryCtrl.dispose();
    _accentCtrl.dispose();
    _playerCtrl.dispose();
    super.dispose();
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

  Future<void> _load() async {
    final pid = _projectId;
    if (pid == null || pid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing projectId';
      });
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Not authenticated';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ProjectsService.getProjectRuntimeConfig(token: token, projectId: pid);
      final data = (res['success'] == true && res['data'] is Map) ? Map<String, dynamic>.from(res['data'] as Map) : null;
      if (!mounted) return;

      setState(() {
        if (data != null) {
          _speed = (data['speed'] is num) ? (data['speed'] as num).toDouble() : _speed;
          _timeScale = (data['timeScale'] is num) ? (data['timeScale'] as num).toDouble() : _timeScale;
          _difficulty = (data['difficulty'] is num) ? (data['difficulty'] as num).toDouble() : _difficulty;

          _themeCtrl.text = (data['theme']?.toString() ?? _themeCtrl.text);
          _notesCtrl.text = (data['notes']?.toString() ?? _notesCtrl.text);
          _genreCtrl.text = (data['genre']?.toString() ?? _genreCtrl.text);
          _assetsTypeCtrl.text = (data['assetsType']?.toString() ?? _assetsTypeCtrl.text);
          _mechanicsCtrl.text = (data['mechanics'] is List)
              ? (data['mechanics'] as List).map((e) => e?.toString() ?? '').where((e) => e.trim().isNotEmpty).join(', ')
              : (_mechanicsCtrl.text);

          _primaryCtrl.text = (data['primaryColor']?.toString() ?? _primaryCtrl.text);
          _secondaryCtrl.text = (data['secondaryColor']?.toString() ?? _secondaryCtrl.text);
          _accentCtrl.text = (data['accentColor']?.toString() ?? _accentCtrl.text);
          _playerCtrl.text = (data['playerColor']?.toString() ?? _playerCtrl.text);

          _fogEnabled = (data['fogEnabled'] is bool) ? (data['fogEnabled'] as bool) : _fogEnabled;
          _fogDensity = (data['fogDensity'] is num) ? (data['fogDensity'] as num).toDouble() : _fogDensity;
          _cameraZoom = (data['cameraZoom'] is num) ? (data['cameraZoom'] as num).toDouble() : _cameraZoom;
          _gravityY = (data['gravityY'] is num) ? (data['gravityY'] as num).toDouble() : _gravityY;
          _jumpForce = (data['jumpForce'] is num) ? (data['jumpForce'] as num).toDouble() : _jumpForce;
        }

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pasteHexInto(TextEditingController ctrl) async {
    final d = await Clipboard.getData('text/plain');
    final raw = d?.text;
    if (raw == null) return;
    var s = raw.trim();
    if (s.isEmpty) return;
    if (!s.startsWith('#')) s = '#$s';
    if (s.length != 7) return;
    if (_parseHexToColor(s) == null) return;
    ctrl.text = s.toUpperCase();
    setState(() {});
  }

  Future<void> _pickColorFor(TextEditingController ctrl) async {
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
    final rgb = picked.value & 0x00FFFFFF;
    ctrl.text = '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
    setState(() {});
  }

  Future<void> _save({required bool rebuild}) async {
    if (_saving) return;

    final pid = _projectId;
    if (pid == null || pid.trim().isEmpty) {
      AppNotifier.showError('Missing projectId');
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      AppNotifier.showError('Not authenticated');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ProjectsService.updateProject(
        token: token,
        projectId: pid,
        speed: _speed.clamp(0.0, 20.0),
        timeScale: _timeScale.clamp(0.5, 2.0),
        difficulty: _difficulty.clamp(0.0, 1.0),
        theme: _themeCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        genre: _genreCtrl.text.trim(),
        assetsType: _assetsTypeCtrl.text.trim(),
        mechanics: _mechanicsCtrl.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        primaryColor: _normHex(_primaryCtrl.text) ?? '#22C55E',
        secondaryColor: _normHex(_secondaryCtrl.text) ?? '#3B82F6',
        accentColor: _normHex(_accentCtrl.text) ?? '#F59E0B',
        playerColor: _normHex(_playerCtrl.text) ?? (_normHex(_accentCtrl.text) ?? '#F59E0B'),
        fogEnabled: _fogEnabled,
        fogDensity: _fogDensity.clamp(0.0, 0.1),
        cameraZoom: _cameraZoom.clamp(0.0, 30.0),
        gravityY: _gravityY.clamp(-50.0, 0.0),
        jumpForce: _jumpForce.clamp(0.0, 50.0),
      );

      if (rebuild) {
        final res = await ProjectsService.rebuildProject(token: token, projectId: pid);
        if (res['success'] == true) {
          try {
            if (!mounted) return;
            context.read<BuildMonitorProvider>().startMonitoring(token: token, projectId: pid);
          } catch (_) {}
          if (!mounted) return;
          AppNotifier.showSuccess('Saved. Build started');
          context.go('/build-progress', extra: {'projectId': pid});
          return;
        }
        AppNotifier.showError(res['message']?.toString() ?? 'Failed to start build');
        return;
      }

      AppNotifier.showSuccess('Saved');
      if (mounted) context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
      AppNotifier.showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
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

  Widget _colorRow({
    required String label,
    required TextEditingController ctrl,
  }) {
    final cs = Theme.of(context).colorScheme;
    final c = _parseHexToColor(ctrl.text);

    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(label, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w800)),
        ),
        InkWell(
          onTap: _saving ? null : () => _pickColorFor(ctrl),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c ?? cs.surfaceVariant,
              border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
              boxShadow: AppShadows.boxShadowSmall,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextFormField(
            controller: ctrl,
            enabled: !_saving,
            decoration: InputDecoration(
              hintText: '#RRGGBB',
              filled: true,
              fillColor: cs.surface,
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
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return null;
              return _normHex(t) == null ? 'Invalid hex color' : null;
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          onPressed: _saving ? null : () => _pasteHexInto(ctrl),
          icon: const Icon(Icons.paste_rounded),
          tooltip: 'Paste',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text('Edit Project', style: AppTypography.subtitle1),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard?tab=projects');
            }
          },
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: AppSpacing.paddingLarge,
              child: Form(
                key: _formKey,
                child: Column(
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
                        child: Text(_error!, style: AppTypography.body2.copyWith(color: cs.onSurface)),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    _sectionTitle('Gameplay'),
                    Container(
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
                              Expanded(child: Text('Speed', style: AppTypography.subtitle2)),
                              Text(_speed.toStringAsFixed(1), style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900)),
                            ],
                          ),
                          Slider(
                            value: _speed.clamp(0.0, 20.0),
                            min: 0,
                            max: 20,
                            divisions: 200,
                            onChanged: _saving ? null : (v) => setState(() => _speed = v),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(child: Text('Time Scale', style: AppTypography.subtitle2)),
                              Text(_timeScale.toStringAsFixed(2), style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900)),
                            ],
                          ),
                          Slider(
                            value: _timeScale.clamp(0.5, 2.0),
                            min: 0.5,
                            max: 2.0,
                            divisions: 150,
                            onChanged: _saving ? null : (v) => setState(() => _timeScale = v),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(child: Text('Difficulty', style: AppTypography.subtitle2)),
                              Text(_difficulty.toStringAsFixed(2), style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900)),
                            ],
                          ),
                          Slider(
                            value: _difficulty.clamp(0.0, 1.0),
                            min: 0,
                            max: 1,
                            divisions: 100,
                            onChanged: _saving ? null : (v) => setState(() => _difficulty = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _sectionTitle('Colors'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(AppBorderRadius.large),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                        boxShadow: AppShadows.boxShadowSmall,
                      ),
                      child: Column(
                        children: [
                          _colorRow(label: 'Primary', ctrl: _primaryCtrl),
                          const SizedBox(height: AppSpacing.md),
                          _colorRow(label: 'Secondary', ctrl: _secondaryCtrl),
                          const SizedBox(height: AppSpacing.md),
                          _colorRow(label: 'Accent', ctrl: _accentCtrl),
                          const SizedBox(height: AppSpacing.md),
                          _colorRow(label: 'Player', ctrl: _playerCtrl),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _sectionTitle('Environment'),
                    Container(
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
                          SwitchListTile.adaptive(
                            value: _fogEnabled,
                            onChanged: _saving ? null : (v) => setState(() => _fogEnabled = v),
                            contentPadding: EdgeInsets.zero,
                            title: Text('Fog enabled', style: AppTypography.subtitle2),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(child: Text('Fog density', style: AppTypography.subtitle2)),
                              Text(_fogDensity.toStringAsFixed(3), style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900)),
                            ],
                          ),
                          Slider(
                            value: _fogDensity.clamp(0.0, 0.1),
                            min: 0,
                            max: 0.1,
                            divisions: 100,
                            onChanged: _saving ? null : (v) => setState(() => _fogDensity = v),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(child: Text('Camera zoom', style: AppTypography.subtitle2)),
                              Text(_cameraZoom.toStringAsFixed(1), style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900)),
                            ],
                          ),
                          Slider(
                            value: _cameraZoom.clamp(0.0, 30.0),
                            min: 0,
                            max: 30,
                            divisions: 300,
                            onChanged: _saving ? null : (v) => setState(() => _cameraZoom = v),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(child: Text('Gravity Y', style: AppTypography.subtitle2)),
                              Text(_gravityY.toStringAsFixed(1), style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900)),
                            ],
                          ),
                          Slider(
                            value: _gravityY.clamp(-50.0, 0.0),
                            min: -50,
                            max: 0,
                            divisions: 500,
                            onChanged: _saving ? null : (v) => setState(() => _gravityY = v),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(child: Text('Jump force', style: AppTypography.subtitle2)),
                              Text(_jumpForce.toStringAsFixed(1), style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900)),
                            ],
                          ),
                          Slider(
                            value: _jumpForce.clamp(0.0, 50.0),
                            min: 0,
                            max: 50,
                            divisions: 500,
                            onChanged: _saving ? null : (v) => setState(() => _jumpForce = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _sectionTitle('Metadata'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(AppBorderRadius.large),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                        boxShadow: AppShadows.boxShadowSmall,
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _themeCtrl,
                            enabled: !_saving,
                            decoration: const InputDecoration(labelText: 'Theme'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _genreCtrl,
                            enabled: !_saving,
                            decoration: const InputDecoration(labelText: 'Genre'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _assetsTypeCtrl,
                            enabled: !_saving,
                            decoration: const InputDecoration(labelText: 'Assets type'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _mechanicsCtrl,
                            enabled: !_saving,
                            decoration: const InputDecoration(labelText: 'Mechanics (comma separated)'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _notesCtrl,
                            enabled: !_saving,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(labelText: 'Notes'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
        padding: AppSpacing.paddingLarge,
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant.withOpacity(0.6))),
        ),
        child: Row(
          children: [
            Expanded(
              child: CustomButton(
                text: _saving ? 'Saving…' : 'Save',
                onPressed: _saving ? null : () => _save(rebuild: false),
                type: ButtonType.secondary,
                size: ButtonSize.large,
                isFullWidth: true,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: CustomButton(
                text: _saving ? 'Starting…' : 'Save & Rebuild',
                onPressed: _saving ? null : () => _save(rebuild: true),
                type: ButtonType.primary,
                size: ButtonSize.large,
                isFullWidth: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
