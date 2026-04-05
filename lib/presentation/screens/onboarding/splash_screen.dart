import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _ambientController;
  late AnimationController _particleController;
  late AnimationController _pulseController;
  
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<double> _textSlide;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(duration: const Duration(milliseconds: 2800), vsync: this);
    _ambientController = AnimationController(duration: const Duration(seconds: 20), vsync: this)..repeat();
    _particleController = AnimationController(duration: const Duration(seconds: 10), vsync: this)..repeat();
    _pulseController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat(reverse: true);

    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.05).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
    ]).animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.6)));

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.4, curve: Curves.easeIn)));

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.6, 1.0, curve: Curves.easeIn)));

    _textSlide = Tween<double>(begin: 30.0, end: 0.0)
        .animate(CurvedAnimation(parent: _entryController, curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic)));

    _startFlow();
  }

  void _startFlow() async {
    _entryController.forward();
    
    // Auto-navigation after animations
    await Future.delayed(const Duration(milliseconds: 3500));
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
    _entryController.dispose();
    _ambientController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF07090E) : cs.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Dynamic Mesh Background
          AnimatedBuilder(
            animation: _ambientController,
            builder: (context, _) {
              final t = _ambientController.value * 2 * math.pi;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: math.sin(t) * 100 - 150,
                    top: math.cos(t) * 100 - 150,
                    child: Container(
                      width: 600,
                      height: 600,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Color(0x336366F1), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: math.cos(t) * 150 - 200,
                    bottom: math.sin(t) * 150 - 200,
                    child: Container(
                      width: 800,
                      height: 800,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Color(0x22A855F7), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: math.sin(t * 1.5) * 200 - 50,
                    bottom: math.cos(t * 1.5) * 100,
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Color(0x2506B6D4), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          // Noise overlay (optional for premium texture feel)
          Container(
            color: isDark ? Colors.black.withOpacity(0.15) : Colors.white.withOpacity(0.15),
          ),
          
          // Particles
          ...List.generate(35, (index) => _buildParticle(index)),
          
          // Center Content
          Center(
            child: AnimatedBuilder(
              animation: _entryController,
              builder: (context, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Enhanced Logo
                    Transform.scale(
                      scale: _logoScale.value,
                      child: Opacity(
                        opacity: _logoOpacity.value,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            final pulse = _pulseController.value;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Deep glowing aura
                                Container(
                                  width: 220,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.35 + 0.35 * pulse),
                                        blurRadius: 90 + 30 * pulse,
                                        spreadRadius: 20 + 10 * pulse,
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFFA855F7).withOpacity(0.25 + 0.25 * pulse),
                                        blurRadius: 60,
                                        spreadRadius: -10,
                                      ),
                                    ],
                                  ),
                                ),
                                // Main Logo - Premium Static PNG
                                Image.file(
                                  File('/Users/mohamedyassineouertani/Downloads/GameForge/controller_static_hd.png'),
                                  width: 260,
                                  height: 260,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    Icons.videogame_asset_rounded,
                                    size: 140,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(color: AppColors.primary.withOpacity(0.8), blurRadius: 40),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 50),
                    
                    // Enhanced Text
                    Opacity(
                      opacity: _textOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _textSlide.value),
                        child: Column(
                          children: [
                            Text(
                              'GameForge AI',
                              style: AppTypography.displayMedium.copyWith(
                                color: isDark ? Colors.white : cs.onSurface,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                                fontSize: 48,
                                shadows: isDark ? [
                                  Shadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 5)),
                                  Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4, offset: const Offset(0, 3)),
                                ] : [],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: (isDark ? Colors.white : cs.primary).withOpacity(0.06),
                                border: Border.all(color: (isDark ? Colors.white : cs.primary).withOpacity(0.12), width: 1.2),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, color: isDark ? const Color(0xFFA855F7) : cs.primary, size: 14),
                                  const SizedBox(width: 8),
                                  Text(
                                    'CREATE AMAZING GAMES WITH AI',
                                    style: AppTypography.labelLarge.copyWith(
                                      color: isDark ? const Color(0xFFE2E8F0) : cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2.0,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticle(int index) {
    final rand = math.Random(index * 12345);
    final size = rand.nextDouble() * 5 + 2;
    // Particles slowly float up
    final speedX = rand.nextDouble() * 1 - 0.5;
    final speedY = rand.nextDouble() * -1.5 - 0.5; 
    final startX = rand.nextDouble();
    final startY = rand.nextDouble();
    final delay = rand.nextDouble();
    final colorType = rand.nextInt(3); 
    
    // Mix of Purple, Blue, and Pink particles
    final Color pColor = colorType == 0 
        ? const Color(0xFF818CF8) 
        : (colorType == 1 ? const Color(0xFFE879F9) : const Color(0xFF38BDF8));

    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        final t = (_particleController.value + delay) % 1.0;
        final x = (startX + t * speedX) % 1.0;
        final y = (startY + t * speedY) % 1.0;

        final ds = math.sin(t * math.pi);
        final opacity = ds * 0.8;
        
        return Positioned(
          left: MediaQuery.of(context).size.width * x,
          top: MediaQuery.of(context).size.height * y,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pColor,
                boxShadow: [
                  BoxShadow(
                    color: pColor.withOpacity(0.9),
                    blurRadius: size * 2.5,
                    spreadRadius: size * 0.5,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
