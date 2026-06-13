import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
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
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    // Feature emoji/icon with advanced effects
                    _buildAdvancedFeatureIcon(feature),
                    
                    const SizedBox(height: 40),
                    
                    // Feature title with Neon Glow
                    ShaderMask(
                      shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                      child: Text(
                        feature.title.toUpperCase(),
                        style: AppTypography.h1.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 34,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Feature description with glass panel
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Text(
                        feature.description,
                        style: AppTypography.bodyLarge.copyWith(
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Feature highlights with premium tiles
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: feature.highlights.asMap().entries.map((entry) {
                        final highlightIndex = entry.key;
                        final highlight = entry.value;
                        final delay = highlightIndex * 0.1;
                        final animationValue = (_cardController.value - delay).clamp(0.0, 1.0);
                        
                        return Transform.scale(
                          scale: animationValue,
                          child: Opacity(
                            opacity: animationValue,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: AppColors.primary,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    highlight,
                                    style: AppTypography.labelLarge.copyWith(
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 30),
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
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        return Container(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating Background Glow
              RotationTransition(
                turns: _floatingController,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(60),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
              // Glassmorphism Container
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Center(
                      child: Text(
                        feature.emoji,
                        style: TextStyle(
                          fontSize: 110,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Floating Orbiting Dots
              ...List.generate(3, (i) {
                return RotationTransition(
                  turns: _floatingController,
                  child: Transform.translate(
                    offset: Offset(
                      110 * (i == 0 ? 1 : i == 1 ? -0.5 : -0.5),
                      110 * (i == 0 ? 0 : i == 1 ? 0.86 : -0.86),
                    ),
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary,
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
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
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: isActive ? 32 : 10,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: isActive 
                      ? AppColors.primaryGradient
                      : LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                  boxShadow: isActive ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.6),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ] : [],
                  border: Border.all(
                    color: isActive ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
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
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _currentPage > 0 ? 1.0 : 0.0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    if (_currentPage > 0) {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOutCubic,
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Back',
                          style: AppTypography.button.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Next button with WOW design
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: () {
                  if (_currentPage < _features.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                    );
                  } else {
                    context.go('/signin');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentPage < _features.length - 1 ? 'NEXT' : 'LAUNCH',
                        style: AppTypography.button.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        _currentPage < _features.length - 1 
                            ? Icons.arrow_forward_ios_rounded 
                            : Icons.auto_awesome_rounded,
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
      icon: Icons.psychology_rounded,
      title: 'AI ENGINE CORE',
      description: 'The world\'s most advanced Neural Engine. Describe any game in natural language and watch GameForge AI write the code, generate assets, and build mechanics instantly.',
      emoji: '🧠',
      highlights: [
        'Natural Language Dev',
        'Auto-Logic Generation',
        'Smart Physics AI',
        'Real-time Synthesis',
      ],
    ),
    Feature(
      icon: Icons.auto_fix_high_rounded,
      title: 'ZERO CODE FORGE',
      description: 'Absolute freedom from coding. Our visual orchestration layer transforms your creative vision into high-performance games without writing a single line of syntax.',
      emoji: '🛠️',
      highlights: [
        'Visual Orchestration',
        'No-Code Workflow',
        'Drag & Drop Power',
        'Auto-Refactor AI',
      ],
    ),
    Feature(
      icon: Icons.rocket_launch_rounded,
      title: 'QUANTUM DEPLOY',
      description: 'The fastest path from idea to player. One-tap global deployment with high-fidelity WebGL optimization for instant play on any device, anywhere.',
      emoji: '🚀',
      highlights: [
        'Single-Tap Launch',
        'High-Fidelity WebGL',
        'Global Distribution',
        'Instant Playback',
      ],
    ),
    Feature(
      icon: Icons.token_rounded,
      title: 'INFINITE ASSET AI',
      description: 'Endless creativity at your fingertips. Generate professional-grade 3D models, textures, characters, and environments using deep generative models.',
      emoji: '💎',
      highlights: [
        'Generative 3D AI',
        'HD Texture Synth',
        'Dynamic NPC Gen',
        'Atmospheric VFX',
      ],
    ),
    Feature(
      icon: Icons.groups_rounded,
      title: 'CREATOR HUB',
      description: 'Enter the future of social game development. Collaborate in real-time with teams across the globe and showcase your masterpieces to millions.',
      emoji: '🌐',
      highlights: [
        'Real-time Co-Dev',
        'Marketplace Access',
        'Team Synergy AI',
        'Viral Discovery',
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
