import 'package:flutter/material.dart';
import '../models/trial_model.dart';

// ─── Column definition ────────────────────────────────────────────────────────

class _ColDef {
  final String header;        // two-line header (use \n for unit on line 2)
  final double width;
  final bool isInteger;       // if true, value displayed without decimal

  const _ColDef(this.header, this.width, {this.isInteger = false});
}

const List<_ColDef> _kColumns = [
  _ColDef('Run\n#',           52,  isInteger: true),
  _ColDef("CA₀'\n[mol/L]",   96),
  _ColDef("CB₀'\n[mol/L]",   96),
  _ColDef('VR\n[L]',         72),
  _ColDef('vA\n[L/min]',     82),
  _ColDef('vB\n[L/min]',     82),
  _ColDef('CA0\n[mol/L]',    96),
  _ColDef('CB0\n[mol/L]',    96),
  _ColDef('τ\n[min]',        72),
  _ColDef('m\n[−]',          68),
  _ColDef('XA\n[−]',         72),
  _ColDef('CA\n[mol/L]',     92),
];

// ─── Colours ─────────────────────────────────────────────────────────────────

const Color _kHeaderBg    = Color(0xFF1A237E); // deep blue
const Color _kHeaderFg    = Colors.white;
const Color _kRowWhite    = Colors.white;
const Color _kRowGrey     = Color(0xFFF5F5F5);
const Color _kAmberAccent = Color(0xFFFFC107);
const Color _kBorderColor = Color(0xFFE0E0E0);
const Color _kCellText    = Color(0xFF424242);

// ─── Widget ──────────────────────────────────────────────────────────────────

/// Horizontally-scrollable data table showing all completed MFR trials.
///
/// - Header row: deep blue background, white bold text, two-line labels
/// - Data rows: alternating white / #F5F5F5 backgrounds
/// - Latest row: 3 px amber left accent border
/// - All numeric values: 4 decimal places
class TrialTable extends StatelessWidget {
  final List<TrialModel> trials;

  const TrialTable({super.key, required this.trials});

  @override
  Widget build(BuildContext context) {
    if (trials.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No trials yet. Run your first experiment above.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _headerRow(),
            const _HorizontalRule(),
            for (int i = 0; i < trials.length; i++)
              _dataRow(trials[i], i),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────

  Widget _headerRow() {
    return Container(
      color: _kHeaderBg,
      child: Row(
        children: _kColumns.map((col) {
          return _HeaderCell(col: col);
        }).toList(),
      ),
    );
  }

  // ── Data row ───────────────────────────────────────────────────────────

  Widget _dataRow(TrialModel t, int index) {
    final bool isLatest = index == trials.length - 1;
    final bool isEven   = index.isEven;

    final cells = _cellValues(t);

    return Container(
      decoration: BoxDecoration(
        color: isEven ? _kRowWhite : _kRowGrey,
        border: isLatest
            ? const Border(
                left: BorderSide(color: _kAmberAccent, width: 3),
              )
            : null,
      ),
      child: Row(
        children: List.generate(_kColumns.length, (i) {
          return _DataCell(
            value: cells[i],
            width: _kColumns[i].width,
            isLatest: isLatest,
          );
        }),
      ),
    );
  }

  // ── Value extraction ───────────────────────────────────────────────────

  /// Returns one display string per column, matching [_kColumns] order.
  List<String> _cellValues(TrialModel t) {
    String f(double v) => v.toStringAsFixed(4);
    return [
      t.runNumber.toString(),
      f(t.CA0_prime),
      f(t.CB0_prime),
      f(t.VR),
      f(t.vA),
      f(t.vB),
      f(t.CA0),
      f(t.CB0),
      f(t.tau),
      f(t.m),
      f(t.XA),
      f(t.CA),
    ];
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _HorizontalRule extends StatelessWidget {
  const _HorizontalRule();

  @override
  Widget build(BuildContext context) {
    final totalWidth =
        _kColumns.fold<double>(0, (sum, c) => sum + c.width);
    return Container(
      width: totalWidth,
      height: 1,
      color: _kBorderColor,
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final _ColDef col;
  const _HeaderCell({required this.col});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: col.width,
      height: 52,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.white24, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Text(
        col.header,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _kHeaderFg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String value;
  final double width;
  final bool isLatest;

  const _DataCell({
    required this.value,
    required this.width,
    required this.isLatest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: _kBorderColor, width: 0.5),
          bottom: BorderSide(color: _kBorderColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: _kCellText,
          fontWeight: isLatest ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}
