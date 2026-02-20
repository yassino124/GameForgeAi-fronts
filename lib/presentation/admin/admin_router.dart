import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import 'screens/login/admin_login_screen.dart';
import 'screens/overview/overview_screen.dart';
import 'screens/users/users_screen.dart';
import 'screens/users/user_detail_screen.dart';
import 'screens/projects/projects_screen.dart';
import 'screens/marketplace/templates_screen.dart';
import 'screens/builds/builds_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'layout/admin_shell.dart';

class AdminRouter {
  static GoRouter get router => _router;
  static final _router = GoRouter(
    initialLocation: '/admin/login',
    routes: [
      GoRoute(
        path: '/admin/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(
          title: _getTitleForRoute(state.uri.path),
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/admin/overview',
            builder: (context, state) => const OverviewScreen(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: '/admin/users/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return UserDetailScreen(userId: id);
            },
          ),
          GoRoute(
            path: '/admin/projects',
            builder: (context, state) => const ProjectsScreen(),
          ),
          GoRoute(
            path: '/admin/marketplace',
            builder: (context, state) => const TemplatesScreen(),
          ),
          GoRoute(
            path: '/admin/builds',
            builder: (context, state) => const BuildsScreen(),
          ),
          GoRoute(
            path: '/admin/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final authProvider = context.read<AuthProvider>();
      final isLoggedIn = authProvider.isAuthenticated;
      final isAdmin = authProvider.user?['role']?.toString().toLowerCase() == 'admin';
      final path = state.uri.path;
      final isLoginRoute = path == '/admin/login';
      final isAdminRoot = path == '/admin' || path == '/admin/';

      if (isAdminRoot) {
        return isLoggedIn && isAdmin ? '/admin/overview' : '/admin/login';
      }
      if (!isLoginRoute && (!isLoggedIn || !isAdmin)) {
        return '/admin/login';
      }
      if (isLoginRoute && isLoggedIn && isAdmin) {
        return '/admin/overview';
      }
      return null;
    },
  );

  static String _getTitleForRoute(String path) {
    switch (path) {
      case '/admin/overview':
        return 'Overview';
      case '/admin/users':
        return 'Users';
      case '/admin/projects':
        return 'Projects';
      case '/admin/marketplace':
        return 'Marketplace / Templates';
      case '/admin/builds':
        return 'Builds';
      case '/admin/notifications':
        return 'Notifications';
      case '/admin/settings':
        return 'Settings';
      default:
        if (path.startsWith('/admin/users/')) {
          return 'User Detail';
        }
        return 'Admin';
    }
  }
}
