import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/game_feed_service.dart';
import '../../../core/services/users_service.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> with TickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;

  late final AnimationController _bgCtrl;

  late final stt.SpeechToText _stt;
  bool _sttReady = false;
  bool _listening = false;

  final Map<String, String> _creatorAvatarCache = <String, String>{};
  final Set<String> _creatorAvatarLoading = <String>{};

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _all = const [];
  String? _cursor;
  bool _paging = false;

  String _query = '';

  bool _loadingCollections = false;
  Map<String, List<String>> _myCollections = <String, List<String>>{};

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _stt = stt.SpeechToText();
    _initStt();
    _loadFirst();
    _loadMyCollections();
    _searchCtrl.addListener(_onSearchChanged);
  }

  String _collectionsKey() {
    final auth = context.read<AuthProvider>();
    final u = auth.user;
    final uid = (u?['id'] ?? u?['_id'] ?? u?['userId'] ?? '').toString().trim();
    return uid.isEmpty ? 'discovery.my_collections.v1' : 'discovery.my_collections.v1.$uid';
  }

  Future<void> _loadMyCollections() async {
    setState(() => _loadingCollections = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_collectionsKey());
      if (raw == null || raw.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _myCollections = <String, List<String>>{};
          _loadingCollections = false;
        });
        return;
      }

      final decoded = jsonDecode(raw);
      final next = <String, List<String>>{};
      if (decoded is Map) {
        for (final e in decoded.entries) {
          final k = e.key.toString().trim();
          if (k.isEmpty) continue;
          final v = e.value;
          if (v is List) {
            next[k] = v.map((x) => x.toString()).where((x) => x.trim().isNotEmpty).toList();
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _myCollections = next;
        _loadingCollections = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCollections = false);
    }
  }

  Future<void> _saveMyCollections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enc = jsonEncode(_myCollections);
      await prefs.setString(_collectionsKey(), enc);
    } catch (_) {}
  }

  Future<void> _createCollectionFlow({String? seedPostId}) async {
    final picked = await _pickPostsForNewCollection(seedPostId: seedPostId);
    final seed = (seedPostId ?? '').trim();
    if (picked.isEmpty && seed.isEmpty) return;

    final nameCtrl = TextEditingController();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0B0D16) : cs.surface,
          title: const Text('New collection'),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: 'Collection name'),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(nameCtrl.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    final n = (name ?? '').trim();
    if (n.isEmpty) return;

    final idsToSave = <String>{...picked};
    if (seed.isNotEmpty) idsToSave.add(seed);

    setState(() {
      final next = Map<String, List<String>>.from(_myCollections);
      next.putIfAbsent(n, () => <String>[]);
      final cur = [...(next[n] ?? <String>[])];
      for (final id in idsToSave) {
        if (id.trim().isEmpty) continue;
        if (!cur.contains(id)) cur.insert(0, id);
      }
      next[n] = cur;
      _myCollections = next;
    });
    await _saveMyCollections();
  }

  Future<List<String>> _pickPostsForNewCollection({String? seedPostId}) async {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seed = (seedPostId ?? '').trim();

    final items = [..._all];
    final picked = <String>{};
    if (seed.isNotEmpty) picked.add(seed);

    final res = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        var mode = 'all';
        var local = <String>{...picked};
        final searchCtrl = TextEditingController();

        List<Map<String, dynamic>> filtered() {
          Iterable<Map<String, dynamic>> it = items;
          if (mode == 'games') {
            it = it.where((p) => !_isReel(p));
          } else if (mode == 'reels') {
            it = it.where((p) => _isReel(p));
          }
          final q = searchCtrl.text.trim().toLowerCase();
          if (q.isNotEmpty) {
            it = it.where((p) {
              final t = _title(p).toLowerCase();
              final c = _creator(p).toLowerCase();
              return t.contains(q) || c.contains(q);
            });
          }
          return it.take(80).toList(growable: false);
        }

        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final list = filtered();
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B0D16) : cs.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : cs.outlineVariant.withOpacity(0.7),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pick games / reels',
                            style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(sheetCtx).pop(local.toList()),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search in feed…',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (_) => setSheet(() {}),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: mode == 'all',
                          onSelected: (_) => setSheet(() => mode = 'all'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Games'),
                          selected: mode == 'games',
                          onSelected: (_) => setSheet(() => mode = 'games'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Reels'),
                          selected: mode == 'reels',
                          onSelected: (_) => setSheet(() => mode = 'reels'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (ctx2, i) {
                          final p = list[i];
                          final pid = _postId(p);
                          final checked = local.contains(pid);
                          final preview = _previewUrl(p).trim();
                          return CheckboxListTile(
                            value: checked,
                            onChanged: (v) {
                              setSheet(() {
                                if (v == true) {
                                  local.add(pid);
                                } else {
                                  local.remove(pid);
                                }
                              });
                            },
                            secondary: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: preview.isEmpty
                                    ? Container(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.06)
                                            : cs.surfaceContainerHighest.withOpacity(0.55),
                                        child: Center(
                                          child: Icon(
                                            _isReel(p)
                                                ? Icons.bolt_rounded
                                                : Icons.videogame_asset_rounded,
                                            size: 20,
                                            color: isDark
                                                ? Colors.white30
                                                : cs.onSurfaceVariant.withOpacity(0.5),
                                          ),
                                        ),
                                      )
                                    : _netThumb(
                                        preview,
                                        isDark: isDark,
                                        cs: cs,
                                        fit: BoxFit.cover,
                                        iconSize: 22,
                                      ),
                              ),
                            ),
                            title: Text(
                              _title(p),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w900),
                            ),
                            subtitle: Text(
                              _isReel(p) ? 'Reel • @${_creator(p)}' : 'Game • @${_creator(p)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: isDark ? Colors.white60 : cs.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return res ?? const <String>[];
  }

  Future<void> _addPostToCollection(Map<String, dynamic> p) async {
    final pid = _postId(p).trim();
    if (pid.isEmpty) return;

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final keys = _myCollections.keys.toList()..sort();
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B0D16) : cs.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : cs.outlineVariant.withOpacity(0.7),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Save to collection',
                        style: AppTypography.subtitle1.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetCtx).pop();
                      await _createCollectionFlow(seedPostId: pid);
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New collection'),
                  ),
                ),
                const SizedBox(height: 10),
                if (keys.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No collections yet',
                      style: AppTypography.body2.copyWith(
                        color: isDark ? Colors.white60 : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  ...keys.map((k) {
                    final ids = _myCollections[k] ?? const <String>[];
                    final already = ids.contains(pid);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        k,
                        style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${ids.length} games',
                        style: AppTypography.caption.copyWith(
                          color: isDark ? Colors.white60 : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      trailing: already
                          ? const Icon(Icons.check_circle_rounded)
                          : const Icon(Icons.add_circle_outline_rounded),
                      onTap: () async {
                        setState(() {
                          final next = Map<String, List<String>>.from(_myCollections);
                          final list = [...(next[k] ?? <String>[])];
                          if (!list.contains(pid)) list.insert(0, pid);
                          next[k] = list;
                          _myCollections = next;
                        });
                        await _saveMyCollections();
                        if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                      },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _creatorsTabBody(List<Map<String, dynamic>> creators) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadFirst,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
        children: [
          _searchBar(),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Top Creators',
                style: AppTypography.subtitle1.copyWith(
                  color: isDark ? Colors.white : cs.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _openCreatorsAllSheet(creators),
                child: Text(
                  'See all',
                  style: AppTypography.caption.copyWith(
                    color: isDark ? Colors.white70 : cs.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (creators.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No creators yet',
                  style: AppTypography.subtitle1.copyWith(
                    color: isDark ? Colors.white60 : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: creators.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.1,
              ),
              itemBuilder: (ctx2, i) {
                final c = creators[i];
                final id = (c['id'] ?? '').toString();
                final username = (c['username'] ?? 'Creator').toString();
                var avatar = (c['avatar'] ?? '').toString();
                final reels = (c['reels'] ?? 0).toString();
                final rank = i + 1;
                final isTop = rank <= 3;
                
                if (avatar.trim().isEmpty && id.trim().isNotEmpty) {
                  final cached = _creatorAvatarCache[id.trim()];
                  if (cached != null && cached.trim().isNotEmpty) {
                    avatar = cached;
                  } else {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _prefetchCreatorAvatar(id);
                    });
                  }
                }

                return _Pressable(
                  onTap: () {
                    if (id.trim().isEmpty) return;
                    context.push('/creator/$id');
                  },
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.15) : cs.outlineVariant.withOpacity(0.8),
                        width: 1.2,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          (isDark ? const Color(0xFF151929) : cs.surface).withOpacity(0.95),
                          (isDark ? const Color(0xFF0A0C14) : cs.surface).withOpacity(0.9),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          child: Row(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  _neonAvatar(avatar, isDark: isDark, cs: cs, size: 52, glow: isTop),
                                  if (isTop)
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        child: Text(
                                          '#$rank',
                                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '@$username',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.subtitle2.copyWith(
                                        color: isDark ? Colors.white : cs.onSurface,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.local_fire_department_rounded, size: 12, color: AppColors.accent),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$reels Reels',
                                          style: AppTypography.caption.copyWith(
                                            color: isDark ? Colors.white60 : cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? Colors.white30 : cs.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _neonAvatar(
    String avatar, {
    required bool isDark,
    required ColorScheme cs,
    double size = 54,
    bool glow = true,
  }) {
    final ring = size + 8;
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (context, _) {
        final t = _bgCtrl.value;
        final rot = t * 6.283185307179586;
        final halo = glow ? (0.12 + (t * 0.10)) : 0.10;
        return Container(
          width: ring,
          height: ring,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              transform: GradientRotation(rot),
              colors: [
                AppColors.primary,
                AppColors.secondary,
                AppColors.accent,
                AppColors.primary,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(isDark ? halo : (halo * 0.65)),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                width: size,
                height: size,
                child: _netThumb(
                  avatar,
                  isDark: isDark,
                  cs: cs,
                  fit: BoxFit.cover,
                  iconSize: 26,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pillBadge(
    String text, {
    required bool isDark,
    required ColorScheme cs,
    Gradient? gradient,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: gradient,
        color: gradient == null ? Colors.black.withOpacity(0.35) : null,
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initStt() async {
    try {
      final ok = await _stt.initialize(
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            _sttReady = false;
          });
        },
        onStatus: (s) {
          if (!mounted) return;
          if (s == 'done' || s == 'notListening') {
            setState(() => _listening = false);
          }
        },
      );
      if (!mounted) return;
      setState(() => _sttReady = ok);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sttReady = false);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _bgCtrl.dispose();
    try {
      _stt.stop();
    } catch (_) {}
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    if (!_sttReady) {
      await _initStt();
    }
    if (!_sttReady) return;

    if (_listening) {
      try {
        await _stt.stop();
      } catch (_) {}
      if (!mounted) return;
      setState(() => _listening = false);
      return;
    }

    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    setState(() => _listening = true);
    await _stt.listen(
      listenMode: stt.ListenMode.search,
      partialResults: true,
      onResult: (res) {
        if (!mounted) return;
        final text = res.recognizedWords.trim();
        if (text.isEmpty) return;
        _searchCtrl.text = text;
        _searchCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _searchCtrl.text.length),
        );
        setState(() => _query = text);
      },
    );
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _query = _searchCtrl.text.trim());
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
      final res = await GameFeedService.list(token: token, limit: 80);
      final data = res['data'];
      final list = (data is List) ? data : const [];
      final posts = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);

      if (!mounted) return;
      setState(() {
        _all = posts;
        _cursor = res['nextCursor']?.toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
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
      final res = await GameFeedService.list(token: token, limit: 80, cursor: next);
      final data = res['data'];
      final list = (data is List) ? data : const [];
      final posts = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);

      if (!mounted) return;
      setState(() {
        _all = [..._all, ...posts];
        _cursor = res['nextCursor']?.toString();
        _paging = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _paging = false);
    }
  }

  int _asInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  int _score(Map<String, dynamic> p) {
    final likes = _asInt(p['likeCount']);
    final plays = _asInt(p['playCount']);
    final views = _asInt(p['viewCount']);
    final remixes = _asInt(p['remixCount']);
    return likes * 4 + plays * 2 + views + remixes * 6;
  }

  DateTime? _asDate(dynamic v) {
    final s = v?.toString();
    if (s == null || s.trim().isEmpty) return null;
    return DateTime.tryParse(s);
  }

  String _postId(Map<String, dynamic> p) => (p['id'] ?? p['_id'] ?? '').toString();

  String _heroTag(Map<String, dynamic> p) {
    final id = _postId(p).trim();
    final url = _webglUrl(p).trim();
    if (id.isNotEmpty) return 'disc_thumb_$id';
    if (url.isNotEmpty) return 'disc_thumb_${url.hashCode}';
    return 'disc_thumb_${p.hashCode}';
  }

  String _title(Map<String, dynamic> p) => (p['title'] ?? p['name'] ?? 'Game').toString();

  Map<String, dynamic>? _creatorObj(Map<String, dynamic> p) {
    final c = p['creator'];
    if (c is Map<String, dynamic>) return c;
    if (c is Map) return Map<String, dynamic>.from(c);
    return null;
  }

  String _creator(Map<String, dynamic> p) {
    final c = _creatorObj(p);
    final v = p['creatorUsername'] ?? p['creatorName'] ?? c?['username'] ?? c?['handle'] ?? c?['name'] ?? 'Creator';
    return v.toString();
  }

  String _creatorId(Map<String, dynamic> p) {
    final c = _creatorObj(p);
    final v = p['creatorId'] ?? p['creatorUserId'] ?? c?['_id'] ?? c?['id'] ?? c?['userId'] ?? p['creator'] ?? '';
    return v.toString();
  }

  String _creatorAvatar(Map<String, dynamic> p) {
    final c = _creatorObj(p);
    dynamic v = p['creatorAvatar'] ??
        p['creatorAvatarUrl'] ??
        p['avatar'] ??
        p['creatorPhoto'] ??
        c?['avatar'] ??
        c?['avatarUrl'] ??
        c?['photoUrl'] ??
        c?['imageUrl'] ??
        c?['profileImage'] ??
        c?['photo'];
    if (v is Map) {
      v = v['url'] ?? v['secure_url'] ?? v['src'] ?? v['path'];
    }
    final raw = (v ?? '').toString();
    final norm = ApiService.normalizeImageUrl(raw);
    if (norm.trim().isNotEmpty) return norm;
    final cid = _creatorId(p).trim();
    if (cid.isNotEmpty) {
      final cached = _creatorAvatarCache[cid];
      if (cached != null && cached.trim().isNotEmpty) return cached;
      
      // Trigger prefetch if not already loading or cached
      if (!_creatorAvatarLoading.contains(cid)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _prefetchCreatorAvatar(cid);
        });
      }
    }
    final name = _creator(p).trim();
    if (name.isEmpty) return '';
    final encoded = Uri.encodeComponent(name);
    return 'https://ui-avatars.com/api/?name=$encoded&size=256&bold=true&background=6D5DF6&color=FFFFFF';
  }

  Future<void> _prefetchCreatorAvatar(String creatorId) async {
    final cid = creatorId.trim();
    if (cid.isEmpty) return;
    if (_creatorAvatarCache.containsKey(cid)) return;
    if (_creatorAvatarLoading.contains(cid)) return;

    final token = context.read<AuthProvider>().token;

    _creatorAvatarLoading.add(cid);
    try {
      debugPrint('Fetching creator avatar for ID: $cid');
      final res = await ApiService.get(
        '/users/${cid.trim()}/public',
        token: (token != null && token.trim().isNotEmpty) ? token : null,
      );
      
      final data = res['user'] ?? res['data'] ?? res;
      if (data is Map) {
        dynamic v = data['avatar'] ?? 
                   data['avatarUrl'] ?? 
                   data['photoUrl'] ?? 
                   data['imageUrl'] ?? 
                   data['profileImage'] ?? 
                   data['photo'];
                   
        if (v is Map) {
          v = v['url'] ?? v['secure_url'] ?? v['src'] ?? v['path'];
        }
        
        final url = ApiService.normalizeImageUrl((v ?? '').toString());
        if (url.trim().isNotEmpty) {
          debugPrint('Successfully found avatar for $cid: $url');
          if (!mounted) return;
          setState(() {
            _creatorAvatarCache[cid] = url;
          });
        } else {
          debugPrint('No avatar found in public profile for $cid');
        }
      } else {
        debugPrint('Invalid response format for creator $cid profile: $res');
      }
    } catch (e) {
      debugPrint('Error fetching creator $cid profile: $e');
    } finally {
      _creatorAvatarLoading.remove(cid);
    }
  }

  String _genre(Map<String, dynamic> p) => (p['genre'] ?? p['gameGenre'] ?? '').toString();

  List<String> _tags(Map<String, dynamic> p) {
    final v = p['tags'];
    if (v is List) {
      return v.map((e) => (e ?? '').toString().trim()).where((e) => e.isNotEmpty).take(8).toList(growable: false);
    }
    return const [];
  }

  String _previewUrl(Map<String, dynamic> p) {
    dynamic v = p['previewImageUrl'] ?? p['previewImage'] ?? p['thumbnailUrl'];
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
    final raw = (v ?? '').toString();
    return ApiService.normalizeImageUrl(raw);
  }

  String _webglUrl(Map<String, dynamic> p) => (p['webglUrl'] ?? p['url'] ?? '').toString();

  bool _isReel(Map<String, dynamic> p) {
    if (p['isReel'] == true) return true;
    final pv = (p['previewVideoUrl'] ?? p['trailerVideoUrl'] ?? p['videoUrl'] ?? '').toString().trim();
    return pv.isNotEmpty;
  }

  Map<String, dynamic> _norm(Map<String, dynamic> p) => Map<String, dynamic>.from(p);

  bool _matchesQuery(Map<String, dynamic> p, String q) {
    final raw = q.trim().toLowerCase();
    final qq = raw.startsWith('#') ? raw.substring(1) : raw;
    if (qq.isEmpty) return true;

    final t = _title(p).toLowerCase();
    final c = _creator(p).toLowerCase();
    final g = _genre(p).toLowerCase();
    final tags = _tags(p).join(' ').toLowerCase();

    return t.contains(qq) || c.contains(qq) || g.contains(qq) || tags.contains(qq);
  }

  Widget _netThumb(
    String url, {
    required bool isDark,
    required ColorScheme cs,
    BoxFit fit = BoxFit.cover,
    double iconSize = 32,
  }) {
    final u = url.trim();
    if (u.isEmpty) {
      return Container(
        color: isDark ? Colors.white.withOpacity(0.03) : cs.surfaceContainerHighest.withOpacity(0.55),
        child: Center(
          child: Icon(
            Icons.sports_esports_rounded,
            size: iconSize,
            color: isDark ? Colors.white24 : cs.onSurfaceVariant.withOpacity(0.4),
          ),
        ),
      );
    }

    return Image.network(
      u,
      fit: fit,
      errorBuilder: (_, __, ___) => Container(
        color: isDark ? Colors.white.withOpacity(0.03) : cs.surfaceContainerHighest.withOpacity(0.55),
        child: Center(
          child: Icon(
            Icons.image_not_supported_rounded,
            size: iconSize,
            color: isDark ? Colors.white24 : cs.onSurfaceVariant.withOpacity(0.4),
          ),
        ),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: isDark ? Colors.white.withOpacity(0.03) : cs.surfaceContainerHighest.withOpacity(0.55),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: (isDark ? Colors.white : cs.primary).withOpacity(0.75),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPreview(Map<String, dynamic> post) async {
    final p = _norm(post);
    final url = _webglUrl(p).trim();
    final hero = _heroTag(p);

    await HapticFeedback.selectionClick();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final cs = Theme.of(sheetCtx).colorScheme;
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;

        final title = _title(p);
        final creator = _creator(p);
        final genre = _genre(p);
        final tags = _tags(p);
        final preview = _previewUrl(p);
        final likes = _asInt(p['likeCount']);
        final plays = _asInt(p['playCount']);

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg + MediaQuery.of(sheetCtx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : cs.outlineVariant.withOpacity(0.8), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.12),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (isDark ? const Color(0xFF0A0C14) : cs.surface).withOpacity(0.96),
                    (isDark ? const Color(0xFF10162A) : cs.surface).withOpacity(0.96),
                  ],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Material(
                  color: Colors.transparent,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.h4.copyWith(
                                    color: isDark ? Colors.white : cs.onSurface,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: () => Navigator.of(sheetCtx).pop(),
                                icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '@$creator',
                            style: AppTypography.body2.copyWith(
                              color: isDark ? Colors.white.withOpacity(0.86) : cs.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (genre.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _pill(Icons.category_rounded, genre),
                          ],
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: tags.map((t) => _tagPill(t)).toList(growable: false),
                            ),
                          ],
                          const SizedBox(height: 14),
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.04) : cs.surfaceContainerHighest.withOpacity(0.55),
                                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.07) : cs.outlineVariant.withOpacity(0.6)),
                                ),
                                child: Hero(
                                  tag: hero,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: _netThumb(
                                      preview,
                                      isDark: isDark,
                                      cs: cs,
                                      fit: BoxFit.cover,
                                      iconSize: 36,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _metric('Plays', plays.toString(), Icons.play_arrow_rounded)),
                              const SizedBox(width: 10),
                              Expanded(child: _metric('Likes', likes.toString(), Icons.favorite_rounded)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: url.isEmpty
                                      ? null
                                      : () {
                                          Navigator.of(sheetCtx).pop();
                                          context.push('/play-webgl', extra: {'url': url, 'projectId': p['projectId']});
                                        },
                                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                  label: const Text('Play Preview'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    final cid = (p['creatorId'] ?? p['creatorUserId'] ?? '').toString();
                                    if (cid.trim().isEmpty) return;
                                    Navigator.of(sheetCtx).pop();
                                    context.push('/creator/$cid');
                                  },
                                  icon: const Icon(Icons.person_rounded, size: 18),
                                  label: const Text('Creator'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? Colors.white : cs.onSurface,
                                    side: BorderSide(color: isDark ? Colors.white.withOpacity(0.16) : cs.outlineVariant.withOpacity(0.8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.of(sheetCtx).pop();
                                await _addPostToCollection(p);
                              },
                              icon: const Icon(Icons.bookmark_add_rounded),
                              label: const Text('Save to collection'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pill(IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : cs.outlineVariant.withOpacity(0.75)),
        color: (isDark ? Colors.black : cs.surface).withOpacity(isDark ? 0.32 : 0.72),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.white70 : cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: isDark ? Colors.white.withOpacity(0.86) : cs.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickFilters(List<Map<String, dynamic>> posts) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final genreCount = <String, int>{};
    final tagCount = <String, int>{};

    for (final p in posts) {
      final g = _genre(p).trim();
      if (g.isNotEmpty) {
        genreCount[g] = (genreCount[g] ?? 0) + 1;
      }
      for (final t in _tags(p)) {
        final tt = t.trim();
        if (tt.isEmpty) continue;
        tagCount[tt] = (tagCount[tt] ?? 0) + 1;
      }
    }

    final topGenres = genreCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTags = tagCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final chips = <String>[
      ...topGenres.take(6).map((e) => e.key),
      ...topTags.take(6).map((e) => '#${e.key}'),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        itemBuilder: (context, i) {
          final text = chips[i];
          final selected = _query.trim().toLowerCase() == text.trim().toLowerCase();
          return Padding(
            padding: EdgeInsets.only(right: i == chips.length - 1 ? 0 : 10),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _searchCtrl.text = text;
                _searchCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: _searchCtrl.text.length),
                );
                _searchFocus.unfocus();
                setState(() => _query = text);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: selected ? AppColors.primaryGradient : null,
                  color: selected
                      ? null
                      : (isDark ? Colors.black : cs.surface).withOpacity(isDark ? 0.28 : 0.72),
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : (isDark ? Colors.white.withOpacity(0.14) : cs.outlineVariant.withOpacity(0.7)),
                    width: 1.1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: (isDark ? AppColors.accent : cs.primary).withOpacity(isDark ? 0.28 : 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  text,
                  style: AppTypography.caption.copyWith(
                    color: selected ? Colors.white : (isDark ? Colors.white70 : cs.onSurface),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tagPill(String text) {
    return _pill(Icons.sell_rounded, text);
  }

  Widget _metric(String label, String value, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.10) : cs.outlineVariant.withOpacity(0.8)),
        color: (isDark ? Colors.black : cs.surface).withOpacity(isDark ? 0.25 : 0.72),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.white70 : cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: isDark ? Colors.white.withOpacity(0.7) : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.subtitle1.copyWith(
                    color: isDark ? Colors.white : cs.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.10) : cs.outlineVariant.withOpacity(0.85), width: 1.2),
        color: (isDark ? const Color(0xFF05060A) : cs.surface).withOpacity(isDark ? 0.62 : 0.92),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: isDark ? Colors.white70 : cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              style: AppTypography.body2.copyWith(color: isDark ? Colors.white : cs.onSurface, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search games, creators, tags, genres',
                hintStyle: AppTypography.body2.copyWith(color: isDark ? Colors.white38 : cs.onSurfaceVariant.withOpacity(0.7), fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (_sttReady)
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _toggleVoice,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    size: 18,
                    color: _listening
                        ? (isDark ? AppColors.accent : cs.primary)
                        : (isDark ? Colors.white60 : cs.onSurfaceVariant),
                  ),
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          if (_query.isNotEmpty)
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  _searchCtrl.clear();
                  _searchFocus.unfocus();
                },
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.white60 : cs.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _extractCreators(List<Map<String, dynamic>> posts, {required String query}) {
    final raw = query.trim().toLowerCase();
    final q = raw.startsWith('@') ? raw.substring(1) : raw;
    if (q.isEmpty) return const [];

    final map = <String, Map<String, dynamic>>{};
    for (final p in posts) {
      final id = _creatorId(p).trim();
      final username = _creator(p).trim();
      if (id.isEmpty || username.isEmpty) continue;
      final avatar = _creatorAvatar(p).trim();

      final key = id;
      if (!map.containsKey(key)) {
        map[key] = {
          'id': id,
          'username': username,
          'avatar': avatar,
          'score': 0,
        };
      }

      map[key]!['score'] = (map[key]!['score'] as int) + _score(p);
    }

    final list = map.values.toList();
    list.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    final filtered = list.where((c) {
      final u = (c['username'] ?? '').toString().toLowerCase();
      return u.contains(q);
    }).toList(growable: false);

    return filtered.take(12).map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  List<Map<String, dynamic>> _topCreators(List<Map<String, dynamic>> posts, {int limit = 18}) {
    final map = <String, Map<String, dynamic>>{};
    for (final p in posts) {
      final id = _creatorId(p).trim();
      final username = _creator(p).trim();
      if (id.isEmpty || username.isEmpty) continue;
      final avatar = _creatorAvatar(p).trim();

      final key = id;
      if (!map.containsKey(key)) {
        map[key] = {
          'id': id,
          'username': username,
          'avatar': avatar,
          'score': 0,
          'postCount': 0,
          'reels': 0,
        };
      }
      map[key]!['score'] = (map[key]!['score'] as int) + _score(p);
      map[key]!['postCount'] = (map[key]!['postCount'] as int) + 1;
      if (_isReel(p)) {
        map[key]!['reels'] = (map[key]!['reels'] as int) + 1;
      }
    }

    final list = map.values.toList();
    list.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return list.take(limit).map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  Future<void> _openCreatorsAllSheet(List<Map<String, dynamic>> creators) async {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.88;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 760, maxHeight: maxH),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF05060A) : cs.surface).withOpacity(0.96),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.10) : cs.outlineVariant.withOpacity(0.8), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withOpacity(0.60) : Colors.black.withOpacity(0.12),
                          blurRadius: 34,
                          offset: const Offset(0, 22),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
                          child: Row(
                            children: [
                              Text(
                                'Creators',
                                style: AppTypography.titleLarge.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : cs.onSurface,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                            itemCount: creators.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.9,
                            ),
                            itemBuilder: (ctx2, i) {
                              final c = creators[i];
                              final id = (c['id'] ?? '').toString();
                              final username = (c['username'] ?? 'Creator').toString();
                              var avatar = (c['avatar'] ?? '').toString();
                              if (avatar.trim().isEmpty && id.trim().isNotEmpty) {
                                final cached = _creatorAvatarCache[id.trim()];
                                if (cached != null && cached.trim().isNotEmpty) {
                                  avatar = cached;
                                } else {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _prefetchCreatorAvatar(id);
                                  });
                                }
                              }
                              final postCount = (c['postCount'] ?? 0).toString();
                              final reels = (c['reels'] ?? 0).toString();
                              return _Pressable(
                                onTap: () {
                                  if (id.trim().isEmpty) return;
                                  Navigator.of(ctx).pop();
                                  context.push('/creator/$id');
                                },
                                borderRadius: BorderRadius.circular(22),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.10) : cs.outlineVariant.withOpacity(0.8), width: 1.1),
                                    color: (isDark ? Colors.black : cs.surface).withOpacity(isDark ? 0.25 : 0.85),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.primaryGradient),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(999),
                                            child: _netThumb(avatar, isDark: isDark, cs: cs, fit: BoxFit.cover, iconSize: 26),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '@$username',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.subtitle2.copyWith(
                                                color: isDark ? Colors.white : cs.onSurface,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$postCount posts • $reels reels',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.caption.copyWith(
                                                color: isDark ? Colors.white60 : cs.onSurfaceVariant,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded, color: isDark ? Colors.white54 : cs.onSurfaceVariant),
                                    ],
                                  ),
                                ),
                              );
                            },
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
      },
    );
  }

  Widget _creatorsShowcase(List<Map<String, dynamic>> posts) {
    final creators = _topCreators(posts, limit: 18);
    if (creators.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Creators',
              style: AppTypography.subtitle1.copyWith(
                color: isDark ? Colors.white : cs.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _openCreatorsAllSheet(creators),
              child: Text(
                'See all',
                style: AppTypography.caption.copyWith(
                  color: isDark ? Colors.white70 : cs.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 102,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: creators.length.clamp(0, 12),
            itemBuilder: (context, i) {
              final c = creators[i];
              final id = (c['id'] ?? '').toString();
              final username = (c['username'] ?? 'Creator').toString();
              var avatar = (c['avatar'] ?? '').toString();
              if (avatar.trim().isEmpty && id.trim().isNotEmpty) {
                final cached = _creatorAvatarCache[id.trim()];
                if (cached != null && cached.trim().isNotEmpty) {
                  avatar = cached;
                } else {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _prefetchCreatorAvatar(id);
                  });
                }
              }
              final reels = (c['reels'] ?? 0).toString();
              final rank = i + 1;
              final isTop = rank <= 3;
              return Padding(
                padding: EdgeInsets.only(right: i == creators.length - 1 ? 0 : 12),
                child: _Pressable(
                  onTap: () {
                    if (id.trim().isEmpty) return;
                    context.push('/creator/$id');
                  },
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 240,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.10) : cs.outlineVariant.withOpacity(0.8),
                        width: 1.1,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          (isDark ? const Color(0xFF0A0C14) : cs.surface).withOpacity(0.85),
                          (isDark ? const Color(0xFF101A33) : cs.surface).withOpacity(0.75),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withOpacity(0.55) : Colors.black.withOpacity(0.10),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: AppColors.accent.withOpacity(isTop ? 0.18 : 0.10),
                          blurRadius: 26,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.22),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: Row(
                              children: [
                                _neonAvatar(avatar, isDark: isDark, cs: cs, size: 54, glow: isTop),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '@$username',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.subtitle2.copyWith(
                                          color: isDark ? Colors.white : cs.onSurface,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        height: 26,
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          physics: const BouncingScrollPhysics(),
                                          child: Row(
                                            children: [
                                              if (isTop)
                                                ConstrainedBox(
                                                  constraints: const BoxConstraints(maxWidth: 92),
                                                  child: _pillBadge(
                                                    '#$rank TOP',
                                                    isDark: isDark,
                                                    cs: cs,
                                                    gradient: AppColors.primaryGradient,
                                                  ),
                                                ),
                                              if (isTop) const SizedBox(width: 8),
                                              ConstrainedBox(
                                                constraints: const BoxConstraints(maxWidth: 120),
                                                child: _pillBadge(
                                                  '$reels REELS',
                                                  isDark: isDark,
                                                  cs: cs,
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      AppColors.accent.withOpacity(0.9),
                                                      AppColors.secondary.withOpacity(0.8),
                                                    ],
                                                  ),
                                                  icon: Icons.local_fire_department_rounded,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, color: isDark ? Colors.white54 : cs.onSurfaceVariant),
                              ],
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
        ),
      ],
    );
  }

  Widget _creatorsSection(List<Map<String, dynamic>> creators) {
    if (creators.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Creators',
              style: AppTypography.subtitle1.copyWith(
                color: isDark ? Colors.white : cs.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            if (_listening)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: AppColors.primaryGradient,
                ),
                child: Text(
                  'Listening…',
                  style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 102,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: creators.length,
            itemBuilder: (context, i) {
              final c = creators[i];
              final id = (c['id'] ?? '').toString();
              final username = (c['username'] ?? 'Creator').toString();
              var avatar = (c['avatar'] ?? '').toString();
              if (avatar.trim().isEmpty && id.trim().isNotEmpty) {
                final cached = _creatorAvatarCache[id.trim()];
                if (cached != null && cached.trim().isNotEmpty) {
                  avatar = cached;
                } else {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _prefetchCreatorAvatar(id);
                  });
                }
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _Pressable(
                  onTap: () {
                    if (id.trim().isEmpty) return;
                    context.push('/creator/$id');
                  },
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.10) : cs.outlineVariant.withOpacity(0.8),
                        width: 1.1,
                      ),
                      color: (isDark ? Colors.black : cs.surface).withOpacity(isDark ? 0.25 : 0.75),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withOpacity(0.45) : Colors.black.withOpacity(0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: avatar.trim().isEmpty
                                  ? Container(
                                      color: isDark ? Colors.white.withOpacity(0.06) : cs.surfaceContainerHighest.withOpacity(0.55),
                                      child: Center(
                                        child: Icon(Icons.person_rounded, color: isDark ? Colors.white30 : cs.onSurfaceVariant.withOpacity(0.4)),
                                      ),
                                    )
                                  : _netThumb(
                                      avatar,
                                      isDark: isDark,
                                      cs: cs,
                                      fit: BoxFit.cover,
                                      iconSize: 26,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '@$username',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.subtitle2.copyWith(
                                  color: isDark ? Colors.white : cs.onSurface,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'View profile',
                                style: AppTypography.caption.copyWith(
                                  color: isDark ? Colors.white60 : cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, color: isDark ? Colors.white54 : cs.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _grid(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final cs = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'No results',
            style: AppTypography.subtitle1.copyWith(
              color: isDark ? Colors.white60 : cs.onSurfaceVariant,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, i) => _gameTile(items[i]),
    );
  }

  Widget _gameTile(Map<String, dynamic> post) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title = _title(post);
    final creator = _creator(post);
    final preview = _previewUrl(post);

    final isReel = _isReel(post);

    final hero = _heroTag(post);

    return _Pressable(
      onTap: () => _openPreview(post),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : cs.outlineVariant.withOpacity(0.8), width: 1.2),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (isDark ? const Color(0xFF0B0E18) : cs.surface).withOpacity(0.92),
              (isDark ? const Color(0xFF111B33) : cs.surface).withOpacity(0.92),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.08),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: hero,
                      child: Material(
                        color: Colors.transparent,
                        child: _netThumb(
                          preview,
                          isDark: isDark,
                          cs: cs,
                          fit: BoxFit.cover,
                          iconSize: 32,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.black.withOpacity(0.40),
                          border: Border.all(color: Colors.white.withOpacity(0.10)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              '${_asInt(post['playCount'])}',
                              style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: isReel ? AppColors.primaryGradient : LinearGradient(colors: [Colors.white.withOpacity(0.16), Colors.white.withOpacity(0.06)]),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                          boxShadow: [
                            BoxShadow(
                              color: (isReel ? AppColors.accent : Colors.black).withOpacity(0.22),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isReel ? Icons.bolt_rounded : Icons.videogame_asset_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isReel ? 'REEL' : 'GAME',
                              style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.70),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.subtitle1.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '@$creator',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: isDark ? Colors.white70 : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: AppColors.primaryGradient,
                      ),
                      child: Text(
                        'Preview',
                        style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
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

  Widget _tabBody(List<Map<String, dynamic>> posts) {
    final creators = _extractCreators(posts, query: _query);
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 420) {
          _loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _loadFirst,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
          children: [
            _searchBar(),
            if (_query.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _creatorsSection(creators),
            ],
            const SizedBox(height: 12),
            _quickFilters(posts),
            const SizedBox(height: 8),
            _grid(posts),
            if (_paging) ...[
              const SizedBox(height: 18),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final q = _query;
    final filtered = _all.where((p) => _matchesQuery(p, q)).toList(growable: false);

    final trending = [...filtered]..sort((a, b) => _score(b).compareTo(_score(a)));

    final newest = [...filtered]
      ..sort((a, b) {
        final da = _asDate(a['createdAt'] ?? a['publishedAt'] ?? a['updatedAt']);
        final db = _asDate(b['createdAt'] ?? b['publishedAt'] ?? b['updatedAt']);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

    final following = newest;
    final forYou = trending;

    final collections = _buildCollections(filtered);

    final creatorsAll = _topCreators(filtered, limit: 60);

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF05060A) : cs.surface,
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bgCtrl,
                builder: (context, _) {
                  final t = _bgCtrl.value;
                  return IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            (isDark ? const Color(0xFF03040B) : cs.surface).withOpacity(1),
                            (isDark ? const Color(0xFF070A12) : cs.surface).withOpacity(1),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: -120 + 60 * t,
                            left: -120 + 40 * t,
                            child: Container(
                              width: 420,
                              height: 420,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFF6366F1).withOpacity(isDark ? 0.16 : 0.10),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: -160 - 70 * t,
                            right: -140 - 40 * t,
                            child: Container(
                              width: 520,
                              height: 520,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFFA855F7).withOpacity(isDark ? 0.14 : 0.08),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: DefaultTabController(
                length: 6,
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/dashboard?tab=arcade');
                        }
                      },
                    ),
                    title: Text(
                      'Discovery',
                      style: AppTypography.subtitle1.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    actions: [
                      IconButton(
                        onPressed: _loadFirst,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                    flexibleSpace: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF6366F1).withOpacity(isDark ? 0.16 : 0.10),
                            const Color(0xFFA855F7).withOpacity(isDark ? 0.12 : 0.08),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                    bottom: TabBar(
                      isScrollable: true,
                      dividerColor: Colors.transparent,
                      labelStyle: AppTypography.caption.copyWith(fontWeight: FontWeight.w900),
                      unselectedLabelStyle: AppTypography.caption.copyWith(fontWeight: FontWeight.w900),
                      labelColor: isDark ? Colors.white : cs.onSurface,
                      unselectedLabelColor: (isDark ? Colors.white : cs.onSurfaceVariant).withOpacity(0.65),
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: AppColors.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: (isDark ? AppColors.accent : cs.primary).withOpacity(isDark ? 0.25 : 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: const [
                        Tab(text: 'Trending'),
                        Tab(text: 'New'),
                        Tab(text: 'Following'),
                        Tab(text: 'For You'),
                        Tab(text: 'Creators'),
                        Tab(text: 'Collections'),
                      ],
                    ),
                  ),
                  body: _loading
                      ? Center(child: CircularProgressIndicator(color: cs.primary))
                      : (_error != null)
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  _error!,
                                  style: AppTypography.body2.copyWith(
                                    color: isDark ? Colors.white70 : cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            )
                          : TabBarView(
                              children: [
                                _tabBody(trending),
                                _tabBody(newest),
                                _tabBody(following),
                                _tabBody(forYou),
                                _creatorsTabBody(creatorsAll),
                                RefreshIndicator(
                                  onRefresh: _loadFirst,
                                  child: _collectionsBody(collections),
                                ),
                              ],
                            ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _buildCollections(List<Map<String, dynamic>> posts) {
    final map = <String, List<Map<String, dynamic>>>{};

    bool is3d(Map<String, dynamic> p) {
      final raw = <dynamic>[p['mode'], p['dimension'], p['type'], p['category'], p['tags'], p['genre']]
          .map((e) => (e ?? '').toString().toLowerCase())
          .join(' ');
      return raw.contains('3d') || raw.contains('fps');
    }

    for (final p in posts) {
      if (_isReel(p)) {
        map.putIfAbsent('Reels', () => <Map<String, dynamic>>[]).add(p);
      } else {
        map.putIfAbsent('Games', () => <Map<String, dynamic>>[]).add(p);
      }
      (is3d(p)
              ? map.putIfAbsent('3D Games', () => <Map<String, dynamic>>[])
              : map.putIfAbsent('2D Games', () => <Map<String, dynamic>>[]))
          .add(p);
    }

    for (final p in posts) {
      final genre = _genre(p).trim();
      if (genre.isNotEmpty) {
        map.putIfAbsent(genre, () => <Map<String, dynamic>>[]).add(p);
      }

      for (final t in _tags(p)) {
        if (t.trim().isEmpty) continue;
        map.putIfAbsent('#$t', () => <Map<String, dynamic>>[]).add(p);
      }
    }

    final entries = map.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final limited = <String, List<Map<String, dynamic>>>{};
    for (final e in entries.take(12)) {
      limited[e.key] = e.value;
    }
    return limited;
  }

  Widget _collectionsBody(Map<String, List<Map<String, dynamic>>> collections) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final keys = collections.keys.toList(growable: false);
    final myKeys = _myCollections.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxxl),
      children: [
        _searchBar(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'My Collections',
                style: AppTypography.subtitle1.copyWith(
                  color: isDark ? Colors.white : cs.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _loadingCollections ? null : () => _createCollectionFlow(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loadingCollections)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (myKeys.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Center(
              child: Text(
                'No collections yet',
                style: AppTypography.subtitle1.copyWith(
                  color: isDark ? Colors.white60 : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          )
        else
          ...myKeys.map((k) {
            final ids = _myCollections[k] ?? const <String>[];
            final posts = ids
                .map((id) => _all.firstWhere(
                      (p) => _postId(p) == id,
                      orElse: () => const <String, dynamic>{},
                    ))
                .where((p) => p.isNotEmpty)
                .toList(growable: false);
            final preview = posts.isNotEmpty ? _previewUrl(posts.first) : '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _Pressable(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  if (posts.isEmpty) return;
                  _openMyCollectionSheet(k, posts);
                },
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.08) : cs.outlineVariant.withOpacity(0.8),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (preview.trim().isNotEmpty)
                          _netThumb(
                            preview,
                            isDark: isDark,
                            cs: cs,
                            fit: BoxFit.cover,
                            iconSize: 34,
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  cs.primary.withOpacity(0.20),
                                  AppColors.accent.withOpacity(0.12),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.08),
                                  Colors.black.withOpacity(0.78),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      k,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.subtitle1.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${ids.length} games',
                                      style: AppTypography.caption.copyWith(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  setState(() {
                                    final next = Map<String, List<String>>.from(_myCollections);
                                    next.remove(k);
                                    _myCollections = next;
                                  });
                                  await _saveMyCollections();
                                },
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
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
          }).toList(growable: false),
        const SizedBox(height: 18),
        Text(
          'Suggested Collections',
          style: AppTypography.subtitle1.copyWith(
            color: isDark ? Colors.white : cs.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        if (keys.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Center(
              child: Text(
                'No collections yet',
                style: AppTypography.subtitle1.copyWith(
                  color: isDark ? Colors.white60 : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          )
        else
          ...keys.map((k) {
            final items = collections[k] ?? const [];
            final sorted = [...items]..sort((a, b) => _score(b).compareTo(_score(a)));

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          k,
                          style: AppTypography.subtitle1.copyWith(
                            color: isDark ? Colors.white : cs.onSurface,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${items.length}',
                        style: AppTypography.caption.copyWith(
                          color: isDark ? Colors.white60 : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 190,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: sorted.take(12).length,
                      itemBuilder: (context, i) {
                        final p = sorted[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 240,
                            child: _collectionTile(p),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }).toList(growable: false),
        if (_paging) ...[
          const SizedBox(height: 18),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  Future<void> _openMyCollectionSheet(String name, List<Map<String, dynamic>> posts) async {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B0D16) : cs.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : cs.outlineVariant.withOpacity(0.7),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: posts.length,
                    itemBuilder: (ctx, i) {
                      final p = posts[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _title(p),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '@${_creator(p)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: isDark ? Colors.white60 : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        trailing: IconButton(
                          onPressed: () async {
                            final pid = _postId(p);
                            setState(() {
                              final next = Map<String, List<String>>.from(_myCollections);
                              final list = [...(next[name] ?? <String>[])];
                              list.remove(pid);
                              next[name] = list;
                              _myCollections = next;
                            });
                            await _saveMyCollections();
                          },
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          _openPreview(p);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _collectionTile(Map<String, dynamic> post) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preview = _previewUrl(post);

    final hero = _heroTag(post);

    return _Pressable(
      onTap: () => _openPreview(post),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : cs.outlineVariant.withOpacity(0.8), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.55) : Colors.black.withOpacity(0.08),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: hero,
                child: Material(
                  color: Colors.transparent,
                  child: _netThumb(
                    preview,
                    isDark: isDark,
                    cs: cs,
                    fit: BoxFit.cover,
                    iconSize: 38,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.15),
                        Colors.black.withOpacity(0.80),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(post),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.subtitle1.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '@${_creator(post)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: Colors.white70, fontWeight: FontWeight.w900),
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
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _Pressable({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: widget.child,
        ),
      ),
    );
  }
}
