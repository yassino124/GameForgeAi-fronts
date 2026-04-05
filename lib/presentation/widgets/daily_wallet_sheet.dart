import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/services/app_notifier.dart';
import '../../core/services/daily_rewards_service.dart';
import '../../core/themes/app_theme.dart';

class DailyWalletSheet extends StatefulWidget {
  final String token;
  const DailyWalletSheet({super.key, required this.token});

  @override
  State<DailyWalletSheet> createState() => _DailyWalletSheetState();
}

class _DailyWalletSheetState extends State<DailyWalletSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await DailyRewardsService.wallet(token: widget.token);
      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        final list = (data['items'] is List) ? (data['items'] as List) : const [];
        setState(() {
          _items = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          _loading = false;
        });
        return;
      }
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _titleFor(Map<String, dynamic> it) {
    final kind = (it['kind'] ?? '').toString();
    final v = (it['value'] is num) ? (it['value'] as num).toInt() : int.tryParse(it['value']?.toString() ?? '') ?? 0;
    if (kind == 'discount_templates') return '$v% OFF Template';
    if (kind == 'discount_subscription') return '$v% OFF Subscription';
    if (kind == 'free_pro_day') return 'Free Pro Day (24h)';
    if (kind == 'rare_template') return 'Rare Template';
    if (kind == 'exclusive_asset_pack') return 'Exclusive Asset Pack';
    return kind.toUpperCase();
  }

  IconData _iconFor(String kind) {
    if (kind == 'discount_templates') return Icons.local_offer_rounded;
    if (kind == 'discount_subscription') return Icons.discount_rounded;
    if (kind == 'free_pro_day') return Icons.workspace_premium_rounded;
    if (kind == 'rare_template') return Icons.auto_awesome_rounded;
    if (kind == 'exclusive_asset_pack') return Icons.inventory_rounded;
    return Icons.card_giftcard_rounded;
  }

  Future<void> _redeem(Map<String, dynamic> it) async {
    final id = (it['id'] ?? '').toString().trim();
    if (id.isEmpty) return;
    try {
      final res = await DailyRewardsService.redeem(token: widget.token, walletItemId: id);
      if (!mounted) return;
      if (res['success'] == true) {
        AppNotifier.showSuccess('Redeemed');
        await _load();
        return;
      }
      AppNotifier.showError(res['message']?.toString() ?? 'Redeem failed');
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.10), width: 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 40, offset: const Offset(0, 24))],
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
                      Text('REWARD WALLET', style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: const [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Loading…'),
                        ],
                      ),
                    )
                  else if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text('No rewards yet. Spin & open boxes to win.', style: AppTypography.body2.copyWith(color: Colors.white70)),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 420),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final it = _items[i];
                          final kind = (it['kind'] ?? '').toString();
                          final status = (it['status'] ?? '').toString();
                          final redeemable = status == 'available' && kind == 'free_pro_day';
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: cs.surface.withOpacity(0.10),
                              border: Border.all(color: Colors.white.withOpacity(0.10)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: AppColors.primaryGradient,
                                  ),
                                  child: Icon(_iconFor(kind), color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_titleFor(it), style: AppTypography.subtitle1.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 4),
                                      Text(
                                        status == 'available'
                                            ? (kind == 'discount_templates'
                                                ? 'Auto-applies at checkout.'
                                                : kind == 'discount_subscription'
                                                    ? 'Auto-applies when subscribing.'
                                                    : kind == 'free_pro_day'
                                                        ? 'Tap redeem to activate.'
                                                        : 'Available')
                                            : status,
                                        style: AppTypography.caption.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (redeemable)
                                  SizedBox(
                                    height: 40,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _redeem(it),
                                          borderRadius: BorderRadius.circular(14),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                            child: Center(
                                              child: Text('REDEEM', style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Icon(Icons.lock_open_rounded, color: Colors.white.withOpacity(0.45)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
                      label: Text('REFRESH', style: AppTypography.labelLarge.copyWith(color: Colors.white70, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
