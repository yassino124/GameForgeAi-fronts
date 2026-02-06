import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/themes/app_theme.dart';
import '../../presentation/widgets/widgets.dart';

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

  final List<GameTemplate> _featuredTemplates = [
    GameTemplate(
      id: '1',
      name: 'Space Odyssey',
      category: 'Action',
      description: 'Epic space adventure with stunning graphics and immersive gameplay',
      rating: 4.9,
      downloads: 25000,
      price: 0.0,
      imageUrl: null,
      tags: ['space', 'adventure', '3d'],
      isFeatured: true,
      creator: 'GameForge Studios',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
    GameTemplate(
      id: '2',
      name: 'Puzzle Master Pro',
      category: 'Puzzle',
      description: 'Challenging puzzles with AI-generated levels',
      rating: 4.8,
      downloads: 18000,
      price: 4.99,
      imageUrl: null,
      tags: ['puzzle', 'brain', 'ai'],
      isFeatured: true,
      creator: 'Mind Games Inc',
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
    ),
  ];

  late final List<GameTemplate> _allTemplates;

  @override
  void initState() {
    super.initState();
    _allTemplates = [
      ..._featuredTemplates,
      GameTemplate(
        id: '3',
        name: 'Fantasy Quest',
        category: 'RPG',
        description: 'Classic RPG with modern twists',
        rating: 4.7,
        downloads: 12000,
        price: 9.99,
        imageUrl: null,
        tags: ['rpg', 'fantasy', 'story'],
        isFeatured: false,
        creator: 'Epic Games Studio',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      GameTemplate(
        id: '4',
        name: 'Tower Defense Elite',
        category: 'Strategy',
        description: 'Strategic tower defense gameplay',
        rating: 4.6,
        downloads: 15000,
        price: 2.99,
        imageUrl: null,
        tags: ['strategy', 'defense', 'tactics'],
        isFeatured: false,
        creator: 'Strategy Masters',
        createdAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      GameTemplate(
        id: '5',
        name: 'Casino Royale',
        category: 'Casual',
        description: 'Premium casino experience',
        rating: 4.5,
        downloads: 8000,
        price: 0.0,
        imageUrl: null,
        tags: ['casino', 'cards', 'luck'],
        isFeatured: false,
        creator: 'Lucky Games',
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
      ),
    ];
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
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ),
                    
                    const SizedBox(width: AppSpacing.md),
                    
                    // Voice search button
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      ),
                      child: Icon(
                        Icons.mic,
                        color: cs.onPrimary,
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
                              child: FilterChip(
                                label: Text(category),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedCategory = category;
                                  });
                                },
                                backgroundColor: cs.surface,
                                selectedColor: AppColors.primary.withOpacity(0.2),
                                labelStyle: AppTypography.caption.copyWith(
                                  color: isSelected ? cs.primary : cs.onSurface,
                                ),
                                side: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
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
                  // Featured carousel
                  if (_featuredTemplates.isNotEmpty) ...[
                    Text(
                      'Featured Templates',
                      style: AppTypography.subtitle2,
                    ),
                    
                    const SizedBox(height: AppSpacing.lg),
                    
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _featuredTemplates.length,
                        itemBuilder: (context, index) {
                          return _buildFeaturedCard(_featuredTemplates[index]);
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
                  _isGridView 
                      ? _buildTemplatesGrid()
                      : _buildTemplatesList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(GameTemplate template) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        gradient: AppColors.primaryGradient,
        boxShadow: AppShadows.boxShadowLarge,
      ),
      child: Stack(
        children: [
          // Background pattern
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
                  // Navigate to template selection or create project with this template
                  context.go('/create-project');
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
    return Container(
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
    );
  }

  Widget _buildTemplateListItem(GameTemplate template) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
        boxShadow: AppShadows.boxShadowSmall,
      ),
      child: Row(
        children: [
          // Template preview
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              gradient: AppColors.primaryGradient,
            ),
            child: Icon(
              _getCategoryIcon(template.category),
              size: 32,
              color: cs.onPrimary.withOpacity(0.75),
            ),
          ),
          
          const SizedBox(width: AppSpacing.lg),
          
          // Template info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      template.name,
                      style: AppTypography.subtitle2,
                    ),
                    
                    const Spacer(),
                    
                    if (template.price > 0)
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
                          '\$${template.price}',
                          style: AppTypography.caption.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
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
                          'FREE',
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
                    Icon(
                      Icons.star,
                      size: 12,
                      color: AppColors.warning,
                    ),
                    
                    const SizedBox(width: 2),
                    
                    Text(
                      template.rating.toString(),
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const SizedBox(width: AppSpacing.md),
                    
                    Text(
                      '${(template.downloads / 1000).toStringAsFixed(1)}k downloads',
                      style: AppTypography.caption.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    
                    const Spacer(),
                    
                    Text(
                      'by ${template.creator}',
                      style: AppTypography.caption.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<GameTemplate> _getFilteredTemplates() {
    var templates = _allTemplates;
    
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
        t.tags.any((tag) => tag.toLowerCase().contains(searchQuery)) ||
        t.creator.toLowerCase().contains(searchQuery)
      ).toList();
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
