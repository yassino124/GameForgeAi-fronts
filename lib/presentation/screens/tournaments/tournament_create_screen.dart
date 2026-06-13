import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/services/game_feed_service.dart';
import '../../../core/services/projects_service.dart';
import '../../../core/services/tournaments_service.dart';

class TournamentCreateScreen extends StatefulWidget {
  const TournamentCreateScreen({super.key});

  @override
  State<TournamentCreateScreen> createState() => _TournamentCreateScreenState();
}

class _TournamentCreateScreenState extends State<TournamentCreateScreen>
    with TickerProviderStateMixin {
  final _titleCtrl = TextEditingController(text: 'Weekly Challenge');
  final _coverCtrl = TextEditingController();

  final _searchCtrl = TextEditingController();

  final _entryFeeCtrl = TextEditingController(text: '100');
  final _maxPlayersCtrl = TextEditingController(text: '20');

  bool _loadingProjects = false;
  bool _loadingArcade = false;
  bool _creating = false;
  String? _error;

  List<Map<String, dynamic>> _projects = const [];
  List<Map<String, dynamic>> _arcadeGames = const [];
  String? _selectedProjectId;

  bool _loadingWallet = false;
  int? _walletCoins;
  final _topUpUsdCtrl = TextEditingController(text: '5');

  late final AnimationController _introCtrl;
  late final AnimationController _bgCtrl;

  String? get _token {
    try {
      final t = context.read<AuthProvider>().token;
      if (t == null || t.trim().isEmpty) return null;
      return t;
    } catch (_) {
      return null;
    }
  }

  String _arcadeProjectIdOf(Map<String, dynamic> p) => _asStr(p['projectId']);

  String _arcadeTitleOf(Map<String, dynamic> p) => _asStr(p['title'] ?? p['name'], 'Game');

  String _arcadeThumbOf(Map<String, dynamic> p) {
    return _asStr(p['previewImageUrl'] ?? p['previewImage'] ?? p['thumbnailUrl'], '');
  }

  String get _authUserId {
    try {
      final u = context.read<AuthProvider>().user;
      return (u?['id'] ?? u?['_id'] ?? u?['sub'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _introCtrl.forward(from: 0);
      await _loadProjects();
      await _loadArcadeGames();
      await _loadWallet();
    });
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _bgCtrl.dispose();
    _titleCtrl.dispose();
    _coverCtrl.dispose();
    _searchCtrl.dispose();
    _topUpUsdCtrl.dispose();
    _entryFeeCtrl.dispose();
    _maxPlayersCtrl.dispose();
    super.dispose();
  }

  int? _tryInt(String s) {
    final v = int.tryParse(s.trim());
    if (v == null) return null;
    return v;
  }

  String _asStr(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();

  Future<void> _loadProjects() async {
    final token = _token;
    if (token == null) {
      if (!mounted) return;
      setState(() => _error = 'Please sign in first');
      return;
    }

    setState(() {
      _loadingProjects = true;
      _error = null;
    });

    try {
      final res = await ProjectsService.listProjects(token: token);
      final data = res['data'];
      final items = data is List
          ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      String? nextSelected = _selectedProjectId;
      if (nextSelected == null || !items.any((p) => _asStr(p['id'] ?? p['_id']) == nextSelected)) {
        nextSelected = items.isNotEmpty ? _asStr(items.first['id'] ?? items.first['_id']) : null;
      }

      if (!mounted) return;
      setState(() {
        _projects = items;
        _selectedProjectId = nextSelected;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load projects');
    } finally {
      if (mounted) setState(() => _loadingProjects = false);
    }
  }

  Future<void> _loadArcadeGames() async {
    final token = _token;
    if (token == null) return;
    setState(() => _loadingArcade = true);
    try {
      final res = await GameFeedService.list(token: token, limit: 50);
      final data = res['data'];
      final raw = data is List
          ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      final map = <String, Map<String, dynamic>>{};
      for (final p in raw) {
        final projectId = (p['projectId'] ?? '').toString().trim();
        if (projectId.isEmpty) continue;
        if (map.containsKey(projectId)) continue;
        map[projectId] = p;
      }
      if (!mounted) return;
      setState(() => _arcadeGames = map.values.toList(growable: false));
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingArcade = false);
    }
  }

  Future<void> _loadWallet() async {
    final token = _token;
    final uid = _authUserId;
    if (token == null || uid.isEmpty) return;

    setState(() => _loadingWallet = true);
    try {
      final res = await TournamentsService.wallet(token: token, userId: uid);
      final data = res['data'] ?? res;
      final coins = (data is Map ? data['coins'] : null);
      final v = coins is num ? coins.toInt() : int.tryParse(coins?.toString() ?? '');
      if (!mounted) return;
      setState(() => _walletCoins = v ?? 0);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingWallet = false);
    }
  }

  double _tryDouble(String s) {
    final v = double.tryParse(s.trim());
    return v == null || !v.isFinite ? 0 : v;
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
    if (msg.startsWith('Exception: ')) return msg.replaceFirst('Exception: ', '');
    return msg;
  }

  Future<void> _topUpWithStripe() async {
    final token = _token;
    final uid = _authUserId;
    if (token == null || uid.isEmpty) return;

    final amountUsd = _tryDouble(_topUpUsdCtrl.text);
    if (amountUsd <= 0) {
      AppNotifier.showError('Enter amount in USD');
      return;
    }

    setState(() => _loadingWallet = true);
    HapticFeedback.mediumImpact();
    try {
      final pk = Stripe.publishableKey;
      if (pk.isEmpty) throw Exception('Missing Stripe publishable key');

      final res = await TournamentsService.topUpPaymentIntent(
        token: token,
        userId: uid,
        amountUsd: amountUsd,
      );
      final data = res['data'] ?? res;
      final map = data is Map ? Map<String, dynamic>.from(data as Map) : <String, dynamic>{};
      final clientSecret = (map['clientSecret'] ?? '').toString().trim();
      final paymentIntentId = (map['paymentIntentId'] ?? '').toString().trim();
      if (clientSecret.isEmpty || paymentIntentId.isEmpty) {
        throw Exception('Invalid PaymentIntent data from server');
      }

      final cs = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'GameForge AI',
          paymentIntentClientSecret: clientSecret,
          style: isDark ? ThemeMode.dark : ThemeMode.light,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              background: cs.surface,
              primary: cs.primary,
              componentBackground: cs.surface,
            ),
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      await TournamentsService.confirmTopUpPaymentIntent(
        token: token,
        paymentIntentId: paymentIntentId,
        userId: uid,
      );

      await _loadWallet();
      AppNotifier.showSuccess('Wallet funded');
    } catch (e) {
      AppNotifier.showError(_formatStripeError(e));
    } finally {
      if (mounted) setState(() => _loadingWallet = false);
    }
  }

  Widget _gameCard({
    required bool isDark,
    required String badge,
    required String id,
    required String title,
    required String thumb,
  }) {
    final active = id == _selectedProjectId;
    final borderC = (active ? const Color(0xFF38BDF8) : Colors.white)
        .withOpacity(active ? 0.42 : 0.10);
    return _PressScale(
      enabled: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).pop(id);
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderC),
            gradient: LinearGradient(
              colors: [
                (active ? const Color(0xFF38BDF8) : Colors.white)
                    .withOpacity(active ? 0.14 : (isDark ? 0.05 : 0.08)),
                Colors.transparent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withOpacity(0.20),
                      blurRadius: 26,
                      offset: const Offset(0, 16),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.35,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (thumb.trim().isNotEmpty)
                        Image.network(
                          thumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.white.withOpacity(isDark ? 0.04 : 0.08),
                            child: const Icon(
                              Icons.videogame_asset_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      else
                        Container(
                          color: Colors.white.withOpacity(isDark ? 0.04 : 0.08),
                          child: const Icon(
                            Icons.videogame_asset_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withOpacity(0.18)),
                            color: Colors.black.withOpacity(0.35),
                          ),
                          child: Text(
                            badge,
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (active)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF38BDF8).withOpacity(0.95),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body2.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    final token = _token;
    if (token == null) {
      AppNotifier.showError('Please sign in first');
      return;
    }
    final creatorId = _authUserId;
    if (creatorId.isEmpty) {
      AppNotifier.showError('Sign in required');
      return;
    }

    final gameId = (_selectedProjectId ?? '').trim();
    final title = _titleCtrl.text.trim();

    if (gameId.isEmpty) {
      AppNotifier.showError('Pick a project');
      return;
    }
    if (title.isEmpty) {
      AppNotifier.showError('Title is required');
      return;
    }

    final entryFee = _tryInt(_entryFeeCtrl.text);
    final maxPlayers = _tryInt(_maxPlayersCtrl.text);

    setState(() {
      _creating = true;
      _error = null;
    });

    HapticFeedback.mediumImpact();

    try {
      final res = await TournamentsService.createTournament(
        token: token,
        creatorId: creatorId,
        gameId: gameId,
        title: title,
        entryFee: entryFee,
        maxPlayers: maxPlayers,
        coverImageUrl: _coverCtrl.text.trim().isEmpty ? null : _coverCtrl.text.trim(),
      );

      final raw = res['data'] ?? res;
      final id = (raw is Map ? (raw['id'] ?? raw['_id'] ?? '') : '').toString().trim();
      if (id.isEmpty) {
        AppNotifier.showSuccess('Tournament created');
        if (!mounted) return;
        context.go('/tournaments');
        return;
      }

      HapticFeedback.lightImpact();
      AppNotifier.showSuccess('Tournament created');
      if (!mounted) return;
      context.go('/tournaments/$id');
    } catch (e) {
      AppNotifier.showError('Create failed');
      if (!mounted) return;
      setState(() => _error = 'Create failed. Make sure your wallet has coins (or enable demo mode).');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Map<String, dynamic>? get _selectedProject {
    final id = _selectedProjectId;
    if (id == null) return null;
    for (final p in _projects) {
      final pid = _asStr(p['id'] ?? p['_id']);
      if (pid == id) return p;
    }
    for (final g in _arcadeGames) {
      final pid = _arcadeProjectIdOf(g);
      if (pid == id) {
        return <String, dynamic>{
          'id': pid,
          'name': _arcadeTitleOf(g),
          'previewImageUrl': _arcadeThumbOf(g),
        };
      }
    }
    return null;
  }

  String _projectIdOf(Map<String, dynamic> p) => _asStr(p['id'] ?? p['_id']);

  String _projectNameOf(Map<String, dynamic> p) => _asStr(p['name'] ?? p['title'], 'Project');

  String _projectThumbOf(Map<String, dynamic> p) {
    return _asStr(
      p['previewImageUrl'] ?? p['previewImage'] ?? p['thumbnailUrl'] ?? p['coverImageUrl'],
      '',
    );
  }

  List<Map<String, dynamic>> _filteredProjects(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return _projects;
    return _projects.where((p) {
      final name = _projectNameOf(p).toLowerCase();
      final id = _projectIdOf(p).toLowerCase();
      return name.contains(query) || id.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _filteredArcade(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return _arcadeGames;
    return _arcadeGames.where((p) {
      final name = _arcadeTitleOf(p).toLowerCase();
      final id = _arcadeProjectIdOf(p).toLowerCase();
      return name.contains(query) || id.contains(query);
    }).toList();
  }

  Future<void> _openProjectPicker() async {
    if (_arcadeGames.isEmpty && _projects.isEmpty) return;
    HapticFeedback.selectionClick();
    _searchCtrl.text = '';

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(26),
            topRight: Radius.circular(26),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(isDark ? 0.92 : 0.96),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(26),
                  topRight: Radius.circular(26),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  final arcade = _filteredArcade(_searchCtrl.text);
                  final mine = _filteredProjects(_searchCtrl.text);

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Colors.white.withOpacity(0.10),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.grid_view_rounded, size: 18, color: AppColors.textSecondary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Choose a Game',
                                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _searchCtrl,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Search games…',
                                prefixIcon: const Icon(Icons.search_rounded),
                                filled: true,
                                fillColor: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: (arcade.isEmpty && mine.isEmpty)
                            ? Center(
                                child: Text(
                                  'No matches',
                                  style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (arcade.isNotEmpty) ...[
                                      Text(
                                        'ARCADE',
                                        style: AppTypography.caption.copyWith(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.1,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      GridView.builder(
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          childAspectRatio: 0.88,
                                        ),
                                        itemCount: arcade.length,
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemBuilder: (context, i) {
                                          final p = arcade[i];
                                          return _gameCard(
                                            isDark: isDark,
                                            badge: 'ARCADE',
                                            id: _arcadeProjectIdOf(p),
                                            title: _arcadeTitleOf(p),
                                            thumb: _arcadeThumbOf(p),
                                          );
                                        },
                                      ),
                                    ],

                                    if (mine.isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      Text(
                                        'YOUR PROJECTS',
                                        style: AppTypography.caption.copyWith(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.1,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      GridView.builder(
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          childAspectRatio: 0.88,
                                        ),
                                        itemCount: mine.length,
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemBuilder: (context, i) {
                                          final p = mine[i];
                                          return _gameCard(
                                            isDark: isDark,
                                            badge: 'PROJECT',
                                            id: _projectIdOf(p),
                                            title: _projectNameOf(p),
                                            thumb: _projectThumbOf(p),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (selected == null || selected.trim().isEmpty) return;
    setState(() => _selectedProjectId = selected);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    final selected = _selectedProject;
    final projectName = _asStr(selected?['name'] ?? selected?['title'], 'Project');
    final previewUrl = _asStr(selected?['previewImageUrl'] ?? selected?['previewImage'] ?? selected?['thumbnailUrl'], '');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Create Tournament'),
        actions: [
          IconButton(
            onPressed: _loadingProjects ? null : _loadProjects,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (context, _) {
              final t = _bgCtrl.value;
              final driftA = (math.sin(t * math.pi * 2) * 18);
              final driftB = (math.cos(t * math.pi * 2) * 16);
              return Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.background,
                              const Color(0xFF0B1220).withOpacity(isDark ? 0.35 : 0.10),
                              AppColors.background.withOpacity(0.92),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -140 + driftA,
                    right: -140 + driftB,
                    child: IgnorePointer(
                      child: _GlowBlob(
                        size: 460,
                        color: const Color(0xFF38BDF8).withOpacity(isDark ? 0.14 : 0.10),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -180 + driftB,
                    left: -120 - driftA,
                    child: IgnorePointer(
                      child: _GlowBlob(
                        size: 520,
                        color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.12 : 0.09),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: AnimatedBuilder(
              animation: _introCtrl,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(_introCtrl.value);
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 14),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      children: [
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.12),
                              border: Border.all(color: AppColors.error.withOpacity(0.25)),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.error),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: AppTypography.body2.copyWith(color: AppColors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: Colors.white.withOpacity(0.10)),
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF6A5CFF).withOpacity(0.16),
                                    const Color(0xFF38BDF8).withOpacity(0.10),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6A5CFF).withOpacity(0.12),
                                    blurRadius: 50,
                                    offset: const Offset(0, 26),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFF59E0B), Color(0xFF38BDF8)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFF59E0B).withOpacity(0.16),
                                              blurRadius: 22,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Creator Arena',
                                          style: AppTypography.titleLarge.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Pick a game, set the entry fee, and launch a ranked tournament. Payouts go to the winners\' Creator Wallet in USD.',
                                    style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        _section(
                          title: 'Core',
                          child: Column(
                            children: [
                              TextField(
                                controller: _titleCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Tournament title',
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _coverCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Cover image URL (optional)',
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                        _section(
                          title: 'Game',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Select a Project',
                                      style: AppTypography.body2.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  if (_loadingProjects)
                                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (_projects.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                                    color: AppColors.surface.withOpacity(0.62),
                                  ),
                                  child: Text(
                                    'No projects found. Create a project first, then come back.',
                                    style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
                                  ),
                                )
                              else
                                _PressScale(
                                  enabled: true,
                                  child: InkWell(
                                    onTap: _openProjectPicker,
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(color: Colors.white.withOpacity(0.10)),
                                        color: AppColors.surface.withOpacity(0.62),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              color: Colors.white.withOpacity(isDark ? 0.06 : 0.12),
                                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                                            ),
                                            child: const Icon(Icons.videogame_asset_rounded, size: 16, color: AppColors.textSecondary),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              projectName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.body2.copyWith(fontWeight: FontWeight.w900),
                                            ),
                                          ),
                                          const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              _previewCard(
                                isDark: isDark,
                                cs: cs,
                                title: _titleCtrl.text.trim().isEmpty ? 'Weekly Challenge' : _titleCtrl.text.trim(),
                                projectName: projectName,
                                previewUrl: previewUrl,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                        _section(
                          title: 'Rules',
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _entryFeeCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Entry fee (coins)',
                                    filled: true,
                                    fillColor: AppColors.surface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _maxPlayersCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Max players',
                                    filled: true,
                                    fillColor: AppColors.surface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                        _section(
                          title: 'Prize Wallet',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Balance',
                                      style: AppTypography.body2.copyWith(fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                  if (_loadingWallet)
                                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                  IconButton(
                                    onPressed: _loadingWallet ? null : _loadWallet,
                                    icon: const Icon(Icons.refresh_rounded),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                                  color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                                ),
                                child: Text(
                                  '${(_walletCoins ?? 0)} coins',
                                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Fund your tournament wallet via Stripe. Creating tournaments may require a funded wallet (production).',
                                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _topUpUsdCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: 'Amount USD',
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    height: 52,
                                    child: ElevatedButton.icon(
                                      onPressed: _loadingWallet ? null : _topUpWithStripe,
                                      icon: const Icon(Icons.payment_rounded),
                                      label: const Text('Top up'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        SizedBox(
                          height: 54,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF38BDF8), Color(0xFF6A5CFF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF38BDF8).withOpacity(0.18),
                                  blurRadius: 26,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: _PressScale(
                              enabled: !(_creating || _selectedProjectId == null || (_selectedProjectId ?? '').trim().isEmpty),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: (_creating || _selectedProjectId == null || (_selectedProjectId ?? '').trim().isEmpty) ? null : _create,
                                icon: _creating
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.rocket_launch_rounded),
                                label: Text(
                                  _creating ? 'Launching…' : 'Create Tournament',
                                  style: AppTypography.body2.copyWith(fontWeight: FontWeight.w900),
                                ),
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
        ],
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            color: AppColors.surface.withOpacity(0.60),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewCard({
    required bool isDark,
    required ColorScheme cs,
    required String title,
    required String projectName,
    required String previewUrl,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        color: Colors.black.withOpacity(isDark ? 0.26 : 0.05),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A5CFF).withOpacity(0.10),
            blurRadius: 34,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6A5CFF).withOpacity(0.18),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      color: Colors.white.withOpacity(isDark ? 0.06 : 0.12),
                    ),
                    child: previewUrl.trim().isEmpty
                        ? Icon(Icons.image_rounded, color: AppColors.textSecondary.withOpacity(0.9))
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              previewUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported_rounded, color: AppColors.textSecondary.withOpacity(0.9)),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body2.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          projectName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _pill('RANKED', const Color(0xFF38BDF8)),
                            _pill('PAYOUT USD', const Color(0xFFF59E0B)),
                          ],
                        ),
                      ],
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

  Widget _pill(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.30)),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _PressScale extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _PressScale({
    required this.child,
    required this.enabled,
  });

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled;
    final scale = active ? (_down ? 0.98 : 1.0) : 1.0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapUp: active ? (_) => setState(() => _down = false) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowBlob({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withOpacity(0.0),
            ],
          ),
        ),
      ),
    );
  }
}
