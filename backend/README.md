# MFR Lab Backend

Node.js + Express + Prisma + PostgreSQL API for the MFR Virtual Lab: auth,
role-based access (admin/student), and encrypted session/trial persistence.

## Stack
- Express 4, Helmet, CORS (allow-list), express-rate-limit, express-validator
- Prisma ORM → PostgreSQL
- JWT (15-min access, 7-day rotating refresh), bcrypt password hashing
- AES-256-GCM encryption of the hidden rate constant `k`

## Setup

```bash
cd backend
npm install
cp .env.example .env      # then fill in the values (see below)
npx prisma migrate dev    # creates the DB + tables
npm run dev               # http://localhost:4000  (GET /health)
```

`npm start` runs the production entrypoint (`node src/index.js`). A `Procfile`
(`web: node src/index.js`) is included for Railway/Render.

## Environment variables

| Var | Purpose |
|---|---|
| `PORT` | Server port (hosts inject this; defaults to 4000) |
| `NODE_ENV` | `development` / `production` |
| `CORS_ORIGINS` | Comma-separated allowed app origins (no wildcard) |
| `DATABASE_URL` | PostgreSQL connection string |
| `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` | JWT signing secrets |
| `JWT_ACCESS_EXPIRES` / `JWT_REFRESH_EXPIRES` | Token lifetimes (`15m` / `7d`) |
| `ENCRYPTION_SECRET` | Master secret for AES-256 hidden-k encryption |
| `ADMIN_EMAILS` | Comma-separated emails granted admin on login |
| `GOOGLE_CLIENT_ID` | Google OAuth (web client id; the secret is not used) |
| `AUTH_RATE_MAX` / `API_RATE_MAX` | Optional rate-limit overrides (5 / 100 per min) |

Generate strong secrets:
```bash
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

## Migrations
```bash
npx prisma migrate dev --name <name>   # create + apply a new migration (dev)
npx prisma migrate deploy              # apply migrations (production)
npx prisma generate                    # regenerate the client
npx prisma studio                      # browse data
```

## Setting an admin
Either add the email to `ADMIN_EMAILS` (role is applied on next login), or
promote an existing user:
```bash
node scripts/promote-admin.js professor@university.edu
```

## API endpoints

| Method | Path | Auth |
|---|---|---|
| GET  | `/health` | public |
| POST | `/api/auth/register` | public |
| POST | `/api/auth/login` | public |
| POST | `/api/auth/refresh` | public (refresh token) |
| POST | `/api/auth/logout` | public |
| GET  | `/api/auth/me` | any authenticated |
| POST | `/api/auth/google` | public (Google token) |
| POST | `/api/sessions` | student |
| GET  | `/api/sessions/active` | student |
| POST | `/api/sessions/:id/trials` | student |
| POST | `/api/sessions/:id/submit` | student |
| GET  | `/api/admin/stats` | admin |
| GET  | `/api/admin/students` | admin |
| GET  | `/api/admin/students/:id` | admin |
| GET  | `/api/admin/sessions/:id` | admin |

## Security notes
- `password_hash` is never returned in any response (`publicUser()` strips it).
- `encrypted_k` is never returned; the decrypted `k` is exposed only to admins,
  or to the owning student's client for the in-browser simulation (kept private
  in the app until they submit their guess).
- Students receive `403` on any `/api/admin/*` route and cannot read other
  students' data. The 10-trial cap is enforced server-side as well as client-side.

## Smoke test
With the server running:
```bash
node scripts/smoke-test.js   # 22 end-to-end checks
```
