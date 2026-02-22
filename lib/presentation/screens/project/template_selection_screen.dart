import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../core/constants/app_constants.dart';
import '../../../core/themes/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/templates_service.dart';
import '../../widgets/widgets.dart';
import 'package:video_player/video_player.dart';

class TemplateSelectionScreen extends StatefulWidget {
  const TemplateSelectionScreen({super.key});

  @override
  State<TemplateSelectionScreen> createState() => _TemplateSelectionScreenState();
}

class _TemplateSelectionScreenState extends State<TemplateSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  GameTemplate? _selectedTemplate;

  bool _loading = false;
  String? _error;
  List<GameTemplate> _templates = const [];

  final List<String> _categories = [
    'All',
    'Action',
    'Puzzle',
    'RPG',
    'Strategy',
    'Casual',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _loadTemplates();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTemplates());
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

      return baseOrigin.replace(path: u.path, query: u.query).toString();
    } catch (_) {
      return raw;
    }
  }

  Future<void> _openVideoPlayer(String url) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _VideoPlayerDialog(url: url),
    );
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
        return GameTemplate(
          id: id,
          name: e['name']?.toString() ?? 'Template',
          category: e['category']?.toString() ?? 'General',
          description: e['description']?.toString() ?? '',
          rating: (e['rating'] is num) ? (e['rating'] as num).toDouble() : 4.7,
          downloads: (e['downloads'] is num) ? (e['downloads'] as num).toInt() : 0,
          imageUrl: _resolveMediaUrl(e['previewImageUrl']?.toString()),
          screenshotUrls: (e['screenshotUrls'] is List)
              ? (e['screenshotUrls'] as List).map((x) => _resolveMediaUrl(x?.toString()) ?? '').where((x) => x.isNotEmpty).toList()
              : const <String>[],
          previewVideoUrl: _resolveMediaUrl(e['previewVideoUrl']?.toString()),
          tags: (e['tags'] is List) ? (e['tags'] as List).map((t) => t.toString()).toList() : const [],
        );
      }).whereType<GameTemplate>().toList();

      setState(() {
        _templates = parsed;
        if (_selectedTemplate != null) {
          final stillExists = _templates.any((t) => t.id == _selectedTemplate!.id);
          if (!stillExists) _selectedTemplate = null;
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text(
          'Choose a Template',
          style: AppTypography.subtitle1,
        ),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
          icon: Icon(
            Icons.arrow_back,
            color: cs.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Coach Guide',
            onPressed: () {
              context.push('/ai-coach');
            },
            icon: Icon(
              Icons.mic_rounded,
              color: cs.onSurface,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Center(
              child: Text(
                '1/3',
                style: AppTypography.caption.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
      
      body: Column(
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary,
                  cs.primary.withOpacity(0.3),
                ],
              ),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.33,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: AppSpacing.paddingHorizontalLarge,
            child: CustomSearchField(
              controller: _searchController,
              hint: 'Search templates...',
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          
          const SizedBox(height: AppSpacing.lg),

          if (_error != null)
            Padding(
              padding: AppSpacing.paddingHorizontalLarge,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
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
            ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          
          // Category tabs
          _buildCategoryTabs(),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Templates grid
          Expanded(
            child: _buildTemplatesGrid(),
          ),
          
          // Bottom button
          Container(
            padding: AppSpacing.paddingLarge,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomButton(
                  text: 'Create from scratch (AI)',
                  onPressed: () {
                    context.go('/ai-create-game');
                  },
                  type: ButtonType.secondary,
                  isFullWidth: true,
                  icon: const Icon(Icons.auto_awesome_rounded),
                ),

                const SizedBox(height: AppSpacing.sm),

                CustomButton(
                  text: 'Instant HTML5 (Phaser)',
                  onPressed: () {
                    context.go('/ai-phaser');
                  },
                  type: ButtonType.secondary,
                  isFullWidth: true,
                  icon: const Icon(Icons.bolt_rounded),
                ),

                const SizedBox(height: AppSpacing.sm),

                CustomButton(
                  text: 'Next',
                  onPressed: _selectedTemplate != null
                      ? () {
                          context.go('/project-details', extra: _selectedTemplate);
                        }
                      : null,
                  isFullWidth: true,
                ),

                const SizedBox(height: AppSpacing.sm),

                CustomButton(
                  text: 'Generate with AI',
                  onPressed: _selectedTemplate != null
                      ? () {
                          context.go(
                            '/ai-configuration',
                            extra: {
                              'templateId': _selectedTemplate!.id,
                              'templateName': _selectedTemplate!.name,
                            },
                          );
                        }
                      : null,
                  type: ButtonType.secondary,
                  isFullWidth: true,
                  icon: const Icon(Icons.auto_awesome),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
                _loadTemplates();
              },
              backgroundColor: cs.surface,
              selectedColor: cs.primary.withOpacity(0.16),
              labelStyle: AppTypography.body2.copyWith(
                color: isSelected ? cs.primary : cs.onSurface,
              ),
              side: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTemplatesGrid() {
    final filteredTemplates = _getFilteredTemplates();
    
    if (filteredTemplates.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.search_off,
        title: 'No templates found',
        subtitle: 'Try adjusting your search or filters',
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: AppSpacing.lg,
          mainAxisSpacing: AppSpacing.lg,
        ),
        itemCount: filteredTemplates.length,
        itemBuilder: (context, index) {
          final template = filteredTemplates[index];
          return _buildTemplateCard(template);
        },
      ),
    );
  }

  Widget _buildTemplateCard(GameTemplate template) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedTemplate?.id == template.id;
    final coverUrl = _resolveMediaUrl(template.imageUrl);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTemplate = isSelected ? null : template;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppBorderRadius.large),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outlineVariant.withOpacity(0.6),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: AppShadows.boxShadowSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Template preview image
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
                                  color: cs.onPrimary.withOpacity(0.85),
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
                          color: cs.onPrimary.withOpacity(0.85),
                        ),
                      ),

                    if (template.previewVideoUrl != null && template.previewVideoUrl!.trim().isNotEmpty)
                      Positioned(
                        bottom: AppSpacing.sm,
                        left: AppSpacing.sm,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                            onTap: () async {
                              await _openVideoPlayer(template.previewVideoUrl!);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: cs.surface.withOpacity(0.82),
                                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_arrow, size: 16, color: cs.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Play',
                                    style: AppTypography.caption.copyWith(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (template.screenshotUrls.isNotEmpty)
                      Positioned(
                        bottom: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surface.withOpacity(0.82),
                            borderRadius: AppBorderRadius.allSmall,
                          ),
                          child: Text(
                            '${template.screenshotUrls.length} shots',
                            style: AppTypography.caption.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    
                    // Category badge
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surface.withOpacity(0.82),
                          borderRadius: AppBorderRadius.allSmall,
                        ),
                        child: Text(
                          template.category,
                          style: AppTypography.caption.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    
                    // Selection indicator
                    if (isSelected)
                      Positioned(
                        top: AppSpacing.sm,
                        left: AppSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 16,
                            color: cs.onPrimary,
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
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: AppTypography.subtitle2.copyWith(color: cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        template.description,
                        style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(Icons.star, size: 12, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          template.rating.toString(),
                          style: AppTypography.caption.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${template.downloads} downloads',
                          style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant),
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

  List<GameTemplate> _getFilteredTemplates() {
    return _templates;
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
  final String? imageUrl;
  final List<String> screenshotUrls;
  final String? previewVideoUrl;
  final List<String> tags;

  GameTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.rating,
    required this.downloads,
    this.imageUrl,
    this.screenshotUrls = const [],
    this.previewVideoUrl,
    required this.tags,
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
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.black,
      child: SafeArea(
        child: FutureBuilder<void>(
          future: _init,
          builder: (context, snapshot) {
            final ready = snapshot.connectionState == ConnectionState.done && _controller.value.isInitialized;
            return Stack(
              children: [
                Positioned.fill(
                  child: ready
                      ? Center(
                          child: AspectRatio(
                            aspectRatio: _controller.value.aspectRatio == 0
                                ? 16 / 9
                                : _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          ),
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
                if (ready)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          colors: VideoProgressColors(
                            playedColor: cs.primary,
                            bufferedColor: Colors.white24,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  if (_controller.value.isPlaying) {
                                    _controller.pause();
                                  } else {
                                    _controller.play();
                                  }
                                });
                              },
                              icon: Icon(
                                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${(_controller.value.position.inSeconds).toString()}s',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
