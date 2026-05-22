// Rate limiters: 5/min on auth endpoints, 100/min on general API.
const rateLimit = require('express-rate-limit');

// Defaults match the spec (5/min auth, 100/min api). Overridable via env for
// local testing only — production should leave these unset.
const authLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: Number(process.env.AUTH_RATE_MAX) || 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Too many auth attempts. Try again shortly.' },
});

const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: Number(process.env.API_RATE_MAX) || 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Too many requests. Slow down.' },
});

module.exports = { authLimiter, apiLimiter };
