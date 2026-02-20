import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/admin_theme.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/admin_button.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  static const _categoryColors = {
    'Platformer': AdminTheme.accentNeon,
    'Shooter': AdminTheme.accentRed,
    'RPG': AdminTheme.accentPurple,
    'Puzzle': AdminTheme.accentGreen,
    'Racing': AdminTheme.accentOrange,
    'Strategy': AdminTheme.accentPurple,
    'Music': AdminTheme.accentOrange,
    'Survival': AdminTheme.accentGreen,
    'Casual': AdminTheme.accentNeon,
    'Adventure': AdminTheme.accentPurple,
    'Simulation': AdminTheme.accentGreen,
    'default': AdminTheme.textSecondary,
  };

  static const _categories = ['all', 'Platformer', 'Shooter', 'RPG', 'Puzzle', 'Racing', 'Adventure'];

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        final templates = provider.filteredTemplates;
        final isGrid = provider.marketplaceGridView;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toolbar
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ..._categories.map((c) => FilterChip(
                  label: Text(c == 'all' ? 'All' : c),
                  selected: provider.marketplaceCategoryFilter.toLowerCase() == c.toLowerCase(),
                  onSelected: (_) => provider.setMarketplaceCategoryFilter(c),
                  selectedColor: AdminTheme.accentNeon.withOpacity(0.3),
                  checkmarkColor: AdminTheme.accentNeon,
                )),
                const Spacer(),
                IconButton(
                  icon: Icon(provider.marketplaceGridView ? Icons.grid_view : Icons.list, color: AdminTheme.textSecondary),
                  onPressed: () => provider.setMarketplaceGridView(!provider.marketplaceGridView),
                  tooltip: provider.marketplaceGridView ? 'List view' : 'Grid view',
                ),
                AdminButton(label: 'Add New Template', icon: Icons.add, onPressed: () => _showTemplateModal(context)),
              ],
            ),
            const SizedBox(height: 24),
            // Content
            if (isGrid)
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 3 : 2);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: templates.length,
                    itemBuilder: (context, i) => _TemplateCard(template: templates[i], color: _categoryColors[templates[i]['category']] ?? _categoryColors['default']!),
                  );
                },
              )
            else
              ...templates.map((t) => _TemplateListTile(
                template: t,
                color: _categoryColors[t['category']] ?? _categoryColors['default']!,
                onEdit: () => _showTemplateModal(context, t),
              )),
          ],
        );
      },
    );
  }

  void _showTemplateModal(BuildContext context, [Map<String, dynamic>? template]) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgSecondary,
        title: Text(template != null ? 'Edit Template' : 'Add New Template', style: const TextStyle(color: AdminTheme.textPrimary)),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Name'),
                  controller: TextEditingController(text: template?['name']?.toString()),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Category'),
                  initialValue: template?['category']?.toString() ?? 'Platformer',
                  dropdownColor: AdminTheme.bgSecondary,
                  items: ['Platformer', 'Shooter', 'RPG', 'Puzzle', 'Racing', 'Strategy', 'Adventure'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (_) {},
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                  controller: TextEditingController(text: template?['description']?.toString()),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: (template?['price'] ?? 0).toString()),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(labelText: 'Unity Version'),
                  controller: TextEditingController(text: template?['unityVersion']?.toString() ?? '2022.3 LTS'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template saved'), backgroundColor: AdminTheme.accentGreen));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.accentNeon, foregroundColor: AdminTheme.bgPrimary),
            child: Text(template != null ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final Map<String, dynamic> template;
  final Color color;

  const _TemplateCard({required this.template, required this.color});

  @override
  Widget build(BuildContext context) {
    final platforms = (template['platforms'] as List?)?.cast<String>() ?? [];
    final price = template['price'];
    final priceStr = (price == 0 || price == 0.0) ? 'FREE' : '\$${price.toStringAsFixed(2)}';

    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.borderGlow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.5), color.withOpacity(0.1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template['name']?.toString() ?? '',
                    style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${template['category']} ★ ${template['rating'] ?? 0}',
                    style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(template['downloads'] ?? 0).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} downloads',
                    style: GoogleFonts.jetBrainsMono(color: AdminTheme.textMuted, fontSize: 11),
                  ),
                  Text(template['unityVersion']?.toString() ?? '', style: GoogleFonts.jetBrainsMono(color: AdminTheme.textMuted, fontSize: 11)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: platforms.take(4).map((p) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AdminTheme.bgTertiary, borderRadius: BorderRadius.circular(4)),
                      child: Text(p, style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary, fontSize: 10)),
                    )).toList(),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(priceStr, style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: AdminTheme.accentNeon)),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.edit, size: 18, color: AdminTheme.accentPurple), onPressed: () {}, tooltip: 'Edit'),
                          IconButton(icon: Icon((template['status'] == 'active' ? Icons.toggle_on : Icons.toggle_off), size: 24, color: AdminTheme.accentGreen), onPressed: () {}, tooltip: 'Toggle'),
                        ],
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
}

class _TemplateListTile extends StatelessWidget {
  final Map<String, dynamic> template;
  final Color color;
  final VoidCallback onEdit;

  const _TemplateListTile({required this.template, required this.color, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final platforms = (template['platforms'] as List?)?.cast<String>() ?? [];
    final price = template['price'];
    final priceStr = (price == 0 || price == 0.0) ? 'FREE' : '\$${price.toStringAsFixed(2)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.borderGlow),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template['name']?.toString() ?? '', style: GoogleFonts.orbitron(fontSize: 16, color: AdminTheme.textPrimary)),
                Text('${template['category']} • ★ ${template['rating']} • ${template['downloads']} downloads', style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(priceStr, style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: AdminTheme.accentNeon)),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.edit, color: AdminTheme.accentPurple), onPressed: onEdit, tooltip: 'Edit'),
        ],
      ),
    );
  }
}
