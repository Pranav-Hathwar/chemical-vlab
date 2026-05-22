// Animated Guide / Help experience for the MFR Virtual Lab.
//
// A self-contained route opened from the home screen's app-bar "?" button.
// It reads no app state and mutates no provider — purely an onboarding/help UI.
import 'package:flutter/material.dart';

import '../constants.dart';
import '../widgets/guide_page_widget.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  static const int _pageCount = 5;

  // Per-page accent colours (match the app's palette).
  static const List<Color> _accents = [
    kGuideInk, // 1 — what is an MFR
    Color(0xFFEF6C00), // 2 — inputs (orange)
    Color(0xFF00897B), // 3 — results (teal)
    Color(0xFF5E35B1), // 4 — graph (deep purple)
    Color(0xFF2E7D32), // 5 — tips (green)
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final int next = (_page + delta).clamp(0, _pageCount - 1);
    if (next == _page) {
      if (delta > 0) Navigator.of(context).pop(); // "Done" on last page
      return;
    }
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _accents[_page];
    final bool isLast = _page == _pageCount - 1;

    return Scaffold(
      backgroundColor: kGuideBg,
      appBar: AppBar(
        title: const Text('Lab Guide',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kGuideInk,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                _pageWhatIsMfr(),
                _pageInputs(),
                _pageResults(),
                _pageGraph(),
                _pageTips(),
              ],
            ),
          ),
          _bottomBar(accent, isLast),
        ],
      ),
    );
  }

  // ── Bottom navigation bar (dots + Back / Next-Done) ────────────────────────
  Widget _bottomBar(Color accent, bool isLast) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back
          SizedBox(
            width: 88,
            child: AnimatedOpacity(
              opacity: _page == 0 ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: TextButton.icon(
                onPressed: _page == 0 ? null : () => _go(-1),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back'),
                style: TextButton.styleFrom(foregroundColor: kGuideMuted),
              ),
            ),
          ),
          // Dots
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pageCount, (i) {
                final bool active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? accent : accent.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          // Next / Done
          SizedBox(
            width: 110,
            child: ElevatedButton(
              onPressed: () => _go(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                isLast ? 'Done' : 'Next',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PAGE 1 — What is an MFR?
  // ════════════════════════════════════════════════════════════════════════
  Widget _pageWhatIsMfr() {
    return GuidePageWidget(
      isActive: _page == 0,
      accent: _accents[0],
      icon: Icons.science_outlined,
      pageLabel: 'Step 1 of 5',
      title: 'What is a Mixed Flow Reactor?',
      subtitle:
          'A continuously-stirred tank where reactants flow in, react, and '
          'products flow out — all at the same time.',
      children: [
        GuideInfoCard(
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  kReactorImagePath,
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 170,
                    alignment: Alignment.center,
                    color: const Color(0xFFEDEFF6),
                    child: const Icon(Icons.science_outlined,
                        size: 64, color: kGuideInk),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 18,
                runSpacing: 10,
                children: [
                  GuideFlowArrows(label: 'A in', color: Color(0xFF1565C0)),
                  GuideFlowArrows(label: 'B in', color: Color(0xFFEF6C00)),
                  GuideFlowArrows(label: 'out', color: Color(0xFF2E7D32)),
                ],
              ),
            ],
          ),
        ),
        const GuideInfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Para(
                'Two feed streams (pure A and pure B) enter the tank. Vigorous '
                'stirring keeps the contents perfectly uniform, so the mixture '
                'leaving the reactor has exactly the same composition as inside '
                'the tank.',
              ),
              SizedBox(height: 12),
              _Para(
                'At "steady state" nothing changes with time: what flows in is '
                'balanced by what reacts plus what flows out. Your goal is to '
                'find the hidden reaction rate constant k from the exit '
                'concentration of A.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PAGE 2 — Inputs
  // ════════════════════════════════════════════════════════════════════════
  Widget _pageInputs() {
    const Color a = Color(0xFFEF6C00);
    return GuidePageWidget(
      isActive: _page == 1,
      accent: a,
      icon: Icons.edit_note_rounded,
      pageLabel: 'Step 2 of 5',
      title: 'Entering Your Inputs',
      subtitle: 'Set the five values, then tap Check Data and Run Trial.',
      children: const [
        GuideInfoCard(
          accent: a,
          child: Column(
            children: [
              GuideFieldRow(
                icon: Icons.opacity,
                label: 'CA₀',
                unit: 'mol/L',
                meaning: 'Concentration of the pure A feed stream.',
                accent: a,
              ),
              GuideFieldRow(
                icon: Icons.opacity,
                label: 'CB₀',
                unit: 'mol/L',
                meaning: 'Concentration of the pure B feed stream.',
                accent: a,
              ),
              GuideFieldRow(
                icon: Icons.water_drop_outlined,
                label: 'Vʀ',
                unit: 'L',
                meaning: 'Volume of the reactor tank (fixed all session).',
                accent: a,
              ),
              GuideFieldRow(
                icon: Icons.speed,
                label: 'vA',
                unit: 'L/min',
                meaning: 'Volumetric flow rate of stream A.',
                accent: a,
              ),
              GuideFieldRow(
                icon: Icons.speed,
                label: 'vB',
                unit: 'L/min',
                meaning: 'Volumetric flow rate of stream B.',
                accent: a,
              ),
            ],
          ),
        ),
        GuideInfoCard(
          accent: a,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline, color: a, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: _Para(
                  'A must be the limiting reactant: after mixing, CB₀/CA₀ must be '
                  'greater than 1. If you see a warning, lower vA or raise vB.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PAGE 3 — Results
  // ════════════════════════════════════════════════════════════════════════
  Widget _pageResults() {
    const Color a = Color(0xFF00897B);
    return GuidePageWidget(
      isActive: _page == 2,
      accent: a,
      icon: Icons.analytics_outlined,
      pageLabel: 'Step 3 of 5',
      title: 'Reading Your Results',
      subtitle: 'Each trial produces these values. During a run you only see Cᴀ '
          '— the rest appear in the results table.',
      children: const [
        GuideInfoCard(
          accent: a,
          child: Column(
            children: [
              GuideTermRow(
                  symbol: 'τ',
                  name: 'Space time (min)',
                  description: 'τ = Vʀ / (vA + vB). Average time fluid spends in the tank.',
                  accent: a),
              GuideTermRow(
                  symbol: 'CA0',
                  name: 'Mixed inlet A',
                  description: 'CA₀ diluted by mixing: CA0 = CA₀·vA/(vA+vB).',
                  accent: a),
              GuideTermRow(
                  symbol: 'CB0',
                  name: 'Mixed inlet B',
                  description: 'CB₀ diluted by mixing: CB0 = CB₀·vB/(vA+vB).',
                  accent: a),
              GuideTermRow(
                  symbol: 'm',
                  name: 'Ratio',
                  description: 'm = CB0 / CA0 (how much excess B is present).',
                  accent: a),
              GuideTermRow(
                  symbol: 'Cᴀ',
                  name: 'Exit concentration of A',
                  description: 'What leaves the reactor: CA = CA0·(1 − XA). The only value shown live.',
                  accent: a),
              GuideTermRow(
                  symbol: 'XA',
                  name: 'Conversion of A',
                  description: 'Fraction of A reacted: XA = (CA0 − CA)/CA0.',
                  accent: a),
              GuideTermRow(
                  symbol: 'CB',
                  name: 'Exit concentration of B',
                  description: 'CB = CB0 − CA0·XA (1:1 reaction A + B).',
                  accent: a),
              GuideTermRow(
                  symbol: 'CA·CB',
                  name: 'Rate group',
                  description: 'Product of exit concentrations — the x-axis of the k graph.',
                  accent: a),
              GuideTermRow(
                  symbol: 'rA',
                  name: 'Reaction rate',
                  description: 'rA = CA0·XA / τ — the y-axis of the k graph.',
                  accent: a),
            ],
          ),
        ),
        GuideInfoCard(
          accent: a,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MiniTitle('Example (vA = 1, vB = 1.2)', a),
              SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip('τ = 2.27'),
                  _Chip('CA0 = 0.455'),
                  _Chip('m = 1.32'),
                  _Chip('XA = 0.239'),
                  _Chip('Cᴀ = 0.346', highlight: true),
                  _Chip('rA = 0.0478'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PAGE 4 — The graph
  // ════════════════════════════════════════════════════════════════════════
  Widget _pageGraph() {
    const Color a = Color(0xFF5E35B1);
    return GuidePageWidget(
      isActive: _page == 3,
      accent: a,
      icon: Icons.show_chart_rounded,
      pageLabel: 'Step 4 of 5',
      title: 'The Graph & Finding k',
      subtitle: 'Plot rA against CA·CB across your trials. The line through the '
          'origin reveals the rate constant.',
      children: const [
        GuideInfoCard(
          accent: a,
          child: GuideSampleGraph(accent: a),
        ),
        GuideInfoCard(
          accent: a,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Para(
                'For this reaction the rate law is rA = k · CA · CB. So a plot of '
                'rA versus CA·CB is a straight line through the origin, and its '
                'slope is exactly k — the rate constant you are trying to find.',
              ),
              SizedBox(height: 12),
              _Para(
                'Physically, k measures how fast A and B react. A larger k means '
                'a faster reaction and more conversion for the same residence '
                'time. Here the slope works out to k ≈ 0.2816 L/(mol·min).',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PAGE 5 — Tips & limits
  // ════════════════════════════════════════════════════════════════════════
  Widget _pageTips() {
    const Color a = Color(0xFF2E7D32);
    return GuidePageWidget(
      isActive: _page == 4,
      accent: a,
      icon: Icons.tips_and_updates_outlined,
      pageLabel: 'Step 5 of 5',
      title: 'Tips & Limits',
      subtitle: 'A few rules and good-to-knows before you start experimenting.',
      children: const [
        GuideInfoCard(
          accent: a,
          child: Column(
            children: [
              GuideTermRow(
                  symbol: '10',
                  name: 'Maximum trials per session',
                  description: 'Vary vA / vB to collect up to 10 data points.',
                  accent: a),
              GuideTermRow(
                  symbol: '3',
                  name: 'Minimum trials before submitting k',
                  description: 'Run at least 3 trials before you enter your k guess.',
                  accent: a),
              GuideTermRow(
                  symbol: 'k',
                  name: 'Submit & reveal',
                  description: 'After you submit your k, the actual hidden k is revealed so you can compare.',
                  accent: a),
            ],
          ),
        ),
        GuideInfoCard(
          accent: a,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MiniTitle('Student vs Admin', a),
              SizedBox(height: 8),
              _Para(
                'Students see the exit concentration Cᴀ and the results table, '
                'and work out k themselves. The k-graph and every student\'s data '
                'are visible only to the admin (instructor).',
              ),
              SizedBox(height: 12),
              _MiniTitle('Exporting to Excel', a),
              SizedBox(height: 8),
              _Para(
                'Once k is revealed you can export the full session to an Excel '
                'sheet (save to device or share) for your lab report.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Small private content helpers ───────────────────────────────────────────

class _Para extends StatelessWidget {
  const _Para(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        height: 1.5,
        color: Color(0xFF455A64),
      ),
    );
  }
}

class _MiniTitle extends StatelessWidget {
  const _MiniTitle(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.highlight = false});
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final Color bg = highlight ? const Color(0xFF0D47A1) : const Color(0xFFEDEFF6);
    final Color fg = highlight ? Colors.white : const Color(0xFF37474F);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
