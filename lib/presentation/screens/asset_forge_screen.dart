import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/assets_service.dart';
import '../../core/services/api_service.dart';

const _assetTypes = [
  {'id': 'photo_asset',   'label': 'Photo Asset',   'icon': '📸', 'hint': 'High-quality game asset photo via Gemini'},
  {'id': 'svg_sprite',    'label': 'Game Sprite',   'icon': '🧝', 'hint': 'SVG game character sprite 200x200px pixel-art style'},
  {'id': 'svg_bg',        'label': 'Background',    'icon': '🌄', 'hint': 'SVG game background scene 200x200px'},
  {'id': 'svg_icon',      'label': 'UI Icon',       'icon': '🎯', 'hint': 'Clean SVG game UI icon 64x64px'},
  {'id': 'color_palette', 'label': 'Color Palette', 'icon': '🎨', 'hint': 'JSON color palette'},
  {'id': 'css_effect',    'label': 'CSS Effect',    'icon': '✨', 'hint': 'CSS keyframe animation for game'},
  {'id': 'canvas_asset',  'label': 'Canvas Code',   'icon': '🖼️','hint': 'JavaScript canvas drawAsset(ctx,x,y) function'},
];

const _styles = [
  {'id': 'pixel',   'label': 'Pixel', 'icon': '👾'},
  {'id': 'cartoon', 'label': 'Cartoon','icon': '🎭'},
  {'id': 'sci-fi',  'label': 'Sci-Fi', 'icon': '🚀'},
  {'id': 'fantasy', 'label': 'Fantasy','icon': '🧙'},
  {'id': 'neon',    'label': 'Neon',   'icon': '💜'},
  {'id': 'minimal', 'label': 'Minimal','icon': '⬜'},
];

class _Asset {
  final String id, title, type, code, style, model;
  _Asset({required this.id, required this.title, required this.type, required this.code, required this.style, required this.model});
}

// ── Removed local _callOllama and _buildPrompt ──

class AssetForgeScreen extends StatefulWidget {
  const AssetForgeScreen({super.key});
  @override
  State<AssetForgeScreen> createState() => _AssetForgeScreenState();
}

class _AssetForgeScreenState extends State<AssetForgeScreen> with TickerProviderStateMixin {
  late TabController _tab;
  String _model = 'claude';
  String _assetType = 'svg_sprite';
  String _style = 'pixel';
  String _desc = '';
  bool _generating = false;
  bool? _ollamaOk;
  String? _error;
  final List<_Asset> _library = [];
  _Asset? _selected;

  Color _aiColor() => const Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOllama());
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _checkOllama() async {
    try {
      String? token;
      try { token = context.read<AuthProvider>().token; } catch (_) {}
      if (token == null || token.isEmpty) return;
      final res = await ApiService.get('/ai/assets/health', token: token);
      final ok = (res['online'] == true) || (res['data'] is Map && res['data']['online'] == true);
      if (mounted) setState(() {
        _ollamaOk = ok;
        _model = 'claude';
      });
    } catch (_) {
      if (mounted) setState(() => _ollamaOk = false);
    }
  }

  Future<void> _generate() async {
    if (_desc.trim().isEmpty) return;
    setState(() { _generating = true; _error = null; });
    try {
      String? token;
      try { token = context.read<AuthProvider>().token; } catch (_) {}
      if (token == null || token.isEmpty) throw Exception('Not authenticated');

      final res = await AssetsService.generateAsset(
        token: token,
        assetType: _assetType,
        style: _style,
        description: _desc,
        model: _model,
      );

      final code = res['code']?.toString() ?? '';
      if (code.isEmpty) {
        throw Exception(
          'Empty response from backend. Check that the backend is running and has ANTHROPIC_AUTH_TOKEN configured.',
        );
      }

      final title = _desc.length > 36 ? _desc.substring(0, 36) : _desc;
      final asset = _Asset(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title, type: _assetType, code: code, style: _style, model: _model,
      );
      setState(() { _library.insert(0, asset); _selected = asset; });
      _tab.animateTo(1);
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg.replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _generating = false);
    }
  }

  Future<void> _saveToBackend(String title, String code) async {
    try {
      String? token;
      try { token = context.read<AuthProvider>().token; } catch (_) {}
      if (token == null || token.isEmpty) return;
      // Write SVG to temp file then upload
      final dir = await getTemporaryDirectory();
      final ext = code.trimLeft().startsWith('<svg') ? 'svg' : 'txt';
      final file = File('${dir.path}/$title.$ext');
      await file.writeAsString(code);
      await AssetsService.uploadAsset(
        token: token, file: file,
        type: _assetType.contains('svg') ? 'texture' : 'other',
        name: title,
        tagsCsv: '$_style,$_model',
      );
    } catch (_) { /* silent — local library still works */ }
  }

  void _copyCode() {
    if (_selected == null) return;
    Clipboard.setData(ClipboardData(text: _selected!.code));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Code copied! ✓'),
      backgroundColor: const Color(0xFFF97316),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _downloadAsset(_Asset asset, {RenderBox? box}) async {
    try {
      final dir = await getTemporaryDirectory();
      String filePath;
      
      if (asset.code.startsWith('data:image')) {
        // Handle Base64 images
        final parts = asset.code.split(',');
        final bytes = base64Decode(parts[1]);
        final ext = parts[0].contains('svg') ? 'svg' : 'png';
        filePath = '${dir.path}/${asset.title}.$ext';
        await File(filePath).writeAsBytes(bytes);
      } else {
        // Handle raw text/SVG
        final ext = asset.code.trimLeft().startsWith('<svg') ? 'svg' : 'txt';
        filePath = '${dir.path}/${asset.title}.$ext';
        await File(filePath).writeAsString(asset.code);
      }
      
      final Rect? shareRect = box != null 
          ? box.localToGlobal(Offset.zero) & box.size 
          : null;

      await Share.shareXFiles(
        [XFile(filePath)], 
        text: 'Check out my GameForge generated asset!',
        sharePositionOrigin: shareRect,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to download: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070810),
      body: SafeArea(child: Column(children: [
        _buildHeader(),
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFFF97316),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFFF97316),
          tabs: const [Tab(text: '🎨 Generate'), Tab(text: '📦 Library')],
        ),
        Expanded(child: TabBarView(controller: _tab, children: [
          _buildGenerateTab(),
          _buildLibraryTab(),
        ])),
      ])),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
        onPressed: () {
          context.go('/dashboard?tab=home');
        },
      ),
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEF4444)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('AssetForge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        Text('AI Asset Generator · Claude (AgentRouter)', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
      ])),
      // Claude status
      GestureDetector(
        onTap: _checkOllama,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _ollamaOk == true ? const Color(0xFF10B981).withOpacity(0.15)
                : _ollamaOk == false ? const Color(0xFFEF4444).withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _ollamaOk == true ? const Color(0xFF10B981).withOpacity(0.4)
                : _ollamaOk == false ? const Color(0xFFEF4444).withOpacity(0.4)
                : Colors.white.withOpacity(0.1)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _ollamaOk == true ? const Color(0xFF10B981) : _ollamaOk == false ? const Color(0xFFEF4444) : Colors.white38,
            )),
            const SizedBox(width: 6),
            Text(_ollamaOk == true ? 'Online' : _ollamaOk == false ? 'Offline' : 'Tap to check',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    ]),
  );

  Widget _buildGenerateTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Model badge
      _sectionLabel('AI Model'),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _aiColor().withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _aiColor().withOpacity(0.45)),
        ),
        child: const Row(children: [
          Text('Claude', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
          SizedBox(width: 8),
          Text('AgentRouter', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      ),
      const SizedBox(height: 18),

      // Asset type
      _sectionLabel('🎨 Asset Type'),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.6,
        children: _assetTypes.map((t) {
          final selected = _assetType == t['id'];
          return GestureDetector(
            onTap: () => setState(() => _assetType = t['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFF97316).withOpacity(0.2) : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? const Color(0xFFF97316).withOpacity(0.5) : Colors.white.withOpacity(0.07)),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(t['icon'] as String, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 2),
                Text(t['label'] as String, style: TextStyle(fontSize: 10, color: selected ? const Color(0xFFF97316) : Colors.white54, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ]),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 18),

      // Style
      _sectionLabel('🖼️ Art Style'),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: _styles.map((s) {
        final selected = _style == s['id'];
        return GestureDetector(
          onTap: () => setState(() => _style = s['id'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF6366F1).withOpacity(0.2) : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? const Color(0xFF6366F1).withOpacity(0.5) : Colors.white.withOpacity(0.07)),
            ),
            child: Text('${s['icon']} ${s['label']}', style: TextStyle(fontSize: 12, color: selected ? const Color(0xFF818CF8) : Colors.white54, fontWeight: FontWeight.bold)),
          ),
        );
      }).toList()),
      const SizedBox(height: 18),

      // Description
      _sectionLabel('📝 Description'),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: TextField(
          style: const TextStyle(color: Colors.white, fontSize: 13),
          maxLines: 3,
          onChanged: (v) => setState(() => _desc = v),
          decoration: InputDecoration(
            hintText: 'e.g. "A brave knight with sword, facing right"',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ),
      const SizedBox(height: 16),

      // Error
      if (_error != null) Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('⚠️ Error', style: TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text(_error!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 11)),
          const SizedBox(height: 4),
          const Text('💡 Make sure backend has ANTHROPIC_AUTH_TOKEN', style: TextStyle(color: Color(0xFFF87171), fontSize: 10)),
        ]),
      ),

      // Generate button
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: (_generating || _desc.trim().isEmpty) ? null : _generate,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: (_desc.trim().isEmpty || _generating)
                  ? null
                  : const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEF4444)]),
              color: (_desc.trim().isEmpty || _generating) ? Colors.white.withOpacity(0.06) : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _generating || _desc.trim().isEmpty ? [] : [BoxShadow(color: const Color(0xFFF97316).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Center(child: _generating
              ? const Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Claude generating…', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ])
              : const Text('🎨 Generate Asset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
        ),
      ),

      // Tips
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF97316).withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF97316).withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Powered by Claude & Gemini', style: TextStyle(color: Color(0xFFFB923C), fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          ...[
            '• SVG → rendered instantly in-app',
            '• Palette → JSON with usage hints',
            '• CSS → animations for your UI',
            '• Canvas → JS drawAsset() for HTML5',
          ].map((t) => Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(t, style: const TextStyle(color: Color(0xFFFB923C), fontSize: 11)))),
        ]),
      ),
    ]),
  );

  Widget _buildLibraryTab() {
    if (_library.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🎨', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text('No assets yet', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
      const SizedBox(height: 4),
      Text('Generate your first asset!', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12)),
    ]));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _library.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) => _buildAssetCard(_library[i]),
    );
  }

  Widget _buildAssetCard(_Asset asset) {
    final typeInfo = _assetTypes.firstWhere((t) => t['id'] == asset.type, orElse: () => {'icon': '🎨', 'label': 'Asset'});
    final isPhoto = asset.type == 'photo_asset';
    final isSvg = asset.type.contains('svg') && asset.code.contains('<svg');
    final isCode = !isPhoto && !isSvg;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131524),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Media Header
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF070810),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: isPhoto && asset.code.contains('base64,')
            ? Image.memory(
                base64Decode(asset.code.split(',').last),
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, _) => const Center(child: Icon(Icons.broken_image, color: Colors.white38)),
              )
            : isSvg
              ? InteractiveViewer(
                  child: SvgPicture.string(asset.code, fit: BoxFit.contain),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(asset.code, style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 10, fontFamily: 'monospace')),
                ),
        ),
        
        // Card Body
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF97316).withOpacity(0.3)),
                ),
                child: Text('${typeInfo['icon']} ${typeInfo['label']}', style: const TextStyle(color: Color(0xFFF97316), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Text(asset.style.toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            ]),
            const SizedBox(height: 12),
            Text(asset.title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            
            // Action button
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(asset.model, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
              Row(
                children: [
                  Builder(
                    builder: (btnCtx) => GestureDetector(
                      onTap: () {
                        final box = btnCtx.findRenderObject() as RenderBox?;
                        _downloadAsset(asset, box: box);
                      },
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.download_rounded, color: Color(0xFF10B981), size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      _selected = asset;
                      _copyCode();
                    },
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF97316).withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.copy_rounded, color: Color(0xFFF97316), size: 18),
                    ),
                  ),
                ],
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String label) => Text(label, style: const TextStyle(color: Color(0xFF71717A), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5));
}
