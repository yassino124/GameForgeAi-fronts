import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/themes/app_theme.dart';
import '../../widgets/widgets.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String? initialEmail;

  const EmailVerificationScreen({super.key, this.initialEmail});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with TickerProviderStateMixin {
  static const int _resendInitialSeconds = 30;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _successController;
  late Animation<double> _successScale;
  late final List<TextEditingController> _digitControllers;
  late final List<FocusNode> _digitFocusNodes;

  late final String _email;
  bool _canResend = true;
  bool _isVerifying = false;
  int _focusedOtpIndex = -1;
  bool _verificationSuccess = false;
  int _resendCountdown = _resendInitialSeconds;

  double get _resendProgress =>
      (_resendCountdown / _resendInitialSeconds).clamp(0.0, 1.0);

  String get _resendTimeLabel {
    final seconds = _resendCountdown.clamp(0, _resendInitialSeconds);
    return '00:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();

    _digitControllers = List.generate(6, (_) => TextEditingController());
    _digitFocusNodes = List.generate(6, (_) => FocusNode());
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _successController = AnimationController(
      duration: const Duration(milliseconds: 560),
      vsync: this,
    );
    _successScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 40,
      ),
    ]).animate(_successController);

    // Start animations
    _pulseController.repeat(reverse: true);

    for (int i = 0; i < _digitFocusNodes.length; i++) {
      _digitFocusNodes[i].addListener(() {
        if (!mounted) return;
        if (_digitFocusNodes[i].hasFocus) {
          setState(() => _focusedOtpIndex = i);
        } else if (_focusedOtpIndex == i) {
          setState(() => _focusedOtpIndex = -1);
        }
      });
    }

    _email = (widget.initialEmail ?? '').trim();

    // Start countdown for resend
    _startResendCountdown();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _successController.dispose();
    for (final c in _digitControllers) {
      c.dispose();
    }
    for (final n in _digitFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _digitControllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    final v = value.trim();

    if (v.length > 1) {
      final digits = v.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6; i++) {
        _digitControllers[i].text = i < digits.length ? digits[i] : '';
      }
      if (digits.length >= 6) {
        _digitFocusNodes[5].unfocus();
      } else {
        final next = digits.length.clamp(0, 5);
        _digitFocusNodes[next].requestFocus();
      }
      setState(() {});

      if (_otpCode.length == 6 && !_isVerifying) {
        _verifyCode();
      }
      return;
    }

    if (v.isNotEmpty && index < 5) {
      _digitFocusNodes[index + 1].requestFocus();
    }
    setState(() {});

    if (_otpCode.length == 6 && !_isVerifying) {
      _verifyCode();
    }
  }

  void _onBackspace(int index) {
    if (_digitControllers[index].text.isEmpty && index > 0) {
      _digitFocusNodes[index - 1].requestFocus();
      _digitControllers[index - 1].clear();
      setState(() {});
    }
  }

  void _startResendCountdown() {
    if (mounted) {
      setState(() {
        _canResend = false;
      });
    }

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
          gradient: AppTheme.authBackgroundGradient(context),
        ),
        child: Stack(
          children: [
            const AuthBackdropGlow(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: AppSpacing.paddingHorizontalLarge.copyWith(
                      bottom: AppSpacing.xxl,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                                color: AppColors.primary.withValues(alpha: 0.1),
                                boxShadow: AppShadows.boxShadowPrimaryGlow,
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Icon(
                                      Icons.email,
                                      size: 60,
                                      color: AppColors.primary,
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
                        'Verify your email',
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
                        _email.isNotEmpty
                            ? 'We\'ve sent a 6-digit verification code to $_email. Enter it below to activate your account.'
                            : 'We\'ve sent a 6-digit verification code to your email. Enter it below to activate your account.',
                        style: AppTypography.body1.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.xxxl),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.white.withValues(alpha: 0.82),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Verification Code',
                          style: AppTypography.body1.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          final isFocused = _focusedOtpIndex == index;
                          final hasValue = _digitControllers[index].text.isNotEmpty;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                if (isFocused)
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.30),
                                    blurRadius: 16,
                                    spreadRadius: 1,
                                  )
                                else if (hasValue)
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    blurRadius: 10,
                                    spreadRadius: 0,
                                  ),
                              ],
                            ),
                            child: KeyboardListener(
                              focusNode: FocusNode(skipTraversal: true),
                              onKeyEvent: (event) {
                                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                                  _onBackspace(index);
                                }
                              },
                              child: TextField(
                                controller: _digitControllers[index],
                                focusNode: _digitFocusNodes[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                textInputAction: index == 5 ? TextInputAction.done : TextInputAction.next,
                                enableInteractiveSelection: true,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                style: AppTypography.h4,
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : Colors.black.withValues(alpha: 0.03),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: hasValue ? AppColors.primary.withValues(alpha: 0.75) : AppColors.border,
                                      width: hasValue ? 1.6 : 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                  ),
                                ),
                                onChanged: (value) => _onDigitChanged(index, value),
                                onTap: () {
                                  setState(() => _focusedOtpIndex = index);
                                },
                                onSubmitted: (_) {
                                  if (index == 5) {
                                    _verifyCode();
                                  }
                                },
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      AnimatedBuilder(
                        animation: _successScale,
                        builder: (context, child) {
                          final scale = _verificationSuccess ? _successScale.value : 1.0;
                          return Transform.scale(
                            scale: scale,
                            child: child,
                          );
                        },
                        child: CustomButton(
                          text: _verificationSuccess ? 'Verified ✓' : 'Verify Code',
                          isLoading: _isVerifying,
                          onPressed: _otpCode.length == 6 ? _verifyCode : null,
                          type: ButtonType.primary,
                          size: ButtonSize.large,
                          isFullWidth: true,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      Text(
                        'Didn\'t receive the email?',
                        style: AppTypography.body2.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: _canResend
                              ? AppColors.success.withValues(alpha: 0.12)
                              : AppColors.primary.withValues(alpha: 0.10),
                          border: Border.all(
                            color: _canResend
                                ? AppColors.success.withValues(alpha: 0.35)
                                : AppColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 34,
                              height: 34,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    strokeWidth: 3,
                                    value: _canResend ? 1 : _resendProgress,
                                    backgroundColor: AppColors.border.withValues(alpha: 0.30),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _canResend ? AppColors.success : AppColors.primary,
                                    ),
                                  ),
                                  Icon(
                                    _canResend ? Icons.check_rounded : Icons.schedule_rounded,
                                    size: 14,
                                    color: _canResend ? AppColors.success : AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _canResend ? 'Ready to resend' : 'Resend available in $_resendTimeLabel',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: _canResend ? AppColors.success : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _canResend
                                        ? 'You can request another code now.'
                                        : 'Please wait until the cooldown finishes.',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      TextButton.icon(
                        onPressed: _canResend ? _resendEmail : null,
                        icon: const Icon(Icons.mark_email_unread_outlined, size: 16),
                        label: Text(
                          _canResend ? 'Resend Email' : 'Please wait ${_resendCountdown}s',
                          style: AppTypography.button.copyWith(
                            color: _canResend ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxxl),
                
                // Continue button
                AnimationConfiguration.staggeredList(
                  position: 4,
                  duration: const Duration(milliseconds: 500),
                  child: SlideAnimation(
                    verticalOffset: 30.0,
                    child: FadeInAnimation(
                      child: CustomButton(
                        text: 'I verified, continue to Sign in',
                        onPressed: () {
                          if (_email.isNotEmpty) {
                            final encodedEmail = Uri.encodeComponent(_email);
                            context.go('/signin?email=$encodedEmail');
                          } else {
                            context.go('/signin');
                          }
                        },
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resendEmail() async {
    if (_email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing email. Please go back and register again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _canResend = false;
      _resendCountdown = _resendInitialSeconds;
    });

    try {
      final res = await AuthService.resendVerificationEmail(_email);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Verification email sent!'),
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

  Future<void> _verifyCode() async {
    final code = _otpCode.trim();
    if (_email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing email. Please go back and register again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit verification code.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);
    try {
      final res = await AuthService.verifyEmailCode(email: _email, code: code);
      if (!mounted) return;

      final ok = res['success'] == true;
      final msg = res['message']?.toString() ?? (ok ? 'Email verified successfully.' : 'Verification failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok ? AppColors.success : AppColors.error,
        ),
      );

      if (ok) {
        setState(() => _verificationSuccess = true);
        _successController.forward(from: 0);
        for (final c in _digitControllers) {
          c.clear();
        }
        await Future.delayed(const Duration(milliseconds: 380));
        if (!mounted) return;
        final encodedEmail = Uri.encodeComponent(_email);
        context.go('/signin?email=$encodedEmail');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to verify code: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
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
