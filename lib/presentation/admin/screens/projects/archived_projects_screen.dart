import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/admin_theme.dart';
import '../../providers/admin_provider.dart';

class ArchivedProjectsScreen extends StatefulWidget {
  const ArchivedProjectsScreen({super.key});

  @override
  State<ArchivedProjectsScreen> createState() => _ArchivedProjectsScreenState();
}

class _ArchivedProjectsScreenState extends State<ArchivedProjectsScreen> {
  static const _categoryColors = {
    'Platformer': AdminTheme.accentNeon,
    'Shooter': AdminTheme.accentRed,
    'RPG': AdminTheme.accentPurple,
    'Puzzle': AdminTheme.accentGreen,
    'Racing': AdminTheme.accentOrange,
    'Strategy': AdminTheme.accentPurple,
    'default': AdminTheme.textSecondary,
  };

  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        // Get archived projects
        final allProjects = provider.projects;
        final archivedProjects = allProjects
            .where((p) => p['status'] == 'archived')
            .toList()
            .where((p) {
          final searchLower = _searchQuery.toLowerCase();
          final name = (p['name']?.toString() ?? '').toLowerCase();
          final owner = (p['ownerDisplay']?.toString() ?? '').toLowerCase();
          return name.contains(searchLower) || owner.contains(searchLower);
        }).toList();

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AdminTheme.bgSecondary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AdminTheme.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Archived Projects',
              style: GoogleFonts.orbitron(
                color: AdminTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          backgroundColor: AdminTheme.bgPrimary,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar
                SizedBox(
                  width: 300,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search archived projects...',
                      prefixIcon: const Icon(Icons.search, color: AdminTheme.textSecondary, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: const TextStyle(color: AdminTheme.textPrimary),
                  ),
                ),
                const SizedBox(height: 24),
                // Content
                if (archivedProjects.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.archive_outlined, size: 64, color: AdminTheme.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            'No archived projects',
                            style: GoogleFonts.rajdhani(
                              color: AdminTheme.textSecondary,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth > 1400 ? 4
                          : (constraints.maxWidth > 1000 ? 3
                          : (constraints.maxWidth > 600 ? 2 : 1));
                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                          itemCount: archivedProjects.length,
                          itemBuilder: (context, i) {
                            final p = archivedProjects[i];
                            final color = _categoryColors[p['templateName']] ?? _categoryColors['default']!;
                            return _ArchivedProjectCard(
                              project: p,
                              color: color,
                              onRestore: () => _showConfirm(context, p),
                              onDelete: () => _showDeleteConfirm(context, p),
                            );
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

  void _showConfirm(BuildContext context, Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgSecondary,
        title: const Text('Restore Project', style: TextStyle(color: AdminTheme.textPrimary)),
        content: const Text('Restore this project to the active projects list?', 
          style: TextStyle(color: AdminTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<AdminProvider>();
              final projectId = p['_id'].toString();
              
              // Call restore (which is unarchive - set status back to original)
              final success = await provider.unarchiveProject(projectId);
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Project restored successfully'),
                    backgroundColor: AdminTheme.accentGreen,
                  ),
                );
                // Refresh the list
                Provider.of<AdminProvider>(context, listen: false).fetchProjects();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to restore project'),
                    backgroundColor: AdminTheme.accentRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.accentGreen,
              foregroundColor: AdminTheme.bgPrimary,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgSecondary,
        title: const Text('Delete Project', style: TextStyle(color: AdminTheme.textPrimary)),
        content: const Text('Permanently delete this project? This cannot be undone.',
          style: TextStyle(color: AdminTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<AdminProvider>();
              final projectId = p['_id'].toString();
              
              final success = await provider.hideProject(projectId);
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Project deleted'),
                    backgroundColor: AdminTheme.accentGreen,
                  ),
                );
                Provider.of<AdminProvider>(context, listen: false).fetchProjects();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete project'),
                    backgroundColor: AdminTheme.accentRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.accentRed,
              foregroundColor: AdminTheme.bgPrimary,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ArchivedProjectCard extends StatelessWidget {
  final Map<String, dynamic> project;
  final Color color;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _ArchivedProjectCard({
    required this.project,
    required this.color,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = project['name']?.toString() ?? 'Unknown';
    final owner = project['ownerDisplay']?.toString() ?? 'Unknown';
    final template = project['templateName']?.toString() ?? 'Unknown';
    final platform = project['buildTarget']?.toString() ?? 'Unknown';
    final buildCount = project['buildCount'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.borderGlow, width: 0.5),
      ),
      child: Stack(
        children: [
          // Gradient overlay for archived
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  name,
                  style: GoogleFonts.orbitron(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AdminTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Owner & Template
                Text(
                  '$owner • $template',
                  style: GoogleFonts.rajdhani(
                    color: AdminTheme.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Platform & Builds
                Text(
                  '$platform • $buildCount builds',
                  style: GoogleFonts.jetBrainsMono(
                    color: AdminTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                // Archived badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AdminTheme.accentOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AdminTheme.accentOrange, width: 0.5),
                  ),
                  child: Text(
                    'Archived',
                    style: GoogleFonts.rajdhani(
                      color: AdminTheme.accentOrange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.restore, size: 18, color: AdminTheme.accentGreen),
                      onPressed: onRestore,
                      tooltip: 'Restore',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: AdminTheme.accentRed),
                      onPressed: onDelete,
                      tooltip: 'Delete',
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
}
