// Central auth state. Owns the service stack and exposes session/auth actions.
import 'package:flutter/foundation.dart';

import '../models/api_response_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/token_service.dart';

enum AuthStatus { unknown, authenticating, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    TokenService? tokenService,
    ApiService? apiService,
    AuthService? authService,
    SessionService? sessionService,
  }) {
    _tokens = tokenService ?? TokenService();
    _api = apiService ?? ApiService(tokenService: _tokens);
    _auth = authService ?? AuthService(api: _api, tokens: _tokens);
    _sessions = sessionService ?? SessionService(api: _api);

    // When silent refresh permanently fails, drop to the login screen.
    _api.onSessionExpired = _forceLogout;
  }

  late final TokenService _tokens;
  late final ApiService _api;
  late final AuthService _auth;
  late final SessionService _sessions;

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _error;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Exposed so screens can make session/admin API calls through the same stack.
  SessionService get sessions => _sessions;

  void _setStatus(AuthStatus s) {
    _status = s;
    notifyListeners();
  }

  // ── Startup: restore session if a valid refresh token exists ───────────────────
  Future<void> bootstrap() async {
    if (!await _tokens.hasUsableSession()) {
      _setStatus(AuthStatus.unauthenticated);
      return;
    }
    try {
      _user = await _auth.me(); // interceptor refreshes the access token if needed
      _setStatus(AuthStatus.authenticated);
    } catch (_) {
      await _tokens.clear();
      _user = null;
      _setStatus(AuthStatus.unauthenticated);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────────
  Future<bool> login(String email, String password) =>
      _run(() => _auth.login(email: email, password: password));

  Future<bool> register(String email, String displayName, String password) =>
      _run(() => _auth.register(
          email: email, displayName: displayName, password: password));

  Future<bool> signInWithGoogle() => _run(_auth.signInWithGoogle);

  Future<bool> _run(Future<UserModel> Function() action) async {
    _error = null;
    _setStatus(AuthStatus.authenticating);
    try {
      _user = await action();
      _setStatus(AuthStatus.authenticated);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _setStatus(AuthStatus.unauthenticated);
      return false;
    } catch (e) {
      _error = e.toString();
      _setStatus(AuthStatus.unauthenticated);
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    _user = null;
    _error = null;
    _setStatus(AuthStatus.unauthenticated);
  }

  void _forceLogout() {
    _user = null;
    _setStatus(AuthStatus.unauthenticated);
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}
