import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/worlds_service.dart';
import '../widgets/mesh_gradient_bg.dart';

const _kThemes = [
  {'id': 'forest',  'label': 'Forest',  'icon': '🌲', 'color': 0xFF10B981},
  {'id': 'space',   'label': 'Space',   'icon': '🚀', 'color': 0xFF6366F1},
  {'id': 'ocean',   'label': 'Ocean',   'icon': '🌊', 'color': 0xFF0EA5E9},
  {'id': 'city',    'label': 'City',    'icon': '🏙️', 'color': 0xFFF59E0B},
  {'id': 'dungeon', 'label': 'Dungeon', 'icon': '⚔️', 'color': 0xFFEF4444},
  {'id': 'neon',    'label': 'Neon',    'icon': '💜', 'color': 0xFF8B5CF6},
  {'id': 'desert',  'label': 'Desert',  'icon': '🏜️', 'color': 0xFFF97316},
];

class WorldsScreen extends StatefulWidget {
  const WorldsScreen({super.key});
  @override
  State<WorldsScreen> createState() => _WorldsScreenState();
}

class _WorldsScreenState extends State<WorldsScreen> with TickerProviderStateMixin {
  late TabController _tab;

  // Discover
  List<dynamic> _publicWorlds = [];
  bool _loadingDiscover = false;

  // Create
  String _theme = 'neon';
  bool _isPublic = true;
  bool _allowNft = false;
  bool _creating = false;
  bool _aiLoading = false;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDiscover());
  }

  @override
  void dispose() {
    _tab.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String? _token() {
    try { return context.read<AuthProvider>().token; } catch (_) { return null; }
  }

  Future<void> _loadDiscover() async {
    setState(() => _loadingDiscover = true);
    try {
      final token = _token();
      final res = await WorldsService.discoverWorlds(token: token ?? '');
      final data = res['data'];
      if (mounted) setState(() => _publicWorlds = (data is List) ? data : []);
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingDiscover = false);
    }
  }

  Future<void> _generateAiDescription() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a world name first'),
        backgroundColor: Color(0xFFF97316),
      ));
      return;
    }
    setState(() => _aiLoading = true);
    final desc = await WorldsService.generateDescription(worldName: name, theme: _theme);
    if (mounted) {
      setState(() { _aiLoading = false; if (desc.isNotEmpty) _descCtrl.text = desc; });
    }
  }

  Future<void> _createWorld() async {
    final token = _token();
    if (token == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a world name')));
      return;
    }
    setState(() => _creating = true);
    try {
      await WorldsService.createWorld(
        token: token,
        name: name,
        theme: _theme,
        description: _descCtrl.text.trim(),
        isPublic: _isPublic,
        allowNftCosmetics: _allowNft,
      );
      if (!mounted) return;
      _nameCtrl.clear();
      _descCtrl.clear();
      _tab.animateTo(0);
      await _loadDiscover();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('🎉 World created!'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Color _themeColor(String id) => Color(
    (_kThemes.firstWhere((t) => t['id'] == id, orElse: () => {'color': 0xFF6366F1})['color'] as int),
  );

  @override
  Widget build(BuildContext context) {
    final totalPlayers = _publicWorlds.fold<int>(0, (s, w) => s + ((w['activePlayers'] ?? 0) as num).toInt());
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
              ),
              child: const Icon(Icons.language, color: Color(0xFF8B5CF6), size: 16),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('GF Worlds', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text('$totalPlayers players online', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          const MeshGradientBg(colors: [Color(0xFF0EA5E9), Color(0xFF6366F1), Color(0xFF0B1020)]),
          Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Discover'),
                    Tab(text: 'My Creations'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _buildDiscoverTab(),
                    _buildCreateTab(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    if (_loadingDiscover) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }
    return RefreshIndicator(
      onRefresh: _loadDiscover,
      color: const Color(0xFF8B5CF6),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF97316)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(children: [
            Text('🔴', style: TextStyle(fontSize: 18)),
            SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('LIVE WORLDS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
              Text('Pull down to refresh', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ]),
        ),
        if (_publicWorlds.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(children: [
              const Text('🌍', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('No public worlds yet', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _tab.animateTo(1),
                child: Text('Create the first one!', style: TextStyle(color: const Color(0xFF8B5CF6).withOpacity(0.8), fontSize: 12)),
              ),
            ]),
          ))
        else
          ..._publicWorlds.map((w) => _buildWorldCard(w)).toList(),
      ]),
    );
  }

  Widget _buildWorldCard(dynamic world) {
    final theme = world['theme']?.toString() ?? 'neon';
    final color = _themeColor(theme);
    final name = world['name']?.toString() ?? 'World';
    final players = (world['activePlayers'] ?? 0) as num;
    final portals = (world['portals'] is List) ? (world['portals'] as List).length : 0;
    final rating = (world['rating'] ?? 0.0) as num;
    final img = world['thumbnailUrl']?.toString() ?? '';
    final events = (world['activeEvents'] is List) ? world['activeEvents'] as List : [];
    final activeEvent = events.where((e) => e['isActive'] == true).firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
        color: Colors.white.withOpacity(0.03),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: SizedBox(
            height: 130, width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              img.isNotEmpty
                  ? Image.network(img, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: color.withOpacity(0.2)))
                  : Container(color: color.withOpacity(0.2),
                      child: Center(child: Text(
                        (_kThemes.firstWhere((t) => t['id'] == theme, orElse: () => {'icon': '🌍'})['icon'] as String),
                        style: const TextStyle(fontSize: 40),
                      ))),
              Container(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
              ))),
              if (activeEvent != null)
                Positioned(top: 10, left: 10, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
                  child: Text(activeEvent['label']?.toString() ?? '🎉 Event', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )),
              Positioned(bottom: 10, left: 12, right: 12, child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.person, color: Colors.white70, size: 11),
                      const SizedBox(width: 3),
                      Text('$players', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ]),
                  ),
                ],
              )),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(Icons.gamepad, color: color, size: 14),
            const SizedBox(width: 4),
            Text('$portals portals', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
            const Spacer(),
            const Icon(Icons.star, color: Colors.amber, size: 13),
            const SizedBox(width: 3),
            Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Entering $name…'),
                backgroundColor: const Color(0xFF8B5CF6),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              )),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Enter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCreateTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Choose Theme', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.3,
        children: _kThemes.map((t) {
          final sel = _theme == t['id'];
          final color = Color(t['color'] as int);
          return GestureDetector(
            onTap: () => setState(() => _theme = t['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: sel ? color.withOpacity(0.2) : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sel ? color.withOpacity(0.6) : Colors.white.withOpacity(0.08), width: sel ? 2 : 1),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(t['icon'] as String, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 4),
                Text(t['label'] as String, style: TextStyle(color: sel ? color : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 20),

      // Name field
      _field('World Name', 'e.g. "The Neon Nexus"', _nameCtrl),
      const SizedBox(height: 12),

      // Description with AI button
      const Text('Description', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(children: [
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'What makes your world unique?',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
            child: GestureDetector(
              onTap: _aiLoading ? null : _generateAiDescription,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _aiLoading
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Color(0xFF8B5CF6), strokeWidth: 2))
                    : const Text('✨', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Text(_aiLoading ? 'AI generating…' : 'Generate with AI (Ollama)',
                  style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 20),

      _toggle('🔓 Public World', 'Anyone can discover and enter', _isPublic, (v) => setState(() => _isPublic = v)),
      const SizedBox(height: 8),
      _toggle('💎 Allow NFT Cosmetics', 'Players can wear ERC1155 items', _allowNft, (v) => setState(() => _allowNft = v)),
      const SizedBox(height: 24),

      SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: _creating ? null : _createWorld,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Center(child: _creating
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('🌐 Create World', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
        ),
      ),
    ]),
  );

  Widget _field(String label, String hint, TextEditingController ctrl) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)), border: InputBorder.none, contentPadding: const EdgeInsets.all(14)),
        ),
      ),
    ],
  );

  Widget _toggle(String label, String desc, bool value, ValueChanged<bool> onChanged) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.07))),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
      ])),
      Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF8B5CF6)),
    ]),
  );
}
