import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/services/gameplay_progression_service.dart';

class ProgressionCardsScreen extends StatefulWidget {
  const ProgressionCardsScreen({super.key});
  @override
  State<ProgressionCardsScreen> createState() => _ProgressionCardsScreenState();
}

class _ProgressionCardsScreenState extends State<ProgressionCardsScreen> with SingleTickerProviderStateMixin {
  bool _loading = false;
  bool _minting = false;
  bool _settingWallet = false;
  Map<String, dynamic>? _me;
  List<Map<String, dynamic>> _cards = const [];
  bool _autoSynced = false;
  late final AnimationController _fx;

  @override
  void initState() {
    super.initState();
    _fx = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat();
    _load();
  }

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final meRes = await GameplayProgressionService.me(token: token);
      final cardsRes = await GameplayProgressionService.cards(token: token);
      if (!mounted) return;
      final data = cardsRes['data'];
      final arr = data is List ? data : (data is Map && data['cards'] is List ? data['cards'] as List : const []);
      setState(() {
        _me = (meRes['data'] is Map) ? Map<String, dynamic>.from(meRes['data'] as Map) : null;
        _cards = arr.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (e) {
      if (mounted) AppNotifier.showError('Load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncRewards() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    setState(() => _loading = true);
    try {
      await GameplayProgressionService.syncRewards(token: token);
      await _load();
    } catch (e) {
      if (mounted) AppNotifier.showError('Sync failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _testRun() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    final scoreCtl = TextEditingController(text: '1000');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Test Small Run (+250 XP)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: scoreCtl, 
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number, 
          decoration: const InputDecoration(labelText: 'Score', labelStyle: TextStyle(color: Colors.white70)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _loading = true);
    try {
      await GameplayProgressionService.finalizeRun(token: token, score: int.tryParse(scoreCtl.text) ?? 1000, durationSec: 60, projectId: 'test');
      await _load();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _mint(String cardId) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    setState(() => _minting = true);
    try {
      await GameplayProgressionService.mintCard(token: token, cardId: cardId);
      await _load();
    } finally {
      if (mounted) setState(() => _minting = false);
    }
  }

  Future<void> _setWalletDialog() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    final currentWallet = (_me?['walletAddress'] ?? '').toString().trim();
    final defaultWallet = (_me?['defaultWalletAddress'] ?? '').toString().trim();
    final walletCtl = TextEditingController(text: currentWallet.isNotEmpty ? currentWallet : defaultWallet);

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Connect Wallet'),
        content: TextField(controller: walletCtl, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (save != true) return;
    final address = walletCtl.text.trim();
    if (address.isEmpty) return;
    setState(() => _settingWallet = true);
    try {
      await GameplayProgressionService.setWalletAddress(token: token, address: address);
      await _load();
    } finally {
      setState(() => _settingWallet = false);
    }
  }

  Color _hexColor(String raw) {
    final s = raw.trim().replaceFirst('#', '');
    if (s.length != 6) return const Color(0xFF334155);
    return Color(int.parse('FF$s', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: AnimatedBuilder(
              animation: _fx,
              builder: (context, _) => Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.indigo.withOpacity(0.18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.22),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              color: Colors.cyanAccent,
              backgroundColor: const Color(0xFF1E293B),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    expandedHeight: 110,
                    floating: true,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      title: const Text(
                        '3D REWARD CARDS',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          fontSize: 16,
                        ),
                      ),
                      centerTitle: true,
                    ),
                    actions: [
                      IconButton(
                        onPressed: _loading ? null : _syncRewards,
                        icon: const Icon(Icons.sync_rounded, color: Colors.cyanAccent),
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _HeaderStats(me: _me, onSetWallet: _setWalletDialog, settingWallet: _settingWallet),
                          const SizedBox(height: 28),
                          _CollectionHeader(onTest: _testRun, loading: _loading),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  if (_loading && _cards.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.cyanAccent),
                      ),
                    )
                  else if (_cards.isEmpty)
                    const SliverFillRemaining(child: _EmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _Reward3DCard(
                            card: _cards[i],
                            index: i,
                            fx: _fx,
                            onMint: () => _mint(_cards[i]['key']),
                            minting: _minting,
                            colorFromHex: _hexColor,
                          ),
                          childCount: _cards.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStats extends StatelessWidget {
  final Map<String, dynamic>? me;
  final VoidCallback onSetWallet;
  final bool settingWallet;
  const _HeaderStats({this.me, required this.onSetWallet, required this.settingWallet});

  @override
  Widget build(BuildContext context) {
    final wallet = (me?['walletAddress'] ?? '').toString();
    final shortWallet = wallet.length > 10
        ? '${wallet.substring(0, 6)}...${wallet.substring(wallet.length - 4)}'
        : 'No wallet linked';

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _StatItem(label: 'LEVEL', value: '${me?['level'] ?? 1}', color: Colors.cyanAccent)),
                  Expanded(child: _StatItem(label: 'XP', value: '${me?['totalXp'] ?? 0}', color: Colors.amberAccent)),
                  Expanded(child: _StatItem(label: 'BEST', value: '${me?['bestScore'] ?? 0}', color: Colors.purpleAccent)),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Colors.white10),
              ),
              InkWell(
                onTap: settingWallet ? null : onSetWallet,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, size: 20, color: Colors.cyanAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          shortWallet,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (settingWallet)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                        )
                      else
                        const Icon(Icons.edit_rounded, size: 16, color: Colors.white38),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold)),
        FittedBox(child: Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900))),
      ],
    );
  }
}

class _CollectionHeader extends StatelessWidget {
  final VoidCallback onTest;
  final bool loading;
  const _CollectionHeader({required this.onTest, required this.loading});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.cyanAccent,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'MY COLLECTION',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: loading ? null : onTest,
          style: TextButton.styleFrom(
            foregroundColor: Colors.amberAccent,
            backgroundColor: Colors.amberAccent.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.bolt_rounded, size: 18),
          label: const Text('TEST RUN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_motion_rounded, size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          const Text(
            'YOUR VAULT IS EMPTY',
            style: TextStyle(
              color: Colors.white24,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Reward3DCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final int index;
  final Animation<double> fx;
  final VoidCallback onMint;
  final bool minting;
  final Color Function(String) colorFromHex;

  const _Reward3DCard({required this.card, required this.index, required this.fx, required this.onMint, required this.minting, required this.colorFromHex});

  IconData _iconForCard(String key, String rarity) {
    final k = key.toLowerCase();
    if (k.contains('best_score')) return Icons.emoji_events_rounded;
    if (k.contains('run')) return Icons.bolt_rounded;
    if (k.startsWith('xp_step_') || k.contains('xp')) return Icons.trending_up_rounded;
    if (k.contains('quiz')) return Icons.quiz_rounded;
    if (k.startsWith('title_')) return Icons.military_tech_rounded;
    if (rarity == 'legendary') return Icons.workspace_premium_rounded;
    if (rarity == 'epic') return Icons.local_fire_department_rounded;
    if (rarity == 'rare') return Icons.diamond_rounded;
    return Icons.sports_esports_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final rarity = (card['rarity'] ?? 'common').toString().toLowerCase();
    final art = card['art3d'] ?? {};
    final nft = card['nft'] is Map ? (card['nft'] as Map) : {};
    final status = (nft['status'] ?? 'eligible').toString();
    final key = (card['key'] ?? '').toString();

    final isHigh = rarity == 'rare' || rarity == 'epic' || rarity == 'legendary';
    final accentColor = rarity == 'legendary'
        ? Colors.amberAccent
        : (rarity == 'epic' ? Colors.purpleAccent : (rarity == 'rare' ? Colors.cyanAccent : Colors.blueGrey));

    return AnimatedBuilder(
      animation: fx,
      builder: (context, _) {
        final phase = (fx.value + (index * 0.15)) % 1.0;
        final floatY = math.sin(phase * math.pi * 2) * 6;

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Transform.translate(
            offset: Offset(0, floatY),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateX(0.07 * math.sin(phase * math.pi * 2))
                ..rotateY(-0.07 * math.cos(phase * math.pi * 2)),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    colors: [
                      colorFromHex(art['gradientA'] ?? '#1e293b'),
                      colorFromHex(art['gradientB'] ?? '#0f172a'),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: accentColor.withOpacity(isHigh ? 0.45 : 0.10),
                    width: isHigh ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(isHigh ? 0.18 : 0.06),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -30,
                        bottom: -30,
                        child: Opacity(
                          opacity: 0.06,
                          child: Icon(
                            _iconForCard(key, rarity),
                            size: 180,
                            color: Colors.white,
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
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.10),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _iconForCard(key, rarity),
                                    size: 22,
                                    color: accentColor,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (card['title'] ?? 'REWARD').toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                        ),
                                      ),
                                      Text(
                                        (card['subtitle'] ?? 'Milestone reached').toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: accentColor.withOpacity(0.35)),
                                  ),
                                  child: Text(
                                    rarity.toUpperCase(),
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'POWER',
                                      style: TextStyle(
                                        color: Colors.white24,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    Text(
                                      '${card['power'] ?? 0}',
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                if (status == 'eligible')
                                  FilledButton(
                                    onPressed: minting ? null : onMint,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: accentColor,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: const Text(
                                      'MINT',
                                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                                    ),
                                  )
                                else if (status == 'minted' || status == 'succeeded')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.verified_rounded, size: 16, color: Colors.greenAccent),
                                        SizedBox(width: 8),
                                        Text(
                                          'MINTED',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Text(
                                    status.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white24,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      letterSpacing: 1,
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
          ),
        );
      },
    );
  }
}
