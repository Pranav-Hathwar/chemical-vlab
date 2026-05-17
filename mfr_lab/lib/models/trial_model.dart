// ignore_for_file: non_constant_identifier_names
/// Pure data class representing a single completed MFR trial run.
///
/// All concentrations are in [mol/L], flow rates in [L/min],
/// volume in [L], and space time in [min].
///
/// Computed fields (derived from inputs):
///   CA0   = CA0_prime * vA / (vA + vB)
///   CB0   = CB0_prime * vB / (vA + vB)
///   tau   = VR / (vA + vB)
///   m     = CB0 / CA0
///   XA    = solved via Newton-Raphson on the MFR design equation
///   CA    = CA0 * (1 - XA)
///   graphY= XA / [(1 - XA) * (m - XA)]
class TrialModel {
  // ── Run identifier ──────────────────────────────────────────────────
  final int runNumber;

  // ── Session-level fixed inputs ───────────────────────────────────────
  final double CA0_prime; // Concentration of A in feed stream A [mol/L]
  final double CB0_prime; // Concentration of B in feed stream B [mol/L]
  final double VR;        // Reactor volume [L]

  // ── Per-trial inputs ────────────────────────────────────────────────
  final double vA; // Volumetric flow rate of stream A [L/min]
  final double vB; // Volumetric flow rate of stream B [L/min]

  // ── Computed: mixed inlet concentrations ────────────────────────────
  final double CA0; // CA0_prime * vA / (vA + vB)  [mol/L]
  final double CB0; // CB0_prime * vB / (vA + vB)  [mol/L]

  // ── Computed: reactor parameters ────────────────────────────────────
  final double tau; // VR / (vA + vB)              [min]
  final double m;   // CB0 / CA0                   [dimensionless]

  // ── Solver output ───────────────────────────────────────────────────
  final double XA; // Fractional conversion of A   [dimensionless, 0–1]

  // ── Post-solve computed values ───────────────────────────────────────
  final double CA;     // CA0 * (1 - XA)                     [mol/L]  ← shown to student
  final double CB;
  final double CACB;
  final double rA;
  final double kPerTrial;
  final double graphY; // XA / [(1 - XA) * (m - XA)]         [mol/L]  ← used in Y vs τ plot

  // ── Named constructor ────────────────────────────────────────────────
  const TrialModel({
    required this.runNumber,
    required this.CA0_prime,
    required this.CB0_prime,
    required this.VR,
    required this.vA,
    required this.vB,
    required this.CA0,
    required this.CB0,
    required this.tau,
    required this.m,
    required this.XA,
    required this.CA,
    required this.CB,
    required this.CACB,
    required this.rA,
    required this.kPerTrial,
    required this.graphY,
  });

  // ── Excel export ─────────────────────────────────────────────────────
  /// Returns a flat list of all fields in display order for Excel export.
  ///
  /// Column order matches the spec:
  /// Run # | CA0′ | CB0′ | VR | vA | vB | CA0 | CB0 | τ | m | XA | CA | Y
  List<dynamic> toExcelRow() {
    return [
      runNumber,
      CA0_prime,
      CB0_prime,
      VR,
      vA,
      vB,
      _r(CA0),
      _r(CB0),
      _r(tau),
      _r(m),
      _r(XA),
      _r(CA),
      _r(CB),
      _r(CACB),
      _r(rA),
      _r(kPerTrial),
      _r(graphY),
    ];
  }

  // ── Map representation ───────────────────────────────────────────────
  /// Returns a human-readable map of all fields for debugging and display.
  Map<String, dynamic> toMap() {
    return {
      'runNumber': runNumber,
      'CA0_prime [mol/L]': CA0_prime,
      'CB0_prime [mol/L]': CB0_prime,
      'VR [L]': VR,
      'vA [L/min]': vA,
      'vB [L/min]': vB,
      'CA0 [mol/L]': _r(CA0),
      'CB0 [mol/L]': _r(CB0),
      'tau [min]': _r(tau),
      'm [-]': _r(m),
      'XA [-]': _r(XA),
      'CA [mol/L]': _r(CA),
      'CB [mol/L]': _r(CB),
      'CACB [mol²/L²]': _r(CACB),
      'rA [mol/L·min]': _r(rA),
      'kPerTrial [L/mol·min]': _r(kPerTrial),
      'graphY [mol/L]': _r(graphY),
    };
  }

  // ── String representation ────────────────────────────────────────────
  @override
  String toString() {
    return 'TrialModel {'
        'run=$runNumber, '
        'vA=${vA.toStringAsFixed(3)}, '
        'vB=${vB.toStringAsFixed(3)}, '
        'CA0=${CA0.toStringAsFixed(4)}, '
        'CB0=${CB0.toStringAsFixed(4)}, '
        'tau=${tau.toStringAsFixed(4)}, '
        'm=${m.toStringAsFixed(4)}, '
        'XA=${XA.toStringAsFixed(6)}, '
        'CA=${CA.toStringAsFixed(6)}, '
        'CB=${CB.toStringAsFixed(6)}, '
        'CACB=${CACB.toStringAsFixed(6)}, '
        'rA=${rA.toStringAsFixed(6)}, '
        'kPerTrial=${kPerTrial.toStringAsFixed(6)}, '
        'Y=${graphY.toStringAsFixed(6)}'
        '}';
  }

  // ── Private helper ──────────────────────────────────────────────────
  /// Rounds a double to 6 significant decimal places for consistent output.
  static double _r(double v) => double.tryParse(v.toStringAsFixed(6)) ?? v;
}

/// Column headers for the Excel sheet — matches [TrialModel.toExcelRow()] order.
const List<String> kTrialExcelHeaders = [
  'Run #',
  'CA0\' [mol/L]',
  'CB0\' [mol/L]',
  'VR [L]',
  'vA [L/min]',
  'vB [L/min]',
  'CA0 [mol/L]',
  'CB0 [mol/L]',
  'τ [min]',
  'm [-]',
  'XA [-]',
  'CA [mol/L]',
  'CB [mol/L]',
  'CACB [mol²/L²]',
  'rA [mol/L·min]',
  'kPerTrial [L/mol·min]',
  'Y [mol/L]',
];
