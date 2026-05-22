# MFR Virtual Lab — Setup & Integration Guide

A virtual chemistry-lab app for determining a reactor rate constant `k`. It has
two parts:

```
MAD_EL/
├─ backend/   Node.js + Express + Prisma + PostgreSQL API
│             (auth, roles, AES-256-GCM encrypted hidden-k, session/trial storage)
└─ mfr_lab/   Flutter app (web + Android). The simulation math runs client-side;
              the backend adds accounts, roles, and persistence.
```

This guide takes you from a fresh clone to a running app with email/password and
Google login. **It assumes you have never seen this project.**
Follow the sections in order.

---

## 0. Prerequisites

Install these first. Versions in brackets are what this project was verified
against — newer is usually fine.

| Tool | Version | Get it |
|---|---|---|
| **Node.js** | ≥ 18 (tested v22) | <https://nodejs.org> |
| **PostgreSQL** | ≥ 14 (tested 18) | <https://www.postgresql.org/download/> |
| **Flutter SDK** | ≥ 3.3 (tested 3.41) | <https://docs.flutter.dev/get-started/install> |
| **Android SDK** | Platform 34+ (tested 36) | via Android Studio, for the APK only |
| **Chrome** | any recent | for `flutter run -d chrome` |

Verify:
```bash
node --version
psql --version          # or confirm the PostgreSQL service is running
flutter --version
flutter doctor          # fix anything it flags for your target platform
```

> **Android only:** if `flutter doctor` says *cmdline-tools missing* or
> *licenses not accepted*, install "Android SDK Command-line Tools" in Android
> Studio → SDK Manager, then run `flutter doctor --android-licenses` and accept
> all. The release APK build will fail to fetch SDK components otherwise.

---

## 1. PostgreSQL: create the database

You need a running PostgreSQL server and an empty database named `mfr_lab`.

1. Make sure the PostgreSQL service is running (Windows: Services → "postgresql-x64-…"; macOS/Linux: `pg_ctl`/systemd/brew services).
2. Create the database (any one of these):

   **psql:**
   ```bash
   psql -U postgres -c "CREATE DATABASE mfr_lab;"
   ```
   **createdb:**
   ```bash
   createdb -U postgres mfr_lab
   ```
   **pgAdmin:** right-click *Databases* → *Create* → *Database…* → name it `mfr_lab`.

   You do **not** need to create any tables — Prisma does that in §2.

3. Note your Postgres **username**, **password**, **host**, and **port** — you'll
   put them in `DATABASE_URL` next.

---

## 2. Backend: configure, migrate, run

```bash
cd backend
npm install
```

### 2a. Create your `.env`
Copy the template and open it:
```bash
cp .env.example .env          # macOS/Linux
Copy-Item .env.example .env   # Windows PowerShell
```
`.env.example` documents **every** variable. The ones you must set for a basic
(email/password) run:

- **`DATABASE_URL`** — your real connection string, e.g.
  `postgresql://postgres:YOURPASSWORD@localhost:5432/mfr_lab?schema=public`
- **`JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `ENCRYPTION_SECRET`** — generate a
  unique random value for each:
  ```bash
  node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
  ```
- **`ADMIN_EMAILS`** — comma-separated emails that become admins on login. Put
  your own email here so you can reach the Admin Dashboard.
- **`AUTH_RATE_MAX=1000`, `API_RATE_MAX=1000`** — keep these high **locally** so
  the smoke test and repeated logins aren't throttled. (In production, delete
  them to fall back to the secure defaults: 5/min auth, 100/min API.)

Google OAuth keys (`GOOGLE_*`) are only needed for §6 — email/password login
works without them.

### 2b. Create the tables (Prisma migrate)
```bash
npx prisma migrate dev        # applies migrations; creates tables in mfr_lab
```
If it prints *"Database schema is up to date!"* or runs the `init` migration,
you're good. Sanity-check anytime with `npx prisma migrate status`.

### 2c. Run the server
```bash
npm run dev                   # auto-reload (node --watch)
# or: npm start               # plain production start
```
You should see `✓ Connected to PostgreSQL` and
`✓ MFR Lab backend listening on http://localhost:4000`.
Confirm: open <http://localhost:4000/health> → `{"success":true,"status":"ok"}`.

### 2d. Make yourself an admin
Either add your email to `ADMIN_EMAILS` **before** logging in (role is applied on
login), or promote an existing user:
```bash
node scripts/promote-admin.js you@example.com
```

---

## 3. Run the smoke test (do this before the app)

With the backend running (§2c), in a second terminal:
```bash
cd backend
node scripts/smoke-test.js
```
**Passing looks like exactly this final line:**
```
=== RESULT: 22 passed, 0 failed ===
```
It exercises register/login/refresh, session + trial creation, the hidden-`k`
encrypt/decrypt round-trip, the 10-trial cap, admin-only access (403 for
students), and that `k` is stored encrypted at rest. If any check **fails**:

- *"Too many auth attempts"* / a crash near the admin step → set
  `AUTH_RATE_MAX=1000` and `API_RATE_MAX=1000` in `.env`, restart the server.
- *Cannot connect / ECONNREFUSED* → the server isn't running on port 4000.
- *Prisma/DB errors* → re-check `DATABASE_URL` and that §2b succeeded.

---

## 4. Run the Flutter web app

The backend's CORS allow-list expects the web app on **port 8087**, so pass
`--web-port=8087`:
```bash
cd mfr_lab
flutter pub get
flutter run -d chrome --web-port=8087
```
Register a new account (defaults to *student*), or log in with an admin email
from `ADMIN_EMAILS` to see the Admin Dashboard.

> The API base URL is resolved automatically: web/desktop → `http://localhost:4000`.
> Override with `--dart-define=API_BASE_URL=http://host:port` if needed.
> To enable Google sign-in on web, also pass the dart-define from §6.

---

## 5. Build & run the Android APK

> **Important — Flutter "startup lock":** you cannot build the APK while a
> `flutter run` (e.g. the web app) is active — the build will hang on
> *"Waiting for another flutter command to release the startup lock."*
> **Stop any running `flutter run` (Ctrl-C) first**, then build.

```bash
cd mfr_lab
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk` (~51 MB).
The release build is **debug-signed** (no keystore needed) — fine for sideloading
and testing, not for the Play Store. For Play, add a real keystore and replace
`signingConfig signingConfigs.debug` in `android/app/build.gradle`.

**Talking to the backend from a phone/emulator:** `localhost` on the device is
not your PC. Pass the right host:
- **Android emulator:** the app auto-maps `localhost` → `10.0.2.2`. Nothing to do.
- **Physical device (same Wi-Fi):** find your PC's LAN IP and pass it, and add it
  to `CORS_ORIGINS`:
  ```bash
  flutter build apk --release --dart-define=API_BASE_URL=http://<PC-LAN-IP>:4000
  ```

To install on a connected device: `flutter install` or
`adb install build/app/outputs/flutter-apk/app-release.apk`.

Toolchain in use (already configured): AGP 8.9.1, Kotlin 2.1.0, Gradle 8.11.1,
compileSdk 36, targetSdk 34, NDK 28.2. The "source/target value 8 is obsolete"
lines during the build are harmless warnings.

---

## 6. Google OAuth (optional — for "Sign in with Google")

The backend verifies Google tokens server-side; no Google secret is needed.

### In Google Cloud Console
1. Go to <https://console.cloud.google.com/apis/credentials> and select/create a project.
2. **OAuth consent screen** → External → add yourself as a *Test user* (if the app is unpublished).
3. **Create Credentials → OAuth client ID → Application type: Web application.**
4. Under **Authorized JavaScript origins** add: `http://localhost:8087` and `http://127.0.0.1:8087`.
5. Copy the **Client ID** (`…apps.googleusercontent.com`).

### Wire it up
1. In `backend/.env` set `GOOGLE_CLIENT_ID=<the client id>` and restart the server.
   (`GOOGLE_CLIENT_SECRET` is **not** used — leave it blank.)
2. Run the web app passing the **same** id:
   ```bash
   flutter run -d chrome --web-port=8087 --dart-define=GOOGLE_CLIENT_ID=<the client id>
   ```
3. Click **Sign in with Google**. Success = you land in the app authenticated.
   - *"audience mismatch" (401)* → the `.env` id and the `--dart-define` id differ.
   - *Popup blocked / origin error* → `http://localhost:8087` isn't in Authorized
     JavaScript origins, or you're not on port 8087.

> **Mobile Google sign-in** additionally needs an *Android* OAuth client whose
> SHA-1 you register in the console (`cd mfr_lab/android && ./gradlew signingReport`).

---

## 7. Security checklist (before sharing or deploying)

- `.env` is **gitignored** — never commit it. Each developer makes their own.
- **Rotate** `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `ENCRYPTION_SECRET` to
  fresh random values for any non-local use. Changing `ENCRYPTION_SECRET` makes
  previously stored hidden-`k` values undecryptable (fine for a fresh DB).
- Set `ADMIN_EMAILS` to your **real** admin email(s) only. Any email listed there
  becomes admin on login.
- In production, **remove** `AUTH_RATE_MAX` / `API_RATE_MAX` to use the secure
  defaults, and set `CORS_ORIGINS` to your real frontend origin(s) only.
- `password_hash` and `encrypted_k` are never returned by the API; the decrypted
  `k` is exposed only to admins or to the owning student's client.

---

## 8. API quick reference

| Method | Path | Who |
|---|---|---|
| GET | `/health` | public |
| POST | `/api/auth/register`, `/login`, `/refresh`, `/logout` | public |
| GET | `/api/auth/me` | any authenticated |
| POST | `/api/auth/google` | public |
| POST | `/api/sessions` | student |
| GET | `/api/sessions/active` | student |
| POST | `/api/sessions/:id/trials`, `/:id/submit` | student |
| GET | `/api/admin/stats`, `/students`, `/students/:id`, `/sessions/:id` | admin |

See `backend/README.md` for the full backend reference and migration commands.
```
