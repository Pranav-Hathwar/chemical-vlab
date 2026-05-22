// Backend session + trial models, with a mapper back to the app's TrialModel so
// the existing TrialTable / MFRGraph / excel_exporter can be reused unchanged.
//
// The trials table stores ca0, cb0, tau, m, xa, ca, graphY. The remaining
// TrialModel fields (CB, CACB, rA, kPerTrial) are pure functions of those, so
// they are recomputed here — no math engine is touched.
// ignore_for_file: non_constant_identifier_names
import 'trial_model.dart';

class BackendTrial {
  final String? id;
  final int runNumber;
  final double va;
  final double vb;
  final double ca0;
  final double cb0;
  final double tau;
  final double m;
  final double xa;
  final double ca;
  final double graphY;

  const BackendTrial({
    required this.runNumber,
    required this.va,
    required this.vb,
    required this.ca0,
    required this.cb0,
    required this.tau,
    required this.m,
    required this.xa,
    required this.ca,
    required this.graphY,
    this.id,
  });

  factory BackendTrial.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
    return BackendTrial(
      id: j['id']?.toString(),
      runNumber: (j['runNumber'] as num?)?.toInt() ?? 0,
      va: d(j['va']),
      vb: d(j['vb']),
      ca0: d(j['ca0']),
      cb0: d(j['cb0']),
      tau: d(j['tau']),
      m: d(j['m']),
      xa: d(j['xa']),
      ca: d(j['ca']),
      graphY: d(j['graphY']),
    );
  }

  /// Reconstruct a full TrialModel (derived fields recomputed from stored data).
  TrialModel toTrialModel({
    required double cA0Prime,
    required double cB0Prime,
    required double vr,
  }) {
    final cb = cb0 - ca0 * xa; // CB = CB0 − CA0·XA
    final caCb = ca * cb; // CACB = CA·CB
    final rA = tau > 0 ? ca0 * xa / tau : 0.0; // rA = CA0·XA/τ
    final kPerTrial = caCb.abs() > 1e-15 ? rA / caCb : 0.0; // k = rA/(CA·CB)
    return TrialModel(
      runNumber: runNumber,
      CA0_prime: cA0Prime,
      CB0_prime: cB0Prime,
      VR: vr,
      vA: va,
      vB: vb,
      CA0: ca0,
      CB0: cb0,
      tau: tau,
      m: m,
      XA: xa,
      CA: ca,
      CB: cb,
      CACB: caCb,
      rA: rA,
      kPerTrial: kPerTrial,
      graphY: graphY,
    );
  }
}

class SessionModel {
  final String id;
  final double ca0Prime;
  final double cb0Prime;
  final double vr;
  final int trialCount;
  final String status; // 'active' | 'completed' | 'abandoned'
  final bool kRevealed;
  final double? studentK;
  final double? accuracyPct;
  final double? actualK; // present for admin, or after reveal
  final DateTime? createdAt;
  final DateTime? completedAt;
  final List<BackendTrial> trials;

  // Optional embedded student (admin session detail).
  final String? studentEmail;
  final String? studentName;

  const SessionModel({
    required this.id,
    required this.ca0Prime,
    required this.cb0Prime,
    required this.vr,
    required this.trialCount,
    required this.status,
    required this.kRevealed,
    required this.trials,
    this.studentK,
    this.accuracyPct,
    this.actualK,
    this.createdAt,
    this.completedAt,
    this.studentEmail,
    this.studentName,
  });

  factory SessionModel.fromJson(Map<String, dynamic> j) {
    double? dn(dynamic v) => v == null ? null : (v as num).toDouble();
    final student = j['student'] as Map<String, dynamic>?;
    return SessionModel(
      id: j['id'].toString(),
      ca0Prime: dn(j['ca0Prime']) ?? 0,
      cb0Prime: dn(j['cb0Prime']) ?? 0,
      vr: dn(j['vr']) ?? 0,
      trialCount: (j['trialCount'] as num?)?.toInt() ?? 0,
      status: j['status']?.toString() ?? 'active',
      kRevealed: j['kRevealed'] == true,
      studentK: dn(j['studentK']),
      accuracyPct: dn(j['accuracyPct']),
      actualK: dn(j['actualK']),
      createdAt: j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt'].toString())
          : null,
      completedAt: j['completedAt'] != null
          ? DateTime.tryParse(j['completedAt'].toString())
          : null,
      trials: ((j['trials'] as List?) ?? [])
          .map((t) => BackendTrial.fromJson(t as Map<String, dynamic>))
          .toList(),
      studentEmail: student?['email']?.toString(),
      studentName: student?['displayName']?.toString(),
    );
  }

  /// All trials as full TrialModels for reuse by TrialTable / MFRGraph / export.
  List<TrialModel> toTrialModels() => trials
      .map((t) => t.toTrialModel(cA0Prime: ca0Prime, cB0Prime: cb0Prime, vr: vr))
      .toList();
}
