import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'package:gamefrogai/core/services/voice_webrtc_controller.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/live_realtime_controller.dart';
import '../../../core/services/live_service.dart';

class LiveWatchScreen extends StatefulWidget {
  final String liveId;
  final String? initialTab;

  const LiveWatchScreen({
    super.key,
    required this.liveId,
    this.initialTab,
  });

  @override
  State<LiveWatchScreen> createState() => _LiveWatchScreenState();
}

class _LiveWatchScreenState extends State<LiveWatchScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  bool _loading = false;
  String? _error;

  final _chat = LiveRealtimeController();
  final _voice = VoiceWebRtcController();

  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _audioPlayer = AudioPlayer();

  final List<Map<String, dynamic>> _activeGifts = [];
  final List<String> _entryMessages = [];
  final List<_FloatingHeart> _floatingHearts = [];

  double _screenShake = 0.0;
  bool _showFireEffect = false;
  Timer? _likeTimer;

  String? _lastGiftEventId;
  int _giftCombo = 0;
  DateTime? _lastGiftAt;
  Timer? _comboTimer;

  VideoTrack? _remoteVideo;

  bool _isPip = false;

  @override
  void initState() {
    super.initState();
    _boot();
    _chat.addListener(_onChatUpdate);

    if (widget.initialTab == 'gift') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDonationSheet();
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _chat.removeListener(_onChatUpdate);
    _chat.disconnect();
    _voice.stop();
    _listener?.dispose();
    _room?.dispose();
    _text.dispose();
    _scroll.dispose();
    _likeTimer?.cancel();
    super.dispose();
  }

  String _normalizeLiveKitUrl(String raw) {
    final u = raw.trim();
    if (u.startsWith('https://')) return 'wss://' + u.substring('https://'.length);
    if (u.startsWith('http://')) return 'ws://' + u.substring('http://'.length);
    return u;
  }

  void _updateRemoteVideo() {
    if (!mounted || _room == null) return;

    VideoTrack? foundTrack;

    for (final participant in _room!.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        if (publication.track is VideoTrack) {
          foundTrack = publication.track as VideoTrack;
          break;
        }
      }
      if (foundTrack != null) break;
    }

    if (_remoteVideo != foundTrack) {
      setState(() {
        _remoteVideo = foundTrack;
      });
    }
  }

  void _autoScroll() {
    if (!_scroll.hasClients) return;
    Future.microtask(() {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onChatUpdate() {
    if (!mounted) return;

    setState(() {});
    _autoScroll();

    if (_chat.gifts.isNotEmpty) {
      final g = _chat.gifts.last;
      if ((_lastGiftEventId ?? '') != g.id) {
        _lastGiftEventId = g.id;
        _registerGiftCombo(g.giftName, g.amount);
        _triggerGiftEffectWithAmount(g.giftName, g.fromUsername, g.amount);
      }
    }

    if (_chat.messages.isNotEmpty) {
      final lastMsg = _chat.messages.last;
      if (lastMsg.text.toLowerCase().contains('joined the room')) {
        _triggerEntryEffect(lastMsg.username);
      }
      if (lastMsg.text.toLowerCase() == 'like') {
        _handleLike();
      }
    }
  }

  void _registerGiftCombo(String giftName, int amount) {
    final now = DateTime.now();
    final last = _lastGiftAt;
    final withinWindow = last != null && now.difference(last).inMilliseconds <= 3000;

    final isLegendary = giftName == 'Rocket' || giftName == 'Crown' || giftName == 'Legendary Drop' || amount >= 500;
    if (!withinWindow) {
      _giftCombo = 1;
    } else {
      _giftCombo = (_giftCombo + 1).clamp(1, 9);
    }
    _lastGiftAt = now;

    _comboTimer?.cancel();
    _comboTimer = Timer(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      setState(() {
        _giftCombo = 0;
      });
    });

    if (isLegendary) {
      _triggerScreenShake();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _handleLike() {
    final token = context.read<AuthProvider>().token;
    if (token != null) {
      _chat.sendLike(token: token);
    }

    HapticFeedback.lightImpact();
    _triggerMilestoneEffect();

    setState(() {
      _floatingHearts.add(
        _FloatingHeart(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          color: [Colors.red, Colors.pink, Colors.orange, Colors.blue][DateTime.now().millisecond % 4],
        ),
      );
      _showFireEffect = true;
    });

    _likeTimer?.cancel();
    _likeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showFireEffect = false;
        });
      }
    });
  }

  Widget _buildEntryNotifications() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _entryMessages
          .map(
            (msg) => TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 500),
              key: ValueKey(msg),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(-20 * (1 - value), 0),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _glass(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              msg,
                              style: AppTypography.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          )
          .toList(),
    );
  }

  Future<void> _boot() async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await LiveService.join(token: token, liveId: widget.liveId);
      final ok = res['success'] == true;
      final data = ok ? res['data'] : null;
      if (!ok || data is! Map) {
        throw Exception(res['message']?.toString() ?? 'Failed to join live');
      }

      final livekitUrl = (data['livekitUrl'] ?? '').toString().trim();
      final roomName = (data['roomName'] ?? '').toString().trim();
      final lkToken = (data['token'] ?? '').toString().trim();
      if (livekitUrl.isEmpty || roomName.isEmpty || lkToken.isEmpty) {
        throw Exception('Invalid live config');
      }

      final room = Room();
      final listener = room.createListener();
      listener
        ..on<RoomDisconnectedEvent>((e) {
          if (!mounted) return;
          final reason = (e.reason ?? '').toString();
          setState(() {
            _error = reason.trim().isEmpty ? 'Disconnected' : 'Disconnected: $reason';
          });
        })
        ..on<RoomReconnectingEvent>((_) {
          if (!mounted) return;
          setState(() {
            _error = 'Reconnecting…';
          });
        })
        ..on<RoomReconnectedEvent>((_) {
          if (!mounted) return;
          setState(() {
            _error = null;
          });
        })
        ..on<TrackSubscribedEvent>((_) => _updateRemoteVideo())
        ..on<TrackUnsubscribedEvent>((_) => _updateRemoteVideo())
        ..on<ParticipantDisconnectedEvent>((_) => _updateRemoteVideo());

      final normalizedUrl = _normalizeLiveKitUrl(livekitUrl);
      await room.connect(normalizedUrl, lkToken);

      _room = room;
      _listener = listener;

      await _chat.connectAndJoin(token: token, liveId: widget.liveId);

      if (_chat.socket != null) {
        await _voice.start(
          socket: _chat.socket!,
          token: token,
          roomId: 'live_${widget.liveId}',
        );
      }

      if (!mounted) return;
      setState(() {
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

  Future<void> _retry() async {
    await _boot();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/dashboard?tab=arcade');
  }

  Widget _glass({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _pulse({required Widget child}) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 1.0, end: 1.1),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
    );
  }

  void _send(String token) {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _text.clear();
    _chat.sendChat(token: token, text: t);
  }

  Widget _chatBar(String token) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withOpacity(0.9) : cs.surface.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withOpacity(0.3) : cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : cs.outlineVariant.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                style: AppTypography.body2.copyWith(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Join the conversation...',
                  hintStyle: AppTypography.body2.copyWith(color: isDark ? Colors.white38 : const Color(0xFF64748B)),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _send(token),
              ),
            ),
            _pulse(
              child: IconButton(
                onPressed: () => _send(token),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatPanel(String token) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: _chatBar(token),
    );
  }

  void togglePip() {
    if (mounted) setState(() => _isPip = !_isPip);
  }

  Widget _pipVideo() {
    if (_remoteVideo == null) return const SizedBox.shrink();
    return Container(
      width: 160,
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, spreadRadius: 2),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: VideoTrackRenderer(_remoteVideo!),
      ),
    );
  }

  Widget _videoStage() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final video = _remoteVideo;

    if (video == null) {
      return Container(
        color: isDark ? const Color(0xFF0F172A) : cs.surface,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pulse(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'LIVE',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'WAITING FOR STREAMER',
                style: AppTypography.subtitle2.copyWith(
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        VideoTrackRenderer(video),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.4),
                ],
                radius: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _triggerMilestoneEffect() {
    HapticFeedback.vibrate();
    _playSfx('https://www.myinstants.com/media/sounds/level-up-pokemon.mp3');
  }

  String _getSfxForGift(String name) {
    switch (name) {
      case 'Rocket':
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/sfx/rocket.mp3';
      case 'Crown':
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/sfx/fanfare.mp3';
      case 'Legendary Drop':
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/sfx/level-up.mp3';
      case 'Fire':
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/sfx/fire.mp3';
      case 'Gem':
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/sfx/crystal.mp3';
      case 'Rose':
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/sfx/sparkle.mp3';
      default:
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/sfx/coin.mp3';
    }
  }

  Future<void> _playSfx(String url) async {
    if (url.trim().isEmpty) return;
    try {
      await _audioPlayer.setVolume(1.0);
      if (_audioPlayer.playing) {
        await _audioPlayer.stop();
      }
      await _audioPlayer.setUrl(url).catchError((_) async {
        // Intentionally silent: remote SFX URLs may 404; we never want to surface/log this.
        return null;
      });

      // If setUrl failed, duration is typically null; avoid calling play() in that case.
      if (_audioPlayer.duration != null) {
        await _audioPlayer.play().catchError((_) async {
          return null;
        });
      }
    } catch (_) {
      // Intentionally silent.
    }
  }

  void _triggerScreenShake() {
    setState(() => _screenShake = 15.0);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _screenShake = -15.0);
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _screenShake = 10.0);
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _screenShake = -10.0);
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _screenShake = 0.0);
    });
  }

  void _triggerEntryEffect(String username) {
    if (_entryMessages.contains('$username joined')) return;
    setState(() {
      _entryMessages.add('$username joined');
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _entryMessages.remove('$username joined');
        });
      }
    });
  }

  void _showDonationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _DonationSheet(
        liveId: widget.liveId,
        onGiftSent: (giftName, from, amount) {
          final token = this.context.read<AuthProvider>().token;
          if (token != null && token.trim().isNotEmpty) {
            _chat.sendGift(token: token, giftName: giftName, amount: amount);
          }
          _triggerGiftEffectWithAmount(giftName, from, amount);
        },
      ),
    );
  }

  void _triggerGiftEffectWithAmount(String giftName, String from, int amount) {
    HapticFeedback.heavyImpact();
    _playSfx(_getSfxForGift(giftName));

    final isLegendary = giftName == 'Rocket' || giftName == 'Crown' || giftName == 'Legendary Drop';
    if (isLegendary) {
      _triggerScreenShake();
    }

    setState(() {
      _activeGifts.add({
        'name': giftName,
        'from': from,
        'amount': amount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  String _getLottieForGift(String name) {
    switch (name) {
      case 'Rocket':
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/lottie/rocket.json';
      case 'Crown':
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/lottie/crown.json';
      case 'Fire':
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/lottie/fire.json';
      case 'Legendary Drop':
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/lottie/gift_box.json';
      case 'Rose':
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/lottie/rose.json';
      case 'Gem':
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/lottie/gem.json';
      default:
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/lottie/gift_box.json';
    }
  }

  String _getFullScreenLottieForGift(String name) {
    switch (name) {
      case 'Rocket':
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/lottie/rocket_launch_full.json';
      case 'Fire':
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/lottie/fireworks_full.json';
      case 'Crown':
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/lottie/gold_confetti_full.json';
      case 'Legendary Drop':
        return 'https://raw.githubusercontent.com/mohamed-yassine-ouertani/GameForge-Assets/main/lottie/explosion_full.json';
      default:
        return '';
    }
  }

  Widget _buildGiftOverlay() {
    if (_activeGifts.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: _activeGifts.map((giftData) {
        final giftName = giftData['name'] as String;
        final from = giftData['from'] as String;
        final int? amount = giftData['amount'] as int?;
        final String lottieUrl = _getLottieForGift(giftName);

        final bool isLegendary = giftName == 'Rocket' || giftName == 'Crown' || giftName == 'Legendary Drop';
        final Color burstA = isLegendary ? const Color(0xFFFFD54F) : AppColors.accent;
        final Color burstB = isLegendary ? const Color(0xFF7C3AED) : const Color(0xFF00E5FF);

        return Center(
          key: ValueKey('${giftName}_${giftData['timestamp']}'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (_getFullScreenLottieForGift(giftName).isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Lottie.network(
                      _getFullScreenLottieForGift(giftName),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              TweenAnimationBuilder<double>(
                duration: const Duration(seconds: 3),
                tween: Tween(begin: 0.0, end: 1.0),
                onEnd: () => setState(() => _activeGifts.remove(giftData)),
                builder: (context, value, child) {
                  final scale = value < 0.2 ? value * 5 : (value > 0.8 ? (1 - value) * 5 : 1.0);
                  final t = value;
                  final burstOpacity = (t < 0.35) ? (1.0 - (t / 0.35)).clamp(0.0, 1.0) : 0.0;
                  final burstScale = 0.65 + (1.45 * (t.clamp(0.0, 0.5) / 0.5));

                  final enterT = Curves.easeOutBack.transform(t.clamp(0.0, 0.32) / 0.32);
                  final exitT = Curves.easeIn.transform(((t - 0.82).clamp(0.0, 0.18)) / 0.18);
                  final y = lerpDouble(260, 0, enterT) ?? 0;
                  final z = lerpDouble(-220, 0, enterT) ?? 0;
                  final rotY = lerpDouble(0.85, 0.0, enterT) ?? 0.0;
                  final rotX = lerpDouble(-0.55, 0.0, enterT) ?? 0.0;
                  final rotZ = lerpDouble(0.20, 0.0, enterT) ?? 0.0;
                  final vanish = 1.0 - exitT;

                  final fxT = Curves.easeOutCubic.transform(t.clamp(0.0, 0.55) / 0.55);
                  final ringOpacity = isLegendary ? (1.0 - fxT).clamp(0.0, 1.0) : 0.0;
                  final ringScale = 0.35 + (1.9 * fxT);
                  final sweepOpacity = isLegendary ? (1.0 - (t.clamp(0.0, 0.22) / 0.22)).clamp(0.0, 1.0) : 0.0;
                  final streakOpacity = isLegendary ? (1.0 - (t.clamp(0.0, 0.30) / 0.30)).clamp(0.0, 1.0) : 0.0;

                  return Opacity(
                    opacity: (scale * vanish).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.5 + (0.5 * scale),
                      child: Transform(
                        transform: (Matrix4.identity()
                          ..setEntry(3, 2, 0.0016)
                          ..translate(0.0, y, z)
                          ..rotateX(rotX)
                          ..rotateY(rotY)
                          ..rotateZ(rotZ)),
                        alignment: Alignment.center,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isLegendary) ...[
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: sweepOpacity,
                                    child: const _NeonSweepFlash(),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: streakOpacity,
                                    child: Transform.scale(
                                      scale: 0.9 + (0.6 * fxT),
                                      child: const _MotionStreaks(),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: ringOpacity,
                                    child: Transform.scale(
                                      scale: ringScale,
                                      child: _ShockwaveRing(colorA: burstA, colorB: burstB),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            IgnorePointer(
                              child: Opacity(
                                opacity: burstOpacity,
                                child: Transform.scale(
                                  scale: burstScale,
                                  child: Container(
                                    width: isLegendary ? 520 : 420,
                                    height: isLegendary ? 520 : 420,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          burstA.withOpacity(0.95),
                                          burstB.withOpacity(0.35),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.55, 1.0],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: burstA.withOpacity(isLegendary ? 0.45 : 0.30),
                                          blurRadius: isLegendary ? 42 : 32,
                                          spreadRadius: isLegendary ? 10 : 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IgnorePointer(
                              child: Opacity(
                                opacity: burstOpacity * 0.9,
                                child: Transform.scale(
                                  scale: 0.9 + (0.9 * burstScale),
                                  child: const _GiftSparkles(),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Lottie.network(
                                  lottieUrl,
                                  width: isLegendary ? 420 : 300,
                                  height: isLegendary ? 420 : 300,
                                  errorBuilder: (context, error, stackTrace) => _Gift3DBadge(giftName: giftName, size: isLegendary ? 190 : 150),
                                ),
                                const SizedBox(height: 14),
                                _glass(
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isLegendary) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(999),
                                            gradient: const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFF7C3AED)]),
                                            boxShadow: [
                                              BoxShadow(color: const Color(0xFFFFD54F).withOpacity(0.35), blurRadius: 18, spreadRadius: 2),
                                            ],
                                          ),
                                          child: Text(
                                            'LEGENDARY',
                                            style: AppTypography.caption.copyWith(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.3,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      Text(
                                        from,
                                        style: AppTypography.subtitle1.copyWith(
                                          color: isLegendary ? burstA : AppColors.accent,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'SENT A $giftName!',
                                        style: AppTypography.h4.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      if (amount != null) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(999),
                                            color: Colors.white.withOpacity(0.06),
                                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                                          ),
                                          child: Text(
                                            '+$amount ',
                                            style: AppTypography.subtitle2.copyWith(
                                              color: isLegendary ? burstA : AppColors.accent,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _giftComboBanner() {
    if (_giftCombo <= 1) return const SizedBox.shrink();
    final t = (_giftCombo >= 4) ? 'HYPE TRAIN x$_giftCombo' : 'COMBO x$_giftCombo';
    final isBig = _giftCombo >= 4;
    final c1 = isBig ? const Color(0xFFFFD54F) : AppColors.accent;
    final c2 = isBig ? const Color(0xFF7C3AED) : const Color(0xFF00E5FF);
    return Positioned(
      top: MediaQuery.of(context).padding.top + 64,
      left: 0,
      right: 0,
      child: Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 260),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, v, child) {
            return Opacity(
              opacity: v,
              child: Transform.scale(
                scale: 0.92 + (0.08 * v),
                child: child,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(colors: [c1, c2]),
              boxShadow: [
                BoxShadow(color: c2.withOpacity(0.45), blurRadius: 20, spreadRadius: 2),
              ],
              border: Border.all(color: Colors.black.withOpacity(0.35), width: 1.2),
            ),
            child: Text(
              t,
              style: AppTypography.caption.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFireCombo() {
    return AnimatedBuilder(
      animation: _chat,
      builder: (context, _) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (0.4 * value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.network(
                    'https://assets10.lottiefiles.com/packages/lf20_dr7pbtun.json',
                    width: 120,
                    height: 120,
                    errorBuilder: (context, error, stackTrace) => const _Gift3DBadge(giftName: 'Fire', size: 96),
                  ),
                  _glass(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'COMBO x${_chat.messages.where((m) => m.text.toLowerCase() == 'like').length}',
                      style: AppTypography.subtitle1.copyWith(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final token = context.watch<AuthProvider>().token;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : cs.surface,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        transform: Matrix4.translationValues(_screenShake, 0, 0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _videoStage(),

            if (!isDark)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cs.surface.withOpacity(0.1),
                          cs.surface.withOpacity(0.0),
                          cs.surface.withOpacity(0.2),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            ..._floatingHearts.map(
              (h) => _FloatingHeartWidget(
                key: ValueKey(h.id),
                heart: h,
                onComplete: () {
                  setState(() {
                    _floatingHearts.removeWhere((item) => item.id == h.id);
                  });
                },
              ),
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
                  child: Row(
                    children: [
                      Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: _close,
                          child: _glass(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white.withOpacity(0.92),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _glass(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _PulsingDot(),
                            const SizedBox(width: 10),
                            Text(
                              'LIVE',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Container(width: 1, height: 12, color: Colors.white.withOpacity(0.2)),
                            const SizedBox(width: 14),
                            const Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 14),
                            const SizedBox(width: 6),
                            AnimatedBuilder(
                              animation: _chat,
                              builder: (context, _) {
                                return Text(
                                  _chat.viewers.toString(),
                                  style: AppTypography.caption.copyWith(
                                    color: Colors.white.withOpacity(0.95),
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'monospace',
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      AnimatedBuilder(
                        animation: _voice,
                        builder: (context, _) {
                          if (!_voice.enabled) return const SizedBox.shrink();
                          return Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () => _voice.toggleMute(),
                              child: _glass(
                                padding: const EdgeInsets.all(12),
                                child: Icon(
                                  _voice.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                                  color: _voice.muted ? Colors.redAccent : Colors.white.withOpacity(0.92),
                                  size: 20,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: togglePip,
                          child: _glass(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              _isPip ? Icons.fullscreen_rounded : Icons.picture_in_picture_alt_rounded,
                              color: Colors.white.withOpacity(0.92),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_loading)
                        _glass(
                          child: const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_error != null)
                        _glass(
                          child: Text(
                            'Error',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            if (token != null && token.trim().isNotEmpty)
              Positioned(
                left: AppSpacing.lg,
                bottom: MediaQuery.of(context).padding.bottom + 300,
                child: _buildEntryNotifications(),
              ),

            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xl + 60,
              height: 200,
              child: AnimatedBuilder(
                animation: _chat,
                builder: (context, child) {
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _chat.messages.length,
                    itemBuilder: (context, index) {
                      final msg = _chat.messages[index];
                      final isMe = msg.username == 'You';
                      final isSystem = msg.text.toLowerCase().contains('joined') || msg.text.toLowerCase().contains('sent a gift');

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _glass(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${msg.username}: ',
                                style: AppTypography.caption.copyWith(
                                  color: isSystem ? Colors.amberAccent : (isMe ? AppColors.accent : Colors.white70),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  msg.text,
                                  style: AppTypography.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
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
            ),

            if (token != null && token.trim().isNotEmpty) _chatPanel(token),

            _buildGiftOverlay(),

            _giftComboBanner(),

            if (_showFireEffect)
              Positioned(
                right: 20,
                bottom: MediaQuery.of(context).padding.bottom + 320,
                child: GestureDetector(
                  onTap: _handleLike,
                  child: _buildFireCombo(),
                ),
              ),

            if (_isPip)
              Positioned(
                right: 20,
                top: MediaQuery.of(context).padding.top + 80,
                child: GestureDetector(
                  onPanUpdate: (details) {},
                  child: _pipVideo(),
                ),
              ),

            if (_error != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _retry,
                  child: Container(
                    color: Colors.black87,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: _glass(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: AppTypography.body1.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _retry,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Retry Connection'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Gift3DBadge extends StatelessWidget {
  final String giftName;
  final double size;

  const _Gift3DBadge({
    required this.giftName,
    required this.size,
  });

  String get _emoji {
    switch (giftName) {
      case 'Rocket':
        return '🚀';
      case 'Crown':
        return '👑';
      case 'Fire':
        return '🔥';
      case 'Rose':
        return '🌹';
      case 'Gem':
        return '💎';
      case 'Legendary Drop':
        return '🎁';
      default:
        return '🎁';
    }
  }

  List<Color> get _colors {
    switch (giftName) {
      case 'Rocket':
        return const [Color(0xFFFFD54F), Color(0xFF7C3AED), Color(0xFF00E5FF)];
      case 'Crown':
        return const [Color(0xFFFFD54F), Color(0xFFFF8A00), Color(0xFF7C3AED)];
      case 'Fire':
        return const [Color(0xFFFF4D4D), Color(0xFFFF8A00), Color(0xFFFFD54F)];
      case 'Rose':
        return const [Color(0xFFFF3D6E), Color(0xFFFF5DA2), Color(0xFF7C3AED)];
      case 'Gem':
        return const [Color(0xFF00E5FF), Color(0xFF3B82F6), Color(0xFF7C3AED)];
      default:
        return const [Color(0xFFFFD54F), Color(0xFF7C3AED), Color(0xFF00E5FF)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    return Transform(
      alignment: Alignment.center,
      transform: (Matrix4.identity()
        ..setEntry(3, 2, 0.002)
        ..rotateX(-0.18)
        ..rotateY(0.22)
        ..rotateZ(0.06)),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              colors[0].withOpacity(0.95),
              colors[1].withOpacity(0.55),
              Colors.black.withOpacity(0.25),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
          boxShadow: [
            BoxShadow(color: colors[1].withOpacity(0.55), blurRadius: 28, spreadRadius: 6),
            BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 18, offset: const Offset(0, 14)),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.4),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 12,
              left: 18,
              child: Container(
                width: size * 0.34,
                height: size * 0.22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.55),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            Text(
              _emoji,
              style: TextStyle(
                fontSize: size * 0.48,
                shadows: [
                  Shadow(color: Colors.black.withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 10)),
                  Shadow(color: colors[2].withOpacity(0.45), blurRadius: 22),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonationSheet extends StatelessWidget {
  final String liveId;
  final Function(String giftName, String from, int amount) onGiftSent;

  const _DonationSheet({required this.liveId, required this.onGiftSent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gifts = <Map<String, dynamic>>[
      {'emoji': '💎', 'name': 'Gem', 'price': 10},
      {'emoji': '🌹', 'name': 'Rose', 'price': 1},
      {'emoji': '🔥', 'name': 'Fire', 'price': 50},
      {'emoji': '👑', 'name': 'Crown', 'price': 100},
      {'emoji': '🚀', 'name': 'Rocket', 'price': 500},
      {'emoji': '🍦', 'name': 'Ice Cream', 'price': 5},
      {'emoji': '🎁', 'name': 'Legendary Drop', 'price': 1000},
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : cs.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Send a Gift', style: AppTypography.h4.copyWith(color: isDark ? Colors.white : cs.onSurface)),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: isDark ? Colors.white70 : cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              itemCount: gifts.length,
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 106,
              ),
              itemBuilder: (context, i) {
                final g = gifts[i];
                return _giftItem(context, g['emoji'] as String, g['name'] as String, g['price'] as int);
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () async {
                final token = context.read<AuthProvider>().token;
                if (token == null) return;

                try {
                  final res = await LiveService.createGiftPaymentSheet(
                    token: token,
                    amount: 10.0,
                  );

                  if (res['success'] == true) {
                    final data = res['data'];
                    await Stripe.instance.initPaymentSheet(
                      paymentSheetParameters: SetupPaymentSheetParameters(
                        paymentIntentClientSecret: data['paymentIntent'],
                        customerEphemeralKeySecret: data['ephemeralKey'],
                        customerId: data['customer'],
                        merchantDisplayName: 'GameForge',
                        style: isDark ? ThemeMode.dark : ThemeMode.light,
                      ),
                    );
                    await Stripe.instance.presentPaymentSheet();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Recharge successful!')),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Recharge failed: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Recharge Coins', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _giftItem(BuildContext context, String emoji, String name, int price) {
    final token = context.read<AuthProvider>().token;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        if (token == null) return;

        try {
          final res = await LiveService.createGiftPaymentSheet(
            token: token,
            amount: price.toDouble(),
          );

          if (res['success'] == true) {
            final data = res['data'];

            await Stripe.instance.initPaymentSheet(
              paymentSheetParameters: SetupPaymentSheetParameters(
                paymentIntentClientSecret: data['paymentIntent'],
                customerEphemeralKeySecret: data['ephemeralKey'],
                customerId: data['customer'],
                merchantDisplayName: 'GameForge',
                style: isDark ? ThemeMode.dark : ThemeMode.light,
                appearance: PaymentSheetAppearance(
                  colors: PaymentSheetAppearanceColors(primary: AppColors.accent),
                ),
              ),
            );

            await Stripe.instance.presentPaymentSheet();

            if (context.mounted) {
              Navigator.pop(context);
              onGiftSent(name, 'You', price);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Successfully sent $name to creator!'),
                  backgroundColor: AppColors.accent,
                ),
              );
            }
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Payment failed: $e')),
            );
          }
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : cs.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : cs.primary.withOpacity(0.1)),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: isDark ? Colors.white70 : cs.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$price 🪙',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftSparkles extends StatelessWidget {
  const _GiftSparkles();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 520,
      height: 520,
      child: Stack(
        children: const [
          _SparkleDot(left: 70, top: 90, size: 10, opacity: 0.9),
          _SparkleDot(left: 120, top: 170, size: 6, opacity: 0.7),
          _SparkleDot(right: 90, top: 120, size: 9, opacity: 0.8),
          _SparkleDot(right: 140, top: 210, size: 6, opacity: 0.6),
          _SparkleDot(left: 160, bottom: 140, size: 8, opacity: 0.7),
          _SparkleDot(right: 120, bottom: 160, size: 10, opacity: 0.85),
          _SparkleDot(left: 90, bottom: 210, size: 6, opacity: 0.55),
          _SparkleDot(right: 70, bottom: 230, size: 7, opacity: 0.65),
        ],
      ),
    );
  }
}

class _SparkleDot extends StatelessWidget {
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double size;
  final double opacity;

  const _SparkleDot({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(opacity * 0.75),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShockwaveRing extends StatelessWidget {
  final Color colorA;
  final Color colorB;

  const _ShockwaveRing({
    required this.colorA,
    required this.colorB,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ShockwavePainter(colorA: colorA, colorB: colorB),
      child: const SizedBox.expand(),
    );
  }
}

class _ShockwavePainter extends CustomPainter {
  final Color colorA;
  final Color colorB;

  _ShockwavePainter({required this.colorA, required this.colorB});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.shortestSide / 2) * 0.85;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..shader = SweepGradient(
        colors: [
          colorA.withOpacity(0.0),
          colorA.withOpacity(0.9),
          colorB.withOpacity(0.85),
          colorA.withOpacity(0.0),
        ],
        stops: const [0.0, 0.25, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));

    canvas.drawCircle(c, r, paint);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..color = colorA.withOpacity(0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawCircle(c, r * 0.98, glow);
  }

  @override
  bool shouldRepaint(covariant _ShockwavePainter oldDelegate) {
    return oldDelegate.colorA != colorA || oldDelegate.colorB != colorB;
  }
}

class _NeonSweepFlash extends StatelessWidget {
  const _NeonSweepFlash();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-1.2, -1.0),
          end: Alignment(1.2, 1.0),
          colors: [
            Color(0x0000E5FF),
            Color(0x667C3AED),
            Color(0x99FFD54F),
            Color(0x0000E5FF),
          ],
          stops: [0.0, 0.35, 0.55, 1.0],
        ),
      ),
    );
  }
}

class _MotionStreaks extends StatelessWidget {
  const _MotionStreaks();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MotionStreakPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _MotionStreakPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0x00FFFFFF), Color(0x99FFFFFF), Color(0x00FFFFFF)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCenter(center: c, width: size.width, height: size.height));

    final dx = size.width * 0.34;
    final dy = size.height * 0.16;
    for (var i = 0; i < 6; i++) {
      final y = c.dy + (i - 2.5) * (dy / 3.2);
      final x1 = c.dx - dx;
      final x2 = c.dx + dx;
      canvas.drawLine(Offset(x1, y), Offset(x2, y - (i.isEven ? 8 : -8)), base);
    }

    final accent = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF00E5FF).withOpacity(0.35);
    canvas.drawLine(Offset(c.dx - dx * 0.8, c.dy + dy * 0.35), Offset(c.dx + dx * 0.6, c.dy + dy * 0.15), accent);
    canvas.drawLine(Offset(c.dx - dx * 0.7, c.dy - dy * 0.25), Offset(c.dx + dx * 0.7, c.dy - dy * 0.45), accent);
  }

  @override
  bool shouldRepaint(covariant _MotionStreakPainter oldDelegate) => false;
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final glow = lerpDouble(0.25, 0.85, _t.value) ?? 0.6;
        final scale = lerpDouble(0.92, 1.18, _t.value) ?? 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.redAccent,
              boxShadow: [
                BoxShadow(color: Colors.redAccent.withOpacity(glow), blurRadius: 14, spreadRadius: 2),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FloatingHeart {
  final String id;
  final Color color;
  _FloatingHeart({required this.id, required this.color});
}

class _FloatingHeartWidget extends StatefulWidget {
  final _FloatingHeart heart;
  final VoidCallback onComplete;
  const _FloatingHeartWidget({super.key, required this.heart, required this.onComplete});

  @override
  State<_FloatingHeartWidget> createState() => _FloatingHeartWidgetState();
}

class _FloatingHeartWidgetState extends State<_FloatingHeartWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _yOffset;
  late Animation<double> _xOffset;
  late double _randomX;

  @override
  void initState() {
    super.initState();
    _randomX = (DateTime.now().millisecond % 100) - 50.0;
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);
    _yOffset = Tween(begin: 0.0, end: -400.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _xOffset = Tween(begin: 0.0, end: _randomX).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      right: 40,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: Transform.translate(
              offset: Offset(_xOffset.value, _yOffset.value),
              child: Icon(Icons.favorite, color: widget.heart.color, size: 30),
            ),
          );
        },
      ),
    );
  }
}
