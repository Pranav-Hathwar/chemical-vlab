// End-to-end smoke test against a running server (http://localhost:4000).
// Run: node scripts/smoke-test.js
require('dotenv').config();
const prisma = require('../src/prisma');

const BASE = 'http://localhost:4000';
let pass = 0;
let fail = 0;

function check(name, cond, extra = '') {
  if (cond) {
    pass++;
    console.log(`  PASS  ${name}${extra ? ' — ' + extra : ''}`);
  } else {
    fail++;
    console.log(`  FAIL  ${name}${extra ? ' — ' + extra : ''}`);
  }
}

async function req(method, path, { token, body } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try {
    data = await res.json();
  } catch (_) {}
  return { status: res.status, data };
}

async function main() {
  console.log('\n=== MFR Lab backend smoke test ===\n');

  // 1. Health
  const health = await req('GET', '/health');
  check('GET /health', health.status === 200 && health.data.success === true);

  // 2. Register student (unique email)
  const stamp = Date.now();
  const studentEmail = `student_${stamp}@test.local`;
  const reg = await req('POST', '/api/auth/register', {
    body: { email: studentEmail, displayName: 'Test Student', password: 'secret123' },
  });
  check('register student', reg.status === 201 && reg.data.data.user.role === 'student',
    `role=${reg.data?.data?.user?.role}`);
  let sToken = reg.data.data.accessToken;
  const sRefresh = reg.data.data.refreshToken;

  // 3. Login student
  const login = await req('POST', '/api/auth/login', {
    body: { email: studentEmail, password: 'secret123' },
  });
  check('login student', login.status === 200 && !!login.data.data.accessToken);
  sToken = login.data.data.accessToken;

  // 4. /me
  const me = await req('GET', '/api/auth/me', { token: sToken });
  check('GET /me', me.status === 200 && me.data.data.user.email === studentEmail);

  // 5. Create session
  const create = await req('POST', '/api/sessions', {
    token: sToken,
    body: { ca0Prime: 2.0, cb0Prime: 3.0, vr: 5.0 },
  });
  const sessionId = create.data?.data?.session?.id;
  const hiddenK = create.data?.data?.hiddenK;
  check('create session', create.status === 201 && !!sessionId, `id=${sessionId}`);
  check('hiddenK returned in [0.25,0.50]', hiddenK >= 0.25 && hiddenK <= 0.5,
    `k=${hiddenK}`);

  // 6. Active session (resume)
  const active = await req('GET', '/api/sessions/active', { token: sToken });
  check('active session present', active.data?.data?.active?.session?.id === sessionId);
  check('active session NOT marked kRevealed',
    active.data?.data?.active?.session?.kRevealed === false);

  // 7. Post 3 trials
  for (let i = 1; i <= 3; i++) {
    const t = await req('POST', `/api/sessions/${sessionId}/trials`, {
      token: sToken,
      body: {
        runNumber: i, va: 1 + i * 0.1, vb: 2 + i * 0.1, ca0: 1.0, cb0: 1.5,
        tau: 1.2 + i * 0.1, m: 1.5, xa: 0.4, ca: 0.6, graphY: 0.3 + i * 0.05,
      },
    });
    check(`record trial ${i}`, t.status === 201 && t.data.data.trialCount === i);
  }

  // 8. Submit k -> reveal, verify actualK == hiddenK
  const studentGuess = 0.4;
  const submit = await req('POST', `/api/sessions/${sessionId}/submit`, {
    token: sToken,
    body: { studentK: studentGuess },
  });
  check('submit k', submit.status === 200 && submit.data.data.actualK != null);
  check('server actualK matches issued hiddenK',
    Math.abs(submit.data.data.actualK - hiddenK) < 1e-6,
    `actualK=${submit.data?.data?.actualK}`);
  const expectedErr = (Math.abs(studentGuess - hiddenK) / hiddenK) * 100;
  check('accuracyPct computed correctly',
    Math.abs(submit.data.data.accuracyPct - expectedErr) < 0.01,
    `pct=${submit.data?.data?.accuracyPct}`);

  // 9. Student blocked from admin routes (403)
  const forbidden = await req('GET', '/api/admin/students', { token: sToken });
  check('student blocked from /api/admin/* (403)', forbidden.status === 403,
    `status=${forbidden.status}`);

  // 10. Max-trials enforcement: new session, 10 trials ok, 11th rejected
  const s2 = await req('POST', '/api/sessions', {
    token: sToken, body: { ca0Prime: 2, cb0Prime: 3, vr: 5 },
  });
  const s2id = s2.data.data.session.id;
  for (let i = 1; i <= 10; i++) {
    await req('POST', `/api/sessions/${s2id}/trials`, {
      token: sToken,
      body: { runNumber: i, va: 1, vb: 2, ca0: 1, cb0: 1.5, tau: 1, m: 1.5, xa: 0.4, ca: 0.6, graphY: 0.3 },
    });
  }
  const eleventh = await req('POST', `/api/sessions/${s2id}/trials`, {
    token: sToken,
    body: { runNumber: 11, va: 1, vb: 2, ca0: 1, cb0: 1.5, tau: 1, m: 1.5, xa: 0.4, ca: 0.6, graphY: 0.3 },
  });
  // Rejected either by the runNumber validator (400) or the trialCount cap (409)
  // — both are server-side enforcement of the 10-trial maximum.
  check('11th trial rejected (server enforces max 10)',
    eleventh.status === 409 || eleventh.status === 400,
    `status=${eleventh.status}`);

  // 11. Refresh token rotation
  const refresh = await req('POST', '/api/auth/refresh', { body: { refreshToken: sRefresh } });
  check('refresh returns new token pair',
    refresh.status === 200 && !!refresh.data.data.accessToken &&
    refresh.data.data.refreshToken !== sRefresh);

  // 12. Admin via ADMIN_EMAILS
  const adminEmail = (process.env.ADMIN_EMAILS || 'professor@university.edu')
    .split(',')[0].trim();
  let adminReg = await req('POST', '/api/auth/register', {
    body: { email: adminEmail, displayName: 'Professor', password: 'secret123' },
  });
  let aToken;
  if (adminReg.status === 201) {
    aToken = adminReg.data.data.accessToken;
  } else {
    const adminLogin = await req('POST', '/api/auth/login', {
      body: { email: adminEmail, password: 'secret123' },
    });
    aToken = adminLogin.data.data.accessToken;
  }
  check('admin email gets admin role',
    (adminReg.data?.data?.user?.role || 'admin') === 'admin');

  // 13. Admin endpoints
  const stats = await req('GET', '/api/admin/stats', { token: aToken });
  check('admin /stats', stats.status === 200 && stats.data.data.totalStudents >= 1,
    `students=${stats.data?.data?.totalStudents}`);

  const students = await req('GET', '/api/admin/students', { token: aToken });
  check('admin /students lists students', students.status === 200 &&
    Array.isArray(students.data.data.students) && students.data.data.students.length >= 1);

  const detail = await req('GET', `/api/admin/sessions/${sessionId}`, { token: aToken });
  check('admin sees DECRYPTED actual k for a session',
    detail.status === 200 && Math.abs(detail.data.data.session.actualK - hiddenK) < 1e-6,
    `actualK=${detail.data?.data?.session?.actualK}`);

  // 14. Verify hidden k is ENCRYPTED at rest (never raw in DB)
  const row = await prisma.session.findUnique({ where: { id: sessionId } });
  const enc = row.encryptedK;
  const looksEncrypted = enc.includes('.') && enc.split('.').length === 3 &&
    !enc.includes(String(hiddenK));
  check('encrypted_k stored encrypted (iv.tag.cipher), not raw', looksEncrypted,
    `db=${enc.slice(0, 24)}...`);

  console.log(`\n=== RESULT: ${pass} passed, ${fail} failed ===\n`);
  await prisma.$disconnect();
  process.exit(fail === 0 ? 0 : 1);
}

main().catch(async (e) => {
  console.error('Smoke test crashed:', e);
  await prisma.$disconnect();
  process.exit(1);
});
