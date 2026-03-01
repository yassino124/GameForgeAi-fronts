import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/admin_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../widgets/user_avatar.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final authProvider = context.watch<AuthProvider>();

    return Container(
      width: AdminTheme.sidebarWidth,
      decoration: BoxDecoration(
        color: AdminTheme.bgSecondary.withOpacity(0.9),
        border: Border(
          right: BorderSide(color: AdminTheme.borderGlow, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: AdminTheme.glowCyan.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Column(
            children: [
              // Logo
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AdminTheme.accentNeon, AdminTheme.accentPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AdminTheme.accentNeon.withOpacity(0.3),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.games, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'GameForge',
                        style: GoogleFonts.orbitron(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AdminTheme.borderGlow, height: 1),
              const SizedBox(height: 16),
              // Nav items
              _NavItem(icon: Icons.dashboard, label: 'Overview', path: '/admin/overview', isActive: location == '/admin/overview'),
              _NavItem(icon: Icons.people, label: 'Users', path: '/admin/users', isActive: location.startsWith('/admin/users')),
              _NavItem(icon: Icons.folder_special, label: 'Games', path: '/admin/projects', isActive: location == '/admin/projects'),
              _NavItem(icon: Icons.store, label: 'Templates', path: '/admin/marketplace', isActive: location == '/admin/marketplace'),
              _NavItem(icon: Icons.build, label: 'Builds', path: '/admin/builds', isActive: location == '/admin/builds'),
              _NavItem(icon: Icons.notifications, label: 'Notifications', path: '/admin/notifications', isActive: location == '/admin/notifications'),
              _NavItem(icon: Icons.settings, label: 'Settings', path: '/admin/settings', isActive: location == '/admin/settings'),
              const Spacer(),
              const Divider(color: AdminTheme.borderGlow, height: 1),
              // Admin info + logout
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                          avatarUrl: authProvider.user?['avatar']?.toString(),
                          username: authProvider.user?['username']?.toString() ?? 'A',
                          radius: 20,
                          backgroundColor: AdminTheme.accentPurple,
                          textColor: AdminTheme.accentPurple,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => context.go('/admin/profile'),
                                child: Text(
                                  authProvider.user?['username'] ?? 'Admin',
                                  style: GoogleFonts.rajdhani(
                                    color: AdminTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                authProvider.user?['email'] ?? '',
                                style: GoogleFonts.rajdhani(
                                  color: AdminTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await authProvider.logout(context: context);
                          if (context.mounted) context.go('/admin/login');
                        },
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Logout'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminTheme.accentRed,
                          side: const BorderSide(color: AdminTheme.accentRed),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String path;
  final bool isActive;

  const _NavItem({required this.icon, required this.label, required this.path, required this.isActive});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final bg = isActive
        ? AdminTheme.glowCyan
        : (_hovered ? AdminTheme.bgTertiary : Colors.transparent);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: isActive ? Border(left: BorderSide(color: AdminTheme.accentNeon, width: 3)) : null,
          ),
          child: ListTile(
            leading: Icon(
              widget.icon,
              size: 22,
              color: isActive ? AdminTheme.accentNeon : AdminTheme.textSecondary,
            ),
            title: Text(
              widget.label,
              style: TextStyle(
                color: isActive ? AdminTheme.textPrimary : AdminTheme.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            onTap: () => context.go(widget.path),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            minLeadingWidth: 32,
          ),
        ),
      ),
    );
  }
}
