import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/admin_theme.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/admin_button.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  void _exportCsv(BuildContext context) {
    final provider = context.read<AdminProvider>();
    final users = provider.filteredUsers;
    final sb = StringBuffer();
    sb.writeln('id,username,email,role,subscription,isActive,lastLogin');
    for (final u in users) {
      sb.writeln('${u['id']},${u['username']},${u['email']},${u['role']},${u['subscription']},${u['isActive']},${u['lastLogin']}');
    }
    // In web, we could trigger download - for now just copy to clipboard
    // ignore: avoid_web_libraries_in_flutter
    // Clipboard.setData(ClipboardData(text: sb.toString()));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
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
                AdminButton(label: 'Export CSV', icon: Icons.download, outlined: true, onPressed: () => _exportCsv(context)),
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
                    final isActive = provider.isUserActive(u['id']?.toString() ?? '');
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
                          label: isActive ? 'Active' : 'Inactive',
                          status: isActive ? 'active' : 'inactive',
                          clickable: true,
                          onTap: () => provider.toggleUserActive(u['id']?.toString() ?? ''),
                        )),
                        DataCell(Text(_formatDate(u['lastLogin']), style: GoogleFonts.jetBrainsMono(color: AdminTheme.textSecondary, fontSize: 12))),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.visibility, size: 20, color: AdminTheme.accentNeon), onPressed: () => context.go('/admin/users/${u['id']}'), tooltip: 'View'),
                            IconButton(icon: const Icon(Icons.edit, size: 20, color: AdminTheme.accentPurple), onPressed: () {}, tooltip: 'Edit role'),
                            IconButton(icon: const Icon(Icons.block, size: 20, color: AdminTheme.accentRed), onPressed: () {}, tooltip: 'Ban'),
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
