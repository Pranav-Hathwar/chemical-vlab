// MFR Lab backend entrypoint.
require('dotenv').config();

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');

const prisma = require('./prisma');
const { apiLimiter } = require('./middleware/rateLimit.middleware');
const authRoutes = require('./routes/auth.routes');
const sessionRoutes = require('./routes/session.routes');
const adminRoutes = require('./routes/admin.routes');

const app = express();

// ── Security + parsing ──────────────────────────────────────────────────────
app.use(helmet());
app.use(express.json({ limit: '256kb' }));

const allowedOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

app.use(
  cors({
    origin(origin, cb) {
      // Allow non-browser clients (curl/mobile) with no Origin header.
      if (!origin || allowedOrigins.length === 0 || allowedOrigins.includes(origin)) {
        return cb(null, true);
      }
      return cb(new Error(`Origin ${origin} not allowed by CORS`));
    },
    credentials: true,
  }),
);

// ── Health check ────────────────────────────────────────────────────────────
app.get('/health', (req, res) => res.json({ success: true, status: 'ok' }));

// ── Routes ──────────────────────────────────────────────────────────────────
// General API limiter (100/min) applies to sessions + admin; auth has its own 5/min.
app.use('/api/auth', authRoutes);
app.use('/api/sessions', apiLimiter, sessionRoutes);
app.use('/api/admin', apiLimiter, adminRoutes);

// ── 404 + error handlers ────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, error: 'Not found' });
});

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err);
  const status = err.status || 500;
  res.status(status).json({ success: false, error: err.message || 'Server error' });
});

// ── Start ───────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 4000;

async function start() {
  try {
    await prisma.$connect();
    console.log('✓ Connected to PostgreSQL');
  } catch (e) {
    console.error('✗ Could not connect to PostgreSQL. Check DATABASE_URL in .env');
    console.error(e.message);
    process.exit(1);
  }
  app.listen(PORT, () => {
    console.log(`✓ MFR Lab backend listening on http://localhost:${PORT}`);
  });
}

start();

// Graceful shutdown
for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, async () => {
    await prisma.$disconnect();
    process.exit(0);
  });
}

module.exports = app;
