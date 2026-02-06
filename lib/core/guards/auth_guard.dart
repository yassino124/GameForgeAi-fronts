import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class AuthGuard {
  static bool canActivate(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.isAuthenticated;
  }

  static String redirectIfNotAuthenticated(BuildContext context, String redirectPath) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      return '/signin';
    }
    return redirectPath;
  }

  static String redirectIfAuthenticated(BuildContext context, String redirectPath) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated) {
      return '/dashboard';
    }
    return redirectPath;
  }
}
