import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../widgets/widgets.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _signInWithBiometrics() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final ok = await authProvider.tryBiometricLogin();
    if (!mounted) return;

    if (ok) {
      context.go('/dashboard');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(authProvider.errorMessage ?? 'Biometric login failed'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: kToolbarHeight + AppSpacing.sm,
        title: Text(
          'Sign In',
          style: AppTypography.subtitle1.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundGradient
              : AppTheme.backgroundGradientLight,
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: AppSpacing.paddingHorizontalLarge,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 
                    MediaQuery.of(context).padding.top - 
                    MediaQuery.of(context).padding.bottom - 
                    AppSpacing.paddingHorizontalLarge.top * 2,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                  const SizedBox(height: AppSpacing.xxxl),

                  // Logo
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.1),
                      boxShadow: AppShadows.boxShadowPrimaryGlow,
                    ),
                    child: const Icon(
                      Icons.games,
                      size: 60,
                      color: AppColors.primary,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // App name
                  Text(
                    'GameForge AI',
                    style: AppTypography.h3,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Welcome text
                  Text(
                    'Welcome back!',
                    style: AppTypography.subtitle1.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  // Sign in form
                  Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        children: [
                          // Email field
                          CustomTextField(
                            label: 'Email',
                            hint: 'Enter your email',
                            prefixIcon: Icons.email,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Password field
                          CustomTextField(
                            label: 'Password',
                            hint: 'Enter your password',
                            prefixIcon: Icons.lock,
                            obscureText: true,
                            controller: _passwordController,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                            onSubmitted: (_) => _signIn(),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // Remember me and forgot password
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              return Row(
                                children: [
                                  // Remember me checkbox
                                  InkWell(
                                    borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                                    onTap: () {
                                      authProvider.setRememberMe(!authProvider.rememberMe);
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: authProvider.rememberMe,
                                          onChanged: (value) {
                                            authProvider.setRememberMe(value ?? false);
                                          },
                                          activeColor: AppColors.primary,
                                        ),
                                        Text(
                                          'Remember me',
                                          style: AppTypography.body2,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const Spacer(),

                                  // Forgot password link
                                  GestureDetector(
                                    onTap: () => _forgotPassword(),
                                    child: Text(
                                      'Forgot Password?',
                                      style: AppTypography.body2.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                        decorationColor: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: AppSpacing.md),

                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              return FutureBuilder<bool>(
                                future: authProvider.hasBiometricLoginConfigured(),
                                builder: (context, snapshot) {
                                  final show = snapshot.data == true;
                                  if (!show) return const SizedBox.shrink();

                                  return CustomButton(
                                    text: 'Continue with Face ID / Touch ID',
                                    onPressed: _signInWithBiometrics,
                                    type: ButtonType.secondary,
                                    isLoading: authProvider.isLoading,
                                    isFullWidth: true,
                                    icon: const Icon(
                                      Icons.fingerprint,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  );
                                },
                              );
                            },
                          ),

                          const SizedBox(height: AppSpacing.xl),

                          // Sign in button
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              return CustomButton(
                                text: 'Sign In',
                                onPressed: _signIn,
                                isLoading: authProvider.isLoading,
                                isFullWidth: true,
                              );
                            },
                          ),

                          const SizedBox(height: AppSpacing.xl),

                          Consumer<AuthProvider>(
                            builder: (context, authProvider, child) {
                              return CustomButton(
                                text: 'Continue with Google',
                                onPressed: () => _signInWithGoogle(),
                                type: ButtonType.secondary,
                                isLoading: authProvider.isLoading,
                                isFullWidth: true,
                                icon: const Icon(
                                  FontAwesomeIcons.google,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: AppSpacing.xl),

                          // Sign up link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: AppTypography.body2.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  context.go('/signup');
                                },
                                child: Text(
                                  'Sign Up',
                                  style: AppTypography.body2.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      try {
        final success = await authProvider.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          rememberMe: authProvider.rememberMe,
        );

        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Login successful!'),
                backgroundColor: AppColors.success,
              ),
            );
            context.go('/dashboard');
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authProvider.errorMessage ?? 'Login failed'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unexpected error: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final success = await authProvider.loginWithGoogle(
        rememberMe: authProvider.rememberMe,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google login successful!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/dashboard');
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Google login failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    final emailQuery = email.isNotEmpty ? '?email=${Uri.encodeComponent(email)}' : '';
    context.push('/forgot-password$emailQuery');
  }
}
