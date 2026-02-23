import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/admin_theme.dart';
import '../../providers/admin_provider.dart';
import '../../data/mock_data.dart';
import '../../widgets/status_chip.dart';

class BuildsScreen extends StatefulWidget {
  const BuildsScreen({super.key});

  @override
  State<BuildsScreen> createState() => _BuildsScreenState();
}

class _BuildsScreenState extends State<BuildsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchBuilds();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        final builds = provider.filteredBuilds;
        final summary = provider.buildsSummary;
        final total = summary['total'] ?? 0;
        final success = summary['success'] ?? 0;
        final failed = summary['failed'] ?? 0;
        final running = summary['running'] ?? 0;
        final queued = summary['queued'] ?? 0;
        final loading = provider.buildsLoading;
        final error = provider.buildsError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats bar
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _StatItem('Total', (total is int ? total : 0).toString(), AdminTheme.textSecondary),
                _StatItem('Success', (success is int ? success : 0).toString(), AdminTheme.accentGreen),
                _StatItem('Failed', (failed is int ? failed : 0).toString(), AdminTheme.accentRed),
                _StatItem('Running', (running is int ? running : 0).toString(), AdminTheme.accentNeon),
                _StatItem('Queued', (queued is int ? queued : 0).toString(), AdminTheme.accentOrange),
              ],
            ),
            const SizedBox(height: 24),
            // Filters
            Wrap(
              spacing: 12,
              children: [
                DropdownButton<String>(
                  value: provider.buildsStatusFilter,
                  dropdownColor: AdminTheme.bgSecondary,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'queued', child: Text('Queued')),
                    DropdownMenuItem(value: 'running', child: Text('Running')),
                    DropdownMenuItem(value: 'ready', child: Text('Ready')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                  ],
                  onChanged: (v) => provider.setBuildsStatusFilter(v ?? 'all'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Loading/Error/Empty states
            if (loading)
              Padding(
                padding: const EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AdminTheme.accentRed),
                      const SizedBox(height: 16),
                      Text(error, style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary)),
                    ],
                  ),
                ),
              )
            else if (builds.isEmpty)
              Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Text('No builds found', style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary)),
                ),
              )
            else
            // Table
            Container(
              decoration: BoxDecoration(
                color: AdminTheme.bgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminTheme.borderGlow),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AdminTheme.bgTertiary),
                  dataRowColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) return AdminTheme.bgTertiary.withOpacity(0.5);
                    return Colors.transparent;
                  }),
                  columns: [
                    DataColumn(label: _header('#')),
                    DataColumn(label: _header('Project')),
                    DataColumn(label: _header('Owner')),
                    DataColumn(label: _header('Platform')),
                    DataColumn(label: _header('Status')),
                    DataColumn(label: _header('Duration')),
                    DataColumn(label: _header('Started')),
                    DataColumn(label: _header('Actions')),
                  ],
                  rows: builds.take(40).toList().asMap().entries.map((e) {
                    final b = e.value;
                    final status = (b['status'] ?? '').toString();
                    final isRunning = status == 'running';
                    return DataRow(
                      cells: [
                        DataCell(Text('${e.key + 1}', style: GoogleFonts.jetBrainsMono(color: AdminTheme.textSecondary))),
                        DataCell(Text(b['name']?.toString() ?? '', style: GoogleFonts.rajdhani(color: AdminTheme.textPrimary))),
                        DataCell(Text(b['ownerDisplay']?.toString() ?? '', style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary))),
                        DataCell(Text(b['buildTarget']?.toString() ?? '', style: GoogleFonts.jetBrainsMono(color: AdminTheme.textSecondary, fontSize: 12))),
                        DataCell(isRunning
                            ? const SizedBox(width: 80, height: 24, child: LinearProgressIndicator(backgroundColor: AdminTheme.bgTertiary, color: AdminTheme.accentNeon))
                            : StatusChip(label: status.toUpperCase(), status: status, clickable: false)),
                        DataCell(Text(_formatDuration(b['buildTimings']?['durationMs']), style: GoogleFonts.jetBrainsMono(color: AdminTheme.textSecondary, fontSize: 12))),
                        DataCell(Text(_formatDate(b['buildTimings']?['startedAt']), style: GoogleFonts.jetBrainsMono(color: AdminTheme.textSecondary, fontSize: 12))),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.terminal, size: 20, color: AdminTheme.accentNeon),
                              onPressed: () => _showLogsModal(context),
                              tooltip: 'View Logs',
                            ),
                            if (status == 'queued' || status == 'running')
                              IconButton(icon: const Icon(Icons.cancel, size: 20, color: AdminTheme.accentRed), onPressed: () {}, tooltip: 'Cancel'),
                            if (status == 'failed')
                              IconButton(icon: const Icon(Icons.refresh, size: 20, color: AdminTheme.accentGreen), onPressed: () {}, tooltip: 'Retry'),
                          ],
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLogsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgPrimary,
        title: Row(
          children: [
            const Icon(Icons.terminal, color: AdminTheme.accentGreen),
            const SizedBox(width: 12),
            Text('Build Logs', style: GoogleFonts.orbitron(color: AdminTheme.accentGreen)),
          ],
        ),
        content: Container(
          width: 500,
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminTheme.borderGlow),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: AdminMockData.mockBuildLogs.map((log) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(log, style: GoogleFonts.jetBrainsMono(color: AdminTheme.accentGreen, fontSize: 12)),
              )).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _header(String text) => Text(
    text,
    style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.textSecondary),
  );

  String _formatDuration(dynamic d) {
    if (d == null || (d is num && d == 0)) return '-';
    if (d is num) {
      final m = (d / 60).floor();
      final s = (d % 60).round();
      return '${m}m ${s}s';
    }
    return d.toString();
  }

  String _formatDate(dynamic d) {
    if (d == null) return '-';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return d.toString();
    }
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary)),
        const SizedBox(width: 8),
        Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
