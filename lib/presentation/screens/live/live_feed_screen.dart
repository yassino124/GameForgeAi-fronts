import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/live_service.dart';
import '../../../../core/constants/app_colors.dart' as constants_colors;
import '../../../../core/constants/app_typography.dart' as constants_typography;
import '../../../../core/constants/app_spacing.dart' as constants_spacing;

class LiveFeedScreen extends StatefulWidget {
  const LiveFeedScreen({super.key});

  @override
  State<LiveFeedScreen> createState() => _LiveFeedScreenState();
}

class _LiveFeedScreenState extends State<LiveFeedScreen> with WidgetsBindingObserver {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  late final PageController _page;
  int _currentIndex = 0;
  Timer? _poll;
  bool _didInitialLoad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _page = PageController();
    _load();
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load(silent: true);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _page.dispose();
    super.dispose();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _load(silent: true);
    });
  }

  Future<void> _load({bool silent = false}) async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    if (_loading) return;

    if (!silent || !_didInitialLoad) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final res = await LiveService.feed(token: token);
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(res['data'] ?? []);
          _loading = false;
          _didInitialLoad = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
          _didInitialLoad = true;
        });
      }
    }
  }

  Widget _glass(
    BuildContext context, {
    required Widget child,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : cs.surface).withOpacity(isDark ? 0.35 : 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.12) : cs.outlineVariant.withOpacity(0.75),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070A12) : cs.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: cs.primary))
                : (_error != null)
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: constants_spacing.AppSpacing.lg),
                          child: _glass(
                            context,
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              _error!,
                              style: constants_typography.AppTypography.body2.copyWith(
                                color: isDark ? Colors.white.withOpacity(0.9) : cs.onSurface,
                              ),
                            ),
                          ),
                        ),
                      )
                    : (_items.isEmpty)
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: constants_spacing.AppSpacing.lg),
                              child: _glass(
                                context,
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No one is live right now',
                                      style: constants_typography.AppTypography.subtitle1.copyWith(
                                        color: isDark ? Colors.white : cs.onSurface,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Be the first creator to go live.',
                                      style: constants_typography.AppTypography.body2.copyWith(
                                        color: isDark ? Colors.white.withOpacity(0.7) : cs.onSurfaceVariant,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    ElevatedButton.icon(
                                      onPressed: () => context.push('/live/go'),
                                      icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                                      label: const Text('Go Live'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: constants_colors.AppColors.accent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : PageView.builder(
                            controller: _page,
                            scrollDirection: Axis.vertical,
                            itemCount: _items.length,
                            onPageChanged: (i) => setState(() => _currentIndex = i),
                            itemBuilder: (context, i) => LiveFeedItem(
                              item: _items[i],
                              isActive: _currentIndex == i,
                            ),
                          ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(constants_spacing.AppSpacing.lg, 10, constants_spacing.AppSpacing.lg, 10),
                child: Row(
                  children: [
                    Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/dashboard?tab=arcade');
                          }
                        },
                        child: _glass(
                          context,
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: isDark ? Colors.white.withOpacity(0.92) : cs.onSurface,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _glass(
                      context,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text(
                        'LIVE',
                        style: constants_typography.AppTypography.subtitle2.copyWith(
                          color: isDark ? Colors.white : cs.onSurface,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _load(),
                        child: _glass(
                          context,
                          child: Icon(
                            Icons.refresh_rounded,
                            color: isDark ? Colors.white.withOpacity(0.92) : cs.onSurface,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/live/go'),
                      icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                      label: const Text('Go Live'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: constants_colors.AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LiveFeedItem extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isActive;

  const LiveFeedItem({
    super.key,
    required this.item,
    required this.isActive,
  });

  @override
  State<LiveFeedItem> createState() => _LiveFeedItemState();
}

class _LiveFeedItemState extends State<LiveFeedItem> {
  Room? _room;
  bool _connecting = false;
  final List<Offset> _hearts = [];

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _connect();
    }
  }

  @override
  void didUpdateWidget(LiveFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _connect();
    } else if (!widget.isActive && oldWidget.isActive) {
      _disconnect();
    }
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_connecting || _room != null) return;
    setState(() => _connecting = true);

    final token = context.read<AuthProvider>().token;
    final liveId = (widget.item['id'] ?? widget.item['_id'] ?? '').toString();

    try {
      final res = await LiveService.join(token: token!, liveId: liveId);
      final ok = res['success'] == true;
      final data = ok ? res['data'] : null;
      if (!ok || data is! Map) {
        throw Exception(res['message']?.toString() ?? 'Failed to join preview');
      }

      final roomToken = data['token'];
      final url = data['livekitUrl'] ?? 'wss://gameforge-l64ymidz.livekit.cloud';

      final room = Room();
      await room.connect(url, roomToken);
      if (mounted) {
        setState(() {
          _room = room;
          _connecting = false;
        });
      }
    } catch (e) {
      debugPrint('Error connecting to live preview: $e');
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _disconnect() {
    _room?.disconnect();
    _room = null;
  }

  void _addHeart(Offset position) {
    HapticFeedback.lightImpact();
    setState(() {
      _hearts.add(position);
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          if (_hearts.isNotEmpty) _hearts.removeAt(0);
        });
      }
    });
  }

  Widget _glass(
    BuildContext context, {
    required Widget child,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : cs.surface).withOpacity(isDark ? 0.35 : 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.12) : cs.outlineVariant.withOpacity(0.75),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final id = (widget.item['id'] ?? widget.item['_id'] ?? '').toString();
    final title = (widget.item['title'] ?? '').toString().trim();
    final desc = (widget.item['description'] ?? '').toString().trim();
    final username = (widget.item['creatorUsername'] ?? 'Creator').toString().trim();
    final gameTitle = (widget.item['gameTitle'] ?? '').toString().trim();
    final avatar = (widget.item['creatorAvatar'] ?? '').toString().trim();
    final v = widget.item['viewerCount'];
    final viewersInt = (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    VideoTrack? videoTrack;
    final room = _room;
    if (room != null) {
      final remoteVideoPub = room.remoteParticipants.values
          .expand((p) => p.videoTrackPublications)
          .where((pub) => pub.subscribed && pub.track is VideoTrack)
          .cast<RemoteTrackPublication<RemoteVideoTrack>?>()
          .firstWhere((_) => true, orElse: () => null);

      final track = remoteVideoPub?.track;
      if (track is VideoTrack) {
        videoTrack = track;
      }
    }

    return GestureDetector(
      onDoubleTapDown: (details) => _addHeart(details.localPosition),
      onTap: () => context.push('/live/watch/$id'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background / Preview
          Positioned.fill(
            child: Container(color: Colors.black),
          ),
          if (videoTrack != null)
            Positioned.fill(
              child: VideoTrackRenderer(videoTrack),
            )
          else if (avatar.isNotEmpty && (avatar.startsWith('http://') || avatar.startsWith('https://')))
            Positioned.fill(
              child: Opacity(
                opacity: 0.3,
                child: Image.network(
                  avatar,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),

          // Loading indicator for preview
          if (_connecting)
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),

          // Overlay Gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.2),
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // Content
          Positioned(
            left: constants_spacing.AppSpacing.lg,
            bottom: MediaQuery.of(context).padding.bottom + constants_spacing.AppSpacing.lg,
            right: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _glass(
                  context,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'LIVE',
                        style: constants_typography.AppTypography.caption.copyWith(
                          color: isDark ? Colors.white : cs.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.visibility_rounded,
                        size: 14,
                        color: isDark ? Colors.white70 : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        viewersInt.toString(),
                        style: constants_typography.AppTypography.caption.copyWith(
                          color: isDark ? Colors.white : cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '@$username',
                  style: constants_typography.AppTypography.subtitle1.copyWith(
                    color: isDark ? Colors.white : cs.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (gameTitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _glass(
                    context,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sports_esports_rounded, color: Colors.cyanAccent, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          gameTitle,
                          style: constants_typography.AppTypography.caption.copyWith(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: constants_typography.AppTypography.h4.copyWith(
                      color: isDark ? Colors.white : cs.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: constants_typography.AppTypography.body2.copyWith(
                      color: isDark ? Colors.white70 : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Right Actions
          Positioned(
            right: constants_spacing.AppSpacing.lg,
            bottom: MediaQuery.of(context).padding.bottom + constants_spacing.AppSpacing.lg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionIcon(Icons.favorite_rounded, 'Like', () => _addHeart(const Offset(200, 400))),
                const SizedBox(height: 20),
                _actionIcon(Icons.chat_bubble_rounded, 'Chat', () => context.push('/live/watch/$id?tab=chat')),
                const SizedBox(height: 20),
                _actionIcon(Icons.card_giftcard_rounded, 'Gift', () => context.push('/live/watch/$id?tab=gift')),
                const SizedBox(height: 20),
                _actionIcon(Icons.share_rounded, 'Share', () {}),
              ],
            ),
          ),

          // Heart animations
          ..._hearts.map((pos) => Positioned(
                left: pos.dx - 40,
                top: pos.dy - 40,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 1.0, end: 0.0),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, -100 * (1 - value)),
                      child: Opacity(
                        opacity: value,
                        child: Transform.scale(
                          scale: 1.5 + (1 - value),
                          child: const Icon(Icons.favorite, color: Colors.red, size: 80),
                        ),
                      ),
                    );
                  },
                ),
              )),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, String label, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: _glass(
            context,
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: isDark ? Colors.white : cs.onSurface, size: 28),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: constants_typography.AppTypography.caption.copyWith(
            color: isDark ? Colors.white70 : cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
