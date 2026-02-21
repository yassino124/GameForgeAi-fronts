import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../constants/admin_theme.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/admin_button.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final provider = context.read<AdminProvider>();
      final auth = context.read<AuthProvider>();
      provider.setTokenGetter(() => auth.token);
      WidgetsBinding.instance.addPostFrameCallback((_) => provider.fetchUsers());
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    final provider = context.read<AdminProvider>();
    final ok = await provider.exportUsersCsv();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'CSV exported' : 'Export failed'),
          backgroundColor: ok ? AdminTheme.accentGreen : AdminTheme.accentRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        if (provider.usersLoading && provider.paginatedUsers.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AdminTheme.accentNeon));
        }
        if (provider.usersError != null && provider.paginatedUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(provider.usersError!, style: GoogleFonts.rajdhani(color: AdminTheme.accentRed)),
                const SizedBox(height: 16),
                AdminButton(label: 'Retry', icon: Icons.refresh, onPressed: () => provider.fetchUsers()),
              ],
            ),
          );
        }

        final users = provider.paginatedUsers;

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
                    onChanged: provider.setUsersSearch,
                    decoration: InputDecoration(
                      hintText: 'Search by username or email',
                      prefixIcon: const Icon(Icons.search, color: AdminTheme.textSecondary, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: const TextStyle(color: AdminTheme.textPrimary),
                  ),
                ),
                DropdownButton<String>(
                  value: provider.usersRoleFilter,
                  dropdownColor: AdminTheme.bgSecondary,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Roles')),
                    DropdownMenuItem(value: 'user', child: Text('User')),
                    DropdownMenuItem(value: 'devl', child: Text('Developer')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => provider.setUsersRoleFilter(v ?? 'all'),
                ),
                DropdownButton<String>(
                  value: provider.usersPlanFilter,
                  dropdownColor: AdminTheme.bgSecondary,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Plans')),
                    DropdownMenuItem(value: 'free', child: Text('Free')),
                    DropdownMenuItem(value: 'pro', child: Text('Pro')),
                    DropdownMenuItem(value: 'enterprise', child: Text('Enterprise')),
                  ],
                  onChanged: (v) => provider.setUsersPlanFilter(v ?? 'all'),
                ),
                DropdownButton<String>(
                  value: provider.usersStatusFilter,
                  dropdownColor: AdminTheme.bgSecondary,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                    DropdownMenuItem(value: 'banned', child: Text('Banned')),
                  ],
                  onChanged: (v) => provider.setUsersStatusFilter(v ?? 'all'),
                ),
                AdminButton(label: 'Export CSV', icon: Icons.download, outlined: true, onPressed: provider.usersLoading ? null : () => _exportCsv(context)),
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
                    DataColumn(label: _header('Avatar')),
                    DataColumn(label: _header('Username')),
                    DataColumn(label: _header('Email')),
                    DataColumn(label: _header('Role')),
                    DataColumn(label: _header('Plan')),
                    DataColumn(label: _header('Status')),
                    DataColumn(label: _header('Last Login')),
                    DataColumn(label: _header('Actions')),
                  ],
                  rows: users.map((u) {
                    final id = u['id']?.toString() ?? u['_id']?.toString() ?? '';
                    final status = (u['status'] ?? (u['isActive'] == true ? 'active' : 'suspended')).toString();
                    final isActive = status == 'active';
                    return DataRow(
                      cells: [
                        DataCell(CircleAvatar(
                          radius: 18,
                          backgroundColor: AdminTheme.accentPurple.withOpacity(0.3),
                          child: Text(
                            (u['username'] ?? '?')[0].toUpperCase(),
                            style: GoogleFonts.rajdhani(color: AdminTheme.accentPurple, fontWeight: FontWeight.bold),
                          ),
                        )),
                        DataCell(Text(u['username']?.toString() ?? '', style: GoogleFonts.rajdhani(color: AdminTheme.textPrimary))),
                        DataCell(Text(u['email']?.toString() ?? '', style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary))),
                        DataCell(StatusChip(label: (u['role'] ?? '').toString().toUpperCase(), status: u['role']?.toString() ?? '', clickable: false, color: AdminTheme.roleColor(u['role']?.toString() ?? ''))),
                        DataCell(StatusChip(label: (u['subscription'] ?? '').toString().toUpperCase(), status: u['subscription']?.toString() ?? '', clickable: false, color: AdminTheme.planColor(u['subscription']?.toString() ?? ''))),
                        DataCell(StatusChip(
                          label: status == 'active' ? 'Active' : (status == 'suspended' ? 'Suspended' : 'Banned'),
                          status: status,
                          clickable: false,
                          color: status == 'active' ? AdminTheme.accentGreen : (status == 'suspended' ? AdminTheme.accentOrange : AdminTheme.accentRed),
                        )),
                        DataCell(Text(_formatDate(u['lastLogin']), style: GoogleFonts.jetBrainsMono(color: AdminTheme.textSecondary, fontSize: 12))),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.visibility, size: 20, color: AdminTheme.accentNeon), onPressed: () => context.go('/admin/users/$id'), tooltip: 'View'),
                            if (isActive) ...[
                              IconButton(icon: const Icon(Icons.pause_circle, size: 20, color: AdminTheme.accentOrange), onPressed: () => _confirmAction(context, provider, id, 'Suspend', 'suspended', 'This will prevent the user from accessing the platform.'), tooltip: 'Suspend'),
                              IconButton(icon: const Icon(Icons.block, size: 20, color: AdminTheme.accentRed), onPressed: () => _confirmAction(context, provider, id, 'Ban', 'banned', 'The user will be permanently banned.'), tooltip: 'Ban'),
                            ] else
                              IconButton(icon: const Icon(Icons.play_circle, size: 20, color: AdminTheme.accentGreen), onPressed: () => _confirmAction(context, provider, id, 'Reactivate', 'active', 'Restore user access.'), tooltip: 'Reactivate'),
                            IconButton(icon: const Icon(Icons.delete, size: 20, color: AdminTheme.accentRed), onPressed: () => _confirmDelete(context, provider, id), tooltip: 'Delete'),
                          ],
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Pagination
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page ${provider.usersPage + 1} of ${provider.usersTotalPages == 0 ? 1 : provider.usersTotalPages}',
                  style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: provider.usersHasPrevPage ? () => provider.prevUsersPage() : null,
                      child: const Text('Previous'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: provider.usersHasNextPage ? () => provider.nextUsersPage() : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAction(BuildContext context, AdminProvider provider, String id, String title, String status, String message) async {
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
    if (ok == true && context.mounted) {
      final success = await provider.updateUserStatus(id, status);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? '$title successful' : 'Failed'), backgroundColor: success ? AdminTheme.accentGreen : AdminTheme.accentRed),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, AdminProvider provider, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.bgSecondary,
        title: const Text('Delete User', style: TextStyle(color: AdminTheme.textPrimary)),
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
    if (ok == true && context.mounted) {
      final success = await provider.deleteUser(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'User deleted' : 'Delete failed'), backgroundColor: success ? AdminTheme.accentGreen : AdminTheme.accentRed),
        );
      }
    }
  }

  Widget _header(String text) => Text(
    text,
    style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.textSecondary),
  );

  String _formatDate(dynamic d) {
    if (d == null) return '-';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return d.toString();
    }
  }
}
