import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/billing_service.dart';
import '../../../core/utils/app_refresh_bus.dart';
import '../../widgets/widgets.dart';

class SubscriptionScreen extends StatefulWidget {
  final bool autoStart;
  const SubscriptionScreen({super.key, this.autoStart = false});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _upgrading = false;
  String? _upgradingPriceId;
  String? _error;

  bool _autoStartHandled = false;

  Timer? _syncTimer;
  bool _syncing = false;
  int _syncAttempts = 0;

  List<Map<String, dynamic>> _plans = const [];
  Map<String, dynamic>? _subscription;
  Map<String, dynamic>? _entitlements;

  late final AnimationController _appearController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final VoidCallback _refreshListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeIn = CurvedAnimation(
      parent: _appearController,
      curve: Curves.easeOutCubic,
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _appearController,
            curve: Curves.easeOutCubic,
          ),
        );

    _refreshListener = () {
      if (!mounted) return;
      _load();
    };
    AppRefreshBus.notifier.addListener(_refreshListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<String?> _resolveToken() async {
    final authToken = context.read<AuthProvider>().token;
    if (authToken != null && authToken.trim().isNotEmpty) {
      return authToken;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('auth_token');
      if (storedToken != null && storedToken.trim().isNotEmpty) {
        return storedToken;
      }
    } catch (_) {}

    return null;
  }

  List<String> _featuresFromPlan(Map<String, dynamic> plan) {
    final ent = (plan['entitlements'] is Map)
        ? Map<String, dynamic>.from(plan['entitlements'] as Map)
        : <String, dynamic>{};
    final limits = (ent['limits'] is Map)
        ? Map<String, dynamic>.from(ent['limits'] as Map)
        : <String, dynamic>{};
    final flags = (ent['flags'] is Map)
        ? Map<String, dynamic>.from(ent['flags'] as Map)
        : <String, dynamic>{};

    int nInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    final ai = nInt(limits['aiGenerationsPerMonth']);
    final mins = nInt(limits['buildMinutesPerMonth']);
    final maxProjects = nInt(limits['maxProjects']);
    final maxAssetsMb = nInt(limits['maxAssetsMb']);

    final android = flags['androidBuildEnabled'] == true;
    final proTemplates = flags['proTemplatesEnabled'] == true;
    final priority = flags['priorityBuildQueue'] == true;

    final out = <String>[];
    if (ai > 0) out.add('$ai AI generations / month');
    if (mins > 0) out.add('$mins build minutes / month');
    if (maxProjects > 0) out.add('Up to $maxProjects projects');
    if (maxAssetsMb > 0) out.add('Up to ${maxAssetsMb}MB assets storage');

    out.add(
      android
          ? 'Android (APK) export enabled'
          : 'Android (APK) export not included',
    );
    out.add(
      proTemplates ? 'Access to Pro templates' : 'Community templates only',
    );
    if (priority) out.add('Priority build queue');

    if (out.isNotEmpty) return out;
    return (plan['features'] as List?)?.cast<String>() ?? const [];
  }

  bool _isNegativeFeature(String v) {
    final s = v.toLowerCase();
    return s.contains('not included') ||
        s.contains('only') ||
        s.contains('no ') ||
        s.contains('requires');
  }

  Widget _featureRow({
    required String feature,
    required ColorScheme cs,
    required Color accent,
  }) {
    final negative = _isNegativeFeature(feature);
    final icon = negative ? Icons.close_rounded : Icons.check_rounded;
    final iconBg = negative
        ? cs.error.withOpacity(0.14)
        : accent.withOpacity(0.14);
    final iconFg = negative ? cs.error : accent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: (negative ? cs.error : accent).withOpacity(0.25),
            ),
          ),
          child: Icon(icon, size: 16, color: iconFg),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            feature,
            style: AppTypography.body2.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _quotaLine({
    required String label,
    required int used,
    required int limit,
  }) {
    final cs = Theme.of(context).colorScheme;
    final l = limit <= 0 ? 1 : limit;
    final progress = (used / l).clamp(0.0, 1.0);
    final remaining = (limit - used).clamp(0, 1 << 30);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$label: $remaining left',
                style: AppTypography.caption.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$used/$limit',
              style: AppTypography.caption.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: cs.surfaceContainerHighest.withOpacity(0.6),
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
        ),
      ],
    );
  }

  Future<void> _startInAppSubscription({
    required String token,
    required String priceId,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pk = Stripe.publishableKey;
    if (pk.isEmpty) {
      throw Exception('Missing Stripe publishable key');
    }

    final res = await BillingService.createPaymentSheet(
      token: token,
      priceId: priceId,
    );
    if (res['success'] != true) {
      throw Exception(res['message']?.toString() ?? 'Failed to start payment');
    }

    final data = (res['data'] is Map)
        ? Map<String, dynamic>.from(res['data'] as Map)
        : <String, dynamic>{};
    final customerId = data['customerId']?.toString() ?? '';
    final ephemeralKeySecret = data['ephemeralKeySecret']?.toString() ?? '';
    // Backend returns a SetupIntent for PaymentSheet card collection.
    final setupIntentClientSecret =
        data['setupIntentClientSecret']?.toString() ?? '';
    final setupIntentId = data['setupIntentId']?.toString() ?? '';

    if (customerId.isEmpty ||
        ephemeralKeySecret.isEmpty ||
        setupIntentClientSecret.isEmpty ||
        setupIntentId.isEmpty) {
      throw Exception('Invalid PaymentSheet data from server');
    }

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        merchantDisplayName: 'GameForge AI',
        customerId: customerId,
        customerEphemeralKeySecret: ephemeralKeySecret,
        setupIntentClientSecret: setupIntentClientSecret,
        style: isDark ? ThemeMode.dark : ThemeMode.light,
        appearance: PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(
            background: cs.surface,
            primary: cs.primary,
            componentBackground: cs.surface,
            componentBorder: cs.outlineVariant,
            componentDivider: cs.outlineVariant,
            componentText: cs.onSurface,
            primaryText: cs.onPrimary,
            secondaryText: cs.onSurfaceVariant,
            placeholderText: cs.onSurfaceVariant,
            icon: cs.onSurfaceVariant,
            error: cs.error,
          ),
        ),
      ),
    );

    await Stripe.instance.presentPaymentSheet();

    // Finalize the subscription on the backend using the completed SetupIntent.
    final subRes = await BillingService.subscribeWithSetupIntent(
      token: token,
      priceId: priceId,
      setupIntentId: setupIntentId,
    );
    if (subRes['success'] != true) {
      throw Exception(
        subRes['message']?.toString() ?? 'Failed to activate subscription',
      );
    }

    await _syncUntilConfirmed(token: token);
  }

  bool _isSyncNeeded() {
    final status = _subscriptionStatus();
    return status == 'incomplete' ||
        status == 'past_due' ||
        status == 'unpaid' ||
        status == 'incomplete_expired';
  }

  Future<void> _syncOnce({required String token}) async {
    if (_syncing) return;
    _syncing = true;
    try {
      await BillingService.syncSubscription(token: token);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncUntilConfirmed({required String token}) async {
    _syncAttempts = 0;
    for (int i = 0; i < 5; i++) {
      _syncAttempts++;
      await _syncOnce(token: token);
      await _load();
      if (_isSubscriptionConfirmed()) return;
      if (!_isSyncNeeded()) return;
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  void _startBackgroundAutoSyncIfNeeded() {
    if (_syncTimer != null) return;
    if (!_isSyncNeeded()) return;

    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) return;

    _syncAttempts = 0;
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (t) async {
      if (!mounted) return;
      if (_isSubscriptionConfirmed() || !_isSyncNeeded()) {
        t.cancel();
        _syncTimer = null;
        return;
      }

      _syncAttempts++;
      if (_syncAttempts > 6) {
        t.cancel();
        _syncTimer = null;
        return;
      }

      try {
        await _syncOnce(token: token);
        await _load();
      } catch (_) {}
    });
  }

  String _formatStripeError(Object e) {
    if (e.runtimeType.toString() == 'StripeConfigException') {
      final msg = e.toString();
      if (msg.trim().isNotEmpty && !msg.startsWith('Instance of')) {
        return msg;
      }
      return 'Stripe is not configured (missing publishable key or url scheme).';
    }
    if (e is StripeException) {
      final code = e.error.code;
      final codeStr = code?.toString();
      final message = e.error.message;
      if (message != null && message.trim().isNotEmpty) {
        return codeStr != null && codeStr.trim().isNotEmpty
            ? '$codeStr: $message'
            : message;
      }
      if (codeStr != null && codeStr.trim().isNotEmpty) return codeStr;
      return 'Stripe error';
    }
    final msg = e.toString();
    if (msg.startsWith('Exception: '))
      return msg.replaceFirst('Exception: ', '');
    return msg;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppRefreshBus.notifier.removeListener(_refreshListener);
    _appearController.dispose();
    try {
      _syncTimer?.cancel();
    } catch (_) {}
    _syncTimer = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    final token = await _resolveToken();

    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'You must be signed in to manage subscriptions.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final plansRes = await BillingService.getPlans(token: token);
      if (plansRes['success'] != true) {
        throw Exception(
          plansRes['message']?.toString() ?? 'Failed to load plans',
        );
      }

      final rawPlans = plansRes['data'];
      final plans = (rawPlans is List)
          ? rawPlans
                .where((e) => e is Map)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
          : <Map<String, dynamic>>[];

      final subRes = await BillingService.getMySubscription(token: token);
      Map<String, dynamic>? subscription;
      if (subRes['success'] == true && subRes['data'] is Map) {
        subscription = Map<String, dynamic>.from(subRes['data'] as Map);
      }

      Map<String, dynamic>? entitlements;
      try {
        final entRes = await BillingService.getEntitlements(token: token);
        if (entRes['success'] == true && entRes['data'] is Map) {
          entitlements = Map<String, dynamic>.from(entRes['data'] as Map);
        }
      } catch (_) {
        entitlements = null;
      }

      if (!mounted) return;
      setState(() {
        _plans = plans;
        _subscription = subscription;
        _entitlements = entitlements;
        _loading = false;
      });
      _appearController.forward(from: 0);
      _startBackgroundAutoSyncIfNeeded();

      if (widget.autoStart) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _maybeAutoStartCheckout(token: token);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _maybeAutoStartCheckout({required String token}) async {
    if (_autoStartHandled) return;
    _autoStartHandled = true;

    if (_upgrading) return;
    if (_plans.isEmpty) return;

    // Pick a sensible default plan:
    // - prefer popular plan
    // - avoid current plan
    // - require a non-empty priceId
    Map<String, dynamic>? chosen;
    for (final p in _plans) {
      final priceId =
          (p['priceId']?.toString() ?? p['stripePriceId']?.toString() ?? '')
              .trim();
      if (priceId.isEmpty) continue;
      if (_isCurrentPlan(p)) continue;
      if (p['isPopular'] == true) {
        chosen = p;
        break;
      }
    }
    chosen ??= _plans.firstWhere((p) {
      final priceId =
          (p['priceId']?.toString() ?? p['stripePriceId']?.toString() ?? '')
              .trim();
      return priceId.isNotEmpty && !_isCurrentPlan(p);
    }, orElse: () => _plans.first);

    final priceId =
        (chosen['priceId']?.toString() ??
                chosen['stripePriceId']?.toString() ??
                '')
            .trim();
    if (priceId.isEmpty) return;

    try {
      setState(() {
        _upgrading = true;
        _upgradingPriceId = priceId;
      });
      await _startInAppSubscription(token: token, priceId: priceId);
      await _load();
    } catch (_) {
      // Intentionally silent: user can retry manually.
    } finally {
      if (!mounted) return;
      setState(() {
        _upgrading = false;
        _upgradingPriceId = null;
      });
    }
  }

  Widget _animatedEntry({required int index, required Widget child}) {
    final start = (0.08 * index).clamp(0.0, 0.5);
    final interval = Interval(start, 1.0, curve: Curves.easeOutCubic);
    final fade = CurvedAnimation(parent: _appearController, curve: interval);
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _appearController, curve: interval));
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }

  Widget _planGlow({required bool enabled, required Widget child}) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 1.0),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeInOut,
      onEnd: () {
        if (mounted) setState(() {});
      },
      builder: (context, t, _) {
        final intensity = 0.20 + (0.10 * t);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(intensity),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }

  Widget _featureStep({
    required int index,
    required int total,
    required String feature,
    required Color accent,
    required Color textColor,
    required Color muted,
  }) {
    final start = (0.10 + 0.05 * index).clamp(0.0, 0.85);
    final interval = Interval(start, 1.0, curve: Curves.easeOutCubic);
    final anim = CurvedAnimation(parent: _appearController, curve: interval);

    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final v = anim.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 26,
                  child: Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withOpacity(0.95),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.25),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                      if (index != total - 1)
                        Container(
                          width: 2,
                          height: 20,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                accent.withOpacity(0.35),
                                muted.withOpacity(0.08),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      feature,
                      style: AppTypography.body2.copyWith(color: textColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw Exception('Invalid URL');
    }

    final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!ok) {
      throw Exception('Failed to open URL');
    }
  }

  String? _currentPriceId() {
    final sub = _subscription;
    if (sub == null) return null;

    if (!_isSubscriptionConfirmed()) return null;

    final priceId = sub['priceId']?.toString().trim();
    if (priceId != null && priceId.isNotEmpty) return priceId;

    final plan = sub['plan'];
    if (plan is Map) {
      final planMap = Map<String, dynamic>.from(plan);
      final planPriceId =
          planMap['priceId']?.toString().trim() ??
          planMap['stripePriceId']?.toString().trim();
      if (planPriceId != null && planPriceId.isNotEmpty) return planPriceId;
    }
    return null;
  }

  bool _isCurrentPlan(Map<String, dynamic> plan) {
    final current = _currentPriceId();
    if (current == null || current.isEmpty) return false;
    final planPriceId =
        (plan['priceId']?.toString() ?? plan['stripePriceId']?.toString() ?? '')
            .trim();
    if (planPriceId.isEmpty) return false;
    return planPriceId == current;
  }

  String _planTitleFromSubscription() {
    final sub = _subscription;
    if (sub == null) return 'Free';

    if (!_isSubscriptionConfirmed()) return 'Free';

    final plan = sub['plan'];
    if (plan is Map) {
      final planMap = Map<String, dynamic>.from(plan);
      final name = planMap['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
    final legacy = sub['planName']?.toString().trim();
    if (legacy != null && legacy.isNotEmpty) return legacy;
    return 'Free';
  }

  String _subscriptionStatus() {
    final status = _subscription?['status']?.toString().trim().toLowerCase();
    if (status == null || status.isEmpty) return 'Unknown';
    return status;
  }

  bool _isSubscriptionConfirmed() {
    final status = _subscriptionStatus();
    return status == 'active' || status == 'trialing';
  }

  Color _statusColor() {
    final status = _subscriptionStatus();
    if (status == 'active' || status == 'trialing') return AppColors.success;
    if (status == 'past_due' || status == 'unpaid') return AppColors.warning;
    if (status == 'canceled' || status == 'incomplete_expired')
      return AppColors.error;
    return AppColors.info;
  }

  Widget _skeletonLine({double height = 14, double widthFactor = 1.0}) {
    final cs = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.35, end: 0.55),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeInOut,
        builder: (context, t, child) {
          return Container(
            height: height,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withOpacity(t),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }

  Widget _skeletonCard({required double height}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: height,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.65)),
        boxShadow: AppShadows.boxShadowSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _skeletonLine(height: 16, widthFactor: 0.62)),
              const SizedBox(width: AppSpacing.md),
              Container(
                width: 84,
                height: 26,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _skeletonLine(height: 26, widthFactor: 0.45),
          const SizedBox(height: AppSpacing.sm),
          _skeletonLine(height: 12, widthFactor: 0.78),
          const SizedBox(height: AppSpacing.lg),
          _skeletonLine(height: 12, widthFactor: 0.92),
          const SizedBox(height: AppSpacing.md),
          _skeletonLine(height: 12, widthFactor: 0.88),
        ],
      ),
    );
  }

  Widget _plansSkeleton() {
    return Column(
      children: [
        _skeletonCard(height: 300),
        const SizedBox(height: AppSpacing.lg),
        _skeletonCard(height: 320),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = _loading && (_plans.isEmpty || _subscription == null);
    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
              return;
            }
            context.go('/settings');
          },
        ),
        elevation: 0,
        title: Text(
          'Subscription',
          style: AppTypography.subtitle1.copyWith(color: colorScheme.onSurface),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: AppSpacing.paddingLarge,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (child, anim) {
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                );
              },
              child: isLoading
                  ? KeyedSubtree(
                      key: const ValueKey('current_skeleton'),
                      child: _skeletonCard(height: 220),
                    )
                  : KeyedSubtree(
                      key: ValueKey(
                        'current_${_planTitleFromSubscription()}_${_subscriptionStatus()}',
                      ),
                      child: _buildCurrentPlan(context),
                    ),
            ),
            SizedBox(height: AppSpacing.xxxl),
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.18),
                    ),
                  ),
                  child: Icon(
                    Icons.view_carousel_rounded,
                    color: colorScheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Plans',
                        style: AppTypography.subtitle2.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Upgrade to unlock higher limits and Android exports.',
                        style: AppTypography.caption.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (child, anim) {
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                );
              },
              child: _loading
                  ? KeyedSubtree(
                      key: const ValueKey('plans_skeleton'),
                      child: _plansSkeleton(),
                    )
                  : (_error != null)
                  ? KeyedSubtree(
                      key: const ValueKey('plans_error'),
                      child: Container(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.large,
                          ),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withOpacity(0.65),
                          ),
                          boxShadow: AppShadows.boxShadowSmall,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: colorScheme.error,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Failed to load billing info',
                                    style: AppTypography.subtitle2.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: AppSpacing.sm),
                            Text(
                              _error!,
                              style: AppTypography.caption.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: AppSpacing.lg),
                            CustomButton(
                              text: 'Retry',
                              onPressed: _load,
                              type: ButtonType.primary,
                              isFullWidth: true,
                            ),
                          ],
                        ),
                      ),
                    )
                  : (_plans.isEmpty)
                  ? KeyedSubtree(
                      key: const ValueKey('plans_empty'),
                      child: Container(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(
                            AppBorderRadius.large,
                          ),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withOpacity(0.65),
                          ),
                          boxShadow: AppShadows.boxShadowSmall,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                'No plans available right now.',
                                style: AppTypography.body2.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('plans_list'),
                      child: Column(
                        children: _plans.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final plan = entry.value;
                          final name = plan['name']?.toString() ?? 'Plan';
                          final description =
                              plan['description']?.toString() ?? '';
                          final price = (plan['priceMonthly'] is num)
                              ? (plan['priceMonthly'] as num).toDouble()
                              : 0.0;
                          final originalPrice =
                              (plan['originalPriceMonthly'] is num)
                              ? (plan['originalPriceMonthly'] as num).toDouble()
                              : price;
                          final discountPercent =
                              (plan['discountPercent'] is num)
                              ? (plan['discountPercent'] as num).toInt()
                              : 0;
                          final features = _featuresFromPlan(plan);

                          final priceId =
                              (plan['priceId']?.toString() ??
                                      plan['stripePriceId']?.toString() ??
                                      '')
                                  .trim();
                          final isCurrent = _isCurrentPlan(plan);
                          final isPopular = plan['isPopular'] == true;

                          final showGlow = price > 0 && !isCurrent;

                          return Padding(
                            padding: EdgeInsets.only(bottom: AppSpacing.lg),
                            child: _animatedEntry(
                              index: idx,
                              child: _planGlow(
                                enabled: showGlow,
                                child: _buildPlanCard(
                                  context,
                                  name,
                                  description,
                                  price,
                                  originalPrice,
                                  discountPercent,
                                  features,
                                  priceId: priceId,
                                  isCurrent: isCurrent,
                                  isPopular: isPopular,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
            SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlan(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = _planTitleFromSubscription();
    final status = _subscriptionStatus();
    final amountText = _subscription?['amount'] != null
        ? '\$${(_subscription!['amount'] as num).toStringAsFixed(2)}/month'
        : 'Manage your plan and billing';
    final periodText = _subscription?['currentPeriodEnd']?.toString() != null
        ? 'Period ends: ${_subscription!['currentPeriodEnd']}'
        : 'Pull to refresh to sync the latest subscription status.';

    final ent = _entitlements;
    final usage = (ent != null && ent['usage'] is Map)
        ? Map<String, dynamic>.from(ent['usage'] as Map)
        : <String, dynamic>{};
    final entObj = (ent != null && ent['entitlements'] is Map)
        ? Map<String, dynamic>.from(ent['entitlements'] as Map)
        : <String, dynamic>{};
    final limits = (entObj['limits'] is Map)
        ? Map<String, dynamic>.from(entObj['limits'] as Map)
        : <String, dynamic>{};
    final aiLimit = (limits['aiGenerationsPerMonth'] is num)
        ? (limits['aiGenerationsPerMonth'] as num).toInt()
        : 0;
    final buildLimit = (limits['buildMinutesPerMonth'] is num)
        ? (limits['buildMinutesPerMonth'] as num).toInt()
        : 0;
    final aiUsed = (usage['aiGenerationsUsed'] is num)
        ? (usage['aiGenerationsUsed'] as num).toInt()
        : 0;
    final buildUsed = (usage['buildMinutesUsed'] is num)
        ? (usage['buildMinutesUsed'] as num).toInt()
        : 0;
    final canShowQuotas = aiLimit > 0 || buildLimit > 0;
    final canCancel = _isSubscriptionConfirmed();
    final canSync =
        status == 'incomplete' ||
        status == 'past_due' ||
        status == 'unpaid' ||
        status == 'incomplete_expired';

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppBorderRadius.large),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withOpacity(0.18),
                colorScheme.secondary.withOpacity(0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            border: Border.all(color: colorScheme.primary.withOpacity(0.28)),
            boxShadow: AppShadows.boxShadowSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.workspace_premium, color: colorScheme.primary),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Current Plan: $title',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: AppTypography.subtitle2.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: StatusBadge(text: status, color: _statusColor()),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                amountText,
                style: AppTypography.h3.copyWith(color: colorScheme.primary),
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                periodText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (canShowQuotas) ...[
                SizedBox(height: AppSpacing.lg),
                _quotaLine(
                  label: 'AI generations',
                  used: aiUsed,
                  limit: aiLimit <= 0 ? 1 : aiLimit,
                ),
                SizedBox(height: AppSpacing.md),
                _quotaLine(
                  label: 'Build minutes',
                  used: buildUsed,
                  limit: buildLimit <= 0 ? 1 : buildLimit,
                ),
              ],
              if (canSync) ...[
                SizedBox(height: AppSpacing.lg),
                CustomButton(
                  text: 'Sync purchase',
                  onPressed: () async {
                    final auth = context.read<AuthProvider>();
                    final token = auth.token;
                    if (token == null || token.isEmpty) return;

                    try {
                      final res = await BillingService.syncSubscription(
                        token: token,
                      );
                      if (res['success'] == true) {
                        await _load();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Subscription synced')),
                        );
                        return;
                      }
                      final message =
                          res['message']?.toString() ??
                          'Failed to sync subscription';
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_formatStripeError(e)),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  type: ButtonType.secondary,
                  isFullWidth: true,
                ),
              ],
              if (canCancel) ...[
                SizedBox(height: AppSpacing.lg),
                CustomButton(
                  text: 'Cancel subscription',
                  onPressed: () async {
                    final auth = context.read<AuthProvider>();
                    final token = auth.token;
                    if (token == null || token.isEmpty) return;

                    try {
                      final res = await BillingService.cancelSubscription(
                        token: token,
                      );
                      if (res['success'] == true) {
                        await _load();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Subscription will cancel at period end',
                            ),
                          ),
                        );
                        return;
                      }
                      final message =
                          res['message']?.toString() ??
                          'Failed to cancel subscription';
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_formatStripeError(e)),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  type: ButtonType.primary,
                  isFullWidth: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    String name,
    String description,
    double price,
    double originalPrice,
    int discountPercent,
    List<String> features, {
    required String priceId,
    bool isCurrent = false,
    bool isPopular = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isFreePlan = price <= 0;
    final hasDiscount =
        !isFreePlan &&
        discountPercent > 0 &&
        originalPrice > 0 &&
        price < originalPrice;

    final accent = isCurrent
        ? colorScheme.primary
        : colorScheme.primary.withOpacity(0.85);
    final isSelected =
        _upgrading && _upgradingPriceId != null && _upgradingPriceId == priceId;
    final isDisabled = _upgrading && !isSelected;

    final baseBorderColor = isCurrent
        ? colorScheme.primary
        : colorScheme.outline.withOpacity(0.5);
    final borderColor = isSelected ? accent : baseBorderColor;
    final borderWidth = isSelected ? 2.5 : (isCurrent ? 2.0 : 1.0);

    return AnimatedScale(
      scale: isSelected ? 1.01 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isDisabled
              ? colorScheme.surface.withOpacity(0.72)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            ...AppShadows.boxShadowSmall,
            if (isSelected)
              BoxShadow(
                color: accent.withOpacity(0.28),
                blurRadius: 26,
                spreadRadius: 1,
                offset: const Offset(0, 14),
              ),
          ],
        ),
        child: AnimatedOpacity(
          opacity: isDisabled ? 0.55 : 1.0,
          duration: const Duration(milliseconds: 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: isPopular
                      ? colorScheme.primary.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppBorderRadius.large),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: AppTypography.subtitle1.copyWith(
                            color: isCurrent
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        if (isPopular)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'POPULAR',
                              style: AppTypography.caption.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      description,
                      style: AppTypography.caption.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (!hasDiscount)
                      Text(
                        price == 0.0
                            ? 'Free'
                            : '\$${price.toStringAsFixed(2)}/month',
                        style: AppTypography.h3.copyWith(
                          color: isCurrent
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    else
                      Column(
                        children: [
                          Text(
                            '\$${originalPrice.toStringAsFixed(2)}/month',
                            style: AppTypography.caption.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${price.toStringAsFixed(2)}/month',
                                style: AppTypography.h3.copyWith(
                                  color: isCurrent
                                      ? colorScheme.primary
                                      : colorScheme.onSurface,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppColors.success.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  '-$discountPercent%',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(features.length, (i) {
                    final feature = features[i];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: i == features.length - 1 ? 0 : AppSpacing.md,
                      ),
                      child: _featureRow(
                        feature: feature,
                        cs: colorScheme,
                        accent: accent,
                      ),
                    );
                  }),
                ),
              ),

              if (!isFreePlan)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: isCurrent ? 'Current Plan' : 'Upgrade to $name',
                      onPressed:
                          isDisabled ||
                              isCurrent ||
                              (price > 0 && priceId.trim().isEmpty)
                          ? null
                          : () async {
                              final auth = context.read<AuthProvider>();
                              final token = auth.token;
                              if (token == null || token.isEmpty) return;

                              try {
                                setState(() {
                                  _upgrading = true;
                                  _upgradingPriceId = priceId;
                                });
                                await _startInAppSubscription(
                                  token: token,
                                  priceId: priceId,
                                );
                                await _load();
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_formatStripeError(e)),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              } finally {
                                if (!mounted) return;
                                setState(() {
                                  _upgrading = false;
                                  _upgradingPriceId = null;
                                });
                              }
                            },
                      type: isCurrent ? ButtonType.ghost : ButtonType.primary,
                      isLoading: isSelected,
                      isFullWidth: true,
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
