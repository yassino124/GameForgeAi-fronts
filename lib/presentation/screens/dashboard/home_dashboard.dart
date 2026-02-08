import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/projects_service.dart';
import '../../../core/themes/app_theme.dart';
import '../../widgets/widgets.dart';
import '../marketplace/marketplace.dart';
import '../profile/profile.dart';
import '../notifications/notifications.dart';

class HomeDashboard extends StatefulWidget {
  final int initialIndex;

  const HomeDashboard({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> with SingleTickerProviderStateMixin {
  late int _selectedIndex;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final AnimationController _drawerAnim;

  Future<List<dynamic>>? _projectsFuture;
  String? _projectsToken;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    _drawerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token != null && token.isNotEmpty && token != _projectsToken) {
      _projectsToken = token;
      _projectsFuture = ProjectsService.listProjects(token: token).then((res) {
        final data = res['data'];
        return data is List ? data : <dynamic>[];
      });
    }
  }

  @override
  void dispose() {
    _drawerAnim.dispose();
    super.dispose();
  }

  Widget _drawerEntry({required int index, required Widget child}) {
    final start = (0.08 * index).clamp(0.0, 0.6);
    final curve = CurvedAnimation(
      parent: _drawerAnim,
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) {
        final v = curve.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset((1 - v) * -14, (1 - v) * 10),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final cs = Theme.of(context).colorScheme;
        final user = authProvider.user;
        final username = user?['username']?.toString() ?? 'User';
        
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          drawer: _buildWowDrawer(context, authProvider),
          appBar: _buildCustomAppBar(),
          body: _buildBody(context, username),
          floatingActionButton: _selectedIndex == 0
            ? FloatingActionButton(
                onPressed: () {
                  context.go('/create-project');
                },
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                child: const Icon(Icons.add),
              )
            : null,
          bottomNavigationBar: _buildBottomNavigationBar(),
        );
      },
    );
  }

  Widget _buildWowDrawer(BuildContext context, AuthProvider authProvider) {
    final cs = Theme.of(context).colorScheme;
    final user = authProvider.user;
    final username = user?['username']?.toString() ?? 'User';
    final fullName = user?['fullName']?.toString().trim() ?? '';
    final avatar = user?['avatar']?.toString();
    final email = user?['email']?.toString() ?? '';

    Widget item({
      required IconData icon,
      required String text,
      required VoidCallback onTap,
      bool danger = false,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: danger
                        ? LinearGradient(
                            colors: [
                              cs.error.withOpacity(0.22),
                              cs.error.withOpacity(0.08),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              cs.primary.withOpacity(0.18),
                              cs.secondary.withOpacity(0.10),
                            ],
                          ),
                    border: Border.all(
                      color: (danger ? cs.error : cs.primary).withOpacity(0.22),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: danger ? cs.error : cs.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: AppTypography.body1.copyWith(
                      color: danger ? cs.error : cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Drawer(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.surface.withOpacity(0.78),
                      cs.surface.withOpacity(0.62),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.20),
                      blurRadius: 34,
                      offset: const Offset(0, 22),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _drawerEntry(
                      index: 0,
                      child: Row(
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.94, end: 1.0),
                            duration: const Duration(milliseconds: 520),
                            curve: Curves.easeOutBack,
                            builder: (context, t, child) {
                              return Transform.scale(scale: t, child: child);
                            },
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.primaryGradient,
                                boxShadow: AppShadows.boxShadowSmall,
                              ),
                              child: ClipOval(
                                child: (avatar != null && avatar.isNotEmpty)
                                    ? Image.network(
                                        avatar,
                                        fit: BoxFit.cover,
                                      )
                                    : Center(
                                        child: Text(
                                          username.isNotEmpty ? username[0].toUpperCase() : 'U',
                                          style: AppTypography.subtitle2.copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName.isNotEmpty ? fullName : username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.subtitle2.copyWith(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email.isNotEmpty ? email : '@$username',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _drawerEntry(
                      index: 1,
                      child: Divider(color: cs.outlineVariant.withOpacity(0.55), height: 1),
                    ),
                    const SizedBox(height: 10),
                    _drawerEntry(
                      index: 2,
                      child: item(
                        icon: Icons.person_outline,
                        text: 'Profile',
                        onTap: () {
                          setState(() {
                            _selectedIndex = 3;
                          });
                        },
                      ),
                    ),
                    _drawerEntry(
                      index: 3,
                      child: item(
                        icon: Icons.workspace_premium_outlined,
                        text: 'Subscription',
                        onTap: () {
                          context.push('/subscription');
                        },
                      ),
                    ),
                    _drawerEntry(
                      index: 4,
                      child: item(
                        icon: Icons.notifications_outlined,
                        text: 'Notifications',
                        onTap: () {
                          context.go('/notifications');
                        },
                      ),
                    ),
                    _drawerEntry(
                      index: 5,
                      child: item(
                        icon: Icons.settings_outlined,
                        text: 'Settings',
                        onTap: () {
                          context.push('/settings');
                        },
                      ),
                    ),
                    if (authProvider.isAdmin || authProvider.isDevl) ...[
                      _drawerEntry(
                        index: 6,
                        child: item(
                          icon: Icons.extension_outlined,
                          text: 'Unity Assets',
                          onTap: () {
                            context.push('/assets');
                          },
                        ),
                      ),
                      _drawerEntry(
                        index: 7,
                        child: item(
                          icon: Icons.upload_file,
                          text: 'Upload Template',
                          onTap: () {
                            context.push('/templates/upload');
                          },
                        ),
                      ),
                    ],
                    const Spacer(),
                    _drawerEntry(
                      index: 8,
                      child: Divider(color: cs.outlineVariant.withOpacity(0.55), height: 1),
                    ),
                    const SizedBox(height: 10),
                    _drawerEntry(
                      index: 9,
                      child: item(
                        icon: Icons.logout_rounded,
                        text: 'Logout',
                        danger: true,
                        onTap: () {
                          authProvider.logout(context: context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, String username) {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        _buildHomeContent(username),
        _buildRecentProjects(),
        _buildTemplatesContent(),
        _buildProfileContent(),
      ],
    );
  }

  PreferredSizeWidget _buildCustomAppBar() {
    final cs = Theme.of(context).colorScheme;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + AppSpacing.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                // Menu button
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    return Builder(
                      builder: (ctx) {
                        return IconButton(
                          tooltip: 'Menu',
                          onPressed: () {
                            _drawerAnim.forward(from: 0);
                            _scaffoldKey.currentState?.openDrawer();
                          },
                          icon: Icon(
                            Icons.menu,
                            color: cs.onSurface,
                          ),
                        );
                      },
                    );
                  },
                ),
                
                const Expanded(
                  child: SizedBox(),
                ),
                
                // Logo
                AnimatedContainer(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.10),
                    borderRadius: AppBorderRadius.allSmall,
                  ),
                  child: Text(
                    'GameForge AI',
                    style: AppTypography.subtitle2.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                
                const Expanded(
                  child: SizedBox(),
                ),
                
                // Notification bell
                Stack(
                  children: [
                    IconButton(
                      onPressed: () {
                        context.go('/notifications');
                      },
                      icon: Icon(
                        Icons.notifications_outlined,
                        color: cs.onSurface,
                      ),
                    ),
                    // Notification badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),

                IconButton(
                  onPressed: () {
                    context.push('/settings');
                  },
                  icon: Icon(
                    Icons.settings,
                    color: cs.onSurface,
                  ),
                ),
                
                const SizedBox(width: AppSpacing.sm),
                
                // User avatar
                Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    final user = authProvider.user;
                    final username = user?['username']?.toString() ?? '';
                    final avatar = user?['avatar']?.toString();

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIndex = 3;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                          boxShadow: AppShadows.boxShadowSmall,
                        ),
                        child: ClipOval(
                          child: (avatar != null && avatar.isNotEmpty)
                              ? Image.network(
                                  avatar,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    if (username.isNotEmpty) {
                                      return Center(
                                        child: Text(
                                          username[0].toUpperCase(),
                                          style: AppTypography.subtitle2.copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      );
                                    }
                                    return const Center(
                                      child: Icon(
                                        Icons.person,
                                        color: AppColors.textPrimary,
                                        size: 20,
                                      ),
                                    );
                                  },
                                )
                              : (username.isNotEmpty)
                                  ? Center(
                                      child: Text(
                                        username[0].toUpperCase(),
                                        style: AppTypography.subtitle2.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(
                                        Icons.person,
                                        color: AppColors.textPrimary,
                                        size: 20,
                                      ),
                                    ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent(String username) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: AppSpacing.paddingHorizontalLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          
          // Welcome message
          Text(
            'Welcome back, $username! 👋',
            style: AppTypography.h3,
          ),
          
          const SizedBox(height: AppSpacing.sm),
          
          Text(
            'Ready to create something amazing today?',
            style: AppTypography.body1.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          
          const SizedBox(height: AppSpacing.xxxl),
          
          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _buildStatsCard(
                  title: 'Projects',
                  value: '12',
                  icon: Icons.videogame_asset,
                  color: AppColors.primary,
                  percentage: 25.0,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _buildStatsCard(
                  title: 'Templates',
                  value: '48',
                  icon: Icons.dashboard,
                  color: AppColors.secondary,
                  percentage: 15.0,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _buildStatsCard(
                  title: 'Downloads',
                  value: '3.2K',
                  icon: Icons.download,
                  color: AppColors.success,
                  percentage: 45.0,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          Row(
            children: [
              Expanded(
                child: _buildStatsCard(
                  title: 'Builds',
                  value: '24',
                  icon: Icons.build,
                  color: AppColors.success,
                  percentage: 10.0,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _buildStatsCard(
                  title: 'Generations',
                  value: '1.2K',
                  icon: Icons.auto_awesome,
                  color: AppColors.accent,
                  percentage: 20.0,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppSpacing.xxxl),
          
          // Quick Actions
          Text(
            'Quick Actions',
            style: AppTypography.subtitle1,
          ),
          
          const SizedBox(height: AppSpacing.lg),
          // Quick Actions
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(AppBorderRadius.large),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppBorderRadius.large),
                          onTap: () {
                            context.go('/create-project');
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.20),
                                    borderRadius: BorderRadius.circular(AppBorderRadius.small),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Create\nNew Game',
                                  style: AppTypography.button.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(AppBorderRadius.large),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppBorderRadius.large),
                          onTap: () {
                            setState(() {
                              _selectedIndex = 2;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(AppBorderRadius.small),
                                  ),
                                  child: const Icon(
                                    Icons.grid_view,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    'Browse Templates',
                                    style: AppTypography.button.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppSpacing.lg),
              
              // Secondary actions
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(AppBorderRadius.large),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppBorderRadius.large),
                          onTap: () {
                            context.go('/marketplace');
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.store,
                                  color: cs.onSurfaceVariant,
                                  size: 18,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Marketplace',
                                  style: AppTypography.buttonSmall.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(AppBorderRadius.large),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppBorderRadius.large),
                          onTap: () {
                            context.go('/build-configuration');
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.build,
                                  color: cs.onSurfaceVariant,
                                  size: 18,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Build Game',
                                  style: AppTypography.buttonSmall.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: AppSpacing.xxxl),
          
          // Recent Projects
          Row(
            children: [
              Text(
                'Recent Projects',
                style: AppTypography.subtitle1,
              ),
              const Expanded(
                child: SizedBox(),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 1;
                  });
                },
                child: Text(
                  'See all',
                  style: AppTypography.body2.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Recent projects list
          _buildRecentProjectsList(),
          
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildRecentProjectsList() {
    final cs = Theme.of(context).colorScheme;
    final recentProjects = [
      {
        'title': 'Space Adventure',
        'description': 'A thrilling space exploration game',
        'status': 'completed',
        'lastModified': DateTime.now().subtract(const Duration(hours: 2)),
        'progress': 1.0,
        'image': '🚀',
        'downloads': 1234,
        'rating': 4.8,
      },
      {
        'title': 'Puzzle Master',
        'description': 'Challenging puzzle game with AI levels',
        'status': 'in-progress',
        'lastModified': DateTime.now().subtract(const Duration(hours: 5)),
        'progress': 0.75,
        'image': '🧩',
        'downloads': 856,
        'rating': 4.6,
      },
      {
        'title': 'Racing Thunder',
        'description': 'High-speed racing game with custom tracks',
        'status': 'in-progress',
        'lastModified': DateTime.now().subtract(const Duration(hours: 8)),
        'progress': 0.45,
        'image': '🏎️',
        'downloads': 2341,
        'rating': 4.9,
      },
    ];
    
    return Column(
      children: recentProjects.map((project) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.surface,
                cs.surfaceVariant,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            border: Border.all(
              color: cs.outlineVariant.withOpacity(0.6),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              onTap: () {
                context.go('/project-detail');
              },
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    // Game icon/image
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      ),
                      child: Center(
                        child: Text(
                          project['image'] as String,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: AppSpacing.lg),
                    
                    // Project info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  project['title'] as String,
                                  style: AppTypography.subtitle1.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: project['status'] == 'completed'
                                      ? AppColors.success.withOpacity(0.2)
                                      : AppColors.warning.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(AppBorderRadius.small),
                                ),
                                child: Text(
                                  project['status'] == 'completed' ? '✓' : '⏳',
                                  style: AppTypography.caption.copyWith(
                                    color: project['status'] == 'completed'
                                        ? AppColors.success
                                        : AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: AppSpacing.xs),
                          
                          Text(
                            project['description'] as String,
                            style: AppTypography.body2.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          const SizedBox(height: AppSpacing.sm),
                          
                          // Progress bar
                          if (project['status'] != 'completed') ...[
                            Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: cs.surfaceVariant,
                                borderRadius: BorderRadius.circular(AppBorderRadius.small),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: project['progress'] as double,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(AppBorderRadius.small),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          
                          // Stats row
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.download,
                                      size: 16,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      '${project['downloads']}',
                                      style: AppTypography.caption.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      size: 16,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      '${project['rating']}',
                                      style: AppTypography.caption.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _formatDate(project['lastModified'] as DateTime),
                                  style: AppTypography.caption.copyWith(
                                    color: cs.onSurfaceVariant.withOpacity(0.8),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Widget _buildStatsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double percentage,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppBorderRadius.small),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: percentage > 0 ? color.withOpacity(0.2) : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppBorderRadius.small),
                  ),
                  child: Text(
                    '+${percentage.toStringAsFixed(1)}%',
                    style: AppTypography.caption.copyWith(
                      color: percentage > 0 ? color : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          Text(
            value,
            style: AppTypography.h3.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          
          const SizedBox(height: AppSpacing.xs),
          
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          
          const SizedBox(height: AppSpacing.sm),
          
          // Progress bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppBorderRadius.small),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppBorderRadius.small),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentProjects() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: AppSpacing.paddingLarge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'All Projects',
                style: AppTypography.h2,
              ),
              const Expanded(child: SizedBox()),
              FutureBuilder<List<dynamic>>(
                future: _projectsFuture,
                builder: (context, snapshot) {
                  final count = snapshot.data?.length;
                  final text = count == null ? '—' : '$count Projects';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                    ),
                    child: Text(
                      text,
                      style: AppTypography.caption.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: AppSpacing.xxl),

          FutureBuilder<List<dynamic>>(
            future: _projectsFuture,
            builder: (context, snapshot) {
              if (_projectsFuture == null) {
                return Center(
                  child: Text(
                    'Sign in to view your projects',
                    style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = snapshot.data ?? <dynamic>[];
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    'No projects yet',
                    style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                  ),
                );
              }

              DateTime parseDate(dynamic v) {
                if (v == null) return DateTime.now();
                final s = v.toString();
                return DateTime.tryParse(s) ?? DateTime.now();
              }

              String mapStatus(String? status) {
                switch ((status ?? '').toLowerCase()) {
                  case 'ready':
                    return 'completed';
                  case 'failed':
                    return 'failed';
                  case 'running':
                  case 'queued':
                    return 'in_progress';
                  default:
                    return status ?? 'unknown';
                }
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.lg,
                  mainAxisSpacing: AppSpacing.lg,
                  childAspectRatio: 0.82,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final p = items[index];
                  final pm = p is Map ? Map<String, dynamic>.from(p as Map) : <String, dynamic>{};
                  final title = pm['name']?.toString() ?? 'Untitled';
                  final desc = pm['description']?.toString();
                  final status = mapStatus(pm['status']?.toString());
                  final lastModified = parseDate(pm['updatedAt'] ?? pm['createdAt']);
                  final thumbnailUrl = pm['previewImageUrl']?.toString();

                  return ProjectCard(
                    title: title,
                    description: desc,
                    thumbnailUrl: thumbnailUrl,
                    status: status,
                    lastModified: lastModified,
                    progress: status == 'in_progress' ? 0.5 : 1.0,
                    onTap: () {
                      final id = pm['_id']?.toString() ?? pm['id']?.toString();
                      context.go('/project-detail', extra: {'projectId': id, 'project': pm});
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesContent() {
    return const TemplateMarketplaceScreen();
  }

  Widget _buildProfileContent() {
    return const UserProfileScreen(showAppBar: false);
  }

  Widget _buildBottomNavigationBar() {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurfaceVariant,
        selectedLabelStyle: AppTypography.caption,
        unselectedLabelStyle: AppTypography.caption,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view),
            label: 'Templates',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _showProjectOptions(BuildContext context, String projectName) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.large),
        ),
      ),
      builder: (context) => Container(
        padding: AppSpacing.paddingLarge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant.withOpacity(0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            // Project name
            Text(
              projectName,
              style: AppTypography.subtitle1,
            ),
            
            const SizedBox(height: AppSpacing.xxl),
            
            // Options
            _buildOptionTile(
              icon: Icons.edit,
              title: 'Edit Project',
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Navigate to edit
              },
            ),
            
            _buildOptionTile(
              icon: Icons.share,
              title: 'Share Project',
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Share project
              },
            ),
            
            _buildOptionTile(
              icon: Icons.copy_rounded,
              title: 'Duplicate Project',
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Duplicate project
              },
            ),
            
            _buildOptionTile(
              icon: Icons.delete,
              title: 'Delete Project',
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Delete project
              },
              isDestructive: true,
            ),
            
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? cs.error : cs.onSurface,
      ),
      title: Text(
        title,
        style: AppTypography.body2.copyWith(
          color: isDestructive ? cs.error : cs.onSurface,
        ),
      ),
      onTap: onTap,
    );
  }
}
