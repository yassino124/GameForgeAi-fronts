import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../widgets/widgets.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _floatingController;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..forward();
    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);
    _floatingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090E),
      body: Stack(
        children: [
          // Dynamic Background (Matches Splash/Welcome)
          _buildAdvancedBackground(),
          
          SafeArea(
            child: Column(
              children: [
                _buildCustomAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: AppSpacing.paddingHorizontalLarge,
                      child: Column(
                        children: [
                          const SizedBox(height: AppSpacing.xl),
                          _buildCenterIllustration(),
                          const SizedBox(height: AppSpacing.xxl),
                          _buildPremiumHeader(),
                          const SizedBox(height: AppSpacing.xxxl),
                          _buildGlassPermissionList(),
                          const SizedBox(height: AppSpacing.xxxl),
                          _buildActionButtons(),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
                        AppColors.primary.withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFA855F7).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterIllustration() {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -15 * _floatingAnimation.value),
          child: Container(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Rotating Neon Aura
                RotationTransition(
                  turns: _floatingController,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: SweepGradient(
                        colors: [
                          AppColors.primary,
                          const Color(0xFFA855F7),
                          const Color(0xFF06B6D4),
                          AppColors.primary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(55),
                    ),
                  ),
                ),
                // Glass Shield
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(45),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(45),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: const Center(
                        child: Icon(
                          Icons.security_rounded,
                          size: 70,
                          color: Colors.white,
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

  Widget _buildPremiumHeader() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
          child: Text(
            'Experience\nGameForge AI',
            textAlign: TextAlign.center,
            style: AppTypography.displayMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 38,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'We need these permissions to unlock the full power of game creation.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyLarge.copyWith(
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassPermissionList() {
    return Column(
      children: [
        _buildGlassPermissionItem(
          icon: Icons.camera_rounded,
          title: 'Vision Core',
          subtitle: 'Capture images for game textures',
          color: const Color(0xFF6366F1),
        ),
        const SizedBox(height: 16),
        _buildGlassPermissionItem(
          icon: Icons.mic_rounded,
          title: 'Audio Node',
          subtitle: 'Voice commands and game sound effects',
          color: const Color(0xFFA855F7),
        ),
        const SizedBox(height: 16),
        _buildGlassPermissionItem(
          icon: Icons.folder_rounded,
          title: 'System Drive',
          subtitle: 'Save projects and generated builds',
          color: const Color(0xFF06B6D4),
        ),
      ],
    );
  }

  Widget _buildGlassPermissionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
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
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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
    );
  }

  Widget _buildActionButtons() {
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
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => _requestPermissions(context),
              child: Center(
                child: Text(
                  'GRANT ACCESS',
                  style: AppTypography.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
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
            'LATER',
            style: AppTypography.labelLarge.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      height: kToolbarHeight + AppSpacing.sm,
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
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Icon(
                    Icons.arrow_back,
                    color: AppColors.textPrimary,
                    size: 24,
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
                  'Permissions',
                  style: AppTypography.h2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          
          // Progress indicator (3/3) with WOW design
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
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          
          const SizedBox(width: AppSpacing.lg),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.subtitle2,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermissions(BuildContext context) async {
    try {
      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      
      // Request storage permission
      final storageStatus = await Permission.storage.request();
      
      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      
      // Show dialog with results
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permissions Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPermissionStatus('Camera', cameraStatus),
              _buildPermissionStatus('Storage', storageStatus),
              _buildPermissionStatus('Microphone', micStatus),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                }
                context.go('/signin');
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error requesting permissions: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildPermissionStatus(String permission, PermissionStatus status) {
    Color statusColor;
    String statusText;
    
    switch (status) {
      case PermissionStatus.granted:
        statusColor = AppColors.success;
        statusText = 'Granted';
        break;
      case PermissionStatus.denied:
        statusColor = AppColors.warning;
        statusText = 'Denied';
        break;
      case PermissionStatus.permanentlyDenied:
        statusColor = AppColors.error;
        statusText = 'Permanently Denied';
        break;
      case PermissionStatus.limited:
        statusColor = AppColors.warning;
        statusText = 'Limited';
        break;
      case PermissionStatus.provisional:
        statusColor = AppColors.warning;
        statusText = 'Provisional';
        break;
      case PermissionStatus.restricted:
        statusColor = AppColors.error;
        statusText = 'Restricted';
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusText = 'Unknown';
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            '$permission: ',
            style: AppTypography.body2,
          ),
          Text(
            statusText,
            style: AppTypography.body2.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
