import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/services/game_feed_service.dart';
import '../../../core/themes/app_theme.dart';
import '../../widgets/widgets.dart';

class ArcadeFeedScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ArcadeFeedScreen({
    super.key,
    this.onBack,
  });

  @override
  State<ArcadeFeedScreen> createState() => _ArcadeFeedScreenState();
}

class _ArcadeFeedScreenState extends State<ArcadeFeedScreen> with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final PageController _pageController = PageController();

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _posts = const [];
  String? _nextCursor;

  int _activeIndex = 0;
  WebViewController? _activeWeb;
  String? _activePostId;

  String? _burstPostId;
  double _burstT = 0;
  Timer? _burstTimer;

  bool _paging = false;
  Timer? _playDebounce;
  late final AnimationController _neonCtrl;

  final Map<String, List<Map<String, dynamic>>> _localComments = <String, List<Map<String, dynamic>>>{};
  final Map<String, String?> _commentsCursor = <String, String?>{};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _neonCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _loadFirst();
  }

  Future<void> _installDoubleTapHook(WebViewController ctrl) async {
    // iOS WebView (platform view) can consume Flutter gestures. Install a JS listener
    // so a double-tap inside the WebGL canvas can still trigger like.
    try {
      await ctrl.runJavaScript('''
(function(){
  try {
    if (window.__gfDoubleTapInstalled) return;
    window.__gfDoubleTapInstalled = true;
    var last = 0;
    document.addEventListener('touchend', function(ev){
      var now = Date.now();
      if (now - last < 320) {
        if (window.GF && window.GF.postMessage) window.GF.postMessage('doubleTap');
        last = 0;
      } else {
        last = now;
      }
    }, {passive:true});
  } catch(e) {}
})();
''');
    } catch (_) {}
  }

  int _postCommentCount(Map<String, dynamic> p) {
    final v = p['commentCount'];
    if (v is num) return v.toInt();
    final parsed = int.tryParse(v?.toString() ?? '');
    if (parsed != null) return parsed;
    final postId = _postId(p);
    final local = _localComments[postId];
    return (local == null) ? 0 : local.length;
  }

  Future<void> _openCommentsSheet(Map<String, dynamic> p) async {
    final postId = _postId(p);
    if (postId.isEmpty) return;

    final me = context.read<AuthProvider>().user;
    final m = (me is Map) ? me : null;
    final username = (m?['username'] ?? m?['name'] ?? m?['email'] ?? '').toString();

    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    _localComments[postId] ??= <Map<String, dynamic>>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return _CommentsSheet(
          token: token,
          postId: postId,
          username: username,
          initialItems: List<Map<String, dynamic>>.from(_localComments[postId] ?? const []),
          onItemsChanged: (items, cursor) {
            _localComments[postId] = items;
            _commentsCursor[postId] = cursor;
          },
          onCommentCountChanged: (count) {
            if (!mounted) return;
            setState(() => p['commentCount'] = count);
          },
        );
      },
    );
  }

  Future<Uint8List?> _qrPng(String data) async {
    try {
      final painter = QrPainter(
        data: data,
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
      );
      final imgData = await painter.toImageData(720, format: ImageByteFormat.png);
      return imgData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _requestSavePermission() async {
    try {
      final st = await Permission.photosAddOnly.request();
      if (st.isGranted) return true;
    } catch (_) {}

    try {
      final st = await Permission.photos.request();
      return st.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<void> _savePngToPhotos(Uint8List bytes, {required String name}) async {
    final ok = await _requestSavePermission();
    if (!ok) {
      if (mounted) AppNotifier.showError('Photos permission denied');
      return;
    }

    try {
      final res = await ImageGallerySaver.saveImage(
        bytes,
        quality: 100,
        name: name,
      );
      final success = (res is Map) ? (res['isSuccess'] == true || res['success'] == true) : true;
      if (mounted) {
        success ? AppNotifier.showSuccess('Saved to Photos') : AppNotifier.showError('Failed to save');
      }
    } catch (e) {
      if (mounted) AppNotifier.showError(e.toString());
    }
  }

  @override
  void dispose() {
    _playDebounce?.cancel();
    _burstTimer?.cancel();
    _neonCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _goBack() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    if (!mounted) return;

    final onBack = widget.onBack;
    if (onBack != null) {
      onBack();
      return;
    }

    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/dashboard?tab=home');
  }

  Widget _buildTopBar() {
    final cs = Theme.of(context).colorScheme;
    final i = (_posts.isEmpty) ? 0 : (_activeIndex.clamp(0, _posts.length - 1));
    final total = _posts.length;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
        child: Row(
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _goBack,
                child: _glass(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Icon(Icons.arrow_back_rounded, color: Colors.white.withOpacity(0.92), size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _glass(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sports_esports_rounded, color: Colors.white.withOpacity(0.92), size: 18),
                  const SizedBox(width: 10),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPress: _openQuickNav,
                    child: Text(
                      'Arcade',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _glass(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (total > 0) ? Colors.white.withOpacity(0.85) : cs.onSurface.withOpacity(0.25),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    (total > 0) ? '${i + 1}/$total' : '0/0',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withOpacity(0.92),
                      fontWeight: FontWeight.w900,
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

  void _confetti() {
    if (!mounted) return;
    final entry = OverlayEntry(
      builder: (context) => const _MiniConfetti(),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    Future.delayed(const Duration(milliseconds: 820), entry.remove);
  }

  void _heartBurst(String postId) {
    _burstTimer?.cancel();
    setState(() {
      _burstPostId = postId;
      _burstT = 0;
    });

    const total = 420;
    const step = 16;
    var t = 0;
    _burstTimer = Timer.periodic(const Duration(milliseconds: step), (timer) {
      t += step;
      final v = (t / total).clamp(0.0, 1.0);
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _burstT = v);
      if (v >= 1) {
        timer.cancel();
        setState(() => _burstPostId = null);
      }
    });
  }

  Future<void> _loadFirst() async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await GameFeedService.list(token: token, limit: 10);
      final data = res['data'];
      final list = (data is List) ? data : const [];
      if (!mounted) return;
      setState(() {
        _posts = list.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
        _nextCursor = res['nextCursor']?.toString();
        _loading = false;
      });
      await _ensureActiveWebView();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _likeWithBurst(Map<String, dynamic> p) async {
    final postId = _postId(p);
    if (postId.isEmpty) return;
    if (!_postLikedByMe(p)) {
      try {
        await HapticFeedback.selectionClick();
      } catch (_) {}
      _heartBurst(postId);
      await _toggleLike(p);
    } else {
      _heartBurst(postId);
    }
  }

  Future<void> _loadMoreIfNeeded(int index) async {
    if (_paging) return;
    if (_nextCursor == null || _nextCursor!.trim().isEmpty) return;
    if (index < _posts.length - 3) return;

    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    setState(() => _paging = true);
    try {
      final res = await GameFeedService.list(token: token, limit: 10, cursor: _nextCursor);
      final data = res['data'];
      final list = (data is List) ? data : const [];
      if (!mounted) return;

      final next = list.map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
      setState(() {
        _posts = [..._posts, ...next];
        _nextCursor = res['nextCursor']?.toString();
        _paging = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _paging = false);
    }
  }

  Map<String, dynamic>? _postAt(int index) {
    if (index < 0 || index >= _posts.length) return null;
    return _posts[index];
  }

  String _postId(Map<String, dynamic> p) => (p['id'] ?? p['_id'] ?? '').toString();

  String _postTitle(Map<String, dynamic> p) => (p['title'] ?? p['name'] ?? 'Game').toString();

  String _postWebglUrl(Map<String, dynamic> p) => (p['webglUrl'] ?? p['url'] ?? '').toString();

  String _postPreview(Map<String, dynamic> p) => (p['previewImageUrl'] ?? p['previewImage'] ?? '').toString();

  String _postProjectId(Map<String, dynamic> p) => (p['projectId'] ?? '').toString();

  int _postLikeCount(Map<String, dynamic> p) {
    final v = p['likeCount'];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  bool _postLikedByMe(Map<String, dynamic> p) => p['likedByMe'] == true;

  Future<void> _ensureActiveWebView() async {
    final p = _postAt(_activeIndex);
    if (p == null) return;

    final postId = _postId(p);
    if (postId.isEmpty) return;

    final url = _postWebglUrl(p).trim();
    if (url.isEmpty) return;

    if (_activeWeb != null && _activePostId == postId) return;

    final ctrl = WebViewController();
    ctrl
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'GF',
        onMessageReceived: (msg) {
          final v = msg.message.trim().toLowerCase();
          if (v == 'doubletap') {
            final cur = _postAt(_activeIndex);
            if (cur != null) _likeWithBurst(cur);
          }
        },
      );

    ctrl.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          _debouncedPlay(postId);
          _installDoubleTapHook(ctrl);
        },
      ),
    );

    try {
      await ctrl.loadRequest(Uri.parse(url));
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _activeWeb = ctrl;
      _activePostId = postId;
    });
  }

  void _debouncedPlay(String postId) {
    _playDebounce?.cancel();
    _playDebounce = Timer(const Duration(milliseconds: 650), () async {
      if (!mounted) return;
      final token = context.read<AuthProvider>().token;
      if (token == null || token.trim().isEmpty) return;
      try {
        await GameFeedService.play(token: token, postId: postId);
      } catch (_) {}
    });
  }

  Future<void> _toggleLike(Map<String, dynamic> p) async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    final postId = _postId(p);
    if (postId.isEmpty) return;

    final liked = _postLikedByMe(p);
    final before = _postLikeCount(p);

    setState(() {
      p['likedByMe'] = !liked;
      p['likeCount'] = liked ? (before - 1).clamp(0, 1 << 30) : before + 1;
    });

    try {
      final res = liked
          ? await GameFeedService.unlike(token: token, postId: postId)
          : await GameFeedService.like(token: token, postId: postId);
      final data = res['data'];
      if (!mounted) return;
      if (data is Map) {
        final likeCount = (data['likeCount'] is num) ? (data['likeCount'] as num).toInt() : null;
        final likedNext = data['liked'] == true;
        setState(() {
          p['likedByMe'] = likedNext;
          if (likeCount != null) p['likeCount'] = likeCount;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        p['likedByMe'] = liked;
        p['likeCount'] = before;
      });
    }
  }

  Future<void> _remix(Map<String, dynamic> p) async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    final postId = _postId(p);
    if (postId.isEmpty) return;

    try {
      final res = await GameFeedService.remix(token: token, postId: postId);
      final data = res['data'];
      final projectId = (data is Map)
          ? (data['projectId']?.toString() ?? (data['data']?['projectId']?.toString() ?? ''))
          : '';

      if (!mounted) return;

      if (projectId.trim().isEmpty) {
        AppNotifier.showSuccess('Remix started');
        context.go('/dashboard?tab=projects');
        return;
      }

      AppNotifier.showSuccess('Remix started');
      context.go('/project-detail', extra: {'projectId': projectId});
    } catch (e) {
      AppNotifier.showError(e.toString());
    }
  }

  Future<Uint8List?> _capturePng(GlobalKey key) async {
    try {
      final ctx = key.currentContext;
      if (ctx == null) return null;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final img = await boundary.toImage(pixelRatio: 3.0);
      final data = await img.toByteData(format: ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _openShareBuildSheet(Map<String, dynamic> p) async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    final postId = _postId(p);
    if (postId.isEmpty) return;

    final title = _postTitle(p).trim();
    final url = _postWebglUrl(p).trim();
    final preview = _postPreview(p).trim();
    if (url.isEmpty) return;

    final shareCardKey = GlobalKey();
    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        var sharing = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final maxH = MediaQuery.of(sheetCtx).size.height * 0.84;

            Future<void> copy(String v) async {
              await Clipboard.setData(ClipboardData(text: v));
              if (mounted) AppNotifier.showSuccess('Copied');
            }

            Future<void> shareNow() async {
              if (sharing) return;
              sharing = true;
              setModalState(() {});

              try {
                final bytes = await _capturePng(shareCardKey);
                if (bytes != null && bytes.isNotEmpty) {
                  final dir = await getTemporaryDirectory();
                  final f = File('${dir.path}/gameforge_arcade_${DateTime.now().millisecondsSinceEpoch}.png');
                  await f.writeAsBytes(bytes);
                  final caption = 'Play my game in 10s — scan the QR\n$url';
                  final box = sheetCtx.findRenderObject() as RenderBox?;
                  final origin = (box != null)
                      ? box.localToGlobal(Offset.zero) & box.size
                      : Rect.fromLTWH(0, 0, MediaQuery.of(sheetCtx).size.width, MediaQuery.of(sheetCtx).size.height);
                  await Share.shareXFiles([XFile(f.path)], text: caption, sharePositionOrigin: origin);
                  _confetti();
                  return;
                }
              } catch (_) {
              } finally {
                sharing = false;
                if (mounted) setModalState(() {});
              }

              try {
                await Share.share(url);
              } catch (_) {}
            }

            Future<void> saveCard() async {
              final bytes = await _capturePng(shareCardKey);
              if (bytes == null || bytes.isEmpty) {
                if (mounted) AppNotifier.showError('Failed to generate share card');
                return;
              }
              await _savePngToPhotos(bytes, name: 'gameforge_card_${DateTime.now().millisecondsSinceEpoch}');
              _confetti();
            }

            Future<void> saveQr() async {
              final png = await _qrPng(url);
              if (png == null || png.isEmpty) {
                if (mounted) AppNotifier.showError('Failed to generate QR');
                return;
              }
              await _savePngToPhotos(png, name: 'gameforge_qr_${DateTime.now().millisecondsSinceEpoch}');
              _confetti();
            }

            Widget glass({required Widget child}) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface.withOpacity(0.86),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: 22,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              );
            }

            Widget actionChip({required IconData icon, required String label, required VoidCallback onTap}) {
          return GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: cs.surfaceContainerHighest.withOpacity(0.55),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: cs.onSurface),
                  const SizedBox(width: 8),
                  Text(label, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          );
        }

            Widget shareCardWidget() {
          return RepaintBoundary(
            key: shareCardKey,
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(color: cs.primary.withOpacity(0.22), blurRadius: 26, offset: const Offset(0, 18)),
                  ],
                ),
                child: _NeonFrame(
                  animation: _neonCtrl,
                  radius: 22,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (preview.isNotEmpty)
                          Image.network(preview, fit: BoxFit.cover)
                        else
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [cs.primary.withOpacity(0.95), AppColors.accent.withOpacity(0.85)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: Icon(Icons.sports_esports_rounded, color: Colors.white.withOpacity(0.92), size: 56),
                            ),
                          ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.58),
                                Colors.transparent,
                                Colors.black.withOpacity(0.72),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.55, 1.0],
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [AppColors.accent.withOpacity(0.28), Colors.transparent],
                                radius: 1.2,
                                center: const Alignment(0.65, -0.75),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: Colors.black.withOpacity(0.22),
                              border: Border.all(color: Colors.white.withOpacity(0.18)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.92),
                                    boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.45), blurRadius: 12)],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'ARCADE',
                                  style: AppTypography.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 14,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      title.isEmpty ? 'Game' : title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.h4.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        height: 1.05,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Built with GameForge',
                                      style: AppTypography.caption.copyWith(
                                        color: Colors.white.withOpacity(0.92),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 92,
                                  height: 92,
                                  padding: const EdgeInsets.all(8),
                                  color: Colors.white,
                                  child: LayoutBuilder(
                                    builder: (context, c) {
                                      final s = c.biggest.shortestSide;
                                      final qr = (s - 20).clamp(42.0, 62.0);
                                      return Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              QrImageView(
                                                data: url,
                                                version: QrVersions.auto,
                                                size: qr,
                                                backgroundColor: Colors.white,
                                              ),
                                              Container(
                                                width: 16,
                                                height: 16,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.black.withOpacity(0.12)),
                                                ),
                                                child: Icon(Icons.gamepad_rounded, size: 11, color: cs.primary),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'Scan',
                                              style: AppTypography.caption.copyWith(
                                                fontWeight: FontWeight.w900,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
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
        }

            return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(maxHeight: maxH),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: glass(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Share build', style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w900)),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetCtx).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      shareCardWidget(),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Share Now',
                        onPressed: shareNow,
                        type: ButtonType.primary,
                        icon: const Icon(Icons.ios_share_rounded),
                        isFullWidth: true,
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Save Share Card',
                        onPressed: saveCard,
                        type: ButtonType.secondary,
                        icon: const Icon(Icons.download_rounded),
                        isFullWidth: true,
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Save QR to Photos',
                        onPressed: saveQr,
                        type: ButtonType.secondary,
                        icon: const Icon(Icons.qr_code_rounded),
                        isFullWidth: true,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('WebGL', style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Playable link', style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900, color: cs.onSurfaceVariant)),
                            const SizedBox(height: 8),
                            Text(url, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                actionChip(icon: Icons.copy_rounded, label: 'Copy', onTap: () => copy(url)),
                                const SizedBox(width: 10),
                                actionChip(
                                  icon: Icons.open_in_new_rounded,
                                  label: 'Open',
                                  onTap: () async {
                                    try {
                                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                    } catch (_) {}
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('QR code', style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 10))],
                          ),
                          child: QrImageView(
                            data: url,
                            version: QrVersions.auto,
                            size: 190,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: actionChip(icon: Icons.copy_rounded, label: 'Copy link for QR', onTap: () => copy(url)),
                      ),
                      const SizedBox(height: 6),
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

    try {
      await GameFeedService.share(token: token, postId: postId);
    } catch (_) {}
  }

  Future<void> _share(Map<String, dynamic> p) async {
    await _openShareBuildSheet(p);
  }

  void _openFullscreenPlay(Map<String, dynamic> p) {
    final url = _postWebglUrl(p).trim();
    if (url.isEmpty) return;
    context.push('/play-webgl', extra: {'url': url});
  }

  Future<void> _openQuickNav() async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.large)),
      ),
      builder: (context) {
        Widget tile({required IconData icon, required String label, required String tab}) {
          return ListTile(
            leading: Icon(icon),
            title: Text(label, style: AppTypography.body1.copyWith(fontWeight: FontWeight.w800)),
            onTap: () {
              Navigator.of(context).pop();
              this.context.go('/dashboard?tab=$tab');
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                tile(icon: Icons.home_rounded, label: 'Home', tab: 'home'),
                tile(icon: Icons.folder_rounded, label: 'Projects', tab: 'projects'),
                tile(icon: Icons.grid_view_rounded, label: 'Templates', tab: 'templates'),
                tile(icon: Icons.person_rounded, label: 'Profile', tab: 'profile'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreview(Map<String, dynamic> p) {
    final cs = Theme.of(context).colorScheme;
    final img = _postPreview(p).trim();
    if (img.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: img,
        fit: BoxFit.cover,
        placeholder: (context, _) => Container(color: Colors.black.withOpacity(0.6)),
        errorWidget: (context, _, __) => Container(color: Colors.black.withOpacity(0.6)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.85), cs.surfaceContainerHighest.withOpacity(0.45)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _glass({required Widget child, EdgeInsets? padding}) {
    final cs = Theme.of(context).colorScheme;
    final r = BorderRadius.circular(18);
    return AnimatedBuilder(
      animation: _neonCtrl,
      builder: (context, _) {
        final t = _neonCtrl.value;
        final glow = 0.22 + 0.10 * (0.5 + 0.5 * math.sin(t * math.pi * 2));
        final borderA = Color.lerp(cs.primary.withOpacity(0.55), AppColors.accent.withOpacity(0.55), 0.5 + 0.5 * math.sin((t + 0.18) * math.pi * 2))!;

        return ClipRRect(
          borderRadius: r,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: r,
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.22),
                    cs.surface.withOpacity(0.16),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: borderA.withOpacity(0.55), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.34),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: cs.primary.withOpacity(glow),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _tagChip(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Text(
        t,
        style: AppTypography.caption.copyWith(
          color: Colors.white.withOpacity(0.90),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildPage(Map<String, dynamic> p, int index) {
    final cs = Theme.of(context).colorScheme;
    final title = _postTitle(p);
    final liked = _postLikedByMe(p);
    final likeCount = _postLikeCount(p);
    final commentCount = _postCommentCount(p);
    final creator = (p['creatorUsername'] ?? p['creator'] ?? '').toString().trim();
    final tags = (p['tags'] is List) ? (p['tags'] as List).map((e) => e?.toString() ?? '').where((e) => e.trim().isNotEmpty).toList() : <String>[];

    final isActive = index == _activeIndex;
    final web = (isActive && _activePostId == _postId(p)) ? _activeWeb : null;

    final burst = (_burstPostId != null && _burstPostId == _postId(p)) ? _burstT : 1.2;
    final burstVisible = (_burstPostId != null && _burstPostId == _postId(p));
    final heartScale = 0.65 + (1 - (burst - 0.5).abs() * 1.3).clamp(0.0, 1.0) * 0.55;
    final heartOpacity = (1.0 - burst).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            onDoubleTap: () => _likeWithBurst(p),
            behavior: HitTestBehavior.opaque,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: Padding(
                padding: EdgeInsets.zero,
                child: isActive
                    ? (web != null ? WebViewWidget(controller: web) : _buildPreview(p))
                    : _buildPreview(p),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.62),
                  Colors.transparent,
                  Colors.black.withOpacity(0.72),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        if (burstVisible)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: heartOpacity,
                  child: Transform.scale(
                    scale: heartScale,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 128,
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: AppSpacing.lg,
          right: 92,
          bottom: AppSpacing.xxl + 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (creator.isNotEmpty)
                _glass(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent,
                          boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 10)],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '@$creator',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withOpacity(0.92),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              if (creator.isNotEmpty) const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.h4.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              if (p['description'] != null && p['description'].toString().trim().isNotEmpty)
                Text(
                  p['description'].toString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body2.copyWith(
                    color: Colors.white.withOpacity(0.88),
                    height: 1.3,
                  ),
                ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.take(4).map(_tagChip).toList(growable: false),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _PillButton(
                    icon: Icons.fullscreen_rounded,
                    label: 'Play',
                    onTap: () => _openFullscreenPlay(p),
                  ),
                  const SizedBox(width: 10),
                  _PillButton(
                    icon: Icons.auto_fix_high_rounded,
                    label: 'Remix',
                    onTap: () => _remix(p),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          right: AppSpacing.lg,
          bottom: AppSpacing.xxl + 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: likeCount.toString(),
                active: liked,
                onTap: () => _toggleLike(p),
              ),
              const SizedBox(height: 14),
              _ActionButton(
                icon: Icons.mode_comment_outlined,
                label: commentCount.toString(),
                onTap: () => _openCommentsSheet(p),
              ),
              const SizedBox(height: 14),
              _ActionButton(
                icon: Icons.ios_share_rounded,
                label: 'Share',
                onTap: () => _share(p),
              ),
            ],
          ),
        ),
        if (!isActive)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.surface.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Text(
                      'Swipe to play',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white.withOpacity(0.92),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _loadFirst,
      child: _loading
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 220),
                Center(child: CircularProgressIndicator()),
              ],
            )
          : (_error != null)
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    const SizedBox(height: 160),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surface.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                      ),
                      child: Text(
                        _error!,
                        style: AppTypography.body2.copyWith(color: cs.onSurface),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PillButton(
                      icon: Icons.refresh_rounded,
                      label: 'Retry',
                      onTap: _loadFirst,
                    ),
                  ],
                )
              : (_posts.isEmpty)
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        const SizedBox(height: 160),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: cs.surface.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Arcade is empty', style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface)),
                              const SizedBox(height: 8),
                              Text(
                                'Publish a WebGL project to start the feed.',
                                style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant, height: 1.35),
                              ),
                              const SizedBox(height: 14),
                              _PillButton(
                                icon: Icons.folder_open_rounded,
                                label: 'Go to Projects',
                                onTap: () => context.go('/dashboard?tab=projects'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 68),
                          child: PageView.builder(
                            controller: _pageController,
                            scrollDirection: Axis.vertical,
                            itemCount: _posts.length,
                            onPageChanged: (i) async {
                              setState(() => _activeIndex = i);
                              await _ensureActiveWebView();
                              await _loadMoreIfNeeded(i);
                            },
                            itemBuilder: (context, index) {
                              final p = _posts[index];
                              return _buildPage(p, index);
                            },
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _buildTopBar(),
                        ),
                      ],
                    ),
    );
  }
}

class _NeonFrame extends StatelessWidget {
  final Animation<double> animation;
  final double radius;
  final Widget child;

  const _NeonFrame({
    required this.animation,
    required this.radius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          painter: _NeonBorderPainter(
            t: animation.value,
            radius: radius,
            primary: cs.primary,
            accent: AppColors.accent,
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: child,
          ),
        );
      },
    );
  }
}

class _NeonBorderPainter extends CustomPainter {
  final double t;
  final double radius;
  final Color primary;
  final Color accent;

  _NeonBorderPainter({
    required this.t,
    required this.radius,
    required this.primary,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3),
      Radius.circular(radius),
    );

    final sweep = SweepGradient(
      transform: GradientRotation(t * math.pi * 2),
      colors: [
        primary.withOpacity(0.0),
        primary.withOpacity(0.95),
        accent.withOpacity(0.95),
        primary.withOpacity(0.0),
      ],
      stops: const [0.0, 0.35, 0.72, 1.0],
    );

    final paintGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..shader = sweep.createShader(Offset.zero & size)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final paintStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = sweep.createShader(Offset.zero & size);

    canvas.drawRRect(r, paintGlow);
    canvas.drawRRect(r, paintStroke);
  }

  @override
  bool shouldRepaint(covariant _NeonBorderPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.radius != radius || oldDelegate.primary != primary || oldDelegate.accent != accent;
  }
}

class _MiniConfetti extends StatefulWidget {
  const _MiniConfetti();

  @override
  State<_MiniConfetti> createState() => _MiniConfettiState();
}

class _MiniConfettiState extends State<_MiniConfetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 720))..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = Curves.easeOutCubic.transform(_c.value);
          final op = (1.0 - v).clamp(0.0, 1.0);
          return Opacity(
            opacity: op,
            child: CustomPaint(
              painter: _ConfettiPainter(t: v),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;

  _ConfettiPainter({required this.t});

  double _rand(int i) {
    final x = math.sin(i * 999.9) * 10000;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = 18;
    for (var i = 0; i < n; i++) {
      final rx = _rand(i * 7 + 3);
      final ry = _rand(i * 11 + 5);
      final drift = (_rand(i * 13 + 9) - 0.5) * 140;
      final x = size.width * rx + drift * t;
      final y = size.height * (0.30 + ry * 0.55) + t * 220;
      final s = 4 + _rand(i * 17 + 2) * 7;

      final c = Color.lerp(
        const Color(0xFFFF3D8D),
        const Color(0xFF00E5FF),
        _rand(i * 19 + 1),
      )!
          .withOpacity((1.0 - t).clamp(0.0, 1.0));

      final p = Paint()..color = c;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: s, height: s * 1.6), const Radius.circular(2)),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.t != t;
}

class _CommentsSheet extends StatefulWidget {
  final String token;
  final String postId;
  final String username;
  final List<Map<String, dynamic>> initialItems;
  final void Function(List<Map<String, dynamic>> items, String? cursor) onItemsChanged;
  final ValueChanged<int> onCommentCountChanged;

  const _CommentsSheet({
    required this.token,
    required this.postId,
    required this.username,
    required this.initialItems,
    required this.onItemsChanged,
    required this.onCommentCountChanged,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  late final TextEditingController _inputCtrl;

  final _speech = stt.SpeechToText();
  bool _listening = false;
  bool _speechReady = false;

  final _rec = AudioRecorder();
  bool _recording = false;
  int _recStartedAtMs = 0;

  final _player = AudioPlayer();
  String? _playingCommentId;
  String? _playingUrl;
  StreamSubscription<PlayerState>? _playerSub;

  late List<Map<String, dynamic>> _items;
  String? _cursor;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inputCtrl = TextEditingController();
    _items = List<Map<String, dynamic>>.from(widget.initialItems);
    _playerSub = _player.playerStateStream.listen((st) {
      if (!mounted) return;
      if (st.processingState == ProcessingState.completed) {
        setState(() {
          _playingCommentId = null;
          _playingUrl = null;
        });
      }
    });
    _loadFirst();
  }

  @override
  void dispose() {
    try {
      _speech.stop();
    } catch (_) {}
    try {
      _rec.dispose();
    } catch (_) {}
    try {
      _playerSub?.cancel();
    } catch (_) {}
    try {
      _player.dispose();
    } catch (_) {}
    _inputCtrl.dispose();
    super.dispose();
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  Future<bool> _ensureMicPermission() async {
    try {
      final cur = await Permission.microphone.status;
      if (cur.isGranted) return true;
      if (cur.isPermanentlyDenied || cur.isRestricted) {
        try {
          await openAppSettings();
        } catch (_) {}
        return false;
      }

      final st = await Permission.microphone.request();
      if (st.isGranted) return true;
      if (st.isPermanentlyDenied || st.isRestricted) {
        try {
          await openAppSettings();
        } catch (_) {}
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      await _stopRecordAndUpload();
      return;
    }

    final ok = await _ensureMicPermission();
    if (!ok) {
      if (mounted) AppNotifier.showError('Enable microphone permission in Settings');
      return;
    }

    try {
      final can = await _rec.hasPermission();
      if (!can) {
        if (mounted) AppNotifier.showError('Enable microphone permission in Settings');
        return;
      }
    } catch (_) {}

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/gf_voice_${_nowMs()}.m4a';
    try {
      await _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
        ),
        path: filePath,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recStartedAtMs = _nowMs();
      });
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}
    } catch (e) {
      if (mounted) AppNotifier.showError('Failed to start recording: ${e.toString()}');
    }
  }

  Future<void> _stopRecordAndUpload() async {
    String? path;
    try {
      path = await _rec.stop();
    } catch (_) {
      path = null;
    }

    if (!mounted) return;
    setState(() => _recording = false);

    if (path == null || path.trim().isEmpty) {
      AppNotifier.showError('Recording failed');
      return;
    }

    final durationMs = (_recStartedAtMs > 0) ? (_nowMs() - _recStartedAtMs) : null;
    final f = File(path);
    if (!await f.exists()) {
      AppNotifier.showError('Recording file missing');
      return;
    }

    try {
      final res = await GameFeedService.addAudioComment(
        token: widget.token,
        postId: widget.postId,
        file: f,
        durationMs: durationMs,
      );
      final data = res['data'];
      if (!mounted) return;
      if (data is Map) {
        final entry = Map<String, dynamic>.from(data);
        setState(() {
          _items.insert(0, entry);
        });
        widget.onItemsChanged(_items, _cursor);

        final cc = entry['commentCount'];
        if (cc is num) widget.onCommentCountChanged(cc.toInt());
        try {
          await HapticFeedback.selectionClick();
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(e.toString());
    }
  }

  String _fmtMs(num? ms) {
    final m = (ms is num) ? ms.toInt() : 0;
    final s = (m / 1000).floor();
    final mm = (s / 60).floor();
    final ss = s % 60;
    final mmStr = mm.toString();
    final ssStr = ss.toString().padLeft(2, '0');
    return '$mmStr:$ssStr';
  }

  Future<void> _togglePlayAudio(String commentId, String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    try {
      if (_playingCommentId == commentId) {
        if (_player.playing) {
          await _player.pause();
        } else {
          await _player.play();
        }
        if (mounted) setState(() {});
        return;
      }

      await _player.stop();
      await _player.setUrl(u);
      _playingCommentId = commentId;
      _playingUrl = u;
      await _player.play();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError('Audio play failed: ${e.toString()}');
      setState(() {
        _playingCommentId = null;
        _playingUrl = null;
      });
    }
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _stopListening();
      return;
    }

    try {
      if (!_speechReady) {
        _speechReady = await _speech.initialize(
          onStatus: (s) {
            if (!mounted) return;
            if (s.toLowerCase().contains('done') || s.toLowerCase().contains('notlistening')) {
              setState(() => _listening = false);
            }
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => _listening = false);
          },
        );
      }
      if (!_speechReady) {
        if (mounted) AppNotifier.showError('Speech recognition not available');
        return;
      }
    } catch (_) {
      if (mounted) AppNotifier.showError('Speech recognition init failed');
      return;
    }

    await _startListening();
  }

  Future<void> _startListening() async {
    if (!mounted) return;
    setState(() => _listening = true);
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}

    try {
      await _speech.listen(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        onResult: (res) {
          final recognized = res.recognizedWords.trim();
          if (recognized.isEmpty) return;
          if (!_inputCtrl.text.contains(recognized)) {
            _inputCtrl.text = recognized;
            _inputCtrl.selection = TextSelection.collapsed(offset: _inputCtrl.text.length);
            if (mounted) setState(() {});
          }
          if (res.finalResult) {
            if (mounted) setState(() => _listening = false);
          }
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _listening = false);
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _listening = false);
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  Future<void> _loadFirst() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await GameFeedService.listComments(token: widget.token, postId: widget.postId, limit: 30);
      final data = res['data'];
      final list = (data is List) ? data : const [];
      final next = res['nextCursor']?.toString();
      if (!mounted) return;

      setState(() {
        _items = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _cursor = next;
        _loading = false;
      });
      widget.onItemsChanged(_items, _cursor);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _send() async {
    final txt = _inputCtrl.text.trim();
    if (txt.isEmpty) return;

    try {
      final res = await GameFeedService.addComment(token: widget.token, postId: widget.postId, text: txt);
      final data = res['data'];
      if (!mounted) return;
      if (data is Map) {
        final entry = Map<String, dynamic>.from(data);
        setState(() {
          _items.insert(0, entry);
          _inputCtrl.clear();
        });
        widget.onItemsChanged(_items, _cursor);

        final cc = entry['commentCount'];
        if (cc is num) widget.onCommentCountChanged(cc.toInt());
        try {
          await HapticFeedback.selectionClick();
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(e.toString());
    }
  }

  Widget _row(Map<String, dynamic> c) {
    final cs = Theme.of(context).colorScheme;
    final author = (c['username'] ?? c['author'] ?? '').toString();
    final text = (c['text'] ?? '').toString();
    final type = (c['type'] ?? 'text').toString().toLowerCase();
    final id = (c['id'] ?? c['_id'] ?? '').toString();
    final audioUrl = (c['audioUrl'] ?? '').toString();
    final durationMs = c['audioDurationMs'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [cs.primary.withOpacity(0.9), AppColors.accent.withOpacity(0.9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                author.isEmpty ? 'U' : author.characters.first.toUpperCase(),
                style: AppTypography.caption.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(author.isEmpty ? 'User' : author, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                if (type == 'audio' && audioUrl.trim().isNotEmpty)
                  StreamBuilder<Duration>(
                    stream: _player.positionStream,
                    builder: (context, snap) {
                      final pos = snap.data ?? Duration.zero;
                      final playingThis = (_playingCommentId == id && _playingUrl == audioUrl.trim());
                      final knownMs = (durationMs is num) ? durationMs.toInt() : 0;
                      final playingTotal = _player.duration ?? Duration(milliseconds: knownMs);
                      final total = playingThis ? playingTotal : Duration(milliseconds: knownMs);
                      final totalMs = total.inMilliseconds;
                      final posMs = (playingThis ? pos.inMilliseconds : 0).clamp(0, totalMs <= 0 ? 1 << 30 : totalMs);
                      final frac = (totalMs > 0) ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => _togglePlayAudio(id, audioUrl),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    cs.surfaceContainerHighest.withOpacity(0.55),
                                    cs.surface.withOpacity(0.40),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
                                boxShadow: [
                                  BoxShadow(
                                    color: (playingThis ? AppColors.accent : cs.primary).withOpacity(0.18),
                                    blurRadius: 20,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: playingThis ? [AppColors.accent, const Color(0xFFFF3D8D)] : [cs.primary, AppColors.accent],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Icon(
                                      playingThis && _player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: cs.onPrimary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 6,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(999),
                                            color: Colors.black.withOpacity(0.18),
                                          ),
                                          child: FractionallySizedBox(
                                            widthFactor: frac,
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(999),
                                                gradient: LinearGradient(
                                                  colors: [cs.primary.withOpacity(0.95), AppColors.accent.withOpacity(0.95)],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${_fmtMs(posMs)} / ${_fmtMs(totalMs)}',
                                          style: AppTypography.caption.copyWith(
                                            color: cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  )
                else
                  Text(text, style: AppTypography.body2.copyWith(color: cs.onSurface, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxH = MediaQuery.of(context).size.height * 0.84;
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: inset),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxH),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface.withOpacity(0.86),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 22,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Comments',
                              style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 1, color: cs.outlineVariant.withOpacity(0.4)),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : (_error != null)
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Failed to load comments',
                                          style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                                        ),
                                        const SizedBox(height: 12),
                                        _PillButton(
                                          icon: Icons.refresh_rounded,
                                          label: 'Retry',
                                          onTap: _loadFirst,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : _items.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(18),
                                        child: Text(
                                          'Be the first to comment',
                                          style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                                      itemCount: _items.length,
                                      itemBuilder: (context, i) => _row(_items[i]),
                                    ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputCtrl,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              decoration: InputDecoration(
                                hintText: 'Write a comment…',
                                filled: true,
                                fillColor: cs.surfaceContainerHighest.withOpacity(0.55),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  borderSide: BorderSide(color: cs.primary.withOpacity(0.7)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _toggleRecord,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOut,
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: _recording
                                      ? [const Color(0xFFFF3D8D), AppColors.error]
                                      : [cs.surfaceContainerHighest.withOpacity(0.65), cs.surface.withOpacity(0.45)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: _recording ? Colors.white.withOpacity(0.22) : cs.outlineVariant.withOpacity(0.5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_recording ? AppColors.error : cs.primary).withOpacity(_recording ? 0.30 : 0.16),
                                    blurRadius: _recording ? 28 : 16,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _recording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded,
                                color: _recording ? Colors.white : cs.onSurface,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _toggleListening,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOut,
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: _listening
                                      ? [AppColors.accent, const Color(0xFFFF3D8D)]
                                      : [cs.surfaceContainerHighest.withOpacity(0.65), cs.surface.withOpacity(0.45)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: _listening ? Colors.white.withOpacity(0.22) : cs.outlineVariant.withOpacity(0.5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_listening ? AppColors.accent : cs.primary).withOpacity(_listening ? 0.30 : 0.16),
                                    blurRadius: _listening ? 26 : 16,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                color: _listening ? Colors.white : cs.onSurface,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _send,
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [cs.primary, AppColors.accent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.primary.withOpacity(0.22),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.send_rounded, color: cs.onPrimary, size: 20),
                            ),
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
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scale = _down ? 0.96 : 1.0;
    final c = widget.active ? AppColors.error : Colors.white;
    final glow = widget.active ? AppColors.error.withOpacity(0.22) : cs.primary.withOpacity(0.16);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: scale,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.surface.withOpacity(0.42),
                    cs.surface.withOpacity(0.22),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: glow,
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: c, size: 30),
            ),
            const SizedBox(height: 8),
            Text(
              widget.label,
              style: AppTypography.caption.copyWith(
                color: Colors.white.withOpacity(0.92),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scale = _down ? 0.97 : 1.0;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: [cs.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.30),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AppColors.accent.withOpacity(0.16),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: cs.onPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: AppTypography.caption.copyWith(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
