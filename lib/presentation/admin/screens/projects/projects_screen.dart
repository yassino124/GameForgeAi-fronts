import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/admin_theme.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/status_chip.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  static const _categoryColors = {
    'Platformer': AdminTheme.accentNeon,
    'Shooter': AdminTheme.accentRed,
    'RPG': AdminTheme.accentPurple,
    'Puzzle': AdminTheme.accentGreen,
    'Racing': AdminTheme.accentOrange,
    'Strategy': AdminTheme.accentPurple,
    'default': AdminTheme.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        final projects = provider.filteredProjects;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toolbar
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 250,
                  child: TextField(
                    onChanged: provider.setProjectsSearch,
                    decoration: InputDecoration(
                      hintText: 'Search projects...',
                      prefixIcon: const Icon(Icons.search, color: AdminTheme.textSecondary, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: const TextStyle(color: AdminTheme.textPrimary),
                  ),
                ),
                DropdownButton<String>(
                  value: provider.projectsStatusFilter,
                  dropdownColor: AdminTheme.bgSecondary,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                    DropdownMenuItem(value: 'published', child: Text('Published')),
                    DropdownMenuItem(value: 'archived', child: Text('Archived')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                  ],
                  onChanged: (v) => provider.setProjectsStatusFilter(v ?? 'all'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 1400 ? 4 : (constraints.maxWidth > 1000 ? 3 : (constraints.maxWidth > 600 ? 2 : 1));
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: projects.length,
                  itemBuilder: (context, i) {
                    final p = projects[i];
                    final color = _categoryColors[p['template']] ?? _categoryColors['default']!;
                    return _ProjectCard(
                      project: p,
                      color: color,
                      onView: () => _showProjectDetail(context, p),
                      onArchive: () => _showConfirm(context, 'Archive', 'Archive this project?', p),
                      onDelete: () => _showConfirm(context, 'Delete', 'Delete this project permanently?', p),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showProjectDetail(BuildContext context, Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgSecondary,
        title: Text(p['title']?.toString() ?? '', style: const TextStyle(color: AdminTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DialogRow('Owner', p['owner']?.toString() ?? ''),
              _DialogRow('Template', p['template']?.toString() ?? ''),
              _DialogRow('Status', p['status']?.toString() ?? ''),
              _DialogRow('Platform', p['platform']?.toString() ?? ''),
              _DialogRow('Builds', p['buildCount']?.toString() ?? '0'),
              _DialogRow('Created', _formatDate(p['createdAt'])),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showConfirm(BuildContext context, String action, String message, Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgSecondary,
        title: Text('$action Project', style: const TextStyle(color: AdminTheme.textPrimary)),
        content: Text(message, style: const TextStyle(color: AdminTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$action requested for ${p['title']}'), backgroundColor: AdminTheme.accentGreen));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'Delete' ? AdminTheme.accentRed : AdminTheme.accentNeon,
              foregroundColor: AdminTheme.bgPrimary,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic d) {
    if (d == null) return '-';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return d.toString();
    }
  }
}

class _ProjectCard extends StatefulWidget {
  final Map<String, dynamic> project;
  final Color color;
  final VoidCallback onView;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _ProjectCard({required this.project, required this.color, required this.onView, required this.onArchive, required this.onDelete});

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    final status = (p['status'] ?? '').toString();
    final isArchived = status == 'archived';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: AdminTheme.bgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminTheme.borderGlow),
          boxShadow: _hovered ? [BoxShadow(color: widget.color.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.color.withOpacity(0.4), widget.color.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Center(child: Icon(Icons.folder_special, size: 48, color: AdminTheme.textMuted)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['title']?.toString() ?? 'Untitled',
                      style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(p['owner']?.toString() ?? '', style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    StatusChip(label: status.replaceAll('_', ' '), status: status, clickable: false, color: AdminTheme.statusColor(status)),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(icon: const Icon(Icons.visibility, size: 18, color: AdminTheme.accentNeon), onPressed: widget.onView, tooltip: 'View'),
                        IconButton(
                          icon: Icon(isArchived ? Icons.restore : Icons.archive, size: 18, color: AdminTheme.accentPurple),
                          onPressed: widget.onArchive,
                          tooltip: isArchived ? 'Restore' : 'Archive',
                        ),
                        IconButton(icon: const Icon(Icons.delete, size: 18, color: AdminTheme.accentRed), onPressed: widget.onDelete, tooltip: 'Delete'),
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
}

class _DialogRow extends StatelessWidget {
  final String label;
  final String value;

  const _DialogRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary)),
          Text(value, style: GoogleFonts.rajdhani(color: AdminTheme.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
