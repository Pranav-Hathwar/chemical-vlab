// Thin wrapper over the backend's uniform { success, data, error } envelope.
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;

  const ApiResponse({required this.success, this.data, this.error});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic data)? parse,
  ) {
    final success = json['success'] == true;
    return ApiResponse<T>(
      success: success,
      data: success && parse != null ? parse(json['data']) : null,
      error: json['error']?.toString(),
    );
  }

  factory ApiResponse.failure(String message) =>
      ApiResponse<T>(success: false, error: message);
}

/// Raised by service-layer calls so the UI can show a friendly message.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
