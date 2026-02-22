import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/scratch_game_service.dart';

// ─── Genre option model ───────────────────────────────────────────────────────
class _Genre {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const _Genre(this.id, this.label, this.icon, this.color);
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class AiScratchGameScreen extends StatefulWidget {
  const AiScratchGameScreen({super.key});

  @override
  State<AiScratchGameScreen> createState() => _AiScratchGameScreenState();
}

class _AiScratchGameScreenState extends State<AiScratchGameScreen>
    with TickerProviderStateMixin {
  // Controllers
  final _promptCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Config
  String _selectedGenre = 'auto';
  String _buildTarget = 'webgl';
  double _difficulty = 0.5;
  bool _has2d = true;

  // State
  bool _previewing = false;
  bool _generating = false;
  Map<String, dynamic>? _gdd;
  String? _error;

  // Animation
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  static const _genres = <_Genre>[
    _Genre('auto', 'Auto Detect', Icons.auto_awesome, Color(0xFF8B5CF6)),
    _Genre('platformer2d', 'Platformer', Icons.sports_gymnastics, Color(0xFF22C55E)),
    _Genre('runner2d', 'Endless Runner', Icons.directions_run, Color(0xFFF59E0B)),
    _Genre('topdown2d', 'Top-Down', Icons.gamepad, Color(0xFF3B82F6)),
    _Genre('puzzle2d', 'Puzzle', Icons.extension, Color(0xFFEC4899)),
    _Genre('survival2d', 'Survival', Icons.shield, Color(0xFFEF4444)),
    _Genre('rpg2d', 'RPG', Icons.auto_stories, Color(0xFF06B6D4)),
    _Genre('racing2d', 'Racing', Icons.speed, Color(0xFFFF6B35)),
    _Genre('fighter2d', 'Fighter', Icons.sports_kabaddi, Color(0xFFDC2626)),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  String get _currentPrompt {
    var p = _promptCtrl.text.trim();
    if (_selectedGenre != 'auto') {
      final g = _genres.firstWhere((e) => e.id == _selectedGenre, orElse: () => _genres.first);
      if (!p.toLowerCase().contains(g.label.toLowerCase())) {
        p = '${g.label} game: $p';
      }
    }
    if (_has2d && !p.contains('2d') && !p.contains('2D')) p += ' (2D)';
    final diff = _difficulty < 0.35 ? 'easy' : _difficulty > 0.7 ? 'hard' : 'medium';
    p += ', difficulty: $diff';
    return p.trim();
  }

  // ─── Actions ───────────────────────────────────────────────────────────────
  Future<void> _previewGdd() async {
    final rawPrompt = _promptCtrl.text.trim();
    if (rawPrompt.isEmpty) {
      setState(() => _error = 'Please describe your game first.');
      return;
    }
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Session expired. Please sign in again.');
      return;
    }

    setState(() { _previewing = true; _error = null; _gdd = null; });

    try {
      final res = await ScratchGameService.previewGdd(
        token: token,
        prompt: _currentPrompt,
      );
      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map) {
        final data = res['data'] as Map;
        setState(() => _gdd = Map<String, dynamic>.from(data['gdd'] as Map? ?? {}));
        // Scroll to GDD preview
        await Future.delayed(const Duration(milliseconds: 100));
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      } else {
        setState(() => _error = res['message']?.toString() ?? 'Failed to generate preview.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _generate() async {
    final rawPrompt = _promptCtrl.text.trim();
    if (rawPrompt.isEmpty) {
      setState(() => _error = 'Please describe your game first.');
      return;
    }
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Session expired. Please sign in again.');
      return;
    }

    setState(() { _generating = true; _error = null; });

    try {
      final res = await ScratchGameService.generateFromScratch(
        token: token,
        prompt: _currentPrompt,
        buildTarget: _buildTarget,
      );
      if (!mounted) return;

      final data = res['data'];
      final projectId = (data is Map) ? data['projectId']?.toString() : null;
      if (res['success'] == true && projectId != null && projectId.isNotEmpty) {
        final gddFromRes = (data is Map && data['gdd'] is Map)
            ? Map<String, dynamic>.from(data['gdd'] as Map)
            : _gdd;
        context.go('/build-progress', extra: {
          'projectId': projectId,
          'prompt': rawPrompt,
          'gdd': gddFromRes,
        });
        return;
      }
      setState(() => _error = res['message']?.toString() ?? 'Failed to start generation.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final surfaceColor = isLight ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final cardColor = isLight ? Colors.white : const Color(0xFF1E293B);
    final accentPurple = const Color(0xFF8B5CF6);
    final accentGreen = const Color(0xFF22C55E);

    return Scaffold(
      backgroundColor: surfaceColor,
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: surfaceColor,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: cs.onSurface, size: 20),
              onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentPurple.withOpacity(0.15),
                      accentGreen.withOpacity(0.08),
                      surfaceColor,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [accentPurple, accentGreen]),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('AI Game From Scratch',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                  letterSpacing: -0.5,
                                )),
                              Text('Describe any game — AI builds it entirely',
                                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                            ]),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(delegate: SliverChildListDelegate([
              const SizedBox(height: 16),

              // ── Error banner
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: TextStyle(color: cs.onSurface, fontSize: 13))),
                    GestureDetector(
                      onTap: () => setState(() => _error = null),
                      child: Icon(Icons.close, color: cs.onSurfaceVariant, size: 18),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // ── Prompt card ──────────────────────────────────────────────
              _SectionCard(
                color: cardColor,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _SectionHeader(icon: Icons.edit_note_rounded, label: 'Describe Your Game', color: accentPurple),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentPurple.withOpacity(0.3)),
                    ),
                    child: TextField(
                      controller: _promptCtrl,
                      minLines: 4,
                      maxLines: 10,
                      style: TextStyle(fontSize: 15, color: cs.onSurface, height: 1.5),
                      decoration: InputDecoration(
                        hintText: 'e.g. "A ninja platformer in a dark forest with coin collection and enemies that shoot arrows. Fast-paced with double jump and wall sliding."',
                        hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6), fontSize: 13, height: 1.5),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '💡 Be specific: theme, mechanics, art style, enemies, power-ups...',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
                  ),
                ]),
              ),

              const SizedBox(height: 12),

              // ── Genre selector ───────────────────────────────────────────
              _SectionCard(
                color: cardColor,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _SectionHeader(icon: Icons.category_rounded, label: 'Game Genre (optional)', color: accentGreen),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: _genres.map((g) {
                    final selected = _selectedGenre == g.id;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedGenre = g.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? g.color.withOpacity(0.15) : surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? g.color : cs.outlineVariant.withOpacity(0.5),
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(g.icon, size: 14, color: selected ? g.color : cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(g.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? g.color : cs.onSurfaceVariant,
                            )),
                        ]),
                      ),
                    );
                  }).toList()),
                ]),
              ),

              const SizedBox(height: 12),

              // ── Config ───────────────────────────────────────────────────
              _SectionCard(
                color: cardColor,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _SectionHeader(icon: Icons.tune_rounded, label: 'Configuration', color: const Color(0xFFF59E0B)),
                  const SizedBox(height: 16),

                  // Difficulty
                  Row(children: [
                    Icon(Icons.trending_up, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text('Difficulty', style: TextStyle(fontSize: 13, color: cs.onSurface, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _difficulty < 0.35
                            ? const Color(0xFF22C55E).withOpacity(0.15)
                            : _difficulty > 0.7
                                ? const Color(0xFFEF4444).withOpacity(0.15)
                                : const Color(0xFFF59E0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _difficulty < 0.35 ? 'Easy' : _difficulty > 0.7 ? 'Hard' : 'Medium',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _difficulty < 0.35
                              ? const Color(0xFF22C55E)
                              : _difficulty > 0.7
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ]),
                  Slider(
                    value: _difficulty,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    activeColor: _difficulty < 0.35
                        ? const Color(0xFF22C55E)
                        : _difficulty > 0.7
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFF59E0B),
                    onChanged: (v) => setState(() => _difficulty = v),
                  ),

                  const SizedBox(height: 8),

                  // Build target
                  Row(children: [
                    Icon(Icons.build_circle_outlined, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text('Build Target', style: TextStyle(fontSize: 13, color: cs.onSurface, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    _ToggleChip(
                      label: 'WebGL',
                      selected: _buildTarget == 'webgl',
                      onTap: () => setState(() => _buildTarget = 'webgl'),
                      color: accentPurple,
                    ),
                    const SizedBox(width: 8),
                    _ToggleChip(
                      label: 'Android',
                      selected: _buildTarget == 'android_apk',
                      onTap: () => setState(() => _buildTarget = 'android_apk'),
                      color: const Color(0xFF22C55E),
                    ),
                  ]),
                ]),
              ),

              const SizedBox(height: 12),

              // ── GDD Preview (shown after preview button) ─────────────────
              if (_gdd != null) ...[
                _GddPreviewCard(gdd: _gdd!, surfaceColor: surfaceColor),
                const SizedBox(height: 12),
              ],

              // ── Action buttons ───────────────────────────────────────────
              Row(children: [
                // Preview button
                Expanded(
                  child: _ActionButton(
                    label: _previewing ? 'Analysing…' : '🔍 Preview GDD',
                    loading: _previewing,
                    outlined: true,
                    color: accentPurple,
                    onTap: (_previewing || _generating) ? null : _previewGdd,
                  ),
                ),
                const SizedBox(width: 12),
                // Generate button
                Expanded(
                  flex: 2,
                  child: _ActionButton(
                    label: _generating ? 'Generating…' : '✨ Generate Game',
                    loading: _generating,
                    outlined: false,
                    color: accentGreen,
                    onTap: (_previewing || _generating) ? null : _generate,
                  ),
                ),
              ]),

              const SizedBox(height: 12),
              Center(
                child: Text(
                  'AI will generate C# scripts, scene, and build your game automatically.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            ])),
          ),
        ],
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final Color color;
  const _SectionCard({required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHeader({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
    ]);
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  const _ToggleChip({required this.label, required this.selected, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Theme.of(context).colorScheme.outlineVariant, width: selected ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool outlined;
  final Color color;
  final VoidCallback? onTap;
  const _ActionButton({required this.label, required this.loading, required this.outlined, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          gradient: outlined ? null : LinearGradient(colors: [color, color.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          color: outlined ? Colors.transparent : null,
          borderRadius: BorderRadius.circular(14),
          border: outlined ? Border.all(color: color, width: 1.5) : null,
          boxShadow: outlined ? null : [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: loading
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(outlined ? color : Colors.white)))
              : Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: outlined ? color : Colors.white)),
        ),
      ),
    );
  }
}

// ─── GDD Preview card ─────────────────────────────────────────────────────────
class _GddPreviewCard extends StatelessWidget {
  final Map<String, dynamic> gdd;
  final Color surfaceColor;
  const _GddPreviewCard({required this.gdd, required this.surfaceColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cardColor = isLight ? Colors.white : const Color(0xFF1E293B);
    final purpleAccent = const Color(0xFF8B5CF6);

    final mechanics = (gdd['mechanics'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final sceneObjs = (gdd['sceneObjects'] as List?)?.map((e) => e as Map).toList() ?? [];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: purpleAccent.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: purpleAccent.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [purpleAccent.withOpacity(0.15), const Color(0xFF22C55E).withOpacity(0.08)]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            const Icon(Icons.document_scanner_rounded, size: 18, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Text('Game Design Document', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: purpleAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Text('AI Generated', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Title + genre
            Text(gdd['title']?.toString() ?? 'Untitled Game',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface)),
            const SizedBox(height: 4),
            Row(children: [
              _GddBadge(gdd['genre']?.toString() ?? '', const Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              _GddBadge(gdd['theme']?.toString() ?? '', const Color(0xFF22C55E)),
            ]),
            const SizedBox(height: 10),

            Text(gdd['description']?.toString() ?? '',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.5)),
            const SizedBox(height: 14),

            // Stats grid
            _StatsGrid(gdd: gdd),
            const SizedBox(height: 14),

            // Mechanics
            if (mechanics.isNotEmpty) ...[
              Text('Mechanics', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: mechanics.map((m) => _GddBadge(m, const Color(0xFF3B82F6))).toList(),
              ),
              const SizedBox(height: 14),
            ],

            // Colors
            Row(children: [
              Text('Colors', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(width: 12),
              _ColorDot(gdd['primaryColor']?.toString()),
              const SizedBox(width: 6),
              _ColorDot(gdd['backgroundColor']?.toString()),
              const SizedBox(width: 6),
              _ColorDot(gdd['playerColor']?.toString()),
              const SizedBox(width: 6),
              _ColorDot(gdd['enemyColor']?.toString()),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _GddBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _GddBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final String? hex;
  const _ColorDot(this.hex);

  Color _parse() {
    try {
      final h = (hex ?? '#888888').replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) { return Colors.grey; }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22, height: 22,
      decoration: BoxDecoration(
        color: _parse(),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: _parse().withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> gdd;
  const _StatsGrid({required this.gdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = [
      ('⚡ Speed', '${gdd['playerSpeed'] ?? 5.0}'),
      ('🦘 Jump', '${gdd['jumpForce'] ?? 8.0}'),
      ('🌍 Gravity', '${gdd['gravity'] ?? -9.8}'),
      ('👾 Enemies', '${gdd['enemyCount'] ?? 0}'),
      ('🎯 Difficulty', _diffLabel(gdd['difficulty'])),
      ('📷 Camera', '${gdd['cameraMode'] ?? 'follow'}'),
      ('🎵 Audio', '${gdd['audioTheme'] ?? 'action'}'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: RichText(text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(text: '${item.$1}  ', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            TextSpan(text: item.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface)),
          ],
        )),
      )).toList(),
    );
  }

  String _diffLabel(dynamic v) {
    final d = v is num ? v.toDouble() : 0.5;
    return d < 0.35 ? 'Easy' : d > 0.7 ? 'Hard' : 'Medium';
  }
}
