// Session + trial business logic.
//
// hidden k is generated and encrypted here on session creation. It is returned
// to the client ONLY so the existing client-side solver can run the simulation
// (the app computes each trial locally). It is kept private in the Flutter
// provider and never shown in the UI until the student submits their guess —
// the same hidden-k contract the original app already enforced.
const prisma = require('../prisma');
const crypto = require('crypto');
const { deriveKey, encrypt, decrypt } = require('../config/encryption');
const { generateHiddenK } = require('./encryption.service');

const MAX_TRIALS = 10; // server-side enforcement (client also enforces)
const MIN_TRIALS_TO_SUBMIT = 3;

const toNum = (d) => (d == null ? null : Number(d));

function trialDTO(t) {
  return {
    id: t.id,
    runNumber: t.runNumber,
    va: toNum(t.va),
    vb: toNum(t.vb),
    ca0: toNum(t.ca0),
    cb0: toNum(t.cb0),
    tau: toNum(t.tau),
    m: toNum(t.m),
    xa: toNum(t.xa),
    ca: toNum(t.ca),
    graphY: toNum(t.graphY),
  };
}

// Student-facing session view. actualK is only present after reveal.
function sessionDTO(s, { includeActualK = false } = {}) {
  const dto = {
    id: s.id,
    ca0Prime: toNum(s.ca0Prime),
    cb0Prime: toNum(s.cb0Prime),
    vr: toNum(s.vr),
    trialCount: s.trialCount,
    status: s.status,
    kRevealed: s.kRevealed,
    studentK: toNum(s.studentK),
    accuracyPct: toNum(s.accuracyPct),
    createdAt: s.createdAt,
    completedAt: s.completedAt,
    trials: (s.trials || []).map(trialDTO),
  };
  if (includeActualK && s.kRevealed) {
    dto.actualK = decryptHiddenK(s);
  }
  return dto;
}

function decryptHiddenK(s) {
  const key = deriveKey(s.studentId, s.id);
  return parseFloat(decrypt(s.encryptedK, key));
}

// ── Create ────────────────────────────────────────────────────────────────────
async function createSession({ studentId, ca0Prime, cb0Prime, vr }) {
  // Only one active session at a time — abandon any prior active ones.
  await prisma.session.updateMany({
    where: { studentId, status: 'active' },
    data: { status: 'abandoned' },
  });

  // Generate the session id up front so the encryption key can be derived from it.
  const sessionId = crypto.randomUUID();
  const hiddenK = generateHiddenK();
  const key = deriveKey(studentId, sessionId);
  const encryptedK = encrypt(hiddenK, key);

  const session = await prisma.session.create({
    data: {
      id: sessionId,
      studentId,
      encryptedK,
      ca0Prime,
      cb0Prime,
      vr,
      status: 'active',
      trialCount: 0,
    },
  });

  // hiddenK returned for client-side simulation (kept private in the app).
  return { session: sessionDTO(session), hiddenK };
}

// ── Active session (for resume) ─────────────────────────────────────────────────
async function getActiveSession(studentId) {
  const session = await prisma.session.findFirst({
    where: { studentId, status: 'active' },
    orderBy: { createdAt: 'desc' },
    include: { trials: { orderBy: { runNumber: 'asc' } } },
  });
  if (!session) return null;

  // Resume requires the client to keep simulating, so deliver hidden k.
  return { session: sessionDTO(session), hiddenK: decryptHiddenK(session) };
}

// ── Record a trial ──────────────────────────────────────────────────────────────
async function recordTrial({ studentId, sessionId, trial }) {
  const session = await prisma.session.findUnique({ where: { id: sessionId } });
  if (!session || session.studentId !== studentId) {
    throw Object.assign(new Error('Session not found'), { status: 404 });
  }
  if (session.status !== 'active') {
    throw Object.assign(new Error('Session is not active'), { status: 409 });
  }
  if (session.trialCount >= MAX_TRIALS) {
    throw Object.assign(
      new Error(`Maximum of ${MAX_TRIALS} trials reached`),
      { status: 409 },
    );
  }

  // Upsert-by-uniqueness: ignore a duplicate run_number (idempotent retry).
  const existing = await prisma.trial.findUnique({
    where: { sessionId_runNumber: { sessionId, runNumber: trial.runNumber } },
  });
  if (existing) {
    return { trialCount: session.trialCount, duplicate: true };
  }

  const [, updated] = await prisma.$transaction([
    prisma.trial.create({
      data: {
        sessionId,
        runNumber: trial.runNumber,
        va: trial.va,
        vb: trial.vb,
        ca0: trial.ca0,
        cb0: trial.cb0,
        tau: trial.tau,
        m: trial.m,
        xa: trial.xa,
        ca: trial.ca,
        graphY: trial.graphY,
      },
    }),
    prisma.session.update({
      where: { id: sessionId },
      data: { trialCount: { increment: 1 } },
    }),
  ]);

  return { trialCount: updated.trialCount, duplicate: false };
}

// ── Submit k (reveal) ───────────────────────────────────────────────────────────
async function submitStudentK({ studentId, sessionId, studentK }) {
  const session = await prisma.session.findUnique({ where: { id: sessionId } });
  if (!session || session.studentId !== studentId) {
    throw Object.assign(new Error('Session not found'), { status: 404 });
  }
  if (session.trialCount < MIN_TRIALS_TO_SUBMIT) {
    throw Object.assign(
      new Error(`At least ${MIN_TRIALS_TO_SUBMIT} trials required before submitting`),
      { status: 409 },
    );
  }

  const actualK = decryptHiddenK(session);
  const accuracyPct = (Math.abs(studentK - actualK) / actualK) * 100;

  await prisma.session.update({
    where: { id: sessionId },
    data: {
      studentK,
      kRevealed: true,
      accuracyPct,
      status: 'completed',
      completedAt: new Date(),
    },
  });

  return {
    actualK: Number(actualK.toFixed(6)),
    accuracyPct: Number(accuracyPct.toFixed(4)),
  };
}

module.exports = {
  MAX_TRIALS,
  MIN_TRIALS_TO_SUBMIT,
  createSession,
  getActiveSession,
  recordTrial,
  submitStudentK,
  sessionDTO,
  trialDTO,
  decryptHiddenK,
};
