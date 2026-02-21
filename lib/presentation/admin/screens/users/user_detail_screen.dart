import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/admin_users_service.dart';
import '../../constants/admin_theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/admin_button.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;

  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Not authenticated';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _user = null;
    });
    final res = await AdminUsersService.getUser(widget.userId, token);
    if (!mounted) return;
    if (res['success'] == true && res['data'] != null) {
      setState(() {
        _user = Map<String, dynamic>.from(res['data'] is Map ? res['data'] as Map : {});
        _loading = false;
        _error = null;
      });
    } else {
      setState(() {
        _user = null;
        _loading = false;
        _error = res['message']?.toString() ?? 'User not found';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _user == null) {
      return const Center(child: CircularProgressIndicator(color: AdminTheme.accentNeon));
    }

    if (_error != null && _user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off, size: 64, color: AdminTheme.textMuted),
            const SizedBox(height: 16),
            Text(_error!, style: GoogleFonts.orbitron(color: AdminTheme.textSecondary)),
            const SizedBox(height: 24),
            AdminButton(label: 'Back to Users', icon: Icons.arrow_back, onPressed: () => context.go('/admin/users')),
          ],
        ),
      );
    }

    final user = _user ?? {};
    final status = (user['status'] ?? (user['isActive'] == true ? 'active' : 'suspended')).toString();
    final isActive = status == 'active';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column - Profile
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AdminTheme.bgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminTheme.borderGlow),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AdminTheme.accentNeon, width: 3),
                      boxShadow: [BoxShadow(color: AdminTheme.accentNeon.withOpacity(0.3), blurRadius: 20)],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: AdminTheme.accentPurple.withOpacity(0.3),
                      child: Text(
                        (user['username'] ?? '?')[0].toUpperCase(),
                        style: GoogleFonts.orbitron(fontSize: 48, fontWeight: FontWeight.bold, color: AdminTheme.accentPurple),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  user['fullName']?.toString() ?? user['username']?.toString() ?? 'Unknown',
                  style: GoogleFonts.orbitron(fontSize: 22, fontWeight: FontWeight.bold, color: AdminTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(user['email']?.toString() ?? '', style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary)),
                const SizedBox(height: 16),
                _InfoRow(label: 'Role', value: (user['role'] ?? '').toString().toUpperCase()),
                _InfoRow(label: 'Plan', value: (user['subscription'] ?? '').toString().toUpperCase()),
                _InfoRow(label: 'Joined', value: _formatDate(user['createdAt'])),
                _InfoRow(label: 'Last Login', value: _formatDate(user['lastLogin'])),
                if ((user['bio'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Bio', style: GoogleFonts.orbitron(fontSize: 12, color: AdminTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(user['bio']?.toString() ?? '', style: GoogleFonts.rajdhani(color: AdminTheme.textPrimary)),
                ],
                if ((user['location'] ?? '').toString().isNotEmpty) _InfoRow(label: 'Location', value: user['location']?.toString() ?? ''),
                if ((user['website'] ?? '').toString().isNotEmpty) _InfoRow(label: 'Website', value: user['website']?.toString() ?? ''),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    AdminButton(label: 'Change Role', icon: Icons.admin_panel_settings, outlined: true, onPressed: () => _showConfirmDialog(context, 'Change Role', 'Are you sure you want to change this user\'s role?')),
                    AdminButton(label: 'Change Plan', icon: Icons.card_membership, outlined: true, onPressed: () => _showConfirmDialog(context, 'Change Plan', 'Are you sure you want to change this user\'s subscription plan?')),
                    if (isActive) ...[
                      AdminButton(label: 'Suspend Account', icon: Icons.block, outlined: true, color: AdminTheme.accentOrange, onPressed: () => _performStatusChange(context, 'suspended', 'Suspend Account', 'This will prevent the user from accessing the platform.')),
                      AdminButton(label: 'Ban Account', icon: Icons.block, outlined: true, color: AdminTheme.accentRed, onPressed: () => _performStatusChange(context, 'banned', 'Ban Account', 'The user will be permanently banned.')),
                    ] else
                      AdminButton(label: 'Reactivate Account', icon: Icons.play_circle, outlined: true, color: AdminTheme.accentGreen, onPressed: () => _performStatusChange(context, 'active', 'Reactivate Account', 'Restore user access.')),
                    AdminButton(label: 'Delete Account', icon: Icons.delete, outlined: true, color: AdminTheme.accentRed, onPressed: () => _performDelete(context)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Right column - Activity
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AdminTheme.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminTheme.borderGlow),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Projects', style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary)),
                    const SizedBox(height: 16),
                    ...AdminMockData.mockProjects.where((p) => p['owner'] == user['username']).take(5).map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(p['title']?.toString() ?? '', style: GoogleFonts.rajdhani(color: AdminTheme.textPrimary))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AdminTheme.statusColor(p['status']?.toString() ?? '').withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text((p['status'] ?? '').toString(), style: GoogleFonts.rajdhani(color: AdminTheme.statusColor(p['status']?.toString() ?? ''), fontSize: 12)),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AdminTheme.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminTheme.borderGlow),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent Activity', style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary)),
                    const SizedBox(height: 16),
                    ...AdminMockData.recentActivity.where((a) => a['user'] == user['username']).take(3).map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${a['detail']} - ${_formatDate(a['timestamp'])}',
                        style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary, fontSize: 14),
                      ),
                    )),
                    if (AdminMockData.recentActivity.where((a) => a['user'] == user['username']).isEmpty)
                      Text('No recent activity', style: GoogleFonts.rajdhani(color: AdminTheme.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showConfirmDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgSecondary,
        title: Text(title, style: const TextStyle(color: AdminTheme.textPrimary)),
        content: Text(message, style: const TextStyle(color: AdminTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title requested'), backgroundColor: AdminTheme.accentGreen));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.accentNeon, foregroundColor: AdminTheme.bgPrimary),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _performStatusChange(BuildContext context, String status, String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgSecondary,
        title: Text(title, style: const TextStyle(color: AdminTheme.textPrimary)),
        content: Text(message, style: const TextStyle(color: AdminTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.accentNeon, foregroundColor: AdminTheme.bgPrimary),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    final res = await AdminUsersService.updateUserStatus(id: widget.userId, status: status, token: token);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['success'] == true ? '$title successful' : 'Failed'),
        backgroundColor: res['success'] == true ? AdminTheme.accentGreen : AdminTheme.accentRed,
      ),
    );
    if (res['success'] == true) await _fetchUser();
  }

  Future<void> _performDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgSecondary,
        title: const Text('Delete Account', style: TextStyle(color: AdminTheme.textPrimary)),
        content: const Text('This action cannot be undone. The user will be soft-deleted.', style: TextStyle(color: AdminTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.accentRed, foregroundColor: AdminTheme.textPrimary),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    final res = await AdminUsersService.deleteUser(widget.userId, token);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['success'] == true ? 'User deleted' : 'Delete failed'),
        backgroundColor: res['success'] == true ? AdminTheme.accentGreen : AdminTheme.accentRed,
      ),
    );
    if (res['success'] == true) context.go('/admin/users');
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

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
