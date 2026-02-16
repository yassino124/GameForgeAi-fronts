import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/templates_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../widgets/widgets.dart';

class TemplateMarketplaceScreen extends StatefulWidget {
  const TemplateMarketplaceScreen({super.key});

  @override
  State<TemplateMarketplaceScreen> createState() => _TemplateMarketplaceScreenState();
}

class _AiFinderSheet extends StatefulWidget {
  final TextEditingController controller;
  final Future<List<GameTemplate>> Function(String prompt) onSearch;
  final void Function(GameTemplate template) onPick;

  const _AiFinderSheet({
    required this.controller,
    required this.onSearch,
    required this.onPick,
  });

  @override
  State<_AiFinderSheet> createState() => _AiFinderSheetState();
}

class _AiFinderSheetState extends State<_AiFinderSheet> {
  bool _loading = false;
  String? _error;
  List<GameTemplate> _results = const [];

  Future<void> _run() async {
    final prompt = widget.controller.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await widget.onSearch(prompt);
      if (!mounted) return;
      setState(() {
        _results = res;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _results = const [];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.48,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppBorderRadius.large)),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  Text('AI Template Finder', style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w900)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Describe your game idea and I\'ll rank the best templates for you.',
                style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, height: 1.25),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _run(),
                      decoration: const InputDecoration(
                        labelText: 'What do you want to build?',
                        hintText: 'ex: 2D endless runner, mobile-ready, sci-fi…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _run,
                      icon: _loading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(_loading ? 'Finding…' : 'Find'),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!, style: AppTypography.caption.copyWith(color: cs.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _results.isEmpty
                    ? Container(
                        key: const ValueKey('empty'),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(AppBorderRadius.large),
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cs.primary.withOpacity(0.12),
                                border: Border.all(color: cs.primary.withOpacity(0.22)),
                              ),
                              child: Icon(Icons.tips_and_updates_rounded, color: cs.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tip: mention 2D/3D + mobile/web + genre for best results.',
                                style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, height: 1.25),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        key: const ValueKey('results'),
                        children: _results.map((t) {
                          return InkWell(
                            borderRadius: BorderRadius.circular(AppBorderRadius.large),
                            onTap: () => widget.onPick(t),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(AppBorderRadius.large),
                                border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: cs.primary.withOpacity(0.12),
                                      border: Border.all(color: cs.primary.withOpacity(0.22)),
                                    ),
                                    child: Icon(Icons.auto_awesome_rounded, color: cs.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t.name, style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 4),
                                        Text(t.category, style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class InlineAutoplayVideo extends StatefulWidget {
  final String url;
  final String? fallbackImageUrl;
  final IconData fallbackIcon;

  const InlineAutoplayVideo({
    super.key,
    required this.url,
    required this.fallbackImageUrl,
    required this.fallbackIcon,
  });

  @override
  State<InlineAutoplayVideo> createState() => _InlineAutoplayVideoState();
}

class _InlineAutoplayVideoState extends State<InlineAutoplayVideo> {
  VideoPlayerController? _controller;
  Future<void>? _init;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant InlineAutoplayVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _setup();
    }
  }

  void _setup() {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = c;
    _init = c.initialize().then((_) {
      c.setLooping(true);
      c.setVolume(0.0);
      c.play();
      if (mounted) setState(() {});
    });
  }

  void _disposeController() {
    try {
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _init = null;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = _controller;
    final init = _init;

    if (c == null || init == null) {
      return Center(child: Icon(widget.fallbackIcon, size: 40, color: cs.onPrimary.withOpacity(0.75)));
    }

    return FutureBuilder<void>(
      future: init,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done || !c.value.isInitialized) {
          final url = widget.fallbackImageUrl;
          if (url != null && url.trim().isNotEmpty) {
            return Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(child: Icon(widget.fallbackIcon, size: 40, color: cs.onPrimary.withOpacity(0.75)));
              },
            );
          }
          return Center(child: Icon(widget.fallbackIcon, size: 40, color: cs.onPrimary.withOpacity(0.75)));
        }

        return FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: c.value.size.width,
            height: c.value.size.height,
            child: VideoPlayer(c),
          ),
        );
      },
    );
  }
}

class _TemplateMarketplaceScreenState extends State<TemplateMarketplaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _sortBy = 'Popular';
  bool _isGridView = true;

  String _proFilter = 'All';

  static const String _kPrefSavedTemplateIds = 'marketplace_saved_template_ids_v1';
  final Set<String> _savedTemplateIds = {};
  bool _showSavedOnly = false;

  final List<GameTemplate> _compareSelection = [];
  bool _compareTrayVisible = false;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<GameTemplate> _templates = [];

  late final VoidCallback _refreshListener;

  final List<String> _categories = [
    'All',
    'Action',
    'Puzzle',
    'RPG',
    'Strategy',
    'Casual',
    'Simulation',
    'Educational',
  ];

  final List<String> _sortOptions = [
    'Popular',
    'Newest',
    'Rating',
    'Downloads',
    'Price',
  ];

  final List<String> _proFilters = const [
    'All',
    'Featured',
    'Mobile-ready',
    'Free',
    'Paid',
    '2D',
    '3D',
  ];

  bool _hasTag(GameTemplate t, String tag) {
    final q = tag.trim().toLowerCase();
    if (q.isEmpty) return false;
    return t.tags.any((x) => x.trim().toLowerCase() == q);
  }

  List<_CompatBadge> _compatBadges(GameTemplate t) {
    final out = <_CompatBadge>[];
    final tags = t.tags.map((e) => e.trim().toLowerCase()).toList();

    bool hasAny(Set<String> values) => tags.any(values.contains);

    final is2d = hasAny({'2d', '2d-ready', '2d_only'});
    final is3d = hasAny({'3d', '3d-ready', '3d_only'});
    final mobile = hasAny({'mobile', 'mobile-ready', 'android', 'ios'});

    if (is2d) out.add(const _CompatBadge(label: '2D', icon: Icons.layers_outlined));
    if (is3d) out.add(const _CompatBadge(label: '3D', icon: Icons.view_in_ar));
    if (mobile) out.add(const _CompatBadge(label: 'Mobile', icon: Icons.phone_iphone));

    return out;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadSavedTemplates();
    _initSpeech();
    _loadTemplates();

    _refreshListener = () {
      _loadTemplates();
    };
    TemplatesService.refreshNotifier.addListener(_refreshListener);
  }

  Future<void> _loadSavedTemplates() async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = p.getStringList(_kPrefSavedTemplateIds) ?? <String>[];
      if (!mounted) return;
      setState(() {
        _savedTemplateIds
          ..clear()
          ..addAll(list.where((e) => e.trim().isNotEmpty));
      });
    } catch (_) {}
  }

  Future<void> _persistSavedTemplates() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_kPrefSavedTemplateIds, _savedTemplateIds.toList());
    } catch (_) {}
  }

  void _toggleSaved(GameTemplate t) {
    setState(() {
      if (_savedTemplateIds.contains(t.id)) {
        _savedTemplateIds.remove(t.id);
      } else {
        _savedTemplateIds.add(t.id);
      }
    });
    _persistSavedTemplates();
  }

  void _toggleCompare(GameTemplate t) {
    setState(() {
      final idx = _compareSelection.indexWhere((x) => x.id == t.id);
      if (idx >= 0) {
        _compareSelection.removeAt(idx);
      } else {
        if (_compareSelection.length >= 3) {
          _compareSelection.removeAt(0);
        }
        _compareSelection.add(t);
      }
      _compareTrayVisible = _compareSelection.isNotEmpty;
    });
  }

  void _clearCompare() {
    setState(() {
      _compareSelection.clear();
      _compareTrayVisible = false;
    });
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize(
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _speechAvailable = false;
            _error = e.errorMsg;
          });
        },
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'notListening' || status == 'done') {
            setState(() {
              _isListening = false;
            });
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _speechAvailable = ok;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _speechAvailable = false;
      });
    }
  }

  Future<void> _toggleVoiceSearch() async {
    final cs = Theme.of(context).colorScheme;

    if (_isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() {
        _isListening = false;
      });
      return;
    }

    if (!_speechAvailable) {
      await _initSpeech();
    }
    if (!_speechAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Voice search not available. Please allow microphone permission.'),
          backgroundColor: cs.error,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isListening = true;
      _error = null;
    });

    await _speech.listen(
      listenMode: stt.ListenMode.search,
      onResult: (result) {
        if (!mounted) return;
        final words = result.recognizedWords;
        if (words.trim().isEmpty) return;
        _searchController.value = TextEditingValue(
          text: words,
          selection: TextSelection.collapsed(offset: words.length),
        );
        if (result.finalResult) {
          setState(() {
            _isListening = false;
          });
        }
      },
    );
  }

  String? _resolveMediaUrl(String? url) {
    if (url == null) return null;
    final raw = url.trim();
    if (raw.isEmpty) return null;

    try {
      final base = Uri.parse(ApiService.baseUrl);
      final baseOrigin = Uri(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null);

      if (raw.startsWith('/')) {
        return baseOrigin.resolve(raw).toString();
      }

      final u = Uri.parse(raw);
      if (!u.hasScheme) {
        return baseOrigin.resolve('/$raw').toString();
      }

      // If backend stored an absolute URL using another host (e.g., 10.0.2.2),
      // keep the path/query but use the current API origin.
      return baseOrigin.replace(path: u.path, query: u.query).toString();
    } catch (_) {
      return raw;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    TemplatesService.refreshNotifier.removeListener(_refreshListener);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _loadTemplates();
    });
  }

  Future<void> _loadTemplates() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await TemplatesService.listPublicTemplates(
        q: _searchController.text,
        category: _selectedCategory,
      );
      final raw = (res['success'] == true && res['data'] is List) ? (res['data'] as List) : const [];
      final parsed = raw.map((e) {
        if (e is! Map) return null;
        final id = (e['_id'] ?? e['id'])?.toString() ?? '';
        if (id.isEmpty) return null;

        final tagsRaw = e['tags'];
        final tags = (tagsRaw is List) ? tagsRaw.map((t) => t.toString()).toList() : const <String>[];

        return GameTemplate(
          id: id,
          name: e['name']?.toString() ?? 'Template',
          category: e['category']?.toString() ?? 'General',
          description: e['description']?.toString() ?? '',
          rating: (e['rating'] is num) ? (e['rating'] as num).toDouble() : 4.7,
          downloads: (e['downloads'] is num) ? (e['downloads'] as num).toInt() : 0,
          price: (e['price'] is num) ? (e['price'] as num).toDouble() : 0.0,
          imageUrl: _resolveMediaUrl(e['previewImageUrl']?.toString()),
          previewVideoUrl: _resolveMediaUrl(e['previewVideoUrl']?.toString()),
          tags: tags,
          isFeatured: e['isFeatured'] == true,
          creator: e['ownerId']?.toString() ?? 'Creator',
          createdAt: DateTime.tryParse(e['createdAt']?.toString() ?? '') ?? DateTime.now(),
        );
      }).whereType<GameTemplate>().toList();

      if (!mounted) return;
      setState(() {
        _templates = parsed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final featured = _getFeaturedTemplates();
    final bottomNavPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.dark
            ? AppColors.backgroundGradient
            : AppTheme.backgroundGradientLight,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 8),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface.withOpacity(isDark ? 0.72 : 0.82),
                  border: Border(
                    bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
                  ),
                ),
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  title: Text(
                    'Marketplace',
                    style: AppTypography.subtitle1.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Saved templates',
                      onPressed: _openSaved,
                      icon: Icon(
                        (_showSavedOnly || _savedTemplateIds.isNotEmpty) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: (_showSavedOnly || _savedTemplateIds.isNotEmpty) ? Colors.redAccent : null,
                      ),
                    ),
                    IconButton(
                      tooltip: 'AI Finder',
                      onPressed: _openAiFinder,
                      icon: const Icon(Icons.auto_awesome_rounded),
                    ),
                    IconButton(
                      tooltip: _isGridView ? 'List view' : 'Grid view',
                      onPressed: () {
                        setState(() {
                          _isGridView = !_isGridView;
                        });
                      },
                      icon: Icon(_isGridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded),
                    ),
                    IconButton(
                      tooltip: 'Compare',
                      onPressed: _compareSelection.isEmpty ? null : _openCompareSheet,
                      icon: const Icon(Icons.compare_arrows_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: AppSpacing.paddingLarge,
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(isDark ? 0.45 : 0.65),
                border: Border(
                  bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CustomSearchField(
                          controller: _searchController,
                          hint: 'Search templates...',
                          onChanged: (_) {},
                          onClear: () {
                            _searchController.clear();
                            _loadTemplates();
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      InkWell(
                        onTap: _toggleVoiceSearch,
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _isListening ? AppColors.accent : cs.primary,
                            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                          ),
                          child: Icon(
                            _isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sortBy,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _sortBy = value;
                              });
                            },
                            style: AppTypography.caption.copyWith(fontWeight: FontWeight.w500),
                            underline: const SizedBox(),
                            icon: Icon(Icons.keyboard_arrow_down, color: cs.onSurfaceVariant),
                            items: _sortOptions
                                .map((option) => DropdownMenuItem(value: option, child: Text(option)))
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),

                      // Category chips
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            itemBuilder: (context, index) {
                              final category = _categories[index];
                              final isSelected = category == _selectedCategory;

                              return Padding(
                                padding: const EdgeInsets.only(right: AppSpacing.sm),
                                child: _AnimatedChoiceChip(
                                  label: category,
                                  selected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedCategory = category;
                                    });
                                    _loadTemplates();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _proFilters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final f = _proFilters[i];
                        final selected = f == _proFilter;
                        return _AnimatedChoiceChip(
                          label: f,
                          selected: selected,
                          densePill: true,
                          onTap: () {
                            setState(() => _proFilter = f);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  bottomNavPad + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_loading) ...[
                      _MarketplaceSkeleton(isGrid: _isGridView),
                      const SizedBox(height: AppSpacing.lg),
                    ],
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

                    // Featured carousel
                    if (featured.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: cs.surface.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.55),
                          borderRadius: BorderRadius.circular(AppBorderRadius.large),
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.local_fire_department_rounded, size: 18, color: cs.primary),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Featured Templates', style: AppTypography.subtitle2)),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        height: 220,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(left: 2, right: 2),
                          itemCount: featured.length,
                          itemBuilder: (context, index) {
                            return _buildFeaturedCard(featured[index]);
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                    ],

                    // All templates
                    Text('All Templates', style: AppTypography.subtitle2),
                    const SizedBox(height: AppSpacing.lg),

                    // Templates grid/list
                    if (!_loading) _isGridView ? _buildTemplatesGrid() : _buildTemplatesList(),
                  ],
                ),
              ),
            ),
            _buildCompareTray(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildCompareTray(ColorScheme cs) {
    final visible = _compareTrayVisible;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      offset: visible ? Offset.zero : const Offset(0, 1.2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: Container(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.md,
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant.withOpacity(0.65))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 24,
                  offset: const Offset(0, -14),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _compareSelection.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final t = _compareSelection[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: cs.primary.withOpacity(0.18)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t.name,
                                style: AppTypography.caption.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => _toggleCompare(t),
                                child: Icon(Icons.close_rounded, size: 16, color: cs.primary),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CustomButton(
                  text: 'Compare',
                  onPressed: _compareSelection.length >= 2 ? _openCompareSheet : null,
                  type: ButtonType.primary,
                  size: ButtonSize.small,
                  icon: const Icon(Icons.compare_arrows_rounded),
                ),
                const SizedBox(width: 10),
                CustomButton(
                  text: 'Clear',
                  onPressed: _clearCompare,
                  type: ButtonType.secondary,
                  size: ButtonSize.small,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<GameTemplate> _getFeaturedTemplates() {
    final copy = [..._templates];
    copy.sort((a, b) => b.rating.compareTo(a.rating));
    return copy.take(6).toList();
  }

  Widget _buildFeaturedCard(GameTemplate template) {
    final cs = Theme.of(context).colorScheme;
    final coverUrl = _resolveMediaUrl(template.imageUrl);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: coverUrl != null
                  ? Image.network(coverUrl, fit: BoxFit.cover)
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cs.primaryContainer, cs.surface],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(Icons.videogame_asset_rounded, size: 48, color: cs.primary.withOpacity(0.2)),
                    ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.0),
                      Colors.black.withOpacity(0.85),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'FEATURED',
                          style: AppTypography.caption.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (template.price <= 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'FREE',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    template.name,
                    style: AppTypography.subtitle1.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template.description,
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push('/template/${template.id}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesGrid() {
    final filteredTemplates = _getFilteredTemplates();
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: AppSpacing.lg,
        mainAxisSpacing: AppSpacing.lg,
      ),
      itemCount: filteredTemplates.length,
      itemBuilder: (context, index) {
        return _buildTemplateCard(filteredTemplates[index]);
      },
    );
  }

  Widget _buildTemplateListItem(GameTemplate template) {
    final cs = Theme.of(context).colorScheme;
    final coverUrl = _resolveMediaUrl(template.imageUrl);
    final videoUrl = _resolveMediaUrl(template.previewVideoUrl);
    final badges = _compatBadges(template);
    final saved = _savedTemplateIds.contains(template.id);
    final compared = _compareSelection.any((t) => t.id == template.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(isDark ? 0.18 : 0.20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: () => context.push('/template/${template.id}'),
        onLongPress: () => _toggleCompare(template),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 100,
                height: 75,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: (videoUrl != null && videoUrl.trim().isNotEmpty)
                          ? InlineAutoplayVideo(
                              url: videoUrl,
                              fallbackImageUrl: coverUrl,
                              fallbackIcon: _getCategoryIcon(template.category),
                            )
                          : (coverUrl != null && coverUrl.trim().isNotEmpty)
                              ? Image.network(coverUrl, fit: BoxFit.cover)
                              : Container(
                                  color: cs.primaryContainer.withOpacity(0.3),
                                  child: Icon(_getCategoryIcon(template.category), color: cs.primary, size: 24),
                                ),
                    ),
                    if (template.isFeatured)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                          child: const Icon(Icons.star, size: 8, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          template.name,
                          style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        template.price > 0 ? '\$${template.price.toStringAsFixed(0)}' : 'FREE',
                        style: AppTypography.caption.copyWith(color: cs.primary, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    template.category,
                    style: AppTypography.caption.copyWith(fontSize: 10, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: Colors.amber[700]),
                      const SizedBox(width: 4),
                      Text(
                        template.rating.toStringAsFixed(1),
                        style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.download_rounded, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${template.downloads}',
                        style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  onPressed: () => _toggleSaved(template),
                  icon: Icon(
                    saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: saved ? Colors.redAccent : cs.onSurfaceVariant,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 8),
                IconButton(
                  onPressed: () => _toggleCompare(template),
                  icon: Icon(
                    compared ? Icons.check_circle_rounded : Icons.compare_arrows_rounded,
                    color: compared ? cs.primary : cs.onSurfaceVariant,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesList() {
    final filteredTemplates = _getFilteredTemplates();
    
    return Column(
      children: filteredTemplates.map((template) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: _buildTemplateListItem(template),
        );
      }).toList(),
    );
  }

  Widget _buildTemplateCard(GameTemplate template) {
    final cs = Theme.of(context).colorScheme;
    final coverUrl = _resolveMediaUrl(template.imageUrl);
    final videoUrl = _resolveMediaUrl(template.previewVideoUrl);
    final badges = _compatBadges(template);
    final saved = _savedTemplateIds.contains(template.id);
    final compared = _compareSelection.any((t) => t.id == template.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: cs.surface.withOpacity(isDark ? 0.4 : 0.7),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go('/template/${template.id}'),
            onLongPress: () => _toggleCompare(template),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: (videoUrl != null && videoUrl.trim().isNotEmpty)
                            ? InlineAutoplayVideo(
                                url: videoUrl,
                                fallbackImageUrl: coverUrl,
                                fallbackIcon: _getCategoryIcon(template.category),
                              )
                            : (coverUrl != null && coverUrl.trim().isNotEmpty)
                                ? Image.network(
                                    coverUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                                        child: Center(
                                          child: Icon(
                                            _getCategoryIcon(template.category),
                                            size: 32,
                                            color: cs.onPrimary.withOpacity(0.80),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                                    child: Center(
                                      child: Icon(
                                        _getCategoryIcon(template.category),
                                        size: 32,
                                        color: cs.onPrimary.withOpacity(0.80),
                                      ),
                                    ),
                                  ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => _toggleCompare(template),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  compared ? Icons.check_circle_rounded : Icons.compare_arrows_rounded,
                                  color: compared ? cs.primary : Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _toggleSaved(template),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: saved ? Colors.redAccent : Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        template.category,
                        style: AppTypography.caption.copyWith(fontSize: 10, color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      if (badges.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          children: badges.take(1).map((b) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(b.label, style: TextStyle(color: cs.primary, fontSize: 8, fontWeight: FontWeight.bold)),
                          )).toList(),
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

  List<GameTemplate> _getFilteredTemplates() {
    List<GameTemplate> templates = _templates;

    if (_showSavedOnly) {
      templates = templates.where((t) => _savedTemplateIds.contains(t.id)).toList();
    }

    if (_selectedCategory != 'All') {
      templates = templates.where((t) => t.category == _selectedCategory).toList();
    }

    if (_proFilter != 'All') {
      switch (_proFilter) {
        case 'Featured':
          templates = templates.where((t) => t.isFeatured).toList();
          break;
        case 'Mobile-ready':
          templates = templates.where((t) => _compatBadges(t).any((b) => b.label == 'Mobile')).toList();
          break;
        case 'Free':
          templates = templates.where((t) => t.price <= 0.0).toList();
          break;
        case 'Paid':
          templates = templates.where((t) => t.price > 0.0).toList();
          break;
        case '2D':
          templates = templates.where((t) => _compatBadges(t).any((b) => b.label == '2D')).toList();
          break;
        case '3D':
          templates = templates.where((t) => _compatBadges(t).any((b) => b.label == '3D')).toList();
          break;
      }
    }

    final searchQuery = _searchController.text.trim().toLowerCase();
    if (searchQuery.isNotEmpty) {
      final tokens = searchQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      int score(GameTemplate t) {
        final hay = '${t.name} ${t.description} ${t.category} ${t.tags.join(' ')} ${t.creator}'.toLowerCase();
        int s = 0;
        for (final tok in tokens) {
          if (t.name.toLowerCase().contains(tok)) s += 6;
          if (t.tags.any((x) => x.toLowerCase().contains(tok))) s += 4;
          if (t.description.toLowerCase().contains(tok)) s += 2;
          if (hay.contains(tok)) s += 1;
        }
        return s;
      }

      templates = templates.where((t) => score(t) > 0).toList();
      templates.sort((a, b) => score(b).compareTo(score(a)));
    }

    switch (_sortBy) {
      case 'Popular':
        templates.sort((a, b) => b.downloads.compareTo(a.downloads));
        break;
      case 'Newest':
        templates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'Rating':
        templates.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Downloads':
        templates.sort((a, b) => b.downloads.compareTo(a.downloads));
        break;
      case 'Price':
        templates.sort((a, b) => a.price.compareTo(b.price));
        break;
    }

    return templates;
  }

  Future<void> _openCompareSheet() async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.50,
          maxChildSize: 0.94,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppBorderRadius.large)),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Row(
                    children: [
                      Text('Compare (${_compareSelection.length}/3)', style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w900)),
                      const Spacer(),
                      IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._compareSelection.map((t) {
                    final badges = _compatBadges(t);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(AppBorderRadius.large),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(t.name, style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w900))),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: t.price > 0 ? cs.primary.withOpacity(0.14) : AppColors.success.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
                                ),
                                child: Text(
                                  t.price > 0 ? '\$${t.price.toStringAsFixed(2)}' : 'FREE',
                                  style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(t.category, style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ...badges.take(3).map(
                                (b) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: cs.primary.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: cs.primary.withOpacity(0.18)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(b.icon, size: 14, color: cs.primary),
                                      const SizedBox(width: 6),
                                      Text(b.label, style: AppTypography.caption.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: cs.surface,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, size: 14, color: AppColors.warning),
                                    const SizedBox(width: 6),
                                    Text(t.rating.toStringAsFixed(1), style: AppTypography.caption.copyWith(fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            t.description,
                            style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant, height: 1.3),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Clear',
                          onPressed: () {
                            Navigator.of(context).pop();
                            _clearCompare();
                          },
                          type: ButtonType.secondary,
                          size: ButtonSize.small,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomButton(
                          text: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          type: ButtonType.primary,
                          size: ButtonSize.small,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openAiFinder() async {
    final promptController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _AiFinderSheet(
            controller: promptController,
            onPick: (t) {
              Navigator.of(context).pop();
              context.go('/template/${t.id}');
            },
            onSearch: (prompt) async {
              final token = context.read<AuthProvider>().token;

              String? derivedCategory;
              final derivedTags = <String>[];
              if (token != null && token.trim().isNotEmpty) {
                try {
                  final res = await AiService.generateTemplateDraft(token: token, description: prompt);
                  if (res['success'] == true && res['data'] is Map) {
                    final data = Map<String, dynamic>.from(res['data'] as Map);
                    derivedCategory = data['category']?.toString();
                    final tagsRaw = data['tags'];
                    if (tagsRaw is List) {
                      derivedTags.addAll(tagsRaw.map((e) => e?.toString() ?? '').where((e) => e.trim().isNotEmpty));
                    }
                  }
                } catch (_) {}
              }

              List<GameTemplate> ranked = [..._templates];

              int score(GameTemplate t) {
                int s = 0;
                final hay = '${t.name} ${t.description} ${t.category} ${t.tags.join(' ')} ${t.creator}'.toLowerCase();
                final tokens = prompt.toLowerCase().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
                for (final tok in tokens) {
                  if (t.name.toLowerCase().contains(tok)) s += 6;
                  if (t.tags.any((x) => x.toLowerCase().contains(tok))) s += 4;
                  if (t.description.toLowerCase().contains(tok)) s += 2;
                  if (hay.contains(tok)) s += 1;
                }
                if (derivedCategory != null && derivedCategory!.trim().isNotEmpty) {
                  if (t.category.toLowerCase() == derivedCategory!.trim().toLowerCase()) s += 10;
                }
                for (final dt in derivedTags) {
                  if (t.tags.any((x) => x.toLowerCase() == dt.toLowerCase())) s += 6;
                }
                if (t.isFeatured) s += 1;
                return s;
              }

              ranked.sort((a, b) => score(b).compareTo(score(a)));
              return ranked.take(10).toList();
            },
          ),
        );
      },
    );

    promptController.dispose();
  }

  Future<void> _openSaved() async {
    final cs = Theme.of(context).colorScheme;
    var saved = _templates.where((t) => _savedTemplateIds.contains(t.id)).toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.72,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xlarge)),
                    border: Border(top: BorderSide(color: cs.outlineVariant.withOpacity(0.6))),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.onSurfaceVariant.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('Saved templates', style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w900)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: saved.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  child: Text(
                                    'No saved templates yet.',
                                    style: AppTypography.body2.copyWith(color: cs.onSurfaceVariant),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                                itemCount: saved.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final t = saved[i];
                                  return InkWell(
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      context.go('/template/${t.id}');
                                    },
                                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                                    child: Container(
                                      padding: const EdgeInsets.all(AppSpacing.md),
                                      decoration: BoxDecoration(
                                        color: cs.surfaceContainerHighest.withOpacity(0.55),
                                        borderRadius: BorderRadius.circular(AppBorderRadius.large),
                                        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(t.name, style: AppTypography.subtitle2, maxLines: 1, overflow: TextOverflow.ellipsis),
                                                const SizedBox(height: 4),
                                                Text(
                                                  t.category,
                                                  style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Remove',
                                            onPressed: () {
                                              _toggleSaved(t);
                                              setSheetState(() {
                                                saved = _templates.where((x) => _savedTemplateIds.contains(x.id)).toList();
                                              });
                                            },
                                            icon: const Icon(Icons.bookmark_remove_rounded),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Action':
        return Icons.flash_on;
      case 'Puzzle':
        return Icons.extension;
      case 'RPG':
        return Icons.psychology;
      case 'Strategy':
        return Icons.lightbulb;
      case 'Casual':
        return Icons.casino;
      case 'Simulation':
        return Icons.sim_card;
      case 'Educational':
        return Icons.school;
      default:
        return Icons.games;
    }
  }
}

class _PressableGlow extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _PressableGlow({
    required this.child,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_PressableGlow> createState() => _PressableGlowState();
}

class _PressableGlowState extends State<_PressableGlow> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _down ? 0.985 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.large),
            boxShadow: _down
                ? [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.22),
                      blurRadius: 22,
                      spreadRadius: 1,
                      offset: const Offset(0, 14),
                    ),
                  ]
                : const [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _AnimatedChoiceChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool densePill;

  const _AnimatedChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.densePill = false,
  });

  @override
  State<_AnimatedChoiceChip> createState() => _AnimatedChoiceChipState();
}

class _AnimatedChoiceChipState extends State<_AnimatedChoiceChip> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sel = widget.selected;
    final br = widget.densePill ? 999.0 : AppBorderRadius.medium.toDouble();
    final bg = sel ? cs.primary.withOpacity(0.22) : cs.surface;
    final fg = sel ? cs.primary : cs.onSurfaceVariant;
    final fw = sel ? FontWeight.w900 : FontWeight.w700;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _down ? 0.97 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(br),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.16),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sel) ...[
                Icon(Icons.check_rounded, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: AppTypography.caption.copyWith(color: fg, fontWeight: fw),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketplaceSkeleton extends StatelessWidget {
  final bool isGrid;
  const _MarketplaceSkeleton({required this.isGrid});

  @override
  Widget build(BuildContext context) {
    if (isGrid) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: AppSpacing.lg,
          mainAxisSpacing: AppSpacing.lg,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const _SkeletonTemplateCard(),
      );
    }

    return Column(
      children: List.generate(
        5,
        (i) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.lg),
          child: _SkeletonTemplateRow(),
        ),
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  final BorderRadius borderRadius;
  final double height;
  final double? width;

  const _Shimmer({
    required this.borderRadius,
    required this.height,
    this.width,
  });

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final x = -1.0 + (2.0 * t);
        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.22),
            ),
            child: ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment(x - 1, 0),
                  end: Alignment(x + 1, 0),
                  colors: [
                    Colors.transparent,
                    Colors.white.withOpacity(0.18),
                    Colors.transparent,
                  ],
                  stops: const [0.25, 0.5, 0.75],
                ).createShader(rect);
              },
              blendMode: BlendMode.srcATop,
              child: Container(color: Colors.white.withOpacity(0.06)),
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonTemplateCard extends StatelessWidget {
  const _SkeletonTemplateCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Shimmer(borderRadius: BorderRadius.zero, height: 110),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Shimmer(borderRadius: BorderRadius.circular(999), height: 14, width: 92),
                  const SizedBox(height: 10),
                  _Shimmer(borderRadius: BorderRadius.circular(8), height: 14, width: 140),
                  const SizedBox(height: 8),
                  _Shimmer(borderRadius: BorderRadius.circular(8), height: 14, width: 120),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Shimmer(borderRadius: BorderRadius.circular(999), height: 22, width: 62),
                      const SizedBox(width: 8),
                      _Shimmer(borderRadius: BorderRadius.circular(999), height: 22, width: 72),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonTemplateRow extends StatelessWidget {
  const _SkeletonTemplateRow();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.55)),
      ),
      child: Row(
        children: [
          _Shimmer(borderRadius: BorderRadius.circular(AppBorderRadius.medium), height: 78, width: 112),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Shimmer(borderRadius: BorderRadius.circular(8), height: 14, width: 160),
                const SizedBox(height: 8),
                _Shimmer(borderRadius: BorderRadius.circular(8), height: 14, width: 120),
                const SizedBox(height: 10),
                _Shimmer(borderRadius: BorderRadius.circular(8), height: 14, width: 220),
                const SizedBox(height: 8),
                _Shimmer(borderRadius: BorderRadius.circular(8), height: 14, width: 190),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatBadge {
  final String label;
  final IconData icon;

  const _CompatBadge({
    required this.label,
    required this.icon,
  });
}

class GameTemplate {
  final String id;
  final String name;
  final String category;
  final String description;
  final double rating;
  final int downloads;
  final double price;
  final String? imageUrl;
  final String? previewVideoUrl;
  final List<String> tags;
  final bool isFeatured;
  final String creator;
  final DateTime createdAt;

  GameTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.rating,
    required this.downloads,
    required this.price,
    this.imageUrl,
    this.previewVideoUrl,
    required this.tags,
    required this.isFeatured,
    required this.creator,
    required this.createdAt,
  });
}

class _VideoPlayerDialog extends StatefulWidget {
  final String url;

  const _VideoPlayerDialog({
    required this.url,
  });

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late final VideoPlayerController _controller;
  late final Future<void> _init;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _init = _controller.initialize().then((_) {
      _controller.setLooping(true);
      _controller.play();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: cs.surface,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: FutureBuilder<void>(
            future: _init,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              return Stack(
                children: [
                  Positioned.fill(child: VideoPlayer(_controller)),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
