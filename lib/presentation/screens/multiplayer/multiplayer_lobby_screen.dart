import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/multiplayer_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../widgets/custom_back_button.dart';

class MultiplayerLobbyScreen extends StatefulWidget {
  const MultiplayerLobbyScreen({super.key});

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  bool _refreshing = false;
  String? _cursor;
  bool _hasMore = true;

  final List<Map<String, dynamic>> _rooms = [];

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final auth = context.read<AuthProvider>();
    final token = (auth.token ?? '').trim();
    if (token.isEmpty) return;

    if (reset) {
      setState(() {
        _loading = true;
        _cursor = null;
        _hasMore = true;
        _rooms.clear();
      });
    } else {
      if (!_hasMore) return;
      setState(() {
        _refreshing = true;
      });
    }

    try {
      final res = await MultiplayerService.listPublicRooms(
        token: token,
        limit: 20,
        cursor: reset ? null : _cursor,
        q: _search.text,
      );

      final ok = res['success'] == true;
      final data = ok ? res['data'] : null;
      final items = (data is Map ? data['items'] : null);
      final nextCursor = (data is Map ? data['nextCursor'] : null)?.toString();

      if (items is List) {
        final parsed = items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);

        setState(() {
          _rooms.addAll(parsed);
          _cursor = (nextCursor != null && nextCursor.trim().isNotEmpty) ? nextCursor.trim() : null;
          _hasMore = parsed.isNotEmpty && _cursor != null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load rooms')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _load(reset: true);
    });
  }

  void _openCreate() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final name = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Lobby', style: AppTypography.subtitle1),
              const SizedBox(height: 10),
              TextField(
                controller: name,
                decoration: InputDecoration(
                  hintText: 'Lobby name (optional)',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.55),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/multiplayer/room', extra: {
                      'mode': 'create',
                      'name': name.text.trim(),
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openJoinById() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final id = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Join by Room ID', style: AppTypography.subtitle1),
              const SizedBox(height: 10),
              TextField(
                controller: id,
                decoration: InputDecoration(
                  hintText: 'room_xxx',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.55),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final rid = id.text.trim();
                    if (rid.isEmpty) return;
                    Navigator.of(context).pop();
                    context.push('/multiplayer/room', extra: {
                      'mode': 'join',
                      'roomId': rid,
                    });
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Join'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerTile(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
      ),
      child: Shimmer.fromColors(
        baseColor: cs.onSurface.withOpacity(0.08),
        highlightColor: cs.onSurface.withOpacity(0.16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 14, width: 140, color: Colors.white),
            const SizedBox(height: 10),
            Container(height: 10, width: 220, color: Colors.white),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: AppBarBackButton(color: cs.onSurface),
        title: const Text('Multiplayer'),
        actions: [
          IconButton(
            tooltip: 'Demo (Solo)',
            onPressed: () {
              context.push('/multiplayer/room', extra: {
                'mode': 'demo',
              });
            },
            icon: const Icon(Icons.smart_toy_rounded),
          ),
          IconButton(
            tooltip: 'Quick Match',
            onPressed: () {
              context.push('/multiplayer/room', extra: {
                'mode': 'matchmaking',
              });
            },
            icon: const Icon(Icons.bolt_rounded),
          ),
          IconButton(
            tooltip: 'Create',
            onPressed: _openCreate,
            icon: const Icon(Icons.add_circle_outline),
          ),
          IconButton(
            tooltip: 'Join by ID',
            onPressed: _openJoinById,
            icon: const Icon(Icons.tag),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primary.withOpacity(0.16),
                    cs.secondary.withOpacity(0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                border: Border.all(color: cs.primary.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Public Lobbies', style: AppTypography.subtitle1)),
                      TextButton.icon(
                        onPressed: () {
                          context.push('/multiplayer/room', extra: {
                            'mode': 'matchmaking',
                          });
                        },
                        icon: const Icon(Icons.bolt_rounded, size: 18),
                        label: const Text('Quick Match'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _search,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search by name',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: cs.surface.withOpacity(0.85),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_loading) ...[
              for (var i = 0; i < 6; i++) _shimmerTile(context),
            ] else if (_rooms.isEmpty) ...[
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'No rooms yet. Create one!',
                  style: AppTypography.body1.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ] else ...[
              for (final room in _rooms) _roomTile(context, room),
              const SizedBox(height: 10),
              if (_hasMore)
                Center(
                  child: TextButton.icon(
                    onPressed: _refreshing ? null : () => _load(reset: false),
                    icon: _refreshing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.expand_more),
                    label: const Text('Load more'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _roomTile(BuildContext context, Map<String, dynamic> room) {
    final cs = Theme.of(context).colorScheme;

    final roomId = (room['roomId'] ?? '').toString();
    final name = (room['name'] ?? 'Lobby').toString();
    final members = (room['members'] is List) ? (room['members'] as List).length : 0;
    final maxPlayers = int.tryParse(room['maxPlayers']?.toString() ?? '') ?? 4;

    final full = members >= maxPlayers;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          onTap: full
              ? null
              : () {
                  context.push('/multiplayer/room', extra: {
                    'mode': 'join',
                    'roomId': roomId,
                  });
                },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: AppColors.primaryGradient,
                  ),
                  child: const Icon(Icons.group, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTypography.subtitle2, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        '$members / $maxPlayers players',
                        style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (full)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Full',
                      style: AppTypography.caption.copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
