import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../constants/admin_theme.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/status_badge.dart' hide CircularProgressIndicator;
import '../../providers/admin_provider.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchDashboard();
      context.read<AdminProvider>().fetchRecentActivity();
      context.read<AdminProvider>().fetchSystemStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();
    final dashboardData = adminProvider.dashboardData?['dashboard'] ?? {};
    final totalUsers = dashboardData['totalUsers'] ?? 1247;
    final totalUsersChange = dashboardData['totalUsersChange'] ?? '+12%';
    final activeProjects = dashboardData['activeProjects'] ?? 0;
    final totalTemplates = dashboardData['totalTemplates'] ?? 0;
    final buildsToday = dashboardData['buildsToday'] ?? 0;
    final newUsersData = dashboardData['newUsersLast30Days'] as List? ?? [];
    final buildsLast30Days = dashboardData['buildsLast30Days'] as List? ?? [];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Cards
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  SizedBox(
                    width:
                        (constraints.maxWidth > 1200
                            ? (constraints.maxWidth - 60) / 4
                            : constraints.maxWidth > 768
                            ? (constraints.maxWidth - 40) / 2
                            : constraints.maxWidth) -
                        20,
                    child: StatCard(
                      title: 'Total Users',
                      value: totalUsers.toString(),
                      change: totalUsersChange,
                      iconColor: AdminTheme.accentNeon,
                      icon: Icons.people,
                    ),
                  ),
                  SizedBox(
                    width:
                        (constraints.maxWidth > 1200
                            ? (constraints.maxWidth - 60) / 4
                            : constraints.maxWidth > 768
                            ? (constraints.maxWidth - 40) / 2
                            : constraints.maxWidth) -
                        20,
                    child: StatCard(
                      title: 'Active Projects',
                      value: activeProjects.toString(),
                      change: '',
                      iconColor: AdminTheme.accentPurple,
                      icon: Icons.gamepad,
                    ),
                  ),
                  SizedBox(
                    width:
                        (constraints.maxWidth > 1200
                            ? (constraints.maxWidth - 60) / 4
                            : constraints.maxWidth > 768
                            ? (constraints.maxWidth - 40) / 2
                            : constraints.maxWidth) -
                        20,
                    child: StatCard(
                      title: 'Templates',
                      value: totalTemplates.toString(),
                      change: '',
                      iconColor: AdminTheme.accentGreen,
                      icon: Icons.store,
                    ),
                  ),
                  SizedBox(
                    width:
                        (constraints.maxWidth > 1200
                            ? (constraints.maxWidth - 60) / 4
                            : constraints.maxWidth > 768
                            ? (constraints.maxWidth - 40) / 2
                            : constraints.maxWidth) -
                        20,
                    child: StatCard(
                      title: 'Builds Today',
                      value: buildsToday.toString(),
                      change: '',
                      isPositive: false,
                      iconColor: AdminTheme.accentOrange,
                      icon: Icons.build,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          // AI Insights Card
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: constraints.maxWidth,
                child: _AiInsightsCard(),
              );
            },
          ),
          const SizedBox(height: 32),
          // Health Monitor Card
          LayoutBuilder(
            builder: (context, constraints) {
              return Consumer<AdminProvider>(
                builder: (context, provider, _) {
                  return SizedBox(
                    width: constraints.maxWidth,
                    child: _HealthMonitorCard(
                      healthData: provider.healthMetrics,
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),
          // Charts row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1000;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  SizedBox(
                    width: isWide
                        ? (constraints.maxWidth - 40) / 2
                        : constraints.maxWidth,
                    child: PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Users Last 30 Days',
                            style: GoogleFonts.orbitron(
                              color: AdminTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 200,
                            child: newUsersData.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No data available',
                                      style: TextStyle(
                                        color: AdminTheme.textSecondary,
                                      ),
                                    ),
                                  )
                                : LineChart(
                                    LineChartData(
                                      gridData: FlGridData(
                                        show: true,
                                        getDrawingHorizontalLine: (value) =>
                                            FlLine(
                                              color: AdminTheme.borderGlow
                                                  .withOpacity(0.3),
                                              strokeWidth: 1,
                                            ),
                                        getDrawingVerticalLine: (value) =>
                                            FlLine(
                                              color: AdminTheme.borderGlow
                                                  .withOpacity(0.3),
                                              strokeWidth: 1,
                                            ),
                                      ),
                                      titlesData: FlTitlesData(
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 22,
                                            interval: 7,
                                            getTitlesWidget: (value, meta) {
                                              final index = value.toInt();
                                              if (index < 0 ||
                                                  index >=
                                                      newUsersData.length) {
                                                return const Text('');
                                              }
                                              final date =
                                                  newUsersData[index]['_id']
                                                      as String;
                                              return Text(
                                                date.substring(5),
                                                style: const TextStyle(
                                                  color:
                                                      AdminTheme.textSecondary,
                                                  fontSize: 10,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            interval: 1,
                                            getTitlesWidget: (value, meta) {
                                              return Text(
                                                value.toInt().toString(),
                                                style: const TextStyle(
                                                  color:
                                                      AdminTheme.textSecondary,
                                                  fontSize: 10,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(
                                        show: true,
                                        border: Border.all(
                                          color: AdminTheme.borderGlow
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: newUsersData
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                                return FlSpot(
                                                  entry.key.toDouble(),
                                                  (entry.value['count'] as num)
                                                      .toDouble(),
                                                );
                                              })
                                              .toList(),
                                          isCurved: true,
                                          color: AdminTheme.accentNeon,
                                          barWidth: 3,
                                          isStrokeCapRound: true,
                                          dotData: FlDotData(
                                            show: true,
                                            getDotPainter:
                                                (
                                                  spot,
                                                  percent,
                                                  barData,
                                                  index,
                                                ) {
                                                  return FlDotCirclePainter(
                                                    radius: 4,
                                                    color:
                                                        AdminTheme.accentNeon,
                                                    strokeColor:
                                                        AdminTheme.bgPrimary,
                                                    strokeWidth: 2,
                                                  );
                                                },
                                          ),
                                        ),
                                      ],
                                      minY: 0,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: isWide
                        ? (constraints.maxWidth - 40) / 2
                        : constraints.maxWidth,
                    child: PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Builds Last 30 Days',
                            style: GoogleFonts.orbitron(
                              color: AdminTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 200,
                            child: buildsLast30Days.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No data available',
                                      style: TextStyle(
                                        color: AdminTheme.textSecondary,
                                      ),
                                    ),
                                  )
                                : LineChart(
                                    LineChartData(
                                      gridData: FlGridData(
                                        show: true,
                                        getDrawingHorizontalLine: (value) =>
                                            FlLine(
                                              color: AdminTheme.borderGlow
                                                  .withOpacity(0.3),
                                              strokeWidth: 1,
                                            ),
                                        getDrawingVerticalLine: (value) =>
                                            FlLine(
                                              color: AdminTheme.borderGlow
                                                  .withOpacity(0.3),
                                              strokeWidth: 1,
                                            ),
                                      ),
                                      titlesData: FlTitlesData(
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 22,
                                            interval: 7,
                                            getTitlesWidget: (value, meta) {
                                              final index = value.toInt();
                                              if (index < 0 ||
                                                  index >=
                                                      buildsLast30Days.length) {
                                                return const Text('');
                                              }
                                              final date =
                                                  buildsLast30Days[index]['_id']
                                                      as String;
                                              return Text(
                                                date.substring(5),
                                                style: const TextStyle(
                                                  color:
                                                      AdminTheme.textSecondary,
                                                  fontSize: 10,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            interval: 1,
                                            getTitlesWidget: (value, meta) {
                                              return Text(
                                                value.toInt().toString(),
                                                style: const TextStyle(
                                                  color:
                                                      AdminTheme.textSecondary,
                                                  fontSize: 10,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(
                                        show: true,
                                        border: Border.all(
                                          color: AdminTheme.borderGlow
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: buildsLast30Days
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                                return FlSpot(
                                                  entry.key.toDouble(),
                                                  (entry.value['count'] as num)
                                                      .toDouble(),
                                                );
                                              })
                                              .toList(),
                                          isCurved: true,
                                          color: AdminTheme.accentOrange,
                                          barWidth: 3,
                                          isStrokeCapRound: true,
                                          dotData: FlDotData(
                                            show: true,
                                            getDotPainter:
                                                (
                                                  spot,
                                                  percent,
                                                  barData,
                                                  index,
                                                ) {
                                                  return FlDotCirclePainter(
                                                    radius: 4,
                                                    color:
                                                        AdminTheme.accentOrange,
                                                    strokeColor:
                                                        AdminTheme.bgPrimary,
                                                    strokeWidth: 2,
                                                  );
                                                },
                                          ),
                                        ),
                                      ],
                                      minY: 0,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: isWide
                        ? (constraints.maxWidth - 40) / 2
                        : constraints.maxWidth,
                    child: PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subscription Distribution',
                            style: GoogleFonts.orbitron(
                              color: AdminTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: AdminTheme.bgTertiary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'Chart Component\n(To be implemented)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AdminTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          // Recent Activity + System Status
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  SizedBox(
                    width: isWide
                        ? (constraints.maxWidth - 40) / 2
                        : constraints.maxWidth,
                    child: _RecentActivityTable(),
                  ),
                  SizedBox(
                    width: isWide
                        ? (constraints.maxWidth - 40) / 2
                        : constraints.maxWidth,
                    child: _SystemStatusCard(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecentActivityTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();
    final activities = adminProvider.recentActivity;
    final loading = adminProvider.activityLoading;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.borderGlow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: GoogleFonts.orbitron(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AdminTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No recent activity',
                style: TextStyle(color: AdminTheme.textSecondary),
              ),
            )
          else
            ...activities.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    StatusBadge(status: a['type']?.toString() ?? 'info'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        a['title']?.toString() ?? '',
                        style: GoogleFonts.rajdhani(
                          color: AdminTheme.textSecondary,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatTime(a['timestamp']?.toString()),
                      style: GoogleFonts.jetBrainsMono(
                        color: AdminTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(String? ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }
}

class _SystemStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();
    final statuses = adminProvider.systemStatus;
    final loading = adminProvider.systemStatusLoading;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.borderGlow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Status',
            style: GoogleFonts.orbitron(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AdminTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else if (statuses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No system status available',
                style: TextStyle(color: AdminTheme.textSecondary),
              ),
            )
          else
            ...statuses.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (s['status'] == 'online')
                            ? AdminTheme.accentGreen
                            : AdminTheme.accentOrange,
                        boxShadow: [
                          BoxShadow(
                            color:
                                ((s['status'] == 'online')
                                        ? AdminTheme.accentGreen
                                        : AdminTheme.accentOrange)
                                    .withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s['name']?.toString() ?? '',
                        style: GoogleFonts.rajdhani(
                          color: AdminTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      s['detail']?.toString() ?? '',
                      style: GoogleFonts.jetBrainsMono(
                        color: AdminTheme.textSecondary,
                        fontSize: 12,
                      ),
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

class _AiInsightsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();
    final summary = adminProvider.aiInsightsSummary;
    final loading = adminProvider.aiInsightsLoading;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'AI Insights',
                  style: GoogleFonts.orbitron(
                    color: AdminTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: loading
                    ? null
                    : () {
                        context.read<AdminProvider>().generateAiInsights();
                      },
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.accentNeon,
                  foregroundColor: AdminTheme.bgPrimary,
                  disabledBackgroundColor: AdminTheme.borderGlow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (summary.isEmpty && !loading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Click "Refresh" to generate platform insights',
                style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary),
              ),
            )
          else
            Text(
              summary,
              style: GoogleFonts.rajdhani(
                color: AdminTheme.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }
}

class _HealthMonitorCard extends StatefulWidget {
  final Map<String, dynamic>? healthData;
  const _HealthMonitorCard({this.healthData});

  @override
  State<_HealthMonitorCard> createState() => _HealthMonitorCardState();
}

class _HealthMonitorCardState extends State<_HealthMonitorCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchHealthMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        final health = widget.healthData ?? {};
        final loading = provider.healthLoading;

        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.health_and_safety,
                          color: AdminTheme.accentGreen,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Platform Health',
                            style: GoogleFonts.orbitron(
                              color: AdminTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!loading)
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: AdminTheme.accentNeon,
                        size: 20,
                      ),
                      onPressed: () => provider.fetchHealthMetrics(),
                      tooltip: 'Refresh',
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (loading)
                const Center(child: CircularProgressIndicator())
              else if (health.isEmpty)
                Center(
                  child: Text(
                    'No health data available',
                    style: GoogleFonts.rajdhani(
                      color: AdminTheme.textSecondary,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    _HealthMetric(
                      label: 'Build Success Rate',
                      value:
                          '${(health['buildSuccessRate'] as num?)?.toStringAsFixed(1) ?? '-'}%',
                      icon: Icons.trending_up,
                      color: AdminTheme.accentGreen,
                    ),
                    _HealthMetric(
                      label: 'Avg Build Time',
                      value:
                          '${((health['avgBuildTimeMs'] as num?)?.toInt() ?? 0) ~/ 60}m',
                      icon: Icons.timer,
                      color: AdminTheme.accentOrange,
                    ),
                    _HealthMetric(
                      label: 'Failed Last Hour',
                      value: '${health['failedBuildsLastHour'] ?? 0}',
                      icon: Icons.warning,
                      color:
                          ((health['failedBuildsLastHour'] as num?)?.toInt() ??
                                  0) >
                              3
                          ? AdminTheme.accentRed
                          : AdminTheme.accentGreen,
                    ),
                    _HealthMetric(
                      label: 'System Uptime',
                      value: '${health['systemUptimeHours'] ?? '-'}h',
                      icon: Icons.cloud_done,
                      color: AdminTheme.accentNeon,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HealthMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _HealthMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.orbitron(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.rajdhani(
            color: AdminTheme.textSecondary,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
