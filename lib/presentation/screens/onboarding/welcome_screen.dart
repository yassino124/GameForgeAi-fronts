import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _titleController;
  late AnimationController _subtitleController;
  late AnimationController _cardController;
  late AnimationController _buttonController;
  late AnimationController _backgroundController;
  late AnimationController _floatingController;
  late AnimationController _entryController;

  late Animation<double> _titleOpacity;
  late Animation<double> _titleSlide;
  late Animation<double> _titleScale;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _subtitleSlide;
  late Animation<double> _cardOpacity;
  late Animation<double> _cardSlide;
  late Animation<double> _buttonOpacity;
  late Animation<double> _buttonScale;
  late Animation<double> _backgroundGradient;
  late Animation<double> _floatingAnimation;
  late Animation<double> _entryFade;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _titleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _subtitleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    _entryFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeIn),
    );

    _titleOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeIn,
    ));

    _titleSlide = Tween<double>(
      begin: -40.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOutCubic,
    ));

    _titleScale = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOutBack,
    ));

    _subtitleOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _subtitleController,
      curve: Curves.easeIn,
    ));

    _subtitleSlide = Tween<double>(
      begin: 20.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _subtitleController,
      curve: Curves.easeOutCubic,
    ));

    _cardOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeIn,
    ));

    _cardSlide = Tween<double>(
      begin: 40.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    ));

    _buttonOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeIn,
    ));

    _buttonScale = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeOutBack,
    ));

    _backgroundGradient = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    _floatingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() async {
    _entryController.forward();
    _backgroundController.forward();
    _floatingController.repeat(reverse: true);

    await Future.delayed(const Duration(milliseconds: 200));
    _titleController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _subtitleController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _cardController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _buttonController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _cardController.dispose();
    _buttonController.dispose();
    _backgroundController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090E),
      body: AnimatedBuilder(
        animation: Listenable.merge([_backgroundController, _entryController]),
        builder: (context, child) {
          return Opacity(
            opacity: _entryFade.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF07090E),
                    const Color(0xFF0F172A),
                    AppColors.primary.withOpacity(0.05 * _backgroundGradient.value),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  _buildAdvancedBackground(),
                  SafeArea(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: AppSpacing.paddingHorizontalLarge,
                        child: Column(
                          children: [
                            const SizedBox(height: AppSpacing.xxxl),
                            _buildAnimatedTitle(),
                            const SizedBox(height: AppSpacing.md),
                            _buildAnimatedSubtitle(),
                            const SizedBox(height: AppSpacing.xxxl),
                            _buildCenterAnimation(),
                            const SizedBox(height: AppSpacing.xxxl),
                            _buildAnimatedFeatureCards(),
                            const SizedBox(height: AppSpacing.xxxl),
                            _buildAnimatedButtons(),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdvancedBackground() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Animated gradient orbs
          AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Positioned(
                top: -150 + (_floatingAnimation.value * 50),
                right: -150 + (_floatingAnimation.value * 30),
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.3 * _floatingAnimation.value),
                        Colors.transparent,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
          
          AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Positioned(
                bottom: -200 + (_floatingAnimation.value * 40),
                left: -150 + (_floatingAnimation.value * 20),
                child: Container(
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppColors.secondary.withOpacity(0.2 * _floatingAnimation.value),
                        Colors.transparent,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
          
          // Floating particles
          ...List.generate(20, (index) {
            return AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                return Positioned(
                  top: 100 + (index * 67) % (MediaQuery.of(context).size.height - 200),
                  left: 30 + (index * 59) % (MediaQuery.of(context).size.width - 60),
                  child: Transform.translate(
                    offset: Offset(
                      (index % 2 == 0 ? 1 : -1) * _floatingAnimation.value * 15,
                      (index % 3 == 0 ? 1 : -1) * _floatingAnimation.value * 10,
                    ),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.4 * _floatingAnimation.value),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCenterAnimation() {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        return Container(
          height: 300,
          width: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating outer ring
              RotationTransition(
                turns: _floatingController,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: List.generate(4, (i) {
                      return Positioned(
                        top: i % 2 == 0 ? 0 : null,
                        bottom: i % 2 != 0 ? 0 : null,
                        left: i < 2 ? 120 : null,
                        right: i >= 2 ? 120 : null,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary,
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              // Main Glass Image
              Transform.translate(
                offset: Offset(0, -20 * _floatingAnimation.value),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(55),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 40,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(55),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Center(
                        child: Icon(
                          Icons.rocket_launch_rounded,
                          size: 110,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: AppColors.primary.withOpacity(0.8),
                              blurRadius: 30,
                            ),
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
  }

  Widget _buildAdvancedButtons() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 64,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.5),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => context.go('/features'),
              child: Center(
                child: Text(
                  'BEGIN JOURNEY',
                  style: AppTypography.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => context.go('/signin'),
          child: Text(
            'I HAVE AN ACCOUNT',
            style: AppTypography.labelLarge.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedTitle() {
    return AnimatedBuilder(
      animation: _titleController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _titleSlide.value),
          child: Transform.scale(
            scale: _titleScale.value,
            child: Opacity(
              opacity: _titleOpacity.value,
              child: ShaderMask(
                shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                child: Text(
                  'Welcome to\nGameForge AI',
                  textAlign: TextAlign.center,
                  style: AppTypography.display(Colors.white).copyWith(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    letterSpacing: -1,
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
          ),
        );
      },
    );
  }

  Widget _buildAnimatedSubtitle() {
    return AnimatedBuilder(
      animation: _subtitleController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _subtitleSlide.value),
          child: Opacity(
            opacity: _subtitleOpacity.value,
            child: Text(
              'Create stunning games with the power of artificial intelligence',
              textAlign: TextAlign.center,
              style: AppTypography.body1.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w300,
                height: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedFeatureCards() {
    return AnimatedBuilder(
      animation: _cardController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _cardSlide.value),
          child: Opacity(
            opacity: _cardOpacity.value,
            child: Column(
              children: [
                _buildAdvancedFeatureCard(
                  icon: Icons.auto_awesome,
                  title: 'AI-Powered',
                  description: 'Advanced AI algorithms generate unique game mechanics',
                  color: AppColors.primary,
                  index: 0,
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                _buildAdvancedFeatureCard(
                  icon: Icons.speed,
                  title: 'Lightning Fast',
                  description: 'Create and deploy games in minutes, not hours',
                  color: AppColors.secondary,
                  index: 1,
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                _buildAdvancedFeatureCard(
                  icon: Icons.palette,
                  title: 'Beautiful Design',
                  description: 'Professional templates and stunning visuals',
                  color: AppColors.accent,
                  index: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdvancedFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required int index,
  }) {
    return AnimatedBuilder(
      animation: _cardController,
      builder: (context, child) {
        final delay = index * 0.1;
        final animationValue = (_cardController.value - delay).clamp(0.0, 1.0);
        
        return Transform.translate(
          offset: Offset(0, (1.0 - animationValue) * 30),
          child: Opacity(
            opacity: animationValue,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: AppTypography.bodyMedium.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedButtons() {
    return AnimatedBuilder(
      animation: _buttonController,
      builder: (context, child) {
        return Transform.scale(
          scale: _buttonScale.value,
          child: Opacity(
            opacity: _buttonOpacity.value,
            child: _buildAdvancedButtons(),
          ),
        );
      },
    );
  }
}
