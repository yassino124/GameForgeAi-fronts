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
import '../../presentation/screens/quiz/game_quiz_screen.dart';

class AppRouter {
  static Page<T> _fadeSlidePage<T>({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.02, 0.02), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

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
        pageBuilder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return _fadeSlidePage(child: const SignInScreen(), state: state);
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

          return _fadeSlidePage(child: HomeDashboard(initialIndex: initialIndex), state: state);
        },
      ),
      
      // Project creation routes (protected)
      GoRoute(
        path: '/create-project',
        pageBuilder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return _fadeSlidePage(child: const SignInScreen(), state: state);
          }
          return _fadeSlidePage(child: const TemplateSelectionScreen(), state: state);
        },
      ),

      GoRoute(
        path: '/ai-create-game',
        pageBuilder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return _fadeSlidePage(child: const SignInScreen(), state: state);
          }
          return _fadeSlidePage(child: const AiCreateGameScreen(), state: state);
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
        pageBuilder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return _fadeSlidePage(child: const SignInScreen(), state: state);
          }
          return _fadeSlidePage(child: const AIConfigurationScreen(), state: state);
        },
      ),
      GoRoute(
        path: '/generation-progress',
        pageBuilder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return _fadeSlidePage(child: const SignInScreen(), state: state);
          }
          return _fadeSlidePage(child: const GenerationProgressScreen(), state: state);
        },
      ),
      GoRoute(
        path: '/project-detail',
        pageBuilder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return _fadeSlidePage(child: const SignInScreen(), state: state);
          }
          final extra = state.extra;
          final data = extra is Map ? Map<String, dynamic>.from(extra as Map) : <String, dynamic>{};
          return _fadeSlidePage(child: ProjectDetailScreen(data: data), state: state);
        },
      ),

      GoRoute(
        path: '/play-webgl',
        pageBuilder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return _fadeSlidePage(child: const SignInScreen(), state: state);
          }
          final extra = state.extra;
          final url = (extra is Map) ? extra['url']?.toString() : null;
          return _fadeSlidePage(child: PlayWebglScreen(url: url ?? ''), state: state);
        },
      ),

      GoRoute(
        path: '/ai-coach',
        pageBuilder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return _fadeSlidePage(child: const SignInScreen(), state: state);
          }
          final extra = state.extra;
          final data = extra is Map ? Map<String, dynamic>.from(extra as Map) : <String, dynamic>{};
          final rawPid = data['projectId']?.toString() ?? '';
          final pid = rawPid.trim().isEmpty ? null : rawPid.trim();
          final name = data['projectName']?.toString();
          return _fadeSlidePage(child: AiCoachScreen(projectId: pid, projectName: name), state: state);
        },
      ),

      GoRoute(
        path: '/game-quiz',
        pageBuilder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return _fadeSlidePage(child: const SignInScreen(), state: state);
          }
          return _fadeSlidePage(child: const GameQuizScreen(), state: state);
        },
      ),
      
      // Build routes (protected)
      GoRoute(
        path: '/build-configuration',
        pageBuilder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return _fadeSlidePage(child: const SignInScreen(), state: state);
          }
          return _fadeSlidePage(child: const BuildConfigurationScreen(), state: state);
        },
      ),
      GoRoute(
        path: '/build-progress',
        pageBuilder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return _fadeSlidePage(child: const SignInScreen(), state: state);
          }
          return _fadeSlidePage(child: const BuildProgressScreen(), state: state);
        },
      ),
      GoRoute(
        path: '/build-results',
        pageBuilder: (context, state) {
          if (!AuthGuard.canActivate(context)) {
            return _fadeSlidePage(child: const SignInScreen(), state: state);
          }
          return _fadeSlidePage(child: const BuildResultsScreen(), state: state);
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
