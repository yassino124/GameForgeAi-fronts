import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audio_session/audio_session.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/sound_forge_service.dart';
import '../../../core/services/api_service.dart';

const _kOllamaBase = 'http://localhost:11434';

const _genres = [
  {'id': 'epic',      'label': 'Epic',      'icon': '⚔️',  'color': 0xFFEF4444},
  {'id': 'chill',     'label': 'Chill',     'icon': '🌊',  'color': 0xFF0EA5E9},
  {'id': 'horror',    'label': 'Horror',    'icon': '👻',  'color': 0xFF8B5CF6},
  {'id': 'action',    'label': 'Action',    'icon': '🔥',  'color': 0xFFF97316},
  {'id': 'adventure', 'label': 'Adventure', 'icon': '🗺️',  'color': 0xFF10B981},
  {'id': 'puzzle',    'label': 'Puzzle',    'icon': '🧩',  'color': 0xFF6366F1},
  {'id': 'retro',     'label': 'Retro',     'icon': '👾',  'color': 0xFFF59E0B},
];

class SoundForgeScreen extends StatefulWidget {
  final String? projectId;
  const SoundForgeScreen({super.key, this.projectId});
  @override
  State<SoundForgeScreen> createState() => _SoundForgeScreenState();
}

class _SoundForgeScreenState extends State<SoundForgeScreen> with TickerProviderStateMixin {
  late TabController _tab;
  final _promptCtrl = TextEditingController();
  final AudioPlayer _player = AudioPlayer();

  String _type  = 'music';
  String _genre = 'epic';
  bool _generating = false;
  String? _error;
  List<dynamic> _library = [];
  bool _loadingLib = false;
  String? _playingId;
  bool _isPlaying = false;
  Map<String, bool> _downloading = {};
  String? _newlyGeneratedId; // highlights the freshly created track

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _initAudio();
    _player.playerStateStream.listen((s) {
      if (mounted) setState(() => _isPlaying = s.playing);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLibrary();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _promptCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _initAudio() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  String? _token() {
    try { return context.read<AuthProvider>().token; } catch (_) { return null; }
  }

  Map<String, String> _authHeadersForUrl(String url) {
    final token = _token();
    if (token == null || token.trim().isEmpty) return {};
    // If the URL points to our API host, it likely requires auth.
    final u = url.toLowerCase();
    final isLocalApi =
        u.contains('localhost:3000') || u.contains('127.0.0.1:3000') || u.contains('10.0.2.2:3000');
    if (!isLocalApi) return {};
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> _loadLibrary() async {
    final token = _token();
    if (token == null) return;
    setState(() => _loadingLib = true);
    try {
      final res = widget.projectId != null && widget.projectId!.isNotEmpty && widget.projectId != 'library'
          ? await SoundForgeService.getProjectTracks(token: token, projectId: widget.projectId!)
          : await SoundForgeService.getLibrary(token: token);
      final data = res['data'];
      if (mounted) setState(() => _library = data is List ? data : []);
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingLib = false);
    }
  }

  Future<void> _generate() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;
    final token = _token();
    if (token == null) { setState(() => _error = 'Not authenticated'); return; }
    setState(() { _generating = true; _error = null; _newlyGeneratedId = null; });
    try {
      final res = await SoundForgeService.generateTrack(
        token: token, type: _type, genre: _genre, prompt: prompt,
        projectId: widget.projectId,
      );
      // Extract the new track ID from response
      final newTrack = res['data'] ?? res;
      final newId = (newTrack?['_id'] ?? newTrack?['id'])?.toString();
      _promptCtrl.clear();
      await _loadLibrary();
      if (newId != null) setState(() => _newlyGeneratedId = newId);
      _tab.animateTo(1);
      // Clear highlight after 8 seconds
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) setState(() => _newlyGeneratedId = null);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _playOrPause(dynamic track) async {
    final id = (track['_id'] ?? track['id'])?.toString() ?? '';
    final fileUrl = track['fileUrl']?.toString() ?? '';

    if (_playingId == id) {
      _isPlaying ? await _player.pause() : await _player.play();
      return;
    }

    await _player.stop();
    setState(() { _playingId = id; _isPlaying = false; });

    if (fileUrl.isNotEmpty) {
      final normalised = ApiService.normalizeImageUrl(fileUrl);
      try {
        final headers = _authHeadersForUrl(normalised);
        
        // Ensure volume is up and player is ready
        await _player.setVolume(1.0);
        
        await _player.setAudioSource(
          AudioSource.uri(
            Uri.parse(normalised),
            headers: headers.isEmpty ? null : headers,
          ),
          preload: true,
        );
        
        // Final check on volume and device output
        await _player.setVolume(1.0);
        await _player.setSpeed(1.0);
        
        await _player.play();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playback failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      // No real file — open prompt for Suno copy
      _copyPrompt(track);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No audio file yet — prompt copied! Paste in suno.ai'),
        backgroundColor: const Color(0xFFF97316),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _download(dynamic track) async {
    final id = (track['_id'] ?? track['id'])?.toString() ?? '';
    final fileUrl = track['fileUrl']?.toString() ?? '';
    if (fileUrl.isNotEmpty) {
      final url = ApiService.normalizeImageUrl(fileUrl);
      setState(() => _downloading[id] = true);
      try {
        final headers = _authHeadersForUrl(url);
        final res = await http.get(Uri.parse(url), headers: headers.isEmpty ? null : headers);
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw Exception('HTTP ${res.statusCode}');
        }

        final dir = await getTemporaryDirectory();
        final title = (track['title']?.toString() ?? 'track').replaceAll(' ', '_');
        final ext = url.contains('.mp3') ? 'mp3' : 'wav';
        final file = File('${dir.path}/$title.$ext');
        await file.writeAsBytes(res.bodyBytes);

        if (!mounted) return;
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'SoundForge track: ${track['title']?.toString() ?? ''}',
        );
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')));
      } finally {
        if (mounted) setState(() => _downloading[id] = false);
      }
    } else {
      // No file — open Suno
      final sunoUrl = Uri.parse('https://suno.ai');
      if (await canLaunchUrl(sunoUrl)) launchUrl(sunoUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _copyPrompt(dynamic track) {
    final prompt = track['prompt']?.toString() ?? '';
    if (prompt.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: prompt));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('✅ Prompt copied — paste in suno.ai'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _toggleFav(dynamic track) async {
    final token = _token();
    if (token == null) return;
    final id = (track['_id'] ?? track['id'])?.toString() ?? '';
    if (id.isEmpty) return;
    await SoundForgeService.toggleFavorite(token: token, trackId: id);
    _loadLibrary();
  }

  Future<void> _delete(dynamic track) async {
    final token = _token();
    if (token == null) return;
    final id = (track['_id'] ?? track['id'])?.toString() ?? '';
    if (id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1120),
        title: const Text('Delete track?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444)))),
        ],
      ),
    );
    if (ok == true) { await SoundForgeService.deleteTrack(token: token, trackId: id); _loadLibrary(); }
  }

  Color _gc(String id) => Color(
    (_genres.firstWhere((g) => g['id'] == id, orElse: () => {'color': 0xFF8B5CF6})['color'] as int));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070810),
      body: SafeArea(child: Column(children: [
        _buildHeader(),
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFF8B5CF6),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFF8B5CF6),
          tabs: const [Tab(text: '🎵 Generate'), Tab(text: '🎧 Library')],
        ),
        Expanded(child: TabBarView(controller: _tab, children: [
          _buildGenTab(),
          _buildLibTab(),
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
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('SoundForge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        Text('Studio Audio IA · Claude', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF8B5CF6))),
          const SizedBox(width: 6),
          Text('Claude Online', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold)),
        ]),
      ),
    ]),
  );

  Widget _buildGenTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Type
      Row(children: [
        Expanded(child: _typeBtn('music', '🎵', 'Music')),
        const SizedBox(width: 10),
        Expanded(child: _typeBtn('sfx', '💥', 'SFX')),
      ]),
      const SizedBox(height: 18),
      // Genre
      const Text('Genre', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: _genres.map((g) {
        final sel = _genre == g['id'];
        final col = Color(g['color'] as int);
        return GestureDetector(
          onTap: () => setState(() => _genre = g['id'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? col.withOpacity(0.2) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? col.withOpacity(0.6) : Colors.white.withOpacity(0.08)),
            ),
            child: Text('${g['icon']} ${g['label']}', style: TextStyle(color: sel ? col : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        );
      }).toList()),
      const SizedBox(height: 18),
      // Prompt
      const Text('Describe your sound', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: TextField(
          controller: _promptCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'e.g. "Epic boss fight with heavy drums and brass"',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 12),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ),
      const SizedBox(height: 14),
      if (_error != null) Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3))),
        child: Text(_error!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 12)),
      ),
      GestureDetector(
        onTap: (_generating || _promptCtrl.text.trim().isEmpty) ? null : _generate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: (_generating || _promptCtrl.text.trim().isEmpty) ? null : const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            color: (_generating || _promptCtrl.text.trim().isEmpty) ? Colors.white.withOpacity(0.06) : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: (_generating || _promptCtrl.text.trim().isEmpty) ? [] : [
              BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Center(child: _generating
            ? const Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Claude génère…', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ])
            : const Text('🎵 Générer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🤖 Claude → AI Prompt → Audio Generation', style: TextStyle(color: Color(0xFFC4B5FD), fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          const Text('• With SUNO_API_KEY: generates & plays real MP3\n• Without key: plays & downloads mock generated WAV\n• Tap ▶ to play or ⬇ to download', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11)),
        ]),
      ),
    ]),
  );

  Widget _typeBtn(String id, String icon, String label) {
    final sel = _type == id;
    return GestureDetector(
      onTap: () => setState(() => _type = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF8B5CF6).withOpacity(0.2) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? const Color(0xFF8B5CF6).withOpacity(0.5) : Colors.white.withOpacity(0.08)),
        ),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sel ? const Color(0xFFC4B5FD) : Colors.white54)),
        ]),
      ),
    );
  }

  Widget _buildLibTab() {
    if (_loadingLib) return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    if (_library.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🎧', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text('No tracks yet', style: TextStyle(color: Colors.white.withOpacity(0.3))),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () => _tab.animateTo(0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(12)),
          child: const Text('Generate First Track', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    ]));

    return RefreshIndicator(
      onRefresh: _loadLibrary,
      color: const Color(0xFF8B5CF6),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _library.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildTrackCard(_library[i]),
      ),
    );
  }

  Widget _buildTrackCard(dynamic track) {
    final id      = (track['_id'] ?? track['id'])?.toString() ?? '';
    final title   = track['title']?.toString() ?? 'Untitled';
    final genre   = track['genre']?.toString() ?? 'epic';
    final type    = track['type']?.toString() ?? 'music';
    final status  = track['status']?.toString() ?? 'ready';
    final prompt  = track['prompt']?.toString() ?? '';
    final fileUrl = track['fileUrl']?.toString() ?? '';
    final isFav   = track['isFavorite'] == true;
    final col     = _gc(genre);
    final isNew   = _newlyGeneratedId == id;
    final isPlaying = _playingId == id && _isPlaying;
    final isDl    = _downloading[id] == true;
    final hasFile = fileUrl.isNotEmpty;
    final genreData = _genres.firstWhere((g) => g['id'] == genre, orElse: () => {'icon': '🎵'});

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNew
            ? const Color(0xFF8B5CF6).withOpacity(0.12)
            : _playingId == id
                ? col.withOpacity(0.1)
                : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNew
              ? const Color(0xFF8B5CF6).withOpacity(0.6)
              : _playingId == id
                  ? col.withOpacity(0.4)
                  : Colors.white.withOpacity(0.07),
          width: isNew ? 2 : 1,
        ),
        boxShadow: isNew ? [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.2), blurRadius: 12, spreadRadius: 1)] : [],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Genre icon
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: col.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(genreData['icon'] as String, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
              if (isNew) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6), borderRadius: BorderRadius.circular(6)),
                  child: const Text('NEW ✨', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Text('${type.toUpperCase()} · $genre', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: (status == 'ready' ? const Color(0xFF10B981) : status == 'error' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status, style: TextStyle(
                  color: status == 'ready' ? const Color(0xFF10B981) : status == 'error' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                  fontSize: 9, fontWeight: FontWeight.bold,
                )),
              ),
            ]),
          ])),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play
              GestureDetector(
                onTap: () => _playOrPause(track),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: col.withOpacity(0.2), shape: BoxShape.circle),
                  child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: col, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              // Download
              if (hasFile) GestureDetector(
                onTap: isDl ? null : () => _download(track),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
                  child: isDl
                    ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                    : const Icon(Icons.download_rounded, color: Colors.white70, size: 18),
                ),
              ) else GestureDetector(
                onTap: () => _copyPrompt(track),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
                  child: const Icon(Icons.open_in_new_rounded, color: Colors.white38, size: 16),
                ),
              ),
              const SizedBox(width: 8),
              // Fav
              GestureDetector(
                onTap: () => _toggleFav(track),
                child: Container(
                   width: 32, height: 32,
                   alignment: Alignment.center,
                   child: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFav ? const Color(0xFFEF4444) : Colors.white24, size: 20),
                ),
              ),
              // Delete
              GestureDetector(
                onTap: () => _delete(track),
                child: Container(
                   width: 32, height: 32,
                   alignment: Alignment.center,
                   child: const Icon(Icons.delete_outline, color: Colors.white24, size: 20),
                ),
              ),
            ],
          ),
        ]),

        // Waveform
        if (prompt.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 28,
            child: Row(children: List.generate(48, (i) {
              final h = ((prompt.codeUnitAt(i % prompt.length) % 70) + 15) / 100;
              final active = isPlaying && (i % 5 == 0);
              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: active ? 300 : 0),
                  height: double.infinity,
                  child: FractionallySizedBox(
                    heightFactor: active ? h * 1.3 : h,
                    alignment: Alignment.center,
                    child: Container(decoration: BoxDecoration(
                      color: col.withOpacity(isPlaying ? 0.9 : 0.4),
                      borderRadius: BorderRadius.circular(2),
                    )),
                  ),
                ),
              ));
            })),
          ),
          const SizedBox(height: 8),
          // No file → show copy prompt button
          if (!hasFile) GestureDetector(
            onTap: () => _copyPrompt(track),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: col.withOpacity(0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.copy_rounded, color: col, size: 12),
                const SizedBox(width: 6),
                Text('Copy Suno Prompt → paste at suno.ai', style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}
