import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
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

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _autoNavigate();
  }

  void _initializeAnimations() {
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

    // Title animations
    _titleOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeIn,
    ));

    _titleSlide = Tween<double>(
      begin: -80.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOutBack,
    ));

    _titleScale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.elasticOut,
    ));

    // Subtitle animations
    _subtitleOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _subtitleController,
      curve: Curves.easeIn,
    ));

    _subtitleSlide = Tween<double>(
      begin: 60.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _subtitleController,
      curve: Curves.easeOutBack,
    ));

    // Card animations
    _cardOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeIn,
    ));

    _cardSlide = Tween<double>(
      begin: 120.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutBack,
    ));

    // Button animations
    _buttonOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeIn,
    ));

    _buttonScale = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.elasticOut,
    ));

    // Background animations
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
    _backgroundController.forward();
    _floatingController.repeat(reverse: true);
    _titleController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _subtitleController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _cardController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _buttonController.forward();
    
    // No auto-navigation - user controls when to proceed
  }

  void _autoNavigate() async {
    // Auto-navigation removed
  }

  @override
  void dispose() {
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
      body: AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.background,
                  AppColors.backgroundLight,
                  AppColors.primary.withOpacity(0.1 * _backgroundGradient.value),
                  AppColors.secondary.withOpacity(0.05 * _backgroundGradient.value),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Advanced background decoration
                _buildAdvancedBackground(),
                
                // Main content
                SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: AppSpacing.paddingHorizontalLarge,
                      child: Column(
                        children: [
                          const SizedBox(height: AppSpacing.xxxl),
                          
                          // Animated title
                          _buildAnimatedTitle(),
                          
                          const SizedBox(height: AppSpacing.lg),
                          
                          // Animated subtitle
                          _buildAnimatedSubtitle(),
                          
                          const SizedBox(height: AppSpacing.xxxl),
                          
                          // Animated feature cards
                          _buildAnimatedFeatureCards(),
                          
                          const SizedBox(height: AppSpacing.xxxl),
                          
                          // Animated buttons
                          _buildAnimatedButtons(),
                          
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
                  'Welcome to\nGameFrog AI',
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
          offset: Offset(0, (1.0 - animationValue) * 50),
          child: Opacity(
            opacity: animationValue,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.surface,
                    AppColors.surfaceLight,
                    color.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                border: Border.all(
                  color: color.withOpacity(0.3 * animationValue),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2 * animationValue),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color,
                          color.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4 * animationValue),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  
                  const SizedBox(width: AppSpacing.lg),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.subtitle2.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        
                        const SizedBox(height: AppSpacing.xs),
                        
                        Text(
                          description,
                          style: AppTypography.body2.copyWith(
                            color: AppColors.textSecondary,
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
            child: Column(
              children: [
                // Get Started button with advanced effects
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 50,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppBorderRadius.large),
                      onTap: () {
                        context.go('/features');
                      },
                      child: Center(
                        child: Text(
                          'Get Started',
                          style: AppTypography.button.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Sign In button with glassmorphism
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    border: Border.all(
                      color: AppColors.border.withOpacity(0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppBorderRadius.large),
                      onTap: () {
                        context.go('/signin');
                      },
                      child: Center(
                        child: Text(
                          'I already have an account',
                          style: AppTypography.button.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
