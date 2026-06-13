import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import 'ai_game_studio_service.dart';

// ─── Phase config ────────────────────────────────────────────────────────────
const _phases = ['gdd', 'scripts', 'assets', 'assembly', 'building'];
const _phaseLabels = {
  'gdd': 'Analyzing Prompt',
  'scripts': 'Writing C# Code',
  'assets': 'Generating Sprites & Audio',
  'assembly': 'Assembling Unity Project',
  'building': 'Compiling Game',
};
const _phaseIcons = {
  'gdd': '🧠',
  'scripts': '✍️',
  'assets': '🎨',
  'assembly': '🔧',
  'building': '🏗️',
};

// ─── Colors ──────────────────────────────────────────────────────────────────
const _bg     = Color(0xFF060B14);
const _card   = Color(0xFF0D1526);
const _border = Color(0xFF1E2D4A);
const _cyan   = Color(0xFF00E5FF);
const _purple = Color(0xFF7C3AED);
const _green  = Color(0xFF00E676);
const _tp     = Color(0xFFE2E8F0);
const _ts     = Color(0xFF8B9EC0);

class AiGameStudioScreen extends StatefulWidget {
  const AiGameStudioScreen({super.key});
  @override
  State<AiGameStudioScreen> createState() => _AiGameStudioScreenState();
}

class _AiGameStudioScreenState extends State<AiGameStudioScreen>
    with TickerProviderStateMixin {
  final _promptCtrl = TextEditingController();
  final _scroll     = ScrollController();

  String  _genre            = '';
  bool    _withSprites      = false;
  String? _userSpriteB64;
  String? _userSpriteFile;

  bool    _busy     = false;
  bool    _done     = false;
  String? _pid;
  String  _phase    = 'queued';
  String  _log      = '';
  String? _error;
  String? _title;
  String? _desc;

  Timer? _poll;
  late AnimationController _pulse;
  late AnimationController _shimmer;

  static const _genres = [
    ('🏃', 'Runner'), ('🔫', 'Shooter'), ('🦘', 'Platformer'),
    ('🧩', 'Puzzle'), ('⚔️', 'RPG'),     ('🌊', 'Survival'),
  ];

  @override
  void initState() {
    super.initState();
    _pulse   = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _promptCtrl.dispose();
    _scroll.dispose();
    _pulse.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  // ─── Pick sprite ──────────────────────────────────────────────────────────
  Future<void> _pickSprite() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() {
      _userSpriteB64  = base64Encode(bytes);
      _userSpriteFile = img.name;
    });
  }

  // ─── Generate ─────────────────────────────────────────────────────────────
  Future<void> _generate() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;
    final token = context.read<AuthProvider>().token ?? '';
    if (token.isEmpty) return;

    setState(() { _busy = true; _done = false; _error = null; _phase = 'gdd'; _log = 'Sending to AI…'; });

    try {
      final resp = await AiGameStudioService.generateFromScratch(
        token: token, prompt: prompt,
        withAiSprites: _withSprites, userSpriteBase64: _userSpriteB64,
      );
      final data = resp['data'] as Map<String, dynamic>?;
      _pid = data?['projectId'] as String?;
      final gdd = data?['gdd'] as Map<String, dynamic>?;
      if (gdd != null) setState(() { _title = gdd['title'] as String?; _desc = gdd['description'] as String?; });
      _startPoll(token);
    } catch (e) {
      setState(() { _busy = false; _error = e.toString(); });
    }
  }

  void _startPoll(String token) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_pid == null) return;
      try {
        final resp = await AiGameStudioService.pollStatus(token: token, projectId: _pid!);
        final d = resp['data'] as Map<String, dynamic>? ?? {};
        final phase  = d['scratchPhase'] as String? ?? 'queued';
        final status = d['status']       as String? ?? '';
        setState(() {
          _phase = phase;
          _log   = d['buildLogLastLine'] as String? ?? '';
          _title = d['title']            as String? ?? _title;
          _desc  = d['description']      as String? ?? _desc;
        });
        if (status == 'ready')  { _poll?.cancel(); setState(() { _busy = false; _done = true; }); }
        if (status == 'failed') { _poll?.cancel(); setState(() { _busy = false; _error = d['error'] as String? ?? 'Build failed'; }); }
      } catch (_) {}
    });
  }

  void _reset() {
    _poll?.cancel();
    setState(() { _busy = false; _done = false; _error = null; _pid = null; _phase = 'queued'; _log = ''; _title = null; _desc = null; });
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(controller: _scroll, slivers: [
        _appBar(),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(delegate: SliverChildListDelegate([
            const SizedBox(height: 8),
            _heroTitle(),
            const SizedBox(height: 24),
            _promptCard(),
            const SizedBox(height: 14),
            _optionsRow(),
            const SizedBox(height: 18),
            _generateBtn(),
            if (_busy || _done || _error != null) ...[const SizedBox(height: 28), _progress()],
            if (_done)   ...[const SizedBox(height: 20), _readyCard()],
            if (_error != null) ...[const SizedBox(height: 12), _errorCard()],
            const SizedBox(height: 80),
          ])),
        ),
      ]),
    );
  }

  // ─── App bar ──────────────────────────────────────────────────────────────
  SliverAppBar _appBar() => SliverAppBar(
    backgroundColor: _bg, elevation: 0, pinned: true,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _tp, size: 20),
      onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
    ),
    title: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, _cyan]), borderRadius: BorderRadius.circular(20)),
        child: const Text('AI STUDIO', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      ),
      const SizedBox(width: 10),
      const Text('Unity Game Studio', style: TextStyle(color: _tp, fontSize: 17, fontWeight: FontWeight.w600)),
    ]),
    actions: [
      if (_busy || _done) IconButton(icon: const Icon(Icons.refresh_rounded, color: _ts), onPressed: _reset),
    ],
  );

  // ─── Hero title ───────────────────────────────────────────────────────────
  Widget _heroTitle() => AnimatedBuilder(
    animation: _pulse,
    builder: (_, __) => Column(children: [
      ShaderMask(
        shaderCallback: (r) => LinearGradient(
          colors: [_cyan, _purple, Color.lerp(_purple, _cyan, _pulse.value)!],
        ).createShader(r),
        child: const Text('Prompt → Unity Game\nIn One Click',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, height: 1.25)),
      ),
      const SizedBox(height: 10),
      Text('Claude writes C# • Gemini generates sprites\nUnity compiles a real playable build',
        textAlign: TextAlign.center,
        style: TextStyle(color: _ts.withOpacity(0.85), fontSize: 13, height: 1.5)),
    ]),
  );

  // ─── Prompt card ─────────────────────────────────────────────────────────
  Widget _promptCard() => AnimatedBuilder(
    animation: _pulse,
    builder: (_, __) => Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [_cyan.withOpacity(0.12 + _pulse.value * 0.07), _purple.withOpacity(0.08 + _pulse.value * 0.04)]),
        border: Border.all(color: _cyan.withOpacity(0.25 + _pulse.value * 0.2), width: 1.5),
      ),
      child: TextField(
        controller: _promptCtrl, maxLines: 4, maxLength: 500, enabled: !_busy,
        style: const TextStyle(color: _tp, fontSize: 15, height: 1.6),
        decoration: InputDecoration(
          hintText: 'Describe your game…\ne.g. "A neon space shooter where enemies swarm and you collect power-ups"',
          hintStyle: TextStyle(color: _ts.withOpacity(0.6), fontSize: 13),
          border: InputBorder.none, contentPadding: const EdgeInsets.all(18),
          counterStyle: TextStyle(color: _ts.withOpacity(0.4), fontSize: 11),
        ),
      ),
    ),
  );

  // ─── Options row ─────────────────────────────────────────────────────────
  Widget _optionsRow() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Genre', style: TextStyle(color: _ts, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
    const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: _genres.map((g) {
      final sel = _genre == g.$2;
      return GestureDetector(
        onTap: () { if (!_busy) setState(() => _genre = sel ? '' : g.$2); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: sel ? const LinearGradient(colors: [_purple, _cyan]) : null,
            color: sel ? null : _card,
            border: Border.all(color: sel ? Colors.transparent : _border),
          ),
          child: Text('${g.$1} ${g.$2}', style: TextStyle(color: sel ? Colors.white : _ts, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      );
    }).toList()),

    const SizedBox(height: 14),
    Row(children: [
      // AI sprites toggle
      Expanded(child: GestureDetector(
        onTap: () { if (!_busy) setState(() => _withSprites = !_withSprites); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36, height: 20,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: _withSprites ? _cyan : _border),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: _withSprites ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(width: 16, height: 16, margin: const EdgeInsets.all(2), decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('✨ AI Sprites', style: TextStyle(color: _tp, fontSize: 13, fontWeight: FontWeight.w500))),
          ]),
        ),
      )),
      const SizedBox(width: 10),
      // Sprite picker
      GestureDetector(
        onTap: _busy ? null : _pickSprite,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _userSpriteB64 != null ? _green.withOpacity(0.12) : _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _userSpriteB64 != null ? _green : _border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.image_rounded, color: _userSpriteB64 != null ? _green : _ts, size: 18),
            const SizedBox(width: 6),
            Text(_userSpriteB64 != null ? '✓ Sprite' : 'My Sprite',
              style: TextStyle(color: _userSpriteB64 != null ? _green : _ts, fontSize: 13)),
          ]),
        ),
      ),
    ]),
  ]);

  // ─── Generate button ──────────────────────────────────────────────────────
  Widget _generateBtn() {
    final ready = !_busy && _promptCtrl.text.trim().isNotEmpty;
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) => GestureDetector(
        onTap: ready ? _generate : null,
        child: Container(
          width: double.infinity, height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment(-1 + _shimmer.value * 2, 0),
              end:   Alignment( 1 + _shimmer.value * 2, 0),
              colors: ready ? [_purple, _cyan, _purple, _cyan] : [_border, _border],
            ),
            boxShadow: ready ? [BoxShadow(color: _cyan.withOpacity(0.25), blurRadius: 20, spreadRadius: 1)] : [],
          ),
          child: Center(child: _busy
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Generate My Game', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
          ),
        ),
      ),
    );
  }

  // ─── Progress section ─────────────────────────────────────────────────────
  Widget _progress() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🤖', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Text('AI is crafting your game', style: TextStyle(color: _tp, fontSize: 15, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (_busy) AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _cyan.withOpacity(0.4 + _pulse.value * 0.6)),
            ),
          ),
        ]),
        if (_title != null) ...[
          const SizedBox(height: 6),
          Text('"$_title"', style: const TextStyle(color: _cyan, fontSize: 13, fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 18),
        ..._phases.map(_phaseRow),
        if (_log.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
            child: Text(_log, style: const TextStyle(color: _ts, fontSize: 11, fontFamily: 'monospace'), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ]),
    );
  }

  Widget _phaseRow(String phase) {
    final pi = _phases.indexOf(phase);
    final ci = _phases.indexOf(_phase);
    final isDone   = ci > pi || _done;
    final isActive = _phase == phase && _busy;
    final dotColor = isDone ? _green : isActive ? _cyan : _border;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: 24, height: 24,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          child: Center(child: isDone
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 12)
            : isActive
              ? AnimatedBuilder(animation: _pulse, builder: (_, __) => Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.7 + _pulse.value * 0.3)),
                ))
              : const SizedBox.shrink()),
        ),
        const SizedBox(width: 12),
        Text('${_phaseIcons[phase]} ${_phaseLabels[phase]}',
          style: TextStyle(
            color: isDone ? _green : isActive ? _tp : _ts,
            fontSize: 13, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
        const Spacer(),
        if (isDone) const Text('✓', style: TextStyle(color: _green, fontSize: 12)),
        if (isActive) const SizedBox(width: 12, height: 12,
          child: CircularProgressIndicator(color: _cyan, strokeWidth: 1.5)),
      ]),
    );
  }

  // ─── Ready card ───────────────────────────────────────────────────────────
  Widget _readyCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [_green.withOpacity(0.1), _cyan.withOpacity(0.07)]),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _green.withOpacity(0.4), width: 1.5),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _green.withOpacity(0.15), border: Border.all(color: _green.withOpacity(0.5))),
          child: const Center(child: Text('🎮', style: TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title ?? 'Your Game', style: const TextStyle(color: _tp, fontSize: 17, fontWeight: FontWeight.w700)),
          if (_desc != null) Text(_desc!, style: const TextStyle(color: _ts, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
      ]),
      const SizedBox(height: 16),
      const Divider(color: _border),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _Btn(label: '▶ Play Now',
          gradient: const LinearGradient(colors: [_green, _cyan]),
          onTap: () => context.push('/play-webgl', extra: {'projectId': _pid}))),
        const SizedBox(width: 10),
        _Btn(label: '📦 Downloads', onTap: () => context.push('/build-results')),
        const SizedBox(width: 10),
        _Btn(label: '🔄 New Game', onTap: _reset),
      ]),
    ]),
  );

  // ─── Error card ───────────────────────────────────────────────────────────
  Widget _errorCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.red.withOpacity(0.3))),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(_error ?? '', style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
      TextButton(onPressed: _reset, child: const Text('Retry', style: TextStyle(color: _cyan))),
    ]),
  );
}

// ─── Small action button ──────────────────────────────────────────────────────
class _Btn extends StatelessWidget {
  final String label;
  final Gradient? gradient;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.onTap, this.gradient});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: gradient, color: gradient == null ? _card : null,
        borderRadius: BorderRadius.circular(12),
        border: gradient == null ? Border.all(color: _border) : null,
      ),
      child: Text(label, style: TextStyle(color: gradient != null ? Colors.white : _tp, fontSize: 13, fontWeight: FontWeight.w600)),
    ),
  );
}
