import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/build_monitor_provider.dart';
import '../../../core/services/projects_service.dart';
import '../../../core/themes/app_theme.dart';
import '../../widgets/widgets.dart';

class BuildProgressScreen extends StatefulWidget {
  const BuildProgressScreen({super.key});

  @override
  State<BuildProgressScreen> createState() => _BuildProgressScreenState();
}

class _BuildProgressScreenState extends State<BuildProgressScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;

  final ScrollController _pollErrorV = ScrollController();
  final ScrollController _pollErrorH = ScrollController();
  final ScrollController _stepErrorV = ScrollController();
  final ScrollController _stepErrorH = ScrollController();

  Timer? _pollTimer;
  String? _projectId;
  String? _pollError;

  List<String> _buildQueue = const <String>[];
  int _buildIndex = 0;
  bool _startingNext = false;

  final List<BuildStep> _buildSteps = [];

  String _buildTarget = 'webgl';
  String _buildStatus = 'queued';

  String _projectName = 'Your Game';
  String _version = '1.0';
  String? _lastLogLine;

  double _overallProgress = 0.2;
  bool _isCompleted = false;
  bool _notifyWhenComplete = true;
  String _currentStep = 'Compiling source code';
  String _estimatedTime = '2 min 30 sec';

  int? _etaTotalSeconds;
  DateTime? _etaStartedAt;
  DateTime? _buildStartedAt;

  static const _kEtaTotalPrefix = 'build.etaTotalSeconds.';
  static const _kEtaStartedPrefix = 'build.etaStartedAtMs.';
  static const _kBuildStartedPrefix = 'build.startedAtMs.';

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
    _progressController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = GoRouterState.of(context);
      final extra = state.extra;
      final id = ((extra is Map) ? extra['projectId']?.toString() : null) ??
          state.uri.queryParameters['projectId'];
      final queue = (extra is Map && extra['buildQueue'] is List)
          ? (extra['buildQueue'] as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
          : null;
      final idx = (extra is Map) ? extra['buildIndex'] : null;
      final parsedIdx = (idx is num) ? idx.toInt() : int.tryParse(idx?.toString() ?? '');
      if (id == null || id.trim().isEmpty) {
        setState(() {
          _pollError = 'Missing projectId';
        });
        return;
      }
      _projectId = id;
      _buildQueue = (queue != null && queue.isNotEmpty) ? queue : const <String>[];
      _buildIndex = (parsedIdx != null && parsedIdx >= 0) ? parsedIdx : 0;

      _restoreTimingCache(id);

      try {
        final token = context.read<AuthProvider>().token;
        final bm = context.read<BuildMonitorProvider>();
        if (token != null && token.isNotEmpty) {
          if (!bm.isMonitoring || bm.projectId != id) {
            bm.startMonitoring(token: token, projectId: id);
          }
        }
      } catch (_) {}
      _startPolling();
    });
  }

  Future<void> _startNextBuildIfAny({required String projectId, required String token}) async {
    if (_startingNext) return;
    if (_buildQueue.isEmpty) return;
    final nextIndex = _buildIndex + 1;
    if (nextIndex >= _buildQueue.length) return;

    final nextTarget = _buildQueue[nextIndex].trim();
    if (nextTarget.isEmpty) return;

    setState(() {
      _startingNext = true;
      _pollError = null;
      _isCompleted = false;
      _buildStatus = 'queued';
      _overallProgress = 0.05;
      _currentStep = 'Queued for build';
      _estimatedTime = '—';
      _etaTotalSeconds = null;
      _etaStartedAt = null;
      _buildTarget = nextTarget;
      _buildIndex = nextIndex;
      _buildSteps
        ..clear()
        ..add(
          BuildStep(
            platform: nextTarget == 'android_apk' ? 'Android' : 'Web',
            status: BuildStatus.inProgress,
            progress: 0.1,
            icon: nextTarget == 'android_apk' ? Icons.phone_android : Icons.language,
          ),
        );
    });

    try {
      await ProjectsService.updateProject(token: token, projectId: projectId, buildTarget: nextTarget);
      await ProjectsService.rebuildProject(token: token, projectId: projectId);
      try {
        context.read<BuildMonitorProvider>().startMonitoring(token: token, projectId: projectId);
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pollError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _startingNext = false;
      });
    }
  }

  Future<void> _restoreTimingCache(String projectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final etaTotal = prefs.getInt('$_kEtaTotalPrefix$projectId');
      final etaStartedMs = prefs.getInt('$_kEtaStartedPrefix$projectId');
      final buildStartedMs = prefs.getInt('$_kBuildStartedPrefix$projectId');

      if (!mounted) return;
      setState(() {
        if (etaTotal != null && etaTotal > 0) _etaTotalSeconds = etaTotal;
        if (etaStartedMs != null && etaStartedMs > 0) {
          _etaStartedAt = DateTime.fromMillisecondsSinceEpoch(etaStartedMs);
        }
        if (buildStartedMs != null && buildStartedMs > 0) {
          _buildStartedAt = DateTime.fromMillisecondsSinceEpoch(buildStartedMs);
        }
      });
    } catch (_) {}
  }

  Future<void> _persistTimingCache(String projectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final etaTotal = _etaTotalSeconds;
      final etaStartedAt = _etaStartedAt;
      final buildStartedAt = _buildStartedAt;

      if (etaTotal != null && etaTotal > 0) {
        await prefs.setInt('$_kEtaTotalPrefix$projectId', etaTotal);
      }
      if (etaStartedAt != null) {
        await prefs.setInt('$_kEtaStartedPrefix$projectId', etaStartedAt.millisecondsSinceEpoch);
      }
      if (buildStartedAt != null) {
        await prefs.setInt('$_kBuildStartedPrefix$projectId', buildStartedAt.millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollErrorV.dispose();
    _pollErrorH.dispose();
    _stepErrorV.dispose();
    _stepErrorH.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Widget _scrollableCodeBox({
    required String text,
    required Color background,
    required Color border,
    required ScrollController vertical,
    required ScrollController horizontal,
    double maxHeight = 220,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Scrollbar(
          controller: vertical,
          child: SingleChildScrollView(
            controller: vertical,
            child: Scrollbar(
              controller: horizontal,
              notificationPredicate: (n) => n.depth == 1,
              child: SingleChildScrollView(
                controller: horizontal,
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  text,
                  style: AppTypography.body2.copyWith(color: cs.onSurface, height: 1.25),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollOnce();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollOnce());
  }

  String _formatEtaSeconds(int seconds) {
    if (seconds <= 0) return '0 sec';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m <= 0) return '$s sec';
    return '$m min ${s.toString().padLeft(2, '0')} sec';
  }

  String _computeEtaText({required int totalSeconds}) {
    final startedAt = _etaStartedAt;
    if (startedAt == null) return _formatEtaSeconds(totalSeconds);
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final remaining = (totalSeconds - elapsed).clamp(0, totalSeconds);
    return _formatEtaSeconds(remaining);
  }

  double _computeSmoothProgress({required int totalSeconds, required double min, required double max}) {
    final startedAt = _etaStartedAt;
    if (startedAt == null || totalSeconds <= 0) return min;
    final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
    final totalMs = totalSeconds * 1000;
    if (totalMs <= 0) return min;
    final t = (elapsed / totalMs).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(t);
    return (min + (max - min) * eased).clamp(min, max);
  }

  String _formatElapsedSince(DateTime? startedAt) {
    if (startedAt == null) return '—';
    final s = DateTime.now().difference(startedAt).inSeconds;
    if (s <= 0) return '0 sec';
    final m = s ~/ 60;
    final ss = s % 60;
    if (m <= 0) return '$ss sec';
    return '$m min ${ss.toString().padLeft(2, '0')} sec';
  }

  Future<void> _pollOnce() async {
    final id = _projectId;
    if (id == null || id.isEmpty) return;
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) return;

    try {
      final res = await ProjectsService.getProject(token: token, projectId: id);
      if (!mounted) return;
      final data = res['data'];
      if (res['success'] != true || data is! Map) {
        setState(() {
          _pollError = res['message']?.toString() ?? 'Failed to fetch build status';
        });
        return;
      }

      final status = (data['status']?.toString() ?? '').toLowerCase();
      final buildTarget = (data['buildTarget']?.toString() ?? 'webgl').trim().toLowerCase();
      final isAndroidApk = buildTarget == 'android_apk' || buildTarget == 'android';
      final error = data['error']?.toString();
      final nm = (data['name']?.toString() ?? data['title']?.toString() ?? '').trim();
      final ver = (data['version']?.toString() ?? '').trim();
      final timings = (data['buildTimings'] is Map) ? Map<String, dynamic>.from(data['buildTimings'] as Map) : null;
      final startedAtStr = timings?['startedAt']?.toString();
      final finishedAtStr = timings?['finishedAt']?.toString();
      final durationMs = (timings?['durationMs'] is num) ? (timings?['durationMs'] as num).toDouble() : null;

      DateTime? startedAt;
      if (startedAtStr != null && startedAtStr.trim().isNotEmpty) {
        try {
          startedAt = DateTime.parse(startedAtStr.trim());
        } catch (_) {
          startedAt = null;
        }
      }

      // status: queued | running | ready | failed
      double prog = _overallProgress;
      String stepText = _currentStep;
      String etaText = _estimatedTime;
      bool done = false;
      String st = status;

      if (_buildTarget != buildTarget) {
        _buildTarget = buildTarget;
        _buildSteps
          ..clear()
          ..add(
            BuildStep(
              platform: isAndroidApk ? 'Android' : 'Web',
              status: BuildStatus.pending,
              progress: 0.0,
              icon: isAndroidApk ? Icons.phone_android : Icons.language,
            ),
          );
      }

      if (status == 'queued') {
        final base = 300;
        if (_etaTotalSeconds != base || _buildStatus != status) {
          _etaTotalSeconds = base;
          _etaStartedAt ??= DateTime.now();
        }
        prog = _computeSmoothProgress(totalSeconds: base, min: 0.05, max: 0.18);
        stepText = 'Queued for build';
        etaText = _computeEtaText(totalSeconds: base);
        if (_buildSteps.isNotEmpty) {
          _buildSteps[0].status = BuildStatus.inProgress;
          _buildSteps[0].progress = 0.2;
        }
      } else if (status == 'running') {
        stepText = isAndroidApk ? 'Building Android APK' : 'Building WebGL';
        final base = isAndroidApk ? 720 : 420;
        if (_etaTotalSeconds != base || _buildStatus != status) {
          _etaTotalSeconds = base;
          _etaStartedAt ??= DateTime.now();
        }
        prog = _computeSmoothProgress(totalSeconds: base, min: 0.2, max: 0.95);
        etaText = _computeEtaText(totalSeconds: base);
        if (_buildSteps.isNotEmpty) {
          _buildSteps[0].status = BuildStatus.inProgress;
          _buildSteps[0].progress = 0.6;
        }
      } else if (status == 'ready') {
        prog = 1.0;
        stepText = 'Build complete';
        etaText = '0 sec';
        done = true;
        for (final s in _buildSteps) {
          s.status = BuildStatus.completed;
          s.progress = 1.0;
        }
      } else if (status == 'failed') {
        prog = 1.0;
        stepText = error?.trim().isNotEmpty == true ? error!.trim() : 'Build failed';
        etaText = '—';
        if (_buildSteps.isNotEmpty) {
          _buildSteps[0].status = BuildStatus.failed;
        }
      }

      // If backend provides actual duration, reflect it.
      if (done && durationMs != null && durationMs > 0) {
        etaText = _formatEtaSeconds((durationMs / 1000).round());
      }
      if (finishedAtStr != null && finishedAtStr.trim().isNotEmpty) {
        etaText = '0 sec';
      }

      setState(() {
        _pollError = null;
        _buildTarget = buildTarget;
        _buildStatus = st;
        _overallProgress = prog;
        _currentStep = stepText;
        _estimatedTime = etaText;
        _isCompleted = done;
        _buildStartedAt = startedAt ?? _buildStartedAt;
        if (nm.isNotEmpty) _projectName = nm;
        if (ver.isNotEmpty) _version = ver;
      });

      if (startedAt != null) {
        _buildStartedAt = startedAt;
      }
      _persistTimingCache(id);

      if (done) {
        // If a build queue exists, chain next target automatically.
        if (_buildQueue.isNotEmpty && _buildIndex < _buildQueue.length - 1 && st == 'ready') {
          unawaited(_startNextBuildIfAny(projectId: id, token: token));
          return;
        }

        _pollTimer?.cancel();
        if (!mounted) return;
        try {
          context.read<BuildMonitorProvider>().stopMonitoring();
        } catch (_) {}
        context.go(
          '/build-results',
          extra: {
            'projectId': id,
            if (_buildQueue.isNotEmpty) 'buildQueue': _buildQueue,
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pollError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final extra = GoRouterState.of(context).extra;
    final projectId = (extra is Map) ? extra['projectId']?.toString() : null;
    final isAndroidApk = _buildTarget == 'android_apk' || _buildTarget == 'android';
    final platformLabel = isAndroidApk ? 'Android APK' : 'WebGL';
    final isFailed = _buildStatus == 'failed';
    final bm = context.watch<BuildMonitorProvider>();
    _lastLogLine = bm.lastLogLine ?? _lastLogLine;

    final title = 'Génération de "$_projectName" v$_version';
    final subtitle = 'Cible : $platformLabel';

    final pct = (_overallProgress * 100).clamp(0, 100).toDouble();

    final steps = <Map<String, dynamic>>[
      {
        'title': 'Compilation du Code',
        'icon': Icons.code_rounded,
      },
      {
        'title': 'Optimisation des Assets',
        'icon': Icons.image_rounded,
      },
      {
        'title': 'Signature de l\'application',
        'icon': Icons.edit_rounded,
      },
      {
        'title': isAndroidApk ? "Finalisation de l'APK" : 'Déploiement WebGL',
        'icon': isAndroidApk ? Icons.inventory_2_rounded : Icons.public_rounded,
      },
    ];

    int activeIndex = 0;
    if (_buildStatus == 'queued') {
      activeIndex = 0;
    } else if (_buildStatus == 'running') {
      if (pct >= 80) {
        activeIndex = 3;
      } else if (pct >= 60) {
        activeIndex = 2;
      } else if (pct >= 35) {
        activeIndex = 1;
      } else {
        activeIndex = 0;
      }
    } else if (_buildStatus == 'ready') {
      activeIndex = 3;
    } else if (_buildStatus == 'failed') {
      activeIndex = (pct >= 60) ? 2 : (pct >= 35 ? 1 : 0);
    }

    Widget glowBlob({
      required Alignment alignment,
      required Color color,
      required double size,
      double opacity = 0.26,
      double blur = 120,
    }) {
      return Positioned.fill(
        child: Align(
          alignment: alignment,
          child: IgnorePointer(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(opacity),
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
    }

    Widget glassCard({required Widget child}) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.72),
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
              boxShadow: AppShadows.boxShadowLarge,
            ),
            child: child,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          'Construction en cours',
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
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.go('/notifications'),
            icon: Icon(
              Icons.notifications_outlined,
              color: _notifyWhenComplete ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
          IconButton(
            tooltip: 'Notifications toggle',
            onPressed: () {
              setState(() => _notifyWhenComplete = !_notifyWhenComplete);
            },
            icon: Icon(
              _notifyWhenComplete ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
              color: _notifyWhenComplete ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                final user = auth.user;
                final username = (user?['username']?.toString() ?? '').trim();
                final avatar = (user?['avatar']?.toString() ?? '').trim();
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => context.go('/dashboard?tab=profile'),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: AppShadows.boxShadowSmall,
                    ),
                    child: ClipOval(
                      child: avatar.isNotEmpty
                          ? Image.network(
                              avatar,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                if (username.isNotEmpty) {
                                  return Center(
                                    child: Text(
                                      username[0].toUpperCase(),
                                      style: AppTypography.caption.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w900),
                                    ),
                                  );
                                }
                                return Icon(Icons.person, color: cs.onPrimary);
                              },
                            )
                          : (username.isNotEmpty)
                              ? Center(
                                  child: Text(
                                    username[0].toUpperCase(),
                                    style: AppTypography.caption.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w900),
                                  ),
                                )
                              : Icon(Icons.person, color: cs.onPrimary),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
        ),
        child: _isCompleted
            ? CustomButton(
                text: 'View Results',
                onPressed: () {
                  context.go(
                    '/build-results',
                    extra: {
                      if (projectId != null && projectId.trim().isNotEmpty) 'projectId': projectId,
                    },
                  );
                },
                type: ButtonType.primary,
                size: ButtonSize.large,
                isFullWidth: true,
              )
            : Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Mettre en arrière-plan',
                      onPressed: () {
                        context.go('/dashboard');
                      },
                      type: ButtonType.secondary,
                      isFullWidth: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: CustomButton(
                      text: 'Annuler',
                      onPressed: _showCancelDialog,
                      type: ButtonType.danger,
                      isFullWidth: true,
                    ),
                  ),
                ],
              ),
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundGradient
              : AppTheme.backgroundGradientLight,
        ),
        child: Stack(
          children: [
            glowBlob(
              alignment: const Alignment(-1.0, -0.92),
              color: const Color(0xFF6366F1),
              size: 320,
            ),
            glowBlob(
              alignment: const Alignment(1.0, -0.75),
              color: const Color(0xFF38BDF8),
              size: 260,
              opacity: 0.22,
            ),
            glowBlob(
              alignment: const Alignment(0.2, 1.05),
              color: const Color(0xFF22C55E),
              size: 300,
              opacity: 0.12,
            ),
            SingleChildScrollView(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
                bottom: MediaQuery.of(context).padding.bottom + 140,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppBorderRadius.large),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
                      gradient: LinearGradient(
                        colors: [
                          cs.surface.withOpacity(0.78),
                          cs.surface.withOpacity(0.48),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.h2.copyWith(color: cs.onSurface, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: cs.surfaceVariant.withOpacity(0.55),
                                border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isAndroidApk ? Icons.android_rounded : Icons.public_rounded,
                                    size: 16,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    subtitle,
                                    style: AppTypography.caption.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            StatusBadge(
                              text: isFailed
                                  ? 'Échec'
                                  : _buildStatus == 'ready'
                                      ? 'Terminé'
                                      : _buildStatus == 'running'
                                          ? 'En cours'
                                          : 'En attente',
                              color: isFailed ? AppColors.error : (_buildStatus == 'ready' ? AppColors.success : cs.primary),
                              icon: isFailed
                                  ? Icons.error_rounded
                                  : _buildStatus == 'ready'
                                      ? Icons.check_circle_rounded
                                      : Icons.auto_awesome,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

              if (_pollError != null) ...[
                _scrollableCodeBox(
                  text: _pollError!,
                  background: cs.errorContainer.withOpacity(0.35),
                  border: cs.error.withOpacity(0.25),
                  vertical: _pollErrorV,
                  horizontal: _pollErrorH,
                  maxHeight: 220,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              AnimatedCard(
                delay: const Duration(milliseconds: 40),
                child: glassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: AppSpacing.sm),
                        ExcludeSemantics(
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: child,
                              );
                            },
                            child: Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isFailed
                                    ? LinearGradient(colors: [cs.error.withOpacity(0.92), cs.error.withOpacity(0.62)])
                                    : AppColors.primaryGradient,
                                boxShadow: isFailed
                                    ? AppShadows.custom(color: cs.error, opacity: 0.22, offset: const Offset(0, 10), blurRadius: 18)
                                    : AppShadows.boxShadowPrimaryGlow,
                              ),
                              child: Icon(
                                isAndroidApk ? Icons.phone_android : Icons.language,
                                size: 46,
                                color: cs.onPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          isFailed ? 'Construction échouée' : 'Construction en cours',
                          style: AppTypography.subtitle1.copyWith(
                            color: isFailed ? cs.error : cs.onSurface,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        if (!isFailed)
                          Text(
                            'Temps restant : ~ $_estimatedTime  •  Écoulé : ${_formatElapsedSince(_buildStartedAt ?? _etaStartedAt)}',
                            style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700, height: 1.25),
                            textAlign: TextAlign.center,
                          ),
                        if (isFailed) ...[
                          const SizedBox(height: 10),
                          _scrollableCodeBox(
                            text: _currentStep,
                            background: cs.errorContainer.withOpacity(0.22),
                            border: cs.error.withOpacity(0.22),
                            vertical: _stepErrorV,
                            horizontal: _stepErrorH,
                            maxHeight: 120,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        Stack(
                          children: [
                            Container(
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: cs.surfaceContainerHighest.withOpacity(0.28),
                                border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                              ),
                            ),
                            Positioned.fill(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: (_overallProgress).clamp(0.0, 1.0)),
                                duration: const Duration(milliseconds: 520),
                                curve: Curves.easeOutCubic,
                                builder: (context, t, _) {
                                  return FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: t,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        gradient: isFailed
                                            ? LinearGradient(colors: [cs.error.withOpacity(0.95), cs.error.withOpacity(0.65)])
                                            : const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF6366F1)]),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isFailed ? cs.error : cs.primary).withOpacity(0.35),
                                            blurRadius: 22,
                                            offset: const Offset(0, 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned.fill(
                              child: Center(
                                child: Text(
                                  '${pct.toStringAsFixed(0)}%',
                                  style: AppTypography.subtitle2.copyWith(color: cs.onSurface, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (!isFailed)
                          Text(
                            _currentStep,
                            style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, height: 1.25),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Étapes du build',
                style: AppTypography.subtitle2.copyWith(color: cs.onSurface, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: AppSpacing.lg),
              glassCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: List.generate(steps.length, (i) {
                      final step = steps[i];
                      final done = _buildStatus == 'ready' ? true : (i < activeIndex);
                      final active = _buildStatus == 'running' && i == activeIndex;
                      final failed = isFailed && i == activeIndex;
                      final lineColor = done
                          ? AppColors.success
                          : (failed ? AppColors.error : (active ? cs.primary : cs.onSurfaceVariant.withOpacity(0.35)));

                      String stateText;
                      if (done) {
                        stateText = 'Terminé';
                      } else if (failed) {
                        stateText = 'Échoué';
                      } else if (active) {
                        stateText = 'En cours…';
                      } else {
                        stateText = 'En attente';
                      }

                      final sub = (active && (_lastLogLine ?? '').trim().isNotEmpty)
                          ? (_lastLogLine!.trim())
                          : (active && _currentStep.trim().isNotEmpty ? _currentStep.trim() : null);

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppBorderRadius.large),
                          border: Border.all(
                            color: (active || failed)
                                ? lineColor.withOpacity(0.35)
                                : cs.outlineVariant.withOpacity(0.0),
                          ),
                          gradient: (active || failed)
                              ? LinearGradient(
                                  colors: [
                                    lineColor.withOpacity(0.10),
                                    cs.surface.withOpacity(0.0),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                )
                              : null,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: lineColor.withOpacity(0.14),
                                    border: Border.all(color: lineColor.withOpacity(0.35)),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: active
                                        ? [
                                            BoxShadow(
                                              color: lineColor.withOpacity(0.28),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Icon(step['icon'] as IconData, size: 18, color: lineColor),
                                ),
                                if (i != steps.length - 1)
                                  Container(
                                    width: 2,
                                    height: 26,
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      color: lineColor.withOpacity(0.35),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step['title'] as String,
                                    style: AppTypography.subtitle2.copyWith(color: cs.onSurface, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    stateText,
                                    style: AppTypography.caption.copyWith(color: lineColor, fontWeight: FontWeight.w700),
                                  ),
                                  if (sub != null && sub.trim().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      sub,
                                      style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, height: 1.25),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (active)
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                                ),
                              )
                            else if (done)
                              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22)
                            else
                              Icon(Icons.radio_button_unchecked, color: cs.onSurfaceVariant.withOpacity(0.35), size: 22),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              glassCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primary.withOpacity(0.14),
                        border: Border.all(color: cs.primary.withOpacity(0.25)),
                      ),
                      child: Icon(Icons.lightbulb_rounded, color: cs.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Astuce du Jour',
                            style: AppTypography.subtitle2.copyWith(color: cs.onSurface, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Astuce : Pensez à tester votre jeu sur différents tailles d'écran pour garantir une bonne expérience utilisateur.",
                            style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, height: 1.25),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ),

              const SizedBox(height: AppSpacing.xl),
              glassCard(
                child: ExpansionTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                  title: Text(
                    'Build Log',
                    style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
                  ),
                  leading: Icon(Icons.terminal, color: cs.primary),
                  subtitle: (_lastLogLine != null && _lastLogLine!.trim().isNotEmpty)
                      ? Text(
                          '> ${_lastLogLine!.trim()}',
                          style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLogEntry('Starting build process...', LogLevel.info),
                          if (_lastLogLine != null && _lastLogLine!.trim().isNotEmpty)
                            _buildLogEntry(_lastLogLine!.trim(), LogLevel.info),
                          if (_isCompleted) ...[
                            _buildLogEntry('Build completed successfully!', LogLevel.success),
                          ] else if (isFailed) ...[
                            _buildLogEntry('Build failed', LogLevel.error),
                          ] else ...[
                            _buildLogEntry('Building in progress...', LogLevel.info),
                          ],
                        ],
                      ),
                    ),
                  ],
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

  Widget _buildPlatformCard(BuildStep step, int index) {
    final cs = Theme.of(context).colorScheme;
    Color statusColor;
    String statusText;
    
    switch (step.status) {
      case BuildStatus.completed:
        statusColor = AppColors.success;
        statusText = 'Completed';
        break;
      case BuildStatus.inProgress:
        statusColor = AppColors.primary;
        statusText = 'Building...';
        break;
      case BuildStatus.failed:
        statusColor = AppColors.error;
        statusText = 'Failed';
        break;
      case BuildStatus.pending:
        statusColor = AppColors.textSecondary;
        statusText = 'Pending';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(
          color: step.status == BuildStatus.inProgress 
              ? cs.primary 
              : cs.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Platform icon
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  step.icon,
                  color: statusColor,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: AppSpacing.lg),
              
              // Platform info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.platform,
                      style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
                    ),
                    
                    const SizedBox(height: AppSpacing.xs),
                    
                    Text(
                      statusText,
                      style: AppTypography.caption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Progress
              if (step.status == BuildStatus.inProgress)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _pulseController.value * 2 * 3.14159,
                      child: Icon(
                        Icons.autorenew,
                        color: statusColor,
                        size: 20,
                      ),
                    );
                  },
                )
              else if (step.status == BuildStatus.completed)
                Icon(
                  Icons.check_circle,
                  color: statusColor,
                  size: 20,
                )
              else
                Icon(
                  Icons.radio_button_unchecked,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
            ],
          ),
          
          if (step.status != BuildStatus.pending) ...[
            const SizedBox(height: AppSpacing.md),
            ProgressIndicatorWidget(
              progress: step.progress,
              color: statusColor,
              height: 6,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogEntry(String message, LogLevel level) {
    Color textColor;
    IconData icon;
    
    switch (level) {
      case LogLevel.info:
        textColor = AppColors.textSecondary;
        icon = Icons.info_outline;
        break;
      case LogLevel.success:
        textColor = AppColors.success;
        icon = Icons.check_circle_outline;
        break;
      case LogLevel.warning:
        textColor = AppColors.warning;
        icon = Icons.warning_amber_outlined;
        break;
      case LogLevel.error:
        textColor = AppColors.error;
        icon = Icons.error_outline;
        break;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: textColor,
          ),
          
          const SizedBox(width: AppSpacing.sm),
          
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(
                color: textColor,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    final token = context.read<AuthProvider>().token;
    final pid = _projectId;
    BuildMonitorProvider? bm;
    try {
      bm = context.read<BuildMonitorProvider>();
    } catch (_) {
      bm = null;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Build'),
        content: const Text(
          'Are you sure you want to cancel the build process? All progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Keep Building'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              if (token != null && token.isNotEmpty && pid != null && pid.trim().isNotEmpty) {
                try {
                  await ProjectsService.cancelBuild(token: token, projectId: pid);
                } catch (_) {}
              }

              if (!mounted) return;

              try {
                bm?.stopMonitoring();
              } catch (_) {}

              if (!mounted) return;
              final popped = await Navigator.of(this.context).maybePop();
              if (!popped && mounted) {
                this.context.go('/dashboard');
              }
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class BuildStep {
  final String platform;
  final IconData icon;
  BuildStatus status;
  double progress;

  BuildStep({
    required this.platform,
    required this.icon,
    required this.status,
    required this.progress,
  });
}

enum BuildStatus {
  pending,
  inProgress,
  completed,
  failed,
}

enum LogLevel {
  info,
  success,
  warning,
  error,
}
