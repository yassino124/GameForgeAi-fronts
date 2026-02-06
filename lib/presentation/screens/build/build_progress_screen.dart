import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/themes/app_theme.dart';
import '../../presentation/widgets/widgets.dart';

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
  late Animation<double> _progressAnimation;

  final List<BuildStep> _buildSteps = [
    BuildStep(
      platform: 'iOS',
      status: BuildStatus.inProgress,
      progress: 0.6,
      icon: Icons.phone_iphone,
    ),
    BuildStep(
      platform: 'Android',
      status: BuildStatus.pending,
      progress: 0.0,
      icon: Icons.phone_android,
    ),
    BuildStep(
      platform: 'Web',
      status: BuildStatus.pending,
      progress: 0.0,
      icon: Icons.language,
    ),
  ];

  double _overallProgress = 0.2;
  bool _isCompleted = false;
  bool _notifyWhenComplete = true;
  String _currentStep = 'Compiling source code';
  String _estimatedTime = '2 min 30 sec';

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
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
    _progressController.forward();
    
    // Start build simulation
    _simulateBuild();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _simulateBuild() async {
    // Simulate iOS build
    for (int i = 0; i <= 100; i += 10) {
      await Future.delayed(const Duration(milliseconds: 400));
      
      if (mounted) {
        setState(() {
          _buildSteps[0].progress = i / 100;
          _overallProgress = (_buildSteps[0].progress + _buildSteps[1].progress + _buildSteps[2].progress) / 3;
          
          if (i < 30) {
            _currentStep = 'Compiling source code';
          } else if (i < 60) {
            _currentStep = 'Optimizing assets';
          } else if (i < 90) {
            _currentStep = 'Creating package';
          } else {
            _currentStep = 'Finalizing build';
          }
          
          // Update estimated time
          final remaining = ((100 - i) / 100) * 150; // seconds
          final minutes = remaining ~/ 60;
          final seconds = (remaining % 60).toInt();
          _estimatedTime = '$minutes min ${seconds} sec';
        });
      }
    }
    
    // Complete iOS build
    if (mounted) {
      setState(() {
        _buildSteps[0].status = BuildStatus.completed;
        _buildSteps[1].status = BuildStatus.inProgress;
      });
    }
    
    // Simulate Android build
    for (int i = 0; i <= 100; i += 15) {
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (mounted) {
        setState(() {
          _buildSteps[1].progress = i / 100;
          _overallProgress = (_buildSteps[0].progress + _buildSteps[1].progress + _buildSteps[2].progress) / 3;
          
          if (i < 50) {
            _currentStep = 'Building Android APK';
          } else {
            _currentStep = 'Signing package';
          }
          
          final remaining = ((100 - i) / 100) * 90; // seconds
          final minutes = remaining ~/ 60;
          final seconds = (remaining % 60).toInt();
          _estimatedTime = '$minutes min ${seconds} sec';
        });
      }
    }
    
    // Complete Android build
    if (mounted) {
      setState(() {
        _buildSteps[1].status = BuildStatus.completed;
        _buildSteps[2].status = BuildStatus.inProgress;
      });
    }
    
    // Simulate Web build
    for (int i = 0; i <= 100; i += 20) {
      await Future.delayed(const Duration(milliseconds: 200));
      
      if (mounted) {
        setState(() {
          _buildSteps[2].progress = i / 100;
          _overallProgress = (_buildSteps[0].progress + _buildSteps[1].progress + _buildSteps[2].progress) / 3;
          _currentStep = 'Building web assets';
          
          final remaining = ((100 - i) / 100) * 45; // seconds
          _estimatedTime = '${remaining.toInt()} sec';
        });
      }
    }
    
    // Complete all builds
    if (mounted) {
      setState(() {
        _isCompleted = true;
        _overallProgress = 1.0;
        _buildSteps[2].status = BuildStatus.completed;
        _currentStep = 'Build completed successfully!';
        _estimatedTime = '0 sec';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          'Building Game',
          style: AppTypography.subtitle1.copyWith(color: cs.onSurface),
        ),
        leading: IconButton(
          onPressed: () {
            _showCancelDialog();
          },
          icon: Icon(
            Icons.close,
            color: cs.onSurface,
          ),
        ),
        actions: [
          // Notify toggle
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Row(
              children: [
                Icon(
                  Icons.notifications,
                  color: _notifyWhenComplete ? cs.primary : cs.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Switch(
                  value: _notifyWhenComplete,
                  onChanged: (value) {
                    setState(() {
                      _notifyWhenComplete = value;
                    });
                  },
                  activeColor: cs.primary,
                ),
              ],
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
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLarge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const SizedBox(height: AppSpacing.xl),
            
            // Build animation
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                        boxShadow: AppShadows.boxShadowPrimaryGlow,
                      ),
                      child: Icon(
                        Icons.build,
                        size: 50,
                        color: cs.onPrimary,
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // Current step
            Text(
              _currentStep,
              style: AppTypography.h3.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            Text(
              'Estimated time: $_estimatedTime',
              style: AppTypography.body1.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppSpacing.xxxl),
            
            // Overall progress
            ProgressIndicatorWidget(
              progress: _overallProgress,
              color: AppColors.primary,
              height: 12,
              borderRadius: AppBorderRadius.allMedium,
            ),
            
            const SizedBox(height: AppSpacing.xxxl),
            
            // Platform builds
            Text(
              'Platform Builds',
              style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            ..._buildSteps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _buildPlatformCard(step, index),
              );
            }),
            
            // Build log (expandable)
            const SizedBox(height: AppSpacing.xl),
            
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: ExpansionTile(
                title: Text(
                  'Build Log',
                  style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
                ),
                leading: Icon(
                  Icons.terminal,
                  color: cs.primary,
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLogEntry('Starting build process...', LogLevel.info),
                        _buildLogEntry('Loading project configuration...', LogLevel.info),
                        _buildLogEntry('Compiling source code...', LogLevel.info),
                        _buildLogEntry('Optimizing assets...', LogLevel.info),
                        if (_isCompleted) ...[
                          _buildLogEntry('Build completed successfully!', LogLevel.success),
                        ] else ...[
                          _buildLogEntry('Building in progress...', LogLevel.info),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxxl),
            
            // Action buttons
            if (_isCompleted) ...[
              CustomButton(
                text: 'View Results',
                onPressed: () {
                  context.go('/build-results');
                },
                type: ButtonType.primary,
                size: ButtonSize.large,
                isFullWidth: true,
              ),
            ] else ...[
              CustomButton(
                text: 'Cancel Build',
                onPressed: _showCancelDialog,
                type: ButtonType.danger,
                isFullWidth: true,
              ),
            ],
            
            const SizedBox(height: AppSpacing.xl),
            ],
          ),
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
