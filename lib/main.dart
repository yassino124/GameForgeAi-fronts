import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'core/router/app_router.dart';
import 'core/services/billing_service.dart';
import 'core/themes/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';

void main() async {
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
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => authProvider),
        ChangeNotifierProvider(create: (_) => themeProvider),
      ],
      child: const GameForgeAI(),
    ),
  );
}

class GameForgeAI extends StatelessWidget {
  const GameForgeAI({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ThemeProvider>(
      builder: (context, _authProvider, themeProvider, child) {
        return MaterialApp.router(
          title: 'GameForge AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: AppRouter.router,
        );
      },
    );
  }
}
