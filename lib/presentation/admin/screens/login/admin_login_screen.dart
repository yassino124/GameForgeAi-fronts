import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../constants/admin_theme.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final ok = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      rememberMe: true,
    );

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _isLoading = false;
        _errorMessage = authProvider.errorMessage ?? 'Login failed';
      });
      return;
    }

    if (authProvider.user?['role']?.toString().toLowerCase() != 'admin') {
      await authProvider.logout(context: context);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Access denied - Admin only';
      });
      return;
    }

    setState(() => _isLoading = false);
    if (mounted) context.go('/admin/overview');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AdminTheme.bgPrimary,
              AdminTheme.bgSecondary,
              AdminTheme.bgTertiary.withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Background grid
            CustomPaint(
              size: Size.infinite,
              painter: _GridPainter(),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: AdminTheme.bgSecondary.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AdminTheme.accentNeon.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: AdminTheme.accentNeon.withOpacity(0.1),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AdminTheme.accentNeon, AdminTheme.accentPurple],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AdminTheme.accentNeon.withOpacity(0.4),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.games, size: 48, color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'GameForgeAI',
                          style: GoogleFonts.orbitron(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AdminTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Admin Dashboard',
                          style: GoogleFonts.rajdhani(
                            fontSize: 16,
                            color: AdminTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 40),
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AdminTheme.accentRed.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AdminTheme.accentRed),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AdminTheme.accentRed, size: 24),
                                const SizedBox(width: 12),
                                Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AdminTheme.accentRed))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined, color: AdminTheme.textSecondary),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                          style: const TextStyle(color: AdminTheme.textPrimary),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline, color: AdminTheme.textSecondary),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                          style: const TextStyle(color: AdminTheme.textPrimary),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AdminTheme.bgPrimary),
                                  )
                                : Text('Login', style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AdminTheme.borderGlow.withOpacity(0.3)
      ..strokeWidth = 1;
    const step = 40.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
