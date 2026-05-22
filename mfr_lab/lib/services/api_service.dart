// Dio HTTP client with auth + silent-refresh interceptor and friendly errors.
//
// • Attaches the Bearer access token to every request.
// • On a 401, transparently refreshes via /api/auth/refresh (rotating tokens),
//   then retries the original request once. Concurrent 401s share one refresh.
// • Maps network failures to friendly ApiException messages (offline handling).
import 'package:dio/dio.dart';

import '../constants.dart';
import '../models/api_response_model.dart';
import 'token_service.dart';

class ApiService {
  ApiService({required TokenService tokenService, Dio? dio})
      : _tokens = tokenService,
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = ApiConfig.baseUrl
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 20)
      ..headers['Content-Type'] = 'application/json'
      ..validateStatus = (status) => status != null && status < 500;

    // Bare client for the refresh call (no interceptors → no recursion).
    _refreshDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] != true) {
            final token = await _tokens.getAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final response = error.response;
          final isAuthError = response?.statusCode == 401;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;
          final isRefreshCall =
              error.requestOptions.path.contains(ApiConfig.refresh);

          if (isAuthError && !alreadyRetried && !isRefreshCall) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              try {
                final retried = await _retry(error.requestOptions);
                return handler.resolve(retried);
              } catch (_) {
                // fall through to propagate the original error
              }
            } else {
              onSessionExpired?.call();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  late final Dio _refreshDio;
  final TokenService _tokens;

  /// Invoked when refresh fails and the session can no longer be recovered.
  void Function()? onSessionExpired;

  Dio get dio => _dio;

  Future<void> _refreshLock = Future.value();
  bool _refreshing = false;

  Future<bool> _tryRefresh() async {
    // Serialise concurrent refreshes: wait for any in-flight one to finish.
    if (_refreshing) {
      await _refreshLock;
      return !await _tokens.isAccessExpired();
    }
    _refreshing = true;
    final completer = _doRefresh();
    _refreshLock = completer;
    final ok = await completer;
    _refreshing = false;
    return ok;
  }

  Future<bool> _doRefresh() async {
    try {
      final refreshToken = await _tokens.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final res = await _refreshDio.post(
        ApiConfig.refresh,
        data: {'refreshToken': refreshToken},
      );
      if (res.statusCode == 200 && res.data['success'] == true) {
        final data = res.data['data'];
        await _tokens.saveTokens(
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'],
        );
        return true;
      }
      await _tokens.clear();
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options) {
    final token = _tokens.getAccessToken();
    return token.then((t) {
      final headers = Map<String, dynamic>.from(options.headers);
      if (t != null) headers['Authorization'] = 'Bearer $t';
      return _dio.request(
        options.path,
        data: options.data,
        queryParameters: options.queryParameters,
        options: Options(
          method: options.method,
          headers: headers,
          extra: {...options.extra, 'retried': true},
        ),
      );
    });
  }

  // ── Public helpers ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool skipAuth = false,
  }) =>
      _send(() => _dio.get(path,
          queryParameters: query, options: Options(extra: {'skipAuth': skipAuth})));

  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
    bool skipAuth = false,
  }) =>
      _send(() => _dio.post(path,
          data: data, options: Options(extra: {'skipAuth': skipAuth})));

  /// Runs a request, normalises the {success,data,error} envelope, and throws
  /// an ApiException with a friendly message on any failure.
  Future<Map<String, dynamic>> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final res = await request();
      final body = res.data;
      if (body is Map && body['success'] == true) {
        return Map<String, dynamic>.from(body);
      }
      final message = (body is Map ? body['error']?.toString() : null) ??
          'Request failed (${res.statusCode})';
      throw ApiException(message, statusCode: res.statusCode);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      throw ApiException(_friendly(e), statusCode: e.response?.statusCode);
    } catch (e) {
      throw ApiException('Unexpected error: $e');
    }
  }

  String _friendly(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'The server took too long to respond. Please try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection or the server is unreachable.';
      default:
        final serverMsg = e.response?.data is Map
            ? e.response?.data['error']?.toString()
            : null;
        return serverMsg ?? 'Network error. Please check your connection.';
    }
  }
}
