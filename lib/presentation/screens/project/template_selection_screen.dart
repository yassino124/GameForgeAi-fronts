import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../presentation/widgets/widgets.dart';

class TemplateSelectionScreen extends StatefulWidget {
  const TemplateSelectionScreen({super.key});

  @override
  State<TemplateSelectionScreen> createState() => _TemplateSelectionScreenState();
}

class _TemplateSelectionScreenState extends State<TemplateSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  GameTemplate? _selectedTemplate;

  final List<String> _categories = [
    'All',
    'Action',
    'Puzzle',
    'RPG',
    'Strategy',
    'Casual',
  ];

  final List<GameTemplate> _templates = [
    GameTemplate(
      id: '1',
      name: 'Space Shooter',
      category: 'Action',
      description: 'Classic arcade space shooting game',
      rating: 4.8,
      downloads: 12500,
      imageUrl: null,
      tags: ['arcade', 'space', 'shooter'],
    ),
    GameTemplate(
      id: '2',
      name: 'Puzzle Quest',
      category: 'Puzzle',
      description: 'Challenging puzzle adventure',
      rating: 4.6,
      downloads: 8900,
      imageUrl: null,
      tags: ['puzzle', 'adventure', 'brain'],
    ),
    GameTemplate(
      id: '3',
      name: 'Fantasy RPG',
      category: 'RPG',
      description: 'Epic role-playing game with magic',
      rating: 4.9,
      downloads: 15200,
      imageUrl: null,
      tags: ['rpg', 'fantasy', 'magic'],
    ),
    GameTemplate(
      id: '4',
      name: 'Tower Defense',
      category: 'Strategy',
      description: 'Strategic tower defense gameplay',
      rating: 4.7,
      downloads: 9800,
      imageUrl: null,
      tags: ['strategy', 'defense', 'tactics'],
    ),
    GameTemplate(
      id: '5',
      name: 'Casino Slots',
      category: 'Casual',
      description: 'Fun slot machine game',
      rating: 4.5,
      downloads: 6700,
      imageUrl: null,
      tags: ['casino', 'slots', 'casual'],
    ),
    GameTemplate(
      id: '6',
      name: 'Racing Thunder',
      category: 'Action',
      description: 'High-speed racing game',
      rating: 4.8,
      downloads: 11200,
      imageUrl: null,
      tags: ['racing', 'action', 'sports'],
    ),
  ];

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
      ),
      
      body: Column(
        children: [
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
            child: CustomButton(
              text: 'Next',
              onPressed: _selectedTemplate != null
                  ? () {
                      context.go('/project-details', extra: _selectedTemplate);
                    }
                  : null,
              isFullWidth: true,
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
                    Center(
                      child: Icon(
                        _getCategoryIcon(template.category),
                        size: 40,
                        color: cs.onPrimary.withOpacity(0.85),
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
            Flexible(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      template.name,
                      style: AppTypography.subtitle2.copyWith(
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                    
                    const SizedBox(height: AppSpacing.xs),
                    
                    // Rating and downloads
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          Icons.star,
                          size: 12,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            template.rating.toString(),
                            style: AppTypography.caption.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            '${(template.downloads / 1000).toStringAsFixed(1)}k',
                            style: AppTypography.caption.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
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

  List<GameTemplate> _getFilteredTemplates() {
    var templates = _templates;
    
    // Filter by category
    if (_selectedCategory != 'All') {
      templates = templates.where((t) => t.category == _selectedCategory).toList();
    }
    
    // Filter by search
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      templates = templates.where((t) => 
        t.name.toLowerCase().contains(searchQuery) ||
        t.description.toLowerCase().contains(searchQuery) ||
        t.tags.any((tag) => tag.toLowerCase().contains(searchQuery))
      ).toList();
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
  final List<String> tags;

  GameTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.rating,
    required this.downloads,
    this.imageUrl,
    required this.tags,
  });
}
