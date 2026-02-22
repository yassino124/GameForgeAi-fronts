import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/local_notifications_service.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/billing_service.dart';
import '../../../core/services/projects_service.dart';
import '../../../core/utils/app_refresh_bus.dart';
import '../../widgets/widgets.dart';

class UserProfileScreen extends StatefulWidget {
  final bool showAppBar;

  const UserProfileScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _subscriptionRefreshTick = 0;

  static const _kPrefQuizStreak = 'quiz_streak';
  static const _kPrefQuizBestScore = 'quiz_best_score';
  static const _kPrefQuizTotalXp = 'quiz_total_xp';
  static const _kPrefQuizTotalPlays = 'quiz_total_plays';
  static const _kPrefQuizBadges = 'quiz_badges';
  static const _kPrefQuizLastXpEarned = 'quiz_last_xp_earned';

  bool _quizLoading = true;
  int _quizStreak = 0;
  int _quizBestScore = 0;
  int _quizTotalXp = 0;
  int _quizTotalPlays = 0;
  List<String> _quizBadges = const [];
  int _quizLastXpEarned = 0;

  late final AnimationController _appearController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  late final VoidCallback _refreshListener;

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    return int.tryParse(s) ?? double.tryParse(s)?.toInt() ?? 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _refreshListener = () {
      _loadQuizPrefs();
    };
    AppRefreshBus.notifier.addListener(_refreshListener);

    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _appearController, curve: Curves.easeOutCubic);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _appearController, curve: Curves.easeOutCubic),
    );

    _appearController.forward();

    _loadQuizPrefs();
  }

  Future<void> _loadQuizPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _quizStreak = p.getInt(_kPrefQuizStreak) ?? 0;
        _quizBestScore = p.getInt(_kPrefQuizBestScore) ?? 0;
        _quizTotalXp = p.getInt(_kPrefQuizTotalXp) ?? 0;
        _quizTotalPlays = p.getInt(_kPrefQuizTotalPlays) ?? 0;
        _quizBadges = p.getStringList(_kPrefQuizBadges) ?? const [];
        _quizLastXpEarned = p.getInt(_kPrefQuizLastXpEarned) ?? 0;
        _quizLoading = false;
      });

      if (_quizLastXpEarned > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 2200));
        if (!mounted) return;
        await p.setInt(_kPrefQuizLastXpEarned, 0);
        if (!mounted) return;
        setState(() {
          _quizLastXpEarned = 0;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _quizLoading = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppRefreshBus.notifier.removeListener(_refreshListener);
    _appearController.dispose();
    super.dispose();
  }

  Widget _wowEntry(Widget child) {
    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(position: _slideUp, child: child),
    );
  }

  Widget _ctaGlow({required bool enabled, required Widget child}) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1600),
      curve: Curves.easeInOut,
      onEnd: () {
        if (mounted) setState(() {});
      },
      builder: (context, t, _) {
        final a = 0.14 + (0.10 * (1 - (t - 0.5).abs() * 2));
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(a),
                blurRadius: 26,
                spreadRadius: 1,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _subscriptionRefreshTick++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final cs = Theme.of(context).colorScheme;
        final user = authProvider.user;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        void _noop = _subscriptionRefreshTick;
        _noop;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: widget.showAppBar
              ? AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  toolbarHeight: kToolbarHeight + AppSpacing.sm,
                  title: Text(
                    'Profile',
                    style: AppTypography.subtitle1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  centerTitle: true,
                  actions: [
                    IconButton(
                      onPressed: () {
                        context.push('/settings');
                      },
                      icon: Icon(
                        Icons.settings,
                        color: cs.onSurface,
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await authProvider.logout(context: context);
                        if (context.mounted) {
                          context.go('/signin');
                        }
                      },
                      icon: Icon(
                        Icons.logout,
                        color: cs.error,
                      ),
                    ),
                  ],
                )
              : null,

          body: Container(
            decoration: BoxDecoration(
              gradient: isDark ? AppColors.backgroundGradient : AppTheme.backgroundGradientLight,
            ),
            child: SafeArea(
              top: !widget.showAppBar,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_quizLoading)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: (_quizLastXpEarned > 0)
                            ? _wowEntry(
                                Container(
                                  key: const ValueKey('quiz-xp-earned'),
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: AppSpacing.xl),
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                                    boxShadow: [
                                      BoxShadow(
                                        color: cs.primary.withOpacity(0.26),
                                        blurRadius: 28,
                                        offset: const Offset(0, 14),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.local_fire_department_rounded, color: Colors.white),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Text(
                                          '+$_quizLastXpEarned XP earned in Quiz',
                                          style: AppTypography.body2.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: Colors.white.withOpacity(0.28)),
                                        ),
                                        child: Text(
                                          'Level ${_levelFromXp(_quizTotalXp)}',
                                          style: AppTypography.caption.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('quiz-xp-empty')),
                      ),
                    _wowEntry(_buildProfileHeader(context, user, authProvider)),
                    const SizedBox(height: AppSpacing.xxxl),
                    _wowEntry(_buildUserStats(context)),
                    const SizedBox(height: AppSpacing.xxxl),
                    _wowEntry(_buildSubscriptionCard(context, user)),
                    const SizedBox(height: AppSpacing.xxxl),
                    _wowEntry(_buildAchievements(context)),
                    const SizedBox(height: AppSpacing.xxxl),
                    _wowEntry(_buildRecentActivity(context)),
                    const SizedBox(height: AppSpacing.xxxl),
                    _wowEntry(_buildLogoutSection(context)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _changeAvatar(BuildContext context, AuthProvider authProvider) async {
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
          toolbarColor: AppColors.surface,
          toolbarWidgetColor: AppColors.textPrimary,
          activeControlsWidgetColor: AppColors.primary,
          backgroundColor: AppColors.background,
        ),
        IOSUiSettings(
          title: 'Edit photo',
        ),
      ],
    );

    if (cropped == null) return;

    final success = await authProvider.updateAvatar(File(cropped.path));
    if (!context.mounted) return;

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

  Widget _buildProfileHeader(
    BuildContext context,
    Map<String, dynamic>? user,
    AuthProvider authProvider,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final username = user?['username']?.toString() ?? 'User';
    final fullName = user?['fullName']?.toString() ?? '';
    final bio = user?['bio']?.toString() ?? '';
    final location = user?['location']?.toString() ?? '';
    final website = user?['website']?.toString() ?? '';
    final email = user?['email']?.toString() ?? 'user@example.com';
    final avatar = user?['avatar']?.toString();
    final createdAt = user?['createdAt']?.toString();

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withOpacity(0.28),
                    AppColors.secondary.withOpacity(0.14),
                    cs.surface.withOpacity(0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: -60,
          right: -40,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withOpacity(0.16),
            ),
          ),
        ),
        Positioned(
          bottom: -90,
          left: -70,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withOpacity(0.10),
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(isDark ? 0.62 : 0.88),
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                border: Border.all(color: cs.outlineVariant.withOpacity(isDark ? 0.22 : 0.55)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, child) {
                          return Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: cs.primary.withOpacity(0.22 + (0.10 * t)),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                              gradient: LinearGradient(
                                colors: [
                                  cs.primary.withOpacity(0.75),
                                  AppColors.secondary.withOpacity(0.65),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: child,
                          );
                        },
                        child: CircleAvatar(
                          radius: 52,
                          backgroundColor: cs.surface,
                          backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                          child: avatar == null || avatar.isEmpty
                              ? Text(
                                  username.isNotEmpty ? username[0].toUpperCase() : 'U',
                                  style: AppTypography.h2.copyWith(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: authProvider.isLoading ? null : () => _changeAvatar(context, authProvider),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: cs.surface, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: cs.primary.withOpacity(0.30),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: authProvider.isLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(Icons.edit, size: 18, color: cs.onPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    (fullName.trim().isNotEmpty ? fullName.trim() : username),
                    style: AppTypography.h3.copyWith(fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                  if (fullName.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '@$username',
                      style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    email,
                    style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
                    ),
                    child: Text(
                      createdAt != null ? 'Member since ${_formatDate(createdAt)}' : 'Member since recently',
                      style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (bio.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      bio.trim(),
                      style: AppTypography.body2.copyWith(color: cs.onSurface, height: 1.3),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (location.trim().isNotEmpty || website.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (location.trim().isNotEmpty)
                          _metaPill(icon: Icons.location_on_rounded, text: location.trim(), cs: cs),
                        if (website.trim().isNotEmpty)
                          _metaPill(icon: Icons.link_rounded, text: website.trim(), cs: cs, accent: cs.primary),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: 'Edit Profile',
                      onPressed: () {
                        context.push('/edit-profile');
                      },
                      type: ButtonType.primary,
                    ),
                  ),
                  if (!widget.showAppBar) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Settings',
                            onPressed: () => context.push('/settings'),
                            type: ButtonType.secondary,
                            size: ButtonSize.small,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CustomButton(
                            text: 'Logout',
                            onPressed: () async {
                              await authProvider.logout(context: context);
                              if (context.mounted) {
                                context.go('/signin');
                              }
                            },
                            type: ButtonType.ghost,
                            size: ButtonSize.small,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _metaPill({required IconData icon, required String text, required ColorScheme cs, Color? accent}) {
    final c = accent ?? cs.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              text,
              style: AppTypography.caption.copyWith(color: cs.onSurface, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.year}';
    } catch (e) {
      return 'Recently';
    }
  }

  Widget _buildUserStats(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.read<AuthProvider>();
    final token = auth.token;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Stats',
            style: AppTypography.subtitle2,
          ),
          
          const SizedBox(height: AppSpacing.lg),

          FutureBuilder<Map<String, dynamic>>(
            future: (token == null || token.isEmpty) ? null : ProjectsService.listProjects(token: token),
            builder: (context, snapshot) {
              int projects = 0;
              int buildsFromProjects = 0;
              int downloads = 0;
              int generations = 0;

              final res = snapshot.data;
              final data = (res != null && res['success'] == true) ? res['data'] : null;
              final list = (data is Map && data['projects'] is List)
                  ? List<Map<String, dynamic>>.from(
                      (data['projects'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
                    )
                  : (data is List)
                      ? List<Map<String, dynamic>>.from(
                          data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
                        )
                      : <Map<String, dynamic>>[];

              projects = list.length;
              for (final p in list) {
                final bc = p['buildCount'] ?? p['buildsCount'] ?? p['builds'];
                final dc = p['downloadCount'] ??
                    p['downloadsCount'] ??
                    p['downloads'] ??
                    p['downloadsTotal'] ??
                    p['totalDownloads'];
                final gc = p['generationCount'] ?? p['generationsCount'] ?? p['generations'];
                buildsFromProjects += _toInt(bc);
                downloads += _toInt(dc);
                generations += _toInt(gc);
              }

              return FutureBuilder<List<Map<String, dynamic>>>(
                future: LocalNotificationsService.listInAppNotifications(),
                builder: (context, notifSnap) {
                  final notifs = notifSnap.data ?? const <Map<String, dynamic>>[];
                  final buildsFromNotifs = notifs.where((n) {
                    final data = n['data'];
                    if (data is! Map) return false;
                    return data['kind']?.toString() == 'build_finished';
                  }).length;

                  final gensFromNotifs = notifs.where((n) {
                    final data = n['data'];
                    if (data is! Map) return false;
                    return data['kind']?.toString() == 'generation_finished';
                  }).length;

                  final builds = buildsFromNotifs > 0 ? buildsFromNotifs : buildsFromProjects;
                  final generationsValue = gensFromNotifs > 0 ? gensFromNotifs : generations;

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatItem(
                              context,
                              'Projects',
                              projects.toString(),
                              Icons.videogame_asset,
                              AppColors.primary,
                            ),
                          ),
                          Expanded(
                            child: _buildStatItem(
                              context,
                              'Quiz XP',
                              _formatCompactNumber(_quizTotalXp),
                              Icons.local_fire_department_rounded,
                              AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatItem(
                              context,
                              'Builds',
                              _formatCompactNumber(builds),
                              Icons.build,
                              AppColors.success,
                            ),
                          ),
                          Expanded(
                            child: _buildStatItem(
                              context,
                              'Downloads',
                              _formatCompactNumber(downloads),
                              Icons.download,
                              AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                      if (generationsValue > 0) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                context,
                                'Generations',
                                _formatCompactNumber(generationsValue),
                                Icons.auto_awesome,
                                AppColors.primary,
                              ),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                context,
                                'Quiz Streak',
                                _quizStreak.toString(),
                                Icons.local_fire_department_outlined,
                                AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatCompactNumber(int n) {
    if (n >= 1000000) {
      final v = (n / 1000000);
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}M';
    }
    if (n >= 1000) {
      final v = (n / 1000);
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}K';
    }
    return n.toString();
  }

  int _levelFromXp(int xp) {
    if (xp <= 0) return 1;
    final level = (xp / 250).floor() + 1;
    return level.clamp(1, 999);
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          
          const SizedBox(height: AppSpacing.sm),
          
          Text(
            value,
            style: AppTypography.subtitle1.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: AppSpacing.xs),
          
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, Map<String, dynamic>? user) {
    final cs = Theme.of(context).colorScheme;

    final auth = context.read<AuthProvider>();
    final token = auth.token;

    return FutureBuilder<Map<String, dynamic>>(
      future: (token == null || token.isEmpty) ? null : BillingService.getMySubscription(token: token),
      builder: (context, snapshot) {
        final Map<String, dynamic>? data =
            (snapshot.data != null && snapshot.data!['success'] == true && snapshot.data!['data'] is Map)
                ? Map<String, dynamic>.from(snapshot.data!['data'] as Map)
                : null;

        final plan = (data != null && data['plan'] is Map) ? Map<String, dynamic>.from(data['plan'] as Map) : null;
        final planName = plan?['name']?.toString().trim().toLowerCase() ?? 'free';
        final status = data?['status']?.toString().trim().toLowerCase() ?? 'inactive';

        final isConfirmedPaid = status == 'active' || status == 'trialing';
        final isEnterprise = planName == 'enterprise';
        final isPro = planName == 'pro';
        final isPaid = (isPro || isEnterprise) && isConfirmedPaid;

        final needsPaymentFix = ['incomplete', 'past_due', 'unpaid'].contains(status);
        final isActiveLike = ['active', 'trialing'].contains(status);

        final title = isEnterprise
            ? 'Enterprise Plan'
            : isPro
                ? 'Pro Plan'
                : 'Free Plan';

        final badgeText = needsPaymentFix
            ? (status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : 'Payment issue')
            : isPaid
                ? (status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : 'Active')
                : 'Free';

        final badgeColor = needsPaymentFix
            ? AppColors.warning
            : isPaid && isActiveLike
                ? AppColors.success
                : cs.onSurfaceVariant;

        final icon = isEnterprise
            ? Icons.emoji_events
            : isPro
                ? Icons.workspace_premium
                : Icons.star_outline;

        final accent = isEnterprise
            ? const Color(0xFF22C55E)
            : isPro
                ? AppColors.primary
                : cs.onSurfaceVariant;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPaid
                  ? [
                      accent.withOpacity(0.14),
                      AppColors.secondary.withOpacity(0.10),
                    ]
                  : [
                      cs.surface,
                      cs.surface,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            border: Border.all(
              color: isPaid ? AppColors.primary.withOpacity(0.3) : cs.outlineVariant.withOpacity(0.6),
            ),
            boxShadow: AppShadows.boxShadowSmall,
          ),
          child: _wowEntry(
            Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: accent,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    title,
                    style: AppTypography.subtitle2.copyWith(
                      color: isPaid ? accent : cs.onSurfaceVariant,
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: StatusBadge(
                      key: ValueKey('badge-$badgeText-$badgeColor'),
                      text: badgeText,
                      color: badgeColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                isEnterprise
                    ? 'Teams, collaboration, and unlimited workflows'
                    : isPro
                        ? 'Unlimited game generations, premium templates, and priority support'
                        : 'Basic game generation features with limited templates',
                style: AppTypography.body2.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: needsPaymentFix
                    ? _ctaGlow(
                        enabled: true,
                        child: SizedBox(
                          key: const ValueKey('cta-fix'),
                          width: double.infinity,
                          child: CustomButton(
                            text: 'Fix payment',
                            onPressed: () async {
                              await context.push('/subscription');
                              if (!context.mounted) return;
                              setState(() {
                                _subscriptionRefreshTick++;
                              });
                            },
                            type: ButtonType.primary,
                          ),
                        ),
                      )
                    : !isPaid
                        ? Column(
                            key: const ValueKey('cta-free'),
                            children: [
                              _ctaGlow(
                                enabled: true,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: CustomButton(
                                    text: 'Upgrade to Pro',
                                    onPressed: () async {
                                      await context.push('/subscription');
                                      if (!context.mounted) return;
                                      setState(() {
                                        _subscriptionRefreshTick++;
                                      });
                                    },
                                    type: ButtonType.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              SizedBox(
                                width: double.infinity,
                                child: CustomButton(
                                  text: 'Upgrade to Enterprise',
                                  onPressed: () async {
                                    await context.push('/subscription');
                                    if (!context.mounted) return;
                                    setState(() {
                                      _subscriptionRefreshTick++;
                                    });
                                  },
                                  type: ButtonType.ghost,
                                ),
                              ),
                            ],
                          )
                        : isPro
                            ? _ctaGlow(
                                enabled: true,
                                child: SizedBox(
                                  key: const ValueKey('cta-pro'),
                                  width: double.infinity,
                                  child: CustomButton(
                                    text: 'Upgrade to Enterprise',
                                    onPressed: () async {
                                      await context.push('/subscription');
                                      if (!context.mounted) return;
                                      setState(() {
                                        _subscriptionRefreshTick++;
                                      });
                                    },
                                    type: ButtonType.primary,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('cta-enterprise')),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildAchievements(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final token = context.read<AuthProvider>().token;
    final quizBadges = _quizBadges.toSet();
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: (token == null || token.isEmpty) ? null : ProjectsService.listProjects(token: token),
            builder: (context, snapshot) {
              int projects = 0;
              int builds = 0;
              int downloads = 0;
              int generations = 0;

              final res = snapshot.data;
              final data = (res != null && res['success'] == true) ? res['data'] : null;
              final list = (data is Map && data['projects'] is List)
                  ? List<Map<String, dynamic>>.from(
                      (data['projects'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
                    )
                  : (data is List)
                      ? List<Map<String, dynamic>>.from(
                          data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
                        )
                      : <Map<String, dynamic>>[];

              projects = list.length;
              for (final p in list) {
                final bc = p['buildCount'] ?? p['buildsCount'] ?? p['builds'];
                final dc = p['downloadCount'] ?? p['downloadsCount'] ?? p['downloads'];
                final gc = p['generationCount'] ?? p['generationsCount'] ?? p['generations'];
                if (bc is num) builds += bc.toInt();
                if (dc is num) downloads += dc.toInt();
                if (gc is num) generations += gc.toInt();
              }

              final achievements = <Achievement>[
                Achievement(
                  title: 'First Game',
                  description: 'Create your first project',
                  icon: Icons.videogame_asset_rounded,
                  color: AppColors.primary,
                  unlocked: projects >= 1,
                ),
                Achievement(
                  title: 'Builder',
                  description: 'Complete 5 builds',
                  icon: Icons.build_rounded,
                  color: AppColors.success,
                  unlocked: builds >= 5,
                ),
                Achievement(
                  title: 'Generator',
                  description: 'Reach 10 generations',
                  icon: Icons.auto_awesome_rounded,
                  color: AppColors.secondary,
                  unlocked: generations >= 10,
                ),
                Achievement(
                  title: 'Popular',
                  description: 'Reach 1K downloads',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.accent,
                  unlocked: downloads >= 1000,
                ),
                Achievement(
                  title: 'First Win',
                  description: 'Answer at least 1 question correctly',
                  icon: Icons.bolt_rounded,
                  color: AppColors.warning,
                  unlocked: quizBadges.contains('first_win'),
                ),
                Achievement(
                  title: 'Streak 3',
                  description: 'Keep a 3-day daily streak',
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.accent,
                  unlocked: quizBadges.contains('streak_3'),
                ),
                Achievement(
                  title: 'Perfect',
                  description: 'Get a perfect score (daily)',
                  icon: Icons.workspace_premium_rounded,
                  color: AppColors.primary,
                  unlocked: quizBadges.contains('perfect'),
                ),
                Achievement(
                  title: 'Plays 10',
                  description: 'Complete 10 quizzes',
                  icon: Icons.repeat_rounded,
                  color: AppColors.success,
                  unlocked: quizBadges.contains('plays_10'),
                ),
                Achievement(
                  title: 'Quiz Level ${_levelFromXp(_quizTotalXp)}',
                  description: '${_quizTotalXp} XP earned',
                  icon: Icons.auto_graph_rounded,
                  color: AppColors.secondary,
                  unlocked: _quizTotalXp > 0,
                ),
              ];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Achievements',
                        style: AppTypography.subtitle2,
                      ),
                      const Expanded(child: SizedBox()),
                      Text(
                        '${achievements.where((a) => a.unlocked).length}/${achievements.length}',
                        style: AppTypography.caption.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (token != null && token.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Unlock achievements from projects and Quiz',
                      style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                    ),
                    itemCount: achievements.length,
                    itemBuilder: (context, index) {
                      return _buildAchievementCard(context, achievements[index]);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(BuildContext context, Achievement achievement) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: achievement.unlocked 
            ? achievement.color.withOpacity(0.1)
            : cs.surfaceVariant,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        border: Border.all(
          color: achievement.unlocked 
              ? achievement.color.withOpacity(0.3)
              : cs.outlineVariant.withOpacity(0.6),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            achievement.icon,
            size: 32,
            color: achievement.unlocked 
                ? achievement.color
                : cs.onSurfaceVariant.withOpacity(0.55),
          ),
          
          const SizedBox(height: AppSpacing.sm),
          
          Text(
            achievement.title,
            style: AppTypography.caption.copyWith(
              color: achievement.unlocked 
                  ? cs.onSurface
                  : cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final token = context.read<AuthProvider>().token;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: AppTypography.subtitle2,
          ),
          
          const SizedBox(height: AppSpacing.lg),

          FutureBuilder<Map<String, dynamic>>(
            future: (token == null || token.isEmpty) ? null : ProjectsService.listProjects(token: token),
            builder: (context, snapshot) {
              final activities = <Activity>[];

              if (_quizTotalPlays > 0) {
                activities.add(
                  Activity(
                    title: 'Played Quiz',
                    description: 'Total plays: $_quizTotalPlays • Best score: $_quizBestScore',
                    timestamp: 'Now',
                    icon: Icons.quiz_rounded,
                    color: AppColors.secondary,
                  ),
                );
              }

              final res = snapshot.data;
              final data = (res != null && res['success'] == true) ? res['data'] : null;
              final list = (data is Map && data['projects'] is List)
                  ? List<Map<String, dynamic>>.from(
                      (data['projects'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
                    )
                  : (data is List)
                      ? List<Map<String, dynamic>>.from(
                          data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
                        )
                      : <Map<String, dynamic>>[];

              list.sort((a, b) {
                final ad = a['updatedAt']?.toString() ?? a['createdAt']?.toString() ?? '';
                final bd = b['updatedAt']?.toString() ?? b['createdAt']?.toString() ?? '';
                return bd.compareTo(ad);
              });

              for (final p in list.take(6)) {
                final name = p['name']?.toString().trim();
                if (name == null || name.isEmpty) continue;
                final status = p['status']?.toString().trim().toLowerCase() ?? '';
                final when = p['updatedAt']?.toString() ?? p['createdAt']?.toString();
                final ts = when != null ? _formatRelative(when) : 'Recently';
                final isBuilding = status == 'queued' || status == 'running' || status == 'building';

                activities.add(
                  Activity(
                    title: name,
                    description: isBuilding ? 'Build in progress' : (status.isNotEmpty ? status : 'Updated'),
                    timestamp: ts,
                    icon: isBuilding ? Icons.build_rounded : Icons.videogame_asset_rounded,
                    color: isBuilding ? AppColors.success : AppColors.primary,
                  ),
                );
              }

              if (activities.isEmpty) {
                return Text(
                  'No activity yet',
                  style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                );
              }

              return Column(
                children: [
                  ...activities.map((activity) => _buildActivityItem(context, activity)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatRelative(String raw) {
    try {
      final d = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inMinutes < 2) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      if (diff.inDays < 30) return '${diff.inDays} days ago';
      return _formatDate(raw);
    } catch (_) {
      return 'Recently';
    }
  }

  Widget _buildActivityItem(BuildContext context, Activity activity) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: activity.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              activity.icon,
              size: 20,
              color: activity.color,
            ),
          ),
          
          const SizedBox(width: AppSpacing.lg),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: AppTypography.body2,
                ),
                
                const SizedBox(height: AppSpacing.xs),
                
                Text(
                  activity.description,
                  style: AppTypography.caption.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          Text(
            activity.timestamp,
            style: AppTypography.caption.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutSection(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.logout,
                    color: AppColors.error,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Sign Out',
                    style: AppTypography.subtitle2.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppSpacing.md),
              
              Text(
                'Sign out of your account and return to the login screen.',
                style: AppTypography.body2.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Sign Out',
                  onPressed: () async {
                    // Show confirmation dialog
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: cs.surface,
                        title: Text(
                          'Sign Out',
                          style: AppTypography.subtitle1,
                        ),
                        content: Text(
                          'Are you sure you want to sign out?',
                          style: AppTypography.body2,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(
                              'Cancel',
                              style: AppTypography.button.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text(
                              'Sign Out',
                              style: AppTypography.button.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirmed == true) {
                      await authProvider.logout(context: context);
                      if (context.mounted) {
                        context.go('/signin');
                      }
                    }
                  },
                  type: ButtonType.danger,
                  isLoading: authProvider.isLoading,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class Achievement {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool unlocked;

  Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.unlocked,
  });
}

class Activity {
  final String title;
  final String description;
  final String timestamp;
  final IconData icon;
  final Color color;

  Activity({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.color,
  });
}
