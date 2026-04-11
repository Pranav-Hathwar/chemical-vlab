// ignore_for_file: non_constant_identifier_names
import 'dart:math' as math;

// ═══════════════════════════════════════════════════════════════════════════
//  RESULT / EXCEPTION TYPES
// ═══════════════════════════════════════════════════════════════════════════

/// Sealed base class for the result of [MFRSolver.validateAndCompute].
/// Pattern-match with a switch expression to handle both cases.
sealed class MFRValidationResult {
  const MFRValidationResult();
}

/// Returned when CB0/CA0 ≤ 1, meaning A is NOT the limiting reactant.
/// The student must adjust vA and vB before a run can proceed.
final class MFRError extends MFRValidationResult {
  final String message;
  const MFRError(this.message);
}

/// Returned when CB0/CA0 > 1 — validation passes.
/// Carries the mixed inlet concentrations ready for the solver.
final class MFRValid extends MFRValidationResult {
  /// Mixed inlet concentration of A:  CA0 = CA0′ · vA / (vA + vB)  [mol/L]
  final double CA0;

  /// Mixed inlet concentration of B:  CB0 = CB0′ · vB / (vA + vB)  [mol/L]
  final double CB0;

  /// Stoichiometric excess ratio:  ratio = CB0 / CA0  (must be > 1 for A to limit)
  final double ratio;

  const MFRValid({
    required this.CA0,
    required this.CB0,
    required this.ratio,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

/// Holds the full output of [MFRSolver.solve] for one completed trial.
final class MFRResult {
  /// Fractional conversion of A determined by Newton-Raphson  [dimensionless]
  final double XA;

  /// Exit concentration of A:  CA = CA0 · (1 − XA)  [mol/L]
  /// This is the ONLY value shown to the student during the trial phase.
  final double CA;

  /// Space time:  τ = VR / (vA + vB)  [min]
  final double tau;

  /// Stoichiometric ratio:  m = CB0 / CA0  [dimensionless]
  final double m;

  /// Linearisation variable for the Y v τ graph:
  ///   Y = XA / [(1 − XA)(m − XA)]
  /// From the design equation:  Y = k · CA0 · τ
  /// So a plot of Y vs τ is linear through the origin with slope = k · CA0.
  final double graphY;

  const MFRResult({
    required this.XA,
    required this.CA,
    required this.tau,
    required this.m,
    required this.graphY,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

/// Thrown when the Newton-Raphson loop fails to converge within the
/// allowed iteration limit — signals a physically unreasonable input set.
class MFRSolverException implements Exception {
  final String message;
  final int iterationsAttempted;

  const MFRSolverException({
    required this.message,
    required this.iterationsAttempted,
  });

  @override
  String toString() =>
      'MFRSolverException: $message '
      '(iterations attempted: $iterationsAttempted)';
}

// ═══════════════════════════════════════════════════════════════════════════
//  SOLVER
// ═══════════════════════════════════════════════════════════════════════════

/// Stateless utility class containing all MFR calculation logic.
///
/// Reaction:   A + B → C      (second-order, one in each reactant)
/// Rate law:   (−rA) = k · CA · CB
/// Design eq.: k · CA0 · τ · (1 − XA)(m − XA) − XA = 0
abstract final class MFRSolver {
  // ── Constants ────────────────────────────────────────────────────────
  static const int _maxIterations = 1000;
  static const double _tolerance = 1e-8;
  static const double _kMin = 0.25; // [L/(mol·min)]
  static const double _kMax = 0.50; // [L/(mol·min)]

  // ── Random number generator (seeded from wall clock) ─────────────────
  static final math.Random _rng = math.Random();

  // ─────────────────────────────────────────────────────────────────────
  // METHOD 1 — validateAndCompute
  // ─────────────────────────────────────────────────────────────────────

  /// Computes mixed inlet concentrations and validates the limiting reactant.
  ///
  /// **Parameters**
  /// - [cA0Prime] — Concentration of pure A feed stream  [mol/L]
  /// - [cB0Prime] — Concentration of pure B feed stream  [mol/L]
  /// - [vR]       — Reactor volume  [L]  (not used here, passed for symmetry)
  /// - [vA]       — Volumetric flow rate of stream A  [L/min]
  /// - [vB]       — Volumetric flow rate of stream B  [L/min]
  ///
  /// **Returns** [MFRValid] if A is the limiting reactant, [MFRError] otherwise.
  static MFRValidationResult validateAndCompute({
    required double cA0Prime,
    required double cB0Prime,
    required double vR,
    required double vA,
    required double vB,
  }) {
    final double vT = vA + vB; // Total volumetric flow rate [L/min]

    // Dilute each pure stream by the mixing ratio.
    // When stream A (flow vA) mixes with stream B (flow vB):
    //   CA0 = CA0′ · vA/(vA+vB)  — A is diluted by the fraction of total flow it contributes
    final double CA0 = cA0Prime * vA / vT;

    //   CB0 = CB0′ · vB/(vA+vB)  — same logic for B
    final double CB0 = cB0Prime * vB / vT;

    // Stoichiometric ratio: for A to be limiting, we need CB0 > CA0,
    // i.e. there is more B (in moles) than A in the mixed feed.
    final double ratio = CB0 / CA0;

    if (ratio <= 1.0) {
      // B would run out first (or simultaneously), so A cannot be limiting.
      return const MFRError(
        'A is not the limiting reactant. Please adjust vA and vB.',
      );
    }

    return MFRValid(CA0: CA0, CB0: CB0, ratio: ratio);
  }

  // ─────────────────────────────────────────────────────────────────────
  // METHOD 2 — solve (Newton-Raphson)
  // ─────────────────────────────────────────────────────────────────────

  /// Solves the steady-state MFR design equation for conversion XA.
  ///
  /// **Design equation** (rearranged to f(XA) = 0):
  /// ```
  ///   f(XA) = k · CA0 · τ · (1 − XA)(m − XA) − XA = 0
  /// ```
  ///
  /// **Newton-Raphson derivative:**
  /// ```
  ///   f′(XA) = k · CA0 · τ · (−m − 1 + 2·XA) − 1
  /// ```
  ///
  /// **Parameters**
  /// - [CA0] — Mixed inlet concentration of A  [mol/L]
  /// - [CB0] — Mixed inlet concentration of B  [mol/L]
  /// - [vR]  — Reactor volume  [L]
  /// - [vA]  — Volumetric flow rate of stream A  [L/min]
  /// - [vB]  — Volumetric flow rate of stream B  [L/min]
  /// - [k]   — Rate constant  [L/(mol·min)]
  ///
  /// **Returns** [MFRResult] with XA, CA, τ, m, and graphY.
  ///
  /// **Throws** [MFRSolverException] if convergence is not achieved.
  static MFRResult solve({
    required double CA0,
    required double CB0,
    required double vR,
    required double vA,
    required double vB,
    required double k,
  }) {
    // ── Derived parameters ──────────────────────────────────────────────

    // m = CB0/CA0: stoichiometric excess of B over A.
    // XA must always stay below m (can't convert more A than B allows).
    final double m = CB0 / CA0;

    // τ = VR/vT: space time — how long (on average) fluid spends in reactor.
    final double vT = vA + vB;
    final double tau = vR / vT;

    // Lumped kinetic–reactor parameter: Damköhler-like group.
    // kappa = k · CA0 · τ  simplifies the NR expressions below.
    final double kappa = k * CA0 * tau;

    // ── Newton-Raphson iteration ────────────────────────────────────────

    // Initial guess: XA = 0.5 (middle of feasible range)
    double XA = 0.5;

    // Feasibility bounds: XA must be strictly between 0 and min(1, m).
    // We use a small epsilon to avoid division-by-zero at the bounds.
    const double eps = 0.0001;
    final double xaMax = math.min(0.9999, m - eps);

    int iter = 0;
    while (iter < _maxIterations) {
      // f(XA) = k·CA0·τ·(1−XA)(m−XA) − XA
      // Represents: moles of A reacted (per unit) = moles of A converted.
      final double fXA = kappa * (1.0 - XA) * (m - XA) - XA;

      // Check convergence: residual is effectively zero
      if (fXA.abs() < _tolerance) break;

      // f′(XA) = k·CA0·τ·(−m − 1 + 2·XA) − 1
      // Analytical derivative of f with respect to XA.
      final double fPrimeXA = kappa * (-m - 1.0 + 2.0 * XA) - 1.0;

      // Guard against zero derivative (flat region — shouldn't happen in range)
      if (fPrimeXA.abs() < 1e-15) {
        throw MFRSolverException(
          message: 'Derivative is zero at XA=$XA; Newton-Raphson cannot continue.',
          iterationsAttempted: iter,
        );
      }

      // Newton-Raphson update step
      final double XANew = XA - fXA / fPrimeXA;

      // Clamp to feasible region to prevent divergence outside physical bounds
      XA = XANew.clamp(eps, xaMax);

      iter++;
    }

    // Final convergence check
    final double fFinal = kappa * (1.0 - XA) * (m - XA) - XA;
    if (fFinal.abs() >= _tolerance) {
      throw MFRSolverException(
        message:
            'Newton-Raphson did not converge after $_maxIterations iterations. '
            'Final residual: ${fFinal.abs().toStringAsExponential(3)}',
        iterationsAttempted: iter,
      );
    }

    // ── Post-solve computations ─────────────────────────────────────────

    // Exit concentration: CA = CA0·(1−XA)
    // Fraction (1−XA) of inlet A remains unreacted.
    final double CA = CA0 * (1.0 - XA);

    // Linearisation variable for the Y vs τ graph.
    // Derived from the design equation:
    //   k·CA0·τ·(1−XA)(m−XA) = XA
    //   ⟹  Y = XA/[(1−XA)(m−XA)] = k·CA0·τ
    // So a plot of Y vs τ has slope = k·CA0, allowing k to be extracted
    // once CA0 is known from the trial inputs.
    final double graphY = XA / ((1.0 - XA) * (m - XA));

    return MFRResult(XA: XA, CA: CA, tau: tau, m: m, graphY: graphY);
  }

  // ─────────────────────────────────────────────────────────────────────
  // METHOD 3 — generateK
  // ─────────────────────────────────────────────────────────────────────

  /// Generates a random hidden rate constant k for a new session.
  ///
  /// Range: [0.25, 0.50] L/(mol·min) — typical range for second-order
  /// liquid-phase reactions at moderate temperatures.
  ///
  /// Called ONCE per session and stored in [ExperimentProvider].
  /// NEVER exposed to the student until they submit their own k guess.
  static double generateK() {
    // Uniform random in [kMin, kMax]
    return _kMin + _rng.nextDouble() * (_kMax - _kMin);
  }
}
