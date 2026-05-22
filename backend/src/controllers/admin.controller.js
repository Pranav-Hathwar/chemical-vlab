// HTTP handlers for admin-only views: students, sessions, decrypted k, stats.
// All routes here are protected by authenticate + requireAdmin.
const prisma = require('../prisma');
const sessionService = require('../services/session.service');

function ok(res, data, status = 200) {
  return res.status(status).json({ success: true, data });
}
function fail(res, err) {
  const status = err.status || 500;
  if (status >= 500) console.error(err);
  return res.status(status).json({ success: false, error: err.message });
}

// Dashboard summary stats.
async function stats(req, res) {
  try {
    const [studentCount, sessionCount, completedCount, accuracyAgg] =
      await Promise.all([
        prisma.user.count({ where: { role: 'student' } }),
        prisma.session.count(),
        prisma.session.count({ where: { status: 'completed' } }),
        prisma.session.aggregate({
          _avg: { accuracyPct: true },
          where: { kRevealed: true },
        }),
      ]);

    return ok(res, {
      totalStudents: studentCount,
      totalSessions: sessionCount,
      completedSessions: completedCount,
      avgAccuracyPct:
        accuracyAgg._avg.accuracyPct != null
          ? Number(accuracyAgg._avg.accuracyPct)
          : null,
    });
  } catch (err) {
    return fail(res, err);
  }
}

// All students with their session counts.
async function listStudents(req, res) {
  try {
    const students = await prisma.user.findMany({
      where: { role: 'student' },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        email: true,
        displayName: true,
        photoUrl: true,
        provider: true,
        createdAt: true,
        lastLoginAt: true,
        _count: { select: { sessions: true } },
      },
    });

    return ok(res, {
      students: students.map((s) => ({
        id: s.id,
        email: s.email,
        displayName: s.displayName,
        photoUrl: s.photoUrl,
        provider: s.provider,
        createdAt: s.createdAt,
        lastLoginAt: s.lastLoginAt,
        sessionCount: s._count.sessions,
      })),
    });
  } catch (err) {
    return fail(res, err);
  }
}

// One student + all their sessions (with trials) and the decrypted actual k.
async function getStudent(req, res) {
  try {
    const student = await prisma.user.findUnique({
      where: { id: req.params.id },
      include: {
        sessions: {
          orderBy: { createdAt: 'desc' },
          include: { trials: { orderBy: { runNumber: 'asc' } } },
        },
      },
    });
    if (!student) {
      return fail(res, Object.assign(new Error('Student not found'), { status: 404 }));
    }

    const sessions = student.sessions.map((s) => {
      const dto = sessionService.sessionDTO(s);
      // Admin always sees the real (decrypted) k.
      dto.actualK = Number(sessionService.decryptHiddenK(s).toFixed(6));
      return dto;
    });

    return ok(res, {
      student: {
        id: student.id,
        email: student.email,
        displayName: student.displayName,
        photoUrl: student.photoUrl,
        provider: student.provider,
        role: student.role,
        createdAt: student.createdAt,
        lastLoginAt: student.lastLoginAt,
      },
      sessions,
    });
  } catch (err) {
    return fail(res, err);
  }
}

// Full session detail with trials + decrypted k (for graph + Excel on admin side).
async function getSession(req, res) {
  try {
    const session = await prisma.session.findUnique({
      where: { id: req.params.id },
      include: {
        trials: { orderBy: { runNumber: 'asc' } },
        student: { select: { id: true, email: true, displayName: true } },
      },
    });
    if (!session) {
      return fail(res, Object.assign(new Error('Session not found'), { status: 404 }));
    }

    const dto = sessionService.sessionDTO(session);
    dto.actualK = Number(sessionService.decryptHiddenK(session).toFixed(6));
    dto.student = session.student;

    return ok(res, { session: dto });
  } catch (err) {
    return fail(res, err);
  }
}

module.exports = { stats, listStudents, getStudent, getSession };
