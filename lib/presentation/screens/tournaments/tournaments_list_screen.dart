import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/services/tournaments_service.dart';

class TournamentsListScreen extends StatefulWidget {
  const TournamentsListScreen({super.key});

  @override
  State<TournamentsListScreen> createState() => _TournamentsListScreenState();
}

class _TournamentsListScreenState extends State<TournamentsListScreen>
    with TickerProviderStateMixin {
  String _tab = 'active';
  bool _joinedOnly = false;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  Timer? _tick;
  int _nowMs = DateTime.now().millisecondsSinceEpoch;

  late final AnimationController _pulseCtrl;
  late final AnimationController _bgCtrl;

  String get _statusQuery {
    if (_tab == 'upcoming') return 'waiting';
    if (_tab == 'past') return 'finished';
    return 'active';
  }

  String? get _token {
    try {
      final t = context.read<AuthProvider>().token;
      if (t == null || t.trim().isEmpty) return null;
      return t;
    } catch (_) {
      return null;
    }
  }

  String get _authUserId {
    try {
      final u = context.read<AuthProvider>().user;
      final id = (u?['id'] ?? u?['_id'] ?? u?['sub'] ?? '').toString().trim();
      return id;
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _nowMs = DateTime.now().millisecondsSinceEpoch);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pulseCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _error = 'Please sign in first';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await TournamentsService.listTournaments(
        token: token,
        status: _statusQuery,
        userId: _joinedOnly && _authUserId.isNotEmpty ? _authUserId : null,
      );

      final data = res['data'];
      final list = data is List
          ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _error = 'Failed to load tournaments';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _asInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  String _asStr(dynamic v, [String fallback = '']) {
    return v == null ? fallback : v.toString();
  }

  String _fmtCountdown(int endsAtMs) {
    final ms = (endsAtMs - _nowMs).clamp(0, 1 << 62);
    final totalSec = (ms / 1000).floor();
    final hh = totalSec ~/ 3600;
    final mm = (totalSec % 3600) ~/ 60;
    final ss = totalSec % 60;
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(hh)}:${pad(mm)}:${pad(ss)}';
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'active') return const Color(0xFF10B981);
    if (s == 'finished') return const Color(0xFFA1A1AA);
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = AnimatedBuilder(
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
              left: -120 + driftB,
              child: IgnorePointer(
                child: _GlowBlob(
                  size: 380,
                  color: const Color(0xFF38BDF8).withOpacity(isDark ? 0.16 : 0.14),
                ),
              ),
            ),
            Positioned(
              top: 160 - driftB,
              right: -160 + driftA,
              child: IgnorePointer(
                child: _GlowBlob(
                  size: 420,
                  color: const Color(0xFF6A5CFF).withOpacity(isDark ? 0.14 : 0.12),
                ),
              ),
            ),
            Positioned(
              bottom: -180 + driftB,
              left: 40 - driftA,
              child: IgnorePointer(
                child: _GlowBlob(
                  size: 460,
                  color: const Color(0xFF10B981).withOpacity(isDark ? 0.10 : 0.08),
                ),
              ),
            ),
          ],
        );
      },
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: AppColors.primary),
            SizedBox(width: AppSpacing.sm),
            Text('Tournaments'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          bg,
          Column(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.12),
                      border: Border.all(color: AppColors.error.withOpacity(0.25)),
                      borderRadius: BorderRadius.circular(16),
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
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 520),
                  tween: Tween(begin: 0, end: 1),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, child) {
                    return Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(0, (1 - v) * 10),
                        child: child,
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(isDark ? 0.20 : 0.04),
                          border: Border.all(
                            color: Colors.white.withOpacity(isDark ? 0.10 : 0.14),
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            _pillTab('active', 'Active'),
                            const SizedBox(width: 10),
                            _pillTab('upcoming', 'Upcoming'),
                            const SizedBox(width: 10),
                            _pillTab('past', 'Past'),
                            const Spacer(),
                            InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _joinedOnly = !_joinedOnly);
                                _load();
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: _joinedOnly
                                      ? AppColors.primary.withOpacity(0.14)
                                      : AppColors.surface,
                                  border: Border.all(
                                    color: (_joinedOnly
                                            ? AppColors.primary
                                            : AppColors.textSecondary)
                                        .withOpacity(_joinedOnly ? 0.35 : 0.18),
                                  ),
                                ),
                                child: Text(
                                  (_joinedOnly ? 'Joined' : 'All').toUpperCase(),
                                  style: AppTypography.caption.copyWith(
                                    color: _joinedOnly
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
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

              if (_loading && _items.isEmpty)
                Expanded(
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, _) {
                      final p = 0.55 + 0.45 * _pulseCtrl.value;
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: 6,
                        itemBuilder: (context, i) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            height: 118,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.white.withOpacity(0.10)),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(isDark ? 0.05 * p : 0.09 * p),
                                  Colors.white.withOpacity(isDark ? 0.02 : 0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      color: Colors.white.withOpacity(
                                        isDark ? 0.06 * p : 0.14 * p,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 14,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(999),
                                            color: Colors.white.withOpacity(
                                              isDark ? 0.06 * p : 0.14 * p,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          height: 12,
                                          width: 160,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(999),
                                            color: Colors.white.withOpacity(
                                              isDark ? 0.04 * p : 0.11 * p,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Row(
                                          children: [
                                            Container(
                                              height: 10,
                                              width: 70,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(999),
                                                color: Colors.white.withOpacity(
                                                  isDark ? 0.04 * p : 0.11 * p,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              height: 10,
                                              width: 96,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(999),
                                                color: Colors.white.withOpacity(
                                                  isDark ? 0.04 * p : 0.11 * p,
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
                      );
                    },
                  ),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 66,
                                    height: 66,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary.withOpacity(0.14),
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(0.22),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.emoji_events_rounded,
                                      color: AppColors.primary,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'No tournaments found',
                                    style: AppTypography.titleMedium.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Try switching tabs or create a new tournament.',
                                    style: AppTypography.body2.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 14),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      context.push('/tournaments/create');
                                    },
                                    icon: const Icon(Icons.rocket_launch_rounded),
                                    label: const Text('Create'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final t = _items[index];
                              final id = _asStr(t['id'] ?? t['_id']);
                              final title = _asStr(t['title'], 'Tournament');
                              final coverUrl = _asStr(
                                t['coverImageUrl'] ?? t['coverUrl'] ?? t['cover'] ?? t['thumbnailUrl'],
                                '',
                              );
                              final status = _asStr(t['status'], 'waiting');
                              final entryFee = _asInt(t['entryFee'], 0);
                              final prizePool = _asInt(t['prizePool'], 0);
                              final playersCount = _asInt(t['playersCount'], 0);
                              final maxPlayers = _asInt(t['maxPlayers'], 0);
                              final endsAt = _asInt(t['endsAt'], 0);
                              final fillPct = maxPlayers > 0
                                  ? (playersCount / maxPlayers).clamp(0.0, 1.0)
                                  : 0.0;

                              final sc = _statusColor(status);

                              return TweenAnimationBuilder<double>(
                                duration: Duration(milliseconds: 420 + (index * 70)),
                                tween: Tween(begin: 0, end: 1),
                                curve: Curves.easeOutCubic,
                                builder: (context, v, child) {
                                  return Opacity(
                                    opacity: v,
                                    child: Transform.translate(
                                      offset: Offset(0, (1 - v) * 14),
                                      child: child,
                                    ),
                                  );
                                },
                                child: AnimatedBuilder(
                                  animation: _pulseCtrl,
                                  builder: (context, _) {
                                    final pulse = 0.6 + 0.4 * _pulseCtrl.value;
                                    final glow = sc.withOpacity(
                                      status.toLowerCase().trim() == 'active' ? 0.18 * pulse : 0.10,
                                    );
                                    final isActive = status.toLowerCase().trim() == 'active';
                                    return InkWell(
                                      onTap: () => context.push('/tournaments/$id'),
                                      borderRadius: BorderRadius.circular(24),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(color: Colors.white.withOpacity(0.10)),
                                          color: AppColors.surface.withOpacity(0.65),
                                          boxShadow: [
                                            BoxShadow(
                                              color: glow,
                                              blurRadius: 42,
                                              offset: const Offset(0, 22),
                                            ),
                                            BoxShadow(
                                              color: Colors.black.withOpacity(isDark ? 0.55 : 0.14),
                                              blurRadius: 26,
                                              offset: const Offset(0, 16),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(24),
                                          child: Stack(
                                            children: [
                                              if (coverUrl.trim().isNotEmpty)
                                                Positioned.fill(
                                                  child: IgnorePointer(
                                                    child: Opacity(
                                                      opacity: 0.16,
                                                      child: ImageFiltered(
                                                        imageFilter: ImageFilter.blur(
                                                          sigmaX: 18,
                                                          sigmaY: 18,
                                                        ),
                                                        child: Image.network(
                                                          coverUrl,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              Positioned.fill(
                                                child: IgnorePointer(
                                                  child: Opacity(
                                                    opacity: 0.95,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [
                                                            sc.withOpacity(0.14),
                                                            Colors.transparent,
                                                          ],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(16),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    if (coverUrl.trim().isNotEmpty) ...[
                                                      Stack(
                                                        clipBehavior: Clip.none,
                                                        children: [
                                                          Container(
                                                            width: 72,
                                                            height: 72,
                                                            decoration: BoxDecoration(
                                                              borderRadius: BorderRadius.circular(18),
                                                              border: Border.all(
                                                                color: sc.withOpacity(
                                                                  isActive ? (0.28 + 0.22 * pulse) : 0.35,
                                                                ),
                                                              ),
                                                              color: Colors.white.withOpacity(isDark ? 0.06 : 0.12),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: sc.withOpacity(isActive ? 0.14 * pulse : 0.18),
                                                                  blurRadius: 26,
                                                                  offset: const Offset(0, 14),
                                                                ),
                                                              ],
                                                            ),
                                                            child: ClipRRect(
                                                              borderRadius: BorderRadius.circular(18),
                                                              child: Image.network(
                                                                coverUrl,
                                                                fit: BoxFit.cover,
                                                                errorBuilder: (_, __, ___) => Icon(
                                                                  Icons.image_not_supported_rounded,
                                                                  color: AppColors.textSecondary.withOpacity(0.9),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          if (isActive)
                                                            Positioned(
                                                              top: -8,
                                                              left: -8,
                                                              child: Container(
                                                                width: 28,
                                                                height: 28,
                                                                decoration: BoxDecoration(
                                                                  shape: BoxShape.circle,
                                                                  color: const Color(0xFFF59E0B).withOpacity(0.22),
                                                                  border: Border.all(
                                                                    color: const Color(0xFFF59E0B).withOpacity(0.38),
                                                                  ),
                                                                  boxShadow: [
                                                                    BoxShadow(
                                                                      color: const Color(0xFFF59E0B).withOpacity(0.18 * pulse),
                                                                      blurRadius: 18,
                                                                      offset: const Offset(0, 10),
                                                                    ),
                                                                  ],
                                                                ),
                                                                child: const Icon(
                                                                  Icons.workspace_premium_rounded,
                                                                  size: 16,
                                                                  color: Color(0xFFF59E0B),
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 12),
                                                    ],
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Hero(
                                                            tag: 'tour_title_$id',
                                                            flightShuttleBuilder: (context, animation, direction, from, to) {
                                                              return DefaultTextStyle(
                                                                style: AppTypography.titleLarge.copyWith(
                                                                  fontWeight: FontWeight.w900,
                                                                  color: AppColors.textPrimary,
                                                                ),
                                                                child: to.widget,
                                                              );
                                                            },
                                                            child: Material(
                                                              type: MaterialType.transparency,
                                                              child: Text(
                                                                title,
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: AppTypography.titleMedium.copyWith(
                                                                  fontWeight: FontWeight.w900,
                                                                  color: AppColors.textPrimary,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 6,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: sc.withOpacity(0.14),
                                                            borderRadius: BorderRadius.circular(999),
                                                            border: Border.all(color: sc.withOpacity(0.38)),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text(
                                                                status.toUpperCase(),
                                                                style: AppTypography.caption.copyWith(
                                                                  color: sc,
                                                                  fontWeight: FontWeight.w900,
                                                                  letterSpacing: 1.0,
                                                                ),
                                                              ),
                                                              const SizedBox(width: 6),
                                                              Icon(
                                                                Icons.chevron_right_rounded,
                                                                size: 18,
                                                                color: sc,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    children: [
                                                      _statChip(
                                                        Icons.attach_money_rounded,
                                                        '${entryFee.toString()} entry',
                                                        tint: sc,
                                                      ),
                                                      _statChip(
                                                        Icons.emoji_events_rounded,
                                                        '${prizePool.toString()} pool',
                                                        tint: sc,
                                                      ),
                                                      _statChip(
                                                        Icons.groups_rounded,
                                                        '$playersCount/$maxPlayers',
                                                        tint: sc,
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 14),
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(999),
                                                    child: LinearProgressIndicator(
                                                      value: fillPct,
                                                      minHeight: 8,
                                                      backgroundColor: Colors.white.withOpacity(0.08),
                                                      valueColor: AlwaysStoppedAnimation<Color>(sc.withOpacity(0.92)),
                                                    ),
                                                  ),
                                                  if (endsAt > 0) ...[
                                                    const SizedBox(height: 10),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: sc.withOpacity(0.08),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: sc.withOpacity(0.15)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.timer_outlined, size: 12, color: sc),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            'Ends in ${_fmtCountdown(endsAt)}',
                                                            style: AppTypography.caption.copyWith(
                                                              color: sc,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
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
                            );
                          },
                        ),
            ),
          ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.selectionClick();
          context.push('/tournaments/create');
        },
        icon: const Icon(Icons.rocket_launch_rounded),
        label: const Text('Create'),
      ),
    );
  }

  Widget _pillTab(String key, String label) {
    final active = _tab == key;
    final c = active ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      onTap: () {
        if (_tab == key) return;
        setState(() => _tab = key);
        _load();
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: active ? AppColors.primary.withOpacity(0.14) : AppColors.surface,
          border: Border.all(color: c.withOpacity(active ? 0.35 : 0.18)),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: active ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String text, {Color? tint}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: (tint ?? Colors.white).withOpacity(tint == null ? 0.05 : 0.08),
        border: Border.all(
          color: (tint ?? Colors.white)
              .withOpacity(tint == null ? 0.08 : 0.18),
        ),
        boxShadow: tint == null
            ? null
            : [
                BoxShadow(
                  color: tint.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: tint == null ? AppColors.textSecondary : tint,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
