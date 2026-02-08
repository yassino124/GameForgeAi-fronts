import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';
import '../themes/app_theme.dart';
import '../guards/auth_guard.dart';
import '../../presentation/screens/onboarding/onboarding.dart';
import '../../presentation/screens/auth/auth.dart';
import '../../presentation/screens/dashboard/dashboard.dart';
import '../../presentation/screens/project/project.dart';
import '../../presentation/screens/build/build.dart';
import '../../presentation/screens/marketplace/marketplace.dart';
import '../../presentation/screens/profile/profile.dart';
import '../../presentation/screens/notifications/notifications.dart';
import '../../presentation/screens/assets/assets_library_screen.dart';
import '../../presentation/screens/assets/assets_export_screen.dart';
import '../../presentation/screens/project/project_export_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      // Onboarding routes
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/features',
        builder: (context, state) => const FeaturesScreen(),
      ),
      GoRoute(
        path: '/permissions',
        builder: (context, state) => const PermissionsScreen(),
      ),
      
      // Authentication routes
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'];
          return ForgotPasswordScreen(initialEmail: email);
        },
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'];
          final token = state.uri.queryParameters['token'];
          final link = state.uri.queryParameters['link'];
          return ResetPasswordScreen(
            initialEmail: email,
            initialTokenOrUrl: token ?? link,
          );
        },
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/email-verification',
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      
      // Main app routes (protected)
      GoRoute(
        path: '/dashboard',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }

          final tab = state.uri.queryParameters['tab'];
          int initialIndex = 0;
          if (tab != null && tab.isNotEmpty) {
            switch (tab) {
              case 'home':
                initialIndex = 0;
                break;
              case 'projects':
                initialIndex = 1;
                break;
              case 'templates':
                initialIndex = 2;
                break;
              case 'profile':
                initialIndex = 3;
                break;
              default:
                final parsed = int.tryParse(tab);
                if (parsed != null && parsed >= 0 && parsed <= 3) {
                  initialIndex = parsed;
                }
            }
          }

          return HomeDashboard(initialIndex: initialIndex);
        },
      ),
      
      // Project creation routes (protected)
      GoRoute(
        path: '/create-project',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const TemplateSelectionScreen();
        },
      ),

      GoRoute(
        path: '/templates/upload',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const TemplateUploadScreen();
        },
      ),
      GoRoute(
        path: '/project-details',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const ProjectDetailsScreen();
        },
      ),
      GoRoute(
        path: '/ai-configuration',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const AIConfigurationScreen();
        },
      ),
      GoRoute(
        path: '/generation-progress',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const GenerationProgressScreen();
        },
      ),
      GoRoute(
        path: '/project-detail',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          final extra = state.extra;
          final data = extra is Map ? Map<String, dynamic>.from(extra as Map) : <String, dynamic>{};
          return ProjectDetailScreen(data: data);
        },
      ),
      
      // Build routes (protected)
      GoRoute(
        path: '/build-configuration',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const BuildConfigurationScreen();
        },
      ),
      GoRoute(
        path: '/build-progress',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const BuildProgressScreen();
        },
      ),
      GoRoute(
        path: '/build-results',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const BuildResultsScreen();
        },
      ),
      
      // Marketplace routes (protected)
      GoRoute(
        path: '/marketplace',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const TemplateMarketplaceScreen();
        },
      ),

      GoRoute(
        path: '/template/:id',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          final id = state.pathParameters['id'] ?? '';
          return TemplateDetailsScreen(templateId: id);
        },
      ),
      
      // Profile and settings routes (protected)
      GoRoute(
        path: '/profile',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const UserProfileScreen();
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const SettingsScreen();
        },
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const EditProfileScreen();
        },
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const ChangePasswordScreen();
        },
      ),
      GoRoute(
        path: '/subscription',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const SubscriptionScreen();
        },
      ),

      GoRoute(
        path: '/assets',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const AssetsLibraryScreen();
        },
      ),
      GoRoute(
        path: '/assets/export',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          final extra = state.extra;
          final url = (extra is Map) ? extra['url']?.toString() : null;
          return AssetsExportScreen(url: url ?? '');
        },
      ),

      GoRoute(
        path: '/projects/export',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          final extra = state.extra;
          final url = (extra is Map) ? extra['url']?.toString() : null;
          return ProjectExportScreen(url: url ?? '');
        },
      ),

      GoRoute(
        path: '/how-to-use',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const HowToUseScreen();
        },
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const AboutAppScreen();
        },
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const PrivacyPolicyScreen();
        },
      ),
      GoRoute(
        path: '/terms-of-service',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const TermsOfServiceScreen();
        },
      ),
      GoRoute(
        path: '/security-center',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const SecurityCenterScreen();
        },
      ),
      
      // Notification and messaging routes (protected)
      GoRoute(
        path: '/notifications',
        builder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return const SignInScreen();
          }
          return const NotificationsScreen();
        },
      ),
      GoRoute(
        path: '/messages',
        builder: (context, state) => const InAppMessagesScreen(),
      ),
      
      // TODO: Add more routes as we implement them
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Page not found',
              style: AppTypography.h3,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              state.error.toString(),
              style: AppTypography.body2.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
