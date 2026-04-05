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
  final bool autoOpenAiFinder;
  const TemplateMarketplaceScreen({super.key, this.autoOpenAiFinder = false});

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

class _FeaturedBadge extends StatelessWidget {
  const _FeaturedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF22D3EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            'FEATURED',
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
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

class _TemplateMarketplaceScreenState extends State<TemplateMarketplaceScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _introAnim;
  late final AnimationController _neonCtrl;
  
  String _selectedCategory = 'All';
  String _proFilter = 'All';
  String _sortBy = 'Popular';
  bool _loading = false;
  bool _isGridView = true;
  bool _showSavedOnly = false;
  String? _error;
  Timer? _debounce;
  List<GameTemplate> _templates = [];
  final List<GameTemplate> _compareSelection = [];
  final List<String> _savedTemplateIds = [];

  final List<String> _categories = ['All', 'Action', 'RPG', 'Puzzle', 'Strategy', 'Adventure'];
  final List<String> _sortOptions = ['Popular', 'Newest', 'Rating', 'Price: Low', 'Price: High'];
  final List<String> _proFilters = ['All', 'Featured', 'Mobile-ready', 'Free', 'Paid', '2D', '3D'];

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  Timer? _voiceStopTimer;

  bool _compactGrid = false;

  @override
  void initState() {
    super.initState();
    _introAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
    _neonCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    
    _initSpeech();
    _loadTemplates();
    _loadSaved();
    
    TemplatesService.refreshNotifier.addListener(_refreshListener);
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.autoOpenAiFinder) {
        _openAiFinder();
      }
    });
  }

  @override
  void dispose() {
    try {
      TemplatesService.refreshNotifier.removeListener(_refreshListener);
    } catch (_) {}
    try {
      _searchController.removeListener(_onSearchChanged);
    } catch (_) {}
    try {
      _debounce?.cancel();
    } catch (_) {}
    try {
      _voiceStopTimer?.cancel();
    } catch (_) {}
    try {
      _speech.stop();
    } catch (_) {}
    try {
      _introAnim.dispose();
    } catch (_) {}
    try {
      _neonCtrl.dispose();
    } catch (_) {}
    try {
      _searchController.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = 'All';
      _proFilter = 'All';
      _sortBy = 'Popular';
      _showSavedOnly = false;
      _isGridView = true;
      _compactGrid = false;
      _searchController.clear();
      _error = null;
    });
    _loadTemplates();
  }

  void _refreshListener() => _loadTemplates();

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
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
        category: _selectedCategory == 'All' ? null : _selectedCategory,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final List<dynamic> data = res['data'] is List ? res['data'] : [];
        setState(() {
          _templates = data.map((e) => GameTemplate.fromMap(Map<String, dynamic>.from(e))).toList();
          _loading = false;
        });
      } else {
        setState(() {
          _error = res['message']?.toString() ?? 'Failed to load templates';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _savedTemplateIds.clear();
        _savedTemplateIds.addAll(prefs.getStringList('saved_templates') ?? []);
      });
    }
  }

  Future<void> _toggleSaved(GameTemplate t) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_savedTemplateIds.contains(t.id)) {
        _savedTemplateIds.remove(t.id);
      } else {
        _savedTemplateIds.add(t.id);
      }
    });
    await prefs.setStringList('saved_templates', _savedTemplateIds);
  }

  void _toggleCompare(GameTemplate t) {
    setState(() {
      if (_compareSelection.any((x) => x.id == t.id)) {
        _compareSelection.removeWhere((x) => x.id == t.id);
      } else {
        if (_compareSelection.length < 3) {
          _compareSelection.add(t);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 3 templates for comparison')),
          );
        }
      }
    });
  }

  void _clearCompare() => setState(() => _compareSelection.clear());

  bool get _compareTrayVisible => _compareSelection.isNotEmpty;

  void _openSaved() => setState(() => _showSavedOnly = !_showSavedOnly);

  List<_CompatBadgeData> _compatBadges(GameTemplate t) {
    final b = <_CompatBadgeData>[];
    if (t.category.contains('Mobile')) b.add(_CompatBadgeData('Mobile', Icons.smartphone));
    if (t.tags.contains('2D')) b.add(_CompatBadgeData('2D', Icons.layers));
    if (t.tags.contains('3D')) b.add(_CompatBadgeData('3D', Icons.view_in_ar));
    return b;
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Action': return Icons.flash_on;
      case 'RPG': return Icons.fort;
      case 'Puzzle': return Icons.extension;
      case 'Strategy': return Icons.map;
      case 'Adventure': return Icons.explore;
      default: return Icons.videogame_asset;
    }
  }

  Future<void> _toggleVoiceSearch() async {
    if (_isListening) {
      try {
        _voiceStopTimer?.cancel();
      } catch (_) {}
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      return;
    }

    if (!_speechAvailable) await _initSpeech();
    if (!_speechAvailable) {
      if (!mounted) return;
      return;
    }

    setState(() {
      _isListening = true;
      _error = null;
    });

    try {
      _voiceStopTimer?.cancel();
      _voiceStopTimer = Timer(const Duration(seconds: 8), () async {
        if (!mounted) return;
        if (!_isListening) return;
        try {
          await _speech.stop();
        } catch (_) {}
        if (mounted) setState(() => _isListening = false);
      });
    } catch (_) {}

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        final text = result.recognizedWords;
        _searchController.value = _searchController.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
          composing: TextRange.empty,
        );
        if (result.finalResult) {
          try {
            _voiceStopTimer?.cancel();
          } catch (_) {}
          setState(() => _isListening = false);
          _loadTemplates();
        }
      },
      listenMode: stt.ListenMode.confirmation,
      partialResults: true,
      cancelOnError: true,
    );
  }

  void _openFiltersSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.42,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xlarge)),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Row(
                    children: [
                      Text('Filters', style: AppTypography.subtitle1.copyWith(fontWeight: FontWeight.w900)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Pro', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _proFilters.map((f) {
                      return _AnimatedChoiceChip(
                        label: f,
                        selected: f == _proFilter,
                        onTap: () => setState(() => _proFilter = f),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Sort', style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _sortOptions.map((o) {
                      return _AnimatedChoiceChip(
                        label: o,
                        selected: o == _sortBy,
                        onTap: () => setState(() => _sortBy = o),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SwitchListTile.adaptive(
                    value: _showSavedOnly,
                    onChanged: (v) => setState(() => _showSavedOnly = v),
                    title: const Text('Saved only'),
                  ),
                  SwitchListTile.adaptive(
                    value: _compactGrid,
                    onChanged: (v) => setState(() => _compactGrid = v),
                    title: const Text('Compact grid'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _resetFilters();
                            Navigator.of(context).pop();
                          },
                          child: const Text('Reset all'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Done'),
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

  String? _resolveMediaUrl(String? url) => ApiService.normalizeImageUrl(url);

  List<GameTemplate> _getFilteredTemplates() {
    var list = _templates;
    if (_showSavedOnly) list = list.where((t) => _savedTemplateIds.contains(t.id)).toList();
    if (_selectedCategory != 'All') list = list.where((t) => t.category == _selectedCategory).toList();
    
    // Apply pro filters
    if (_proFilter != 'All') {
      switch (_proFilter) {
        case 'Featured':
          list = list.where((t) => t.isFeatured).toList();
          break;
        case 'Mobile-ready':
          list = list.where((t) => t.category.contains('Mobile')).toList();
          break;
        case 'Free':
          list = list.where((t) => t.price <= 0).toList();
          break;
        case 'Paid':
          list = list.where((t) => t.price > 0).toList();
          break;
        case '2D':
          list = list.where((t) => t.tags.contains('2D')).toList();
          break;
        case '3D':
          list = list.where((t) => t.tags.contains('3D')).toList();
          break;
      }
    }

    // Apply sorting
    switch (_sortBy) {
      case 'Popular':
        list.sort((a, b) => b.downloads.compareTo(a.downloads));
        break;
      case 'Newest':
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'Rating':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Price: Low':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
    }

    return list;
  }

  List<GameTemplate> _getTopTemplates() {
    final list = List<GameTemplate>.from(_getFilteredTemplates());
    list.sort((a, b) {
      final byRating = b.rating.compareTo(a.rating);
      if (byRating != 0) return byRating;
      return b.downloads.compareTo(a.downloads);
    });
    return list.take(5).toList();
  }

  Widget _buildTopTemplatesCarousel() {
    final list = _getTopTemplates();
    if (_loading || list.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Top Templates',
                  style: AppTypography.subtitle2.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  'Top 5',
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.7)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final cs = Theme.of(context).colorScheme;
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final t = list[i];
                  final coverUrl = _resolveMediaUrl(t.imageUrl);
                  return SizedBox(
                    width: 300,
                    child: _PressableGlow(
                      onTap: () => context.push('/template/${t.id}'),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: coverUrl != null && coverUrl.isNotEmpty
                                  ? Image.network(
                                      coverUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(color: AppColors.primary.withOpacity(0.18));
                                      },
                                    )
                                  : Container(color: AppColors.primary.withOpacity(0.18)),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      (isDark ? Colors.black : Colors.white).withOpacity(isDark ? 0.05 : 0.0),
                                      (isDark ? Colors.black : Colors.white).withOpacity(isDark ? 0.55 : 0.45),
                                      (isDark ? Colors.black : Colors.white).withOpacity(isDark ? 0.85 : 0.92),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                            if (t.isFeatured)
                              const Positioned(top: 10, left: 10, child: _FeaturedBadge()),
                            if (t.isDevOwner)
                              const Positioned(top: 10, right: 10, child: _DevBadge.compact()),
                            Positioned(
                              bottom: 12,
                              left: 12,
                              right: 12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    t.name,
                                    style: AppTypography.subtitle2.copyWith(
                                      color: isDark ? Colors.white : cs.onSurface,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.category,
                                    style: AppTypography.caption.copyWith(
                                      color: isDark ? Colors.white70 : cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 12,
                              right: 12,
                              top: 12,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: (isDark ? Colors.black : cs.surfaceContainerHighest).withOpacity(isDark ? 0.35 : 0.75),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: isDark ? Colors.white.withOpacity(0.12) : cs.outlineVariant.withOpacity(0.85),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                        const SizedBox(width: 4),
                                        Text(
                                          t.rating.toStringAsFixed(1),
                                          style: AppTypography.caption.copyWith(
                                            color: isDark ? Colors.white : cs.onSurface,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: (isDark ? Colors.black : cs.surfaceContainerHighest).withOpacity(isDark ? 0.30 : 0.70),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: isDark ? Colors.white.withOpacity(0.10) : cs.outlineVariant.withOpacity(0.80),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.download_rounded,
                                          size: 14,
                                          color: isDark ? Colors.white.withOpacity(0.85) : cs.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${t.downloads}',
                                          style: AppTypography.caption.copyWith(
                                            color: isDark ? Colors.white.withOpacity(0.95) : cs.onSurface,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<GameTemplate> _getFeaturedTemplates() {
    return _templates.where((t) => t.isFeatured).toList();
  }

  Widget _buildFeaturedCarousel() {
    final featured = _getFeaturedTemplates();
    if (_loading || featured.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Featured',
              style: AppTypography.subtitle2.copyWith(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: featured.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final cs = Theme.of(context).colorScheme;
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final t = featured[i];
                  final coverUrl = _resolveMediaUrl(t.imageUrl);
                  return SizedBox(
                    width: 260,
                    child: _PressableGlow(
                      onTap: () => context.push('/template/${t.id}'),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: coverUrl != null && coverUrl.isNotEmpty
                                  ? Image.network(
                                      coverUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(color: AppColors.primary.withOpacity(0.18));
                                      },
                                    )
                                  : Container(color: AppColors.primary.withOpacity(0.18)),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      (isDark ? Colors.black : Colors.white).withOpacity(isDark ? 0.78 : 0.92),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                            const Positioned(top: 10, left: 10, child: _FeaturedBadge()),
                            if (t.isDevOwner)
                              const Positioned(top: 10, right: 10, child: _DevBadge.compact()),
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.subtitle1.copyWith(
                                      color: isDark ? Colors.white : cs.onSurface,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildMetaRow(t),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : cs.surfaceContainerHighest).withOpacity(isDark ? 0.05 : 0.55),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.10) : cs.outlineVariant.withOpacity(0.85),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No templates found',
                    style: AppTypography.subtitle1.copyWith(
                      color: isDark ? Colors.white : cs.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try clearing filters or searching with voice.',
                    style: AppTypography.body2.copyWith(
                      color: isDark ? Colors.white.withOpacity(0.75) : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _resetFilters,
                          child: const Text('Clear filters'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _toggleVoiceSearch(),
                          icon: const Icon(Icons.mic_rounded, size: 18),
                          label: const Text('Try voice'),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasResults = _getFilteredTemplates().isNotEmpty;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF05060A) : cs.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _introAnim,
              builder: (context, _) => CustomPaint(
                painter: _MarketplaceMeshPainter(
                  color1: AppColors.primary.withOpacity(isDark ? 0.10 : 0.08),
                  color2: AppColors.secondary.withOpacity(isDark ? 0.05 : 0.04),
                  progress: _introAnim.value,
                ),
              ),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildHeader(),
              _buildSearchSection(),
              _buildTopTemplatesCarousel(),
              _buildFeaturedCarousel(),
              if (!_loading && !hasResults) _buildEmptyState(),
              if (_loading || hasResults) (_isGridView ? _buildTemplateGrid() : _buildTemplatesList()),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          _buildCompareTray(cs),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Text(
                'NEURAL REPOSITORY',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'GAME\nSTACKS.',
              style: AppTypography.displayLarge.copyWith(
                color: isDark ? Colors.white : cs.onSurface,
                height: 0.9,
                letterSpacing: -2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : cs.surfaceContainerHighest).withOpacity(isDark ? 0.05 : 0.55),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _isListening
                                ? AppColors.primary.withOpacity(0.55)
                                : (isDark ? Colors.white.withOpacity(0.1) : cs.outlineVariant.withOpacity(0.85)),
                            width: _isListening ? 1.6 : 1.0,
                          ),
                          boxShadow: _isListening
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.35),
                                    blurRadius: 26,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 14),
                                  ),
                                ]
                              : const [],
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(color: isDark ? Colors.white : cs.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Search Neural Templates...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white.withOpacity(0.3) : cs.onSurfaceVariant,
                            ),
                            prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary.withOpacity(0.7)),
                            suffixIcon: Tooltip(
                              message: _speechAvailable ? '' : 'Voice search not available',
                              child: IconButton(
                                onPressed: _speechAvailable ? () => _toggleVoiceSearch() : () => _initSpeech(),
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Icon(
                                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                    key: ValueKey(_isListening),
                                    color: _isListening ? AppColors.primary : (isDark ? Colors.white70 : cs.onSurfaceVariant),
                                  ),
                                ),
                              ),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _compactIconButton(
                  onPressed: _openFiltersSheet,
                  icon: Icons.tune_rounded,
                  color: Colors.white,
                ),
                _compactIconButton(
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                  icon: _isGridView ? Icons.grid_view_rounded : Icons.view_list_rounded,
                  color: Colors.white,
                ),
                _compactIconButton(
                  onPressed: _openAiFinder,
                  icon: Icons.auto_awesome_rounded,
                  color: Colors.white,
                ),
                _compactIconButton(
                  onPressed: _openSaved,
                  icon: _showSavedOnly ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _showSavedOnly ? Colors.redAccent : Colors.white,
                ),
              ],
            ),
            if (_isListening) ...[
              const SizedBox(height: 8),
              Text(
                'Listening…',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary.withOpacity(0.95),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildCategoryChips(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildProFilterChips()),
                const SizedBox(width: 8),
                _buildSortDropdown(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactIconButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: isDark ? color : cs.onSurface),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      splashRadius: 20,
      iconSize: 22,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final c = _categories[i];
          final selected = c == _selectedCategory;
          return _AnimatedChoiceChip(
            label: c,
            selected: selected,
            onTap: () {
              if (_selectedCategory == c) return;
              setState(() => _selectedCategory = c);
              _loadTemplates();
            },
          );
        },
      ),
    );
  }

  Widget _buildProFilterChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _proFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final f = _proFilters[i];
          final selected = f == _proFilter;
          return _AnimatedChoiceChip(
            label: f,
            selected: selected,
            onTap: () {
              if (_proFilter == f) return;
              setState(() => _proFilter = f);
            },
          );
        },
      ),
    );
  }

  Widget _buildSortDropdown() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : cs.surfaceContainerHighest).withOpacity(isDark ? 0.05 : 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.10) : cs.outlineVariant.withOpacity(0.85),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: isDark ? const Color(0xFF0B0D14) : cs.surface,
              value: _sortBy,
              items: _sortOptions.map((o) {
                return DropdownMenuItem(
                  value: o,
                  child: Text(o),
                );
              }).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _sortBy = v);
              },
              style: AppTypography.caption.copyWith(
                color: isDark ? Colors.white : cs.onSurface,
                fontWeight: FontWeight.w900,
              ),
              iconEnabledColor: isDark ? Colors.white70 : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price <= 0) return 'FREE';
    final p = price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2);
    return '\$$p';
  }

  Widget _buildMetaRow(GameTemplate t) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : cs.surfaceContainerHighest).withOpacity(isDark ? 0.28 : 0.70),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.12) : cs.outlineVariant.withOpacity(0.85),
            ),
          ),
          child: Text(
            _formatPrice(t.price),
            style: AppTypography.caption.copyWith(
              color: isDark ? Colors.white : cs.onSurface,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : cs.surfaceContainerHighest).withOpacity(isDark ? 0.22 : 0.65),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.10) : cs.outlineVariant.withOpacity(0.80),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                t.rating.toStringAsFixed(1),
                style: AppTypography.caption.copyWith(
                  color: isDark ? Colors.white : cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.download_rounded,
                size: 14,
                color: isDark ? Colors.white.withOpacity(0.8) : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${t.downloads}',
                style: AppTypography.caption.copyWith(
                  color: isDark ? Colors.white.withOpacity(0.9) : cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateGrid() {
    if (_loading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: _MarketplaceSkeleton(isGrid: true),
        ),
      );
    }
    final list = _getFilteredTemplates();
    return SliverPadding(
      padding: EdgeInsets.all(_compactGrid ? 16 : 24),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: _compactGrid ? 14 : 20,
          crossAxisSpacing: _compactGrid ? 14 : 20,
          childAspectRatio: _compactGrid ? 0.86 : 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildTemplateCard(list[index]),
          childCount: list.length,
        ),
      ),
    );
  }

  Widget _buildTemplateCard(GameTemplate t) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final saved = _savedTemplateIds.contains(t.id);
    final compared = _compareSelection.any((x) => x.id == t.id);
    final coverUrl = _resolveMediaUrl(t.imageUrl);
    return AnimatedCard(
      child: GestureDetector(
        onTap: () => context.push('/template/${t.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : cs.onSurface).withOpacity(isDark ? 0.03 : 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : cs.outlineVariant.withOpacity(0.8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: coverUrl != null && coverUrl.isNotEmpty
                            ? Image.network(
                                coverUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(color: AppColors.primary.withOpacity(0.2));
                                },
                              )
                            : Container(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      if (t.isDevOwner)
                        const Positioned(
                          top: 8,
                          left: 8,
                          child: _DevBadge.compact(),
                        ),
                      if (t.isFeatured)
                        const Positioned(
                          top: 8,
                          left: 72,
                          child: _FeaturedBadge(),
                        ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10,
                        child: _buildMetaRow(t),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _toggleCompare(t),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.black : cs.surface).withOpacity(isDark ? 0.26 : 0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  compared ? Icons.check_circle : Icons.compare_arrows,
                                  size: 16,
                                  color: compared ? AppColors.primary : (isDark ? Colors.white : cs.onSurface),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _toggleSaved(t),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.black : cs.surface).withOpacity(isDark ? 0.26 : 0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  saved ? Icons.favorite : Icons.favorite_border,
                                  size: 16,
                                  color: saved ? Colors.redAccent : (isDark ? Colors.white : cs.onSurface),
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
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(
                        color: isDark ? Colors.white : cs.onSurface,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.category.toUpperCase(),
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.primary : cs.primary,
                        fontSize: 8,
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

  Widget _buildCompareTray(ColorScheme cs) {
    if (!_compareTrayVisible) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.95),
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_compareSelection.length} selected for comparison',
                style: AppTypography.body2,
              ),
            ),
            TextButton(onPressed: _clearCompare, child: const Text('Clear')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _openCompareSheet, child: const Text('Compare')),
          ],
        ),
      ),
    );
  }

  Future<void> _openCompareSheet() async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            var compared = List<GameTemplate>.from(_compareSelection);
            return DraggableScrollableSheet(
              initialChildSize: 0.78,
              minChildSize: 0.50,
              maxChildSize: 0.94,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xlarge)),
                    color: cs.surface,
                    border: Border(top: BorderSide(color: cs.outlineVariant)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Text('Compare', style: AppTypography.subtitle1),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: compared.length,
                          itemBuilder: (context, i) => ListTile(
                            title: Text(compared[i].name),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _toggleCompare(compared[i]);
                                setSheetState(() => compared = List<GameTemplate>.from(_compareSelection));
                                if (compared.isEmpty) Navigator.pop(context);
                              },
                            ),
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
      },
    );
  }

  Future<void> _openAiFinder() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AiFinderSheet(
        controller: TextEditingController(),
        onSearch: (p) async => _templates,
        onPick: (t) {
          Navigator.pop(context);
          context.push('/template/${t.id}');
        },
      ),
    );
  }

  Widget _buildTemplatesList() {
    if (_loading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: _MarketplaceSkeleton(isGrid: false),
        ),
      );
    }
    final list = _getFilteredTemplates();
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: list.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildTemplateListItem(t),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildTemplateListItem(GameTemplate t) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final saved = _savedTemplateIds.contains(t.id);
    final compared = _compareSelection.any((x) => x.id == t.id);
    final coverUrl = _resolveMediaUrl(t.imageUrl);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : cs.onSurface).withOpacity(isDark ? 0.03 : 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : cs.outlineVariant.withOpacity(0.8),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 80,
              height: 60,
              child: coverUrl != null && coverUrl.isNotEmpty
                  ? Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(color: AppColors.primary.withOpacity(0.2));
                      },
                    )
                  : Container(color: AppColors.primary.withOpacity(0.2)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.name,
                  style: AppTypography.subtitle2.copyWith(
                    color: isDark ? Colors.white : cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  t.category,
                  style: AppTypography.caption.copyWith(
                    color: isDark ? AppColors.primary : cs.primary,
                  ),
                ),
                const SizedBox(height: 6),
                _buildMetaRow(t),
                if (t.isFeatured) ...[
                  const SizedBox(height: 6),
                  const _FeaturedBadge(),
                ],
                if (t.isDevOwner) ...[
                  const SizedBox(height: 6),
                  const _DevBadge.compact(),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => _toggleCompare(t),
            icon: Icon(
              compared ? Icons.check_circle : Icons.compare_arrows,
              color: compared 
                  ? AppColors.primary 
                  : (isDark ? Colors.white54 : cs.onSurface.withOpacity(0.54)),
            ),
          ),
          IconButton(
            onPressed: () => _toggleSaved(t),
            icon: Icon(
              saved ? Icons.favorite : Icons.favorite_border,
              color: saved 
                  ? Colors.redAccent 
                  : (isDark ? Colors.white54 : cs.onSurface.withOpacity(0.54)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatBadgeData {
  final String label;
  final IconData icon;
  _CompatBadgeData(this.label, this.icon);
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

class _DevBadge extends StatelessWidget {
  final bool compact;

  const _DevBadge({this.compact = false});

  const _DevBadge.compact() : compact = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 6);

    final iconSize = compact ? 12.0 : 14.0;
    final fontSize = compact ? 9.0 : 10.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary.withOpacity(0.95), cs.secondary.withOpacity(0.90)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: pad,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: iconSize, color: cs.onPrimary),
            const SizedBox(width: 6),
            Text(
              'DEV',
              style: AppTypography.caption.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.w900,
                fontSize: fontSize,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PressableGlow extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _PressableGlow({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = sel ? Colors.white : cs.onSurfaceVariant;
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
            gradient: sel
                ? LinearGradient(
                    colors: [cs.primary, cs.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      cs.surfaceContainerHighest.withOpacity(isDark ? 0.22 : 0.55),
                      cs.surface.withOpacity(isDark ? 0.16 : 0.45),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(br),
            border: Border.all(color: sel ? cs.primary.withOpacity(0.38) : cs.outlineVariant.withOpacity(0.55)),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.22),
                      blurRadius: 18,
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
  final String? ownerRole;
  final String? ownerUsername;
  final String? ownerAvatar;
  final DateTime createdAt;

  bool get isDevOwner {
    final r = (ownerRole ?? '').trim().toLowerCase();
    return r == 'dev' || r == 'devl';
  }

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
    this.ownerRole,
    this.ownerUsername,
    this.ownerAvatar,
    required this.createdAt,
  });

  factory GameTemplate.fromMap(Map<String, dynamic> map) {
    final rawImage = (map['imageUrl'] ??
            map['previewImageUrl'] ??
            map['previewImage'] ??
            map['thumbnailUrl'] ??
            map['thumbnail'] ??
            map['coverUrl'])
        ?.toString();

    final rawVideo = (map['previewVideoUrl'] ?? map['previewVideo'])?.toString();

    return GameTemplate(
      id: map['_id']?.toString() ?? map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      category: map['category']?.toString() ?? 'Other',
      description: map['description']?.toString() ?? '',
      rating: double.tryParse(map['rating']?.toString() ?? '') ?? 0.0,
      downloads: int.tryParse(map['downloads']?.toString() ?? '') ?? 0,
      price: double.tryParse(map['price']?.toString() ?? '') ?? 0.0,
      imageUrl: ApiService.normalizeImageUrl(rawImage),
      previewVideoUrl: ApiService.normalizeImageUrl(rawVideo),
      tags: (map['tags'] is List) 
          ? List<String>.from(map['tags'].map((e) => e.toString()))
          : (map['tags']?.toString() ?? '').split(',').where((s) => s.trim().isNotEmpty).toList(),
      isFeatured: map['isFeatured'] == true,
      creator: map['creator']?.toString() ?? 'Anonymous',
      ownerRole: map['ownerRole']?.toString(),
      ownerUsername: map['ownerUsername']?.toString(),
      ownerAvatar: map['ownerAvatar']?.toString(),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
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

class _MarketplaceMeshPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final double progress;

  _MarketplaceMeshPainter({
    required this.color1,
    required this.color2,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    paint.color = color1;
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * (0.1 + 0.1 * progress)),
      size.width * 0.6 * progress,
      paint,
    );
    paint.color = color2;
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * (0.4 - 0.05 * progress)),
      size.width * 0.4 * progress,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MarketplaceMeshPainter oldDelegate) => true;
}
