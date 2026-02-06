import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../core/constants/app_constants.dart';
import '../../core/themes/app_theme.dart';
import '../../presentation/widgets/widgets.dart';

class GenerationProgressScreen extends StatefulWidget {
  const GenerationProgressScreen({super.key});

  @override
  State<GenerationProgressScreen> createState() => _GenerationProgressScreenState();
}

class _GenerationProgressScreenState extends State<GenerationProgressScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

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
    
    // Start simulation
    _simulateGeneration();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _simulateGeneration() async {
    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        setState(() {
          if (i > 0) {
            _steps[i - 1].status = StepStatus.completed;
          }
          _steps[i].status = StepStatus.inProgress;
          _overallProgress = (i + 1) / _steps.length;
        });
      }
    }
    
    // Complete generation
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() {
        _isCompleted = true;
        _overallProgress = 1.0;
        _steps.last.status = StepStatus.completed;
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
            child: Column(
              children: [
              // Header
              Row(
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
                  
                  const Expanded(
                    child: SizedBox(),
                  ),
                  
                  Text(
                    'Generating Game',
                    style: AppTypography.subtitle1.copyWith(color: cs.onSurface),
                  ),
                  
                  const Expanded(
                    child: SizedBox(),
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
              ),
              
              const SizedBox(height: AppSpacing.xxxl),
              
              // AI Brain Animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
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
              
              // Progress bar
              ProgressIndicatorWidget(
                progress: _overallProgress,
                color: cs.primary,
                height: 8,
              ),
              
              const SizedBox(height: AppSpacing.xxxl),
              
              // Generation steps
              Expanded(
                child: ListView.builder(
                  itemCount: _steps.length,
                  itemBuilder: (context, index) {
                    return _buildStepItem(_steps[index]);
                  },
                ),
              ),
              
              // Action buttons
              if (_isCompleted) ...[
                CustomButton(
                  text: 'View Game',
                  onPressed: () {
                    context.go('/project-detail');
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
              Navigator.of(context).pop();
            },
            child: const Text('Keep Generating'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back
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
