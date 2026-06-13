import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/services/tournaments_service.dart';

class TournamentDetailsScreen extends StatefulWidget {
  final String tournamentId;

  const TournamentDetailsScreen({
    super.key,
    required this.tournamentId,
  });

  @override
  State<TournamentDetailsScreen> createState() => _TournamentDetailsScreenState();
}

class _AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle style;
  final Duration duration;

  const _AnimatedCount({
    required this.value,
    required this.style,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Text(v.round().toString(), style: style);
      },
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
    final scale = active
        ? (_down ? 0.98 : 1.0)
        : 1.0;

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

class _winnerSpotlight extends StatelessWidget {
  final int rank;

  const _winnerSpotlight({required this.rank});

  @override
  Widget build(BuildContext context) {
    Color medal() {
      if (rank == 1) return const Color(0xFFF59E0B);
      if (rank == 2) return const Color(0xFFA1A1AA);
      return const Color(0xFFB45309);
    }

    final c = medal();
    final label = rank == 1 ? 'YOU ARE #1' : 'YOU ARE TOP $rank';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withOpacity(0.40)),
        gradient: LinearGradient(
          colors: [
            c.withOpacity(0.20),
            Colors.black.withOpacity(0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: c.withOpacity(0.14),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.withOpacity(0.18),
              border: Border.all(color: c.withOpacity(0.45)),
            ),
            child: Icon(
              rank == 1 ? Icons.workspace_premium_rounded : Icons.emoji_events_rounded,
              color: c,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            'Spotlight',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentDetailsScreenState extends State<TournamentDetailsScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _detail;
  String _playerName = 'Falcon42';

  bool _joining = false;

  Timer? _poll;

  late final AnimationController _revealCtrl;
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
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    );
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _revealCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
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

  String _publicShareLink() {
    try {
      final base = Uri.parse(ApiService.baseUrl);
      final origin = Uri(
        scheme: base.scheme,
        host: base.host,
        port: base.hasPort ? base.port : null,
      ).toString();
      return '$origin/tournaments/${widget.tournamentId}';
    } catch (_) {
      return 'https://gameforge.ai/tournaments/${widget.tournamentId}';
    }
  }

  Future<void> _openQrSheet() async {
    final link = _publicShareLink();
    HapticFeedback.selectionClick();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(26),
              topRight: Radius.circular(26),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(isDark ? 0.92 : 0.96),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(26),
                    topRight: Radius.circular(26),
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                        const Icon(Icons.qr_code_rounded, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Share Tournament',
                            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.10)),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF38BDF8).withOpacity(0.10),
                            const Color(0xFF6A5CFF).withOpacity(0.10),
                            Colors.transparent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white,
                        ),
                        child: QrImageView(
                          data: link,
                          size: 210,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Colors.black),
                          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Colors.black),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.10)),
                        color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                      ),
                      child: Text(
                        link,
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              Clipboard.setData(ClipboardData(text: link));
                              AppNotifier.showSuccess('Copied');
                            },
                            icon: const Icon(Icons.copy_rounded),
                            label: const Text('Copy'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Share.share(link);
                            },
                            icon: const Icon(Icons.ios_share_rounded),
                            label: const Text('Share'),
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
    );
  }

  Future<void> _load({bool silent = false}) async {
    final token = _token;
    if (token == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Please sign in first';
        _detail = null;
      });
      return;
    }

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final res = await TournamentsService.getTournament(token: token, tournamentId: widget.tournamentId);
      final raw = res['data'] ?? res;
      final map = raw is Map ? Map<String, dynamic>.from(raw as Map) : null;

      if (!mounted) return;
      setState(() {
        _detail = map;
        _error = null;
        _loading = false;
      });

      if (map != null) {
        _revealCtrl.forward(from: 0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load tournament';
        _loading = false;
      });
    }
  }

  Future<void> _join() async {
    final token = _token;
    if (token == null) return;
    final uid = _authUserId;
    if (uid.isEmpty) {
      AppNotifier.showError('Sign in required');
      return;
    }

    setState(() => _joining = true);

    try {
      await TournamentsService.join(
        token: token,
        tournamentId: widget.tournamentId,
        userId: uid,
        playerName: _playerName.trim().isEmpty ? uid : _playerName.trim(),
      );
      await _load();
      AppNotifier.showSuccess('Joined');
    } catch (_) {
      AppNotifier.showError('Join failed');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = _asStr(d?['title'], 'Tournament');
    final status = _asStr(d?['status'], 'waiting').toLowerCase();
    final entryFee = _asInt(d?['entryFee'], 0);
    final prizePool = _asInt(d?['prizePool'], 0);
    final playersCount = _asInt(d?['playersCount'], 0);
    final maxPlayers = _asInt(d?['maxPlayers'], 0);

    final leaderboard = (d?['leaderboardTop'] is List)
        ? (d!['leaderboardTop'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    final top3 = (d?['top3'] is List)
        ? (d!['top3'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

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
              top: -120 + driftA,
              right: -120 + driftB,
              child: IgnorePointer(
                child: _GlowBlob(
                  size: 420,
                  color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.13 : 0.10),
                ),
              ),
            ),
            Positioned(
              top: 120 - driftB,
              left: -140 + driftA,
              child: IgnorePointer(
                child: _GlowBlob(
                  size: 460,
                  color: const Color(0xFF38BDF8).withOpacity(isDark ? 0.12 : 0.09),
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
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _openQrSheet,
            icon: const Icon(Icons.qr_code_2_rounded),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          bg,
          _loading && d == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
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
                          Expanded(child: Text(_error!, style: AppTypography.body2.copyWith(color: AppColors.textPrimary))),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: AnimatedBuilder(
                    animation: _revealCtrl,
                    builder: (context, _) {
                      final t = Curves.easeOutCubic.transform(_revealCtrl.value);
                      return Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, (1 - t) * 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary.withOpacity(0.20),
                                      const Color(0xFF38BDF8).withOpacity(0.10),
                                      Colors.transparent,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.14),
                                      blurRadius: 48,
                                      offset: const Offset(0, 22),
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
                                                color: const Color(0xFFF59E0B).withOpacity(0.18),
                                                blurRadius: 22,
                                                offset: const Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Hero(
                                            tag: 'tour_title_${widget.tournamentId}',
                                            child: Material(
                                              type: MaterialType.transparency,
                                              child: Text(
                                                title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.titleLarge.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _pill(status.toUpperCase(), _statusColor(status)),
                                        _pill('ENTRY $entryFee', const Color(0xFFF59E0B)),
                                        _pill('POOL $prizePool', const Color(0xFF38BDF8)),
                                        _pill('PLAYERS $playersCount/$maxPlayers', const Color(0xFF22C55E)),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      onChanged: (v) => _playerName = v,
                                      decoration: InputDecoration(
                                        hintText: 'Nickname',
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _PressScale(
                                            enabled: status != 'finished' && !_joining,
                                            child: OutlinedButton.icon(
                                              onPressed: status == 'finished'
                                                  ? null
                                                  : (_joining
                                                      ? null
                                                      : () {
                                                          HapticFeedback.mediumImpact();
                                                          _join();
                                                        }),
                                              icon: _joining
                                                  ? const SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    )
                                                  : const Icon(Icons.person_add_alt_1_rounded),
                                              label: const Text('Join'),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _PressScale(
                                            enabled: d != null,
                                            child: ElevatedButton.icon(
                                              onPressed: d == null
                                                  ? null
                                                  : () {
                                                      HapticFeedback.lightImpact();
                                                      context.push('/tournaments/${widget.tournamentId}/play');
                                                    },
                                              icon: const Icon(Icons.play_arrow_rounded),
                                              label: const Text('Play'),
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
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      if (top3.isNotEmpty) ...[
                        Text(
                          'Top 3',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        AnimatedBuilder(
                          animation: _revealCtrl,
                          builder: (context, _) {
                            final t = Curves.easeOutBack.transform(_revealCtrl.value);
                            return Transform.scale(
                              scale: 0.98 + 0.02 * t,
                              child: Opacity(
                                opacity: (0.2 + 0.8 * _revealCtrl.value).clamp(0.0, 1.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 12,
                                      sigmaY: 12,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.10),
                                        ),
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFFF59E0B).withOpacity(0.10),
                                            const Color(0xFF38BDF8).withOpacity(0.06),
                                            Colors.transparent,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        color: AppColors.surface.withOpacity(0.55),
                                      ),
                                      child: _top3Podium(top3),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                      ],
                      Text(
                        'Leaderboard',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.white.withOpacity(0.10)),
                              color: AppColors.surface.withOpacity(0.62),
                            ),
                            child: leaderboard.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white.withOpacity(0.06),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.10),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.leaderboard_rounded,
                                            color: AppColors.textSecondary,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'No scores yet.',
                                            style: AppTypography.body2.copyWith(
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    children: leaderboard
                                        .take(10)
                                        .map((r) => _row(r))
                                        .toList(),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> r) {
    final rank = (r['rank'] ?? '').toString();
    final playerName = (r['playerName'] ?? '').toString();
    final score = (r['score'] ?? '').toString();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color medalColor(int n) {
      if (n == 1) return const Color(0xFFF59E0B);
      if (n == 2) return const Color(0xFFA1A1AA);
      if (n == 3) return const Color(0xFFB45309);
      return Colors.white.withOpacity(0.10);
    }

    final rankInt = int.tryParse(rank);
    final medal = (rankInt == null) ? null : medalColor(rankInt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
        gradient: rankInt == 1
            ? LinearGradient(
                colors: [
                  const Color(0xFFF59E0B).withOpacity(0.08),
                  Colors.transparent,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: medal?.withOpacity(0.18) ?? Colors.white.withOpacity(0.04),
                  border: Border.all(
                    color: medal?.withOpacity(0.40) ?? Colors.white.withOpacity(0.08),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#$rank',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w900,
                    color: medal == null ? AppColors.textSecondary : medal,
                  ),
                ),
              ),
              if (rankInt == 1)
                Positioned(
                  top: -8,
                  right: -8,
                  child: Transform.rotate(
                    angle: 0.3,
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              playerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body2.copyWith(
                color: rankInt == 1 ? const Color(0xFFF59E0B) : AppColors.textPrimary,
                fontWeight: rankInt != null && rankInt <= 3 ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            score,
            style: AppTypography.body2.copyWith(
              fontWeight: FontWeight.w900,
              color: rankInt == 1 ? const Color(0xFFF59E0B) : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _top3Podium(List<Map<String, dynamic>> top3) {
    Map<String, dynamic>? rowFor(int rank) {
      for (final r in top3) {
        if (_asInt(r['rank'], 0) == rank) return r;
      }
      return null;
    }

    Color medal(int rank) {
      if (rank == 1) return const Color(0xFFF59E0B);
      if (rank == 2) return const Color(0xFFA1A1AA);
      return const Color(0xFFB45309);
    }

    Widget tile(int rank, double heightFactor, double tileW) {
      final r = rowFor(rank);
      final name = _asStr(r?['playerName'], '—');
      final coinsWon = r?['coinsWon'];
      final coins = coinsWon == null ? '' : coinsWon.toString();
      final c = medal(rank);

      return Expanded(
        child: TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 520 + rank * 120),
          tween: Tween(begin: 0, end: 1),
          curve: Curves.easeOutBack,
          builder: (context, t, child) {
            final o = (t).clamp(0.0, 1.0);
            return Opacity(
              opacity: o,
              child: Transform.translate(
                offset: Offset(0, (1 - o) * 14),
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (rank == 1)
                const Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 24),
              const SizedBox(height: 4),
              Container(
                width: tileW,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: c.withOpacity(0.35)),
                  gradient: LinearGradient(
                    colors: [c.withOpacity(0.18), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.withOpacity(0.12),
                        border: Border.all(color: c.withOpacity(0.24), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: c.withOpacity(0.15),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$rank',
                        style: AppTypography.titleLarge.copyWith(
                          color: c,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        name,
                        style: AppTypography.body2.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (coins.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$coins coins',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final gap = 10.0;
        final tileW = ((w - gap * 2) / 3).clamp(90.0, 140.0);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            tile(2, 0.86, tileW),
            const SizedBox(width: 10),
            tile(1, 1.06, tileW),
            const SizedBox(width: 10),
            tile(3, 0.78, tileW),
          ],
        );
      },
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

  Widget _pillWidget(Color c, Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.30)),
      ),
      child: DefaultTextStyle(
        style: AppTypography.caption.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
        child: child,
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'active') return const Color(0xFF10B981);
    if (s == 'finished') return const Color(0xFFA1A1AA);
    return const Color(0xFFF59E0B);
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
