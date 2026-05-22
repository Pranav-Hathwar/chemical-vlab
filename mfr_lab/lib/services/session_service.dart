// Session + trial API calls (student), plus admin read endpoints.
import '../constants.dart';
import '../models/session_model.dart';
import '../models/user_model.dart';
import 'api_service.dart';

/// Result of creating/resuming a session: the session plus the hidden k that
/// the client-side solver needs to simulate (kept private in the provider).
class SessionWithKey {
  final SessionModel session;
  final double hiddenK;
  const SessionWithKey({required this.session, required this.hiddenK});
}

class SessionService {
  SessionService({required ApiService api}) : _api = api;
  final ApiService _api;

  // ── Student ────────────────────────────────────────────────────────────────
  Future<SessionWithKey> createSession({
    required double ca0Prime,
    required double cb0Prime,
    required double vr,
  }) async {
    final res = await _api.post(
      ApiConfig.sessions,
      data: {'ca0Prime': ca0Prime, 'cb0Prime': cb0Prime, 'vr': vr},
    );
    final data = res['data'] as Map<String, dynamic>;
    return SessionWithKey(
      session: SessionModel.fromJson(data['session'] as Map<String, dynamic>),
      hiddenK: (data['hiddenK'] as num).toDouble(),
    );
  }

  /// Returns the active session (for resume) or null if none exists.
  Future<SessionWithKey?> getActiveSession() async {
    final res = await _api.get(ApiConfig.activeSession);
    final active = (res['data'] as Map<String, dynamic>)['active'];
    if (active == null) return null;
    final map = active as Map<String, dynamic>;
    return SessionWithKey(
      session: SessionModel.fromJson(map['session'] as Map<String, dynamic>),
      hiddenK: (map['hiddenK'] as num).toDouble(),
    );
  }

  Future<int> recordTrial({
    required String sessionId,
    required int runNumber,
    required double va,
    required double vb,
    required double ca0,
    required double cb0,
    required double tau,
    required double m,
    required double xa,
    required double ca,
    required double graphY,
  }) async {
    final res = await _api.post(
      ApiConfig.sessionTrials(sessionId),
      data: {
        'runNumber': runNumber,
        'va': va,
        'vb': vb,
        'ca0': ca0,
        'cb0': cb0,
        'tau': tau,
        'm': m,
        'xa': xa,
        'ca': ca,
        'graphY': graphY,
      },
    );
    return ((res['data'] as Map<String, dynamic>)['trialCount'] as num).toInt();
  }

  /// Submits the student's k and returns { actualK, accuracyPct } from the server.
  Future<({double actualK, double accuracyPct})> submitK({
    required String sessionId,
    required double studentK,
  }) async {
    final res = await _api.post(
      ApiConfig.sessionSubmit(sessionId),
      data: {'studentK': studentK},
    );
    final data = res['data'] as Map<String, dynamic>;
    return (
      actualK: (data['actualK'] as num).toDouble(),
      accuracyPct: (data['accuracyPct'] as num).toDouble(),
    );
  }

  // ── Admin ────────────────────────────────────────────────────────────────────
  Future<AdminStats> getStats() async {
    final res = await _api.get(ApiConfig.adminStats);
    return AdminStats.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<List<StudentSummary>> getStudents() async {
    final res = await _api.get(ApiConfig.adminStudents);
    final list = (res['data'] as Map<String, dynamic>)['students'] as List;
    return list
        .map((s) => StudentSummary.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Returns the student profile + all their sessions (with decrypted actual k).
  Future<({StudentSummary student, List<SessionModel> sessions})> getStudentDetail(
    String studentId,
  ) async {
    final res = await _api.get(ApiConfig.adminStudent(studentId));
    final data = res['data'] as Map<String, dynamic>;
    final sessions = (data['sessions'] as List)
        .map((s) => SessionModel.fromJson(s as Map<String, dynamic>))
        .toList();
    final s = data['student'] as Map<String, dynamic>;
    final summary = StudentSummary(
      id: s['id'].toString(),
      email: s['email']?.toString() ?? '',
      displayName: s['displayName']?.toString() ?? '',
      photoUrl: s['photoUrl']?.toString(),
      provider: s['provider']?.toString() ?? 'email',
      sessionCount: sessions.length,
      lastLoginAt: s['lastLoginAt'] != null
          ? DateTime.tryParse(s['lastLoginAt'].toString())
          : null,
    );
    return (student: summary, sessions: sessions);
  }

  Future<SessionModel> getSessionDetail(String sessionId) async {
    final res = await _api.get(ApiConfig.adminSession(sessionId));
    return SessionModel.fromJson(
      (res['data'] as Map<String, dynamic>)['session'] as Map<String, dynamic>,
    );
  }
}
