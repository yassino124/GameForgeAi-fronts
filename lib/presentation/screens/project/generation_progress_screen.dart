import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/projects_service.dart';
import '../../widgets/widgets.dart';

class GenerationProgressScreen extends StatefulWidget {
  const GenerationProgressScreen({super.key});

  @override
  State<GenerationProgressScreen> createState() => _GenerationProgressScreenState();
}

class _GenerationProgressScreenState extends State<GenerationProgressScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late AnimationController _neonRingController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  Timer? _pollTimer;
  Timer? _clockTimer;
  String? _projectId;
  String? _pollError;

  bool _isFailed = false;
  String? _buildError;
  Map<String, dynamic>? _buildTimings;
  bool _rebuilding = false;

  String? _templateName;
  String? _prompt;

  DateTime? _startedAt;
  String _currentStep = 'Preparing…';
  String _estimatedTime = '—';

  final List<GenerationStep> _steps = [
    GenerationStep(
      title: 'Analyzing requirements',
      description: 'Understanding your game concept and preferences',
      status: StepStatus.completed,
    ),
    GenerationStep(
      title: 'Generating game logic',
      description: 'Creating core game mechanics and rules',
      status: StepStatus.inProgress,
    ),
    GenerationStep(
      title: 'Creating assets',
      description: 'Designing characters, environments, and items',
      status: StepStatus.pending,
    ),
    GenerationStep(
      title: 'Building scenes',
      description: 'Constructing game levels and environments',
      status: StepStatus.pending,
    ),
    GenerationStep(
      title: 'Optimizing performance',
      description: 'Fine-tuning for smooth gameplay',
      status: StepStatus.pending,
    ),
  ];

  double _overallProgress = 0.2;
  bool _isCompleted = false;
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    _neonRingController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
    _progressController.forward();
    _neonRingController.repeat();

    _startedAt = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final extra = GoRouterState.of(context).extra;
      final data = extra is Map ? Map<String, dynamic>.from(extra as Map) : <String, dynamic>{};
      final id = data['projectId']?.toString();
      _templateName = data['templateName']?.toString();
      _prompt = data['prompt']?.toString();
      if (id == null || id.trim().isEmpty) {
        setState(() {
          _pollError = 'Missing projectId';
        });
        return;
      }
      _projectId = id;
      _startPolling();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    _pulseController.dispose();
    _progressController.dispose();
    _neonRingController.dispose();
    super.dispose();
  }

  String _formatElapsed() {
    final s = _startedAt;
    if (s == null) return '0:00';
    final d = DateTime.now().difference(s);
    final totalSeconds = d.inSeconds;
    final m = totalSeconds ~/ 60;
    final sec = totalSeconds % 60;
    return '${m.toString()}:${sec.toString().padLeft(2, '0')}';
  }

  String _formatEtaSeconds(int seconds) {
    if (seconds <= 0) return '0 sec';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m <= 0) return '$s sec';
    return '$m min ${s.toString().padLeft(2, '0')} sec';
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollOnce();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollOnce());
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
          _pollError = res['message']?.toString() ?? 'Failed to fetch status';
        });
        return;
      }

      final status = (data['status']?.toString() ?? '').toLowerCase();
      final buildTarget = (data['buildTarget']?.toString() ?? 'webgl').toLowerCase();
      final errorMsg = data['error']?.toString();
      final timings = (data['buildTimings'] is Map)
          ? Map<String, dynamic>.from(data['buildTimings'] as Map)
          : null;

      final isAndroidApk = buildTarget == 'android_apk' || buildTarget == 'android';

      // Map backend status to UI steps.
      // Expected statuses: queued, running, ready, failed
      StepStatus s0 = StepStatus.pending;
      StepStatus s1 = StepStatus.pending;
      StepStatus s2 = StepStatus.pending;
      StepStatus s3 = StepStatus.pending;
      StepStatus s4 = StepStatus.pending;
      double prog = 0.1;
      bool done = false;

      if (status == 'queued') {
        s0 = StepStatus.completed;
        s1 = StepStatus.inProgress;
        prog = 0.2;
        _currentStep = 'Queued for build';
        _estimatedTime = _formatEtaSeconds(180);
      } else if (status == 'running' || status == 'building') {
        s0 = StepStatus.completed;
        s1 = StepStatus.completed;
        s2 = StepStatus.inProgress;
        prog = 0.55;
        _currentStep = isAndroidApk ? 'Building Android APK' : 'Building WebGL project';
        _estimatedTime = _formatEtaSeconds(420);
      } else if (status == 'ready') {
        s0 = StepStatus.completed;
        s1 = StepStatus.completed;
        s2 = StepStatus.completed;
        s3 = StepStatus.completed;
        s4 = StepStatus.completed;
        prog = 1.0;
        done = true;
        _currentStep = 'Ready to play';
        _estimatedTime = _formatEtaSeconds(0);
      } else if (status == 'failed') {
        // Mark progress as stopped.
        s0 = StepStatus.completed;
        s1 = StepStatus.completed;
        s2 = StepStatus.completed;
        s3 = StepStatus.inProgress;
        prog = 0.85;
        _currentStep = 'Build failed';
        _estimatedTime = '—';
      } else {
        // Unknown status, keep polling.
        s0 = StepStatus.completed;
        s1 = StepStatus.inProgress;
        prog = 0.2;
        _currentStep = 'Starting…';
        _estimatedTime = '—';
      }

      setState(() {
        _pollError = null;
        _isFailed = status == 'failed';
        _buildError = status == 'failed' ? errorMsg : null;
        _buildTimings = timings;
        _steps[0].status = s0;
        _steps[1].status = s1;
        _steps[2].status = s2;
        _steps[3].status = s3;
        _steps[4].status = s4;
        _overallProgress = prog;
        _isCompleted = done;
      });

      if (done) {
        _pollTimer?.cancel();
        if (!mounted) return;
        context.go('/project-detail', extra: {'projectId': id});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pollError = e.toString();
      });
    }
  }

  Future<void> _rebuildNow() async {
    if (_rebuilding) return;
    final id = _projectId;
    if (id == null || id.isEmpty) return;

    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) return;

    setState(() {
      _rebuilding = true;
      _pollError = null;
    });

    try {
      final res = await ProjectsService.rebuildProject(token: token, projectId: id);
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _isFailed = false;
          _buildError = null;
          _buildTimings = null;
          _currentStep = 'Queued for build';
          _estimatedTime = _formatEtaSeconds(180);
          _overallProgress = 0.2;
        });
        _startPolling();
      } else {
        setState(() {
          _pollError = res['message']?.toString() ?? 'Failed to rebuild';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pollError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _rebuilding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isMinimized) {
      return _buildMinimizedView();
    }
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundGradient
              : AppTheme.backgroundGradientLight,
        ),
        child: SafeArea(
          child: Padding(
            padding: AppSpacing.paddingLarge,
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
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xxxl,
                ),
                child: Column(
              children: [
              if (_pollError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    border: Border.all(color: AppColors.error.withOpacity(0.35)),
                  ),
                  child: Text(
                    _pollError!,
                    style: AppTypography.body2.copyWith(color: cs.onSurface),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              if (_isFailed) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    border: Border.all(color: AppColors.error.withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Build failed',
                        style: AppTypography.subtitle2.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        (_buildError == null || _buildError!.trim().isEmpty)
                            ? 'Unknown error. Please check backend logs.'
                            : _buildError!,
                        style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              text: _rebuilding ? 'Rebuilding…' : 'Rebuild now',
                              onPressed: _rebuilding ? null : _rebuildNow,
                              type: ButtonType.primary,
                              icon: const Icon(Icons.refresh_rounded),
                              isFullWidth: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              text: 'View project',
                              onPressed: () {
                                final id = _projectId;
                                if (id == null || id.isEmpty) return;
                                context.go('/project-detail', extra: {'projectId': id});
                              },
                              type: ButtonType.secondary,
                              icon: const Icon(Icons.dashboard_customize_rounded),
                              isFullWidth: true,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: CustomButton(
                              text: 'Dashboard',
                              onPressed: () => context.go('/dashboard'),
                              type: ButtonType.secondary,
                              icon: const Icon(Icons.home_rounded),
                              isFullWidth: true,
                            ),
                          ),
                        ],
                      ),
                      if (_buildTimings != null && _buildTimings!['steps'] is Map) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Steps',
                          style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...Map<String, dynamic>.from(_buildTimings!['steps'] as Map)
                            .entries
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        e.key,
                                        style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                                      ),
                                    ),
                                    Text(
                                      '${e.value}ms',
                                      style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              _buildHeader(),
              
              const SizedBox(height: AppSpacing.xxxl),
              
              // AI Brain Animation
              AnimatedBuilder(
                animation: Listenable.merge([_pulseAnimation, _neonRingController]),
                builder: (context, child) {
                  final t = _pulseAnimation.value;
                  return Transform.scale(
                    scale: t,
                    child: SizedBox(
                      width: 142,
                      height: 142,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.rotate(
                            angle: _neonRingController.value * 2 * math.pi,
                            child: Container(
                              width: 142,
                              height: 142,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: [
                                    cs.primary.withOpacity(0.0),
                                    cs.primary.withOpacity(0.55),
                                    cs.secondary.withOpacity(0.75),
                                    cs.primary.withOpacity(0.0),
                                  ],
                                  stops: const [0.0, 0.35, 0.65, 1.0],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.primary.withOpacity(0.22 * t),
                                    blurRadius: 42 * t,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: cs.secondary.withOpacity(0.18 * t),
                                    blurRadius: 58 * t,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                              boxShadow: AppShadows.boxShadowPrimaryGlow,
                            ),
                            child: Icon(
                              Icons.psychology,
                              size: 60,
                              color: cs.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: AppSpacing.xl),
              
              // Overall progress
              Text(
                _isCompleted ? 'Game Generated!' : 'Creating your game...',
                style: AppTypography.h3.copyWith(color: cs.onSurface),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: AppSpacing.md),
              
              Text(
                _isCompleted 
                    ? 'Your game is ready to play and customize'
                    : 'AI is working its magic to bring your vision to life',
                style: AppTypography.body1.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: AppSpacing.xxxl),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: cs.surface.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                  boxShadow: AppShadows.boxShadowLarge,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Text(
                        _currentStep,
                        key: ValueKey(_currentStep),
                        style: AppTypography.subtitle1.copyWith(color: cs.onSurface),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        _buildMiniStat(label: 'Elapsed', value: _formatElapsed()),
                        const SizedBox(width: AppSpacing.md),
                        _buildMiniStat(label: 'ETA', value: _estimatedTime),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppSpacing.xl),
              
              // Progress bar
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: _overallProgress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) {
                  return AnimatedBuilder(
                    animation: _neonRingController,
                    builder: (context, _) {
                      final phase = _neonRingController.value;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Stack(
                          children: [
                            ProgressIndicatorWidget(
                              progress: v,
                              color: cs.primary,
                              height: 8,
                            ),
                            // Neon shine overlay that moves across the bar.
                            Positioned.fill(
                              child: FractionallySizedBox(
                                alignment: Alignment(phase * 2 - 1, 0),
                                widthFactor: 0.22,
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.transparent,
                                          cs.secondary.withOpacity(0.22),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              
              const SizedBox(height: AppSpacing.xxxl),
              
              // Generation steps
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  return _buildTimelineStep(index: index, step: _steps[index]);
                },
              ),
              
              // Action buttons
              if (_isCompleted) ...[
                CustomButton(
                  text: 'View Project',
                  onPressed: () {
                    final id = _projectId;
                    if (id == null || id.isEmpty) return;
                    context.go('/project-detail', extra: {'projectId': id});
                  },
                  type: ButtonType.primary,
                  size: ButtonSize.large,
                  isFullWidth: true,
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                CustomButton(
                  text: 'Continue in Background',
                  onPressed: _minimizeGeneration,
                  type: ButtonType.ghost,
                  isFullWidth: true,
                ),
              ] else ...[
                CustomButton(
                  text: 'Cancel Generation',
                  onPressed: () {
                    _showCancelDialog();
                  },
                  type: ButtonType.danger,
                  isFullWidth: true,
                ),
              ],
              
              const SizedBox(height: AppSpacing.xl),
              ],
            ),
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMinimizedView() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: _restoreGeneration,
        child: Container(
          color: (isDark ? Colors.black : Colors.white).withOpacity(0.55),
          child: Center(
            child: Container(
              padding: AppSpacing.paddingLarge,
              margin: AppSpacing.paddingHorizontalLarge,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                boxShadow: AppShadows.boxShadowLarge,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // AI Brain with pulse
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                          ),
                          child: Icon(
                            Icons.psychology,
                            size: 30,
                            color: cs.onPrimary,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: AppSpacing.lg),
                  
                  Text(
                    'Game Generation in Progress',
                    style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  ProgressIndicatorWidget(
                    progress: _overallProgress,
                    color: cs.primary,
                    height: 6,
                  ),
                  
                  const SizedBox(height: AppSpacing.md),
                  
                  Text(
                    'Tap to restore',
                    style: AppTypography.caption.copyWith(
                      color: cs.onSurfaceVariant,
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

  Widget _buildStepItem(GenerationStep step) {
    final cs = Theme.of(context).colorScheme;
    IconData icon;
    Color color;
    
    switch (step.status) {
      case StepStatus.completed:
        icon = Icons.check_circle;
        color = AppColors.success;
        break;
      case StepStatus.inProgress:
        icon = Icons.autorenew;
        color = AppColors.primary;
        break;
      case StepStatus.pending:
        icon = Icons.radio_button_unchecked;
        color = cs.onSurfaceVariant;
        break;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(
          color: step.status == StepStatus.inProgress 
              ? cs.primary 
              : cs.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          // Step icon
          if (step.status == StepStatus.inProgress)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _pulseController.value * 2 * 3.14159,
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                );
              },
            )
          else
            Icon(
              icon,
              color: color,
              size: 24,
            ),
          
          const SizedBox(width: AppSpacing.lg),
          
          // Step info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: AppTypography.body2.copyWith(
                    fontWeight: FontWeight.w600,
                    color: step.status == StepStatus.inProgress 
                        ? cs.primary 
                        : cs.onSurface,
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xs),
                
                Text(
                  step.description,
                  style: AppTypography.caption.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final cs = Theme.of(context).colorScheme;
    final tn = (_templateName ?? '').trim();
    final p = (_prompt ?? '').trim();
    final subtitle = tn.isNotEmpty ? '3/3 • $tn' : '3/3';

    return Row(
      children: [
        IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: Icon(
            Icons.close,
            color: cs.onSurface,
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Generating Game',
                  style: AppTypography.subtitle1.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                if (p.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                    ),
                    child: Text(
                      p,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: AppShadows.boxShadowPrimaryGlow,
                  ),
                  child: Text(
                    'AI Forge',
                    style: AppTypography.caption.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: _minimizeGeneration,
          child: Text(
            'Minimize',
            style: AppTypography.body2.copyWith(
              color: cs.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat({required String label, required String value}) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.55),
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.subtitle2.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({required int index, required GenerationStep step}) {
    final cs = Theme.of(context).colorScheme;
    final isLast = index == _steps.length - 1;
    final isActive = step.status == StepStatus.inProgress;

    IconData icon;
    Color accent;
    switch (step.status) {
      case StepStatus.completed:
        icon = Icons.check_rounded;
        accent = AppColors.success;
        break;
      case StepStatus.inProgress:
        icon = Icons.auto_awesome;
        accent = cs.primary;
        break;
      case StepStatus.pending:
        icon = Icons.circle_outlined;
        accent = cs.onSurfaceVariant;
        break;
    }

    final leading = Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isActive ? AppColors.primaryGradient : null,
            color: !isActive ? cs.surface : null,
            border: Border.all(
              color: isActive ? cs.primary : cs.outlineVariant,
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive ? AppShadows.boxShadowPrimaryGlow : null,
          ),
          child: Center(
            child: isActive
                ? AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _pulseController.value * 2 * 3.14159,
                        child: Icon(icon, color: cs.onPrimary, size: 18),
                      );
                    },
                  )
                : Icon(icon, color: accent, size: 18),
          ),
        ),
        if (!isLast)
          Expanded(
            child: Container(
              width: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: (step.status == StepStatus.completed)
                    ? AppColors.success.withOpacity(0.6)
                    : cs.outlineVariant.withOpacity(0.6),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 44, child: leading),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(isActive ? 0.95 : 0.78),
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                border: Border.all(
                  color: isActive ? cs.primary.withOpacity(0.8) : cs.outlineVariant.withOpacity(0.8),
                  width: isActive ? 1.4 : 1,
                ),
                boxShadow: isActive ? AppShadows.boxShadowPrimaryGlow : AppShadows.boxShadowSmall,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.title,
                          style: AppTypography.body1.copyWith(
                            color: isActive ? cs.primary : cs.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: step.status == StepStatus.completed
                            ? Icon(Icons.verified_rounded, key: const ValueKey('done'), color: AppColors.success)
                            : step.status == StepStatus.inProgress
                                ? Icon(Icons.bolt_rounded, key: const ValueKey('go'), color: cs.primary)
                                : const SizedBox(key: ValueKey('none'), width: 0, height: 0),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    step.description,
                    style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _minimizeGeneration() {
    setState(() {
      _isMinimized = true;
    });
  }

  void _restoreGeneration() {
    setState(() {
      _isMinimized = false;
    });
  }

  void _showCancelDialog() {
    final outerContext = context;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Generation'),
        content: const Text(
          'Are you sure you want to cancel the game generation? All progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
            },
            child: const Text('Keep Generating'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              if (!mounted) return;
              // Use the screen's context for go_router navigation.
              outerContext.go('/dashboard');
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

class GenerationStep {
  final String title;
  final String description;
  StepStatus status;

  GenerationStep({
    required this.title,
    required this.description,
    required this.status,
  });
}

enum StepStatus {
  pending,
  inProgress,
  completed,
}
