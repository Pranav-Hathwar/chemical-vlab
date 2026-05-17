import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/trial_model.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const Color _kBlue  = Color(0xFF1A237E);
const Color _kAmber = Color(0xFFFFC107);
const Color _kGrid  = Color(0xFFEEEEEE);

/// Scatter chart with best-fit line overlay for graphical k determination.
///
/// X-axis : τ (space time, min)
/// Y-axis : Y = XA / [CA0·(1−XA)(m−XA)]
///
/// From the MFR design equation: Y = k · τ
/// So the regression line through the origin has  slope = k.
class MFRGraph extends StatefulWidget {
  final List<TrialModel> trials;

  const MFRGraph({super.key, required this.trials});

  @override
  State<MFRGraph> createState() => _MFRGraphState();
}

class _MFRGraphState extends State<MFRGraph> {
  int? _touchedSpotIndex;

  // ── Regression ─────────────────────────────────────────────────────────────

  /// Least-squares slope through origin: slope = Σ(τᵢ·Yᵢ) / Σ(τᵢ²)
  double _computeSlope() {
    double sumTauY = 0, sumTau2 = 0;
    for (final t in widget.trials) {
      sumTauY += t.tau * t.graphY;
      sumTau2 += t.tau * t.tau;
    }
    return sumTau2 > 1e-15 ? sumTauY / sumTau2 : 0;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.trials.isEmpty) return _emptyState();

    final slope     = _computeSlope();
    final maxTau    = widget.trials.map((t) => t.tau).reduce(math.max);
    final maxY      = widget.trials.map((t) => t.graphY).reduce(math.max);
    final chartMaxX = maxTau * 1.3;
    final chartMaxY = math.max(maxY, slope * chartMaxX) * 1.25;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'Graphical k Determination',
                style: TextStyle(
                  color: _kBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            // Chart + slope annotation overlay
            SizedBox(
              height: 300,
              child: Stack(
                children: [
                  LineChart(
                    _buildChartData(slope, chartMaxX, chartMaxY),
                    duration: const Duration(milliseconds: 250),
                  ),
                  Positioned(
                    top: 8,
                    right: 4,
                    child: _slopeAnnotation(slope),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _legend(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Chart data ─────────────────────────────────────────────────────────────

  LineChartData _buildChartData(
    double slope,
    double chartMaxX,
    double chartMaxY,
  ) {
    final scatterSpots =
        widget.trials.map((t) => FlSpot(t.tau, t.graphY)).toList();

    return LineChartData(
      minX: 0, maxX: chartMaxX,
      minY: 0, maxY: chartMaxY,

      // ── Grid ──────────────────────────────────────────────────────────────
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: _kGrid, strokeWidth: 1),
        getDrawingVerticalLine: (_) =>
            const FlLine(color: _kGrid, strokeWidth: 1),
      ),

      // ── Border ────────────────────────────────────────────────────────────
      borderData: FlBorderData(
        show: true,
        border: const Border(
          bottom: BorderSide(color: _kBlue, width: 2),
          left:   BorderSide(color: _kBlue, width: 2),
          top:    BorderSide(color: Colors.transparent),
          right:  BorderSide(color: Colors.transparent),
        ),
      ),

      // ── Axis titles ───────────────────────────────────────────────────────
      titlesData: FlTitlesData(
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),

        bottomTitles: AxisTitles(
          axisNameWidget: const Text(
            'τ  (space time, min)',
            style: TextStyle(
              color: _kBlue,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          axisNameSize: 28,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            interval: _niceInterval(chartMaxX, 5),
            getTitlesWidget: (v, meta) => SideTitleWidget(
              axisSide: meta.axisSide,
              child: Text(
                v.toStringAsFixed(2),
                style: const TextStyle(color: Color(0xFF757575), fontSize: 9.5),
              ),
            ),
          ),
        ),

        leftTitles: AxisTitles(
          axisNameWidget: const RotatedBox(
            quarterTurns: -1,
            child: Text(
              'XA / [CA₀(1−XA)(m−XA)]',
              softWrap: false,
              style: TextStyle(
                color: _kBlue,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          axisNameSize: 36,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 48,
            interval: _niceInterval(chartMaxY, 5),
            getTitlesWidget: (v, meta) => SideTitleWidget(
              axisSide: meta.axisSide,
              child: Text(
                v.toStringAsFixed(2),
                style: const TextStyle(color: Color(0xFF757575), fontSize: 9.5),
              ),
            ),
          ),
        ),
      ),

      // ── Line bars ─────────────────────────────────────────────────────────
      lineBarsData: [
        // Index 0 — Best-fit dashed line through origin
        LineChartBarData(
          spots: widget.trials.length >= 2 
                 ? [const FlSpot(0, 0), FlSpot(chartMaxX, slope * chartMaxX)]
                 : [const FlSpot(0, 0)],
          color: widget.trials.length >= 2 ? _kBlue : Colors.transparent,
          barWidth: widget.trials.length >= 2 ? 2 : 0,
          isCurved: false,
          dashArray: [10, 5],
          dotData: const FlDotData(show: false),
        ),

        // Index 1 — Scatter data points (amber circles, no connecting line)
        LineChartBarData(
          spots: scatterSpots,
          color: Colors.transparent,
          barWidth: 0,
          isCurved: false,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, __, index) {
              final touched = index == _touchedSpotIndex;
              return FlDotCirclePainter(
                radius:      touched ? 8.5 : 6.0,
                color:       _kAmber,
                strokeWidth: touched ? 2.5 : 1.5,
                strokeColor: touched ? _kBlue : Colors.white,
              );
            },
          ),
        ),
      ],

      // ── Touch / tooltip ───────────────────────────────────────────────────
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
          setState(() {
            if (!event.isInterestedForInteractions ||
                response?.lineBarSpots == null) {
              _touchedSpotIndex = null;
              return;
            }
            for (final spot in response!.lineBarSpots!) {
              if (spot.barIndex == 1) {
                _touchedSpotIndex = spot.spotIndex;
                return;
              }
            }
            _touchedSpotIndex = null;
          });
        },
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => _kBlue.withValues(alpha: 0.92),
          tooltipRoundedRadius: 8,
          tooltipPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          getTooltipItems: (spots) {
            return spots.map((spot) {
              if (spot.barIndex != 1) return null; // skip fit-line bar
              final trial = widget.trials[spot.spotIndex];
              return LineTooltipItem(
                'Run ${trial.runNumber}\n'
                'τ = ${trial.tau.toStringAsFixed(3)} min\n'
                'Y = ${trial.graphY.toStringAsFixed(4)}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  // ── Helper: nice axis interval ─────────────────────────────────────────────

  static double _niceInterval(double max, int targetCount) {
    if (max <= 0) return 1;
    final raw = max / targetCount;
    final exp = (math.log(raw) / math.ln10).floor();
    final mag = math.pow(10, exp).toDouble();
    final r   = raw / mag;
    final nice = r <= 1.5 ? 1.0 : r <= 3.5 ? 2.0 : r <= 7.5 ? 5.0 : 10.0;
    return nice * mag;
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _emptyState() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.scatter_plot_outlined, size: 52, color: Color(0xFFBDBDBD)),
              SizedBox(height: 14),
              Text(
                'Complete at least 3 trials to see the graph',
                style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slopeAnnotation(double slope) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _kBlue.withValues(alpha: 0.25)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(1, 2)),
        ],
      ),
      child: Text(
        'Slope = k ≈ ${slope.toStringAsFixed(4)}',
        style: const TextStyle(
          color: _kBlue,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _legend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 20,
        runSpacing: 6,
        children: [
          // Amber circle — trial data point
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12, height: 12,
                decoration: const BoxDecoration(
                  color: _kAmber, shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text('Trial data point',
                  style: TextStyle(fontSize: 12, color: Color(0xFF424242))),
            ],
          ),
          // Blue dashed segment — best fit line
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hand-drawn dashes
              ...List.generate(4, (i) => i.isEven
                  ? Container(width: 8, height: 2.5, color: _kBlue)
                  : const SizedBox(width: 3)),
              const SizedBox(width: 6),
              const Text('Best fit line  (slope = k)',
                  style: TextStyle(fontSize: 12, color: Color(0xFF424242))),
            ],
          ),
        ],
      ),
    );
  }
}
