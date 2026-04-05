import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/multiplayer_controller.dart';
import '../../../core/services/game_feed_service.dart';
import '../../../core/services/projects_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../widgets/custom_back_button.dart';

class MultiplayerRoomScreen extends StatefulWidget {
  final String mode; // create | join
  final String? roomId;
  final String? name;

  const MultiplayerRoomScreen({
    super.key,
    required this.mode,
    this.roomId,
    this.name,
  });

  @override
  State<MultiplayerRoomScreen> createState() => _MultiplayerRoomScreenState();
}

class _MultiplayerRoomScreenState extends State<MultiplayerRoomScreen> {
  final _controller = MultiplayerController();
  final _text = TextEditingController();
  final _scroll = ScrollController();
  bool _started = false;

  String? _lastNavSessionId;
  Timer? _previewRetryTimer;
  int _previewRetryCount = 0;

  @override
  void initState() {
    super.initState();
    _boot();
    _controller.addListener(_autoscroll);
    _controller.addListener(_maybeAutoOpenWebgl);
  }

  @override
  void dispose() {
    _controller.removeListener(_autoscroll);
    _controller.removeListener(_maybeAutoOpenWebgl);
    _controller.disconnect();
    _previewRetryTimer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _autoscroll() {
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

  Future<void> _maybeAutoOpenWebgl() async {
    final sid = (_controller.sessionId ?? '').trim();
    final rurl = (_controller.startedRuntimeUrl ?? '').trim();
    final pid = (_controller.startedProjectId ?? '').trim();
    if (sid.isEmpty) return;
    if (rurl.isEmpty && pid.isEmpty) return;
    if (_lastNavSessionId == sid) return;

    if (rurl.isNotEmpty) {
      _lastNavSessionId = sid;
      final room = _controller.room;
      final myId = (_controller.myUserId ?? '').trim();
      final isHost = room != null && myId.isNotEmpty && room.hostUserId == myId;
      if (!mounted) return;

      String outUrl = rurl;
      if (pid.isNotEmpty) {
        try {
          final u = Uri.parse(rurl);
          final qp = Map<String, String>.from(u.queryParameters);
          qp['projectId'] = pid;
          outUrl = u.replace(queryParameters: qp).toString();
        } catch (_) {}
      }
      context.push(
        '/play-webgl',
        extra: {
          'url': outUrl,
          'projectId': pid.isEmpty ? null : pid,
          'roomId': room?.roomId,
          'sessionId': sid,
          'isHost': isHost,
        },
      );
      return;
    }

    _previewRetryTimer?.cancel();
    _previewRetryCount = 0;

    final auth = context.read<AuthProvider>();
    final token = (auth.token ?? '').trim();
    if (token.isEmpty) return;

    try {
      final res = await ProjectsService.getProjectPreviewUrl(token: token, projectId: pid);
      final ok = res['success'] == true;
      final data = ok ? res['data'] : null;
      final url = (data is Map ? data['url'] : data)?.toString();

      if (!mounted) return;
      final u = (url ?? '').trim();
      if (u.isEmpty) {
        if (_previewRetryCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WebGL preview URL not available yet')),
          );
        }

        _previewRetryCount++;
        if (_previewRetryCount <= 8) {
          _previewRetryTimer?.cancel();
          _previewRetryTimer = Timer(const Duration(seconds: 2), () {
            if (!mounted) return;
            _maybeAutoOpenWebgl();
          });
        }
        return;
      }

      _lastNavSessionId = sid;

      final room = _controller.room;
      final myId = (_controller.myUserId ?? '').trim();
      final isHost = room != null && myId.isNotEmpty && room.hostUserId == myId;
      context.push(
        '/play-webgl',
        extra: {
          'url': u,
          'projectId': pid.isEmpty ? null : pid,
          'roomId': room?.roomId,
          'sessionId': sid,
          'isHost': isHost,
        },
      );
    } catch (_) {
      if (!mounted) return;

      if (_previewRetryCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open WebGL preview')),
        );
      }

      _previewRetryCount++;
      if (_previewRetryCount <= 8) {
        _previewRetryTimer?.cancel();
        _previewRetryTimer = Timer(const Duration(seconds: 2), () {
          if (!mounted) return;
          _maybeAutoOpenWebgl();
        });
      }
    }
  }

  Future<void> _promptStartAsHost({required String roomId}) async {
    final cs = Theme.of(context).colorScheme;
    final cProject = TextEditingController();
    final cUrl = TextEditingController();
    final cArcadePostId = TextEditingController();
    final auth = context.read<AuthProvider>();
    final token = (auth.token ?? '').trim();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        int tabIndex = 0;

        Widget projectTile(Map<String, dynamic> p) {
          final title = (p['name'] ?? 'Untitled').toString();
          final pid = (p['_id'] ?? p['id'])?.toString() ?? '';
          final buildTarget = p['buildTarget']?.toString();
          final status = p['status']?.toString();
          final hasWebgl = (buildTarget ?? '').toLowerCase().contains('webgl');

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                onTap: pid.trim().isEmpty
                    ? null
                    : () {
                        cProject.text = pid;
                      },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: hasWebgl ? AppColors.primaryGradient : null,
                          color: hasWebgl ? null : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          hasWebgl ? Icons.public : Icons.folder_open,
                          color: hasWebgl ? Colors.white : cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTypography.buttonSmall.copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pid,
                              style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (status != null && status.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status,
                            style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        Widget arcadeTile(Map<String, dynamic> p) {
          final title = (p['title'] ?? p['name'] ?? 'Game').toString();
          final postId = (p['id'] ?? p['_id'] ?? '').toString();
          final url = (p['webglUrl'] ?? p['url'] ?? '').toString();
          final u = url.trim();
          final pid = postId.trim();

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppBorderRadius.large),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                onTap: (u.isEmpty || pid.isEmpty)
                    ? null
                    : () {
                        cUrl.text = u;
                        cArcadePostId.text = pid;
                      },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.public, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTypography.buttonSmall.copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              u,
                              style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Start in Play WebGL', style: AppTypography.subtitle1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment<int>(value: 0, label: Text('Arcade')),
                            ButtonSegment<int>(value: 1, label: Text('URL')),
                            ButtonSegment<int>(value: 2, label: Text('Projects')),
                          ],
                          selected: {tabIndex},
                          onSelectionChanged: (s) {
                            if (s.isEmpty) return;
                            setModalState(() => tabIndex = s.first);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (tabIndex == 0)
                    FutureBuilder<Map<String, dynamic>>(
                      future: token.isEmpty ? Future.value({'success': false}) : GameFeedService.list(token: token, limit: 12),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                const SizedBox(width: 10),
                                Text('Loading arcade…', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                              ],
                            ),
                          );
                        }
                        final raw = snap.data;
                        final ok = raw != null && raw['success'] == true;
                        final data = ok ? (raw == null ? null : raw['data']) : null;
                        final list = (data is List) ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

                        if (list.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text('Arcade feed is empty.', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                          );
                        }

                        return ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                for (final p in list.take(10)) arcadeTile(p),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  if (tabIndex == 1) ...[
                    TextField(
                      controller: cUrl,
                      decoration: InputDecoration(
                        hintText: 'WebGL URL (https://...)',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withOpacity(0.55),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: cArcadePostId,
                      decoration: InputDecoration(
                        hintText: 'Arcade Post ID (optional)',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withOpacity(0.55),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                  if (tabIndex == 2) ...[
                    if (token.isNotEmpty)
                      FutureBuilder<Map<String, dynamic>>(
                        future: ProjectsService.listProjects(token: token),
                        builder: (context, snap) {
                          final raw = snap.data;
                          final ok = raw != null && raw['success'] == true;
                          final data = ok && raw != null ? raw['data'] : null;
                          final items = (data is List) ? data : (data is Map ? data['items'] : null);
                          final list = (items is List)
                              ? items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
                              : <Map<String, dynamic>>[];

                          if (snap.connectionState == ConnectionState.waiting) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                  const SizedBox(width: 10),
                                  Text('Loading projects…', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                                ],
                              ),
                            );
                          }

                          if (list.isNotEmpty) {
                            list.sort((a, b) {
                              final aw = (a['buildTarget']?.toString() ?? '').toLowerCase().contains('webgl');
                              final bw = (b['buildTarget']?.toString() ?? '').toLowerCase().contains('webgl');
                              if (aw == bw) return 0;
                              return aw ? -1 : 1;
                            });

                            return ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 240),
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    for (final p in list.take(8)) projectTile(p),
                                  ],
                                ),
                              ),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'No projects found. Paste a Project ID below.',
                              style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                            ),
                          );
                        },
                      ),
                    TextField(
                      controller: cProject,
                      decoration: InputDecoration(
                        hintText: 'Project ID',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withOpacity(0.55),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tip: use a project that already has WebGL preview ready.',
                      style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final pid = cProject.text.trim();
                        final url = cUrl.text.trim();
                        final postId = cArcadePostId.text.trim();

                        if (tabIndex == 2) {
                          if (pid.isEmpty) return;
                          Navigator.of(ctx).pop();
                          _controller.startMatch(roomId: roomId, projectId: pid);
                          return;
                        }

                        if (url.isEmpty) return;
                        Navigator.of(ctx).pop();
                        _controller.startMatch(roomId: roomId, runtimeUrl: url, arcadePostId: postId.isEmpty ? null : postId);
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start'),
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

  Future<void> _boot() async {
    if (_started) return;
    _started = true;

    final auth = context.read<AuthProvider>();
    final token = (auth.token ?? '').trim();
    final username = (auth.user?['username'] ?? auth.user?['name'] ?? auth.user?['email'] ?? 'player').toString();

    if (widget.mode == 'demo') {
      await _controller.startDemoRoom(username: username);
      return;
    }

    if (token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in required')));
      context.go('/signin');
      return;
    }

    await _controller.connect(token: token, username: username);

    if (widget.mode == 'matchmaking') {
      await _controller.queueMatchmaking();
      return;
    }

    if (widget.mode == 'create') {
      await _controller.createRoom(name: widget.name);
      return;
    }

    final rid = (widget.roomId ?? '').trim();
    if (rid.isNotEmpty) {
      await _controller.joinRoom(roomId: rid);
    }
  }

  Future<void> _leave() async {
    final rid = _controller.room?.roomId ?? widget.roomId;
    await _controller.leaveRoom(roomId: rid);
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final room = _controller.room;

    return Scaffold(
      appBar: AppBar(
        leading: AppBarBackButton(color: cs.onSurface),
        title: Text(widget.mode == 'matchmaking' && room == null ? 'Quick Match' : (room?.name ?? 'Lobby')),
        actions: [
          IconButton(
            tooltip: 'Leave',
            onPressed: _leave,
            icon: const Icon(Icons.exit_to_app),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final room = _controller.room;
                final err = (_controller.error ?? '').trim();
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.surfaceGradient,
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room?.roomId ?? (widget.roomId ?? '—'),
                                  style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _pill(
                                      context,
                                      icon: Icons.people,
                                      text: '${room?.members.length ?? 0} / ${room?.maxPlayers ?? 4}',
                                    ),
                                    const SizedBox(width: 8),
                                    _pill(
                                      context,
                                      icon: Icons.public,
                                      text: 'Public',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _controller.connected ? cs.tertiaryContainer : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _controller.connected ? 'LIVE' : (_controller.connecting ? 'Connecting' : 'Offline'),
                              style: AppTypography.caption.copyWith(
                                color: _controller.connected ? cs.onTertiaryContainer : cs.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (err.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          err,
                          style: AppTypography.caption.copyWith(color: cs.error, fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (widget.mode == 'matchmaking' && _controller.room == null) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(AppBorderRadius.large),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Finding players… (4 players match)',
                            style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _controller.leaveMatchmaking();
                            context.pop();
                          },
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (_controller.sessionId != null && _controller.sessionId!.trim().isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(AppBorderRadius.large),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withOpacity(0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Game started • Session ${_controller.sessionId}',
                            style: AppTypography.buttonSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),

          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final room = _controller.room;
              if (room == null) return const SizedBox.shrink();
              final myId = _controller.myUserId;
              final isHost = myId != null && room.hostUserId.trim().isNotEmpty && room.hostUserId == myId;
              final isReady = myId != null && _controller.readyUserIds.contains(myId);
              final allReady = room.members.isNotEmpty && room.members.every((m) => _controller.readyUserIds.contains(m.userId));

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        decoration: BoxDecoration(
                          color: isReady ? cs.tertiaryContainer : cs.surface,
                          borderRadius: BorderRadius.circular(AppBorderRadius.large),
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppBorderRadius.large),
                            onTap: myId == null
                                ? null
                                : () {
                                    _controller.setReady(
                                      ready: !isReady,
                                      roomId: room.roomId,
                                    );
                                  },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(isReady ? Icons.check_circle : Icons.circle_outlined, size: 18, color: cs.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Text(
                                    isReady ? 'Ready' : 'Not ready',
                                    style: AppTypography.buttonSmall.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: (isHost && allReady) ? AppColors.primaryGradient : null,
                          color: (isHost && allReady) ? null : cs.surface,
                          borderRadius: BorderRadius.circular(AppBorderRadius.large),
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppBorderRadius.large),
                            onTap: (isHost && allReady)
                                ? () {
                                    _promptStartAsHost(roomId: room.roomId);
                                  }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_arrow_rounded, size: 18, color: (isHost && allReady) ? Colors.white : cs.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Text(
                                    isHost ? (allReady ? 'Start' : 'Start (waiting)') : 'Waiting host',
                                    style: AppTypography.buttonSmall.copyWith(
                                      color: (isHost && allReady) ? Colors.white : cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: _controller.voiceJoined ? cs.tertiaryContainer : cs.surface,
                        borderRadius: BorderRadius.circular(AppBorderRadius.large),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                      ),
                      child: GestureDetector(
                        onLongPress: () {
                          if (_controller.voiceJoined) {
                            _controller.voiceStop();
                            return;
                          }

                          if (_controller.voiceLoopback) {
                            _controller.voiceSelfTestStop();
                          } else {
                            _controller.voiceSelfTestStart();
                          }
                        },
                        child: IconButton(
                          tooltip: _controller.voiceJoined
                              ? (_controller.voiceMuted ? 'Muted (tap to unmute)' : 'Live voice (tap to mute)')
                              : (_controller.voiceLoopback ? 'Self test (long-press to stop)' : 'Join voice (long-press = self test)'),
                          onPressed: () {
                            if (!_controller.voiceJoined) {
                              _controller.voiceJoin(roomId: room.roomId);
                            } else {
                              _controller.voiceToggleMute();
                            }
                          },
                          icon: Icon(
                            _controller.voiceLoopback
                                ? Icons.hearing_rounded
                                : (!_controller.voiceJoined
                                    ? Icons.mic_none_rounded
                                    : (_controller.voiceMuted ? Icons.mic_off_rounded : Icons.mic_rounded)),
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final members = _controller.room?.members ?? const [];
                final messages = _controller.messages;

                return Column(
                  children: [
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, i) {
                          final m = members[i];
                          final online = m.isOnline;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: online ? cs.surface : cs.surface.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: online 
                                  ? (_controller.readyUserIds.contains(m.userId) ? AppColors.success : cs.primary).withOpacity(0.4)
                                  : cs.outlineVariant.withOpacity(0.3),
                                width: _controller.readyUserIds.contains(m.userId) ? 2 : 1,
                              ),
                              boxShadow: _controller.readyUserIds.contains(m.userId) ? [
                                BoxShadow(
                                  color: AppColors.success.withOpacity(0.15),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ] : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: online ? (_controller.readyUserIds.contains(m.userId) ? AppColors.success : cs.primary) : cs.outlineVariant,
                                      ),
                                    ),
                                    if (online && _controller.readyUserIds.contains(m.userId))
                                      TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        duration: const Duration(milliseconds: 800),
                                        builder: (context, value, _) {
                                          return Container(
                                            width: 20 * value,
                                            height: 20 * value,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: AppColors.success.withOpacity(1.0 - value)),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.username,
                                      style: AppTypography.buttonSmall.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: online ? Colors.white : Colors.white38,
                                      ),
                                    ),
                                    Text(
                                      _controller.readyUserIds.contains(m.userId) ? 'READY' : (online ? 'WAITING' : 'OFFLINE'),
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                        color: _controller.readyUserIds.contains(m.userId) ? AppColors.success : (online ? cs.primary : Colors.white24),
                                      ),
                                    ),
                                  ],
                                ),
                                if (room?.hostUserId == m.userId) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.shield_rounded, size: 14, color: AppColors.warning.withOpacity(0.8)),
                                ],
                              ],
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemCount: members.length,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: messages.length,
                        itemBuilder: (context, i) {
                          final msg = messages[i];
                          return _messageBubble(context, msg.username, msg.text);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant.withOpacity(0.6))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Message…',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest.withOpacity(0.55),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, {required IconData icon, required String text}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(text, style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _messageBubble(BuildContext context, String username, String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            username,
            style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(text, style: AppTypography.body2),
        ],
      ),
    );
  }

  void _send() {
    final v = _text.text;
    _text.clear();
    _controller.sendChat(text: v, roomId: _controller.room?.roomId ?? widget.roomId);
  }
}
