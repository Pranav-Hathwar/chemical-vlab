// Authenticated user + admin-side student summary.

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String role; // 'admin' | 'student'
  final String provider; // 'email' | 'google'
  final String? photoUrl;

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.provider,
    this.photoUrl,
  });

  bool get isAdmin => role == 'admin';
  bool get isStudent => role == 'student';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      email: json['email']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      role: json['role']?.toString() ?? 'student',
      provider: json['provider']?.toString() ?? 'email',
      photoUrl: json['photoUrl']?.toString(),
    );
  }
}

/// Compact student record for the admin student list.
class StudentSummary {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String provider;
  final int sessionCount;
  final DateTime? lastLoginAt;

  const StudentSummary({
    required this.id,
    required this.email,
    required this.displayName,
    required this.provider,
    required this.sessionCount,
    this.photoUrl,
    this.lastLoginAt,
  });

  factory StudentSummary.fromJson(Map<String, dynamic> json) {
    return StudentSummary(
      id: json['id'].toString(),
      email: json['email']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      photoUrl: json['photoUrl']?.toString(),
      provider: json['provider']?.toString() ?? 'email',
      sessionCount: (json['sessionCount'] as num?)?.toInt() ?? 0,
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.tryParse(json['lastLoginAt'].toString())
          : null,
    );
  }
}

/// Admin dashboard aggregate stats.
class AdminStats {
  final int totalStudents;
  final int totalSessions;
  final int completedSessions;
  final double? avgAccuracyPct;

  const AdminStats({
    required this.totalStudents,
    required this.totalSessions,
    required this.completedSessions,
    this.avgAccuracyPct,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalStudents: (json['totalStudents'] as num?)?.toInt() ?? 0,
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      completedSessions: (json['completedSessions'] as num?)?.toInt() ?? 0,
      avgAccuracyPct: (json['avgAccuracyPct'] as num?)?.toDouble(),
    );
  }
}
