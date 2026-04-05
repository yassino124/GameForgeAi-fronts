import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/claude_game_service.dart';
import '../../widgets/widgets.dart';

class AiClaudeGameScreen extends StatefulWidget {
  const AiClaudeGameScreen({super.key});

  @override
  State<AiClaudeGameScreen> createState() => _AiClaudeGameScreenState();
}

class _AiClaudeGameScreenState extends State<AiClaudeGameScreen>
    with TickerProviderStateMixin {
  // ─── Controllers ────────────────────────────────────────────────────────
  final _promptCtrl = TextEditingController();

  // ─── Generation state ────────────────────────────────────────────────────
  bool _creating = false;
  String? _error;

  String? _gameId;
  String _status = 'idle';
  String? _playUrl;
  String? _gameTitle;
  String? _gameDescription;
  bool _usedFallback = false;
  String? _fallbackType;

  String _selectedStyle = 'auto';

  Timer? _pollTimer;

  // ─── Animations ──────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  // ─── Prompt suggestions ──────────────────────────────────────────────────
  static const _suggestions = [
    '🚀 A space shooter — destroy alien invaders and collect power-ups',
    '🧟 A zombie survival — dodge zombie hordes at night in a neon city',
    '🏃 A dog runner — cute dog jumps over obstacles and collects bones',
    '⚔️ A knight platformer — collect gems and stomp enemies on platforms',
    '🐍 A neon snake game — eat glowing fruits and grow longer',
    '🧱 A brick breaker — destroy all bricks with power-up paddles',
    '🌑 An asteroids shooter — rotate your ship and blast space rocks',
    '🐦 A flappy bird in space — dodge meteor pipes',
    '🏎️ A racing game — dodge traffic in 3 lanes at high speed',
    '🏓 A neon pong — face an AI opponent in a glowing arena',
  ];

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _promptCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ─── Polling ─────────────────────────────────────────────────────────────

  Future<void> _startPoll() async {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollOnce());
    await _pollOnce();
  }

  Future<void> _pollOnce() async {
    final token = context.read<AuthProvider>().token;
    final gid = _gameId;
    if (token == null || token.isEmpty || gid == null || gid.isEmpty) return;

    try {
      final res = await ClaudeGameService.status(token: token, gameId: gid);
      if (!mounted) return;

      final data = res['data'];
      if (data is! Map) return;

      final status = data['status']?.toString();
      final playUrl = data['playUrl']?.toString();
      final err = data['error']?.toString();
      final title = data['title']?.toString();
      final desc = data['description']?.toString();
      final usedFallback = data['usedFallback'] == true;
      final fallbackType = data['fallbackType']?.toString();

      if (res['success'] == true && status != null) {
        setState(() {
          _status = status;
          _playUrl = playUrl;
          if (title != null && title.trim().isNotEmpty) _gameTitle = title.trim();
          if (desc != null && desc.trim().isNotEmpty) _gameDescription = desc.trim();
          _usedFallback = usedFallback;
          _fallbackType = fallbackType;
          if (status == 'failed' && err != null && err.trim().isNotEmpty) {
            _error = err.trim();
          }
        });

        if (status == 'ready' && playUrl != null && playUrl.trim().isNotEmpty) {
          _pollTimer?.cancel();
          if (mounted) {
            context.push('/play-webgl', extra: {'url': playUrl.trim()});
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  // ─── Generate ─────────────────────────────────────────────────────────────

  Future<void> _generate() async {
    if (_creating) return;

    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) {
      setState(() => _error = 'Please enter a prompt describing your game.');
      return;
    }

    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Session expired. Please sign in again.');
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
      _gameId = null;
      _status = 'queued';
      _playUrl = null;
      _gameTitle = null;
      _gameDescription = null;
      _usedFallback = false;
      _fallbackType = null;
    });

    try {
      final res = await ClaudeGameService.generate(
        token: token,
        prompt: prompt,
        style: _selectedStyle,
      );
      if (!mounted) return;

      final data = res['data'];
      final gid = (data is Map) ? data['gameId']?.toString() : null;

      if (res['success'] == true && gid != null && gid.trim().isNotEmpty) {
        setState(() {
          _gameId = gid.trim();
          _status = (data is Map ? data['status']?.toString() : null) ?? 'queued';
        });
        await _startPoll();
        return;
      }

      setState(() {
        _error = res['message']?.toString() ?? 'Failed to start generation.';
        _status = 'idle';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _status = 'idle';
      });
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _reset() {
    _pollTimer?.cancel();
    setState(() {
      _creating = false;
      _error = null;
      _gameId = null;
      _status = 'idle';
      _playUrl = null;
      _gameTitle = null;
      _gameDescription = null;
      _usedFallback = false;
      _fallbackType = null;
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  bool get _isRunning => _status == 'queued' || _status == 'running';

  String get _statusLabel {
    switch (_status) {
      case 'queued':
        return 'Queued — waiting to start…';
      case 'running':
        return 'Claude is writing your game…';
      case 'ready':
        return 'Game ready! 🎮';
      case 'failed':
        return 'Generation failed';
      default:
        return 'Ready to generate';
    }
  }

  Color _statusColor(ColorScheme cs) {
    switch (_status) {
      case 'ready':
        return const Color(0xFF22C55E);
      case 'failed':
        return AppColors.error;
      case 'running':
      case 'queued':
        return cs.primary;
      default:
        return cs.onSurfaceVariant;
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(cs),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProviderBadge(cs),
            const SizedBox(height: AppSpacing.xl),
            if (_error != null) ...[
              _buildErrorBanner(cs),
              const SizedBox(height: AppSpacing.lg),
            ],
            _buildPromptSection(cs),
            const SizedBox(height: AppSpacing.lg),
            _buildStylePicker(cs),
            const SizedBox(height: AppSpacing.xl),
            _buildSuggestions(cs),
            const SizedBox(height: AppSpacing.xl),
            _buildGenerateButton(cs),
            const SizedBox(height: AppSpacing.lg),
            _buildStatusCard(cs),
            if (_gameTitle != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildGameInfoCard(cs),
            ],
            if (_playUrl != null && _status == 'ready') ...[
              const SizedBox(height: AppSpacing.lg),
              _buildPlayButton(cs),
            ],
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  AppBar _buildAppBar(ColorScheme cs) {
    return AppBar(
      backgroundColor: cs.surface,
      elevation: 0,
      leading: IconButton(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/dashboard'),
        icon: Icon(Icons.arrow_back, color: cs.onSurface),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6A5CFF), Color(0xFFAA44FF)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Text('Claude Game Generator', style: AppTypography.subtitle1),
        ],
      ),
      actions: [
        if (_status != 'idle')
          IconButton(
            onPressed: _reset,
            icon: Icon(Icons.refresh_rounded, color: cs.onSurfaceVariant),
            tooltip: 'New game',
          ),
      ],
    );
  }

  // ─── Provider badge ───────────────────────────────────────────────────────

  Widget _buildProviderBadge(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6A5CFF).withOpacity(0.15),
            const Color(0xFFAA44FF).withOpacity(0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(
          color: const Color(0xFF6A5CFF).withOpacity(0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.psychology_rounded, color: Color(0xFF6A5CFF), size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Powered by Claude — generates spec + full Phaser 3 JS',
              style: AppTypography.caption.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Error banner ─────────────────────────────────────────────────────────

  Widget _buildErrorBanner(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: AppColors.error.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: AppTypography.body2.copyWith(color: cs.onSurface),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: Icon(Icons.close_rounded,
                color: cs.onSurfaceVariant, size: 16),
          ),
        ],
      ),
    );
  }

  // ─── Prompt input ─────────────────────────────────────────────────────────

  Widget _buildPromptSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.edit_rounded, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text('Game Prompt', style: AppTypography.subtitle2),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _promptCtrl,
          minLines: 4,
          maxLines: 10,
          enabled: !_isRunning,
          decoration: InputDecoration(
            hintText:
                'Describe your game — genre, theme, mechanics, style…\n'
                'e.g. "A neon space shooter where you dodge asteroids"',
            hintStyle: AppTypography.body2
                .copyWith(color: cs.onSurfaceVariant.withOpacity(0.6)),
          ),
        ),
      ],
    );
  }

  // ─── Style picker ─────────────────────────────────────────────────────────

  Widget _buildStylePicker(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune_rounded, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text('Style Preference', style: AppTypography.subtitle2),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _styleChip('auto', '🤖 Auto (Claude decides)', cs),
            const SizedBox(width: 8),
            _styleChip('2d', '📐 2D', cs),
            const SizedBox(width: 8),
            _styleChip('3d', '🎲 3D', cs),
          ],
        ),
      ],
    );
  }

  Widget _styleChip(String value, String label, ColorScheme cs) {
    final selected = _selectedStyle == value;
    return GestureDetector(
      onTap: _isRunning ? null : () => setState(() => _selectedStyle = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF6A5CFF), Color(0xFFAA44FF)],
                )
              : null,
          color: selected ? null : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF6A5CFF)
                : cs.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? Colors.white : cs.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ─── Suggestions ──────────────────────────────────────────────────────────

  Widget _buildSuggestions(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text('Quick Prompts', style: AppTypography.subtitle2),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions
              .map((s) => GestureDetector(
                    onTap: _isRunning
                        ? null
                        : () => setState(() {
                              _promptCtrl.text = s
                                  .replaceAll(RegExp(r'^[\p{Emoji}\s]+', unicode: true), '')
                                  .trim();
                            }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: cs.outlineVariant.withOpacity(0.4)),
                      ),
                      child: Text(
                        s,
                        style: AppTypography.caption
                            .copyWith(color: cs.onSurface),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ─── Generate button ──────────────────────────────────────────────────────

  Widget _buildGenerateButton(ColorScheme cs) {
    final canGenerate = !_creating && !_isRunning;

    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: canGenerate
            ? const LinearGradient(
                colors: [Color(0xFF6A5CFF), Color(0xFFAA44FF)],
              )
            : null,
        color: canGenerate ? null : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        boxShadow: canGenerate
            ? [
                BoxShadow(
                  color: const Color(0xFF6A5CFF).withOpacity(0.40),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canGenerate ? _generate : null,
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          child: Center(
            child: _creating
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Starting…',
                        style: AppTypography.button
                            .copyWith(color: Colors.white),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: canGenerate
                            ? Colors.white
                            : cs.onSurfaceVariant,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isRunning
                            ? 'Generating…'
                            : _status == 'ready'
                                ? 'Generate Again'
                                : 'Generate with Claude',
                        style: AppTypography.button.copyWith(
                          color: canGenerate
                              ? Colors.white
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ─── Status card ──────────────────────────────────────────────────────────

  Widget _buildStatusCard(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          _buildStatusDot(cs),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel,
                  style: AppTypography.body2.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_isRunning)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Claude is classifying → designing → coding your game',
                      style: AppTypography.caption
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
          if (_gameId != null)
            Text(
              '#${_gameId!.substring(0, _gameId!.length > 6 ? 6 : _gameId!.length)}',
              style: AppTypography.caption
                  .copyWith(color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusDot(ColorScheme cs) {
    final color = _statusColor(cs);
    if (_isRunning) {
      return ScaleTransition(
        scale: _pulseAnim,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.6), blurRadius: 8),
            ],
          ),
        ),
      );
    }
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  // ─── Game info card ───────────────────────────────────────────────────────

  Widget _buildGameInfoCard(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.videogame_asset_rounded,
                  size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _gameTitle ?? 'Claude Game',
                  style: AppTypography.subtitle2
                      .copyWith(color: cs.onSurface),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_gameDescription != null && _gameDescription!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _gameDescription!,
              style: AppTypography.caption
                  .copyWith(color: cs.onSurfaceVariant),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (_usedFallback && _fallbackType != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withOpacity(0.30)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.orange, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'Fallback used: $_fallbackType template',
                    style: AppTypography.caption.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Play button ──────────────────────────────────────────────────────────

  Widget _buildPlayButton(ColorScheme cs) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
            ),
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22C55E).withOpacity(0.40),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push(
                '/play-webgl',
                extra: {'url': _playUrl!.trim()},
              ),
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Play Game Now',
                      style: AppTypography.button
                          .copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: _reset,
          icon: Icon(Icons.add_circle_outline_rounded,
              color: cs.onSurfaceVariant, size: 16),
          label: Text(
            'Generate another game',
            style: AppTypography.body2
                .copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
