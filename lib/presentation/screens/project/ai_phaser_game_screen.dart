import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/phaser_game_service.dart';
import '../../widgets/widgets.dart';

class AiPhaserGameScreen extends StatefulWidget {
  const AiPhaserGameScreen({super.key});

  @override
  State<AiPhaserGameScreen> createState() => _AiPhaserGameScreenState();
}

class _AiPhaserGameScreenState extends State<AiPhaserGameScreen> with TickerProviderStateMixin {
  final _promptCtrl = TextEditingController();

  bool _creating = false;
  String? _error;

  String? _gameId;
  String _status = 'idle';
  String? _playUrl;

  Timer? _pollTimer;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _promptCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startPoll() async {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollOnce();
    });
    await _pollOnce();
  }

  Future<void> _pollOnce() async {
    final token = context.read<AuthProvider>().token;
    final gid = _gameId;
    if (token == null || token.isEmpty || gid == null || gid.isEmpty) return;

    try {
      final res = await PhaserGameService.status(token: token, gameId: gid);
      if (!mounted) return;

      final data = res['data'];
      final status = (data is Map) ? data['status']?.toString() : null;
      final playUrl = (data is Map) ? data['playUrl']?.toString() : null;
      final err = (data is Map) ? data['error']?.toString() : null;

      if (res['success'] == true && status != null) {
        setState(() {
          _status = status;
          _playUrl = playUrl;
          if (status == 'failed' && err != null && err.trim().isNotEmpty) {
            _error = err.trim();
          }
        });

        if (status == 'ready' && playUrl != null && playUrl.trim().isNotEmpty) {
          _pollTimer?.cancel();
          context.push('/play-webgl', extra: {'url': playUrl.trim()});
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _create() async {
    if (_creating) return;

    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) {
      setState(() => _error = 'Please enter a prompt');
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
    });

    try {
      final res = await PhaserGameService.generate(token: token, prompt: prompt);
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
        _error = res['message']?.toString() ?? 'Failed to start generation';
        _status = 'idle';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _status = 'idle';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _creating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final isRunning = _status == 'queued' || _status == 'running';
    final statusLabel = _status == 'idle'
        ? 'Ready'
        : _status == 'queued'
            ? 'Queued'
            : _status == 'running'
                ? 'Generating…'
                : _status == 'ready'
                    ? 'Ready'
                    : 'Failed';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text('Phaser Instant Game', style: AppTypography.subtitle1),
        leading: IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
        ),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  border: Border.all(color: AppColors.error.withOpacity(0.35)),
                ),
                child: Text(
                  _error!,
                  style: AppTypography.body2.copyWith(color: cs.onSurface),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text('Prompt', style: AppTypography.subtitle2),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _promptCtrl,
              minLines: 4,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: 'Describe the HTML5 game you want (Phaser.js)…',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            CustomButton(
              text: _creating ? 'Starting…' : 'Generate (Phaser)',
              onPressed: (_creating || isRunning) ? null : _create,
              isFullWidth: true,
              type: ButtonType.primary,
              icon: const Icon(Icons.bolt),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _status == 'failed'
                            ? AppColors.error
                            : _status == 'ready'
                                ? Colors.green
                                : cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Status: $statusLabel',
                      style: AppTypography.body2.copyWith(color: cs.onSurface),
                    ),
                  ),
                  if (_gameId != null)
                    Text(
                      _gameId!.substring(0, _gameId!.length > 6 ? 6 : _gameId!.length),
                      style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            if (_playUrl != null && _playUrl!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              CustomButton(
                text: 'Play Now',
                onPressed: () => context.push('/play-webgl', extra: {'url': _playUrl!.trim()}),
                isFullWidth: true,
                type: ButtonType.secondary,
                icon: const Icon(Icons.play_arrow_rounded),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
