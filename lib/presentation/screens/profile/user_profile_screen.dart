import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/billing_service.dart';
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

  late final AnimationController _appearController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _appearController, curve: Curves.easeOutCubic);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _appearController, curve: Curves.easeOutCubic),
    );

    _appearController.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        void _noop = _subscriptionRefreshTick;
        _noop;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: widget.showAppBar
              ? AppBar(
                  backgroundColor: cs.surface,
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
          
          body: SingleChildScrollView(
            padding: AppSpacing.paddingLarge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),
                
                // Profile header
                _buildProfileHeader(context, user, authProvider),
                
                const SizedBox(height: AppSpacing.xxxl),
                
                // User stats
                _buildUserStats(context),
                
                const SizedBox(height: AppSpacing.xxxl),
                
                // Subscription status
                _buildSubscriptionCard(context, user),
                
                const SizedBox(height: AppSpacing.xxxl),
                
                // Recent achievements
                _buildAchievements(context),
                
                const SizedBox(height: AppSpacing.xxxl),
                
                // Recent activity
                _buildRecentActivity(context),
                
                const SizedBox(height: AppSpacing.xxxl),
                
                // Logout button
                _buildLogoutSection(context),
                
                const SizedBox(height: AppSpacing.xxl),
              ],
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
    final username = user?['username']?.toString() ?? 'User';
    final fullName = user?['fullName']?.toString() ?? '';
    final bio = user?['bio']?.toString() ?? '';
    final location = user?['location']?.toString() ?? '';
    final website = user?['website']?.toString() ?? '';
    final email = user?['email']?.toString() ?? 'user@example.com';
    final avatar = user?['avatar']?.toString();
    final createdAt = user?['createdAt']?.toString();
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.primary,
                backgroundImage: avatar != null && avatar.isNotEmpty 
                    ? NetworkImage(avatar) 
                    : null,
                child: avatar == null || avatar.isEmpty
                    ? Text(
                        username.isNotEmpty 
                            ? username[0].toUpperCase()
                            : 'U',
                        style: AppTypography.h2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: authProvider.isLoading
                      ? null
                      : () => _changeAvatar(context, authProvider),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 2),
                    ),
                    child: authProvider.isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.edit,
                            size: 16,
                            color: cs.onPrimary,
                          ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // User name
          Text(
            (fullName.trim().isNotEmpty ? fullName.trim() : username),
            style: AppTypography.h3,
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
          
          // User email
          Text(
            email,
            style: AppTypography.body1.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Member since
          Text(
            createdAt != null 
                ? 'Member since ${_formatDate(createdAt)}'
                : 'Member since recently',
            style: AppTypography.caption.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),

          if (bio.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              bio.trim(),
              style: AppTypography.body2.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
          ],

          if (location.trim().isNotEmpty || website.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            if (location.trim().isNotEmpty)
              Text(
                location.trim(),
                style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            if (website.trim().isNotEmpty) ...[
              if (location.trim().isNotEmpty) const SizedBox(height: AppSpacing.xs),
              Text(
                website.trim(),
                style: AppTypography.caption.copyWith(color: cs.primary),
                textAlign: TextAlign.center,
              ),
            ],
          ],
          
          const SizedBox(height: AppSpacing.lg),
          
          // Edit profile button
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              text: 'Edit Profile',
              onPressed: () {
                context.push('/edit-profile');
              },
              type: ButtonType.secondary,
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
          
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  'Projects',
                  '12',
                  Icons.videogame_asset,
                  AppColors.primary,
                ),
              ),
              
              Expanded(
                child: _buildStatItem(
                  context,
                  'Generations',
                  '48',
                  Icons.auto_awesome,
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
                  '24',
                  Icons.build,
                  AppColors.success,
                ),
              ),
              
              Expanded(
                child: _buildStatItem(
                  context,
                  'Downloads',
                  '1.2K',
                  Icons.download,
                  AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
    final achievements = [
      Achievement(
        title: 'First Game',
        description: 'Created your first game',
        icon: Icons.star,
        color: AppColors.warning,
        unlocked: true,
      ),
      Achievement(
        title: 'Power User',
        description: 'Generated 10+ games',
        icon: Icons.flash_on,
        color: AppColors.primary,
        unlocked: true,
      ),
      Achievement(
        title: 'Creator',
        description: 'Published 5+ games',
        icon: Icons.publish,
        color: AppColors.success,
        unlocked: false,
      ),
      Achievement(
        title: 'Popular',
        description: '1000+ total downloads',
        icon: Icons.trending_up,
        color: AppColors.accent,
        unlocked: false,
      ),
    ];
    
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
          Row(
            children: [
              Text(
                'Achievements',
                style: AppTypography.subtitle2,
              ),
              
              const Expanded(
                child: SizedBox(),
              ),
              
              Text(
                '${achievements.where((a) => a.unlocked).length}/${achievements.length}',
                style: AppTypography.caption.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          
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
    final activities = [
      Activity(
        title: 'Generated Space Adventure',
        description: 'Action game with AI assets',
        timestamp: '2 hours ago',
        icon: Icons.auto_awesome,
        color: AppColors.primary,
      ),
      Activity(
        title: 'Built iOS version',
        description: 'Successfully deployed to App Store',
        timestamp: '1 day ago',
        icon: Icons.build,
        color: AppColors.success,
      ),
      Activity(
        title: 'Shared Puzzle Master',
        description: 'Game shared with 5 friends',
        timestamp: '3 days ago',
        icon: Icons.share,
        color: AppColors.accent,
      ),
    ];
    
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
          
          ...activities.map((activity) => _buildActivityItem(context, activity)),
        ],
      ),
    );
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
