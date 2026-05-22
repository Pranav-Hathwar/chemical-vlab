// Admin landing screen: aggregate stats + student list. Admin-only (routed by
// AuthWrapper based on role).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/admin/stats_card.dart';
import '../../widgets/admin/student_card.dart';
import 'student_detail_screen.dart';
import 'student_list_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminStats? _stats;
  List<StudentSummary> _students = [];
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
      final svc = context.read<AuthProvider>().sessions;
      final results = await Future.wait([svc.getStats(), svc.getStudents()]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as AdminStats;
        _students = results[1] as List<StudentSummary>;
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

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(auth.user?.displayName ?? 'Admin',
                  style: const TextStyle(fontSize: 14)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Stats grid ──────────────────────────────────────────────────────
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            StatsCard(
              icon: Icons.people_alt_outlined,
              color: const Color(0xFF1A237E),
              label: 'Students',
              value: '${_stats?.totalStudents ?? 0}',
            ),
            StatsCard(
              icon: Icons.science_outlined,
              color: const Color(0xFF00897B),
              label: 'Sessions',
              value: '${_stats?.totalSessions ?? 0}',
            ),
            StatsCard(
              icon: Icons.check_circle_outline,
              color: const Color(0xFF388E3C),
              label: 'Completed',
              value: '${_stats?.completedSessions ?? 0}',
            ),
            StatsCard(
              icon: Icons.percent_outlined,
              color: const Color(0xFFFFA000),
              label: 'Avg % error',
              value: _stats?.avgAccuracyPct != null
                  ? _stats!.avgAccuracyPct!.toStringAsFixed(1)
                  : '—',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Students header ─────────────────────────────────────────────────
        Row(
          children: [
            const Text('Students',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E))),
            const Spacer(),
            if (_students.length > 5)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const StudentListScreen()),
                ),
                child: const Text('View all'),
              ),
          ],
        ),
        const SizedBox(height: 4),

        if (_students.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text('No students have registered yet.',
                  style: TextStyle(color: Color(0xFF9E9E9E))),
            ),
          )
        else
          ..._students.take(8).map(
                (s) => StudentCard(
                  student: s,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StudentDetailScreen(studentId: s.id),
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.cloud_off, size: 56, color: Color(0xFFBDBDBD)),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF757575))),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
