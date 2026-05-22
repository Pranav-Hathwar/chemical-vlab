// List tile-style card for a student in the admin views.
import 'package:flutter/material.dart';

import '../../models/user_model.dart';

class StudentCard extends StatelessWidget {
  final StudentSummary student;
  final VoidCallback onTap;

  const StudentCard({super.key, required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initials = student.displayName.isNotEmpty
        ? student.displayName.trim()[0].toUpperCase()
        : '?';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: onTap,
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFFE8EAF6),
          backgroundImage:
              student.photoUrl != null ? NetworkImage(student.photoUrl!) : null,
          child: student.photoUrl == null
              ? Text(initials,
                  style: const TextStyle(
                      color: Color(0xFF1A237E), fontWeight: FontWeight.bold))
              : null,
        ),
        title: Text(
          student.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(student.email,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Chip(
              label: Text('${student.sessionCount} session'
                  '${student.sessionCount == 1 ? '' : 's'}'),
              visualDensity: VisualDensity.compact,
              backgroundColor: const Color(0xFFE8EAF6),
              labelStyle: const TextStyle(
                  fontSize: 12, color: Color(0xFF1A237E)),
            ),
          ],
        ),
      ),
    );
  }
}
