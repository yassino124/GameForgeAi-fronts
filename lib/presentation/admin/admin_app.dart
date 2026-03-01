import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_router.dart';
import 'constants/admin_theme.dart';
import 'providers/admin_provider.dart';
import '../../../core/providers/auth_provider.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return ChangeNotifierProvider(
          create: (_) => AdminProvider()..setTokenGetter(() => authProvider.token),
          child: MaterialApp.router(
            title: 'GameForgeAI Admin',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: AdminTheme.bgPrimary,
              colorScheme: const ColorScheme.dark(
                primary: AdminTheme.accentNeon,
                secondary: AdminTheme.accentPurple,
                surface: AdminTheme.bgSecondary,
                onPrimary: AdminTheme.bgPrimary,
                onSecondary: AdminTheme.textPrimary,
                onSurface: AdminTheme.textPrimary,
                error: AdminTheme.accentRed,
              ),
              textTheme: TextTheme(
                headlineLarge: GoogleFonts.orbitron(color: AdminTheme.textPrimary),
                headlineMedium: GoogleFonts.orbitron(color: AdminTheme.textPrimary),
                bodyLarge: GoogleFonts.rajdhani(color: AdminTheme.textPrimary),
                bodyMedium: GoogleFonts.rajdhani(color: AdminTheme.textSecondary),
                labelLarge: GoogleFonts.rajdhani(color: AdminTheme.textPrimary),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AdminTheme.bgTertiary,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminTheme.borderGlow)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminTheme.accentNeon, width: 2)),
                hintStyle: const TextStyle(color: AdminTheme.textSecondary),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.accentNeon,
                  foregroundColor: AdminTheme.bgPrimary,
                ),
              ),
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
                  TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
                },
              ),
            ),
            routerConfig: AdminRouter.router,
          ),
        );
      },
    );
  }
}
