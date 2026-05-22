// JWT helpers — access tokens (short-lived) and refresh tokens (long-lived).
//
// Access token  : 15 min, signed with JWT_ACCESS_SECRET, carries { sub, email, role }.
// Refresh token : 7 days, signed with JWT_REFRESH_SECRET, carries { sub, jti }.
//   The refresh token's SHA-256 hash is stored in the DB so it can be rotated
//   and revoked. `jti` ties the JWT to a specific refresh_tokens row.
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET;
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET;
const ACCESS_EXPIRES = process.env.JWT_ACCESS_EXPIRES || '15m';
const REFRESH_EXPIRES = process.env.JWT_REFRESH_EXPIRES || '7d';

function signAccessToken(user) {
  return jwt.sign(
    { sub: user.id, email: user.email, role: user.role },
    ACCESS_SECRET,
    { expiresIn: ACCESS_EXPIRES },
  );
}

function signRefreshToken(user, jti) {
  return jwt.sign({ sub: user.id, jti }, REFRESH_SECRET, {
    expiresIn: REFRESH_EXPIRES,
  });
}

function verifyAccessToken(token) {
  return jwt.verify(token, ACCESS_SECRET);
}

function verifyRefreshToken(token) {
  return jwt.verify(token, REFRESH_SECRET);
}

// SHA-256 hash used to store refresh tokens at rest (never store the raw token).
function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

// Days from the configured refresh expiry, for computing DB expires_at.
function refreshExpiryDate() {
  const match = /^(\d+)d$/.exec(REFRESH_EXPIRES);
  const days = match ? parseInt(match[1], 10) : 7;
  return new Date(Date.now() + days * 24 * 60 * 60 * 1000);
}

module.exports = {
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  hashToken,
  refreshExpiryDate,
  ACCESS_EXPIRES,
  REFRESH_EXPIRES,
};
