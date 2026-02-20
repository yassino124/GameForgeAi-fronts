import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/admin_theme.dart';
import '../../providers/admin_provider.dart';
import '../../data/mock_data.dart';
import '../../widgets/status_chip.dart';

class BuildsScreen extends StatelessWidget {
  const BuildsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        final builds = provider.filteredBuilds;
        final total = builds.length;
        final success = builds.where((b) => b['status'] == 'success').length;
        final failed = builds.where((b) => b['status'] == 'failed').length;
        final running = builds.where((b) => b['status'] == 'running').length;
        final queued = builds.where((b) => b['status'] == 'queued').length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats bar
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _StatItem('Total', total.toString(), AdminTheme.textSecondary),
                _StatItem('Success', success.toString(), AdminTheme.accentGreen),
                _StatItem('Failed', failed.toString(), AdminTheme.accentRed),
                _StatItem('Running', running.toString(), AdminTheme.accentNeon),
                _StatItem('Queued', queued.toString(), AdminTheme.accentOrange),
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
                    DropdownMenuItem(value: 'success', child: Text('Success')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (v) => provider.setBuildsStatusFilter(v ?? 'all'),
                ),
              ],
            ),
            const SizedBox(height: 24),
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
                        DataCell(Text(b['projectName']?.toString() ?? '', style: GoogleFonts.rajdhani(color: AdminTheme.textPrimary))),
                        DataCell(Text(b['owner']?.toString() ?? '', style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary))),
                        DataCell(Text(b['platform']?.toString() ?? '', style: GoogleFonts.jetBrainsMono(color: AdminTheme.textSecondary, fontSize: 12))),
                        DataCell(isRunning
                            ? const SizedBox(width: 80, height: 24, child: LinearProgressIndicator(backgroundColor: AdminTheme.bgTertiary, color: AdminTheme.accentNeon))
                            : StatusChip(label: status.toUpperCase(), status: status, clickable: false)),
                        DataCell(Text(_formatDuration(b['duration']), style: GoogleFonts.jetBrainsMono(color: AdminTheme.textSecondary, fontSize: 12))),
                        DataCell(Text(_formatDate(b['startedAt']), style: GoogleFonts.jetBrainsMono(color: AdminTheme.textSecondary, fontSize: 12))),
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
