import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/admin_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';

// Conditional import for dart:io (not available on web)
import 'dart:io' as io show File;

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _showPasswordFields = false;
  bool _isUploadingAvatar = false;
  String? _errorMessage;
  XFile? _selectedAvatarFile;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    print('User data: ${authProvider.user}');
    final user = authProvider.user;
    
    if (user != null) {
      _usernameController.text = user['username'] ?? '';
      _emailController.text = user['email'] ?? '';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _currentPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final imagePicker = ImagePicker();
      final pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      setState(() {
        _selectedAvatarFile = pickedFile;
        _isUploadingAvatar = true;
        _errorMessage = null;
      });

      final authProvider = context.read<AuthProvider>();
      
      // Check if running on web
      const isWeb = bool.fromEnvironment('dart.library.html', defaultValue: false);
      
      bool success;
      if (isWeb) {
        // For web, use uploadAvatarWeb with bytes
        success = await authProvider.uploadAvatarWeb(
          fileName: _selectedAvatarFile!.name,
          bytes: await _selectedAvatarFile!.readAsBytes(),
        );
      } else {
        // For native platforms, use updateAvatar with File
        success = await authProvider.updateAvatar(
          io.File(_selectedAvatarFile!.path),
        );
      }

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar uploaded successfully'),
            backgroundColor: AdminTheme.accentGreen,
          ),
        );
      } else {
        setState(() {
          _errorMessage = authProvider.errorMessage ?? 'Failed to upload avatar';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error uploading avatar: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      
      // Update basic profile info
      final success = await authProvider.updateProfile(
        username: _usernameController.text.trim(),
      );

      if (!success) {
        setState(() {
          _errorMessage = authProvider.errorMessage ?? 'Failed to update profile';
        });
        return;
      }

      // Update password if provided
      if (_showPasswordFields && _passwordController.text.isNotEmpty) {
        final passwordSuccess = await authProvider.changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _passwordController.text,
        );

        if (!passwordSuccess) {
          setState(() {
            _errorMessage = authProvider.errorMessage ?? 'Failed to update password';
          });
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AdminTheme.accentNeon,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AdminTheme.bgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminTheme.borderGlow),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      UserAvatar(
                        avatarUrl: user?['avatar']?.toString(),
                        username: user?['username']?.toString() ?? 'A',
                        radius: 40,
                        backgroundColor: AdminTheme.accentPurple,
                        textColor: AdminTheme.accentPurple,
                      ),
                      if (!_isUploadingAvatar)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickAndUploadAvatar,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AdminTheme.accentNeon,
                                border: Border.all(color: AdminTheme.bgSecondary, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, size: 16, color: AdminTheme.bgPrimary),
                            ),
                          ),
                        )
                      else
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AdminTheme.accentGreen,
                              border: Border.all(color: AdminTheme.bgSecondary, width: 2),
                            ),
                            child: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AdminTheme.bgPrimary)),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?['username'] ?? 'Admin',
                          style: GoogleFonts.orbitron(
                            color: AdminTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?['email'] ?? '',
                          style: GoogleFonts.rajdhani(
                            color: AdminTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AdminTheme.accentNeon.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            user?['role']?.toString().toUpperCase() ?? 'ADMIN',
                            style: GoogleFonts.rajdhani(
                              color: AdminTheme.accentNeon,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Form Fields
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AdminTheme.bgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminTheme.borderGlow),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Information',
                    style: GoogleFonts.orbitron(
                      color: AdminTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Username
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: TextStyle(color: AdminTheme.textSecondary),
                      filled: true,
                      fillColor: AdminTheme.bgTertiary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AdminTheme.borderGlow),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AdminTheme.borderGlow),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AdminTheme.accentNeon, width: 2),
                      ),
                    ),
                    style: TextStyle(color: AdminTheme.textPrimary),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Username is required';
                      }
                      if (value.trim().length < 3) {
                        return 'Username must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: AdminTheme.textSecondary),
                      filled: true,
                      fillColor: AdminTheme.bgTertiary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AdminTheme.borderGlow),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AdminTheme.borderGlow),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AdminTheme.accentNeon, width: 2),
                      ),
                    ),
                    style: TextStyle(color: AdminTheme.textPrimary),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Password Section Toggle
                  Row(
                    children: [
                      Text(
                        'Change Password',
                        style: GoogleFonts.orbitron(
                          color: AdminTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _showPasswordFields,
                        onChanged: (value) {
                          setState(() {
                            _showPasswordFields = value;
                            if (!value) {
                              _passwordController.clear();
                              _currentPasswordController.clear();
                              _confirmPasswordController.clear();
                            }
                          });
                        },
                        activeThumbColor: AdminTheme.accentNeon,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_showPasswordFields) ...[
                    // Current Password
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        labelStyle: TextStyle(color: AdminTheme.textSecondary),
                        filled: true,
                        fillColor: AdminTheme.bgTertiary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AdminTheme.borderGlow),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AdminTheme.borderGlow),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AdminTheme.accentNeon, width: 2),
                        ),
                      ),
                      style: TextStyle(color: AdminTheme.textPrimary),
                      validator: (value) {
                        if (_showPasswordFields && (value == null || value.isEmpty)) {
                          return 'Current password is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // New Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        labelStyle: TextStyle(color: AdminTheme.textSecondary),
                        filled: true,
                        fillColor: AdminTheme.bgTertiary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AdminTheme.borderGlow),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AdminTheme.borderGlow),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AdminTheme.accentNeon, width: 2),
                        ),
                      ),
                      style: TextStyle(color: AdminTheme.textPrimary),
                      validator: (value) {
                        if (_showPasswordFields && value != null && value.isNotEmpty) {
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Confirm New Password
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        labelStyle: TextStyle(color: AdminTheme.textSecondary),
                        filled: true,
                        fillColor: AdminTheme.bgTertiary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AdminTheme.borderGlow),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AdminTheme.borderGlow),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AdminTheme.accentNeon, width: 2),
                        ),
                      ),
                      style: TextStyle(color: AdminTheme.textPrimary),
                      validator: (value) {
                        if (_showPasswordFields && _passwordController.text.isNotEmpty) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Error Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminTheme.accentRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminTheme.accentRed.withOpacity(0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.rajdhani(
                    color: AdminTheme.accentRed,
                    fontSize: 14,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go('/admin/users'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AdminTheme.borderGlow),
                      foregroundColor: AdminTheme.textSecondary,
                    ),
                    child: Text(
                      'Back to Users',
                      style: GoogleFonts.rajdhani(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AdminTheme.accentNeon,
                      foregroundColor: AdminTheme.bgPrimary,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Update Profile',
                            style: GoogleFonts.rajdhani(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
