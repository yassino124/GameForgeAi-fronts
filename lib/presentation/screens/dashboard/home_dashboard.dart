import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/build_monitor_provider.dart';
import '../../../core/services/local_notifications_service.dart';
import '../../../core/services/notifications_service.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/projects_service.dart';
import '../../../core/themes/app_theme.dart';
import '../../widgets/widgets.dart';
import '../marketplace/marketplace.dart';
import '../profile/profile.dart';
import '../notifications/notifications.dart';

class GradientTranslation extends GradientTransform {
  final double dx;
  const GradientTranslation(this.dx);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, 0.0, 0.0);
  }
}

class HomeDashboard extends StatefulWidget {
  final int initialIndex;

  const HomeDashboard({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> with TickerProviderStateMixin {
  late int _selectedIndex;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final AnimationController _drawerAnim;
  late final AnimationController _homeIntroAnim;
  late final AnimationController _wowAnim;

  Future<List<dynamic>>? _projectsFuture;
  String? _projectsToken;

  String? _trendsToken;
  Timer? _trendsTimer;

  List<Map<String, dynamic>> _trendsItems = const [];
  bool _trendsLoading = false;
  String? _trendsError;
  Timer? _trendsAutoTimer;
  int _trendsIndex = 0;
  final PageController _trendsPageController = PageController(viewportFraction: 0.92);

  int _unreadNotifCount = 0;
  bool _unreadNotifLoading = false;
  Timer? _notifTimer;

  static const List<String> _trendFallbackImages = [
    'https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1556438064-2d7646166914?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1535223289827-42f1e9919769?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1200&q=80',
  ];

  String _fallbackTrendImageUrl(int index) {
    if (_trendFallbackImages.isEmpty) return '';
    final i = index.abs() % _trendFallbackImages.length;
    return _trendFallbackImages[i];
  }

  String _tryGetHost(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return '';
    try {
      final u = Uri.parse(raw);
      final h = u.host.trim();
      if (h.isEmpty) return '';
      if (h.startsWith('www.')) return h.substring(4);
      return h;
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    _drawerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _homeIntroAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _homeIntroAnim.forward();

    _wowAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  void _advanceTrend() {
    if (_trendsItems.isEmpty) return;
    final next = (_trendsIndex + 1) % _trendsItems.length;
    _trendsIndex = next;
    try {
      _trendsPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 560),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      setState(() {});
    }
  }

  void _startTrendsAutoAdvance() {
    _trendsAutoTimer?.cancel();
    if (_trendsItems.length <= 1) return;
    _trendsAutoTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _advanceTrend();
    });
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
        if (data is Map && data['projects'] is List) {
          return (data['projects'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        if (data is List) {
          return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
        return <dynamic>[];
      });
    }

    if (token != null && token.isNotEmpty && token != _trendsToken) {
      _trendsToken = token;
      _trendsTimer?.cancel();
      _loadTrends();
      _trendsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _loadTrends();
      });
    }

    if (token != null && token.isNotEmpty) {
      _notifTimer?.cancel();
      _loadUnreadNotifications();
      _notifTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _loadUnreadNotifications();
      });
    } else {
      _notifTimer?.cancel();
      if (_unreadNotifCount != 0) {
        setState(() => _unreadNotifCount = 0);
      }
    }
  }

  @override
  void dispose() {
    _drawerAnim.dispose();
    _homeIntroAnim.dispose();
    _wowAnim.dispose();
    _trendsTimer?.cancel();
    _trendsAutoTimer?.cancel();
    _notifTimer?.cancel();
    _trendsPageController.dispose();
    super.dispose();
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  Future<void> _loadUnreadNotifications() async {
    final token = _trendsToken;
    if (token == null || token.trim().isEmpty) return;
    if (_unreadNotifLoading) return;

    _unreadNotifLoading = true;
    try {
      final local = await LocalNotificationsService.listInAppNotifications();
      final localUnread = local.where((e) => e['isRead'] != true).length;

      final res = await NotificationsService.listNotifications(token: token);
      if (!mounted) return;

      int remoteUnread = 0;
      if (res['success'] == true) {
        final data = (res['data'] is List) ? (res['data'] as List) : const [];
        remoteUnread = data.where((e) => e is Map && e['isRead'] != true).length;
      }

      final total = localUnread + remoteUnread;
      if (_unreadNotifCount != total) {
        setState(() => _unreadNotifCount = total);
      }
    } catch (_) {
      // ignore; keep last known value
    } finally {
      _unreadNotifLoading = false;
    }
  }

  Widget _animatedBlobs(ColorScheme cs) {
    return IgnorePointer(
      ignoring: true,
      child: AnimatedBuilder(
        animation: _wowAnim,
        builder: (context, _) {
          final t = _wowAnim.value * math.pi * 2;
          final dx1 = math.sin(t) * 10.0;
          final dy1 = math.cos(t * 0.7) * 8.0;
          final dx2 = math.cos(t * 0.9) * 12.0;
          final dy2 = math.sin(t * 0.6) * 10.0;

          return Stack(
            children: [
              Positioned(
                left: -30 + dx1,
                top: -26 + dy1,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        cs.primary.withOpacity(0.26),
                        cs.primary.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -44 + dx2,
                bottom: -44 + dy2,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        cs.secondary.withOpacity(0.22),
                        cs.secondary.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _shimmerBox({
    double? width,
    required double height,
    double radius = 16,
  }) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceContainerHighest.withOpacity(0.75);
    final highlight = cs.onSurface.withOpacity(0.06);

    return AnimatedBuilder(
      animation: _wowAnim,
      builder: (context, _) {
        final v = _wowAnim.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: ShaderMask(
            shaderCallback: (rect) {
              final dx = (rect.width * 2) * (v - 0.5);
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  base,
                  highlight,
                  base,
                ],
                stops: const [0.0, 0.5, 1.0],
                transform: GradientTranslation(dx),
              ).createShader(rect);
            },
            blendMode: BlendMode.srcATop,
            child: Container(
              width: width,
              height: height,
              color: base,
            ),
          ),
        );
      },
    );
  }

  Widget _introEntry({required int index, required Widget child}) {
    final start = (0.06 * index).clamp(0.0, 0.70);
    final curve = CurvedAnimation(
      parent: _homeIntroAnim,
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: curve,
      child: child,
      builder: (context, c) {
        final v = curve.value;
        final t = (1 - v);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 16 * t),
            child: Transform.scale(
              scale: 0.985 + (v * 0.015),
              child: c,
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadTrends() async {
    final token = _trendsToken;
    if (token == null || token.isEmpty) return;
    if (_trendsLoading) return;

    setState(() {
      _trendsLoading = true;
      _trendsError = null;
    });

    try {
      final res = await AiService.listTrends(token: token);
      if (!mounted) return;
      if (res['success'] == true) {
        final data = res['data'];
        final items = (data is Map) ? data['items'] : null;
        final list = items is List ? items : const [];
        setState(() {
          _trendsItems = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false);
          if (_trendsItems.isEmpty) {
            _trendsIndex = 0;
          } else {
            _trendsIndex = _trendsIndex.clamp(0, _trendsItems.length - 1);
          }
          _trendsLoading = false;
        });
        _startTrendsAutoAdvance();
        return;
      }

      setState(() {
        _trendsError = res['message']?.toString();
        _trendsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _trendsError = e.toString();
        _trendsLoading = false;
      });
    }
  }

  Future<void> _openTrendUrl(String url) async {
    final u = Uri.tryParse(url);
    if (u == null) return;
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {}
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
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'fab_coach',
                    onPressed: () {
                      context.push('/ai-coach');
                    },
                    backgroundColor: cs.surface,
                    foregroundColor: cs.onSurface,
                    child: const Icon(Icons.mic_rounded),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: 'fab_create_project',
                    onPressed: () {
                      context.go('/create-project');
                    },
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    child: const Icon(Icons.add),
                  ),
                ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 12),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(isDark ? 0.72 : 0.82),
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    // Menu button - Minimalist
                    IconButton(
                      onPressed: () {
                        _drawerAnim.forward(from: 0);
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      icon: Icon(Icons.menu_rounded, color: cs.onSurface),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Logo WOW with Glow
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cs.primary.withOpacity(0.12),
                            cs.secondary.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.primary.withOpacity(0.2)),
                      ),
                      child: ShaderMask(
                        shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                        child: Text(
                          'GameForge AI',
                          style: AppTypography.subtitle2.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    
                    const Spacer(),

                    IconButton(
                      onPressed: () => context.go('/settings'),
                      icon: Icon(Icons.settings_rounded, color: cs.onSurface, size: 24),
                    ),
                    
                    Consumer<BuildMonitorProvider>(
                      builder: (context, bm, _) {
                        final inProgress = bm.isMonitoring && (bm.status == 'queued' || bm.status == 'running');
                        final pid = bm.projectId;
                        final showNotifDot = !inProgress && _unreadNotifCount > 0;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              onPressed: () {
                                if (inProgress && pid != null && pid.trim().isNotEmpty) {
                                  context.go(
                                    '/build-progress',
                                    extra: {
                                      'projectId': pid,
                                    },
                                  );
                                  return;
                                }
                                context.go('/notifications');
                              },
                              icon: AnimatedBuilder(
                                animation: _wowAnim,
                                builder: (context, child) {
                                  if (!inProgress) return child!;
                                  final w = _wowAnim.value;
                                  final pulse = (math.sin(w * math.pi * 2) + 1) / 2; // 0..1
                                  final scale = 0.94 + pulse * 0.12;
                                  final glow = 0.35 + pulse * 0.35;
                                  return Transform.scale(
                                    scale: scale,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: cs.primary.withOpacity(glow),
                                            blurRadius: 12,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Icon(
                                  inProgress ? Icons.build_circle_outlined : Icons.notifications_none_rounded,
                                  color: inProgress ? cs.primary : cs.onSurface,
                                  size: 26,
                                ),
                              ),
                            ),
                            if (inProgress)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: AnimatedBuilder(
                                  animation: _wowAnim,
                                  builder: (context, child) {
                                    final w = _wowAnim.value;
                                    final pulse = (math.sin(w * math.pi * 2) + 1) / 2; // 0..1
                                    final scale = 0.96 + pulse * 0.10;
                                    final opacity = 0.72 + pulse * 0.28;
                                    return Opacity(
                                      opacity: opacity,
                                      child: Transform.scale(
                                        scale: scale,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cs.primary,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.4), blurRadius: 6)],
                                    ),
                                    child: const Text(
                                      'BUILD',
                                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            if (showNotifDot)
                              Positioned(
                                top: -1,
                                right: -1,
                                child: AnimatedBuilder(
                                  animation: _wowAnim,
                                  builder: (context, child) {
                                    final w = _wowAnim.value;
                                    final pulse = (math.sin(w * math.pi * 2) + 1) / 2; // 0..1
                                    final scale = 0.92 + pulse * 0.18;
                                    final opacity = 0.65 + pulse * 0.35;
                                    return Opacity(
                                      opacity: opacity,
                                      child: Transform.scale(
                                        scale: scale,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.redAccent.withOpacity(0.45),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                      border: Border.all(color: cs.surface, width: 1.2),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(width: 4),
                    
                    // User Profile Mini WOW
                    Consumer<AuthProvider>(
                      builder: (context, authProvider, _) {
                        final user = authProvider.user;
                        final avatar = user?['avatar']?.toString();
                        return GestureDetector(
                          onTap: () => setState(() => _selectedIndex = 3),
                          child: Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: cs.surface, width: 1.5),
                              ),
                              child: ClipOval(
                                child: SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: (avatar != null && avatar.isNotEmpty)
                                      ? Image.network(avatar, fit: BoxFit.cover)
                                      : Container(
                                          color: cs.primaryContainer,
                                          child: Icon(Icons.person_rounded, color: cs.onPrimaryContainer, size: 20),
                                        ),
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

          _introEntry(
            index: 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    child: _animatedBlobs(cs),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppBorderRadius.large),
                        border: Border.all(color: cs.primary.withOpacity(0.25)),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withOpacity(0.15),
                            blurRadius: 20,
                            spreadRadius: -5,
                          ),
                        ],
                        gradient: RadialGradient(
                          center: const Alignment(-0.8, -0.5),
                          radius: 1.5,
                          colors: [
                            cs.primary.withOpacity(0.12),
                            cs.surface.withOpacity(0.85),
                          ],
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: cs.primary.withOpacity(0.15),
                                  ),
                                ),
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: AppColors.primaryGradient,
                                    boxShadow: [
                                      BoxShadow(
                                        color: cs.primary.withOpacity(0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                                ),
                              ],
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Welcome back,',
                                    style: AppTypography.caption.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Text(
                                    username,
                                    style: AppTypography.h3.copyWith(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24,
                                      height: 1.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'READY TO CREATE',
                                      style: AppTypography.caption.copyWith(
                                        color: cs.primary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
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

          const SizedBox(height: AppSpacing.xxl),
          
          // Stats Cards
          _introEntry(
            index: 1,
            child: FutureBuilder<List<dynamic>>(
              future: _projectsFuture,
              builder: (context, snapshot) {
                final raw = snapshot.data ?? const <dynamic>[];
                final items = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

                final projectCount = items.length;
                final downloads = items.fold<int>(0, (sum, p) => sum + _toInt(p['downloadCount'] ?? p['downloadsCount'] ?? p['downloads']));
                final builds = items.fold<int>(0, (sum, p) => sum + _toInt(p['buildCount'] ?? p['buildsCount'] ?? p['builds']));
                final gens = items.fold<int>(0, (sum, p) => sum + _toInt(p['generationCount'] ?? p['generationsCount'] ?? p['generations']));

                final templateIds = <String>{};
                for (final p in items) {
                  final tid = p['templateId']?.toString() ?? p['sourceTemplateId']?.toString();
                  if (tid != null && tid.trim().isNotEmpty) templateIds.add(tid.trim());
                }
                final templatesUsed = templateIds.length;

                String fmt(int n) {
                  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
                  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
                  return n.toString();
                }

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatsCard(
                        title: 'Projects',
                        value: projectCount == 0 && _projectsFuture == null ? '—' : fmt(projectCount),
                        icon: Icons.videogame_asset,
                        color: AppColors.primary,
                        percentage: 0.0,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: _buildStatsCard(
                        title: 'Templates',
                        value: _projectsFuture == null ? '—' : fmt(templatesUsed),
                        icon: Icons.dashboard,
                        color: AppColors.secondary,
                        percentage: 0.0,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: _buildStatsCard(
                        title: 'Downloads',
                        value: _projectsFuture == null ? '—' : fmt(downloads),
                        icon: Icons.download,
                        color: AppColors.success,
                        percentage: 0.0,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          const SizedBox(height: AppSpacing.lg),

          _introEntry(
            index: 2,
            child: FutureBuilder<List<dynamic>>(
              future: _projectsFuture,
              builder: (context, snapshot) {
                final raw = snapshot.data ?? const <dynamic>[];
                final items = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
                final builds = items.fold<int>(0, (sum, p) => sum + _toInt(p['buildCount'] ?? p['buildsCount'] ?? p['builds']));
                final gens = items.fold<int>(0, (sum, p) => sum + _toInt(p['generationCount'] ?? p['generationsCount'] ?? p['generations']));

                String fmt(int n) {
                  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
                  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
                  return n.toString();
                }

                return Row(
                  children: [
                    Expanded(
                      child: _buildStatsCard(
                        title: 'Builds',
                        value: _projectsFuture == null ? '—' : fmt(builds),
                        icon: Icons.build,
                        color: AppColors.success,
                        percentage: 0.0,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: _buildStatsCard(
                        title: 'Generations',
                        value: _projectsFuture == null ? '—' : fmt(gens),
                        icon: Icons.auto_awesome,
                        color: AppColors.accent,
                        percentage: 0.0,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          const SizedBox(height: AppSpacing.xxxl),
          
          // Quick Actions
          _introEntry(
            index: 3,
            child: Text(
              'Quick Actions',
              style: AppTypography.subtitle1,
            ),
          ),
          
          const SizedBox(height: AppSpacing.lg),
          // Quick Actions
          _introEntry(
            index: 4,
            child: Column(
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
                          onHighlightChanged: (v) {
                            if (!v) return;
                            HapticFeedback.selectionClick();
                          },
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
                          onHighlightChanged: (v) {
                            if (!v) return;
                            HapticFeedback.selectionClick();
                          },
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
                          onHighlightChanged: (v) {
                            if (!v) return;
                            HapticFeedback.selectionClick();
                          },
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
                          onHighlightChanged: (v) {
                            if (!v) return;
                            HapticFeedback.selectionClick();
                          },
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

              const SizedBox(height: AppSpacing.lg),

              // Quiz action
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.tertiary.withOpacity(0.18),
                      cs.primary.withOpacity(0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    onHighlightChanged: (v) {
                      if (!v) return;
                      HapticFeedback.selectionClick();
                    },
                    onTap: () {
                      context.push('/game-quiz');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.quiz_rounded, color: Colors.white),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Game Quiz',
                                  style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Quick interactive questions • streak rewards',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.xxxl),

          // AI Games Trends
          _introEntry(
            index: 5,
            child: Row(
              children: [
                Text(
                  'AI Games Trends',
                  style: AppTypography.subtitle1,
                ),
                const Expanded(child: SizedBox()),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _trendsLoading ? null : _loadTrends,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          if (_trendsError != null && _trendsError!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _trendsError!,
              style: AppTypography.body2.copyWith(color: cs.error),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          if (_trendsItems.isEmpty && _trendsLoading) ...[
            _introEntry(
              index: 6,
              child: Container(
                height: 200,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(height: 16, radius: 10, width: 140),
                    const SizedBox(height: 10),
                    _shimmerBox(height: 12, radius: 10, width: 220),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: _shimmerBox(height: 110, radius: AppBorderRadius.large.toDouble())),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_trendsItems.isNotEmpty) ...[
            _introEntry(
              index: 6,
              child: SizedBox(
                height: 206,
                child: PageView.builder(
                  controller: _trendsPageController,
                  onPageChanged: (i) {
                    setState(() => _trendsIndex = i);
                  },
                  itemCount: _trendsItems.length,
                  itemBuilder: (context, i) {
                    final it = _trendsItems[i];
                    final title = it['title']?.toString() ?? 'Article';
                    final url = it['url']?.toString() ?? '';
                    final source = it['source']?.toString() ?? '';
                    final publishedAt = it['publishedAt']?.toString();
                    final imageUrl = it['imageUrl']?.toString();
                    final bgUrl = (imageUrl != null && imageUrl.trim().isNotEmpty)
                        ? imageUrl.trim()
                        : _fallbackTrendImageUrl(i);
                    final dateText = (publishedAt != null && publishedAt.trim().isNotEmpty)
                        ? publishedAt.split('T').first
                        : '';
                    final host = _tryGetHost(url);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppBorderRadius.large),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.22),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppBorderRadius.large),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: url.isEmpty ? null : () => _openTrendUrl(url),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: AnimatedBuilder(
                                      animation: _trendsPageController,
                                      builder: (context, _) {
                                        double page = _trendsIndex.toDouble();
                                        try {
                                          if (_trendsPageController.hasClients) {
                                            page = (_trendsPageController.page ?? _trendsIndex).toDouble();
                                          }
                                        } catch (_) {}
                                        final delta = (page - i).clamp(-1.0, 1.0);
                                        return Transform.translate(
                                          offset: Offset(delta * -18.0, 0),
                                          child: Image.network(
                                            bgUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) {
                                              final fallback = _fallbackTrendImageUrl(i + 1);
                                              return Image.network(
                                                fallback,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) {
                                                  return Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          cs.primary.withOpacity(0.26),
                                                          cs.secondary.withOpacity(0.14),
                                                          cs.surface,
                                                        ],
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.black.withOpacity(0.68),
                                            Colors.black.withOpacity(0.24),
                                            Colors.black.withOpacity(0.06),
                                          ],
                                          begin: Alignment.bottomLeft,
                                          end: Alignment.topRight,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          colors: [
                                            cs.primary.withOpacity(0.26),
                                            Colors.transparent,
                                          ],
                                          radius: 1.15,
                                          center: const Alignment(-0.7, -0.9),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(AppBorderRadius.large),
                                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(AppSpacing.lg),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.16),
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                                            ),
                                            const SizedBox(width: AppSpacing.sm),
                                            Expanded(
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Wrap(
                                                  spacing: AppSpacing.sm,
                                                  runSpacing: AppSpacing.sm,
                                                  children: [
                                                    if (source.isNotEmpty)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white.withOpacity(0.14),
                                                          borderRadius: BorderRadius.circular(99),
                                                          border: Border.all(color: Colors.white.withOpacity(0.14)),
                                                        ),
                                                        child: Text(
                                                          source,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: AppTypography.caption.copyWith(
                                                            color: Colors.white.withOpacity(0.90),
                                                            fontWeight: FontWeight.w800,
                                                          ),
                                                        ),
                                                      ),
                                                    if (host.isNotEmpty)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: Colors.black.withOpacity(0.22),
                                                          borderRadius: BorderRadius.circular(99),
                                                          border: Border.all(color: Colors.white.withOpacity(0.10)),
                                                        ),
                                                        child: Text(
                                                          host,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: AppTypography.caption.copyWith(
                                                            color: Colors.white.withOpacity(0.90),
                                                            fontWeight: FontWeight.w800,
                                                          ),
                                                        ),
                                                      ),
                                                    if (dateText.isNotEmpty)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: Colors.black.withOpacity(0.22),
                                                          borderRadius: BorderRadius.circular(99),
                                                          border: Border.all(color: Colors.white.withOpacity(0.10)),
                                                        ),
                                                        child: Text(
                                                          dateText,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: AppTypography.caption.copyWith(
                                                            color: Colors.white.withOpacity(0.90),
                                                            fontWeight: FontWeight.w800,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.92)),
                                          ],
                                        ),
                                        const Spacer(),
                                        Text(
                                          title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.subtitle1.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                url.isNotEmpty ? url : 'Tap to open',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.caption.copyWith(
                                                  color: Colors.white.withOpacity(0.82),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.16),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: Colors.white.withOpacity(0.18)),
                                              ),
                                              child: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _introEntry(
              index: 7,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _trendsItems.length.clamp(0, 8),
                  (i) {
                    final active = i == (_trendsIndex.clamp(0, math.max(0, _trendsItems.length - 1)));
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? cs.primary : cs.outlineVariant.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

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

    if (_projectsFuture == null) {
      return Text(
        'Sign in to view your projects',
        style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
      );
    }

    String timeAgo(String? rawDate) {
      if (rawDate == null || rawDate.trim().isEmpty) return 'Recently';
      try {
        final d = DateTime.parse(rawDate).toLocal();
        final now = DateTime.now();
        final diff = now.difference(d);
        if (diff.inMinutes < 2) return 'Just now';
        if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
        if (diff.inHours < 24) return '${diff.inHours}h ago';
        return '${diff.inDays}d ago';
      } catch (_) {
        return 'Recently';
      }
    }

    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return FutureBuilder<List<dynamic>>(
      future: _projectsFuture,
      builder: (context, snapshot) {
        final raw = snapshot.data ?? const <dynamic>[];
        final items = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

        items.sort((a, b) {
          final ad = a['updatedAt']?.toString() ?? a['createdAt']?.toString() ?? '';
          final bd = b['updatedAt']?.toString() ?? b['createdAt']?.toString() ?? '';
          return bd.compareTo(ad);
        });

        final recent = items.take(3).toList();
        if (recent.isEmpty) {
          return Text(
            'No projects yet',
            style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
          );
        }

        return Column(
          children: recent.map((p) {
            final name = (p['name']?.toString() ?? '').trim().isNotEmpty ? p['name'].toString() : 'Project';
            final desc = (p['description']?.toString() ?? '').trim();
            final status = (p['status']?.toString() ?? '').trim().toLowerCase();
            final completed = status == 'ready' || status == 'completed';
            final when = p['updatedAt']?.toString() ?? p['createdAt']?.toString();
            final id = p['_id']?.toString() ?? p['id']?.toString();
            final downloads = toInt(p['downloadCount'] ?? p['downloadsCount'] ?? p['downloads']);
            final avatarText = name.isNotEmpty ? name[0].toUpperCase() : 'G';

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
                  onTap: (id == null || id.trim().isEmpty)
                      ? null
                      : () {
                          context.go('/project-detail', extra: {'projectId': id, 'project': p});
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                          ),
                          child: Center(
                            child: Text(
                              avatarText,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: AppTypography.subtitle1.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: AppSpacing.xs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: completed
                                          ? AppColors.success.withOpacity(0.2)
                                          : AppColors.warning.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(AppBorderRadius.small),
                                    ),
                                    child: Text(
                                      completed ? '✓' : '⏳',
                                      style: AppTypography.caption.copyWith(
                                        color: completed ? AppColors.success : AppColors.warning,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                desc.isNotEmpty ? desc : '—',
                                style: AppTypography.body2.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.sm),
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
                                          downloads.toString(),
                                          style: AppTypography.caption.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    timeAgo(when),
                                    style: AppTypography.caption.copyWith(
                                      color: cs.onSurfaceVariant,
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
      },
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
