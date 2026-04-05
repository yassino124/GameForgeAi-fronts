import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/build_monitor_provider.dart';
import '../../../core/services/coach_overlay_controller.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/services/game_feed_service.dart';
import '../../../core/services/local_notifications_service.dart';
import '../../../core/services/notifications_service.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/projects_service.dart';
import '../../../core/services/templates_service.dart';
import '../../../core/services/users_service.dart';
import '../../../core/services/daily_rewards_service.dart';
import '../../../core/services/reward_sfx_service.dart';
import '../../../core/utils/app_refresh_bus.dart';
import '../../../core/themes/app_theme.dart';
import '../../widgets/daily_wallet_sheet.dart';
import '../../widgets/reward_confetti_overlay.dart';
import '../../widgets/widgets.dart';
import '../marketplace/marketplace.dart';
import '../profile/profile.dart';
import '../notifications/notifications.dart';
import '../arcade/arcade_feed_screen.dart';

void _noop() {}

class _DailyRewardPopupSheet extends StatefulWidget {
  final String token;
  final bool canClaim;
  final bool canBox;
  final int streak;
  final int walletCount;
  final Future<void> Function() onDone;

  const _DailyRewardPopupSheet({
    required this.token,
    required this.canClaim,
    required this.canBox,
    required this.streak,
    required this.walletCount,
    required this.onDone,
  });

  @override
  State<_DailyRewardPopupSheet> createState() => _DailyRewardPopupSheetState();
}

class _DailyRewardPopupSheetState extends State<_DailyRewardPopupSheet> with TickerProviderStateMixin {
  late final AnimationController _glow;
  late final AnimationController _coins;
  bool _busy = false;
  Map<String, dynamic>? _lastReward;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
    _coins = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  }

  @override
  void dispose() {
    _glow.dispose();
    _coins.dispose();
    super.dispose();
  }

  String _rewardTitle(Map<String, dynamic> r) {
    final kind = (r['kind'] ?? '').toString();
    final value = r['value'];
    final v = (value is num) ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
    if (kind == 'bundle') return 'STREAK REWARD';
    if (kind == 'ai_credits') return '+$v AI CREDITS';
    if (kind == 'xp') return '+$v XP';
    if (kind == 'discount_templates') return '$v% OFF TEMPLATE';
    if (kind == 'discount_subscription') return '$v% OFF SUBSCRIPTION';
    if (kind == 'rare_template') return 'RARE TEMPLATE';
    if (kind == 'exclusive_asset_pack') return 'EXCLUSIVE ASSET';
    if (kind == 'free_pro_day') return 'FREE PRO DAY (24H)';
    return 'REWARD';
  }

  String _rewardSubtitle(Map<String, dynamic> r) {
    final kind = (r['kind'] ?? '').toString();
    final meta = r['meta'];
    if (kind == 'bundle' && meta is Map) {
      final xp = (meta['xp'] is num) ? (meta['xp'] as num).toInt() : int.tryParse(meta['xp']?.toString() ?? '') ?? 0;
      final credits = (meta['aiCredits'] is num) ? (meta['aiCredits'] as num).toInt() : int.tryParse(meta['aiCredits']?.toString() ?? '') ?? 0;
      return '+$xp XP  •  +$credits AI Credits';
    }
    if (kind == 'discount_templates') return 'Auto-applied at template checkout.';
    if (kind == 'discount_subscription') return 'Auto-applied when you subscribe.';
    if (kind == 'free_pro_day') return 'Redeem from your wallet.';
    return 'Unlocked now.';
  }

  Future<void> _fireCoins() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
    _coins.value = 0;
    try {
      await _coins.animateTo(1, curve: Curves.easeOutCubic);
    } catch (_) {}
  }

  Future<void> _claim() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await DailyRewardsService.claim(token: widget.token);
      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        final rewardRaw = data['reward'];
        final reward = rewardRaw is Map ? Map<String, dynamic>.from(rewardRaw) : <String, dynamic>{};
        setState(() => _lastReward = reward);
        await _fireCoins();
        await widget.onDone();
      } else {
        AppNotifier.showError(res['message']?.toString() ?? 'Claim failed');
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openBox() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await DailyRewardsService.openMysteryBox(token: widget.token);
      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        final rewardRaw = data['reward'];
        final reward = rewardRaw is Map ? Map<String, dynamic>.from(rewardRaw) : <String, dynamic>{};
        setState(() => _lastReward = reward);
        await _fireCoins();
        await widget.onDone();
      } else {
        AppNotifier.showError(res['message']?.toString() ?? 'Open failed');
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openWallet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DailyWalletSheet(token: widget.token),
    );
    await widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final reward = _lastReward;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.10), width: 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.60), blurRadius: 44, offset: const Offset(0, 26))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: AnimatedBuilder(
              animation: Listenable.merge([_glow, _coins]),
              builder: (context, _) {
                final glow = 0.5 + 0.5 * math.sin(_glow.value * 2 * math.pi);
                return Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      color: const Color(0xFF0B1020).withOpacity(0.90),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'DAILY REWARD UNLOCKED',
                                style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary.withOpacity(0.18 + 0.08 * glow),
                                  AppColors.accent.withOpacity(0.10 + 0.06 * glow),
                                ],
                              ),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Day ${math.max(1, widget.streak)} Streak', style: AppTypography.labelLarge.copyWith(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                                const SizedBox(height: 8),
                                Text(
                                  reward == null ? 'Claim now to reveal your reward.' : _rewardTitle(reward),
                                  style: AppTypography.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  reward == null ? 'Spin / Mystery Box / Wallet rewards.' : _rewardSubtitle(reward),
                                  style: AppTypography.body2.copyWith(color: Colors.white70, height: 1.25),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        color: Colors.black.withOpacity(0.25),
                                        border: Border.all(color: Colors.white.withOpacity(0.10)),
                                      ),
                                      child: Text(
                                        'Wallet: ${widget.walletCount}',
                                        style: AppTypography.labelSmall.copyWith(color: Colors.white70, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: _openWallet,
                                      icon: const Icon(Icons.inventory_2_rounded, color: Colors.white70, size: 18),
                                      label: Text('WALLET', style: AppTypography.labelLarge.copyWith(color: Colors.white70, fontWeight: FontWeight.w900)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: (widget.canClaim && !_busy) ? AppColors.primaryGradient : null,
                                      color: (widget.canClaim && !_busy) ? null : Colors.white10,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: (!widget.canClaim || _busy) ? null : _claim,
                                        borderRadius: BorderRadius.circular(18),
                                        child: Center(
                                          child: Text(
                                            _busy ? 'CLAIMING…' : (widget.canClaim ? 'CLAIM NOW 🚀' : 'CLAIMED'),
                                            style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 11),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: (widget.canBox && !_busy) ? LinearGradient(colors: [AppColors.accent, AppColors.primary]) : null,
                                      color: (widget.canBox && !_busy) ? null : Colors.white10,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: (!widget.canBox || _busy) ? null : _openBox,
                                        borderRadius: BorderRadius.circular(18),
                                        child: Center(
                                          child: Text(
                                            _busy ? 'OPENING…' : (widget.canBox ? 'MYSTERY BOX 🎁' : 'OPENED'),
                                            style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 11),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tip: Discounts auto-apply. Free Pro Day can be redeemed from wallet.',
                            style: AppTypography.caption.copyWith(color: Colors.white54, fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    if (_coins.value > 0)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _CoinBurstPainter(progress: _coins.value),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CoinBurstPainter extends CustomPainter {
  final double progress;
  const _CoinBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    final center = Offset(size.width * 0.5, size.height * 0.35);

    final paint = Paint()..style = PaintingStyle.fill;
    final count = 16;
    for (int i = 0; i < count; i++) {
      final a = (i / count) * math.pi * 2;
      final radius = (80 + 180 * t);
      final wobble = 0.85 + 0.25 * math.sin((t * 6 * math.pi) + i);
      final p = center + Offset(math.cos(a) * radius * wobble, math.sin(a) * radius * wobble);
      final alpha = (1.0 - t).clamp(0.0, 1.0);

      paint.color = Color.lerp(AppColors.accent, AppColors.primary, (i % 5) / 5)!.withOpacity(0.75 * alpha);
      canvas.drawCircle(p, 6.5 - 2.0 * t, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CoinBurstPainter oldDelegate) => oldDelegate.progress != progress;
}

class _MeshPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final double progress;

  _MeshPainter({required this.color1, required this.color2, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    paint.color = color1;
    canvas.drawCircle(
      Offset(
        size.width * (0.2 + 0.1 * math.sin(progress * 2 * math.pi)),
        size.height * (0.3 + 0.1 * math.cos(progress * 2 * math.pi)),
      ),
      size.width * 0.6,
      paint,
    );
    paint.color = color2;
    canvas.drawCircle(
      Offset(
        size.width * (0.8 + 0.1 * math.cos(progress * 2 * math.pi)),
        size.height * (0.7 + 0.1 * math.sin(progress * 2 * math.pi)),
      ),
      size.width * 0.5,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) => true;
}

class GradientTranslation extends GradientTransform {
  final double dx;
  const GradientTranslation(this.dx);
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, 0.0, 0.0);
  }
}

class _TrendingGameData {
  final String title;
  final String subtitle;
  final String metric;
  final IconData metricIcon;
  final String imageUrl;

  const _TrendingGameData({
    required this.title,
    required this.subtitle,
    required this.metric,
    required this.metricIcon,
    required this.imageUrl,
  });
}

class _AICoachPromptCard extends StatelessWidget {
  final AnimationController wow;
  final String message;
  final String yesLabel;
  final String laterLabel;
  final VoidCallback onYes;
  final VoidCallback onLater;
  final VoidCallback onAvatarTap;

  const _AICoachPromptCard({
    required this.wow,
    required this.message,
    required this.yesLabel,
    required this.laterLabel,
    required this.onYes,
    required this.onLater,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: wow,
      builder: (context, _) {
        final t = wow.value;
        final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : cs.outlineVariant.withOpacity(0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.18 + 0.12 * pulse),
                blurRadius: 26,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (isDark ? const Color(0xFF0F111A) : cs.surface).withOpacity(0.68),
                      (isDark ? Colors.white : cs.primary).withOpacity(isDark ? 0.04 : 0.035),
                    ],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onAvatarTap,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.95),
                              const Color(0xFFA855F7).withOpacity(0.90),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.20 + 0.15 * pulse),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: isDark ? const Color(0xFF0B0D14) : cs.surface,
                          child: ClipOval(
                            child: Image.network(
                              'https://api.dicebear.com/7.x/bottts/png?seed=gameforge&backgroundColor=0b0d14',
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.smart_toy_rounded,
                                  color: isDark ? Colors.white70 : cs.onSurfaceVariant,
                                  size: 26,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.06) : cs.surfaceContainerHighest.withOpacity(0.60),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withOpacity(0.10) : cs.outlineVariant.withOpacity(0.9),
                                  ),
                                ),
                                child: Text(
                                  'AI Coach:',
                                  style: AppTypography.labelLarge.copyWith(
                                    color: isDark ? Colors.white : cs.onSurface,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.bolt_rounded, color: const Color(0xFFFBBF24).withOpacity(0.85), size: 18),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            message,
                            style: AppTypography.subtitle2.copyWith(
                              color: isDark ? Colors.white : cs.onSurface,
                              fontWeight: FontWeight.w900,
                              height: 1.25,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: isDark
                                          ? const []
                                          : [
                                              BoxShadow(
                                                color: AppColors.primary.withOpacity(0.18),
                                                blurRadius: 18,
                                                offset: const Offset(0, 10),
                                              ),
                                            ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: onYes,
                                        borderRadius: BorderRadius.circular(999),
                                        child: Center(
                                          child: Text(
                                            yesLabel,
                                            style: AppTypography.labelLarge.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: OutlinedButton(
                                    onPressed: onLater,
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: isDark ? Colors.white.withOpacity(0.18) : cs.outlineVariant.withOpacity(0.9),
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                      foregroundColor: isDark ? Colors.white : cs.onSurface,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        laterLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ),
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
      },
    );
  }
}

class _TrendingGameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String metric;
  final IconData metricIcon;
  final String imageUrl;
  final VoidCallback onTap;

  const _TrendingGameCard({
    required this.title,
    required this.subtitle,
    required this.metric,
    required this.metricIcon,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.transparent : cs.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : cs.outlineVariant.withOpacity(0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withOpacity(0.18),
                          AppColors.accent.withOpacity(0.12),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                      ? [
                          Colors.transparent,
                          Colors.black.withOpacity(0.86),
                        ]
                      : [
                          Colors.transparent,
                          cs.surface.withOpacity(0.95),
                        ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.subtitle2.copyWith(
                        color: isDark ? Colors.white : cs.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            style: AppTypography.body3.copyWith(
                              color: isDark ? Colors.white70 : cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isDark ? cs.surface : cs.primaryContainer).withOpacity(0.34),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.12) : cs.outlineVariant.withOpacity(0.8),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                metricIcon,
                                size: 14,
                                color: isDark ? Colors.white70 : cs.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                metric,
                                style: AppTypography.labelSmall.copyWith(
                                  color: isDark ? Colors.white : cs.onSurface,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
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
    );
  }
}

class _RecentProjectCard extends StatelessWidget {
  final Map<String, dynamic> project;
  final VoidCallback onTap;

  const _RecentProjectCard({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = (project['name'] ?? project['title'] ?? 'Untitled').toString();
    final status = (project['status'] ?? 'queued').toString().toLowerCase();
    final isReady = status == 'ready';
    final isFailed = status == 'failed';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : cs.onSurface).withOpacity(isDark ? 0.03 : 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : cs.outlineVariant.withOpacity(0.8),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: isFailed
                    ? LinearGradient(colors: [AppColors.error.withOpacity(0.2), AppColors.error.withOpacity(0.1)])
                    : AppColors.primaryGradient.withOpacity(0.1),
              ),
              child: Icon(
                isReady ? Icons.rocket_launch_rounded : (isFailed ? Icons.error_outline_rounded : Icons.hourglass_empty_rounded),
                color: isFailed ? AppColors.error : (isReady ? cs.primary : cs.onSurfaceVariant),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.subtitle2.copyWith(
                      color: isDark ? Colors.white : cs.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFailed ? AppColors.error : (isReady ? AppColors.success : Colors.orange),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.toUpperCase(),
                        style: AppTypography.caption.copyWith(
                          color: isDark ? Colors.white54 : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : cs.onSurfaceVariant.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedTemplateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final String imageUrl;
  final VoidCallback onTap;

  const _FeaturedTemplateCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 118,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : cs.outlineVariant.withOpacity(0.8),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.08),
              blurRadius: 26,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cs.primary.withOpacity(0.22),
                          cs.secondary.withOpacity(0.14),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: isDark
                      ? [
                          Colors.black.withOpacity(0.88),
                          Colors.black.withOpacity(0.35),
                          Colors.transparent,
                        ]
                      : [
                          cs.surface.withOpacity(0.92),
                          cs.surface.withOpacity(0.4),
                          Colors.transparent,
                        ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withOpacity(isDark ? 0.22 : 0.4),
                              ),
                            ),
                            child: Text(
                              badge,
                              style: AppTypography.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            style: AppTypography.subtitle2.copyWith(
                              color: isDark ? Colors.white : cs.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: AppTypography.body3.copyWith(
                              color: isDark ? Colors.white70 : cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (isDark ? cs.surface : cs.primaryContainer).withOpacity(0.30),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.12) : cs.outlineVariant.withOpacity(0.8),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: isDark ? cs.onSurface : cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeDashboard extends StatefulWidget {
  final int initialIndex;
  const HomeDashboard({super.key, this.initialIndex = 0});
  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  static const _kPrefDailyYmd = 'profile_daily_ymd';
  static const _kPrefDailyXp = 'profile_daily_xp';
  static const _kPrefDailyRewardsYmd = 'daily_rewards_ymd';
  static const _kPrefDailyRewardsClaimed = 'daily_rewards_claimed';
  static const _kPrefDailyRewardsKind = 'daily_rewards_kind';
  static const _kPrefDailyRewardsValue = 'daily_rewards_value';
  static const _kPrefDailyMarketplaceVisit = 'daily_marketplace_visit';
  static const _kPrefDailyForgeAction = 'daily_forge_action';
  static const _kPrefCoachTipIndex = 'coach_tip_index';

  @override
  bool get wantKeepAlive => true;

  late int _selectedIndex;
  int _lastNonArcadeIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final AnimationController _drawerAnim;
  late final AnimationController _homeIntroAnim;
  late final AnimationController _wowAnim;
  bool _dailyRewardsLoading = false;
  bool _dailyRewardsClaimed = false;
  String _dailyRewardsYmd = '';
  String? _dailyRewardsKind;
  int? _dailyRewardsValue;
  bool _dailyRewardsCanSpin = true;
  bool _dailyRewardsCanClaim = false;
  bool _dailyRewardsCanBox = false;
  int _dailyRewardsStreak = 0;
  int _dailyRewardsAiCredits = 0;
  int _dailyRewardsWalletCount = 0;
  bool _dailyRewardsPopupShown = false;
  Future<List<dynamic>>? _projectsFuture;
  String? _projectsToken;
  Future<Map<String, dynamic>>? _statsFuture;
  String _recentForgesFilter = 'All';
  String? _trendsToken;
  Timer? _trendsTimer;
  List<Map<String, dynamic>> _trendsItems = const [];
  bool _trendsLoading = false;
  String? _trendsError;

  bool _trendingLoading = false;
  String? _trendingError;
  List<_TrendingGameData> _trendingGames = const [];

  bool _topTemplateLoading = false;
  String? _topTemplateError;
  Map<String, dynamic>? _topTemplate;
  String? _templatesToken;
  Timer? _trendsAutoTimer;
  int _trendsIndex = 0;
  final PageController _trendsPageController = PageController(viewportFraction: 0.92);
  int _unreadNotifCount = 0;
  bool _unreadNotifLoading = false;
  Timer? _notifTimer;
  late final VoidCallback _refreshListener;

  static const Map<String, Map<String, List<String>>> _coachTipPoolsByLang = {
    'ar': {
      'onboarding': [
        '"Start سريع: اضغط Create New Game و جرّب Template باش ما تبدأش من الصفر."',
        '"لوّل game؟ خليك بسيط: level واحد + هدف واحد (وصل للباب/جمع coins)."',
        '"جرّب controls: Move + Jump فقط… بعد زيد mechanics وحدة وحدة."',
      ],
      'ai': [
        '"مش عارف شنوّة تعمل توا؟ امشي للـ Coach و قلو شنوّة نوع لعبتك، يعطيك plan."',
        '"استعمل Coach باش يعملك ideas للـ levels و missions حسب genre متاعك."',
        '"جرّب Generation واحدة للـ assets/description… وبعد عدّل عليهم بإيدك."',
      ],
      'publish': [
        '"قبل ما تنشر: حطّ thumbnail واضح + title قصير + description فيه gameplay."',
        '"اعمل playtest مع صاحبك: إذا ضاع في أول 10 ثواني، بدّل tutorial/UX."',
        '"ضيف زر Restart و Pause… حاجات صغار يفرقو برشا في الجودة."',
      ],
      'polish': [
        '"زيد juice: particles + sfx + small camera shake… يعطي feeling pro."',
        '"أحسن حاجة للـ retention: Tutorial صغير 5 ثواني (Jump/Move) قبل أول level."',
        '"خلي هدف واضح: Collect coins / Reach the door / Defeat boss… و اكتبها في UI."',
      ],
      'performance': [
        '"Performance tip: قلّل صور كبيرة، و استعمل نفس prefab/object بدل ما تخلق برشا."',
        '"جرّب على تليفون ضعيف: إذا FPS يطيح، نقص effects و صغّر textures."',
        '"خلي UI خفيف و واضح… الزيادة تعمل lag و تشوّش اللاعب."',
      ],
      'general': [
        '"استعمل Quick Actions: Create New Game باش تبدا، و Browse Templates باش تلقى أفكار."',
        '"كل مرة تعمل build جرّبو على تليفونك: FPS و controls يبانوا غادي خير."',
        '"مش عارف شنوة تصلّح اليوم؟ امشي للـ Coach و قولي شنية نوع لعبتك، نعاونك بخطّة."',
      ],
    },
    'fr': {
      'onboarding': [
        '"Démarrage rapide : clique sur Create New Game et pars d\'un Template."',
        '"Premier jeu ? Reste simple : 1 niveau + 1 objectif (porte / pièces)."',
        '"Commence avec Move + Jump, puis ajoute des mécaniques petit à petit."',
      ],
      'ai': [
        '"Bloqué ? Va au Coach, dis le genre de ton jeu, il te donne un plan."',
        '"Utilise le Coach pour des idées de niveaux et de missions selon ton genre."',
        '"Fais une génération (assets/description) puis améliore-la toi-même."',
      ],
      'publish': [
        '"Avant de publier : miniature claire + titre court + description gameplay."',
        '"Fais tester 10 secondes : si c\'est confus, améliore le tutoriel/UX."',
        '"Ajoute Restart et Pause : petits détails, grosse qualité."',
      ],
      'polish': [
        '"Ajoute du juice : particules + SFX + léger screen shake."',
        '"Un mini tutoriel (5 secondes) augmente énormément la rétention."',
        '"Objectif clair : coins / porte / boss… affiche-le dans l\'UI."',
      ],
      'performance': [
        '"Performance : réduis les grosses images et réutilise les objets/prefabs."',
        '"Teste sur un téléphone faible : baisse les effets si les FPS chutent."',
        '"UI simple et léger : trop d\'effets = lag + confusion."',
      ],
      'general': [
        '"Utilise Quick Actions pour démarrer, et Browse Templates pour l\'inspiration."',
        '"Teste à chaque build sur téléphone : contrôles et FPS se sentent mieux."',
        '"Tu ne sais pas quoi améliorer ? Va au Coach, je te guide étape par étape."',
      ],
    },
    'en': {
      'onboarding': [
        '"Quick start: tap Create New Game and begin from a Template."',
        '"First game? Keep it simple: 1 level + 1 clear goal (door / coins)."',
        '"Start with Move + Jump, then add mechanics one by one."',
      ],
      'ai': [
        '"Stuck? Go to Coach, tell your game genre, and get a clear plan."',
        '"Use Coach for level and mission ideas tailored to your genre."',
        '"Generate once (assets/description) then refine it yourself."',
      ],
      'publish': [
        '"Before publishing: clear thumbnail + short title + gameplay description."',
        '"Do a 10-second playtest: if it\'s confusing, improve tutorial/UX."',
        '"Add Restart and Pause—small features, big quality boost."',
      ],
      'polish': [
        '"Add juice: particles + SFX + subtle screen shake."',
        '"A 5-second tutorial greatly improves retention."',
        '"Make the goal explicit: coins / door / boss… show it in the UI."',
      ],
      'performance': [
        '"Performance: reduce large textures and reuse objects/prefabs."',
        '"Test on a low-end phone: lower effects if FPS drops."',
        '"Keep UI clean and light—too many effects can cause lag."',
      ],
      'general': [
        '"Use Quick Actions to start, and Browse Templates for inspiration."',
        '"Test every build on your phone: controls and FPS feel different."',
        '"Not sure what to improve today? Go to Coach and I\'ll guide you."',
      ],
    },
  };

  int _coachTipIndex = -1;
  String _coachTipCategory = 'general';
  String _coachLang = 'ar';
  String _coachTipMessage = _coachTipPoolsByLang['ar']!['general']!.first;
  bool _coachCardDismissed = false;

  int? _cachedProjectsCount;
  int? _cachedGenerationsCount;
  int? _cachedDownloadsCount;

  static const List<String> _trendFallbackImages = [
    'https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1542751110-97427bbecf20?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1605902711622-cfb43c44367f?auto=format&fit=crop&w=1200&q=80',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedIndex = widget.initialIndex;
    _lastNonArcadeIndex = (_selectedIndex == 3) ? 0 : _selectedIndex;
    _refreshListener = () {
      final token = _projectsToken;
      if (token != null && token.trim().isNotEmpty) {
        setState(() {
          _projectsFuture = ProjectsService.listProjects(token: token).then((res) {
            if (res['success'] != true) {
              throw Exception(res['message']?.toString() ?? 'Failed to load projects');
            }
            final data = res['data'];
            if (data is Map && data['projects'] is List) {
              return (data['projects'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
            }
            if (data is List) return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
            return <dynamic>[];
          });
          _statsFuture = UsersService.getMyStats(token: token);
        });
        _loadUnreadNotifications();
      }
    };
    AppRefreshBus.notifier.addListener(_refreshListener);
    _drawerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _homeIntroAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _homeIntroAnim.forward();
    _wowAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200))..repeat();
    _loadDailyRewards();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowDailyRewardPopup();
    });
    unawaited(_refreshCoachTip(advance: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshCoachTip(advance: true));
    }
  }

  Future<void> _refreshCoachTip({required bool advance}) async {
    final p = await SharedPreferences.getInstance();
    final category = _pickCoachCategory();
    final langPools = _coachTipPoolsByLang[_coachLang] ?? _coachTipPoolsByLang['en']!;
    final pool = langPools[category] ?? langPools['general']!;
    final key = '${_kPrefCoachTipIndex}_${_coachLang}_$category';
    final last = p.getInt(key) ?? -1;
    final nextIndex = advance ? ((last + 1) % pool.length) : (last % pool.length);
    await p.setInt(key, nextIndex);
    if (!mounted) return;
    setState(() {
      _coachTipCategory = category;
      _coachTipIndex = nextIndex;
      _coachTipMessage = pool[nextIndex];
      _coachCardDismissed = false;
    });
  }

  String _pickCoachCategory() {
    final projects = _cachedProjectsCount;
    final gens = _cachedGenerationsCount;
    final dls = _cachedDownloadsCount;

    if (projects != null && projects <= 0) return 'onboarding';
    if (gens != null && gens <= 0) return 'ai';
    if (dls != null && dls <= 0) return 'publish';
    if (projects != null && projects >= 3) return 'polish';
    return 'general';
  }

  dynamic _statFromStatsKeysRaw(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final k in keys) {
      if (data.containsKey(k)) return data[k];
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    final lang = (locale.languageCode).toLowerCase();
    final normalized = (lang == 'fr' || lang == 'en') ? lang : 'ar';
    if (_coachLang != normalized) {
      _coachLang = normalized;
      unawaited(_refreshCoachTip(advance: false));
    }
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token != null && token.isNotEmpty && token != _projectsToken) {
      _projectsToken = token;
      _projectsFuture = ProjectsService.listProjects(token: token).then((res) {
        if (res['success'] != true) {
          throw Exception(res['message']?.toString() ?? 'Failed to load projects');
        }
        final data = res['data'];
        if (data is Map && data['projects'] is List) {
          return (data['projects'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
        if (data is List) return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        return <dynamic>[];
      });
      unawaited(_projectsFuture!.then((list) {
        if (!mounted) return;
        final count = list.length;
        if (_cachedProjectsCount != count) {
          setState(() => _cachedProjectsCount = count);
        }
      }).catchError((_) {}));
      _statsFuture = UsersService.getMyStats(token: token);
      unawaited(_statsFuture!.then((res) {
        final ok = (res['success'] == true);
        final data = ok && res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : null;
        final gens = _asInt(_statFromStatsKeysRaw(data, const ['generations', 'aiGenerations', 'generationCount']));
        final dls = _asInt(_statFromStatsKeysRaw(data, const ['downloads', 'templateDownloads', 'downloadCount']));
        if (!mounted) return;
        if (_cachedGenerationsCount != gens || _cachedDownloadsCount != dls) {
          setState(() {
            _cachedGenerationsCount = gens;
            _cachedDownloadsCount = dls;
          });
        }
      }).catchError((_) {}));
    }
    if (token != null && token.isNotEmpty && token != _trendsToken) {
      _trendsToken = token;
      _trendsTimer?.cancel();
      _loadTrends();
      _trendsTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadTrends());
    }
    if (token != null && token.isNotEmpty && token != _templatesToken) {
      _templatesToken = token;
      _loadTrendingGames();
      _loadTopTemplate();
    }
    if (token != null && token.isNotEmpty) {
      _notifTimer?.cancel();
      _loadUnreadNotifications();
      _notifTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadUnreadNotifications());
    } else {
      _notifTimer?.cancel();
      if (_unreadNotifCount != 0) setState(() => _unreadNotifCount = 0);
    }
  }

  String? _resolveMediaUrl(String? url) {
    if (url == null) return null;
    final raw = url.trim();
    if (raw.isEmpty) return null;

    try {
      final base = Uri.parse(ApiService.baseUrl);
      final baseOrigin = Uri(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null);

      if (raw.startsWith('/')) {
        return baseOrigin.resolve(raw).toString();
      }

      final u = Uri.parse(raw);
      if (!u.hasScheme) {
        return baseOrigin.resolve('/$raw').toString();
      }

      return baseOrigin.replace(path: u.path, query: u.query).toString();
    } catch (_) {
      return raw;
    }
  }

  int _asInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  String _formatCount(int n) {
    if (n >= 1000000) {
      final v = (n / 1000000.0);
      return v >= 10 ? '${v.toStringAsFixed(0)}M' : '${v.toStringAsFixed(1)}M';
    }
    if (n >= 1000) {
      final v = (n / 1000.0);
      return v >= 10 ? '${v.toStringAsFixed(0)}K' : '${v.toStringAsFixed(1)}K';
    }
    return n.toString();
  }

  double _gameScore(Map<String, dynamic> p) {
    final likes = _asInt(p['likeCount']);
    final plays = _asInt(p['playCount']);
    final views = _asInt(p['viewCount']);
    final rating = _asDouble(p['rating']);

    final v = (views > 0) ? views : plays;
    return likes * 3.0 + math.sqrt(v.toDouble()) * 1.8 + rating * 10.0;
  }

  double _templateScore(Map<String, dynamic> t) {
    final rating = _asDouble(t['rating']);
    final downloads = _asInt(t['downloads']);
    final likes = _asInt(t['likeCount']);
    return rating * 40.0 + math.sqrt(downloads.toDouble()) * 2.2 + likes * 3.0;
  }

  Future<void> _loadTrendingGames() async {
    final token = _templatesToken;
    if (token == null || token.trim().isEmpty || _trendingLoading) return;

    setState(() {
      _trendingLoading = true;
      _trendingError = null;
    });

    try {
      final res = await GameFeedService.list(token: token, limit: 30);
      final data = res['data'];
      final list = (data is List) ? data : const [];

      final posts = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      posts.sort((a, b) => _gameScore(b).compareTo(_gameScore(a)));

      final top = posts.take(12).map((p) {
        final title = (p['title'] ?? p['name'] ?? 'Game').toString();
        final likes = _asInt(p['likeCount']);
        final plays = _asInt(p['playCount']);
        final views = _asInt(p['viewCount']);
        final v = (views > 0) ? views : plays;

        final imageUrl = (p['previewImageUrl'] ?? p['previewImage'] ?? p['thumbnailUrl'] ?? '').toString();
        final resolvedImage = _resolveMediaUrl(imageUrl) ?? imageUrl;

        return _TrendingGameData(
          title: title,
          subtitle: v > 0 ? '${_formatCount(v)} views' : '${_formatCount(likes)} likes',
          metric: _formatCount(likes),
          metricIcon: Icons.favorite_rounded,
          imageUrl: resolvedImage,
        );
      }).toList(growable: false);

      if (!mounted) return;
      setState(() {
        _trendingGames = top;
        _trendingLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _trendingLoading = false;
        _trendingError = e.toString();
        _trendingGames = const [];
      });
    }
  }

  Future<void> _loadTopTemplate() async {
    if (_topTemplateLoading) return;

    setState(() {
      _topTemplateLoading = true;
      _topTemplateError = null;
    });

    try {
      final res = await TemplatesService.listPublicTemplates();
      final raw = (res['success'] == true && res['data'] is List) ? (res['data'] as List) : const [];
      final templates = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      templates.sort((a, b) => _templateScore(b).compareTo(_templateScore(a)));

      final best = templates.isNotEmpty ? templates.first : null;
      if (!mounted) return;
      setState(() {
        _topTemplate = best;
        _topTemplateLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _topTemplateLoading = false;
        _topTemplateError = e.toString();
        _topTemplate = null;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppRefreshBus.notifier.removeListener(_refreshListener);
    _drawerAnim.dispose();
    _homeIntroAnim.dispose();
    _wowAnim.dispose();
    _trendsTimer?.cancel();
    _trendsAutoTimer?.cancel();
    _notifTimer?.cancel();
    _trendsPageController.dispose();
    super.dispose();
  }

  String _todayYmd() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  Future<void> _loadDailyRewards() async {
    if (_dailyRewardsLoading) return;
    _dailyRewardsLoading = true;
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      if (token == null || token.trim().isEmpty) return;

      final res = await DailyRewardsService.status(token: token);
      if (!mounted) return;
      if (res['success'] != true || res['data'] is! Map) return;
      final data = Map<String, dynamic>.from(res['data'] as Map);

      final today = (data['today'] ?? _todayYmd()).toString();
      final canSpin = data['canSpin'] == true;
      final canClaim = data['canClaim'] == true;
      final canBox = data['canOpenMysteryBox'] == true;
      final streak = (data['streak'] is num) ? (data['streak'] as num).toInt() : int.tryParse((data['streak'] ?? '0').toString()) ?? 0;
      final aiCredits = (data['aiCredits'] is num) ? (data['aiCredits'] as num).toInt() : int.tryParse((data['aiCredits'] ?? '0').toString()) ?? 0;
      final walletCount = (data['walletCount'] is num) ? (data['walletCount'] as num).toInt() : int.tryParse((data['walletCount'] ?? '0').toString()) ?? 0;
      final recent = (data['recent'] is List) ? (data['recent'] as List) : const [];

      String? kind;
      int? value;
      try {
        final todaySpin = recent.firstWhere(
          (e) => e is Map && (e['ymd']?.toString() ?? '') == today && (e['source']?.toString() ?? '') == 'spin',
          orElse: () => null,
        );
        if (todaySpin is Map) {
          kind = todaySpin['kind']?.toString();
          final vRaw = todaySpin['value'];
          value = (vRaw is num) ? vRaw.toInt() : int.tryParse(vRaw?.toString() ?? '');
        }
      } catch (_) {}

      setState(() {
        _dailyRewardsYmd = today;
        _dailyRewardsCanSpin = canSpin;
        _dailyRewardsClaimed = !canSpin;
        _dailyRewardsCanClaim = canClaim;
        _dailyRewardsCanBox = canBox;
        _dailyRewardsStreak = streak;
        _dailyRewardsAiCredits = aiCredits;
        _dailyRewardsWalletCount = walletCount;
        _dailyRewardsKind = kind;
        _dailyRewardsValue = value;
      });
    } finally {
      _dailyRewardsLoading = false;
    }
  }

  Future<void> _maybeShowDailyRewardPopup() async {
    if (_dailyRewardsPopupShown) return;
    _dailyRewardsPopupShown = true;

    try {
      await _loadDailyRewards();
    } catch (_) {}

    if (!mounted) return;
    if (!_dailyRewardsCanClaim && !_dailyRewardsCanBox) return;

    final auth = context.read<AuthProvider>();
    final token = (auth.token ?? '').trim();
    if (token.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _DailyRewardPopupSheet(
          token: token,
          canClaim: _dailyRewardsCanClaim,
          canBox: _dailyRewardsCanBox,
          streak: _dailyRewardsStreak,
          walletCount: _dailyRewardsWalletCount,
          onDone: () async {
            await _loadDailyRewards();
            AppRefreshBus.bump();
          },
        );
      },
    );
  }

  Future<void> _trackDailyFlag(String key) async {
    final p = await SharedPreferences.getInstance();
    final today = _todayYmd();
    final storedDailyYmd = p.getString(_kPrefDailyYmd) ?? '';
    if (storedDailyYmd != today) {
      await p.setString(_kPrefDailyYmd, today);
      await p.setInt(_kPrefDailyXp, 0);
      await p.setInt(_kPrefDailyMarketplaceVisit, 0);
      await p.setInt(_kPrefDailyForgeAction, 0);
    }
    if ((p.getInt(key) ?? 0) == 0) {
      await p.setInt(key, 1);
      AppRefreshBus.bump();
    }
  }

  Future<void> _openDailyRewardsWheel() async {
    if (_dailyRewardsLoading) return;
    await _loadDailyRewards();
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final token = (auth.token ?? '').trim();
    if (token.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _DailyRewardsWheelSheet(
          token: token,
          alreadyClaimed: !_dailyRewardsCanSpin,
          previouslyKind: _dailyRewardsKind,
          previouslyValue: _dailyRewardsValue,
          onClaimed: (kind, value) async {
            if (!mounted) return;
            setState(() {
              _dailyRewardsClaimed = true;
              _dailyRewardsCanSpin = false;
              _dailyRewardsKind = kind;
              _dailyRewardsValue = value;
            });
            AppRefreshBus.bump();
          },
        );
      },
    );
  }

  Future<void> _loadUnreadNotifications() async {
    final token = _trendsToken;
    if (token == null || token.trim().isEmpty || _unreadNotifLoading) return;
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
      if (_unreadNotifCount != total) setState(() => _unreadNotifCount = total);
    } catch (_) {} finally { _unreadNotifLoading = false; }
  }

  Future<void> _loadTrends() async {
    final token = _trendsToken;
    if (token == null || token.isEmpty || _trendsLoading) return;
    setState(() { _trendsLoading = true; _trendsError = null; });
    try {
      final res = await AiService.listTrends(token: token);
      if (!mounted) return;
      if (res['success'] == true) {
        final data = res['data'];
        final items = data is Map ? data['items'] : null;
        final list = items is List ? items : const [];
        setState(() {
          _trendsItems = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
          _trendsIndex = _trendsItems.isEmpty ? 0 : _trendsIndex.clamp(0, _trendsItems.length - 1);
          _trendsLoading = false;
        });
        _startTrendsAutoAdvance();
        return;
      }
      setState(() { _trendsError = res['message']?.toString(); _trendsLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _trendsError = e.toString(); _trendsLoading = false; });
    }
  }

  void _startTrendsAutoAdvance() {
    _trendsAutoTimer?.cancel();
    if (_trendsItems.length <= 1) return;
    _trendsAutoTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_trendsItems.isEmpty) return;
      final next = (_trendsIndex + 1) % _trendsItems.length;
      _trendsIndex = next;
      try { _trendsPageController.animateToPage(next, duration: const Duration(milliseconds: 560), curve: Curves.easeOutCubic); }
      catch (_) { setState(() {}); }
    });
  }

  String _fallbackTrendImageUrl(int index) {
    if (_trendFallbackImages.isEmpty) return '';
    return _trendFallbackImages[index.abs() % _trendFallbackImages.length];
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'GOOD MORNING';
    if (h < 18) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  String _statFromStats(Map<String, dynamic>? stats, String key, String fallback) {
    if (stats == null) return fallback;
    final v = stats[key];
    if (v == null) return fallback;
    if (v is num) return v.toString();
    final s = v.toString();
    return s.trim().isEmpty ? fallback : s;
  }

  String _statFromStatsKeys(Map<String, dynamic>? stats, List<String> keys, String fallback) {
    if (stats == null) return fallback;
    for (final k in keys) {
      final v = stats[k];
      if (v == null) continue;
      if (v is num) return v.toString();
      final s = v.toString();
      if (s.trim().isNotEmpty) return s;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = context.watch<AuthProvider>();
    final username = auth.user?['username']?.toString() ?? 'CREATOR';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      extendBody: false,
      backgroundColor: isDark ? const Color(0xFF070914) : cs.surface,
      drawer: _buildWowDrawer(context, auth),
      floatingActionButton: _selectedIndex == 0 ? _buildAICoachFAB() : null,
      bottomNavigationBar: _selectedIndex == 3 ? null : _buildBottomNavigationBar(),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _homeIntroAnim,
              builder: (context, _) => CustomPaint(
                painter: _MeshPainter(
                  color1: AppColors.primary.withOpacity(isDark ? 0.16 : 0.12),
                  color2: AppColors.accent.withOpacity(isDark ? 0.12 : 0.10),
                  progress: _homeIntroAnim.value,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _wowAnim,
              builder: (context, _) {
                final w = _wowAnim.value;
                final dx = math.sin(w * math.pi * 2) * 120;
                final dy = math.cos(w * math.pi * 2) * 80;
                return IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF6366F1).withOpacity(isDark ? 0.18 : 0.12),
                          const Color(0xFFA855F7).withOpacity(isDark ? 0.14 : 0.08),
                          const Color(0xFFEC4899).withOpacity(isDark ? 0.08 : 0.05),
                        ],
                        stops: const [0.1, 0.5, 0.9],
                        transform: GradientTranslation(dx * 0.5),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Large soft glow 1
                        Positioned(
                          top: -100 + dy,
                          left: -100 + dx,
                          child: Container(
                            width: 400,
                            height: 400,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF6366F1).withOpacity(isDark ? 0.15 : 0.1),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Large soft glow 2
                        Positioned(
                          bottom: -150 - dy,
                          right: -100 - dx,
                          child: Container(
                            width: 500,
                            height: 500,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFFA855F7).withOpacity(isDark ? 0.12 : 0.08),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (isDark ? const Color(0xFF03040B) : cs.surface).withOpacity(0.4),
                      (isDark ? const Color(0xFF03040B) : cs.surface).withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              if (_selectedIndex != 3) _buildCustomAppBar(),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _animatedTab(0, _buildHomeView()),
                    _animatedTab(1, _buildProjectsGrid()),
                    _animatedTab(2, _buildTemplatesContent()),
                    _animatedTab(3, ArcadeFeedScreen(onBack: () => setState(() => _selectedIndex = _lastNonArcadeIndex))),
                    _animatedTab(4, _buildProfileContent()),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _animatedTab(int index, Widget child) {
    final isSelected = _selectedIndex == index;
    return IgnorePointer(
      ignoring: !isSelected,
      child: AnimatedOpacity(
        opacity: isSelected ? 1 : 0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: isSelected ? Offset.zero : const Offset(0.02, 0),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: child,
        ),
      ),
    );
  }

  Widget _buildHomeView() {
    final auth = context.watch<AuthProvider>();
    final username = auth.user?['username']?.toString() ?? 'CREATOR';
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AnimatedCard(
              duration: const Duration(milliseconds: 800),
              slideY: 30,
              child: Container(
                constraints: const BoxConstraints(minHeight: 236),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.06) : cs.outlineVariant.withOpacity(0.8),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.08),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF0F111A) : cs.surface).withOpacity(isDark ? 0.72 : 0.90),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -40,
                            top: -30,
                            child: Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFF6366F1).withOpacity(0.18),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: -50,
                            bottom: -40,
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFFA855F7).withOpacity(0.12),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: (isDark ? const Color(0xFF1E293B) : cs.primaryContainer).withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: (isDark ? const Color(0xFF6366F1) : cs.primary).withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.auto_awesome, color: isDark ? const Color(0xFF818CF8) : cs.primary, size: 13),
                                          const SizedBox(width: 8),
                                          Text(
                                            'NEURAL ENGINE v4.0',
                                            style: AppTypography.labelSmall.copyWith(
                                              color: isDark ? const Color(0xFF818CF8) : cs.primary,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.8,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFBBF24), size: 22),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  _greeting(),
                                  style: AppTypography.titleMedium.copyWith(
                                    color: isDark ? const Color(0xFF94A3B8) : cs.onSurfaceVariant.withOpacity(0.7),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2.2,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  username.toUpperCase(),
                                  style: AppTypography.displayMedium.copyWith(
                                    color: isDark ? Colors.white : cs.onSurface,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.2,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 44,
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Your next masterpiece is one prompt away.',
                                  style: AppTypography.body2.copyWith(
                                    color: isDark ? const Color(0xFF64748B) : cs.onSurfaceVariant,
                                    fontSize: 13.5,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                LayoutBuilder(
                                  builder: (context, c) {
                                    final isNarrow = c.maxWidth < 340;

                                    final primaryCta = SizedBox(
                                      height: 44,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: AppColors.primaryGradient,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary.withOpacity(0.25),
                                              blurRadius: 14,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              _trackDailyFlag(_kPrefDailyForgeAction);
                                              context.go('/create-project');
                                            },
                                            borderRadius: BorderRadius.circular(16),
                                            child: Center(
                                              child: Text(
                                                'FORGE NEW GAME',
                                                style: AppTypography.labelLarge.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.8,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );

                                    final secondaryCta = SizedBox(
                                      height: 44,
                                      child: OutlinedButton(
                                        onPressed: () => setState(() => _selectedIndex = 2),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: AppColors.primary.withOpacity(isDark ? 0.35 : 0.6), width: 1.6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          foregroundColor: isDark ? Colors.white : cs.onSurface,
                                        ),
                                        child: Text(
                                          'BROWSE TEMPLATES',
                                          style: AppTypography.labelLarge.copyWith(
                                            color: isDark ? Colors.white : cs.onSurface,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    );

                                    if (isNarrow) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          primaryCta,
                                          const SizedBox(height: 12),
                                          secondaryCta,
                                        ],
                                      );
                                    }

                                    return Row(
                                      children: [
                                        Expanded(child: primaryCta),
                                        const SizedBox(width: 12),
                                        Expanded(child: secondaryCta),
                                      ],
                                    );
                                  },
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
            ),
          ),
          const SizedBox(height: 40),
          _introEntry(
            index: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _DailyRewardsCard(
                wow: _wowAnim,
                claimed: _dailyRewardsClaimed,
                kind: _dailyRewardsKind,
                value: _dailyRewardsValue,
                onTap: _openDailyRewardsWheel,
              ),
            ),
          ),
          const SizedBox(height: 16), // Reduced further from 24 to 16 to move stats even higher
          _introEntry(
            index: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildNeoStatGrid(),
            ),
          ),
          const SizedBox(height: 16), // Reduced from 24 to 16
          _introEntry(
            index: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _coachCardDismissed
                  ? const SizedBox.shrink()
                  : _AICoachPromptCard(
                      wow: _wowAnim,
                      message: _coachTipMessage,
                      yesLabel: _coachLang == 'fr'
                          ? 'Oui'
                          : (_coachLang == 'en' ? 'Yes' : 'نعم'),
                      laterLabel: _coachLang == 'fr'
                          ? 'Plus tard'
                          : (_coachLang == 'en' ? 'Later' : 'بعد'),
                      onYes: () => context.push('/ai-coach'),
                      onLater: () {
                        setState(() => _coachCardDismissed = true);
                      },
                      onAvatarTap: () => context.push('/ai-coach'),
                    ),
            ),
          ),
          const SizedBox(height: 28),
          _introEntry(
            index: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    'Trending Games',
                    style: AppTypography.titleMedium.copyWith(
                      color: isDark ? Colors.white : cs.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedIndex = 3),
                    child: Text('SEE ALL', style: AppTypography.labelLarge.copyWith(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _introEntry(
            index: 6,
            child: SizedBox(
              height: 168,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                itemCount: _trendingLoading ? 3 : _trendingGames.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final g = _trendingLoading
                      ? const _TrendingGameData(
                          title: 'Loading…',
                          subtitle: 'Fetching feed',
                          metric: '—',
                          metricIcon: Icons.favorite_rounded,
                          imageUrl: '',
                        )
                      : _trendingGames[i];
                  return _TrendingGameCard(
                    title: g.title,
                    subtitle: g.subtitle,
                    metric: g.metric,
                    metricIcon: g.metricIcon,
                    imageUrl: g.imageUrl,
                    onTap: () => setState(() => _selectedIndex = 3),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 28),
          _introEntry(
            index: 7,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    'Top Rated Template',
                    style: AppTypography.titleMedium.copyWith(
                      color: isDark ? Colors.white : cs.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      _trackDailyFlag(_kPrefDailyMarketplaceVisit);
                      setState(() => _selectedIndex = 2);
                    },
                    child: Text('BROWSE', style: AppTypography.labelLarge.copyWith(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _introEntry(
            index: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: (_topTemplateLoading)
                  ? const _FeaturedTemplateCard(
                      title: 'Loading…',
                      subtitle: 'Finding best template',
                      badge: 'BEST PICK',
                      imageUrl: '',
                      onTap: _noop,
                    )
                  : (_topTemplate == null)
                      ? _FeaturedTemplateCard(
                          title: 'No templates yet',
                          subtitle: (_topTemplateError != null && _topTemplateError!.trim().isNotEmpty)
                              ? _topTemplateError!
                              : 'Browse the marketplace to explore templates.',
                          badge: 'BEST PICK',
                          imageUrl: '',
                          onTap: () {
                            _trackDailyFlag(_kPrefDailyMarketplaceVisit);
                            setState(() => _selectedIndex = 2);
                          },
                        )
                      : _FeaturedTemplateCard(
                          title: (_topTemplate!['name'] ?? _topTemplate!['title'] ?? 'Template').toString(),
                          subtitle: 'Top rated • ${_formatCount(_asInt(_topTemplate!['downloads']))} downloads',
                          badge: 'BEST PICK',
                          imageUrl: _resolveMediaUrl(_topTemplate!['previewImageUrl']?.toString()) ?? (_topTemplate!['previewImageUrl']?.toString() ?? ''),
                          onTap: () {
                            _trackDailyFlag(_kPrefDailyMarketplaceVisit);
                            setState(() => _selectedIndex = 2);
                          },
                        ),
            ),
          ),
          const SizedBox(height: 40),
          _introEntry(index: 2, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECENT FORGES',
                  style: AppTypography.titleLarge.copyWith(
                    color: isDark ? Colors.white : cs.onSurface,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(onPressed: () => setState(() => _selectedIndex = 1), child: Text('SEE ALL', style: AppTypography.labelLarge.copyWith(color: AppColors.primary, fontSize: 11))),
              ],
            ),
          )),
          const SizedBox(height: 16),
          _introEntry(
            index: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _recentFilterChip('All'),
                    const SizedBox(width: 10),
                    _recentFilterChip('Ready'),
                    const SizedBox(width: 10),
                    _recentFilterChip('Queued'),
                    const SizedBox(width: 10),
                    _recentFilterChip('Failed'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _introEntry(index: 3, child: _buildRecentProjectsList()),
          const SizedBox(height: 40),
          _introEntry(index: 5, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text('AI Games Trends', style: AppTypography.titleMedium),
                const Spacer(),
                IconButton(onPressed: _trendsLoading ? null : _loadTrends, icon: Icon(Icons.refresh_rounded, color: cs.onSurfaceVariant)),
              ],
            ),
          )),
          const SizedBox(height: 16),
          if (_trendsLoading)
            _introEntry(
              index: 6,
              child: _trendsSkeleton(),
            )
          else if (_trendsError != null && _trendsError!.trim().isNotEmpty)
            _introEntry(
              index: 6,
              child: SizedBox(
                height: 206,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Could not load trends',
                          style: AppTypography.titleMedium.copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _trendsError!,
                          style: AppTypography.body2.copyWith(color: Colors.white70),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _loadTrends,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else if (_trendsItems.isNotEmpty)
            _introEntry(
              index: 6,
              child: SizedBox(
                height: 226,
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _trendsPageController,
                        onPageChanged: (i) => setState(() => _trendsIndex = i),
                        itemCount: _trendsItems.length,
                        itemBuilder: (context, i) {
                          final it = _trendsItems[i];
                          final bgUrl = (it['imageUrl']?.toString() ?? '').isNotEmpty
                              ? it['imageUrl']
                              : _fallbackTrendImageUrl(i);
                          final subtitle = (it['source'] ?? it['timeframe'] ?? it['category'] ?? 'Trending now').toString();
                          final url = it['url']?.toString();
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    bgUrl.toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              AppColors.primary.withOpacity(0.16),
                                              AppColors.accent.withOpacity(0.10),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.82),
                                        ],
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          it['title']?.toString() ?? 'Article',
                                          style: AppTypography.titleMedium.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                subtitle,
                                                style: AppTypography.body2.copyWith(
                                                  color: Colors.white.withOpacity(0.75),
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (url != null && url.trim().isNotEmpty)
                                              TextButton(
                                                onPressed: () async {
                                                  final u = Uri.tryParse(url);
                                                  if (u == null) return;
                                                  await launchUrl(u, mode: LaunchMode.externalApplication);
                                                },
                                                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                                                child: Text(
                                                  'OPEN',
                                                  style: AppTypography.labelLarge.copyWith(
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.8,
                                                    fontSize: 11,
                                                  ),
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
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _trendsItems.length.clamp(0, 8),
                        (idx) {
                          final active = idx == _trendsIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 18 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: active ? AppColors.primaryGradient : null,
                              color: active ? null : Colors.white24,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _introEntry(
              index: 6,
              child: SizedBox(
                height: 206,
                child: Center(
                  child: Text(
                    'No trends available right now',
                    style: AppTypography.body2.copyWith(color: Colors.white70),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 40),
          _introEntry(index: 7, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text('Quick Actions', style: AppTypography.titleMedium))),
          const SizedBox(height: 16),
          _introEntry(index: 8, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _buildQuickActionButton('Create\nNew Game', Icons.add, AppColors.primaryGradient, () => context.go('/create-project'))),
                const SizedBox(width: 16),
                Expanded(child: _buildQuickActionButton('Browse\nTemplates', Icons.grid_view, null, () { _trackDailyFlag(_kPrefDailyMarketplaceVisit); setState(() => _selectedIndex = 2); }, isOutlined: true)),
              ],
            ),
          )),
          const SizedBox(height: 16),
          _introEntry(index: 9, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _buildQuickActionButton('Claude\nAI Game', Icons.auto_awesome, const LinearGradient(colors: [Color(0xFF6A5CFF), Color(0xFFAA44FF)]), () => context.go('/ai-claude-game'))),
                const SizedBox(width: 16),
                Expanded(child: _buildQuickActionButton('Phaser\nInstant Game', Icons.bolt, const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6A5CFF)]), () => context.go('/ai-phaser-game'))),
              ],
            ),
          )),
          const SizedBox(height: 16),
          _introEntry(index: 10, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _buildQuickActionButton('3D Game 🎲', Icons.view_in_ar_rounded, const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6A5CFF)]), () => context.go('/ai-threejs-game'))),
              ],
            ),
          )),
          const SizedBox(height: 16),
          _introEntry(index: 11, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _buildQuickActionButton('Quiz\nChallenge', Icons.quiz_rounded, null, () => context.go('/game-quiz'), isOutlined: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildQuickActionButton('Multiplayer\nLobby', Icons.groups_rounded, AppColors.primaryGradient, () => context.go('/multiplayer'))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildNeoStatGrid() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data?['data'];

        String projects = '0';
        String templates = '0';
        String downloads = '0';
        String generations = '0';

        if (stats is Map) {
          projects = (stats['projectsCount'] ?? stats['projects'] ?? _cachedProjectsCount ?? 0).toString();
          templates = (stats['templatesCount'] ?? stats['templates'] ?? 0).toString();
          downloads = (stats['downloadsCount'] ?? stats['downloads'] ?? _cachedDownloadsCount ?? 0).toString();
          generations = (stats['generationsCount'] ?? stats['generations'] ?? _cachedGenerationsCount ?? 0).toString();

          if (snapshot.hasData) {
            _cachedProjectsCount = int.tryParse(projects);
            _cachedDownloadsCount = int.tryParse(downloads);
            _cachedGenerationsCount = int.tryParse(generations);
          }
        } else {
          projects = (_cachedProjectsCount ?? 0).toString();
          downloads = (_cachedDownloadsCount ?? 0).toString();
          generations = (_cachedGenerationsCount ?? 0).toString();
        }

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 24,
          crossAxisSpacing: 24,
          childAspectRatio: 1.05,
          children: [
            _build3DStatCard('PROJECTS', projects, Icons.rocket_launch_rounded, AppColors.primary, 0, isDark, cs),
            _build3DStatCard('TEMPLATES', templates, Icons.grid_view_rounded, AppColors.success, 1, isDark, cs),
            _build3DStatCard('DOWNLOADS', downloads, Icons.file_download_rounded, cs.tertiary, 2, isDark, cs),
            _build3DStatCard('GENERATIONS', generations, Icons.auto_awesome_rounded, AppColors.accent, 3, isDark, cs),
          ],
        );
      },
    );
  }

  Widget _build3DStatCard(String label, String value, IconData icon, Color color, int index, bool isDark, ColorScheme cs) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800 + (index * 150)),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.elasticOut,
      builder: (context, anim, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * anim),
          child: Opacity(
            opacity: anim.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B2E) : color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.05) : color.withOpacity(0.15),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(isDark ? 0.2 : 0.12),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: Stack(
                  children: [
                    Positioned(
                      right: -15,
                      top: -15,
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(seconds: 3),
                        tween: Tween(begin: 0, end: 1),
                        builder: (context, v, _) {
                          return Transform.rotate(
                            angle: v * 2 * math.pi,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    color.withOpacity(0.15),
                                    Colors.transparent,
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(22.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(icon, color: color, size: 28),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TweenAnimationBuilder<int>(
                                duration: const Duration(milliseconds: 1500),
                                tween: IntTween(begin: 0, end: int.tryParse(value) ?? 0),
                                builder: (context, val, _) {
                                  return Text(
                                    val.toString(),
                                    style: AppTypography.displaySmall.copyWith(
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 34,
                                      height: 1,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 6),
                              Text(
                                label,
                                style: AppTypography.caption.copyWith(
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  fontSize: 11,
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
      },
    );
  }

  Widget _buildNeoStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color tint,
    required int index,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedCard(
      delay: Duration(milliseconds: 320 + (index * 90)),
      duration: const Duration(milliseconds: 780),
      slideY: 36,
      child: Container(
        height: 132,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: tint.withOpacity(0.12),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tint.withOpacity(0.14),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: tint.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: tint.withOpacity(0.22)),
                        ),
                        child: Icon(icon, color: tint, size: 20),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withOpacity(0.10)),
                        ),
                        child: Text(
                          '+0.0%',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: AppTypography.displayLarge.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: tint,
                      letterSpacing: -0.8,
                      height: 1.05,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: AppTypography.body2.copyWith(
                      color: Colors.white60,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Gradient? gradient, VoidCallback onTap, {bool isOutlined = false}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? (isOutlined ? Colors.transparent : cs.surface) : null,
        borderRadius: BorderRadius.circular(24),
        border: isOutlined ? Border.all(color: AppColors.primary.withOpacity(0.3), width: 2) : null,
        boxShadow: !isOutlined ? [BoxShadow(color: (gradient != null ? AppColors.primary : Colors.black).withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 6))] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: isOutlined ? AppColors.primary : Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: AppTypography.labelSmall.copyWith(color: isOutlined ? AppColors.primary : Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
          ]),
        ),
      ),
    );
  }

  Widget _buildRecentProjects() => _buildRecentProjectsList();
  Widget _buildTemplatesContent() => const TemplateMarketplaceScreen();
  Widget _buildProfileContent() => const UserProfileScreen(showAppBar: false);

  Widget _buildRecentProjectsList() {
    return FutureBuilder<List<dynamic>>(
      future: _projectsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _recentProjectsSkeleton();
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load projects',
                    style: AppTypography.titleMedium.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: AppTypography.body2.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      final token = _projectsToken;
                      if (token == null || token.trim().isEmpty) return;
                      setState(() {
                        _projectsFuture = ProjectsService.listProjects(token: token).then((res) {
                          if (res['success'] != true) {
                            throw Exception(res['message']?.toString() ?? 'Failed to load projects');
                          }
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
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('No projects yet', style: AppTypography.titleMedium.copyWith(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first forge to see it here.',
                    style: AppTypography.body2.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.go('/create-project'),
                    child: const Text('Create Project'),
                  ),
                ],
              ),
            ),
          );
        }

        final filtered = _recentForgesFilter == 'All'
            ? items
            : items.where((e) {
                if (e is! Map) return false;
                final st = (e['status'] ?? '').toString().toLowerCase();
                return st == _recentForgesFilter.toLowerCase();
              }).toList();

        // Keep dashboard "Recent Forges" lean.
        final limited = filtered.length > 5 ? filtered.sublist(0, 5) : filtered;
        return SizedBox(
          height: 285,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: limited.length,
            itemBuilder: (context, i) {
              final p = Map<String, dynamic>.from(limited[i]);
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 16),
                child: ProjectCard(
                  title: p['name'] ?? p['title'] ?? 'Untitled',
                  description: p['description'],
                  thumbnailUrl: p['previewImageUrl'] ??
                      p['thumbnailUrl'] ??
                      p['iconUrl'] ??
                      p['imageUrl'] ??
                      p['previewImage'] ??
                      p['image'] ??
                      (p['media'] is Map ? (p['media'] as Map)['previewImage'] : null) ??
                      (p['media'] is Map ? (p['media'] as Map)['thumbnailUrl'] : null),
                  status: p['status'] ?? 'unknown',
                  lastModified: DateTime.tryParse(p['updatedAt'] ?? '') ?? DateTime.now(),
                  onTap: () => context.go('/project-detail', extra: {'projectId': p['_id'], 'project': p}),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProjectsGrid() {
    return FutureBuilder<List<dynamic>>(
      future: _projectsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                snapshot.error.toString(),
                style: AppTypography.body2.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('No projects yet', style: AppTypography.titleMedium.copyWith(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first forge to see it here.',
                    style: AppTypography.body2.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.go('/create-project'),
                    child: const Text('Create Project'),
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.72,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final p = Map<String, dynamic>.from(items[i]);
            return ProjectCard(
              title: p['name'] ?? p['title'] ?? 'Untitled',
              description: p['description'],
              thumbnailUrl: p['previewImageUrl'] ??
                  p['thumbnailUrl'] ??
                  p['iconUrl'] ??
                  p['imageUrl'] ??
                  p['previewImage'] ??
                  p['image'] ??
                  (p['media'] is Map ? (p['media'] as Map)['previewImage'] : null) ??
                  (p['media'] is Map ? (p['media'] as Map)['thumbnailUrl'] : null),
              status: p['status'] ?? 'unknown',
              lastModified: DateTime.tryParse(p['updatedAt'] ?? '') ?? DateTime.now(),
              onTap: () => context.go('/project-detail', extra: {'projectId': p['_id'], 'project': p}),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.black).withOpacity(isDark ? 0.5 : 0.10),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF0D0E14) : cs.surface).withOpacity(isDark ? 0.85 : 0.90),
                  border: Border(
                    top: BorderSide(
                      color: (isDark ? Colors.white.withOpacity(0.12) : cs.outlineVariant.withOpacity(0.9)),
                      width: 1.2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildNavItem(0, Icons.home_rounded, 'HOME'),
                    _buildNavItem(1, Icons.rocket_launch_rounded, 'FORGE'),
                    _buildNavItem(2, Icons.layers_rounded, 'TEMPLATES'),
                    _buildNavItem(3, Icons.sports_esports_rounded, 'ARCADE'),
                    _buildNavItem(4, Icons.person_rounded, 'PROFILE'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final unselected = isDark ? Colors.white38 : cs.onSurfaceVariant.withOpacity(0.70);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedIndex = index;
          if (index != 3) _lastNonArcadeIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : unselected,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: isSelected ? AppColors.primary : unselected,
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAICoachFAB() {
    return AnimatedBuilder(
      animation: _wowAnim,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3 + 0.1 * _wowAnim.value),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.85), const Color(0xFFA855F7).withOpacity(0.85)],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1.2,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final coach = context.read<CoachOverlayController>();
                      if (coach.overlayEnabled) {
                        coach.hideOverlay();
                      } else {
                        coach.showOverlay();
                      }
                    },
                    onLongPress: () {
                      HapticFeedback.heavyImpact();
                      context.push('/ai-coach');
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'AI Coach',
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
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
      },
    );
  }

  Widget _recentFilterChip(String label) {
    final selected = _recentForgesFilter == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => setState(() => _recentForgesFilter = label),
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.primary.withOpacity(0.16) : AppColors.primary.withOpacity(0.12))
              : (isDark ? Colors.black.withOpacity(0.18) : cs.surfaceVariant),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.primary.withOpacity(isDark ? 0.35 : 0.28)
                : (isDark ? Colors.white.withOpacity(0.10) : cs.outlineVariant.withOpacity(0.9)),
            width: 1.2,
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.labelSmall.copyWith(
            color: selected
                ? (isDark ? Colors.white : AppColors.primary)
                : (isDark ? Colors.white60 : cs.onSurfaceVariant),
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            fontSize: 9,
          ),
        ),
      ),
    );
  }

  Widget _skeletonBlock({
    required double height,
    BorderRadius? radius,
  }) {
    return AnimatedBuilder(
      animation: _wowAnim,
      builder: (context, _) {
        final t = _wowAnim.value;
        final shimmer = 0.35 + 0.35 * ((math.sin(t * math.pi * 2) + 1) / 2);
        return Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: radius ?? BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.06 + shimmer * 0.05),
                Colors.white.withOpacity(0.02 + shimmer * 0.03),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _recentProjectsSkeleton() {
    return SizedBox(
      height: 285,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          return SizedBox(
            width: 200,
            child: Column(
              children: [
                _skeletonBlock(
                  height: 160,
                  radius: BorderRadius.circular(32),
                ),
                const SizedBox(height: 12),
                _skeletonBlock(
                  height: 18,
                  radius: BorderRadius.circular(999),
                ),
                const SizedBox(height: 10),
                _skeletonBlock(
                  height: 14,
                  radius: BorderRadius.circular(999),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _trendsSkeleton() {
    return SizedBox(
      height: 206,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _skeletonBlock(
          height: 206,
          radius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  Widget _buildWowDrawer(BuildContext context, AuthProvider auth) {
    final cs = Theme.of(context).colorScheme;
    return Drawer(
      backgroundColor: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: cs.surface.withOpacity(0.8),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                CircleAvatar(radius: 40, backgroundImage: (auth.user?['avatar']?.toString() ?? '').isNotEmpty ? NetworkImage(auth.user!['avatar']) : null),
                const SizedBox(height: 12),
                Text(auth.user?['username'] ?? 'User', style: AppTypography.titleLarge),
                const Divider(),
                ListTile(leading: const Icon(Icons.person_outline), title: const Text('Profile'), onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 4); }),
                ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Settings'), onTap: () => context.push('/settings')),
                if (auth.isAdmin || auth.isDevl) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.widgets_outlined),
                    title: const Text('Add Assets'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/assets');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.cloud_upload_outlined),
                    title: const Text('Add Template'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/templates/upload');
                    },
                  ),
                ],
                const Spacer(),
                ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Logout', style: TextStyle(color: Colors.red)), onTap: () => auth.logout(context: context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarActions(ColorScheme cs) {
    return Consumer2<BuildMonitorProvider, AuthProvider>(builder: (context, bm, auth, _) {
      final inProgress = bm.isMonitoring && (bm.status == 'queued' || bm.status == 'running');
      final avatarUrl = auth.user?['avatar']?.toString();

      Widget notifButton() {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => context.go(
                inProgress ? '/build-progress' : '/notifications',
                extra: inProgress ? {'projectId': bm.projectId} : null,
              ),
              icon: Icon(
                inProgress ? Icons.build_circle_outlined : Icons.notifications_none_rounded,
                color: inProgress ? cs.primary : cs.onSurface,
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
                      child: Transform.scale(scale: scale, child: child),
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
              )
            else if (_unreadNotifCount > 0)
              Positioned(
                top: 8,
                right: 10,
                child: AnimatedBuilder(
                  animation: _wowAnim,
                  builder: (context, child) {
                    final w = _wowAnim.value;
                    final pulse = (math.sin(w * math.pi * 2) + 1) / 2; // 0..1
                    final scale = 0.92 + pulse * 0.18;
                    final opacity = 0.65 + pulse * 0.35;
                    return Opacity(
                      opacity: opacity,
                      child: Transform.scale(scale: scale, child: child),
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
                          color: Colors.redAccent.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              _trackDailyFlag(_kPrefDailyForgeAction);
              context.go('/create-project');
            },
            icon: Icon(Icons.add_circle_outline_rounded, color: cs.onSurface),
            tooltip: 'Forge new game',
          ),
          notifButton(),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => setState(() => _selectedIndex = 4),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [cs.primary.withOpacity(0.65), cs.secondary.withOpacity(0.55)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withOpacity(0.22)),
              ),
              child: ClipOval(
                child: (avatarUrl != null && avatarUrl.trim().isNotEmpty)
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.person_rounded, color: cs.onSurface);
                        },
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Icon(Icons.person_rounded, color: cs.onSurface);
                        },
                      )
                    : Icon(Icons.person_rounded, color: cs.onSurface),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildCustomAppBar() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(isDark ? 0.46 : 0.70),
              border: Border(bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.35))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: Icon(Icons.menu_rounded, color: cs.onSurface),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          cs.primary.withOpacity(0.24),
                          cs.secondary.withOpacity(0.18),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Text(
                      'GameForge AI',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildAppBarActions(cs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _introEntry({required int index, required Widget child}) {
    final start = (0.06 * index).clamp(0.0, 0.70);
    final curve = CurvedAnimation(parent: _homeIntroAnim, curve: Interval(start, 1.0, curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: curve,
      child: child,
      builder: (context, c) {
        final v = curve.value;
        return Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: c));
      },
    );
  }
}

class _DailyRewardsCard extends StatelessWidget {
  final AnimationController wow;
  final bool claimed;
  final String? kind;
  final int? value;
  final VoidCallback onTap;

  const _DailyRewardsCard({
    required this.wow,
    required this.claimed,
    required this.kind,
    required this.value,
    required this.onTap,
  });

  String _label() {
    if (!claimed) return 'Spin the wheel. Claim your daily reward.';
    if (kind == null || value == null) return 'Daily reward claimed.';
    if (kind == 'xp') return '+$value XP added to today.';
    if (kind == 'ai_credits' || kind == 'coins') return '+$value AI Credits added.';
    if (kind == 'discount_templates' || kind == 'coupon') return '$value% off 1 template unlocked.';
    if (kind == 'discount_subscription') return '$value% off subscription unlocked.';
    return 'Daily reward claimed.';
  }

  String _title() {
    if (!claimed) return 'DAILY REWARDS WHEEL';
    return 'REWARD CLAIMED';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: wow,
        builder: (context, _) {
          final t = wow.value;
          final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : cs.outlineVariant.withOpacity(0.8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(isDark ? (0.22 + 0.08 * pulse) : 0.1),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                        ? [
                            Colors.white.withOpacity(0.10),
                            Colors.white.withOpacity(0.03),
                          ]
                        : [
                            cs.surface,
                            cs.surface.withOpacity(0.9),
                          ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -40,
                        top: -60,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.accent.withOpacity(isDark ? (0.22 + 0.08 * pulse) : 0.12),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: AppColors.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.28 + 0.06 * pulse),
                                  blurRadius: 18,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Transform.rotate(
                              angle: 0.10 * math.sin(t * 2 * math.pi),
                              child: const Icon(Icons.casino_rounded, color: Colors.white, size: 34),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _title(),
                                  style: AppTypography.labelSmall.copyWith(
                                    color: isDark ? Colors.white : cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _label(),
                                  style: AppTypography.subtitle2.copyWith(
                                    color: isDark ? Colors.white : cs.onSurface,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: (isDark ? Colors.black : cs.primaryContainer).withOpacity(isDark ? 0.26 : 0.4),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: isDark ? Colors.white.withOpacity(0.10) : cs.primary.withOpacity(0.2),
                                        ),
                                      ),
                                      child: Text(
                                        claimed ? 'Come back tomorrow' : 'Tap to spin',
                                        style: AppTypography.labelSmall.copyWith(
                                          color: isDark ? Colors.white70 : cs.primary,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    if (claimed) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DailyRewardsWheelSheet extends StatefulWidget {
  final String token;
  final bool alreadyClaimed;
  final String? previouslyKind;
  final int? previouslyValue;
  final Future<void> Function(String kind, int value) onClaimed;

  const _DailyRewardsWheelSheet({
    required this.token,
    required this.alreadyClaimed,
    required this.previouslyKind,
    required this.previouslyValue,
    required this.onClaimed,
  });

  @override
  State<_DailyRewardsWheelSheet> createState() => _DailyRewardsWheelSheetState();
}

class _DailyRewardsWheelSheetState extends State<_DailyRewardsWheelSheet> with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _punchCtrl;
  bool _spinning = false;
  bool _claimed = false;
  double _spinTarget = 0;
  String? _kind;
  int? _value;

  bool _confetti = false;

  Future<void> _showDiscountCtaIfNeeded() async {
    final kind = _kind;
    final value = _value;
    if (kind == null || value == null) return;

    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}

    await RewardSfxService.playWin();

    String? title;
    String? subtitle;
    String? btn;
    VoidCallback? onTap;

    if (kind == 'discount_templates' || kind == 'coupon') {
      title = '$value% OFF Template';
      subtitle = 'Tap to use it now in the marketplace.';
      btn = 'USE NOW';
      onTap = () {
        Navigator.of(context).pop();
        context.go('/marketplace?autofinder=1');
      };
    } else if (kind == 'discount_subscription') {
      title = '$value% OFF Subscription';
      subtitle = 'Tap to use it now on the subscription screen.';
      btn = 'UPGRADE NOW';
      onTap = () {
        Navigator.of(context).pop();
        context.go('/subscription?autostart=1');
      };
    }

    if (title == null || subtitle == null || btn == null || onTap == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
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
                          painter: _CoinBurstPainter(progress: (t * 0.9).clamp(0.0, 1.0)),
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
              border: Border.all(color: Colors.white.withOpacity(0.10), width: 1.2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.60), blurRadius: 44, offset: const Offset(0, 26))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  color: const Color(0xFF0B1020).withOpacity(0.90),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text('DISCOUNT UNLOCKED', style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                          const Spacer(),
                          IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close_rounded, color: Colors.white70)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              cs.primary.withOpacity(0.18),
                              AppColors.accent.withOpacity(0.10),
                            ],
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('You won', style: AppTypography.labelLarge.copyWith(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                            const SizedBox(height: 8),
                            Text(title!, style: AppTypography.titleLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Text(subtitle!, style: AppTypography.body2.copyWith(color: Colors.white70, height: 1.25)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: BorderSide(color: Colors.white.withOpacity(0.14)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                                child: Text('LATER', style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: onTap,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  elevation: 0,
                                ),
                                child: Text(btn!, style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                              ),
                            ),
                          ),
                        ],
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
  }

  static final List<_RewardSlice> _slices = [
    _RewardSlice(kind: 'xp', value: 25, colorA: Color(0xFF6366F1), colorB: Color(0xFF22D3EE), label: '+25 XP'),
    _RewardSlice(kind: 'ai_credits', value: 20, colorA: Color(0xFF22C55E), colorB: Color(0xFF10B981), label: '+20 Credits'),
    _RewardSlice(kind: 'xp', value: 50, colorA: Color(0xFFA855F7), colorB: Color(0xFF6366F1), label: '+50 XP'),
    _RewardSlice(kind: 'discount_templates', value: 20, colorA: Color(0xFFF97316), colorB: Color(0xFFEF4444), label: '20% OFF'),
    _RewardSlice(kind: 'ai_credits', value: 50, colorA: Color(0xFF22D3EE), colorB: Color(0xFF6366F1), label: '+50 Credits'),
    _RewardSlice(kind: 'xp', value: 25, colorA: Color(0xFF10B981), colorB: Color(0xFF22C55E), label: '+25 XP'),
    _RewardSlice(kind: 'discount_subscription', value: 35, colorA: Color(0xFFEF4444), colorB: Color(0xFFA855F7), label: '35% OFF'),
    _RewardSlice(kind: 'ai_credits', value: 200, colorA: Color(0xFF8B5CF6), colorB: Color(0xFF6366F1), label: '+200 Credits'),
  ];

  @override
  void initState() {
    super.initState();
    _claimed = widget.alreadyClaimed;
    _spinCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
    _punchCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    if (widget.alreadyClaimed) {
      _kind = widget.previouslyKind;
      _value = widget.previouslyValue;
    }
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _glowCtrl.dispose();
    _punchCtrl.dispose();
    super.dispose();
  }

  bool _isBigWin(String kind, int value) {
    if (kind == 'discount_templates' || kind == 'discount_subscription' || kind == 'coupon') return true;
    if (kind == 'ai_credits' || kind == 'coins') return value >= 50;
    if (kind == 'xp') return value >= 50;
    return false;
  }

  Future<void> _playSfx(String kind) async {
    if (kind == 'ai_credits' || kind == 'coins' || kind == 'xp') {
      await RewardSfxService.playCoins();
      return;
    }
    await RewardSfxService.playWin();
  }

  void _burstConfetti() {
    if (!mounted) return;
    setState(() => _confetti = true);
    Future<void>.delayed(const Duration(milliseconds: 1250), () {
      if (!mounted) return;
      setState(() => _confetti = false);
    });
  }

  Future<void> _spin() async {
    if (_spinning || _claimed) return;
    setState(() => _spinning = true);

    Map<String, dynamic> res;
    try {
      res = await DailyRewardsService.spin(token: widget.token);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _spinning = false;
      });
      AppNotifier.showError(e.toString());
      return;
    }

    if (!mounted) return;
    if (res['success'] != true || res['data'] is! Map) {
      setState(() {
        _spinning = false;
      });
      AppNotifier.showError(res['message']?.toString() ?? 'Spin failed');
      return;
    }

    final data = Map<String, dynamic>.from(res['data'] as Map);
    final rewardRaw = data['reward'];
    final reward = rewardRaw is Map ? Map<String, dynamic>.from(rewardRaw) : <String, dynamic>{};
    final kind = (reward['kind'] ?? '').toString();
    final vRaw = reward['value'];
    final value = (vRaw is num) ? vRaw.toInt() : int.tryParse(vRaw?.toString() ?? '');
    if (kind.isEmpty || value == null) {
      setState(() {
        _spinning = false;
      });
      AppNotifier.showError('Invalid spin reward');
      return;
    }

    final chosen = _slices.firstWhere(
      (s) => s.kind == kind && s.value == value,
      orElse: () => _slices.first,
    );

    final rng = math.Random();
    final sliceAngle = (2 * math.pi) / _slices.length;
    final idx = _slices.indexOf(chosen);
    final targetAngle = (idx * sliceAngle) + (sliceAngle * 0.5);
    final extraTurns = 5 + rng.nextInt(4);
    _spinTarget = (2 * math.pi * extraTurns) + (2 * math.pi - targetAngle);

    _spinCtrl.value = 0;
    await _spinCtrl.animateTo(
      1,
      duration: const Duration(milliseconds: 2600),
      curve: Curves.easeOutCubic,
    );

    setState(() {
      _kind = chosen.kind;
      _value = chosen.value;
      _spinning = false;
      _claimed = true;
    });

    _punchCtrl.forward(from: 0);
    await _playSfx(chosen.kind);
    if (_isBigWin(chosen.kind, chosen.value)) {
      _burstConfetti();
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}
    }

    await _showDiscountCtaIfNeeded();

    try {
      await widget.onClaimed(chosen.kind, chosen.value);
    } catch (_) {}
  }

  _RewardSlice _weightedPick(math.Random rng) {
    final pool = <_RewardSlice>[];
    for (final s in _slices) {
      int w = 2;
      if (s.kind == 'xp') {
        if (s.value >= 120) w = 1;
        else if (s.value >= 60) w = 2;
        else w = 3;
      } else if (s.kind == 'coupon') {
        if (s.value >= 35) w = 1;
        else w = 2;
      } else {
        if (s.value >= 120) w = 1;
        else w = 2;
      }
      for (int i = 0; i < w; i++) {
        pool.add(s);
      }
    }
    return pool[rng.nextInt(pool.length)];
  }

  String _resultLine() {
    if (_kind == null || _value == null) return 'Spin to reveal your reward.';
    if (_kind == 'xp') return '+$_value XP added to today';
    if (_kind == 'ai_credits' || _kind == 'coins') return '+$_value AI Credits unlocked';
    if (_kind == 'discount_templates' || _kind == 'coupon') return '$_value% off 1 template';
    if (_kind == 'discount_subscription') return '$_value% off subscription';
    return 'Reward claimed';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return RewardConfettiOverlay(
      play: _confetti,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.10) : cs.outlineVariant.withOpacity(0.5), width: 1.2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.55 : 0.15), blurRadius: 40, offset: const Offset(0, 24))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF0B1020) : cs.surface).withOpacity(0.86),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Row(
                    children: [
                      Text(
                        'DAILY REWARDS',
                        style: AppTypography.titleMedium.copyWith(
                          color: isDark ? Colors.white : cs.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: Listenable.merge([_spinCtrl, _glowCtrl, _punchCtrl]),
                    builder: (context, _) {
                      final t = Curves.easeOutCubic.transform(_spinCtrl.value);
                      final glow = 0.5 + 0.5 * math.sin(_glowCtrl.value * 2 * math.pi);
                      final rotation = (_spinTarget * t) + (2 * math.pi * _glowCtrl.value * 0.03);
                      final punch = Curves.elasticOut.transform(_punchCtrl.value);
                      final punchScale = 1.0 + (_claimed ? 0.06 * (1 - (punch - 1).abs()) : 0);
                      final tilt = 0.08 * math.sin(t * math.pi);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateX(-tilt)
                              ..rotateY(tilt * 0.7)
                              ..scale(punchScale),
                            child: Container(
                              width: 310,
                              height: 310,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.18 + 0.10 * glow),
                                    blurRadius: 40,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Transform.rotate(
                                angle: rotation,
                                child: CustomPaint(
                                  painter: _WheelPainter(slices: _slices, glow: glow),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            child: Icon(Icons.navigation_rounded, color: isDark ? Colors.white.withOpacity(0.85) : cs.onSurface.withOpacity(0.85), size: 38),
                          ),
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.28 + 0.08 * glow),
                                  blurRadius: 22,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                              border: Border.all(color: Colors.white.withOpacity(0.14), width: 1.2),
                            ),
                            child: const Center(
                              child: Icon(Icons.star_rounded, color: Colors.white, size: 44),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _claimed ? 1 : 0),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    builder: (context, t, child) {
                      return Transform.scale(
                        scale: 1.0 + 0.04 * t,
                        child: Opacity(opacity: (0.35 + 0.65 * t).clamp(0.0, 1.0), child: child),
                      );
                    },
                    child: Text(
                      _resultLine(),
                      style: AppTypography.subtitle2.copyWith(
                        color: isDark ? Colors.white : cs.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _claimed ? null : AppColors.primaryGradient,
                        color: _claimed ? (isDark ? Colors.white10 : cs.surfaceContainerHighest) : null,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isDark ? Colors.white.withOpacity(0.10) : cs.outlineVariant.withOpacity(0.3)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _claimed ? null : _spin,
                          borderRadius: BorderRadius.circular(18),
                          child: Center(
                            child: Text(
                              _claimed ? 'COME BACK TOMORROW' : (_spinning ? 'SPINNING…' : 'SPIN NOW'),
                              style: AppTypography.labelLarge.copyWith(
                                color: _claimed ? (isDark ? Colors.white24 : cs.onSurfaceVariant.withOpacity(0.5)) : Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                                fontSize: 11,
                              ),
                            ),
                          ),
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
      ),
    );
  }
}

class _RewardSlice {
  final String kind;
  final int value;
  final Color colorA;
  final Color colorB;
  final String label;

  const _RewardSlice({
    required this.kind,
    required this.value,
    required this.colorA,
    required this.colorB,
    required this.label,
  });
}

class _WheelPainter extends CustomPainter {
  final List<_RewardSlice> slices;
  final double glow;

  _WheelPainter({required this.slices, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;
    final arc = (2 * math.pi) / slices.length;

    for (int i = 0; i < slices.length; i++) {
      final s = slices[i];
      final start = (-math.pi / 2) + (i * arc);
      final rect = Rect.fromCircle(center: c, radius: r);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [s.colorA.withOpacity(0.92), s.colorB.withOpacity(0.92)],
        ).createShader(rect);
      canvas.drawArc(rect, start, arc, true, paint);

      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withOpacity(0.12 + 0.06 * glow);
      canvas.drawArc(rect, start, arc, true, border);

      final textPainter = TextPainter(
        text: TextSpan(
          text: s.label,
          style: AppTypography.labelLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: r * 0.9);

      final angle = start + arc * 0.5;
      final pos = Offset(
        c.dx + (r * 0.62) * math.cos(angle),
        c.dy + (r * 0.62) * math.sin(angle),
      );

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle + math.pi / 2);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..shader = LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.28 + 0.08 * glow),
          AppColors.accent.withValues(alpha: 0.22 + 0.08 * glow),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r - 4, ring);

    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.black.withOpacity(0.45);
    canvas.drawCircle(c, r - 14, inner);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.glow != glow || oldDelegate.slices.length != slices.length;
  }
}

class _SparkleTrailPainter extends CustomPainter {
  final double spinT;
  final double glow;
  final bool active;

  _SparkleTrailPainter({required this.spinT, required this.glow, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;
    final rr = r - 6;

    final base = 0.25 + 0.55 * glow;
    final p1 = Paint()
      ..color = AppColors.accent.withOpacity(0.22 * base)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final p2 = Paint()
      ..color = AppColors.primary.withOpacity(0.26 * base)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    for (var i = 0; i < 22; i++) {
      final a0 = (i / 22.0) * math.pi * 2;
      final phase = (spinT * 2.2 + i * 0.13) % 1.0;
      final a = a0 + phase * math.pi * 2;
      final amp = 0.7 + 0.6 * math.sin((spinT * math.pi * 2) + i);
      final rad = rr + 5 * amp;
      final pos = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
      final s = 1.4 + 2.0 * amp;
      canvas.drawCircle(pos, s, (i.isEven ? p1 : p2));
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleTrailPainter oldDelegate) {
    return oldDelegate.spinT != spinT || oldDelegate.glow != glow || oldDelegate.active != active;
  }
}
