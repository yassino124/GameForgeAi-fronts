import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../widgets/widgets.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with TickerProviderStateMixin {
  late AnimationController _checkmarkController;
  late AnimationController _pulseController;
  late Animation<double> _checkmarkAnimation;
  late Animation<double> _pulseAnimation;

  bool _isVerified = false;
  bool _canResend = true;
  int _resendCountdown = 30;

  @override
  void initState() {
    super.initState();
    
    _checkmarkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _checkmarkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _checkmarkController,
      curve: Curves.elasticOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _checkmarkController.forward();
    _pulseController.repeat(reverse: true);

    // Simulate email verification after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isVerified = true;
        });
      }
    });

    // Start countdown for resend
    _startResendCountdown();
  }

  @override
  void dispose() {
    _checkmarkController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
        return _resendCountdown > 0;
      }
      return false;
    }).then((_) {
      if (mounted) {
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundGradient
              : AppTheme.backgroundGradientLight,
        ),
        child: SafeArea(
          child: Padding(
            padding: AppSpacing.paddingHorizontalLarge,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xxxl),
                
                // Email icon with animation
                AnimationConfiguration.staggeredList(
                  position: 0,
                  duration: const Duration(milliseconds: 500),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isVerified 
                                    ? AppColors.success.withOpacity(0.1)
                                    : AppColors.primary.withOpacity(0.1),
                                boxShadow: _isVerified
                                    ? AppShadows.custom(color: AppColors.success)
                                    : AppShadows.boxShadowPrimaryGlow,
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Icon(
                                      _isVerified ? Icons.check_circle : Icons.email,
                                      size: 60,
                                      color: _isVerified ? AppColors.success : AppColors.primary,
                                    ),
                                  ),
                                  
                                  // Checkmark animation
                                  if (_isVerified)
                                    Positioned.fill(
                                      child: AnimatedBuilder(
                                        animation: _checkmarkAnimation,
                                        builder: (context, child) {
                                          return CustomPaint(
                                            painter: CheckmarkPainter(
                                              progress: _checkmarkAnimation.value,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xxxl),
                
                // Title
                AnimationConfiguration.staggeredList(
                  position: 1,
                  duration: const Duration(milliseconds: 500),
                  child: SlideAnimation(
                    verticalOffset: 30.0,
                    child: FadeInAnimation(
                      child: Text(
                        _isVerified ? 'Email Verified!' : 'Verify your email',
                        style: AppTypography.h2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Instruction text
                AnimationConfiguration.staggeredList(
                  position: 2,
                  duration: const Duration(milliseconds: 500),
                  child: SlideAnimation(
                    verticalOffset: 30.0,
                    child: FadeInAnimation(
                      child: Text(
                        _isVerified
                            ? 'Your email has been successfully verified. You can now start creating amazing games!'
                            : 'We\'ve sent a verification link to your email. Please check your inbox and click the link to verify your account.',
                        style: AppTypography.body1.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xxxl),
                
                // Resend email section (only show if not verified)
                if (!_isVerified) ...[
                  AnimationConfiguration.staggeredList(
                    position: 3,
                    duration: const Duration(milliseconds: 500),
                    child: SlideAnimation(
                      verticalOffset: 30.0,
                      child: FadeInAnimation(
                        child: Column(
                          children: [
                            Text(
                              'Didn\'t receive the email?',
                              style: AppTypography.body2.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextButton(
                              onPressed: _canResend ? _resendEmail : null,
                              child: Text(
                                _canResend 
                                    ? 'Resend Email'
                                    : 'Resend in $_resendCountdown',
                                style: AppTypography.button.copyWith(
                                  color: _canResend 
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.xxxl),
                ],
                
                // Continue button
                AnimationConfiguration.staggeredList(
                  position: 4,
                  duration: const Duration(milliseconds: 500),
                  child: SlideAnimation(
                    verticalOffset: 30.0,
                    child: FadeInAnimation(
                      child: CustomButton(
                        text: 'Continue to App',
                        onPressed: _isVerified ? () {
                          context.go('/dashboard');
                        } : null,
                        type: ButtonType.primary,
                        size: ButtonSize.large,
                        isFullWidth: true,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resendEmail() async {
    setState(() {
      _canResend = false;
      _resendCountdown = 30;
    });

    try {
      // TODO: Implement resend email logic
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend email: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    _startResendCountdown();
  }
}

class CheckmarkPainter extends CustomPainter {
  final double progress;

  CheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.success
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final checkmarkSize = size.width * 0.6;

    // Draw checkmark path
    final path = Path();
    
    // Start point
    final startPoint = Offset(
      center.dx - checkmarkSize * 0.3,
      center.dy,
    );
    
    // Middle point
    final middlePoint = Offset(
      center.dx - checkmarkSize * 0.1,
      center.dy + checkmarkSize * 0.2,
    );
    
    // End point
    final endPoint = Offset(
      center.dx + checkmarkSize * 0.3,
      center.dy - checkmarkSize * 0.2,
    );

    // Animate the checkmark drawing
    if (progress <= 0.5) {
      // First segment: start to middle
      final segmentProgress = progress * 2;
      final currentPoint = Offset.lerp(startPoint, middlePoint, segmentProgress)!;
      path.moveTo(startPoint.dx, startPoint.dy);
      path.lineTo(currentPoint.dx, currentPoint.dy);
    } else {
      // Complete first segment
      path.moveTo(startPoint.dx, startPoint.dy);
      path.lineTo(middlePoint.dx, middlePoint.dy);
      
      // Second segment: middle to end
      final segmentProgress = (progress - 0.5) * 2;
      final currentPoint = Offset.lerp(middlePoint, endPoint, segmentProgress)!;
      path.lineTo(currentPoint.dx, currentPoint.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
