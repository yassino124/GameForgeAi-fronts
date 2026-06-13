import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/services/creator_monetization_service.dart';
import '../../../core/services/game_feed_service.dart';
import '../../../core/services/users_service.dart';
import '../../../core/themes/app_theme.dart';
import '../../widgets/widgets.dart';
import '../project/project_insights_screen.dart';

class CreatorProfileScreen extends StatefulWidget {
  final String creatorId;

  const CreatorProfileScreen({
    super.key,
    required this.creatorId,
  });

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _VideoPreviewSheet extends StatefulWidget {
  final String url;

  const _VideoPreviewSheet({required this.url});

  @override
  State<_VideoPreviewSheet> createState() => _VideoPreviewSheetState();
}

class _VideoPreviewSheetState extends State<_VideoPreviewSheet> {
  VideoPlayerController? _ctrl;
  bool _init = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final url = widget.url.trim();
    if (url.isEmpty) return;
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    _ctrl = ctrl;
    try {
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.play();
      if (!mounted) return;
      setState(() => _init = true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _init = true;
      });
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final maxH = MediaQuery.of(context).size.height * 0.82;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 620, maxHeight: maxH),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF05060A) : cs.surface).withOpacity(0.92),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.10) : cs.outlineVariant.withOpacity(0.8), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withOpacity(0.55) : Colors.black.withOpacity(0.12),
                      blurRadius: 30,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: !_init
                          ? Center(child: CircularProgressIndicator(color: cs.primary))
                          : _failed
                              ? Center(
                                  child: Icon(Icons.video_library_rounded, size: 56, color: isDark ? Colors.white24 : cs.onSurfaceVariant.withOpacity(0.4)),
                                )
                              : GestureDetector(
                                  onTap: () {
                                    final c = _ctrl;
                                    if (c == null) return;
                                    if (c.value.isPlaying) {
                                      c.pause();
                                    } else {
                                      c.play();
                                    }
                                    setState(() {});
                                  },
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: _ctrl!.value.size.width,
                                      height: _ctrl!.value.size.height,
                                      child: VideoPlayer(_ctrl!),
                                    ),
                                  ),
                                ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.15),
                                Colors.transparent,
                                Colors.black.withOpacity(0.65),
                              ],
                              stops: const [0.0, 0.55, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : cs.onSurfaceVariant),
                          ),
                          const Spacer(),
                          if (_ctrl != null && _init && !_failed)
                            IconButton(
                              onPressed: () {
                                final c = _ctrl;
                                if (c == null) return;
                                if (c.value.volume > 0) {
                                  c.setVolume(0);
                                } else {
                                  c.setVolume(1);
                                }
                                setState(() {});
                              },
                              icon: Icon(
                                (_ctrl?.value.volume ?? 0) > 0 ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                                color: isDark ? Colors.white70 : cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_ctrl != null && _init && !_failed)
                      Positioned(
                        bottom: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.black.withOpacity(0.35),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                (_ctrl?.value.isPlaying ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                (_ctrl?.value.isPlaying ?? false) ? 'Playing' : 'Paused',
                                style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                              ),
                            ],
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
    );
  }
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _stats;

  List<Map<String, dynamic>> _posts = const [];
  String? _cursor;
  bool _paging = false;

  String _resolveAvatarUrl(String raw) {
    return ApiService.normalizeImageUrl(raw);
  }

  Widget _videoCard(Map<String, dynamic> post) {
    final title = _toStr(post['title'] ?? post['name'] ?? 'Video');
    final thumb = _resolvePostThumb(post);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _openVideoPreview(post),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : cs.shadow).withOpacity(isDark ? 0.55 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: _glass(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.white.withOpacity(0.06),
                  child: thumb.isEmpty
                      ? Icon(Icons.video_library_rounded, color: Colors.white.withOpacity(0.6), size: 34)
                      : Image.network(
                          thumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.video_library_rounded,
                            color: Colors.white.withOpacity(0.6),
                            size: 34,
                          ),
                        ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.62)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.55, 1.0],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.30),
                      border: Border.all(color: Colors.white.withOpacity(0.16)),
                    ),
                    child: const Center(
                      child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.subtitle2.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProjectInsightsScreen(
                            gameId: post['_id'] ?? post['id'] ?? '',
                            gameName: title,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withOpacity(0.6), blurRadius: 15, spreadRadius: 3),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('AI REVIEWS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _resolvePostThumb(Map<String, dynamic> post) {
    dynamic v = post['previewImageUrl'] ?? post['previewImage'] ?? post['thumbnailUrl'];
    if (v is Map) {
      v = v['url'] ?? v['secure_url'] ?? v['src'] ?? v['path'];
    }
    if (v is List && v.isNotEmpty) {
      final first = v.first;
      if (first is String) v = first;
      if (first is Map) {
        v = first['url'] ?? first['secure_url'] ?? first['src'] ?? first['path'];
      }
    }

    final s = (v ?? '').toString();
    return ApiService.normalizeImageUrl(s);
  }

  String _resolvePostVideo(Map<String, dynamic> post) {
    dynamic v = post['previewVideoUrl'] ?? post['trailerVideoUrl'] ?? post['videoUrl'];
    if (v == null && post['reel'] is Map) {
      final r = post['reel'] as Map;
      v = r['previewVideoUrl'] ?? r['trailerVideoUrl'] ?? r['videoUrl'];
    }
    if (v is Map) {
      v = v['url'] ?? v['secure_url'] ?? v['src'] ?? v['path'];
    }
    final s = (v ?? '').toString();
    return ApiService.normalizeImageUrl(s);
  }

  bool _isVideoPost(Map<String, dynamic> post) {
    if (post['isReel'] == true) return true;
    return _resolvePostVideo(post).trim().isNotEmpty;
  }

  Future<void> _openVideoPreview(Map<String, dynamic> post) async {
    final url = _resolvePostVideo(post).trim();
    if (url.isEmpty) return;

    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return _VideoPreviewSheet(url: url);
      },
    );
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    return int.tryParse(s) ?? double.tryParse(s)?.toInt() ?? 0;
  }

  String _normUrl(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    return 'https://$v';
  }

  Future<void> _openWebsite(String raw) async {
    final url = _normUrl(raw);
    if (url.isEmpty) return;
    try {
      final u = Uri.parse(url);
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      AppNotifier.showError('Failed to open link');
    }
  }

  Future<void> _shareProfile(BuildContext ctx, {required String username, required String creatorId}) async {
    final text = username.trim().isNotEmpty ? 'Check out @$username on GameForge AI' : 'Check out this creator on GameForge AI';
    final meta = creatorId.trim().isNotEmpty ? '\nCreator id: ${creatorId.trim()}' : '';
    try {
      Rect? origin;
      try {
        final box = ctx.findRenderObject();
        if (box is RenderBox) {
          final pos = box.localToGlobal(Offset.zero);
          origin = pos & box.size;
        }
      } catch (_) {}

      await Share.share(
        '$text$meta',
        sharePositionOrigin: origin,
      );
    } catch (_) {
      try {
        await Clipboard.setData(ClipboardData(text: '$text$meta'));
        AppNotifier.showSuccess('Copied to clipboard');
      } catch (_) {
        AppNotifier.showError('Share failed');
      }
    }
  }

  Future<void> _openTipSheet({required String creatorId, required String creatorUsername}) async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;
    if (creatorId.trim().isEmpty) return;

    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        var busy = false;
        var amount = 5.0;
        final msgCtrl = TextEditingController();

        Widget glass({required Widget child}) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 26, offset: const Offset(0, 18)),
                  ],
                ),
                child: child,
              ),
            ),
          );
        }

        Future<void> openPaymentSheet() async {
          if (busy) return;
          busy = true;
          try {
            final pk = Stripe.publishableKey;
            if (pk.isEmpty) {
              throw Exception('Missing Stripe publishable key');
            }

            final res = await CreatorMonetizationService.paymentSheet(
              token: token,
              creatorUserId: creatorId,
              type: 'tip',
              amountUsd: amount,
              message: msgCtrl.text.trim().isEmpty ? null : msgCtrl.text.trim(),
            );

            if (res['success'] != true) {
              final msg = (res['message'] ?? res['error'] ?? 'PaymentSheet request failed').toString();
              throw Exception(msg);
            }

            final data = res['data'];
            final m = (data is Map) ? Map<String, dynamic>.from(data as Map) : <String, dynamic>{};
            final customerId = m['customerId']?.toString() ?? '';
            final ephemeralKeySecret = m['ephemeralKeySecret']?.toString() ?? '';
            final paymentIntentClientSecret = m['paymentIntentClientSecret']?.toString() ?? '';
            final paymentIntentId = m['paymentIntentId']?.toString() ?? '';
            if (customerId.isEmpty || ephemeralKeySecret.isEmpty || paymentIntentClientSecret.isEmpty) {
              throw Exception('Invalid PaymentSheet data from server: ${m.isEmpty ? res.toString() : m.toString()}');
            }

            final sheetCs = Theme.of(sheetCtx).colorScheme;
            final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;

            await Stripe.instance.initPaymentSheet(
              paymentSheetParameters: SetupPaymentSheetParameters(
                merchantDisplayName: 'GameForge AI',
                customerId: customerId,
                customerEphemeralKeySecret: ephemeralKeySecret,
                paymentIntentClientSecret: paymentIntentClientSecret,
                style: isDark ? ThemeMode.dark : ThemeMode.light,
                appearance: PaymentSheetAppearance(
                  colors: PaymentSheetAppearanceColors(
                    background: sheetCs.surface,
                    primary: sheetCs.primary,
                    componentBackground: sheetCs.surface,
                    componentBorder: sheetCs.outlineVariant,
                    componentDivider: sheetCs.outlineVariant,
                    componentText: sheetCs.onSurface,
                    primaryText: sheetCs.onPrimary,
                    secondaryText: sheetCs.onSurfaceVariant,
                    placeholderText: sheetCs.onSurfaceVariant,
                    icon: sheetCs.onSurfaceVariant,
                    error: sheetCs.error,
                  ),
                ),
              ),
            );

            await Stripe.instance.presentPaymentSheet();

            if (paymentIntentId.trim().isNotEmpty) {
              try {
                await CreatorMonetizationService.confirmPaymentIntent(token: token, paymentIntentId: paymentIntentId.trim());
              } catch (_) {}
            }

            if (sheetCtx.mounted) {
              Navigator.of(sheetCtx).pop();
            }
            AppNotifier.showSuccess('Tip sent');
          } catch (e) {
            AppNotifier.showError(e.toString());
          } finally {
            busy = false;
          }
        }

        Widget amountChip(double v, void Function(VoidCallback) setModalState) {
          final selected = (amount - v).abs() < 0.01;
          return GestureDetector(
            onTap: () => setModalState(() => amount = v),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: selected ? cs.primary.withOpacity(0.14) : cs.surfaceContainerHighest.withOpacity(0.35),
                border: Border.all(color: selected ? cs.primary.withOpacity(0.38) : cs.outlineVariant.withOpacity(0.55)),
              ),
              child: Text(
                '\$$v',
                style: AppTypography.caption.copyWith(color: cs.onSurface, fontWeight: FontWeight.w900),
              ),
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            final maxH = MediaQuery.of(sheetCtx).size.height * 0.78;
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 520, maxHeight: maxH),
                  child: glass(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  creatorUsername.trim().isEmpty ? 'Send a tip' : 'Tip @$creatorUsername',
                                  style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(sheetCtx).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Support the creator and help fund new games.',
                            style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              amountChip(2, setModalState),
                              amountChip(5, setModalState),
                              amountChip(10, setModalState),
                              amountChip(20, setModalState),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: msgCtrl,
                            minLines: 1,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Message (optional)',
                              filled: true,
                              fillColor: cs.surfaceContainerHighest.withOpacity(0.4),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.7))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.7))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: cs.primary.withOpacity(0.9), width: 1.4)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.payment_rounded),
                              label: Text(busy ? 'Processing...' : 'Send tip'),
                              onPressed: busy ? null : openPaymentSheet,
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
      },
    );
  }

  Widget _skeletonPulse({required double h, double w = double.infinity, BorderRadius? radius}) {
    final r = radius ?? BorderRadius.circular(AppBorderRadius.large);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 0.55),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeInOut,
      onEnd: () {
        if (mounted) setState(() {});
      },
      builder: (context, a, _) {
        return Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: r,
            color: Colors.white.withOpacity(a * 0.16),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
        );
      },
    );
  }

  Widget _loadingSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
      children: [
        Row(
          children: [
            _skeletonPulse(h: 76, w: 76, radius: BorderRadius.circular(999)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeletonPulse(h: 16, w: 220, radius: BorderRadius.circular(10)),
                  const SizedBox(height: 10),
                  _skeletonPulse(h: 12, w: 260, radius: BorderRadius.circular(10)),
                  const SizedBox(height: 8),
                  _skeletonPulse(h: 12, w: 200, radius: BorderRadius.circular(10)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: _skeletonPulse(h: 56)),
            const SizedBox(width: 10),
            Expanded(child: _skeletonPulse(h: 56)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _skeletonPulse(h: 56)),
            const SizedBox(width: 10),
            Expanded(child: _skeletonPulse(h: 56)),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, i) => _skeletonPulse(h: 240),
        ),
      ],
    );
  }

  String _toStr(dynamic v) => (v ?? '').toString().trim();

  String _fmtDate(dynamic v) {
    try {
      final raw = _toStr(v);
      if (raw.isEmpty) return '';
      final dt = DateTime.tryParse(raw);
      if (dt == null) return raw;
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    } catch (_) {
      return _toStr(v);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Not authenticated';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profileRes = await UsersService.getPublicProfile(token: token, userId: widget.creatorId);
      final profile = profileRes['data'];

      final feedRes = await GameFeedService.listCreator(token: token, creatorId: widget.creatorId, limit: 12);
      final data = feedRes['data'];

      final posts = (data is List)
          ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false)
          : const <Map<String, dynamic>>[];

      Map<String, dynamic>? stats = (feedRes['stats'] is Map) ? Map<String, dynamic>.from(feedRes['stats'] as Map) : null;
      if (posts.isNotEmpty) {
        final st = stats ?? const <String, dynamic>{};
        final postCount = _toInt(st['postCount']);
        final totalLikes = _toInt(st['totalLikes']);
        final totalPlays = _toInt(st['totalPlays']);
        final totalRemixes = _toInt(st['totalRemixes']);

        // Fallback if backend stats are missing/zero (e.g., server not restarted).
        if (postCount == 0 && totalLikes == 0 && totalPlays == 0 && totalRemixes == 0) {
          var likes = 0;
          var plays = 0;
          var remixes = 0;
          for (final p in posts) {
            likes += _toInt(p['likeCount']);
            plays += _toInt(p['playCount']);
            remixes += _toInt(p['remixCount']);
          }
          stats = {
            'postCount': posts.length,
            'totalLikes': likes,
            'totalPlays': plays,
            'totalRemixes': remixes,
          };
        }
      }

      setState(() {
        _profile = (profile is Map) ? Map<String, dynamic>.from(profile as Map) : null;
        _stats = stats;
        _posts = posts;
        _cursor = feedRes['nextCursor']?.toString();
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

  Future<void> _loadMore() async {
    if (_paging) return;
    final next = _cursor;
    if (next == null || next.trim().isEmpty) return;

    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    setState(() => _paging = true);
    try {
      final res = await GameFeedService.listCreator(token: token, creatorId: widget.creatorId, limit: 12, cursor: next);
      final data = res['data'];
      final rows = (data is List)
          ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false)
          : const <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _posts = [..._posts, ...rows];
        _cursor = res['nextCursor']?.toString();
        _paging = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _paging = false);
      AppNotifier.showError(e.toString());
    }
  }

  Widget _glass({required Widget child, EdgeInsets padding = const EdgeInsets.all(12)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppBorderRadius.large),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  Widget _statChip({required IconData icon, required String label, required int value}) {
    return _glass(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white.withOpacity(0.92)),
          const SizedBox(width: 10),
          Text(
            value.toString(),
            style: AppTypography.subtitle2.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: Colors.white.withOpacity(0.86), fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _metric({required IconData icon, required String label, required int value}) {
    return Expanded(
      child: _glass(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white.withOpacity(0.92)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.subtitle2.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: Colors.white.withOpacity(0.86), fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameCard(Map<String, dynamic> post) {
    final title = _toStr(post['title'] ?? post['name'] ?? 'Game');
    final preview = _resolvePostThumb(post);
    final likes = _toInt(post['likeCount']);
    final plays = _toInt(post['playCount']);

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _openPlay(post),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : cs.shadow).withOpacity(isDark ? 0.55 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: _glass(
          padding: EdgeInsets.zero,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: Colors.white.withOpacity(0.06),
                      child: preview.isEmpty
                          ? Icon(Icons.videogame_asset_rounded, color: Colors.white.withOpacity(0.6), size: 34)
                          : Image.network(
                              preview,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.videogame_asset_rounded,
                                color: Colors.white.withOpacity(0.6),
                                size: 34,
                              ),
                            ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: AppColors.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withOpacity(0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              plays.toString(),
                              style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.favorite_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              likes.toString(),
                              style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black.withOpacity(0.58)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.62, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProjectInsightsScreen(
                                gameId: post['_id'] ?? post['id'] ?? '',
                                gameName: title,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.4)),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withOpacity(0.6), blurRadius: 15, spreadRadius: 3),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('AI REVIEWS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.28),
                          border: Border.all(color: Colors.white.withOpacity(0.14)),
                        ),
                        child: const Center(
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.subtitle2.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _openPlay(Map<String, dynamic> post) {
    final url = _toStr(post['webglUrl'] ?? post['url']);
    if (url.isEmpty) return;
    context.push('/play-webgl', extra: {'url': url});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    final p = _profile;
    final username = _toStr(p?['username']);
    final fullName = _toStr(p?['fullName']);
    final bio = _toStr(p?['bio']);
    final avatar = _resolveAvatarUrl(_toStr(p?['avatar']));
    final location = _toStr(p?['location']);
    final website = _toStr(p?['website']);
    final createdAt = _fmtDate(p?['createdAt']);

    final s = _stats ?? const <String, dynamic>{};
    final postCount = _toInt(s['postCount']);
    final totalLikes = _toInt(s['totalLikes']);
    final totalPlays = _toInt(s['totalPlays']);
    final totalRemixes = _toInt(s['totalRemixes']);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark ? AppColors.backgroundGradient : AppTheme.backgroundGradientLight,
          ),
          child: SafeArea(
            child: _loading
                ? _loadingSkeleton()
                : (_error != null)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error ?? 'Failed to load',
                                textAlign: TextAlign.center,
                                style: AppTypography.body2.copyWith(color: cs.onSurface.withOpacity(0.86)),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              CustomButton(
                                text: 'Retry',
                                onPressed: _load,
                                type: ButtonType.primary,
                              ),
                            ],
                          ),
                        ),
                      )
                    : NestedScrollView(
                        headerSliverBuilder: (context, innerScrolled) {
                          return [
                            SliverAppBar(
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              pinned: true,
                              expandedHeight: 240,
                              leading: IconButton(
                                onPressed: () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/dashboard?tab=home');
                                  }
                                },
                                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                              ),
                              actions: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: IconButton(
                                    onPressed: () => _openTipSheet(creatorId: widget.creatorId, creatorUsername: username),
                                    icon: const Icon(Icons.volunteer_activism_outlined),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: IconButton(
                                    onPressed: () => _shareProfile(context, username: username, creatorId: widget.creatorId),
                                    icon: const Icon(Icons.ios_share_rounded),
                                  ),
                                ),
                              ],
                              title: Text(
                                username.isEmpty ? 'Creator' : '@$username',
                                style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w900),
                              ),
                              centerTitle: true,
                              flexibleSpace: FlexibleSpaceBar(
                                collapseMode: CollapseMode.parallax,
                                background: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [cs.primary.withOpacity(0.30), AppColors.accent.withOpacity(0.20), Colors.transparent],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                                        child: const SizedBox.shrink(),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 88, AppSpacing.lg, 86),
                                      child: Align(
                                        alignment: Alignment.bottomLeft,
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: AppColors.primaryGradient,
                                                boxShadow: [
                                                  BoxShadow(color: cs.primary.withOpacity(0.18), blurRadius: 30, offset: const Offset(0, 14)),
                                                ],
                                              ),
                                              child: CircleAvatar(
                                                radius: 34,
                                                backgroundColor: Colors.white.withOpacity(0.08),
                                                backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
                                                child: avatar.isEmpty
                                                    ? Icon(Icons.person_rounded, color: Colors.white.withOpacity(0.7))
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    fullName.isNotEmpty ? fullName : (username.isEmpty ? 'Creator' : '@$username'),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: AppTypography.h4.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                                                  ),
                                                  if (bio.isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      bio,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: AppTypography.body2.copyWith(color: Colors.white.withOpacity(0.90), fontWeight: FontWeight.w700, height: 1.25),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              bottom: PreferredSize(
                                preferredSize: const Size.fromHeight(56),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 12),
                                  child: _glass(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    child: TabBar(
                                      dividerColor: Colors.transparent,
                                      labelStyle: AppTypography.caption.copyWith(fontWeight: FontWeight.w900),
                                      unselectedLabelStyle: AppTypography.caption.copyWith(fontWeight: FontWeight.w900),
                                      labelColor: Colors.white,
                                      unselectedLabelColor: Colors.white.withOpacity(0.74),
                                      indicator: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        gradient: AppColors.primaryGradient,
                                      ),
                                      indicatorSize: TabBarIndicatorSize.tab,
                                      tabs: const [
                                        Tab(text: 'Games'),
                                        Tab(text: 'Videos'),
                                        Tab(text: 'About'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ];
                        },
                        body: TabBarView(
                          children: [
                            RefreshIndicator(
                              onRefresh: _load,
                              child: NotificationListener<ScrollNotification>(
                                onNotification: (n) {
                                  if (n.metrics.pixels >= n.metrics.maxScrollExtent - 320) {
                                    _loadMore();
                                  }
                                  return false;
                                },
                                child: ListView(
                                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
                                  children: [
                                    Row(
                                      children: [
                                        _metric(icon: Icons.grid_view_rounded, label: 'Games', value: postCount),
                                        const SizedBox(width: 10),
                                        _metric(icon: Icons.play_arrow_rounded, label: 'Plays', value: totalPlays),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        _metric(icon: Icons.favorite_rounded, label: 'Likes', value: totalLikes),
                                        const SizedBox(width: 10),
                                        _metric(icon: Icons.auto_fix_high_rounded, label: 'Remixes', value: totalRemixes),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.xl),
                                    if (_posts.isEmpty)
                                      _glass(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          'No games published yet.',
                                          style: AppTypography.body2.copyWith(color: Colors.white.withOpacity(0.86), fontWeight: FontWeight.w700),
                                        ),
                                      )
                                    else
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: _posts.length,
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          mainAxisSpacing: 12,
                                          crossAxisSpacing: 12,
                                          childAspectRatio: 0.82,
                                        ),
                                        itemBuilder: (context, i) => _gameCard(_posts[i]),
                                      ),
                                    if (_paging) ...[
                                      const SizedBox(height: 18),
                                      const Center(child: CircularProgressIndicator()),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            RefreshIndicator(
                              onRefresh: _load,
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
                                children: [
                                  if (_posts.where(_isVideoPost).isEmpty)
                                    _glass(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        'No videos yet.',
                                        style: AppTypography.body2.copyWith(color: Colors.white.withOpacity(0.86), fontWeight: FontWeight.w700),
                                      ),
                                    )
                                  else
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _posts.where(_isVideoPost).length,
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 0.82,
                                      ),
                                      itemBuilder: (context, i) {
                                        final videos = _posts.where(_isVideoPost).toList(growable: false);
                                        return _videoCard(videos[i]);
                                      },
                                    ),
                                  if (_paging) ...[
                                    const SizedBox(height: 18),
                                    const Center(child: CircularProgressIndicator()),
                                  ],
                                ],
                              ),
                            ),
                            ListView(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
                              children: [
                                _glass(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Profile', style: AppTypography.subtitle1.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 10),
                                      if (username.isNotEmpty)
                                        Text(
                                          '@$username',
                                          style: AppTypography.body2.copyWith(color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.w800),
                                        ),
                                      if (fullName.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          fullName,
                                          style: AppTypography.body2.copyWith(color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.w800),
                                        ),
                                      ],
                                      if (bio.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          bio,
                                          style: AppTypography.body2.copyWith(color: Colors.white.withOpacity(0.90), fontWeight: FontWeight.w700, height: 1.35),
                                        ),
                                      ],
                                      if (location.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Icon(Icons.location_on_rounded, size: 18, color: Colors.white.withOpacity(0.82)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                location,
                                                style: AppTypography.body2.copyWith(color: Colors.white.withOpacity(0.88), fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (website.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        GestureDetector(
                                          onTap: () => _openWebsite(website),
                                          child: Row(
                                            children: [
                                              Icon(Icons.link_rounded, size: 18, color: Colors.white.withOpacity(0.82)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  website,
                                                  style: AppTypography.body2.copyWith(
                                                    color: Colors.white.withOpacity(0.92),
                                                    fontWeight: FontWeight.w900,
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: Colors.white.withOpacity(0.55),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Icon(Icons.open_in_new_rounded, size: 18, color: Colors.white.withOpacity(0.70)),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (createdAt.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_month_rounded, size: 18, color: Colors.white.withOpacity(0.82)),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Joined $createdAt',
                                              style: AppTypography.body2.copyWith(color: Colors.white.withOpacity(0.88), fontWeight: FontWeight.w700),
                                            ),
                                          ],
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
        ),
      ),
    );
  }
}
