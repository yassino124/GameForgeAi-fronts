import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/admin_users_service.dart';
import '../../constants/admin_theme.dart';
import '../../widgets/admin_button.dart';
import '../../widgets/user_avatar.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;

  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  Map<String, dynamic>? _user;
  List<dynamic> _projects = [];
  List<dynamic> _activity = [];
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
      _projects = [];
      _activity = [];
    });

    // Fetch user details
    final userRes = await AdminUsersService.getUser(widget.userId, token);
    if (!mounted) return;

    // Fetch projects and activity in parallel
    final projectsRes = await AdminUsersService.getUserProjects(
      widget.userId,
      token,
    );
    final activityRes = await AdminUsersService.getUserActivity(
      widget.userId,
      token,
    );

    if (userRes['success'] == true && userRes['data'] != null) {
      setState(() {
        _user = Map<String, dynamic>.from(
          userRes['data'] is Map ? userRes['data'] as Map : {},
        );
        _projects =
            (projectsRes['success'] == true && projectsRes['data'] is List)
            ? projectsRes['data'] as List
            : [];
        _activity =
            (activityRes['success'] == true && activityRes['data'] is List)
            ? activityRes['data'] as List
            : [];
        _loading = false;
        _error = null;
      });
    } else {
      setState(() {
        _user = null;
        _loading = false;
        _error = userRes['message']?.toString() ?? 'User not found';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _user == null) {
      return const Center(
        child: CircularProgressIndicator(color: AdminTheme.accentNeon),
      );
    }

    if (_error != null && _user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off, size: 64, color: AdminTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: GoogleFonts.orbitron(color: AdminTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            AdminButton(
              label: 'Back to Users',
              icon: Icons.arrow_back,
              onPressed: () => context.go('/admin/users'),
            ),
          ],
        ),
      );
    }

    final user = _user ?? {};
    final status =
        (user['status'] ?? (user['isActive'] == true ? 'active' : 'suspended'))
            .toString();
    final isActive = status == 'active';

    return SingleChildScrollView(
      child: Row(
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
                        border: Border.all(
                          color: AdminTheme.accentNeon,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AdminTheme.accentNeon.withOpacity(0.3),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: UserAvatar(
                        avatarUrl: user['avatar']?.toString(),
                        username: user['username']?.toString() ?? '?',
                        radius: 58,
                        backgroundColor: AdminTheme.accentPurple,
                        textColor: AdminTheme.accentPurple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    user['fullName']?.toString() ??
                        user['username']?.toString() ??
                        'Unknown',
                    style: GoogleFonts.orbitron(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user['email']?.toString() ?? '',
                    style: GoogleFonts.rajdhani(
                      color: AdminTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    label: 'Role',
                    value: (user['role'] ?? '').toString().toUpperCase(),
                  ),
                  _InfoRow(
                    label: 'Plan',
                    value: (user['subscription'] ?? '')
                        .toString()
                        .toUpperCase(),
                  ),
                  _InfoRow(
                    label: 'Joined',
                    value: _formatDate(user['createdAt']),
                  ),
                  _InfoRow(
                    label: 'Last Login',
                    value: _formatDate(user['lastLogin']),
                  ),
                  if ((user['bio'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Bio',
                      style: GoogleFonts.orbitron(
                        fontSize: 12,
                        color: AdminTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user['bio']?.toString() ?? '',
                      style: GoogleFonts.rajdhani(
                        color: AdminTheme.textPrimary,
                      ),
                    ),
                  ],
                  if ((user['location'] ?? '').toString().isNotEmpty)
                    _InfoRow(
                      label: 'Location',
                      value: user['location']?.toString() ?? '',
                    ),
                  if ((user['website'] ?? '').toString().isNotEmpty)
                    _InfoRow(
                      label: 'Website',
                      value: user['website']?.toString() ?? '',
                    ),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      AdminButton(
                        label: 'Change Role',
                        icon: Icons.admin_panel_settings,
                        outlined: true,
                        onPressed: () => _showConfirmDialog(
                          context,
                          'Change Role',
                          'Are you sure you want to change this user\'s role?',
                        ),
                      ),
                      AdminButton(
                        label: 'Change Plan',
                        icon: Icons.card_membership,
                        outlined: true,
                        onPressed: () => _showConfirmDialog(
                          context,
                          'Change Plan',
                          'Are you sure you want to change this user\'s subscription plan?',
                        ),
                      ),
                      if (isActive) ...[
                        AdminButton(
                          label: 'Suspend Account',
                          icon: Icons.block,
                          outlined: true,
                          color: AdminTheme.accentOrange,
                          onPressed: () => _performStatusChange(
                            context,
                            'suspended',
                            'Suspend Account',
                            'This will prevent the user from accessing the platform.',
                          ),
                        ),
                        AdminButton(
                          label: 'Ban Account',
                          icon: Icons.block,
                          outlined: true,
                          color: AdminTheme.accentRed,
                          onPressed: () => _performStatusChange(
                            context,
                            'banned',
                            'Ban Account',
                            'The user will be permanently banned.',
                          ),
                        ),
                      ] else
                        AdminButton(
                          label: 'Reactivate Account',
                          icon: Icons.play_circle,
                          outlined: true,
                          color: AdminTheme.accentGreen,
                          onPressed: () => _performStatusChange(
                            context,
                            'active',
                            'Reactivate Account',
                            'Restore user access.',
                          ),
                        ),
                      AdminButton(
                        label: 'Delete Account',
                        icon: Icons.delete,
                        outlined: true,
                        color: AdminTheme.accentRed,
                        onPressed: () => _performDelete(context),
                      ),
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
                      Text(
                        'Projects',
                        style: GoogleFonts.orbitron(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AdminTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_projects.isEmpty)
                        Text(
                          'No projects',
                          style: GoogleFonts.rajdhani(
                            color: AdminTheme.textMuted,
                          ),
                        )
                      else
                        ..._projects
                            .take(5)
                            .map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p['title']?.toString() ??
                                                'Untitled',
                                            style: GoogleFonts.rajdhani(
                                              color: AdminTheme.textPrimary,
                                            ),
                                          ),
                                          if ((p['description'] ?? '')
                                              .toString()
                                              .isNotEmpty)
                                            Text(
                                              p['description']?.toString() ??
                                                  '',
                                              style: GoogleFonts.rajdhani(
                                                color: AdminTheme.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AdminTheme.statusColor(
                                          p['status']?.toString() ?? 'unknown',
                                        ).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        (p['status'] ?? 'unknown')
                                            .toString()
                                            .toUpperCase(),
                                        style: GoogleFonts.rajdhani(
                                          color: AdminTheme.statusColor(
                                            p['status']?.toString() ??
                                                'unknown',
                                          ),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
                      Text(
                        'Recent Activity',
                        style: GoogleFonts.orbitron(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AdminTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_activity.isEmpty)
                        Text(
                          'No recent activity',
                          style: GoogleFonts.rajdhani(
                            color: AdminTheme.textMuted,
                          ),
                        )
                      else
                        ..._activity
                            .take(3)
                            .map(
                              (a) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: a['type'] == 'login'
                                            ? AdminTheme.accentGreen
                                            : AdminTheme.accentNeon,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  a['title']?.toString() ??
                                                      'Activity',
                                                  style: GoogleFonts.rajdhani(
                                                    color:
                                                        AdminTheme.textPrimary,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: a['type'] == 'login'
                                                      ? AdminTheme.accentGreen
                                                            .withOpacity(0.2)
                                                      : AdminTheme.accentPurple
                                                            .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                ),
                                                child: Text(
                                                  a['type'] == 'login'
                                                      ? 'LOGIN'
                                                      : 'PROJECT',
                                                  style: GoogleFonts.rajdhani(
                                                    color: a['type'] == 'login'
                                                        ? AdminTheme.accentGreen
                                                        : AdminTheme
                                                              .accentPurple,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if ((a['description'] ?? '')
                                              .toString()
                                              .isNotEmpty)
                                            Text(
                                              a['description']?.toString() ??
                                                  '',
                                              style: GoogleFonts.rajdhani(
                                                color: AdminTheme.textSecondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                          Text(
                                            _formatActivityTime(
                                              a['timestamp'] ?? a['createdAt'],
                                            ),
                                            style: GoogleFonts.rajdhani(
                                              color: AdminTheme.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgSecondary,
        title: Text(
          title,
          style: const TextStyle(color: AdminTheme.textPrimary),
        ),
        content: Text(
          message,
          style: const TextStyle(color: AdminTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$title requested'),
                  backgroundColor: AdminTheme.accentGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.accentNeon,
              foregroundColor: AdminTheme.bgPrimary,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _performStatusChange(
    BuildContext context,
    String status,
    String title,
    String message,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgSecondary,
        title: Text(
          title,
          style: const TextStyle(color: AdminTheme.textPrimary),
        ),
        content: Text(
          message,
          style: const TextStyle(color: AdminTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.accentNeon,
              foregroundColor: AdminTheme.bgPrimary,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    final res = await AdminUsersService.updateUserStatus(
      id: widget.userId,
      status: status,
      token: token,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['success'] == true ? '$title successful' : 'Failed'),
        backgroundColor: res['success'] == true
            ? AdminTheme.accentGreen
            : AdminTheme.accentRed,
      ),
    );
    if (res['success'] == true) await _fetchUser();
  }

  Future<void> _performDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgSecondary,
        title: const Text(
          'Delete Account',
          style: TextStyle(color: AdminTheme.textPrimary),
        ),
        content: const Text(
          'This action cannot be undone. The user will be soft-deleted.',
          style: TextStyle(color: AdminTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.accentRed,
              foregroundColor: AdminTheme.textPrimary,
            ),
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
        content: Text(
          res['success'] == true ? 'User deleted' : 'Delete failed',
        ),
        backgroundColor: res['success'] == true
            ? AdminTheme.accentGreen
            : AdminTheme.accentRed,
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

  String _formatActivityTime(dynamic d) {
    if (d == null) return '-';
    try {
      final dt = DateTime.parse(d.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
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
          Text(
            label,
            style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.rajdhani(
                color: AdminTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
