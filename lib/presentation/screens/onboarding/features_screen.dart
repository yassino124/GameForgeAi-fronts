import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../widgets/widgets.dart';

class FeaturesScreen extends StatefulWidget {
  const FeaturesScreen({super.key});

  @override
  State<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends State<FeaturesScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _cardController;
  late AnimationController _backgroundController;
  late AnimationController _floatingController;
  late AnimationController _indicatorController;
  
  late Animation<double> _cardOpacity;
  late Animation<double> _cardSlide;
  late Animation<double> _backgroundGradient;
  late Animation<double> _floatingAnimation;
  late Animation<double> _indicatorPulse;
  
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
  }

  void _initializeAnimations() {
    _pageController = PageController();
    
    _cardController = AnimationController(
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
    
    _indicatorController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _cardOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeIn,
    ));

    _cardSlide = Tween<double>(
      begin: 100.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
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

    _indicatorPulse = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _indicatorController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() async {
    _backgroundController.forward();
    _floatingController.repeat(reverse: true);
    _indicatorController.repeat(reverse: true);
    _cardController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cardController.dispose();
    _backgroundController.dispose();
    _floatingController.dispose();
    _indicatorController.dispose();
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
                // Advanced background
                _buildAdvancedBackground(),
                
                // Main content
                SafeArea(
                  child: Column(
                    children: [
                      // Custom App Bar with back button
                      _buildCustomAppBar(),
                      
                      const SizedBox(height: AppSpacing.lg),
                      
                      // PageView for features
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _features.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return _buildFeaturePage(_features[index], index);
                          },
                        ),
                      ),
                      
                      // Advanced page indicators
                      _buildAdvancedIndicators(),
                      
                      // Bottom navigation with WOW design
                      _buildBottomNavigation(),
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

  Widget _buildCustomAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button with WOW design
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              border: Border.all(
                color: AppColors.border.withOpacity(0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/welcome');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.arrow_back,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          
          // Title with gradient - Centered
          Expanded(
            child: Center(
              child: ShaderMask(
                shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                child: Text(
                  'Features',
                  style: AppTypography.h2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          
          // Skip button with WOW design
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    'Skip',
                    style: AppTypography.button.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
                top: -200 + (_floatingAnimation.value * 60),
                right: -200 + (_floatingAnimation.value * 40),
                child: Container(
                  width: 500,
                  height: 500,
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
                bottom: -250 + (_floatingAnimation.value * 50),
                left: -200 + (_floatingAnimation.value * 30),
                child: Container(
                  width: 600,
                  height: 600,
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
          ...List.generate(30, (index) {
            return AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                return Positioned(
                  top: 100 + (index * 43) % (MediaQuery.of(context).size.height - 200),
                  left: 20 + (index * 37) % (MediaQuery.of(context).size.width - 40),
                  child: Transform.translate(
                    offset: Offset(
                      (index % 2 == 0 ? 1 : -1) * _floatingAnimation.value * 20,
                      (index % 3 == 0 ? 1 : -1) * _floatingAnimation.value * 15,
                    ),
                    child: Transform.rotate(
                      angle: _floatingAnimation.value * (index % 4 + 1) * 0.3,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4 * _floatingAnimation.value),
                              blurRadius: 4,
                            ),
                          ],
                        ),
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

  Widget _buildFeaturePage(Feature feature, int index) {
    return AnimatedBuilder(
      animation: _cardController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _cardSlide.value),
          child: Opacity(
            opacity: _cardOpacity.value,
            child: Padding(
              padding: AppSpacing.paddingHorizontalLarge,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Feature emoji/icon with advanced effects
                    _buildAdvancedFeatureIcon(feature),
                    
                    const SizedBox(height: AppSpacing.xxl),
                    
                    // Feature title
                    Text(
                      feature.title,
                      style: AppTypography.h2.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: AppSpacing.md),
                    
                    // Feature description
                    Text(
                      feature.description,
                      style: AppTypography.body1.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w300,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: AppSpacing.xl),
                    
                    // Feature highlights with staggered animation
                    ...feature.highlights.asMap().entries.map((entry) {
                      final highlightIndex = entry.key;
                      final highlight = entry.value;
                      final delay = highlightIndex * 0.1;
                      final animationValue = (_cardController.value - delay).clamp(0.0, 1.0);
                      
                      return AnimatedBuilder(
                        animation: _cardController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, (1.0 - animationValue) * 30),
                            child: Opacity(
                              opacity: animationValue,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.3 * animationValue),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    
                                    const SizedBox(width: AppSpacing.sm),
                                    
                                    Expanded(
                                      child: Text(
                                        highlight,
                                        style: AppTypography.body2.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdvancedFeatureIcon(Feature feature) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(50),
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
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner glow effect
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  AppColors.primaryLight.withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(45),
            ),
          ),
          
          // Feature emoji
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Center(
              child: Text(
                feature.emoji,
                style: const TextStyle(fontSize: 100),
              ),
            ),
          ),
          
          // Pulse ring effect
          AnimatedBuilder(
            animation: _indicatorController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_indicatorPulse.value * 0.05),
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primaryLight.withOpacity(0.6 * _indicatorPulse.value),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedIndicators() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _features.length,
          (index) => AnimatedBuilder(
            animation: _indicatorController,
            builder: (context, child) {
              final isActive = _currentPage == index;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: isActive 
                      ? AppColors.primaryGradient
                      : LinearGradient(
                          colors: [AppColors.surfaceVariant, AppColors.surfaceVariant],
                        ),
                  boxShadow: isActive ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button with WOW design
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              border: Border.all(
                color: AppColors.border.withOpacity(0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                onTap: () {
                  if (_currentPage > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back,
                        color: _currentPage > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Previous',
                        style: AppTypography.button.copyWith(
                          color: _currentPage > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Next button with WOW design
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                onTap: () {
                  if (_currentPage < _features.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    // Last page - navigate to signin
                    context.go('/signin');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentPage < _features.length - 1 ? 'Next' : 'Get Started',
                        style: AppTypography.button.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        _currentPage < _features.length - 1 ? Icons.arrow_forward : Icons.check,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  final List<Feature> _features = [
    Feature(
      icon: Icons.auto_awesome,
      title: 'AI-Powered Creation',
      description: 'Advanced AI algorithms generate unique game mechanics and assets automatically',
      emoji: '🤖',
      highlights: [
        'Intelligent level design',
        'Asset generation',
        'Balanced gameplay',
        'Adaptive difficulty',
      ],
    ),
    Feature(
      icon: Icons.speed,
      title: 'Lightning Fast',
      description: 'Create and deploy games in minutes, not hours with our optimized workflow',
      emoji: '⚡',
      highlights: [
        'Rapid prototyping',
        'Instant deployment',
        'Real-time preview',
        'Optimized performance',
      ],
    ),
    Feature(
      icon: Icons.palette,
      title: 'Beautiful Design',
      description: 'Professional templates and stunning visuals with modern design principles',
      emoji: '🎨',
      highlights: [
        'Modern UI/UX',
        'Responsive layouts',
        'Custom themes',
        'Professional assets',
      ],
    ),
    Feature(
      icon: Icons.cloud_done,
      title: 'Cloud Storage',
      description: 'Save your projects securely in the cloud and access them anywhere',
      emoji: '☁️',
      highlights: [
        'Auto-save',
        'Version control',
        'Collaborative editing',
        'Cross-platform access',
      ],
    ),
    Feature(
      icon: Icons.people,
      title: 'Collaborative',
      description: 'Work together with your team in real-time on shared projects',
      emoji: '👥',
      highlights: [
        'Real-time sync',
        'Team chat',
        'Shared workspaces',
        'Role management',
      ],
    ),
  ];
}

class Feature {
  final IconData icon;
  final String title;
  final String description;
  final String emoji;
  final List<String> highlights;

  Feature({
    required this.icon,
    required this.title,
    required this.description,
    required this.emoji,
    List<String>? highlights,
  }) : highlights = highlights ?? [];
}
