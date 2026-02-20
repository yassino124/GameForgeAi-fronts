import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/admin_theme.dart';
import '../../widgets/admin_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _maintenanceMode = false;
  final _maxProjectsController = TextEditingController(text: '5');
  final _maxBuildsController = TextEditingController(text: '10');

  @override
  void dispose() {
    _maxProjectsController.dispose();
    _maxBuildsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Platform Settings
          _SettingsCard(
            title: 'Platform Settings',
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'App Name'),
                controller: TextEditingController(text: 'GameFrogAI'),
                style: const TextStyle(color: AdminTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(labelText: 'App Version'),
                controller: TextEditingController(text: '1.0.0'),
                style: const TextStyle(color: AdminTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Maintenance Mode', style: GoogleFonts.rajdhani(color: AdminTheme.textPrimary)),
                  const Spacer(),
                  Switch(
                    value: _maintenanceMode,
                    onChanged: (v) => setState(() => _maintenanceMode = v),
                    activeThumbColor: AdminTheme.accentNeon,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _maxProjectsController,
                decoration: const InputDecoration(labelText: 'Max projects per free user'),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AdminTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _maxBuildsController,
                decoration: const InputDecoration(labelText: 'Max builds per day'),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AdminTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Email Configuration
          _SettingsCard(
            title: 'Email Configuration',
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'SMTP Host'),
                readOnly: true,
                controller: TextEditingController(text: 'smtp.example.com'),
                style: const TextStyle(color: AdminTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(labelText: 'Port'),
                readOnly: true,
                controller: TextEditingController(text: '587'),
                style: const TextStyle(color: AdminTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(labelText: 'From Email'),
                readOnly: true,
                obscureText: true,
                controller: TextEditingController(text: 'noreply@gamefrogai.com'),
                style: const TextStyle(color: AdminTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Test email sent'), backgroundColor: AdminTheme.accentGreen, behavior: SnackBarBehavior.floating),
                  );
                },
                icon: const Icon(Icons.email, size: 18),
                label: const Text('Test Email'),
                style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.accentNeon, foregroundColor: AdminTheme.bgPrimary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Subscription Plans
          _SettingsCard(
            title: 'Subscription Plans',
            children: [
              _PlanCard(name: 'Free', price: '\$0', features: ['5 projects', '3 builds/day'], onEdit: () {}),
              const SizedBox(height: 12),
              _PlanCard(name: 'Pro', price: '\$19/mo', features: ['50 projects', '50 builds/day', 'Priority support'], onEdit: () {}),
              const SizedBox(height: 12),
              _PlanCard(name: 'Enterprise', price: '\$99/mo', features: ['Unlimited projects', 'Unlimited builds', '24/7 support', 'API access'], onEdit: () {}),
            ],
          ),
          const SizedBox(height: 24),
          // Security
          _SettingsCard(
            title: 'Security',
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'JWT Expiration (minutes)'),
                controller: TextEditingController(text: '60'),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AdminTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(labelText: 'Max sessions per user'),
                controller: TextEditingController(text: '5'),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AdminTheme.textPrimary),
              ),
              const SizedBox(height: 24),
              AdminButton(
                label: 'Revoke All Sessions',
                icon: Icons.logout,
                outlined: true,
                color: AdminTheme.accentRed,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AdminTheme.bgSecondary,
                      title: const Text('Revoke All Sessions', style: TextStyle(color: AdminTheme.textPrimary)),
                      content: const Text('This will log out all users. Continue?', style: TextStyle(color: AdminTheme.textSecondary)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('All sessions revoked'), backgroundColor: AdminTheme.accentGreen, behavior: SnackBarBehavior.floating),
                            );
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.accentRed),
                          child: const Text('Revoke'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.borderGlow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;
  final List<String> features;
  final VoidCallback onEdit;

  const _PlanCard({required this.name, required this.price, required this.features, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.bgTertiary.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminTheme.borderGlow),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.w600, color: AdminTheme.textPrimary)),
                Text(price, style: GoogleFonts.rajdhani(color: AdminTheme.accentNeon)),
                const SizedBox(height: 4),
                ...features.map((f) => Text('• $f', style: GoogleFonts.rajdhani(color: AdminTheme.textSecondary, fontSize: 12))),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}
