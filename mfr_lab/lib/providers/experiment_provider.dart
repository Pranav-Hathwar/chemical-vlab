// ignore_for_file: non_constant_identifier_names
import 'package:flutter/foundation.dart';
import '../models/trial_model.dart';
import '../utils/mfr_solver.dart';

/// Central state manager for a single MFR Virtual Lab session.
///
/// Lifecycle:
///   1. [initSession] — student enters CA0′, CB0′, VR → hidden k generated
///   2. [checkData]   — student enters vA, vB → inlet concentrations validated
///   3. [runExperiment] — reactor solved → TrialModel appended to [trials]
///   4. Repeat steps 2–3 for up to 12 trials (minimum 3 before submitting)
///   5. [submitStudentK] — student submits calculated k → [revealedK] unlocked
///   6. [resetSession] — clears everything for a fresh session
class ExperimentProvider extends ChangeNotifier {
  // ═══════════════════════════════════════════════════════════════════
  //  STATE VARIABLES
  // ═══════════════════════════════════════════════════════════════════

  // ── Session-level fixed inputs (set once via initSession) ───────────
  double? CA0_prime; // Concentration of A in feed stream [mol/L]
  double? CB0_prime; // Concentration of B in feed stream [mol/L]
  double? VR;        // Reactor volume [L]

  // ── Hidden rate constant — NEVER exposed until student submits ──────
  double? _hiddenK; // [L/(mol·min)],  range [0.25, 0.50]

  // ── Accumulated trial results ────────────────────────────────────────
  List<TrialModel> trials = [];

  // ── Per-run validation state ─────────────────────────────────────────
  /// True after [checkData] passes; reset to false after each [runExperiment].
  bool isDataValid = false;

  /// Cache of last computed CA0 / CB0 from [checkData] — used by [runExperiment].
  double? _lastCA0;
  double? _lastCB0;

  // ── Submission / reveal state ────────────────────────────────────────
  /// True once the student calls [submitStudentK].
  bool kRevealed = false;

  /// The student's k guess — set by [submitStudentK].
  double? studentK;

  // ── UI helpers ────────────────────────────────────────────────────────
  /// Last validation error from [checkData] or [initSession]; null if none.
  String? errorMessage;

  /// True once [initSession] has been called successfully.
  bool sessionStarted = false;

  /// True while [runExperiment] is executing (prevents re-entrant double-tap).
  bool isRunning = false;

  // ═══════════════════════════════════════════════════════════════════
  //  GETTERS
  // ═══════════════════════════════════════════════════════════════════

  /// Total number of completed trials this session.
  int get trialCount => trials.length;

  /// Whether additional trials are still allowed (max 12).
  bool get canRunMore => trials.length < 12;

  /// Whether the student has run enough trials to submit their k guess (min 3).
  bool get canSubmitK => trials.length >= 3;

  /// True when the maximum of 12 trials has been reached.
  bool get sessionComplete => trials.length >= 12;

  /// Percentage accuracy of the student's k guess relative to the hidden k.
  /// Returns 0.0 if k has not been revealed yet.
  double get accuracy {
    if (!kRevealed || studentK == null || _hiddenK == null) return 0.0;
    // % error = |student_k − actual_k| / actual_k  × 100
    return (studentK! - _hiddenK!).abs() / _hiddenK! * 100.0;
  }

  /// Exposes the hidden k ONLY after the student has submitted their guess.
  /// Returns null at all other times, keeping k secret during the experiment.
  double? get revealedK => kRevealed ? _hiddenK : null;

  // ═══════════════════════════════════════════════════════════════════
  //  METHODS
  // ═══════════════════════════════════════════════════════════════════

  // ── 1. initSession ───────────────────────────────────────────────────

  /// Initialises the session with the fixed reactor parameters.
  ///
  /// Validates that all inputs are strictly positive, then generates a new
  /// hidden k for this session using [MFRSolver.generateK].
  ///
  /// Returns an error message string if validation fails, null on success.
  String? initSession({
    required double cA0Prime,
    required double cB0Prime,
    required double vr,
  }) {
    // Guard: do NOT overwrite _hiddenK if session is already running
    // (student already has trials in progress, k must remain constant)
    if (sessionStarted && _hiddenK != null) {
      return null; // silently succeed — session already initialised
    }

    // Validate: all fixed inputs must be positive real numbers
    if (cA0Prime <= 0) return 'CA0′ must be a positive number.';
    if (cB0Prime <= 0) return 'CB0′ must be a positive number.';
    if (vr <= 0) return 'VR must be a positive number.';
    if (vr > 10000) return 'VR is physically unreasonable (>10,000 L).';

    // Store session-level fixed inputs
    CA0_prime = cA0Prime;
    CB0_prime = cB0Prime;
    VR = vr;

    // Generate a fresh hidden k — one per session, never changes mid-session
    _hiddenK = MFRSolver.generateK();

    // Reset all per-session mutable state (in case of re-init)
    trials = [];
    isDataValid = false;
    kRevealed = false;
    studentK = null;
    _lastCA0 = null;
    _lastCB0 = null;
    errorMessage = null;
    sessionStarted = true;

    notifyListeners();
    return null; // success
  }

  // ── 2. checkData ─────────────────────────────────────────────────────

  /// Validates the per-trial flow rate inputs vA and vB.
  ///
  /// Calls [MFRSolver.validateAndCompute] to compute mixed inlet concentrations
  /// and verify that A is the limiting reactant (CB0/CA0 > 1).
  ///
  /// Returns null on success (isDataValid set to true and CA0/CB0 cached),
  /// or an error message string on failure (isDataValid set to false).
  String? checkData({required double vA, required double vB}) {
    // Basic positive-value guard before handing off to solver
    if (vA <= 0) {
      errorMessage = 'vA must be a positive number.';
      isDataValid = false;
      notifyListeners();
      return errorMessage;
    }
    if (vB <= 0) {
      errorMessage = 'vB must be a positive number.';
      isDataValid = false;
      notifyListeners();
      return errorMessage;
    }

    // Session must be started before checking data
    if (CA0_prime == null || CB0_prime == null || VR == null) {
      errorMessage = 'Session not initialised. Please complete the Setup screen.';
      isDataValid = false;
      notifyListeners();
      return errorMessage;
    }

    // Delegate to MFRSolver for the chemistry check
    final result = MFRSolver.validateAndCompute(
      cA0Prime: CA0_prime!,
      cB0Prime: CB0_prime!,
      vR: VR!,
      vA: vA,
      vB: vB,
    );

    switch (result) {
      case MFRError(:final message):
        errorMessage = message;
        isDataValid = false;
        _lastCA0 = null;
        _lastCB0 = null;
        notifyListeners();
        return message;

      case MFRValid(:final CA0, :final CB0):
        errorMessage = null;
        isDataValid = true;
        _lastCA0 = CA0; // Cache for immediate use in runExperiment
        _lastCB0 = CB0;
        notifyListeners();
        return null; // success
    }
  }

  // ── 3. runExperiment ─────────────────────────────────────────────────

  /// Runs the reactor simulation for the current vA/vB input pair.
  ///
  /// Prerequisites: [checkData] must have passed and [canRunMore] must be true.
  ///
  /// Calls [MFRSolver.solve] with the session's hidden k, creates a
  /// [TrialModel] from the result, appends it to [trials], and resets
  /// [isDataValid] to false (forcing a fresh [checkData] for the next run).
  ///
  /// Returns the newly created [TrialModel] on success, or null if guards fail.
  TrialModel? runExperiment({required double vA, required double vB}) {
    // Guard: prevent re-entrant double execution
    if (isRunning) return null;

    // Guard: data must have been validated for this exact vA/vB pair
    if (!isDataValid) return null;

    // Guard: session must not be exhausted
    if (!canRunMore) return null;

    // Guard: cached concentrations must be present (set by checkData)
    if (_lastCA0 == null || _lastCB0 == null) return null;

    // Guard: hidden k must exist (set by initSession)
    if (_hiddenK == null || VR == null) return null;

    late MFRResult result;
    isRunning = true;
    try {
      result = MFRSolver.solve(
        CA0: _lastCA0!,
        CB0: _lastCB0!,
        vR: VR!,
        vA: vA,
        vB: vB,
        k: _hiddenK!,
      );
    } on MFRSolverException catch (_) {
      // Convergence failure — surface a friendly message, trial not recorded
      errorMessage =
          'Could not solve for these inputs. Try different vA/vB values.';
      isDataValid = false;
      isRunning = false;
      notifyListeners();
      return null;
    }

    // Assemble the full TrialModel from inputs + solver output
    final trial = TrialModel(
      runNumber: trials.length + 1,
      CA0_prime: CA0_prime!,
      CB0_prime: CB0_prime!,
      VR: VR!,
      vA: vA,
      vB: vB,
      CA0: _lastCA0!,
      CB0: _lastCB0!,
      tau: result.tau,
      m: result.m,
      XA: result.XA,
      CA: result.CA,
      graphY: result.graphY,
    );

    trials.add(trial);

    // Reset validation flag: the next run MUST call checkData again.
    isDataValid = false;
    _lastCA0 = null;
    _lastCB0 = null;
    errorMessage = null;
    isRunning = false;

    notifyListeners();
    return trial;
  }

  // ── 4. submitStudentK ────────────────────────────────────────────────

  /// Records the student's calculated k guess and reveals the actual hidden k.
  ///
  /// After this call, [revealedK] will return the real k value and
  /// [accuracy] will return the percentage error.
  ///
  /// Guard: [canSubmitK] must be true (≥ 3 trials completed).
  void submitStudentK(double k) {
    if (!canSubmitK) return;
    if (k <= 0) return; // k must be physically meaningful

    studentK = k;
    kRevealed = true;
    notifyListeners();
  }

  // ── 5. resetSession ──────────────────────────────────────────────────

  /// Clears all session state and resets the provider to its initial condition.
  ///
  /// A new hidden k will be generated when [initSession] is next called.
  /// This is the ONLY way to start a new experimental session.
  void resetSession() {
    // Fixed inputs
    CA0_prime = null;
    CB0_prime = null;
    VR = null;

    // Hidden k — destroyed here; a brand-new one is generated next session
    _hiddenK = null;

    // Trial data
    trials = [];

    // Per-run validation
    isDataValid = false;
    _lastCA0 = null;
    _lastCB0 = null;
    isRunning = false;

    // Submission / reveal
    kRevealed = false;
    studentK = null;

    // UI
    errorMessage = null;
    sessionStarted = false;

    notifyListeners();
  }
}
