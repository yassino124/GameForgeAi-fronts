import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/templates_service.dart';
import '../../widgets/widgets.dart';

class TemplateMarketplaceScreen extends StatefulWidget {
  const TemplateMarketplaceScreen({super.key});

  @override
  State<TemplateMarketplaceScreen> createState() => _TemplateMarketplaceScreenState();
}

class _TemplateMarketplaceScreenState extends State<TemplateMarketplaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _sortBy = 'Popular';
  bool _isGridView = true;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<GameTemplate> _templates = [];

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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initSpeech();
    _loadTemplates();
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
    final featured = _getFeaturedTemplates();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          'Template Marketplace',
          style: AppTypography.subtitle1,
        ),
        actions: [
          // View toggle
          IconButton(
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            icon: Icon(
              _isGridView ? Icons.view_list : Icons.grid_view,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
      
      body: Column(
        children: [
          // Search and filters
          Container(
            padding: AppSpacing.paddingLarge,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
              ),
            ),
            child: Column(
              children: [
                // Search bar with voice search
                Row(
                  children: [
                    Expanded(
                      child: CustomSearchField(
                        controller: _searchController,
                        hint: 'Search templates...',
                        onChanged: (_) {},
                      ),
                    ),
                    
                    const SizedBox(width: AppSpacing.md),
                    
                    // Voice search button
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
                          _isListening ? Icons.graphic_eq : Icons.mic,
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: AppSpacing.lg),
                
                // Category chips and sort
                Row(
                  children: [
                    // Sort dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortBy,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _sortBy = value;
                              });
                            }
                          },
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          underline: const SizedBox(),
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          items: _sortOptions.map((option) {
                            return DropdownMenuItem(
                              value: option,
                              child: Text(option),
                            );
                          }).toList(),
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
                              child: ChoiceChip(
                                label: Text(category),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedCategory = category;
                                  });
                                  _loadTemplates();
                                },
                                selectedColor: cs.primary.withOpacity(0.2),
                                backgroundColor: cs.surface,
                                labelStyle: AppTypography.caption.copyWith(
                                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                                  side: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: AppSpacing.paddingLarge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loading) ...[
                    const Center(child: CircularProgressIndicator()),
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
                    Text(
                      'Featured Templates',
                      style: AppTypography.subtitle2,
                    ),
                    
                    const SizedBox(height: AppSpacing.lg),
                    
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: featured.length,
                        itemBuilder: (context, index) {
                          return _buildFeaturedCard(featured[index]);
                        },
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.xxxl),
                  ],

                  // All templates
                  Text(
                    'All Templates',
                    style: AppTypography.subtitle2,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Templates grid/list
                  _isGridView ? _buildTemplatesGrid() : _buildTemplatesList(),
                ],
              ),
            ),
          ),
        ],
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
    return GestureDetector(
      onTap: () {
        context.go('/template/${template.id}');
      },
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          gradient: AppColors.primaryGradient,
          boxShadow: AppShadows.boxShadowLarge,
        ),
        child: Stack(
          children: [
            if (coverUrl != null && coverUrl.trim().isNotEmpty)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  child: Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppBorderRadius.large),
                          color: cs.onPrimary.withOpacity(0.10),
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    color: cs.onPrimary.withOpacity(0.10),
                  ),
                ),
              ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Featured badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: AppBorderRadius.allSmall,
                  ),
                  child: Text(
                    'FEATURED',
                    style: AppTypography.caption.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(height: AppSpacing.sm),
                
                // Template name
                Text(
                  template.name,
                  style: AppTypography.subtitle1.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: AppSpacing.sm),
                
                // Description
                Text(
                  template.description,
                  style: AppTypography.caption.copyWith(
                    color: cs.onPrimary.withOpacity(0.85),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                // Rating and price
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 16,
                      color: cs.onPrimary,
                    ),
                    
                    const SizedBox(width: 4),
                    
                    Text(
                      template.rating.toString(),
                      style: AppTypography.caption.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const Spacer(),
                    
                    Text(
                      template.price == 0.0 ? 'FREE' : '\$${template.price}',
                      style: AppTypography.caption.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Use template button
          Positioned(
            bottom: AppSpacing.lg,
            right: AppSpacing.lg,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                onTap: () {
                  context.go('/template/${template.id}');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: cs.onPrimary,
                    borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                    boxShadow: [
                      BoxShadow(
                        color: cs.onPrimary.withOpacity(0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'Use Template',
                    style: AppTypography.caption.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
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

  Widget _buildTemplatesGrid() {
    final filteredTemplates = _getFilteredTemplates();
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: AppSpacing.lg,
        mainAxisSpacing: AppSpacing.lg,
      ),
      itemCount: filteredTemplates.length,
      itemBuilder: (context, index) {
        return _buildTemplateCard(filteredTemplates[index]);
      },
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
    return GestureDetector(
      onTap: () {
        context.go('/template/${template.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
          boxShadow: AppShadows.boxShadowSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Template preview
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppBorderRadius.large),
                  ),
                  gradient: AppColors.primaryGradient,
                ),
                child: Stack(
                  children: [
                    if (coverUrl != null && coverUrl.trim().isNotEmpty)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppBorderRadius.large),
                          ),
                          child: Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  _getCategoryIcon(template.category),
                                  size: 40,
                                  color: cs.onPrimary.withOpacity(0.75),
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    else
                      Center(
                        child: Icon(
                          _getCategoryIcon(template.category),
                          size: 40,
                          color: cs.onPrimary.withOpacity(0.75),
                        ),
                      ),
                    
                    // Price badge
                    if (template.price > 0)
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: AppBorderRadius.allSmall,
                          ),
                          child: Text(
                            '\$${template.price}',
                            style: AppTypography.caption.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: AppBorderRadius.allSmall,
                          ),
                          child: Text(
                            'FREE',
                            style: AppTypography.caption.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Template info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: AppTypography.subtitle2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: AppSpacing.xs),
                    
                    Text(
                      template.description,
                      style: AppTypography.caption.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: AppSpacing.xs),
                    
                    // Rating and creator
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 12,
                          color: AppColors.warning,
                        ),
                        
                        const SizedBox(width: 2),
                        
                        Expanded(
                          child: Text(
                            template.rating.toString(),
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        const SizedBox(width: AppSpacing.sm),
                        
                        Expanded(
                          flex: 2,
                          child: Text(
                            template.creator,
                            style: AppTypography.caption.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateListItem(GameTemplate template) {
    final cs = Theme.of(context).colorScheme;
    final coverUrl = _resolveMediaUrl(template.imageUrl);
    return GestureDetector(
      onTap: () {
        context.go('/template/${template.id}');
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
          boxShadow: AppShadows.boxShadowSmall,
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                gradient: AppColors.primaryGradient,
              ),
              child: (coverUrl != null && coverUrl.trim().isNotEmpty)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      child: Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            _getCategoryIcon(template.category),
                            size: 32,
                            color: cs.onPrimary.withOpacity(0.75),
                          );
                        },
                      ),
                    )
                  : Icon(
                      _getCategoryIcon(template.category),
                      size: 32,
                      color: cs.onPrimary.withOpacity(0.75),
                    ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          template.name,
                          style: AppTypography.subtitle2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: AppBorderRadius.allSmall,
                        ),
                        child: Text(
                          template.price > 0 ? '\$${template.price}' : 'FREE',
                          style: AppTypography.caption.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    template.description,
                    style: AppTypography.caption.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.star, size: 12, color: AppColors.warning),
                      const SizedBox(width: 2),
                      Text(
                        template.rating.toString(),
                        style: AppTypography.caption.copyWith(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          '${(template.downloads / 1000).toStringAsFixed(1)}k downloads',
                          style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Flexible(
                        child: Text(
                          'by ${template.creator}',
                          style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
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

  List<GameTemplate> _getFilteredTemplates() {
    var templates = [..._templates];
    
    // Filter by category
    if (_selectedCategory != 'All') {
      templates = templates.where((t) => t.category == _selectedCategory).toList();
    }
    
    // Local intelligent ranking (in addition to backend filter)
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
    
    // Sort
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

class GameTemplate {
  final String id;
  final String name;
  final String category;
  final String description;
  final double rating;
  final int downloads;
  final double price;
  final String? imageUrl;
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
    required this.tags,
    required this.isFeatured,
    required this.creator,
    required this.createdAt,
  });
}
