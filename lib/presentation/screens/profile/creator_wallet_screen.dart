import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/services/creator_monetization_service.dart';
import '../../../core/themes/app_theme.dart';
import '../../widgets/widgets.dart';

class CreatorWalletScreen extends StatefulWidget {
  const CreatorWalletScreen({super.key});

  @override
  State<CreatorWalletScreen> createState() => _CreatorWalletScreenState();
}

class _CreatorWalletScreenState extends State<CreatorWalletScreen> with SingleTickerProviderStateMixin {
  late AnimationController _cardAnimationController;
  late Animation<double> _cardScale;
  late Animation<double> _cardRotation;
  late Animation<double> _cardGlowOpacity;
  late Animation<Offset> _listSlideAnimation;
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? _wallet;
  List<Map<String, dynamic>> _tx = const [];
  String? _cursor;
  bool _paging = false;

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final w = await CreatorMonetizationService.wallet(token: token);
      final t = await CreatorMonetizationService.transactions(token: token, limit: 20);
      if (!mounted) return;

      setState(() {
        _wallet = (w['data'] is Map) ? Map<String, dynamic>.from(w['data'] as Map) : null;
        final data = t['data'];
        final list = (data is List) ? data : const [];
        _tx = list.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
        _cursor = t['nextCursor']?.toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_paging) return;
    if (_cursor == null || _cursor!.trim().isEmpty) return;

    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    setState(() => _paging = true);
    try {
      final t = await CreatorMonetizationService.transactions(token: token, limit: 20, cursor: _cursor);
      final data = t['data'];
      final list = (data is List) ? data : const [];
      if (!mounted) return;

      final next = list.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
      setState(() {
        _tx = [..._tx, ...next];
        _cursor = t['nextCursor']?.toString();
        _paging = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _paging = false);
    }
  }

  int _cents(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _currency() {
    final s = (_wallet?['currency'] ?? 'usd').toString().toUpperCase();
    return s.isEmpty ? 'USD' : s;
  }

  String _money(int cents) {
    final v = (cents / 100.0);
    return v.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    _cardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _cardScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.8, end: 1.05).chain(CurveTween(curve: Curves.easeOutBack)), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 60),
    ]).animate(_cardAnimationController);

    _cardRotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.1, end: -0.02).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: -0.02, end: 0.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 50),
    ]).animate(_cardAnimationController);

    _cardGlowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    ));

    _listSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    ));

    _cardAnimationController.forward();
    _load();
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final available = _money(_cents(_wallet?['availableBalanceCents']));
    final pending = _money(_cents(_wallet?['pendingBalanceCents']));
    final lifetime = _money(_cents(_wallet?['lifetimeEarningsCents']));
    final curr = _currency();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF05060A) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF05060A) : const Color(0xFFF8FAFC),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                'MY WALLET',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontSize: 18,
                  color: isDark ? Colors.white : cs.onSurface,
                ),
              ),
            ),
            leading: IconButton(
              onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard?tab=profile'),
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : cs.onSurface, size: 20),
            ),
            actions: [
              IconButton(
                onPressed: _load,
                icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white : cs.onSurface),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // Futuristic 3D Card with Enhanced Effects
                  AnimatedBuilder(
                    animation: _cardAnimationController,
                    builder: (context, child) {
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..rotateX(_cardRotation.value)
                          ..rotateY(_cardRotation.value * 0.5)
                          ..scale(_cardScale.value),
                        child: Container(
                          width: double.infinity,
                          height: 230,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [
                                      cs.primary,
                                      AppColors.accent,
                                      const Color(0xFF6366F1), // Indigo accent
                                    ]
                                  : [
                                      cs.primary,
                                      cs.primary.withOpacity(0.8),
                                      AppColors.accent,
                                    ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withOpacity(isDark ? 0.6 * _cardGlowOpacity.value : 0.3),
                                blurRadius: 40,
                                offset: Offset(0, 20 * _cardGlowOpacity.value),
                                spreadRadius: -5,
                              ),
                              if (isDark)
                                BoxShadow(
                                  color: AppColors.accent.withOpacity(0.4 * _cardGlowOpacity.value),
                                  blurRadius: 60,
                                  offset: const Offset(0, 10),
                                  spreadRadius: -10,
                                ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: Stack(
                              children: [
                                // Glassmorphic overlay for texture
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topRight,
                                        end: Alignment.bottomLeft,
                                        colors: [
                                          Colors.white.withOpacity(0.12),
                                          Colors.white.withOpacity(0.0),
                                          Colors.black.withOpacity(0.05),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Animated mesh-like circles
                                Positioned(
                                  top: -40,
                                  right: -20,
                                  child: Transform.rotate(
                                    angle: _cardAnimationController.value * 0.5,
                                    child: Container(
                                      width: 180,
                                      height: 180,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white.withOpacity(0.08), width: 20),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -50,
                                  left: 10,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.05),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.1),
                                          blurRadius: 40,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: const BoxDecoration(
                                                      color: Colors.greenAccent,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(color: Colors.greenAccent, blurRadius: 4),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'ACTIVE BALANCE',
                                                    style: AppTypography.labelLarge.copyWith(
                                                      color: Colors.white.withOpacity(0.85),
                                                      letterSpacing: 2.0,
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              ShaderMask(
                                                shaderCallback: (bounds) => const LinearGradient(
                                                  colors: [Colors.white, Colors.white70],
                                                ).createShader(bounds),
                                                child: Text(
                                                  '$available $curr',
                                                  style: AppTypography.displaySmall.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 38,
                                                    letterSpacing: -1,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(20),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          _miniStat(label: 'PENDING REVENUE', value: '$pending $curr'),
                                          const SizedBox(width: 40),
                                          _miniStat(label: 'TOTAL EARNED', value: '$lifetime $curr'),
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
                    },
                  ),
                  const SizedBox(height: 30),
                  // Action Button
                  CustomButton(
                    text: 'ACTIVATE PAYOUTS',
                    onPressed: () async {
                      final token = context.read<AuthProvider>().token;
                      if (token == null || token.trim().isEmpty) return;
                      try {
                        final res = await CreatorMonetizationService.onboardingLink(token: token);
                        final data = res['data'];
                        final url = (data is Map) ? data['url']?.toString() : null;
                        if (url == null || url.trim().isEmpty) {
                          AppNotifier.showError('Missing onboarding url');
                          return;
                        }
                        final uri = Uri.tryParse(url.trim());
                        if (uri == null) {
                          AppNotifier.showError('Invalid onboarding url');
                          return;
                        }
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        AppNotifier.showError(e.toString());
                      }
                    },
                    type: ButtonType.primary,
                    isFullWidth: true,
                    icon: const Icon(Icons.rocket_launch_rounded),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TRANSACTIONS',
                        style: AppTypography.subtitle2.copyWith(
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : cs.onSurface,
                          letterSpacing: 1,
                        ),
                      ),
                      if (!_loading && _tx.isNotEmpty)
                        Text(
                          '${_tx.length} Items',
                          style: AppTypography.caption.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                  else if (_tx.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: isDark ? cs.surface.withOpacity(0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : cs.outlineVariant.withOpacity(0.5)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.history_rounded, size: 48, color: cs.onSurfaceVariant.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          Text(
                            'No transactions yet.',
                            style: AppTypography.body1.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!_loading && _tx.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return SlideTransition(
                      position: _listSlideAnimation,
                      child: _txTile(_tx[index], cs),
                    );
                  },
                  childCount: _tx.length,
                ),
              ),
            ),
          if (_cursor != null && _cursor!.trim().isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CustomButton(
                  text: _paging ? 'LOADING…' : 'LOAD MORE',
                  onPressed: _paging ? null : _loadMore,
                  type: ButtonType.ghost,
                  isFullWidth: true,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _miniStat({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: Colors.white.withOpacity(0.6),
            fontWeight: FontWeight.w900,
            fontSize: 9,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.body2.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _statTile({required String label, required String value}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(value, style: AppTypography.body1.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _txTile(Map<String, dynamic> t, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = (t['type'] ?? '').toString();
    final status = (t['status'] ?? '').toString();
    final net = _money(_cents(t['creatorNetCents']));
    final curr = (t['currency'] ?? _currency()).toString().toUpperCase();
    final message = (t['metadata'] is Map) ? (t['metadata']['message']?.toString() ?? '') : '';

    IconData icon = Icons.payments_rounded;
    String title = 'Earning';
    Color iconColor = AppColors.success;
    
    if (type == 'creator_pass') {
      icon = Icons.workspace_premium_rounded;
      title = 'Creator Pass';
      iconColor = AppColors.primary;
    } else if (type == 'tip') {
      icon = Icons.volunteer_activism_rounded;
      title = 'Donation';
      iconColor = AppColors.accent;
    }

    final ok = status == 'succeeded';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surface.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : cs.outlineVariant.withOpacity(0.5),
        ),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (ok ? iconColor : cs.onSurfaceVariant).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: ok ? iconColor : cs.onSurfaceVariant, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body1.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ok ? 'COMPLETED' : status.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+$net $curr',
                style: AppTypography.body1.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.success,
                ),
              ),
              if (message.trim().isNotEmpty)
                Text(
                  'TIP',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 8,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
