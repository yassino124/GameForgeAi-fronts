import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _particleController;
  late AnimationController _textController;
  late AnimationController _glowController;
  
  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _logoOpacity;
  late Animation<double> _particleOpacity;
  late Animation<double> _textOpacity;
  late Animation<double> _textSlide;
  late Animation<double> _glowPulse;
  late Animation<double> _backgroundGradient;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Logo animations
    _logoScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _logoRotation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));

    _logoOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    // Particle animations
    _particleOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: Curves.easeIn,
    ));

    // Text animations
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ));

    _textSlide = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutBack,
    ));

    // Glow effects
    _glowPulse = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    _backgroundGradient = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() async {
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _glowController.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 500));
    _particleController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _textController.forward();
    
    // Auto-navigation after animations
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (!authProvider.isAuthenticated && authProvider.biometricEnabled) {
        await authProvider.tryBiometricLogin();
      }
      if (!mounted) return;
      context.go(authProvider.isAuthenticated ? '/dashboard' : '/welcome');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _particleController.dispose();
    _textController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _logoController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 2.0 + (_backgroundGradient.value * 0.5),
                colors: [
                  AppColors.primary.withOpacity(0.3 * _backgroundGradient.value),
                  AppColors.background,
                  AppColors.surfaceDark,
                ],
              ),
            ),
            child: Stack(
              children: [
                // Animated particle background
                _buildParticleBackground(),
                
                // Main content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo with advanced effects
                      _buildAdvancedLogo(),
                      
                      const SizedBox(height: AppSpacing.xxxl),
                      
                      // Title with animation
                      _buildAnimatedTitle(),
                      
                      const SizedBox(height: AppSpacing.lg),
                      
                      // Subtitle
                      _buildAnimatedSubtitle(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdvancedLogo() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _logoRotation.value * 0.1,
          child: Transform.scale(
            scale: _logoScale.value,
            child: Opacity(
              opacity: _logoOpacity.value,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 80,
                      spreadRadius: 20,
                    ),
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.1),
                      blurRadius: 120,
                      spreadRadius: 30,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Inner glow effect
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        return Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                AppColors.primaryLight.withOpacity(0.4 * _glowPulse.value),
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                        );
                      },
                    ),
                    
                    // Logo icon with glow
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.9),
                            Colors.white.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.gamepad,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    
                    // Pulse ring effect
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_glowPulse.value * 0.1),
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.primaryLight.withOpacity(0.6 * _glowPulse.value),
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(35),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedTitle() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _textSlide.value),
          child: Opacity(
            opacity: _textOpacity.value,
            child: ShaderMask(
              shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
              child: Text(
                'GameFrog AI',
                style: AppTypography.display(Colors.white).copyWith(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  letterSpacing: -2,
                  shadows: [
                    Shadow(
                      color: AppColors.primary.withOpacity(0.6),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                    Shadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 60,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedSubtitle() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        return Opacity(
          opacity: _textOpacity.value * 0.8,
          child: Text(
            'Create Amazing Games with AI',
            style: AppTypography.subtitle1.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w300,
              letterSpacing: 1,
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticleBackground() {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        return Opacity(
          opacity: _particleOpacity.value * 0.4,
          child: Stack(
            children: List.generate(25, (index) {
              final size = (index % 4 + 1) * 3.0;
              final opacity = (index % 6 + 1) * 0.15;
              
              return Positioned(
                top: 100 + (index * 37) % (MediaQuery.of(context).size.height - 200),
                left: 50 + (index * 43) % (MediaQuery.of(context).size.width - 100),
                child: AnimatedBuilder(
                  animation: _particleController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        (index % 2 == 0 ? 1 : -1) * _particleController.value * 30,
                        (index % 3 == 0 ? 1 : -1) * _particleController.value * 20,
                      ),
                      child: Transform.rotate(
                        angle: _particleController.value * (index % 3 + 1) * 0.2,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(size / 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(opacity),
                                blurRadius: size * 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
