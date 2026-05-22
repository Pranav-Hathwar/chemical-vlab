// Admin: one student's profile + all their sessions. Tapping a session opens a
// full read-only view WITH the graph and the decrypted actual k (admin only),
// plus Excel export for any session.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/session_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/excel_exporter.dart';
import '../../widgets/admin/session_card.dart';
import '../../widgets/mfr_graph.dart';
import '../../widgets/trial_table.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentId;
  const StudentDetailScreen({super.key, required this.studentId});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  StudentSummary? _student;
  List<SessionModel> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context
          .read<AuthProvider>()
          .sessions
          .getStudentDetail(widget.studentId);
      if (!mounted) return;
      setState(() {
        _student = res.student;
        _sessions = res.sessions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: Text(_student?.displayName ?? 'Student')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile header
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFE8EAF6),
                    backgroundImage: _student?.photoUrl != null
                        ? NetworkImage(_student!.photoUrl!)
                        : null,
                    child: _student?.photoUrl == null
                        ? Text(
                            (_student?.displayName.isNotEmpty ?? false)
                                ? _student!.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Color(0xFF1A237E),
                                fontWeight: FontWeight.bold,
                                fontSize: 20))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_student?.displayName ?? '',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(_student?.email ?? '',
                            style: const TextStyle(color: Color(0xFF757575))),
                        const SizedBox(height: 6),
                        Text('Via ${_student?.provider ?? 'email'}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF9E9E9E))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Sessions',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E))),
          const SizedBox(height: 4),
          if (_sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('This student has no sessions yet.',
                    style: TextStyle(color: Color(0xFF9E9E9E))),
              ),
            )
          else
            ..._sessions.map(
              (s) => SessionCard(
                session: s,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _AdminSessionDetailScreen(sessionId: s.id),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Read-only session detail (admin) ───────────────────────────────────────────
class _AdminSessionDetailScreen extends StatefulWidget {
  final String sessionId;
  const _AdminSessionDetailScreen({required this.sessionId});

  @override
  State<_AdminSessionDetailScreen> createState() =>
      _AdminSessionDetailScreenState();
}

class _AdminSessionDetailScreenState extends State<_AdminSessionDetailScreen> {
  SessionModel? _session;
  bool _loading = true;
  String? _error;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await context
          .read<AuthProvider>()
          .sessions
          .getSessionDetail(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _session = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _export() async {
    final s = _session;
    if (s == null || _exporting) return;
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Excel Data'),
        content: const Text('Save to device or share the file?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('Save to Device')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'share'),
              child: const Text('Share File')),
        ],
      ),
    );
    if (mode == null) return;
    setState(() => _exporting = true);
    try {
      final path = await exportToExcel(
        trials: s.toTrialModels(),
        studentK: s.studentK ?? 0,
        actualK: s.actualK ?? 0,
        cA0Prime: s.ca0Prime,
        cB0Prime: s.cb0Prime,
        vR: s.vr,
        saveMode: mode,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(path != null ? 'Saved to:\n$path' : 'File exported'),
          backgroundColor: const Color(0xFF388E3C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Session Detail'),
        actions: [
          if (_session != null)
            IconButton(
              tooltip: 'Export Excel',
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded),
              onPressed: _exporting ? null : _export,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final s = _session!;
    final trials = s.toTrialModels();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // Key metrics incl. the DECRYPTED actual k (admin-only).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            color: const Color(0xFFE8EAF6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${s.status.toUpperCase()}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E))),
                  const SizedBox(height: 10),
                  _kv('Actual k (decrypted)',
                      s.actualK?.toStringAsFixed(5) ?? '—'),
                  _kv('Student k',
                      s.studentK?.toStringAsFixed(5) ?? 'not submitted'),
                  _kv('Percentage error',
                      s.accuracyPct != null
                          ? '${s.accuracyPct!.toStringAsFixed(2)}%'
                          : '—'),
                  _kv('Trials', '${s.trialCount}'),
                  _kv('Fixed: CA₀′ / CB₀′ / Vʀ',
                      '${s.ca0Prime} / ${s.cb0Prime} / ${s.vr}'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Data table (reuses the app's TrialTable unchanged)
        TrialTable(trials: trials),
        const SizedBox(height: 16),

        // Graph — admins ALWAYS see the graph (reuses MFRGraph unchanged)
        MFRGraph(trials: trials),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(k,
                style: const TextStyle(color: Color(0xFF555555), fontSize: 13)),
          ),
          Expanded(
            child: Text(v,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
