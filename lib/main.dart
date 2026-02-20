import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'core/router/app_router.dart';
import 'core/services/billing_service.dart';
import 'core/services/app_notifier.dart';
import 'core/services/local_notifications_service.dart';
import 'core/themes/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/build_monitor_provider.dart';
import 'core/providers/theme_provider.dart';
import 'presentation/admin/admin_app.dart';

void main() async {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Zone.current.handleUncaughtError(details.exception, details.stack ?? StackTrace.current);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    Zone.current.handleUncaughtError(error, stack);
    return true;
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    var stripePublishableKey = const String.fromEnvironment('STRIPE_PUBLISHABLE_KEY', defaultValue: '');

    if (stripePublishableKey.isEmpty) {
      try {
        final res = await BillingService.getStripeConfig();
        if (res['success'] == true && res['data'] is Map) {
          final data = Map<String, dynamic>.from(res['data'] as Map);
          stripePublishableKey = (data['publishableKey']?.toString() ?? '').trim();
        }
      } catch (_) {}
    }

    if (stripePublishableKey.isNotEmpty) {
      Stripe.publishableKey = stripePublishableKey;
      Stripe.urlScheme = 'flutterstripe';
      await Stripe.instance.applySettings();
    }

    // Initialize auth provider
    final authProvider = AuthProvider();
    await authProvider.init();

    final themeProvider = ThemeProvider();
    await themeProvider.init();

    try {
      await LocalNotificationsService.init();
      await LocalNotificationsService.bootstrapDailyQuizReminder();
    } catch (_) {}

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => authProvider),
          ChangeNotifierProvider(create: (_) => themeProvider),
          ChangeNotifierProvider(create: (_) => BuildMonitorProvider()),
        ],
        child: kIsWeb ? const AdminApp() : const GameForgeAI(),
      ),
    );
  }, (error, stack) {
    // Keep this as a plain print so it shows up even if logging infra is not ready.
    // ignore: avoid_print
    print('UNCAUGHT_ERROR: $error\n$stack');
  });
}

class GameForgeAI extends StatelessWidget {
  const GameForgeAI({super.key});

  @override
  Widget build(BuildContext context) {
    return const _GameForgeApp();
  }
}

class _GameForgeApp extends StatefulWidget {
  const _GameForgeApp();

  @override
  State<_GameForgeApp> createState() => _GameForgeAppState();
}

class _GameForgeAppState extends State<_GameForgeApp> {
  StreamSubscription<String>? _notifSub;

  @override
  void initState() {
    super.initState();

    void handlePayload(String payload) {
      final p = payload.trim();
      if (p.isEmpty) return;

      if (p.startsWith('build_results:')) {
        final pid = p.substring('build_results:'.length).trim();
        if (pid.isEmpty) return;
        AppRouter.router.go('/build-results?projectId=$pid');
      }
    }

    final launchPayload = LocalNotificationsService.consumeLaunchPayload();
    if (launchPayload != null && launchPayload.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handlePayload(launchPayload);
      });
    }

    _notifSub = LocalNotificationsService.onNotificationTap.listen(handlePayload);
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _notifSub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ThemeProvider>(
      builder: (context, _authProvider, themeProvider, child) {
        return MaterialApp.router(
          title: 'GameForge AI',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: AppNotifier.messengerKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: AppRouter.router,
        );
      },
    );
  }
}
