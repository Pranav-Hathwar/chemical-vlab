// Auth business logic: registration, login, OAuth user resolution, and the
// JWT access/refresh token lifecycle (issue, rotate, revoke).
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const prisma = require('../prisma');
const {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
  hashToken,
  refreshExpiryDate,
} = require('../config/jwt');

const BCRYPT_ROUNDS = 12;

// ── Roles ─────────────────────────────────────────────────────────────────────
function adminEmails() {
  return (process.env.ADMIN_EMAILS || '')
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
}

function roleForEmail(email) {
  return adminEmails().includes(email.toLowerCase()) ? 'admin' : 'student';
}

// Public-safe view of a user (never leaks password_hash).
function publicUser(u) {
  return {
    id: u.id,
    email: u.email,
    displayName: u.displayName,
    role: u.role,
    provider: u.provider,
    photoUrl: u.photoUrl,
    createdAt: u.createdAt,
    lastLoginAt: u.lastLoginAt,
  };
}

// ── Token lifecycle ────────────────────────────────────────────────────────────
async function issueTokens(user) {
  const jti = crypto.randomUUID();
  const accessToken = signAccessToken(user);
  const refreshToken = signRefreshToken(user, jti);

  await prisma.refreshToken.create({
    data: {
      userId: user.id,
      tokenHash: hashToken(refreshToken),
      expiresAt: refreshExpiryDate(),
    },
  });

  return { accessToken, refreshToken, user: publicUser(user) };
}

// Verify + rotate a refresh token. Old token is revoked, a fresh pair is issued.
async function rotateRefreshToken(rawRefreshToken) {
  let payload;
  try {
    payload = verifyRefreshToken(rawRefreshToken);
  } catch (_) {
    throw Object.assign(new Error('Invalid or expired refresh token'), {
      status: 401,
    });
  }

  const tokenHash = hashToken(rawRefreshToken);
  const stored = await prisma.refreshToken.findUnique({ where: { tokenHash } });

  if (!stored || stored.isRevoked || stored.expiresAt < new Date()) {
    throw Object.assign(new Error('Refresh token no longer valid'), {
      status: 401,
    });
  }

  const user = await prisma.user.findUnique({ where: { id: payload.sub } });
  if (!user) {
    throw Object.assign(new Error('User no longer exists'), { status: 401 });
  }

  // Rotate: revoke the used token, then issue a brand-new pair.
  await prisma.refreshToken.update({
    where: { id: stored.id },
    data: { isRevoked: true },
  });

  return issueTokens(user);
}

async function revokeRefreshToken(rawRefreshToken) {
  if (!rawRefreshToken) return;
  const tokenHash = hashToken(rawRefreshToken);
  await prisma.refreshToken
    .updateMany({ where: { tokenHash }, data: { isRevoked: true } })
    .catch(() => {});
}

// ── Email/password ──────────────────────────────────────────────────────────────
async function registerUser({ email, displayName, password }) {
  const normalized = email.toLowerCase();
  const existing = await prisma.user.findUnique({ where: { email: normalized } });
  if (existing) {
    throw Object.assign(new Error('An account with this email already exists'), {
      status: 409,
    });
  }

  const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
  const user = await prisma.user.create({
    data: {
      email: normalized,
      displayName,
      passwordHash,
      role: roleForEmail(normalized),
      provider: 'email',
    },
  });

  return issueTokens(user);
}

async function loginUser({ email, password }) {
  const normalized = email.toLowerCase();
  const user = await prisma.user.findUnique({ where: { email: normalized } });

  // Uniform error to avoid leaking which emails exist.
  const invalid = Object.assign(new Error('Invalid email or password'), {
    status: 401,
  });
  if (!user || !user.passwordHash) throw invalid;

  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) throw invalid;

  // Re-evaluate role from the admin list on every login, then stamp last login.
  const updated = await prisma.user.update({
    where: { id: user.id },
    data: { role: roleForEmail(normalized), lastLoginAt: new Date() },
  });

  return issueTokens(updated);
}

// ── OAuth ──────────────────────────────────────────────────────────────────────
async function findOrCreateOAuthUser({
  email,
  displayName,
  providerId,
  photoUrl,
  provider,
}) {
  const normalized = email.toLowerCase();
  const role = roleForEmail(normalized);
  let user = await prisma.user.findUnique({ where: { email: normalized } });

  if (!user) {
    user = await prisma.user.create({
      data: {
        email: normalized,
        displayName: displayName || normalized.split('@')[0],
        role,
        provider,
        providerId,
        photoUrl,
      },
    });
  } else {
    user = await prisma.user.update({
      where: { id: user.id },
      data: {
        role,
        provider,
        providerId,
        photoUrl: photoUrl || user.photoUrl,
        lastLoginAt: new Date(),
      },
    });
  }

  return issueTokens(user);
}

module.exports = {
  roleForEmail,
  publicUser,
  issueTokens,
  rotateRefreshToken,
  revokeRefreshToken,
  registerUser,
  loginUser,
  findOrCreateOAuthUser,
};
