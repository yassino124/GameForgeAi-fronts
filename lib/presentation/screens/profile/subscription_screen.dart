import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/billing_service.dart';
import '../../widgets/widgets.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _upgrading = false;
  String? _upgradingPriceId;
  String? _error;

  List<Map<String, dynamic>> _plans = const [];
  Map<String, dynamic>? _subscription;

  late final AnimationController _appearController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeIn = CurvedAnimation(parent: _appearController, curve: Curves.easeOutCubic);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _appearController, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
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

    final res = await BillingService.createPaymentSheet(token: token, priceId: priceId);
    if (res['success'] != true) {
      throw Exception(res['message']?.toString() ?? 'Failed to start payment');
    }

    final data = (res['data'] is Map) ? Map<String, dynamic>.from(res['data'] as Map) : <String, dynamic>{};
    final customerId = data['customerId']?.toString() ?? '';
    final ephemeralKeySecret = data['ephemeralKeySecret']?.toString() ?? '';
    final paymentIntentClientSecret = data['paymentIntentClientSecret']?.toString() ?? '';

    if (customerId.isEmpty || ephemeralKeySecret.isEmpty || paymentIntentClientSecret.isEmpty) {
      throw Exception('Invalid PaymentSheet data from server');
    }

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        merchantDisplayName: 'GameForge AI',
        customerId: customerId,
        customerEphemeralKeySecret: ephemeralKeySecret,
        paymentIntentClientSecret: paymentIntentClientSecret,
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
        return codeStr != null && codeStr.trim().isNotEmpty ? '$codeStr: $message' : message;
      }
      if (codeStr != null && codeStr.trim().isNotEmpty) return codeStr;
      return 'Stripe error';
    }
    final msg = e.toString();
    if (msg.startsWith('Exception: ')) return msg.replaceFirst('Exception: ', '');
    return msg;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appearController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;

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
      final plansRes = await BillingService.getPlans();
      if (plansRes['success'] != true) {
        throw Exception(plansRes['message']?.toString() ?? 'Failed to load plans');
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

      if (!mounted) return;
      setState(() {
        _plans = plans;
        _subscription = subscription;
        _loading = false;
      });
      _appearController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Widget _animatedEntry({required int index, required Widget child}) {
    final start = (0.08 * index).clamp(0.0, 0.5);
    final interval = Interval(start, 1.0, curve: Curves.easeOutCubic);
    final fade = CurvedAnimation(parent: _appearController, curve: interval);
    final slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _appearController, curve: interval),
    );
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
                      style: AppTypography.body2.copyWith(
                        color: textColor,
                      ),
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
      final planPriceId = planMap['priceId']?.toString().trim() ??
          planMap['stripePriceId']?.toString().trim();
      if (planPriceId != null && planPriceId.isNotEmpty) return planPriceId;
    }
    return null;
  }

  bool _isCurrentPlan(Map<String, dynamic> plan) {
    final current = _currentPriceId();
    if (current == null || current.isEmpty) return false;
    final planPriceId = (plan['priceId']?.toString() ?? plan['stripePriceId']?.toString() ?? '').trim();
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
    if (status == 'canceled' || status == 'incomplete_expired') return AppColors.error;
    return AppColors.info;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
            _buildCurrentPlan(context),
            SizedBox(height: AppSpacing.xxxl),
            Text(
              'Available Plans',
              style: AppTypography.subtitle2.copyWith(color: colorScheme.onSurface),
            ),
            SizedBox(height: AppSpacing.lg),
            if (_loading)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: CircularProgressIndicator(color: colorScheme.primary),
                ),
              )
            else if (_error != null)
              Container(
                padding: EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  border: Border.all(color: colorScheme.outline.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Failed to load billing info',
                      style: AppTypography.subtitle2.copyWith(color: colorScheme.onSurface),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      _error!,
                      style: AppTypography.caption.copyWith(color: colorScheme.onSurfaceVariant),
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
              )
            else if (_plans.isEmpty)
              Container(
                padding: EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  border: Border.all(color: colorScheme.outline.withOpacity(0.5)),
                ),
                child: Text(
                  'No plans available right now.',
                  style: AppTypography.body2.copyWith(color: colorScheme.onSurface),
                ),
              )
            else
              ..._plans.asMap().entries.map((entry) {
                final idx = entry.key;
                final plan = entry.value;
                final name = plan['name']?.toString() ?? 'Plan';
                final description = plan['description']?.toString() ?? '';
                final price = (plan['priceMonthly'] is num)
                    ? (plan['priceMonthly'] as num).toDouble()
                    : 0.0;
                final features = (plan['features'] as List?)?.cast<String>() ?? const [];

                final priceId = (plan['priceId']?.toString() ?? plan['stripePriceId']?.toString() ?? '').trim();
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
                        features,
                        priceId: priceId,
                        isCurrent: isCurrent,
                        isPopular: isPopular,
                      ),
                    ),
                  ),
                );
              }).toList(),
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
                  Icon(
                    Icons.workspace_premium,
                    color: colorScheme.primary,
                  ),
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
                      child: StatusBadge(
                        text: status,
                        color: _statusColor(),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                amountText,
                style: AppTypography.h3.copyWith(
                  color: colorScheme.primary,
                ),
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
              SizedBox(height: AppSpacing.lg),
              CustomButton(
                text: 'Cancel subscription',
                onPressed: () async {
                  final auth = context.read<AuthProvider>();
                  final token = auth.token;
                  if (token == null || token.isEmpty) return;

                  try {
                    final res = await BillingService.cancelSubscription(token: token);
                    if (res['success'] == true) {
                      await _load();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Subscription will cancel at period end')),
                      );
                      return;
                    }
                    final message = res['message']?.toString() ?? 'Failed to cancel subscription';
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message), backgroundColor: AppColors.error),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_formatStripeError(e as Object)),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
                type: ButtonType.primary,
                isFullWidth: true,
              ),
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
    List<String> features, {
    required String priceId,
    bool isCurrent = false,
    bool isPopular = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isFreePlan = price <= 0;

    final accent = isCurrent ? colorScheme.primary : colorScheme.primary.withOpacity(0.85);
    final isSelected = _upgrading && _upgradingPriceId != null && _upgradingPriceId == priceId;
    final isDisabled = _upgrading && !isSelected;

    final baseBorderColor = isCurrent ? colorScheme.primary : colorScheme.outline.withOpacity(0.5);
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
          color: isDisabled ? colorScheme.surface.withOpacity(0.72) : colorScheme.surface,
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
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
            children: [
          // Header
          Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isPopular ? colorScheme.primary.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppBorderRadius.large),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: AppTypography.subtitle1.copyWith(
                        color: isCurrent ? colorScheme.primary : colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    if (isPopular) ...[
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: AppBorderRadius.allSmall,
                        ),
                        child: Text(
                          'POPULAR',
                          style: AppTypography.caption.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                
                SizedBox(height: AppSpacing.sm),
                
                Text(
                  description,
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: AppSpacing.md),
                
                Text(
                  price == 0.0 ? 'Free' : '\$${price.toStringAsFixed(2)}/month',
                  style: AppTypography.h3.copyWith(
                    color: isCurrent ? colorScheme.primary : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          
          // Features
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: List.generate(features.length, (i) {
                final feature = features[i];
                final child = _featureStep(
                  index: i,
                  total: features.length,
                  feature: feature,
                  accent: accent,
                  textColor: colorScheme.onSurface,
                  muted: colorScheme.onSurfaceVariant,
                );
                return Padding(
                  padding: EdgeInsets.only(bottom: i == features.length - 1 ? 0 : AppSpacing.md),
                  child: child,
                );
              }),
            ),
          ),
          
          // Action button
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: !isFreePlan
                ? SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: isCurrent ? 'Current Plan' : 'Upgrade to $name',
                      onPressed: isDisabled || isCurrent || (price > 0 && priceId.trim().isEmpty)
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
                                await _startInAppSubscription(token: token, priceId: priceId);
                                await _load();
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_formatStripeError(e as Object)),
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
                  )
                : const SizedBox.shrink(),
          ),
            ],
          ),
        ),
      ),
    );
  }
}
