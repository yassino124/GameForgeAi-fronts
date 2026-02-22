import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/coach_overlay_controller.dart';
import '../../core/themes/app_theme.dart';

class CoachGlobalOverlay extends StatefulWidget {
  const CoachGlobalOverlay({super.key});

  @override
  State<CoachGlobalOverlay> createState() => _CoachGlobalOverlayState();
}

class _CoachGlobalOverlayState extends State<CoachGlobalOverlay> with SingleTickerProviderStateMixin {
  static const _kPosKey = 'gameforge.coachOrbPos.v1';

  late final AnimationController _pulse;

  Offset _pos = const Offset(0, 0);
  bool _loaded = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _loadPos();
  }

  Future<void> _loadPos() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = (p.getString(_kPosKey) ?? '').trim();
      final parts = raw.split(',');
      if (parts.length == 2) {
        final dx = double.tryParse(parts[0]);
        final dy = double.tryParse(parts[1]);
        if (dx != null && dy != null) {
          _pos = Offset(dx, dy);
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loaded = true);
  }

  Future<void> _savePos(Offset v) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kPosKey, '${v.dx},${v.dy}');
    } catch (_) {}
  }

  Offset _clampToScreen({required Offset proposed, required Size screen, required double orbSize, required EdgeInsets safe}) {
    final minX = safe.left + 8;
    final minY = safe.top + 8;
    final maxX = screen.width - safe.right - orbSize - 8;
    final maxY = screen.height - safe.bottom - orbSize - 8;

    final x = proposed.dx.clamp(minX, math.max(minX, maxX));
    final y = proposed.dy.clamp(minY, math.max(minY, maxY));
    return Offset(x.toDouble(), y.toDouble());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final coach = context.watch<CoachOverlayController>();

    if (!coach.overlayEnabled) return const SizedBox.shrink();

    final token = (auth.token ?? '').trim();
    final screen = MediaQuery.of(context).size;
    final safe = MediaQuery.of(context).padding;

    const orb = 64.0;

    const bubbleW = 260.0;
    const bubbleH = 86.0;

    if (_pos == const Offset(0, 0)) {
      final defaultPos = Offset(screen.width - safe.right - orb - 18, safe.top + 104);
      _pos = _clampToScreen(proposed: defaultPos, screen: screen, orbSize: orb, safe: safe);
    } else {
      _pos = _clampToScreen(proposed: _pos, screen: screen, orbSize: orb, safe: safe);
    }

    final enabled = token.isNotEmpty;

    Widget miniPanel() {
      if (!enabled) return const SizedBox.shrink();
      if (!_expanded) return const SizedBox.shrink();

      final items = coach.messages.length <= 3 ? coach.messages : coach.messages.sublist(coach.messages.length - 3);

      Widget pill({required IconData icon, required String label, required VoidCallback? onTap, Color? glowColor}) {
        final c = glowColor ?? cs.primary;
        return GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surface.withOpacity(0.62),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.40)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 18, offset: const Offset(0, 12)),
                    BoxShadow(color: c.withOpacity(0.12), blurRadius: 26, offset: const Offset(0, 16)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: cs.onSurface),
                    const SizedBox(width: 8),
                    Text(label, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface)),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 292,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.58),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.40)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.26), blurRadius: 26, offset: const Offset(0, 18)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Coach', style: AppTypography.subtitle2.copyWith(fontWeight: FontWeight.w900, color: cs.onSurface)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () async {
                        setState(() => _expanded = false);
                        await coach.hideOverlay();
                      },
                      child: Icon(Icons.close_rounded, size: 18, color: cs.onSurface.withOpacity(0.80)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (items.isNotEmpty)
                  ...items.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        (m.role == 'user') ? 'You: ${m.text}' : 'Coach: ${m.text}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: cs.onSurface.withOpacity(m.role == 'user' ? 0.78 : 0.92),
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    'Tip: ask for “best settings” or “make it harder”.',
                    style: AppTypography.caption.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    pill(
                      icon: coach.handsFree ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      label: coach.handsFree ? 'Hands‑free: ON' : 'Hands‑free: OFF',
                      glowColor: coach.handsFree ? cs.primary : cs.outline,
                      onTap: () async {
                        try {
                          await HapticFeedback.selectionClick();
                          SystemSound.play(SystemSoundType.click);
                        } catch (_) {}
                        await coach.setHandsFree(!coach.handsFree, token: token);
                      },
                    ),
                    pill(
                      icon: Icons.refresh_rounded,
                      label: 'Reset',
                      glowColor: cs.secondary,
                      onTap: () async {
                        try {
                          await HapticFeedback.selectionClick();
                          SystemSound.play(SystemSoundType.click);
                        } catch (_) {}
                        await coach.reset();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget captionBubble() {
      final show = enabled &&
          (coach.handsFree || coach.listening || coach.waitingReply || coach.speaking || coach.draftUser.trim().isNotEmpty || coach.draftAssistant.trim().isNotEmpty);
      if (!show) return const SizedBox.shrink();

      String text;
      if (coach.listening) {
        final t = coach.draftUser.trim();
        text = t.isEmpty ? 'Listening…' : t;
      } else if (coach.waitingReply) {
        final t = coach.draftAssistant.trim();
        text = t.isEmpty ? 'Thinking…' : t;
      } else if (coach.speaking) {
        final t = coach.messages.isNotEmpty ? coach.messages.last.text.trim() : coach.draftAssistant.trim();
        text = t.isEmpty ? 'Speaking…' : t;
      } else {
        final t = coach.draftAssistant.trim();
        if (t.isNotEmpty) {
          text = t;
        } else {
          text = coach.handsFree ? 'LIVE • Say something…' : 'Ready';
        }
      }

      final maxChars = 150;
      if (text.length > maxChars) {
        text = '${text.substring(0, maxChars)}…';
      }

      final bg = cs.surface.withOpacity(coach.handsFree ? 0.62 : 0.55);

      return IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) {
            final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
            final slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(fade);
            return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: child));
          },
          child: ClipRRect(
            key: ValueKey<String>(text),
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 22, offset: const Offset(0, 14)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (coach.handsFree)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (coach.listening ? cs.error : cs.primary).withOpacity(0.90),
                              boxShadow: [
                                BoxShadow(
                                  color: (coach.listening ? cs.error : cs.primary).withOpacity(0.28),
                                  blurRadius: 10,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (coach.handsFree) const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          text,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body2.copyWith(
                            color: cs.onSurface,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget orbCore({required bool down}) {
      return AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final p = _pulse.value;
          final listening = coach.listening;
          final thinking = coach.waitingReply;
          final ringColor = listening
              ? cs.error
              : thinking
                  ? cs.secondary
                  : cs.primary;
          final glow = 0.10 + p * 0.18;
          final scale = down ? 0.96 : (0.98 + p * 0.03);

          return AnimatedScale(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            scale: scale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                IgnorePointer(
                  child: SizedBox(
                    width: orb + 48,
                    height: orb + 48,
                    child: _SiriWaveform(
                      t: p,
                      color: ringColor,
                      intensity: listening ? 1.0 : (thinking ? 0.55 : (coach.handsFree ? 0.38 : 0.22)),
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      width: orb,
                      height: orb,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accent.withOpacity(listening ? 0.85 : 0.95),
                            ringColor.withOpacity(0.92),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.24), blurRadius: 22, offset: const Offset(0, 14)),
                          BoxShadow(color: ringColor.withOpacity(glow), blurRadius: 34, offset: const Offset(0, 20)),
                        ],
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Icon(
                        listening
                            ? Icons.hearing_rounded
                            : (coach.handsFree ? Icons.auto_awesome_rounded : Icons.mic_rounded),
                        color: cs.onPrimary,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    final preferLeft = _pos.dx > (screen.width * 0.55);
    final preferAbove = _pos.dy > (screen.height * 0.55);

    final gap = 10.0;

    var bubbleLeft = preferLeft ? -(bubbleW + gap) : (orb + gap);
    var bubbleTop = preferAbove ? -(bubbleH + gap) : (orb + gap);

    // Clamp bubble absolute rect within screen.
    final absLeft = _pos.dx + bubbleLeft;
    final absTop = _pos.dy + bubbleTop;
    final minX = safe.left + 8;
    final maxX = screen.width - safe.right - bubbleW - 8;
    final minY = safe.top + 8;
    final maxY = screen.height - safe.bottom - bubbleH - 8;

    final clampedAbsLeft = absLeft.clamp(minX, math.max(minX, maxX)).toDouble();
    final clampedAbsTop = absTop.clamp(minY, math.max(minY, maxY)).toDouble();

    bubbleLeft = clampedAbsLeft - _pos.dx;
    bubbleTop = clampedAbsTop - _pos.dy;

    // Panel positioning (bigger): prefer opposite side of screen edge.
    final panelW = 292.0;
    final panelH = 210.0;
    final panelGap = 12.0;
    var panelLeft = preferLeft ? -(panelW + panelGap) : (orb + panelGap);
    var panelTop = preferAbove ? -(panelH + panelGap) : (orb + panelGap);
    final panelAbsLeft = _pos.dx + panelLeft;
    final panelAbsTop = _pos.dy + panelTop;
    final panelMinX = safe.left + 8;
    final panelMaxX = screen.width - safe.right - panelW - 8;
    final panelMinY = safe.top + 8;
    final panelMaxY = screen.height - safe.bottom - panelH - 8;
    final panelClampedLeft = panelAbsLeft.clamp(panelMinX, math.max(panelMinX, panelMaxX)).toDouble();
    final panelClampedTop = panelAbsTop.clamp(panelMinY, math.max(panelMinY, panelMaxY)).toDouble();
    panelLeft = panelClampedLeft - _pos.dx;
    panelTop = panelClampedTop - _pos.dy;

    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: panelLeft,
            top: panelTop,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) {
                final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
                final slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(fade);
                return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: child));
              },
              child: _expanded ? miniPanel() : const SizedBox.shrink(),
            ),
          ),
          Positioned(
            left: bubbleLeft,
            top: bubbleTop,
            child: captionBubble(),
          ),
          _CoachOrbGesture(
            enabled: enabled,
            childBuilder: (down) => orbCore(down: down),
            onPan: (delta) {
              setState(() {
                _pos = _clampToScreen(proposed: _pos + delta, screen: screen, orbSize: orb, safe: safe);
              });
            },
            onPanEnd: () {
              _savePos(_pos);
            },
            onTap: () {
              if (!enabled) return;
              setState(() => _expanded = !_expanded);
            },
            onDoubleTap: () async {
              if (!enabled) return;
              try {
                await HapticFeedback.selectionClick();
                SystemSound.play(SystemSoundType.click);
              } catch (_) {}
              await coach.setHandsFree(!coach.handsFree, token: token);
            },
            onPressStart: () async {
              if (!enabled) return;
              try {
                await HapticFeedback.heavyImpact();
                SystemSound.play(SystemSoundType.click);
              } catch (_) {}
              await coach.startPushToTalk(token: token);
            },
            onPressEnd: () async {
              if (!enabled) return;
              try {
                await HapticFeedback.mediumImpact();
                SystemSound.play(SystemSoundType.click);
              } catch (_) {}
              await coach.stopAndSend(token: token);
            },
          ),
        ],
      ),
    );
  }
}

class _SiriWaveform extends StatelessWidget {
  final double t;
  final Color color;
  final double intensity;

  const _SiriWaveform({
    required this.t,
    required this.color,
    required this.intensity,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SiriWaveformPainter(
        t: t,
        color: color,
        intensity: intensity,
      ),
    );
  }
}

class _SiriWaveformPainter extends CustomPainter {
  final double t;
  final Color color;
  final double intensity;

  const _SiriWaveformPainter({
    required this.t,
    required this.color,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final base = (h * 0.10).clamp(10.0, 22.0);
    final amp = (h * 0.24) * intensity;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;

    final bars = 7;
    final spacing = 10.0;
    final startX = cx - ((bars - 1) * spacing) / 2;

    for (var i = 0; i < bars; i++) {
      final phase = (i * 0.55) + t * math.pi * 2;
      final v = (math.sin(phase) * 0.5 + 0.5);
      final v2 = (math.sin(phase * 0.7 + 1.1) * 0.5 + 0.5);
      final height = base + (v * 0.65 + v2 * 0.35) * amp;

      final x = startX + i * spacing;
      final y1 = cy - height / 2;
      final y2 = cy + height / 2;

      paint.color = color.withOpacity((0.10 + v * 0.20).clamp(0.10, 0.32));
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }

    // Soft glow halo
    final halo = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withOpacity((0.06 + intensity * 0.06).clamp(0.06, 0.14));
    canvas.drawCircle(Offset(cx, cy), (w * 0.46), halo);
  }

  @override
  bool shouldRepaint(covariant _SiriWaveformPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.color != color || oldDelegate.intensity != intensity;
  }
}

typedef _DownBuilder = Widget Function(bool down);

class _CoachOrbGesture extends StatefulWidget {
  final bool enabled;
  final _DownBuilder childBuilder;
  final void Function(Offset delta) onPan;
  final VoidCallback onPanEnd;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final Future<void> Function() onPressStart;
  final Future<void> Function() onPressEnd;

  const _CoachOrbGesture({
    required this.enabled,
    required this.childBuilder,
    required this.onPan,
    required this.onPanEnd,
    required this.onTap,
    required this.onDoubleTap,
    required this.onPressStart,
    required this.onPressEnd,
  });

  @override
  State<_CoachOrbGesture> createState() => _CoachOrbGestureState();
}

class _CoachOrbGestureState extends State<_CoachOrbGesture> {
  bool _down = false;
  bool _dragging = false;

  void _setDown(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      onPanStart: (_) {
        _dragging = true;
      },
      onPanUpdate: (d) {
        widget.onPan(d.delta);
      },
      onPanEnd: (_) {
        _dragging = false;
        widget.onPanEnd();
      },
      onLongPressStart: (_) async {
        if (_dragging) return;
        _setDown(true);
        if (widget.enabled) {
          await widget.onPressStart();
        }
      },
      onLongPressEnd: (_) async {
        if (_dragging) return;
        _setDown(false);
        if (widget.enabled) {
          await widget.onPressEnd();
        }
      },
      onLongPressCancel: () async {
        if (_dragging) return;
        _setDown(false);
        if (widget.enabled) {
          await widget.onPressEnd();
        }
      },
      child: widget.childBuilder(_down),
    );
  }
}
