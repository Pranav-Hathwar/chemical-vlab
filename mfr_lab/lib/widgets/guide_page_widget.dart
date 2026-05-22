// Reusable building blocks for the animated Guide / Help experience.
//
// Nothing here touches app state or any provider — these are purely
// presentational widgets used by lib/screens/guide_screen.dart.
import 'dart:math' as math;

import 'package:flutter/material.dart';

// ── Shared palette (mirrors the app theme) ──────────────────────────────────
const Color kGuideInk = Color(0xFF1A237E); // deep indigo
const Color kGuideBg = Color(0xFFF5F7FA);
const Color kGuideMuted = Color(0xFF607D8B);

// ════════════════════════════════════════════════════════════════════════════
//  GuidePageWidget — animated scaffold for one guide page.
//
//  Renders a header (badge + label + title + subtitle) and a list of content
//  blocks that fade + slide in with a staggered cascade whenever the page
//  becomes the active page in the PageView. The cascade replays on every visit.
// ════════════════════════════════════════════════════════════════════════════
class GuidePageWidget extends StatefulWidget {
  const GuidePageWidget({
    super.key,
    required this.isActive,
    required this.accent,
    required this.icon,
    required this.pageLabel,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  /// Whether this page is the one currently shown (drives the entrance cascade).
  final bool isActive;
  final Color accent;
  final IconData icon;
  final String pageLabel; // e.g. "Step 1 of 5"
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  State<GuidePageWidget> createState() => _GuidePageWidgetState();
}

class _GuidePageWidgetState extends State<GuidePageWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    if (widget.isActive) _c.forward();
  }

  @override
  void didUpdateWidget(covariant GuidePageWidget old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _c.forward(from: 0);
    } else if (!widget.isActive && old.isActive) {
      _c.reset();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Fade + rise, staggered by position so blocks cascade in.
  Widget _staggered(int index, int total, Widget child) {
    final double start = (0.10 + 0.62 * (index / total)).clamp(0.0, 0.8);
    final double end = (start + 0.40).clamp(0.0, 1.0);
    final Animation<double> anim = CurvedAnimation(
      parent: _c,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.14),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.children.length + 1;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _staggered(0, total, _header()),
          const SizedBox(height: 22),
          for (int i = 0; i < widget.children.length; i++) ...[
            _staggered(i + 1, total, widget.children[i]),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.accent, widget.accent.withValues(alpha: 0.65)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.pageLabel,
                style: TextStyle(
                  color: widget.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2933),
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.subtitle,
          style: const TextStyle(fontSize: 15, color: kGuideMuted, height: 1.4),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  GuideInfoCard — white rounded card holding a block of content.
// ════════════════════════════════════════════════════════════════════════════
class GuideInfoCard extends StatelessWidget {
  const GuideInfoCard({
    super.key,
    required this.child,
    this.accent = kGuideInk,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final Color accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  GuideTermRow — a symbol/name + description line (for results & tips).
// ════════════════════════════════════════════════════════════════════════════
class GuideTermRow extends StatelessWidget {
  const GuideTermRow({
    super.key,
    required this.symbol,
    required this.name,
    required this.description,
    required this.accent,
  });

  final String symbol;
  final String name;
  final String description;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              symbol,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: Color(0xFF263238),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: kGuideMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  GuideFieldRow — an input field explainer (icon + label + unit + meaning).
// ════════════════════════════════════════════════════════════════════════════
class GuideFieldRow extends StatelessWidget {
  const GuideFieldRow({
    super.key,
    required this.icon,
    required this.label,
    required this.unit,
    required this.meaning,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String unit;
  final String meaning;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        unit,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  meaning,
                  style: const TextStyle(
                    fontSize: 13,
                    color: kGuideMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  GuideFlowArrows — marching chevrons that suggest continuous flow.
// ════════════════════════════════════════════════════════════════════════════
class GuideFlowArrows extends StatefulWidget {
  const GuideFlowArrows({
    super.key,
    required this.label,
    required this.color,
    this.count = 3,
  });

  final String label;
  final Color color;
  final int count;

  @override
  State<GuideFlowArrows> createState() => _GuideFlowArrowsState();
}

class _GuideFlowArrowsState extends State<GuideFlowArrows>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: widget.color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.count, (i) {
                // Marching highlight: each chevron peaks in turn.
                final double phase = (_c.value * widget.count - i) % widget.count;
                final double t = (1 - (phase % widget.count)).clamp(0.0, 1.0);
                final double opacity = 0.25 + 0.75 * t;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: widget.color.withValues(alpha: opacity),
                    size: 22,
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  GuideSampleGraph — animated "line-drawing" of an rA vs CA·CB plot.
//  Slope of the best-fit line through the origin == k (= 0.2816 here).
// ════════════════════════════════════════════════════════════════════════════
class GuideSampleGraph extends StatefulWidget {
  const GuideSampleGraph({super.key, this.accent = const Color(0xFF5E35B1)});

  final Color accent;

  @override
  State<GuideSampleGraph> createState() => _GuideSampleGraphState();
}

class _GuideSampleGraphState extends State<GuideSampleGraph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  // Sample data from the verified test cases (CA·CB, rA).
  static const List<Offset> _points = [
    Offset(0.130391, 0.036716),
    Offset(0.157027, 0.044224),
    Offset(0.169876, 0.047848),
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.45,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return CustomPaint(
            painter: _GraphPainter(
              progress: Curves.easeInOut.transform(_c.value),
              accent: widget.accent,
              points: _points,
            ),
          );
        },
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.progress,
    required this.accent,
    required this.points,
  });

  final double progress;
  final Color accent;
  final List<Offset> points;

  static const double _maxX = 0.20;
  static const double _maxY = 0.06;
  static const double _slope = 0.2816;

  @override
  void paint(Canvas canvas, Size size) {
    const double padL = 34, padB = 26, padT = 10, padR = 12;
    final double plotW = size.width - padL - padR;
    final double plotH = size.height - padT - padB;

    Offset toCanvas(double x, double y) => Offset(
          padL + (x / _maxX) * plotW,
          padT + plotH - (y / _maxY) * plotH,
        );

    // ── Grid ──
    final grid = Paint()
      ..color = const Color(0xFFE3E7EF)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final double gy = padT + plotH * i / 4;
      canvas.drawLine(Offset(padL, gy), Offset(padL + plotW, gy), grid);
      final double gx = padL + plotW * i / 4;
      canvas.drawLine(Offset(gx, padT), Offset(gx, padT + plotH), grid);
    }

    // ── Axes ──
    final axis = Paint()
      ..color = kGuideInk
      ..strokeWidth = 2;
    canvas.drawLine(
        const Offset(padL, padT), Offset(padL, padT + plotH), axis); // y
    canvas.drawLine(Offset(padL, padT + plotH),
        Offset(padL + plotW, padT + plotH), axis); // x

    // ── Animated best-fit line through the origin (slope = k) ──
    final double xEnd = _maxX * 0.95 * progress;
    final line = Paint()
      ..color = accent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final Offset tip = toCanvas(xEnd, _slope * xEnd);
    canvas.drawLine(toCanvas(0, 0), tip, line);

    // Glowing dot at the moving tip.
    canvas.drawCircle(
      tip,
      5,
      Paint()..color = accent.withValues(alpha: 0.30),
    );
    canvas.drawCircle(tip, 2.5, Paint()..color = accent);

    // ── Data points, revealed as the line sweeps past them ──
    for (final p in points) {
      if (p.dx <= xEnd + 0.004) {
        final c = toCanvas(p.dx, p.dy);
        canvas.drawCircle(c, 5.5, Paint()..color = const Color(0xFFFFC107));
        canvas.drawCircle(
          c,
          5.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white,
        );
      }
    }

    // ── Axis labels ──
    _label(canvas, 'rA', const Offset(2, padT - 2), kGuideInk, vertical: true);
    _label(canvas, 'CA·CB', Offset(size.width - 52, size.height - 16), kGuideInk);

    // ── Slope annotation ──
    _label(
      canvas,
      'slope = k ≈ 0.2816',
      Offset(padL + plotW * 0.20, padT + plotH * 0.18),
      accent,
      bold: true,
    );
  }

  void _label(Canvas canvas, String text, Offset at, Color color,
      {bool vertical = false, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (vertical) {
      canvas.save();
      canvas.translate(at.dx + tp.height, at.dy + tp.width);
      canvas.rotate(-math.pi / 2);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    } else {
      tp.paint(canvas, at);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) =>
      old.progress != progress || old.accent != accent;
}
