import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../widgets/widgets.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;
  late final TextEditingController _websiteController;

  PreferredSizeWidget _buildGlassAppBar(ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + AppSpacing.sm),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(isDark ? 0.72 : 0.86),
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.35)),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight + AppSpacing.sm,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/dashboard?tab=profile');
                        }
                      },
                      icon: Icon(Icons.arrow_back, color: cs.onSurface),
                    ),
                    Expanded(
                      child: Text(
                        'Edit Profile',
                        textAlign: TextAlign.center,
                        style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _fullNameController = TextEditingController();
    _bioController = TextEditingController();
    _locationController = TextEditingController();
    _websiteController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = context.read<AuthProvider>();
    final currentUsername = authProvider.user?['username']?.toString() ?? '';
    final currentFullName = authProvider.user?['fullName']?.toString() ?? '';
    final currentBio = authProvider.user?['bio']?.toString() ?? '';
    final currentLocation = authProvider.user?['location']?.toString() ?? '';
    final currentWebsite = authProvider.user?['website']?.toString() ?? '';

    if (_usernameController.text.isEmpty && currentUsername.isNotEmpty) {
      _usernameController.text = currentUsername;
    }

    if (_fullNameController.text.isEmpty && currentFullName.isNotEmpty) {
      _fullNameController.text = currentFullName;
    }
    if (_bioController.text.isEmpty && currentBio.isNotEmpty) {
      _bioController.text = currentBio;
    }
    if (_locationController.text.isEmpty && currentLocation.isNotEmpty) {
      _locationController.text = currentLocation;
    }
    if (_websiteController.text.isEmpty && currentWebsite.isNotEmpty) {
      _websiteController.text = currentWebsite;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar(AuthProvider authProvider) async {
    if (authProvider.token == null) return;

    final cs = Theme.of(context).colorScheme;

    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: cs.surface,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: cs.onSurface),
                title: Text('Gallery', style: TextStyle(color: cs.onSurface)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: cs.onSurface),
                title: Text('Camera', style: TextStyle(color: cs.onSurface)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    final picked = await picker.pickImage(
      source: source,
      imageQuality: 92,
    );

    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 92,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Edit photo',
          toolbarColor: cs.surface,
          toolbarWidgetColor: cs.onSurface,
          activeControlsWidgetColor: cs.primary,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        IOSUiSettings(
          title: 'Edit photo',
        ),
      ],
    );

    if (cropped == null) return;

    final success = await authProvider.updateAvatar(File(cropped.path));
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo updated'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Failed to update photo'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _save(AuthProvider authProvider) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final username = _usernameController.text.trim();
    final fullName = _fullNameController.text.trim();
    final bio = _bioController.text.trim();
    final location = _locationController.text.trim();
    final website = _websiteController.text.trim();

    final success = await authProvider.updateProfile(
      username: username,
      fullName: fullName,
      bio: bio,
      location: location,
      website: website,
    );
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: AppColors.success,
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/dashboard?tab=profile');
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(authProvider.errorMessage ?? 'Failed to update profile'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  String? _validateUsername(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter your username';
    if (v.length < 3) return 'Username must be at least 3 characters';
    if (v.length > 24) return 'Username must be 24 characters or less';
    final isValid = RegExp(r'^[a-zA-Z0-9_\.\-]+$').hasMatch(v);
    if (!isValid) return 'Only letters, numbers, underscore, dot and dash are allowed';
    return null;
  }

  String? _validateFullName(String? value) {
    final v = value?.trim() ?? '';
    if (v.length > 60) return 'Full name must be 60 characters or less';
    return null;
  }

  String? _validateBio(String? value) {
    final v = value ?? '';
    if (v.length > 280) return 'Bio must be 280 characters or less';
    return null;
  }

  String? _validateLocation(String? value) {
    final v = value?.trim() ?? '';
    if (v.length > 60) return 'Location must be 60 characters or less';
    return null;
  }

  String? _validateWebsite(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final uri = Uri.tryParse(v);
    final isValid = uri != null && uri.isAbsolute;
    if (!isValid || !(v.startsWith('http://') || v.startsWith('https://'))) {
      return 'Website must be a valid URL (include https://)';
    }
    if (v.length > 200) return 'Website must be 200 characters or less';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final cs = Theme.of(context).colorScheme;
        final user = authProvider.user;
        final email = user?['email']?.toString() ?? '';
        final avatar = user?['avatar']?.toString();
        final username = user?['username']?.toString() ?? 'User';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: _buildGlassAppBar(cs),
          body: Container(
            decoration: BoxDecoration(
              gradient: isDark ? AppColors.backgroundGradient : AppTheme.backgroundGradientLight,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 12),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                                    decoration: BoxDecoration(
                                      color: cs.surface.withOpacity(isDark ? 0.40 : 0.55),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
                                    ),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: AppColors.primaryGradient,
                                            boxShadow: [
                                              BoxShadow(
                                                color: cs.primary.withOpacity(0.28),
                                                blurRadius: 22,
                                                offset: const Offset(0, 14),
                                              ),
                                            ],
                                          ),
                                          child: CircleAvatar(
                                            radius: 54,
                                            backgroundColor: cs.primary,
                                            backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                            child: avatar == null || avatar.isEmpty
                                                ? Text(
                                                    username.isNotEmpty ? username[0].toUpperCase() : 'U',
                                                    style: AppTypography.h2.copyWith(
                                                      color: cs.onPrimary,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 2,
                                          right: -2,
                                          child: GestureDetector(
                                            onTap: authProvider.isLoading ? null : () => _pickAndUploadAvatar(authProvider),
                                            child: Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                gradient: AppColors.primaryGradient,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: cs.surface.withOpacity(0.85), width: 2),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: cs.primary.withOpacity(0.30),
                                                    blurRadius: 16,
                                                    offset: const Offset(0, 10),
                                                  ),
                                                ],
                                              ),
                                              child: authProvider.isLoading
                                                  ? const Padding(
                                                      padding: EdgeInsets.all(10),
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    )
                                                  : Icon(
                                                      Icons.camera_alt_rounded,
                                                      size: 18,
                                                      color: cs.onPrimary,
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppBorderRadius.large),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  decoration: BoxDecoration(
                                    color: cs.surface.withOpacity(isDark ? 0.50 : 0.72),
                                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                                    border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                                  ),
                                  child: Column(
                                    children: [
                                      CustomTextField(
                                        label: 'Full Name',
                                        hint: 'Enter your full name',
                                        prefixIcon: Icons.badge,
                                        controller: _fullNameController,
                                        textInputAction: TextInputAction.next,
                                        maxLength: 60,
                                        showCharacterCount: true,
                                        enabled: !authProvider.isLoading,
                                        validator: _validateFullName,
                                      ),
                                      const SizedBox(height: AppSpacing.lg),
                                      CustomTextField(
                                        label: 'Username',
                                        hint: 'Enter your username',
                                        prefixIcon: Icons.person,
                                        controller: _usernameController,
                                        textInputAction: TextInputAction.done,
                                        maxLength: 24,
                                        showCharacterCount: true,
                                        enabled: !authProvider.isLoading,
                                        validator: _validateUsername,
                                        onSubmitted: (_) => _save(authProvider),
                                      ),
                                      const SizedBox(height: AppSpacing.lg),
                                      CustomTextField(
                                        label: 'Bio',
                                        hint: 'Tell us about you',
                                        prefixIcon: Icons.short_text,
                                        controller: _bioController,
                                        keyboardType: TextInputType.multiline,
                                        textInputAction: TextInputAction.newline,
                                        maxLines: 4,
                                        maxLength: 280,
                                        showCharacterCount: true,
                                        enabled: !authProvider.isLoading,
                                        validator: _validateBio,
                                      ),
                                      const SizedBox(height: AppSpacing.lg),
                                      CustomTextField(
                                        label: 'Location',
                                        hint: 'City, Country',
                                        prefixIcon: Icons.location_on,
                                        controller: _locationController,
                                        textInputAction: TextInputAction.next,
                                        maxLength: 60,
                                        showCharacterCount: true,
                                        enabled: !authProvider.isLoading,
                                        validator: _validateLocation,
                                      ),
                                      const SizedBox(height: AppSpacing.lg),
                                      CustomTextField(
                                        label: 'Website',
                                        hint: 'https://example.com',
                                        prefixIcon: Icons.link,
                                        controller: _websiteController,
                                        textInputAction: TextInputAction.next,
                                        maxLength: 200,
                                        showCharacterCount: true,
                                        enabled: !authProvider.isLoading,
                                        validator: _validateWebsite,
                                      ),
                                      const SizedBox(height: AppSpacing.lg),
                                      CustomTextField(
                                        label: 'Email',
                                        hint: email,
                                        prefixIcon: Icons.email,
                                        enabled: false,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 10, AppSpacing.lg, AppSpacing.lg),
                      child: Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              text: 'Save',
                              onPressed: authProvider.isLoading ? null : () => _save(authProvider),
                              isLoading: authProvider.isLoading,
                              isFullWidth: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
