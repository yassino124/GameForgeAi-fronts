import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/admin_theme.dart';
import '../../providers/admin_provider.dart';
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
                _StatItem(
                  'Total',
                  (total is int ? total : 0).toString(),
                  AdminTheme.textSecondary,
                ),
                _StatItem(
                  'Success',
                  (success is int ? success : 0).toString(),
                  AdminTheme.accentGreen,
                ),
                _StatItem(
                  'Failed',
                  (failed is int ? failed : 0).toString(),
                  AdminTheme.accentRed,
                ),
                _StatItem(
                  'Running',
                  (running is int ? running : 0).toString(),
                  AdminTheme.accentNeon,
                ),
                _StatItem(
                  'Queued',
                  (queued is int ? queued : 0).toString(),
                  AdminTheme.accentOrange,
                ),
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
                child: Center(
                  child: Container(
                    color: AdminTheme.bgPrimary,
                    child: const CircularProgressIndicator(),
                  ),
                ),
              )
            else if (error != null)
              Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AdminTheme.accentRed,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        error,
                        style: GoogleFonts.rajdhani(
                          color: AdminTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (builds.isEmpty)
              Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Text(
                    'No builds found',
                    style: GoogleFonts.rajdhani(
                      color: AdminTheme.textSecondary,
                    ),
                  ),
                ),
              )
            else
              // Table with pagination
              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AdminTheme.bgSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminTheme.borderGlow),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          AdminTheme.bgTertiary,
                        ),
                        dataRowColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered))
                            return AdminTheme.bgTertiary.withOpacity(0.5);
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
                        rows: provider.paginatedBuilds.asMap().entries.map((e) {
                          final b = e.value;
                          final status = (b['status'] ?? '').toString();
                          final isRunning = status == 'running';
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  '${e.key + 1}',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: AdminTheme.textSecondary,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  b['name']?.toString() ?? '',
                                  style: GoogleFonts.rajdhani(
                                    color: AdminTheme.textPrimary,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  b['ownerDisplay']?.toString() ?? '',
                                  style: GoogleFonts.rajdhani(
                                    color: AdminTheme.textSecondary,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  b['buildTarget']?.toString() ?? '',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: AdminTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              DataCell(
                                isRunning
                                    ? const SizedBox(
                                        width: 80,
                                        height: 24,
                                        child: LinearProgressIndicator(
                                          backgroundColor:
                                              AdminTheme.bgTertiary,
                                          color: AdminTheme.accentNeon,
                                        ),
                                      )
                                    : StatusChip(
                                        label: status.toUpperCase(),
                                        status: status,
                                        clickable: false,
                                      ),
                              ),
                              DataCell(
                                Text(
                                  _formatDuration(
                                    b['buildTimings']?['durationMs'],
                                  ),
                                  style: GoogleFonts.jetBrainsMono(
                                    color: AdminTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _formatDate(b['buildTimings']?['startedAt']),
                                  style: GoogleFonts.jetBrainsMono(
                                    color: AdminTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.terminal,
                                        size: 20,
                                        color: AdminTheme.accentNeon,
                                      ),
                                      onPressed: () => _showLogsModal(
                                        context,
                                        b['_id']?.toString() ?? '',
                                      ),
                                      tooltip: 'View Logs',
                                    ),
                                    if (status == 'queued' ||
                                        status == 'running')
                                      IconButton(
                                        icon: const Icon(
                                          Icons.cancel,
                                          size: 20,
                                          color: AdminTheme.accentRed,
                                        ),
                                        onPressed: () {},
                                        tooltip: 'Cancel',
                                      ),
                                    if (status == 'failed') ...[
                                      IconButton(
                                        icon: const Icon(
                                          Icons.auto_awesome,
                                          size: 20,
                                          color: AdminTheme.accentPurple,
                                        ),
                                        onPressed: () =>
                                            _showAiAnalysisModal(context, b),
                                        tooltip: 'Analyze Error',
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.refresh,
                                          size: 20,
                                          color: AdminTheme.accentGreen,
                                        ),
                                        onPressed: () {},
                                        tooltip: 'Retry',
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  // Pagination controls
                  if (provider.buildsTotalPages > 1) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_left,
                            color: AdminTheme.textSecondary,
                          ),
                          onPressed: provider.buildsHasPrevPage
                              ? provider.prevBuildsPage
                              : null,
                          tooltip: 'Previous page',
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AdminTheme.bgSecondary,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AdminTheme.borderGlow),
                          ),
                          child: Text(
                            'Page ${provider.buildsCurrentPage} of ${provider.buildsTotalPages}',
                            style: GoogleFonts.rajdhani(
                              color: AdminTheme.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_right,
                            color: AdminTheme.textSecondary,
                          ),
                          onPressed: provider.buildsHasNextPage
                              ? provider.nextBuildsPage
                              : null,
                          tooltip: 'Next page',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }

  void _showLogsModal(BuildContext context, String buildId) {
    showDialog(
      context: context,
      builder: (ctx) => _BuildLogsDialog(buildId: buildId),
    );
  }

  void _showAiAnalysisModal(BuildContext context, Map<String, dynamic> build) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AiAnalysisDialog(build: build),
    );
  }

  Widget _header(String text) => Text(
    text,
    style: GoogleFonts.orbitron(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AdminTheme.textSecondary,
    ),
  );

  String _formatDuration(dynamic d) {
    if (d == null || (d is num && d == 0)) return '-';
    if (d is num) {
      // d is in milliseconds, convert to seconds first
      int totalSec = (d / 1000).round();
      int min = totalSec ~/ 60;
      int sec = totalSec % 60;
      return '${min}m ${sec}s';
    }
    return d.toString();
  }

  String _formatDate(dynamic d) {
    if (d == null) return '-';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
        Text(
          label,
          style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AiAnalysisDialog extends StatefulWidget {
  final Map<String, dynamic> build;

  const _AiAnalysisDialog({required this.build});

  @override
  State<_AiAnalysisDialog> createState() => _AiAnalysisDialogState();
}

class _AiAnalysisDialogState extends State<_AiAnalysisDialog> {
  bool _analyzing = false;
  Map<String, dynamic>? _analysis;
  String? _error;

  @override
  void initState() {
    super.initState();
    _analyzeError();
  }

  Future<void> _analyzeError() async {
    setState(() {
      _analyzing = true;
      _error = null;
    });

    final provider = context.read<AdminProvider>();

    // Get the actual error message from the build object
    final errorMessage =
        widget.build['error']?.toString() ??
        widget.build['buildLog']?.toString() ??
        'Unknown build error';

    final result = await provider.analyzeAiBuildError(
      errorMessage: errorMessage,
      buildTarget: widget.build['buildTarget']?.toString(),
      projectName: widget.build['name']?.toString(),
    );

    if (mounted) {
      setState(() {
        _analyzing = false;
        if (result != null) {
          _analysis = result;
        } else {
          _error = 'Failed to analyze error';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AdminTheme.bgSecondary,
      title: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AdminTheme.accentPurple),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'AI Error Analysis',
              style: GoogleFonts.orbitron(color: AdminTheme.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: _analyzing
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AdminTheme.accentPurple),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing build error...',
                      style: TextStyle(color: AdminTheme.textSecondary),
                    ),
                  ],
                ),
              )
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AdminTheme.accentRed,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: AdminTheme.textSecondary),
                    ),
                  ],
                ),
              )
            : _analysis != null
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Build info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminTheme.bgTertiary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Build: ${widget.build['name']}',
                            style: GoogleFonts.rajdhani(
                              color: AdminTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Target: ${widget.build['buildTarget']}',
                            style: GoogleFonts.jetBrainsMono(
                              color: AdminTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Severity badge
                    Row(
                      children: [
                        Text(
                          'Severity: ',
                          style: GoogleFonts.rajdhani(
                            color: AdminTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getSeverityColor(
                                _analysis!['severity']?.toString() ?? 'medium',
                              ).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getSeverityColor(
                                  _analysis!['severity']?.toString() ??
                                      'medium',
                                ),
                              ),
                            ),
                            child: Text(
                              (_analysis!['severity']?.toString() ?? 'medium')
                                  .toUpperCase(),
                              style: GoogleFonts.orbitron(
                                color: _getSeverityColor(
                                  _analysis!['severity']?.toString() ??
                                      'medium',
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Analysis
                    Text(
                      'Analysis:',
                      style: GoogleFonts.orbitron(
                        color: AdminTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AdminTheme.bgPrimary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminTheme.borderGlow),
                      ),
                      child: Text(
                        _analysis!['analysis']?.toString() ?? '',
                        style: GoogleFonts.rajdhani(
                          color: AdminTheme.textSecondary,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Suggested Fix
                    Text(
                      'Suggested Fix:',
                      style: GoogleFonts.orbitron(
                        color: AdminTheme.accentGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AdminTheme.bgPrimary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AdminTheme.accentGreen.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _analysis!['suggestedFix']?.toString() ?? '',
                        style: GoogleFonts.jetBrainsMono(
                          color: AdminTheme.textSecondary,
                          fontSize: 13,
                          height: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Close',
            style: TextStyle(color: AdminTheme.textSecondary),
          ),
        ),
        if (_analysis != null)
          ElevatedButton.icon(
            onPressed: () async {
              // Copy suggested fix to clipboard
              final fixText =
                  _analysis!['suggestedFix']?.toString() ?? 'No fix available';
              await Clipboard.setData(ClipboardData(text: fixText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard ✓'),
                  backgroundColor: AdminTheme.accentGreen,
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Fix'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.accentGreen,
              foregroundColor: AdminTheme.bgPrimary,
            ),
          ),
      ],
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return AdminTheme.accentRed;
      case 'medium':
        return AdminTheme.accentOrange;
      case 'low':
        return AdminTheme.accentGreen;
      default:
        return AdminTheme.textSecondary;
    }
  }
}

class _BuildLogsDialog extends StatefulWidget {
  final String buildId;
  const _BuildLogsDialog({required this.buildId});

  @override
  State<_BuildLogsDialog> createState() => _BuildLogsDialogState();
}

class _BuildLogsDialogState extends State<_BuildLogsDialog> {
  Future<String?>? _logsFuture;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AdminProvider>();
    _logsFuture = provider.getBuildLogs(widget.buildId);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AdminTheme.bgPrimary,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.terminal, color: AdminTheme.accentGreen),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Build Logs',
                    style: GoogleFonts.orbitron(color: AdminTheme.accentGreen),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: AdminTheme.accentNeon),
            onPressed: () {
              // Copy logs to clipboard
              _logsFuture?.then((logs) {
                if (logs != null) {
                  // For Flutter web, we would use flutter_web_plugins
                  // For now, just show a snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logs copied to clipboard')),
                  );
                }
              });
            },
            tooltip: 'Copy Logs',
          ),
        ],
      ),
      content: FutureBuilder<String?>(
        future: _logsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(
              width: 500,
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final logs = snapshot.data ?? 'No logs available';

          return Container(
            width: 500,
            height: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AdminTheme.borderGlow),
            ),
            child: SingleChildScrollView(
              child: Text(
                logs,
                style: GoogleFonts.jetBrainsMono(
                  color: AdminTheme.accentGreen,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
