// Card summarising one lab session for the admin student-detail view.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/session_model.dart';

class SessionCard extends StatelessWidget {
  final SessionModel session;
  final VoidCallback onTap;

  const SessionCard({super.key, required this.session, required this.onTap});

  Color _statusColor() {
    switch (session.status) {
      case 'completed':
        return const Color(0xFF388E3C);
      case 'abandoned':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFFFFA000); // active
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy, HH:mm');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor().withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      session.status.toUpperCase(),
                      style: TextStyle(
                          color: _statusColor(),
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    session.createdAt != null ? df.format(session.createdAt!) : '',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _metric('Trials', '${session.trialCount}'),
                  _metric(
                    'Actual k',
                    session.actualK != null
                        ? session.actualK!.toStringAsFixed(4)
                        : '—',
                  ),
                  _metric(
                    'Student k',
                    session.studentK != null
                        ? session.studentK!.toStringAsFixed(4)
                        : '—',
                  ),
                  _metric(
                    'Error',
                    session.accuracyPct != null
                        ? '${session.accuracyPct!.toStringAsFixed(2)}%'
                        : '—',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View graph & data',
                        style: TextStyle(
                            color: Color(0xFF1A237E),
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    Icon(Icons.chevron_right, color: Color(0xFF1A237E), size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121))),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF757575))),
        ],
      ),
    );
  }
}
