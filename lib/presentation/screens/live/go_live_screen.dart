import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';

import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/app_notifier.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/live_service.dart';
import '../../../core/services/projects_service.dart';
import '../../../core/themes/app_theme.dart';

class GoLiveScreen extends StatefulWidget {
  const GoLiveScreen({super.key});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();

  bool _starting = false;
  String? _error;

  String? _liveId;
  Map<String, dynamic>? _selectedProject;
  List<Map<String, dynamic>> _projects = [];
  bool _loadingProjects = false;
  bool _isMockLive = false;

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  LocalVideoTrack? _localVideo;
  LocalAudioTrack? _localAudio;

  bool _isScreenShare = false;
  WebViewController? _webController;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() => _loadingProjects = true);
    try {
      final res = await ProjectsService.listProjects(token: token);
      if (mounted && res['success'] == true) {
        final data = res['data'];
        final List<Map<String, dynamic>> list = [];
        if (data is Map && data['projects'] is List) {
          list.addAll((data['projects'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
        } else if (data is List) {
          list.addAll(data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
        }
        setState(() => _projects = list);
      }
    } catch (e) {
      debugPrint('Error loading projects: $e');
    } finally {
      if (mounted) setState(() => _loadingProjects = false);
    }
  }

  @override
  void dispose() {
    _stopLocalTracks();
    _listener?.dispose();
    _room?.dispose();
    _title.dispose();
    _desc.dispose();
    _webController = null;
    super.dispose();
  }

  String _normalizeLiveKitUrl(String raw) {
    final u = raw.trim();
    if (u.startsWith('https://')) return 'wss://' + u.substring('https://'.length);
    if (u.startsWith('http://')) return 'ws://' + u.substring('http://'.length);
    if (u.startsWith('wss://') || u.startsWith('ws://')) return u;
    // If backend returned a bare host (rare), default to secure websocket.
    return 'wss://' + u;
  }

  bool _isLocalhostUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('localhost') || u.contains('127.0.0.1');
  }

  String? _resolveMediaUrl(String? url) {
    return ApiService.normalizeImageUrl(url);
  }

  String? _projectThumb(Map<String, dynamic> p) {
    final cand = (p['previewImageUrl'] ??
            p['thumbnailUrl'] ??
            p['iconUrl'] ??
            p['imageUrl'] ??
            p['previewImage'] ??
            p['image'])
        ?.toString();
    return _resolveMediaUrl(cand);
  }

  Future<void> _stopLocalTracks() async {
    try {
      await _localVideo?.stop();
    } catch (_) {}
    try {
      await _localAudio?.stop();
    } catch (_) {}
    _localVideo = null;
    _localAudio = null;
  }

  Future<void> _start() async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) return;

    if (_starting) return;

    setState(() {
      _starting = true;
      _error = null;
    });

    try {
      final res = await LiveService.create(
        token: token,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        gameTitle: _selectedProject?['name'],
        gameIcon: _selectedProject?['previewImage'],
      );
      final ok = res['success'] == true;
      final data = ok ? res['data'] : null;
      if (!ok || data is! Map) throw Exception(res['message']?.toString() ?? 'Failed to create live');

      final liveId = (data['id'] ?? '').toString().trim();
      final livekitUrl = (data['livekitUrl'] ?? '').toString().trim();
      final lkToken = (data['token'] ?? '').toString().trim();
      if (liveId.isEmpty || livekitUrl.isEmpty || lkToken.isEmpty) throw Exception('Invalid live config');

      final normalizedUrl = _normalizeLiveKitUrl(livekitUrl);
      // Common dev misconfig: LiveKit URL is localhost. On a physical phone,
      // "localhost" points to the phone itself, so connection will always fail.
      if (!kIsWeb && _isLocalhostUrl(normalizedUrl)) {
        throw Exception('LiveKit URL is localhost. Use your machine IP/domain for LIVEKIT_URL.');
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
        });

      debugPrint('GoLiveScreen connecting to LiveKit: $normalizedUrl');
      await room.connect(normalizedUrl, lkToken);

      try {
        if (_isScreenShare) {
          await Future.delayed(const Duration(milliseconds: 500));
          _localVideo = await LocalVideoTrack.createScreenShareTrack(
            const ScreenShareCaptureOptions(
              captureScreenAudio: true,
              preferCurrentTab: false,
            ),
          );
        } else {
          // Fallback for Simulator which has no camera
          try {
            _localVideo = await LocalVideoTrack.createCameraTrack();
          } catch (e) {
            debugPrint('Camera track creation failed (expected on simulator): $e');
            // On simulator we might continue without video or show a placeholder
          }
        }
        
        try {
          _localAudio = await LocalAudioTrack.create();
        } catch (e) {
          debugPrint('Audio track creation failed: $e');
        }

        if (_localVideo != null) {
          await room.localParticipant?.publishVideoTrack(_localVideo!);
        }
        if (_localAudio != null) {
          await room.localParticipant?.publishAudioTrack(_localAudio!);
        }

        // If both failed on simulator, we might still want to "connect" to show we are live
        // even if no tracks are published, or show a better error.
        if (_localVideo == null && _localAudio == null && !kIsWeb) {
          debugPrint('No tracks created. This is common on Simulator.');
        }
      } catch (trackError) {
        debugPrint('Track creation error: $trackError');
        // Don't throw yet, let the room stay connected
      }

      _room = room;
      _listener = listener;
      _liveId = liveId;

      if (_isScreenShare && _selectedProject != null) {
        final projectId = (_selectedProject!['id'] ?? _selectedProject!['_id']).toString();

        String? gameUrl;
        try {
          final pr = await ProjectsService.getProjectPreviewUrl(
            token: token,
            projectId: projectId,
          );
          final ok2 = pr['success'] == true;
          final d2 = ok2 ? pr['data'] : null;
          if (d2 is Map && d2['url'] != null) {
            gameUrl = d2['url']?.toString();
          } else if (d2 is String) {
            gameUrl = d2;
          }
        } catch (e) {
          debugPrint('Failed to fetch project preview url: $e');
        }

        // Fallback (may be blocked by iOS ATS if it's plain http)
        gameUrl ??= ApiService.baseUrl.replaceAll('/api', '') + '/projects/$projectId/preview';

        _webController = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onWebResourceError: (WebResourceError error) {
                debugPrint('WebView error: ${error.description}');
              },
            ),
          )
          ..loadRequest(Uri.parse(gameUrl));
      }

      if (!mounted) return;
      setState(() {
        _starting = false;
      });

      AppNotifier.showSuccess(_isMockLive ? 'MOCK Live Mode Active' : 'You are LIVE');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _end() async {
    final token = context.read<AuthProvider>().token;
    final liveId = (_liveId ?? '').trim();
    if (token == null || token.trim().isEmpty || liveId.isEmpty) {
      _close();
      return;
    }

    try {
      await LiveService.end(token: token, liveId: liveId);
    } catch (_) {}

    try {
      await _room?.disconnect();
    } catch (_) {}
    _isMockLive = false;

    _close();
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
    required bool isDark,
    required ColorScheme cs,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : cs.surface).withOpacity(isDark ? 0.35 : 0.8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: (isDark ? Colors.white : cs.primary).withOpacity(0.12)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required ColorScheme cs,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.2) : (isDark ? Colors.black : cs.surfaceContainerHighest).withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accent : (isDark ? Colors.white : cs.onSurface).withOpacity(0.12),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? (isDark ? Colors.white : AppColors.accent) : (isDark ? Colors.white70 : cs.onSurfaceVariant), size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: isSelected ? (isDark ? Colors.white : AppColors.accent) : (isDark ? Colors.white70 : cs.onSurfaceVariant),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _projectPicker(bool isDark, ColorScheme cs) {
    if (_loadingProjects) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Select Game to Stream',
          style: AppTypography.caption.copyWith(
            color: (isDark ? Colors.white : cs.onSurface).withOpacity(0.9),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _projects.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : cs.onSurface).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: (isDark ? Colors.white : cs.onSurface).withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.videogame_asset_outlined, color: (isDark ? Colors.white : cs.onSurface).withOpacity(0.3), size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'No games found. Create a project first!',
                      style: AppTypography.caption.copyWith(color: (isDark ? Colors.white : cs.onSurface).withOpacity(0.5)),
                    ),
                  ],
                ),
              )
            : SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _projects.length,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemBuilder: (context, index) {
                    final p = _projects[index];
                    final isSelected = _selectedProject?['_id'] == p['_id'] || _selectedProject?['id'] == p['id'];
                    final imageUrl = _projectThumb(p);
                    final name = (p['name'] ?? 'Game').toString();
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedProject = p;
                          _isScreenShare = true;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 100,
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppColors.accent : (isDark ? Colors.white : cs.onSurface).withOpacity(0.1),
                            width: 2.5,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)
                          ] : [],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(17),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (imageUrl != null)
                                Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(color: isDark ? const Color(0xFF1E293B) : cs.surfaceVariant),
                                )
                              else
                                Container(color: isDark ? const Color(0xFF1E293B) : cs.surfaceVariant),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      (isDark ? Colors.black : cs.surface).withOpacity(0.85),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                right: 8,
                                bottom: 8,
                                child: Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.caption.copyWith(
                                    color: (isDark ? Colors.white : cs.onSurface),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  color: AppColors.accent.withOpacity(0.3),
                                  child: const Center(
                                    child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 32),
                                  ),
                                )
                              else
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Icon(Icons.gamepad_rounded, color: (isDark ? Colors.white : cs.onSurface).withOpacity(0.5), size: 16),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
        if (_selectedProject != null) ...[
          const SizedBox(height: 8),
          _glass(
            isDark: isDark,
            cs: cs,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videogame_asset_rounded, size: 14, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  'Streaming: ${_selectedProject!['name']}',
                  style: AppTypography.caption.copyWith(
                    color: (isDark ? Colors.white : cs.onSurface),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final publishing = room != null || _isMockLive;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : cs.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_localVideo != null)
            VideoTrackRenderer(
              _localVideo!,
            )
          else
            Container(color: isDark ? Colors.black : cs.surface),
          
          if (publishing && _isScreenShare && _webController != null)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: WebViewWidget(controller: _webController!),
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
                        borderRadius: BorderRadius.circular(18),
                        onTap: _close,
                        child: _glass(
                          isDark: isDark,
                          cs: cs,
                          child: Icon(Icons.close_rounded, color: isDark ? Colors.white.withOpacity(0.92) : cs.onSurface, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _glass(
                      isDark: isDark,
                      cs: cs,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'GO LIVE',
                            style: AppTypography.caption.copyWith(
                              color: isDark ? Colors.white : cs.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (publishing)
                      Material(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _end,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Text('End', style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      )
                    else
                      _glass(
                        isDark: isDark,
                        cs: cs,
                        child: _starting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(
                                'Setup',
                                style: AppTypography.caption.copyWith(
                                  color: isDark ? Colors.white.withOpacity(0.9) : cs.onSurface,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (!publishing)
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
              child: _glass(
                isDark: isDark,
                cs: cs,
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Title',
                      style: AppTypography.caption.copyWith(
                        color: isDark ? Colors.white.withOpacity(0.9) : cs.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _title,
                      style: AppTypography.body2.copyWith(color: isDark ? Colors.white : cs.onSurface),
                      decoration: InputDecoration(
                        hintText: 'What are you playing?',
                        hintStyle: AppTypography.body2.copyWith(color: (isDark ? Colors.white : cs.onSurface).withOpacity(0.55)),
                        filled: true,
                        fillColor: isDark ? Colors.black.withOpacity(0.35) : cs.surfaceContainerHighest.withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Description',
                      style: AppTypography.caption.copyWith(
                        color: isDark ? Colors.white.withOpacity(0.9) : cs.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _desc,
                      maxLines: 2,
                      style: AppTypography.body2.copyWith(color: isDark ? Colors.white : cs.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Say hi to viewers…',
                        hintStyle: AppTypography.body2.copyWith(color: (isDark ? Colors.white : cs.onSurface).withOpacity(0.55)),
                        filled: true,
                        fillColor: isDark ? Colors.black.withOpacity(0.35) : cs.surfaceContainerHighest.withOpacity(0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    _projectPicker(isDark, cs),
                    const SizedBox(height: 12),
                    Text(
                      'Stream Source',
                      style: AppTypography.caption.copyWith(
                        color: isDark ? Colors.white.withOpacity(0.9) : cs.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _sourceButton(
                            isDark: isDark,
                            cs: cs,
                            icon: Icons.videocam_rounded,
                            label: 'Camera',
                            isSelected: !_isScreenShare,
                            onTap: () => setState(() => _isScreenShare = false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _sourceButton(
                            isDark: isDark,
                            cs: cs,
                            icon: Icons.screenshot_monitor_rounded,
                            label: 'Game/Screen',
                            isSelected: _isScreenShare,
                            onTap: () => setState(() => _isScreenShare = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _starting ? null : _start,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: Text('Start Live', style: AppTypography.subtitle2.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: AppTypography.body2.copyWith(color: isDark ? Colors.white.withOpacity(0.85) : cs.error)),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
