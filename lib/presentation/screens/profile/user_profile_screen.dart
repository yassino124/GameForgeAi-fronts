import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/services/billing_service.dart';
import '../../../core/services/local_notifications_service.dart';
import '../../../core/services/notifications_service.dart';
import '../../../core/services/projects_service.dart';
import '../../../core/services/users_service.dart';
import '../../../core/services/daily_rewards_service.dart';
import '../../../core/services/reward_sfx_service.dart';
import '../../../core/utils/app_refresh_bus.dart';
import '../../../core/themes/app_theme.dart';
import '../../widgets/daily_wallet_sheet.dart';
import '../../widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../../widgets/reward_confetti_overlay.dart';

class UserProfileScreen extends StatefulWidget {
  final bool showAppBar;

  const UserProfileScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _XpMilestone {
  final int xp;
  final String title;
  final String rewardText;
  final IconData icon;
  final Color tone;

  const _XpMilestone({
    required this.xp,
    required this.title,
    required this.rewardText,
    required this.icon,
    required this.tone,
  });
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  int _subscriptionRefreshTick = 0;

  static const _kPrefQuizStreak = 'quiz_streak';
  static const _kPrefQuizBestScore = 'quiz_best_score';
  static const _kPrefQuizTotalXp = 'quiz_total_xp';
  static const _kPrefQuizTotalPlays = 'quiz_total_plays';
  static const _kPrefQuizBadges = 'quiz_badges';
  static const _kPrefQuizLastXpEarned = 'quiz_last_xp_earned';
  static const _kPrefQuizLastDateYmd = 'quiz_last_date_ymd';
  static const _kPrefDailyYmd = 'profile_daily_ymd';
  static const _kPrefDailyXp = 'profile_daily_xp';
  static const _kPrefDailyClaimedCsv = 'profile_daily_claimed_csv';

  bool _quizLoading = true;
  int _quizStreak = 0;
  int _quizBestScore = 0;
  int _quizTotalXp = 0;
  int _quizTotalPlays = 0;
  List<String> _quizBadges = const [];
  int _quizLastXpEarned = 0;
  String _quizLastDailyYmd = '';

  String _dailyYmd = '';
  int _dailyXp = 0;
  Set<String> _dailyClaimed = <String>{};

  bool _dailyStatusLoading = false;
  bool _canSpin = false;
  bool _canBox = false;
  int _aiCredits = 0;
  int _walletCount = 0;
  int _backendTotalXp = 0;
  int _backendStreak = 0;

  late final AnimationController _appearController;
  late final AnimationController _neonCtrl;

  late final VoidCallback _refreshListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _refreshListener = () {
      _loadQuizPrefs();
      _loadDailyStatus();
    };
    AppRefreshBus.notifier.addListener(_refreshListener);

    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    
    _neonCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _loadEverything();
  }

  Future<void> _loadEverything() async {
    await _loadQuizPrefs();
    await _loadDailyStatus();
  }

  Future<void> _loadDailyStatus() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || token.trim().isEmpty) return;

    setState(() => _dailyStatusLoading = true);
    try {
      final res = await DailyRewardsService.status(token: token);
      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        setState(() {
          _canSpin = data['canSpin'] == true;
          _canBox = data['canOpenMysteryBox'] == true;
          _aiCredits = (data['aiCredits'] is num) ? (data['aiCredits'] as num).toInt() : 0;
          _walletCount = (data['walletCount'] is num) ? (data['walletCount'] as num).toInt() : 0;
          _backendTotalXp = (data['totalXp'] is num) ? (data['totalXp'] as num).toInt() : 0;
          _backendStreak = (data['streak'] is num) ? (data['streak'] as num).toInt() : 0;
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _dailyStatusLoading = false);
    }
  }

  Future<void> _loadQuizPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final today = _todayYmd();
      final storedDailyYmd = p.getString(_kPrefDailyYmd) ?? '';
      if (storedDailyYmd != today) {
        await p.setString(_kPrefDailyYmd, today);
        await p.setInt(_kPrefDailyXp, 0);
        await p.setString(_kPrefDailyClaimedCsv, '');
      }

      if (!mounted) return;
      setState(() {
        _quizStreak = p.getInt(_kPrefQuizStreak) ?? 0;
        _quizBestScore = p.getInt(_kPrefQuizBestScore) ?? 0;
        _quizTotalXp = p.getInt(_kPrefQuizTotalXp) ?? 0;
        _quizTotalPlays = p.getInt(_kPrefQuizTotalPlays) ?? 0;
        _quizBadges = p.getStringList(_kPrefQuizBadges) ?? const [];
        _quizLastXpEarned = p.getInt(_kPrefQuizLastXpEarned) ?? 0;
        _quizLastDailyYmd = p.getString(_kPrefQuizLastDateYmd) ?? '';

        _dailyYmd = p.getString(_kPrefDailyYmd) ?? today;
        _dailyXp = p.getInt(_kPrefDailyXp) ?? 0;
        _dailyClaimed = (p.getString(_kPrefDailyClaimedCsv) ?? '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet();

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
    _neonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final cs = Theme.of(context).colorScheme;
        final user = authProvider.user;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF05060A) : cs.surface,
          body: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _appearController,
                  builder: (context, _) => CustomPaint(
                    painter: _ProfileMeshPainter(
                      color1: AppColors.primary.withOpacity(isDark ? 0.12 : 0.08),
                      color2: AppColors.secondary.withOpacity(isDark ? 0.08 : 0.06),
                      progress: _appearController.value,
                    ),
                  ),
                ),
              ),

              SafeArea(
                top: !widget.showAppBar,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    if (widget.showAppBar)
                      SliverAppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        title: Text(
                          'NEURAL IDENTITY',
                          style: AppTypography.labelLarge.copyWith(
                            color: isDark ? Colors.white : cs.onSurface,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        centerTitle: true,
                        leading: IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : cs.onSurface, size: 20),
                          onPressed: () => context.pop(),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            _buildProfileCard(context, user, authProvider, cs),
                            const SizedBox(height: 24),
                            _buildDailyHubWow(context),
                            const SizedBox(height: 18),
                            _buildUserStats(context),
                            const SizedBox(height: 18),
                            _buildAchievements(context),
                            const SizedBox(height: 18),
                            _buildRecentActivity(context),
                            const SizedBox(height: 18),
                            _buildSubscriptionCard(context, user),
                            const SizedBox(height: 18),
                            _buildActionList(authProvider, cs),
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileCard(BuildContext context, Map<String, dynamic>? user, AuthProvider auth, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatar = user?['avatar']?.toString();
    final username = user?['username']?.toString() ?? 'User';
    final email = user?['email']?.toString() ?? '';

    // Use backend XP instead of local shared preferences
    final totalXp = _backendTotalXp;
    final level = _levelFromXp(totalXp);
    final thisLevelStart = (level - 1) * 250;
    final nextLevelAt = level * 250;
    final within = (totalXp - thisLevelStart).clamp(0, 250);
    final progress = (within / 250).clamp(0.0, 1.0);

    return AnimatedCard(
      duration: const Duration(milliseconds: 1000),
      slideY: 40,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : cs.onSurface).withOpacity(isDark ? 0.03 : 0.05),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : cs.outlineVariant.withOpacity(0.8),
          ),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _neonCtrl,
                  builder: (context, child) {
                    return Container(
                      width: 110,
                      height: 110,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.secondary,
                            AppColors.primary.withOpacity(0.2),
                            AppColors.primary,
                          ],
                          transform: GradientRotation(_neonCtrl.value * 2 * 3.14159),
                        ),
                      ),
                      child: child,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? const Color(0xFF05060A) : cs.surface,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: (avatar != null && avatar.isNotEmpty)
                          ? NetworkImage(avatar)
                          : null,
                      child: (avatar == null || avatar.isEmpty)
                          ? const Icon(Icons.person_rounded, size: 40, color: Colors.white24)
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _changeAvatar(context, auth),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? const Color(0xFF05060A) : cs.surface, width: 2),
                      ),
                      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              username.toUpperCase(),
              style: AppTypography.displaySmall.copyWith(
                color: isDark ? Colors.white : cs.onSurface,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: AppTypography.bodyMedium.copyWith(
                color: isDark ? Colors.white38 : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Text(
                'LEVEL $level • $_quizTotalXp XP',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : cs.onSurface).withOpacity(isDark ? 0.02 : 0.04),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.05) : cs.outlineVariant.withOpacity(0.7),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'XP PROGRESS',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark ? Colors.white38 : cs.onSurfaceVariant,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                      Text(
                        '$within/250',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark ? Colors.white60 : cs.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 10,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              color: (isDark ? Colors.white : cs.onSurface).withOpacity(isDark ? 0.05 : 0.1),
                            ),
                          ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0.95),
                                    AppColors.secondary.withOpacity(0.85),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.18),
                                      blurRadius: 18,
                                      spreadRadius: 1,
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
                  const SizedBox(height: 10),
                  Text(
                    'Next level at $nextLevelAt XP',
                    style: AppTypography.caption.copyWith(
                      color: isDark ? Colors.white38 : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _todayYmd() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _claimDaily(String id, int bonusXp) async {
    final p = await SharedPreferences.getInstance();
    final today = _todayYmd();
    final storedDailyYmd = p.getString(_kPrefDailyYmd) ?? '';
    if (storedDailyYmd != today) {
      await p.setString(_kPrefDailyYmd, today);
      await p.setInt(_kPrefDailyXp, 0);
      await p.setString(_kPrefDailyClaimedCsv, '');
    }

    final claimed = (p.getString(_kPrefDailyClaimedCsv) ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (claimed.contains(id)) return;

    claimed.add(id);
    await p.setString(_kPrefDailyClaimedCsv, claimed.join(','));

    final prevXp = p.getInt(_kPrefQuizTotalXp) ?? 0;
    await p.setInt(_kPrefQuizTotalXp, prevXp + bonusXp);
    await p.setInt(_kPrefQuizLastXpEarned, bonusXp);

    AppRefreshBus.bump();
    if (!mounted) return;
    setState(() {
      _quizTotalXp = prevXp + bonusXp;
      _quizLastXpEarned = bonusXp;
      _dailyClaimed = claimed;
      _dailyYmd = p.getString(_kPrefDailyYmd) ?? today;
      _dailyXp = p.getInt(_kPrefDailyXp) ?? 0;
    });
  }

  void _openWallet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final auth = context.read<AuthProvider>();
        // Use the common DailyWalletSheet widget from home_dashboard.dart
        return DailyWalletSheet(token: auth.token ?? '');
      },
    );
  }

  String _rewardTitle(Map<String, dynamic> r) {
    final kind = (r['kind'] ?? '').toString();
    final v = (r['value'] is num) ? (r['value'] as num).toInt() : int.tryParse(r['value']?.toString() ?? '') ?? 0;
    if (kind == 'ai_credits') return '+$v AI Credits';
    if (kind == 'discount_templates') return '$v% OFF Template';
    if (kind == 'discount_subscription') return '$v% OFF Subscription';
    if (kind == 'free_pro_day') return 'Free Pro Day (24h)';
    if (kind == 'rare_template') return 'Rare Template';
    if (kind == 'exclusive_asset_pack') return 'Exclusive Asset Pack';
    if (kind == 'mystery_box') return 'Mystery Box';
    return kind.replaceAll('_', ' ').toUpperCase();
  }

  String _rewardSubtitle(Map<String, dynamic> r) {
    final kind = (r['kind'] ?? '').toString();
    if (kind == 'discount_templates') return 'Auto-applied at template checkout.';
    if (kind == 'discount_subscription') return 'Auto-applied when you subscribe.';
    if (kind == 'free_pro_day') return 'Redeem from your wallet.';
    return 'Unlocked now.';
  }

  Future<void> _openMysteryBoxFromProfile() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || token.trim().isEmpty) return;

    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}

    await RewardSfxService.playOpenBox();

    try {
      final res = await DailyRewardsService.openMysteryBox(token: token);
      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        final rewardRaw = data['reward'];
        final reward = rewardRaw is Map ? Map<String, dynamic>.from(rewardRaw) : <String, dynamic>{};

        final kind = (reward['kind'] ?? '').toString();
        final v = (reward['value'] is num) ? (reward['value'] as num).toInt() : int.tryParse(reward['value']?.toString() ?? '') ?? 0;
        if (kind == 'rare_template' || kind == 'exclusive_asset_pack' || v >= 200) {
          await RewardSfxService.playRareWin();
        } else {
          await RewardSfxService.playWin();
        }

        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            final cs = Theme.of(ctx).colorScheme;
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final bottom = MediaQuery.of(ctx).viewInsets.bottom;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (ctx, t, child) {
                return Padding(
                  padding: EdgeInsets.only(bottom: bottom),
                  child: Stack(
                    children: [
                      RewardConfettiOverlay(play: true, child: child!),
                      if (t > 0)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _ProfileCoinBurstPainter(progress: (t * 0.9).clamp(0.0, 1.0)),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.10) : cs.primary.withOpacity(0.1), 
                    width: 1.2
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withOpacity(0.60) : cs.primary.withOpacity(0.1), 
                      blurRadius: 44, 
                      offset: const Offset(0, 26)
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      color: isDark 
                          ? const Color(0xFF0B1020).withOpacity(0.90)
                          : cs.surface.withOpacity(0.95),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'MYSTERY BOX', 
                                style: AppTypography.titleMedium.copyWith(
                                  color: isDark ? Colors.white : cs.onSurface, 
                                  fontWeight: FontWeight.w900
                                )
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.of(ctx).pop(), 
                                icon: Icon(
                                  Icons.close_rounded, 
                                  color: isDark ? Colors.white70 : cs.onSurfaceVariant
                                )
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const _MysteryBox3DReveal(),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.accent.withOpacity(isDark ? 0.18 : 0.12),
                                  cs.primary.withOpacity(isDark ? 0.10 : 0.05),
                                ],
                              ),
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.12) : cs.primary.withOpacity(0.1)
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You won', 
                                  style: AppTypography.labelLarge.copyWith(
                                    color: isDark ? Colors.white70 : cs.onSurfaceVariant, 
                                    fontWeight: FontWeight.w900, 
                                    letterSpacing: 0.6
                                  )
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _rewardTitle(reward),
                                  style: AppTypography.titleLarge.copyWith(
                                    color: isDark ? Colors.white : cs.onSurface, 
                                    fontWeight: FontWeight.w900
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _rewardSubtitle(reward),
                                  style: AppTypography.body2.copyWith(
                                    color: isDark ? Colors.white70 : cs.onSurfaceVariant, 
                                    height: 1.25
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                elevation: 0,
                              ),
                              child: Text(
                                'NICE!', 
                                style: AppTypography.labelLarge.copyWith(
                                  fontWeight: FontWeight.w900, 
                                  letterSpacing: 0.8
                                )
                              ),
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
        );

        await _loadDailyStatus();
        return;
      }
      AppNotifier.showError(res['message']?.toString() ?? 'Open failed');
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(e.toString());
    }
  }

  void _openRewardHistory() {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('REWARD HISTORY', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900)),
                  ),
                  Expanded(
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: DailyRewardsService.status(token: token),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        final recent = (snap.data?['data']?['recent'] as List?) ?? [];
                        if (recent.isEmpty) return const Center(child: Text('No history yet.'));
                        return ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: recent.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final e = Map<String, dynamic>.from(recent[i]);
                            final kind = e['kind']?.toString() ?? '';
                            final source = e['source']?.toString().toUpperCase() ?? '';
                            final val = e['value']?.toString() ?? '0';
                            final ymd = e['ymd']?.toString() ?? '';
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(source, style: AppTypography.labelSmall.copyWith(color: cs.primary, fontWeight: FontWeight.w900)),
                                      Text(kind.replaceAll('_', ' ').toUpperCase(), style: AppTypography.body2.copyWith(fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const Spacer(),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(val, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900)),
                                      Text(ymd, style: AppTypography.caption.copyWith(color: Colors.white38)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDailyHubWow(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = _todayYmd();
    final dailyDone = _quizLastDailyYmd == today;

    final level = _levelFromXp(_backendTotalXp);
    final milestones = <_XpMilestone>[
      _XpMilestone(
        xp: 1000,
        title: 'Reach 1000 XP',
        rewardText: 'Win 10% OFF Templates',
        icon: Icons.local_offer_rounded,
        tone: cs.primary,
      ),
      _XpMilestone(
        xp: 2500,
        title: 'Reach 2500 XP',
        rewardText: 'Win 15% OFF Templates',
        icon: Icons.local_offer_rounded,
        tone: cs.tertiary,
      ),
      _XpMilestone(
        xp: 5000,
        title: 'Reach 5000 XP',
        rewardText: 'Win 10% OFF Subscription',
        icon: Icons.discount_rounded,
        tone: AppColors.warning,
      ),
      _XpMilestone(
        xp: 7500,
        title: 'Reach 7500 XP',
        rewardText: 'Win 20% OFF Subscription',
        icon: Icons.discount_rounded,
        tone: AppColors.accent,
      ),
    ];
    final challenges = <_DailyChallengeData>[
      _DailyChallengeData(
        id: 'daily_quiz',
        title: 'Daily Quiz Complete',
        subtitle: 'Finish today\'s daily quiz',
        icon: Icons.quiz_rounded,
        tone: cs.primary,
        current: dailyDone ? 1 : 0,
        target: 1,
        isDone: dailyDone,
        rewardXp: 25,
      ),
      _DailyChallengeData(
        id: 'daily_xp',
        title: 'XP Boost',
        subtitle: 'Earn 50 XP today',
        icon: Icons.auto_graph_rounded,
        tone: cs.tertiary,
        current: _dailyYmd == today ? _dailyXp : 0,
        target: 50,
        isDone: (_dailyYmd == today ? _dailyXp : 0) >= 50,
        rewardXp: 40,
      ),
      _DailyChallengeData(
        id: 'streak_3',
        title: 'Streak Builder',
        subtitle: 'Reach 3-day streak',
        icon: Icons.local_fire_department_rounded,
        tone: AppColors.warning,
        current: _backendStreak,
        target: 3,
        isDone: _backendStreak >= 3,
        rewardXp: 30,
      ),
    ];

    final completed = challenges.where((c) => c.isDone).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Row (Streak, Credits, Wallet)
        Row(
          children: [
            _buildHubStatCard(context, 'Streak', '$_backendStreak', Icons.local_fire_department_rounded, AppColors.warning),
            const SizedBox(width: 12),
            _buildHubStatCard(context, 'Credits', '$_aiCredits', Icons.auto_awesome_rounded, cs.primary),
            const SizedBox(width: 12),
            _buildHubStatCard(context, 'Wallet', '$_walletCount', Icons.inventory_2_rounded, cs.tertiary),
          ],
        ),
        const SizedBox(height: 18),
        
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : cs.onSurface).withOpacity(isDark ? 0.03 : 0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : cs.outlineVariant.withOpacity(0.8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAILY HUB',
                          style: AppTypography.titleMedium.copyWith(
                            color: isDark ? Colors.white : cs.onSurface,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Level $level • $completed/${challenges.length} completed',
                          style: AppTypography.body3.copyWith(
                            color: isDark ? Colors.white38 : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/game-quiz'),
                    child: Text(
                      'Play',
                      style: AppTypography.labelLarge.copyWith(
                        color: isDark ? AppColors.primary : cs.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Mystery Box Card
              if (_canBox)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildMysteryBoxPrompt(cs),
                ),

              ...challenges.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildDailyChallengeTile(context, c),
                  )),

              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : cs.onSurface).withOpacity(isDark ? 0.02 : 0.04),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.05) : cs.outlineVariant.withOpacity(0.7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: AppColors.primaryGradient,
                          ),
                          child: const Icon(Icons.emoji_events_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'XP MILESTONES',
                                style: AppTypography.subtitle2.copyWith(
                                  color: isDark ? Colors.white : cs.onSurface,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Your XP: $_backendTotalXp',
                                style: AppTypography.body3.copyWith(
                                  color: isDark ? Colors.white38 : cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...milestones.map((m) {
                      final reached = _backendTotalXp >= m.xp;
                      final prev = milestones.indexOf(m) == 0 ? 0 : milestones[milestones.indexOf(m) - 1].xp;
                      final span = (m.xp - prev).clamp(1, 999999999);
                      final within = (_backendTotalXp - prev).clamp(0, span);
                      final prog = (within / span).clamp(0.0, 1.0);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : cs.onSurface).withOpacity(isDark ? 0.02 : 0.04),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (reached ? m.tone : (isDark ? Colors.white : cs.outlineVariant))
                                .withOpacity(reached ? 0.30 : (isDark ? 0.06 : 0.8)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: m.tone.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: m.tone.withOpacity(0.24)),
                              ),
                              child: Icon(m.icon, color: m.tone),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          m.title,
                                          style: AppTypography.subtitle2.copyWith(
                                            color: isDark ? Colors.white : cs.onSurface,
                                            fontWeight: FontWeight.w900,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: (reached ? AppColors.success : (isDark ? Colors.white : cs.onSurface)).withOpacity(reached ? 0.12 : 0.06),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(
                                            color: (isDark ? Colors.white : cs.outlineVariant).withOpacity(0.08),
                                          ),
                                        ),
                                        child: Text(
                                          reached ? 'Unlocked' : '${m.xp - _backendTotalXp} XP left',
                                          style: AppTypography.labelSmall.copyWith(
                                            color: reached ? AppColors.success : (isDark ? Colors.white70 : cs.onSurfaceVariant),
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    m.rewardText,
                                    style: AppTypography.body3.copyWith(
                                      color: isDark ? Colors.white38 : cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: SizedBox(
                                      height: 8,
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: Container(
                                              color: (isDark ? Colors.white : cs.onSurface).withOpacity(0.05),
                                            ),
                                          ),
                                          FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: reached ? 1.0 : prog,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    m.tone.withOpacity(0.85),
                                                    m.tone.withOpacity(0.35),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _openWallet,
                    icon: const Icon(Icons.inventory_2_rounded, size: 18),
                    label: const Text('WALLET'),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white60 : cs.onSurfaceVariant,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openRewardHistory,
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('HISTORY'),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white60 : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHubStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : cs.onSurface).withOpacity(isDark ? 0.03 : 0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : cs.outlineVariant.withOpacity(0.8),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTypography.titleMedium.copyWith(
                color: isDark ? Colors.white : cs.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label.toUpperCase(),
              style: AppTypography.labelSmall.copyWith(
                color: isDark ? Colors.white38 : cs.onSurfaceVariant,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMysteryBoxPrompt(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.12), cs.primary.withOpacity(0.08)]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.inventory_2_rounded, color: AppColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mystery Box Ready!', style: AppTypography.subtitle2.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                Text('Open now for rare rewards', style: AppTypography.body3.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              onPressed: _openMysteryBoxFromProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                elevation: 0,
              ),
              child: Text('OPEN 🎁', style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyChallengeTile(BuildContext context, _DailyChallengeData c) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final claimed = _dailyClaimed.contains(c.id);
    final progress = (c.target <= 0) ? 0.0 : (c.current / c.target).clamp(0.0, 1.0);
    final canClaim = c.isDone && !claimed;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : cs.onSurface).withOpacity(isDark ? 0.02 : 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (c.isDone ? c.tone : (isDark ? Colors.white : cs.outlineVariant))
              .withOpacity(c.isDone ? 0.30 : (isDark ? 0.06 : 0.8)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.tone.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.tone.withOpacity(0.24)),
            ),
            child: Icon(c.icon, color: c.tone),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.title,
                  style: AppTypography.subtitle2.copyWith(
                    color: isDark ? Colors.white : cs.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  c.subtitle,
                  style: AppTypography.body3.copyWith(
                    color: isDark ? Colors.white38 : cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 8,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            color: (isDark ? Colors.white : cs.onSurface).withOpacity(0.05),
                          ),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(color: c.tone.withOpacity(0.85)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${c.current}/${c.target} • +${c.rewardXp} XP',
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? Colors.white38 : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (claimed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.success.withOpacity(0.22)),
              ),
              child: Text(
                'Claimed',
                style: AppTypography.labelSmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w900),
              ),
            )
          else
            SizedBox(
              height: 38,
              child: OutlinedButton(
                onPressed: canClaim ? () => _claimDaily(c.id, c.rewardXp) : null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: (canClaim ? c.tone : cs.outlineVariant).withOpacity(0.55)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  canClaim ? 'Claim' : (c.isDone ? 'Done' : 'Start'),
                  style: AppTypography.labelLarge.copyWith(
                    color: canClaim ? c.tone : (isDark ? Colors.white38 : cs.onSurfaceVariant.withOpacity(0.5)),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionList(AuthProvider auth, ColorScheme cs) {
    return Column(
      children: [
        _buildActionTile(context, 'Edit Profile', Icons.edit_rounded, () => context.push('/edit-profile')),
        _buildActionTile(context, 'Settings', Icons.settings_outlined, () => context.push('/settings')),
        _buildActionTile(context, 'Subscription', Icons.workspace_premium_outlined, () => context.push('/subscription')),
        _buildActionTile(context, 'Billing History', Icons.receipt_long_outlined, () {}),
        _buildActionTile(context, 'Security', Icons.security_rounded, () {}),
        const SizedBox(height: 16),
        _buildActionTile(context, 'Logout', Icons.logout_rounded, () => auth.logout(context: context), isDanger: true),
      ],
    );
  }

  Widget _buildActionTile(BuildContext context, String title, IconData icon, VoidCallback onTap, {bool isDanger = false}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : cs.onSurface).withOpacity(isDark ? 0.03 : 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : cs.outlineVariant.withOpacity(0.8),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDanger
                    ? AppColors.error
                    : (isDark ? Colors.white70 : cs.onSurfaceVariant),
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.subtitle2.copyWith(
                    color: isDanger
                        ? AppColors.error
                        : (isDark ? Colors.white : cs.onSurface),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white24 : cs.onSurfaceVariant.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Widget _wowEntry(Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _ctaGlow({required Widget child, bool enabled = true}) {
    if (!enabled) return child;
    return AnimatedBuilder(
      animation: _neonCtrl,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2 * _neonCtrl.value),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: child,
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

  Widget _chip(
    BuildContext context, {
    required IconData icon,
    required String text,
    Color? accent,
  }) {
    final cs = Theme.of(context).colorScheme;
    return _metaPill(icon: icon, text: text, cs: cs, accent: accent);
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
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withOpacity(0.22),
                    cs.surface.withOpacity(0.92),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      border: Border.all(color: cs.primary.withOpacity(0.25)),
                    ),
                    child: Icon(Icons.insights_rounded, color: cs.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Stats',
                          style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your build & activity snapshot',
                          style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (_quizStreak > 0)
                    _chip(
                      context,
                      icon: Icons.local_fire_department_rounded,
                      text: '${_quizStreak} streak',
                      accent: cs.tertiary,
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          FutureBuilder<Map<String, dynamic>>(
            future: (token == null || token.isEmpty) ? null : UsersService.getMyStats(token: token),
            builder: (context, snapshot) {
              final res = snapshot.data;
              final data = (res != null && res['success'] == true && res['data'] is Map)
                  ? Map<String, dynamic>.from(res['data'] as Map)
                  : <String, dynamic>{};

              final projects = _toInt(data['projects']);
              final downloads = _toInt(data['downloads']);
              final buildsFromStats = _toInt(data['builds']);
              final generationsFromStats = _toInt(data['generations']);

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

                  final builds = buildsFromNotifs > 0 ? buildsFromNotifs : buildsFromStats;
                  final generationsValue = gensFromNotifs > 0 ? gensFromNotifs : generationsFromStats;

                  final remixes = generationsValue;
                  final plays = _quizTotalPlays;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                          childAspectRatio: 2.05,
                          children: [
                            _buildWowStatTile(
                              context,
                              title: 'Games',
                              value: _formatCompactNumber(projects),
                              icon: Icons.videogame_asset_rounded,
                              tone: cs.primary,
                            ),
                            _buildWowStatTile(
                              context,
                              title: 'Remix',
                              value: _formatCompactNumber(remixes),
                              icon: Icons.auto_awesome_rounded,
                              tone: cs.tertiary,
                            ),
                            _buildWowStatTile(
                              context,
                              title: 'Builds',
                              value: _formatCompactNumber(builds),
                              icon: Icons.build_rounded,
                              tone: AppColors.success,
                            ),
                            _buildWowStatTile(
                              context,
                              title: 'Downloads',
                              value: _formatCompactNumber(downloads),
                              icon: Icons.download_rounded,
                              tone: cs.secondary,
                            ),
                            _buildWowStatTile(
                              context,
                              title: 'Plays',
                              value: _formatCompactNumber(plays),
                              icon: Icons.play_circle_fill_rounded,
                              tone: AppColors.warning,
                            ),
                            _buildWowStatTile(
                              context,
                              title: 'XP',
                              value: _formatCompactNumber(_quizTotalXp),
                              icon: Icons.local_fire_department_rounded,
                              tone: AppColors.secondary,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                        child: Row(
                          children: [
                            _chip(
                              context,
                              icon: Icons.trending_up_rounded,
                              text: 'Level ${_levelFromXp(_quizTotalXp)}',
                              accent: cs.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _chip(
                              context,
                              icon: Icons.rocket_launch_rounded,
                              text: '${_formatCompactNumber(builds)} builds shipped',
                              accent: cs.secondary,
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildWowStatTile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color tone,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
        gradient: LinearGradient(
          colors: [
            tone.withOpacity(0.16),
            cs.surfaceContainerHighest.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone.withOpacity(0.14),
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              border: Border.all(color: tone.withOpacity(0.25)),
            ),
            child: Icon(icon, color: tone, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subtitle1.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
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
                  title: 'Quiz Level ${_levelFromXp(_backendTotalXp)}',
                  description: '${_backendTotalXp} XP earned',
                  icon: Icons.auto_graph_rounded,
                  color: AppColors.secondary,
                  unlocked: _backendTotalXp > 0,
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

class _ProfileMeshPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final double progress;

  _ProfileMeshPainter({required this.color1, required this.color2, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    paint.color = color1;
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * (0.1 + 0.1 * progress)),
      size.width * 0.6 * progress,
      paint,
    );
    paint.color = color2;
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * (0.4 - 0.05 * progress)),
      size.width * 0.4 * progress,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProfileMeshPainter oldDelegate) => true;
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

class _DailyChallengeData {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tone;
  final int current;
  final int target;
  final bool isDone;
  final int rewardXp;

  const _DailyChallengeData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.current,
    required this.target,
    required this.isDone,
    required this.rewardXp,
  });
}

class _MysteryBox3DReveal extends StatefulWidget {
  const _MysteryBox3DReveal();

  @override
  State<_MysteryBox3DReveal> createState() => _MysteryBox3DRevealState();
}

class _MysteryBox3DRevealState extends State<_MysteryBox3DReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final wobble = math.sin(t * math.pi * 2) * 0.10;
        final wobble2 = math.cos(t * math.pi * 2) * 0.08;
        final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);
        final glow = 0.20 + 0.22 * pulse;
        final scale = 1.0 + 0.03 * pulse;

        return Center(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(-wobble2)
              ..rotateY(wobble)
              ..scale(scale),
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accent.withOpacity(isDark ? 0.22 + glow : 0.15 + glow * 0.5),
                    cs.primary.withOpacity(isDark ? 0.12 + glow : 0.08 + glow * 0.5),
                  ],
                ),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withOpacity(0.14 + glow)
                      : cs.primary.withOpacity(0.1 + glow * 0.2)
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(isDark ? 0.18 + glow : 0.1 + glow * 0.3),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: isDark ? 0.22 + 0.25 * pulse : 0.1 + 0.1 * pulse,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(34),
                          gradient: RadialGradient(
                            colors: [
                              isDark ? Colors.white.withOpacity(0.25) : cs.primary.withOpacity(0.15),
                              Colors.transparent,
                            ],
                            radius: 0.9,
                            center: Alignment.topLeft,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, -2 + 4 * math.sin(t * math.pi * 4)),
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        color: isDark ? Colors.white.withOpacity(0.06) : cs.surface.withOpacity(0.8),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.12) : cs.primary.withOpacity(0.1)
                        ),
                        boxShadow: isDark ? null : [
                          BoxShadow(
                            color: cs.primary.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        size: 44,
                        color: isDark ? Colors.white.withOpacity(0.92) : cs.primary,
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

class _ProfileCoinBurstPainter extends CustomPainter {
  final double progress;
  const _ProfileCoinBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    final center = Offset(size.width * 0.5, size.height * 0.35);

    final paint = Paint()..style = PaintingStyle.fill;
    const count = 14;
    for (int i = 0; i < count; i++) {
      final a = (i / count) * math.pi * 2;
      final radius = (70 + 170 * t);
      final wobble = 0.85 + 0.25 * math.sin((t * 6 * math.pi) + i);
      final p = center + Offset(math.cos(a) * radius * wobble, math.sin(a) * radius * wobble);
      final alpha = (1.0 - t).clamp(0.0, 1.0);

      paint.color = Color.lerp(AppColors.accent, AppColors.primary, (i % 5) / 5)!.withOpacity(0.75 * alpha);
      canvas.drawCircle(p, 6.0 - 2.0 * t, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProfileCoinBurstPainter oldDelegate) => oldDelegate.progress != progress;
}
