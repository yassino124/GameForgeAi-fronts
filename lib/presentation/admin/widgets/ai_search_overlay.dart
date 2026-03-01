import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';

class AiSearchOverlay extends StatefulWidget {
  const AiSearchOverlay({super.key});

  @override
  State<AiSearchOverlay> createState() => _AiSearchOverlayState();
}

class _AiSearchOverlayState extends State<AiSearchOverlay> {
  final _controller = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _results;

  Future<void> _search() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _results = null;
    });

    final provider = context.read<AdminProvider>();
    final res = await provider.aiSearch(_controller.text.trim());

    setState(() {
      _loading = false;
      _results = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                          decoration: InputDecoration(
                            hintText: 'Ask anything...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.mic, color: Colors.white),
                        onPressed: () {
                          // Web Speech API integration (placeholder)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Voice input coming soon')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: _search,
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),

                // Results
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _results == null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search, size: 64, color: Colors.white.withOpacity(0.3)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Search projects, templates, users...',
                                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                                  ),
                                ],
                              ),
                            )
                          : _buildResults(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_results == null) return const SizedBox();

    final projects = (_results!['projects'] as List?) ?? [];
    final templates = (_results!['templates'] as List?) ?? [];
    final users = (_results!['users'] as List?) ?? [];

    if (projects.isEmpty && templates.isEmpty && users.isEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (projects.isNotEmpty) ...[
          _buildSection('Projects', projects, Icons.videogame_asset),
          const SizedBox(height: 24),
        ],
        if (templates.isNotEmpty) ...[
          _buildSection('Templates', templates, Icons.category),
          const SizedBox(height: 24),
        ],
        if (users.isNotEmpty) ...[
          _buildSection('Users', users, Icons.person),
        ],
      ],
    );
  }

  Widget _buildSection(String title, List items, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Card(
              color: Colors.white10,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(icon, color: Colors.white70),
                title: Text(
                  item['title'] ?? item['name'] ?? item['username'] ?? 'Unknown',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: item['status'] != null
                    ? Text(
                        item['status'].toString(),
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(),
              ),
            )),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
