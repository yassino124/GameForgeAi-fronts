import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/admin_theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/status_badge.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                    width: (constraints.maxWidth > 1200 ? (constraints.maxWidth - 60) / 4 : constraints.maxWidth > 768 ? (constraints.maxWidth - 40) / 2 : constraints.maxWidth) - 20,
                    child: StatCard(
                      title: 'Total Users',
                      value: '1,247',
                      change: '+12%',
                      iconColor: AdminTheme.accentNeon,
                      icon: Icons.people,
                    ),
                  ),
                  SizedBox(
                    width: (constraints.maxWidth > 1200 ? (constraints.maxWidth - 60) / 4 : constraints.maxWidth > 768 ? (constraints.maxWidth - 40) / 2 : constraints.maxWidth) - 20,
                    child: StatCard(
                      title: 'Active Projects',
                      value: '389',
                      change: '+8%',
                      iconColor: AdminTheme.accentPurple,
                      icon: Icons.gamepad,
                    ),
                  ),
                  SizedBox(
                    width: (constraints.maxWidth > 1200 ? (constraints.maxWidth - 60) / 4 : constraints.maxWidth > 768 ? (constraints.maxWidth - 40) / 2 : constraints.maxWidth) - 20,
                    child: StatCard(
                      title: 'Templates',
                      value: '56',
                      change: '+3',
                      iconColor: AdminTheme.accentGreen,
                      icon: Icons.store,
                    ),
                  ),
                  SizedBox(
                    width: (constraints.maxWidth > 1200 ? (constraints.maxWidth - 60) / 4 : constraints.maxWidth > 768 ? (constraints.maxWidth - 40) / 2 : constraints.maxWidth) - 20,
                    child: StatCard(
                      title: 'Builds Today',
                      value: '142',
                      change: '-5%',
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
          // Charts row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1000;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 40) / 2 : constraints.maxWidth,
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
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 40) / 2 : constraints.maxWidth,
                    child: PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Builds per Day',
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
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 40) / 2 : constraints.maxWidth,
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
                    width: isWide ? (constraints.maxWidth - 40) / 2 : constraints.maxWidth,
                    child: _RecentActivityTable(),
                  ),
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 40) / 2 : constraints.maxWidth,
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
          ...AdminMockData.recentActivity.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                StatusBadge(status: a['status']?.toString() ?? 'success'),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    a['detail']?.toString() ?? '',
                    style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatTime(a['timestamp']?.toString()),
                  style: GoogleFonts.jetBrainsMono(color: AdminTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          )),
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
          ...AdminMockData.systemStatus.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (s['status'] == 'online') ? AdminTheme.accentGreen : AdminTheme.accentOrange,
                    boxShadow: [
                      BoxShadow(
                        color: ((s['status'] == 'online') ? AdminTheme.accentGreen : AdminTheme.accentOrange).withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  s['name']?.toString() ?? '',
                  style: GoogleFonts.rajdhani(color: AdminTheme.textPrimary, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  s['detail']?.toString() ?? '',
                  style: GoogleFonts.jetBrainsMono(color: AdminTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
