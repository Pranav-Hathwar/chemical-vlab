// App-wide configuration constants for backend integration & auth.
//
// NOTE on host:
//   • Flutter web / Windows desktop  → http://localhost:4000
//   • Android emulator               → http://10.0.2.2:4000 (maps to host localhost)
//   • Physical device                → http://<your-PC-LAN-IP>:4000
// Override at build time with: --dart-define=API_BASE_URL=http://host:port
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Top-level app constants
//  NOTE: the API base URL is centralized in [ApiConfig] below (it resolves the
//  host per-platform — Android emulator → 10.0.2.2 — and supports
//  --dart-define=API_BASE_URL=...). There are no hardcoded URLs in screens.
// ─────────────────────────────────────────────────────────────────────────────

// App info
const String kAppName = 'MFR Virtual Lab';
const String kAppVersion = '1.0.0';

// Experiment rules (mirror the backend)
const int kMaxTrials = 10;
const double kMinK = 0.25;
const double kMaxK = 0.50;

// Asset paths
const String kReactorImagePath = 'assets/images/reactor_diagram.png';

class ApiConfig {
  ApiConfig._();

  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  /// Resolved base URL. On Android (non-web) localhost must be 10.0.2.2.
  static String get baseUrl {
    const fromEnv = _defaultBaseUrl;
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        fromEnv.contains('localhost')) {
      return fromEnv.replaceFirst('localhost', '10.0.2.2');
    }
    return fromEnv;
  }

  // ── Endpoint paths ──────────────────────────────────────────────────────────
  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String me = '/api/auth/me';
  static const String googleAuth = '/api/auth/google';

  static const String sessions = '/api/sessions';
  static const String activeSession = '/api/sessions/active';
  static String sessionTrials(String id) => '/api/sessions/$id/trials';
  static String sessionSubmit(String id) => '/api/sessions/$id/submit';

  static const String adminStats = '/api/admin/stats';
  static const String adminStudents = '/api/admin/students';
  static String adminStudent(String id) => '/api/admin/students/$id';
  static String adminSession(String id) => '/api/admin/sessions/$id';
}

class AuthConfig {
  AuthConfig._();

  // Google OAuth: web requires a meta tag in web/index.html; mobile uses the
  // platform client id from google-services config. Scopes only here.
  static const List<String> googleScopes = ['email', 'profile'];

  // Optional explicit Google web/desktop client id (otherwise plugin picks up
  // the meta tag). Fill from --dart-define=GOOGLE_CLIENT_ID=... if needed.
  static const String googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
}

class StorageKeys {
  StorageKeys._();
  static const String accessToken = 'mfr_access_token';
  static const String refreshToken = 'mfr_refresh_token';
}

// Shared business limits (must mirror the backend).
class LabLimits {
  LabLimits._();
  static const int maxTrials = kMaxTrials;
  static const int minTrialsToSubmit = 3;
}
