// Auth API calls: email register/login, Google OAuth, logout, me.
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../constants.dart';
import '../models/api_response_model.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'token_service.dart';

class AuthService {
  AuthService({required ApiService api, required TokenService tokens})
      : _api = api,
        _tokens = tokens;

  final ApiService _api;
  final TokenService _tokens;

  // Persist tokens from an auth payload and return the user.
  Future<UserModel> _consumeAuth(Map<String, dynamic> data) async {
    await _tokens.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  // ── Email / password ─────────────────────────────────────────────────────────
  Future<UserModel> register({
    required String email,
    required String displayName,
    required String password,
  }) async {
    final res = await _api.post(
      ApiConfig.register,
      data: {'email': email, 'displayName': displayName, 'password': password},
      skipAuth: true,
    );
    return _consumeAuth(res['data'] as Map<String, dynamic>);
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.post(
      ApiConfig.login,
      data: {'email': email, 'password': password},
      skipAuth: true,
    );
    return _consumeAuth(res['data'] as Map<String, dynamic>);
  }

  Future<UserModel> me() async {
    final res = await _api.get(ApiConfig.me);
    return UserModel.fromJson(
      (res['data'] as Map<String, dynamic>)['user'] as Map<String, dynamic>,
    );
  }

  Future<void> logout() async {
    final refresh = await _tokens.getRefreshToken();
    try {
      await _api.post(
        ApiConfig.logout,
        data: {'refreshToken': refresh},
        skipAuth: true,
      );
    } catch (_) {
      // Even if the server call fails, clear local tokens.
    } finally {
      await _tokens.clear();
    }
  }

  // ── Google OAuth ─────────────────────────────────────────────────────────────

  Future<UserModel> signInWithGoogle() async {
    // Google Sign-In on web REQUIRES a real OAuth client id. We gate on the
    // compile-time GOOGLE_CLIENT_ID (--dart-define) so this fails with a clear
    // message instead of crashing inside the plugin with a raw assertion.
    // (This is a compile-time constant — no runtime DOM lookup, so it is
    // 100% reliable.) The same id is passed to GoogleSignIn below to enable it.
    if (kIsWeb && AuthConfig.googleClientId.isEmpty) {
      throw const ApiException(
        'Google sign-in is not configured. Launch with '
        '--dart-define=GOOGLE_CLIENT_ID=<your-web-client-id> '
        '(see INTEGRATION_README §3), or use email / password.',
      );
    }

    final googleSignIn = GoogleSignIn(
      scopes: AuthConfig.googleScopes,
      clientId:
          AuthConfig.googleClientId.isNotEmpty ? AuthConfig.googleClientId : null,
    );
    final account = await googleSignIn.signIn();
    if (account == null) {
      throw const ApiException('Google sign-in was cancelled');
    }
    final auth = await account.authentication;
    // On web the plugin reliably provides an access token (not an idToken), so
    // we send the access token; the backend validates it and reads the profile.
    final accessToken = auth.accessToken;
    final idToken = auth.idToken;
    if (accessToken == null && idToken == null) {
      throw const ApiException('Google did not return a usable token');
    }

    final res = await _api.post(
      ApiConfig.googleAuth,
      data: {
        if (accessToken != null) 'accessToken': accessToken,
        if (idToken != null) 'idToken': idToken,
      },
      skipAuth: true,
    );
    return _consumeAuth(res['data'] as Map<String, dynamic>);
  }
}
