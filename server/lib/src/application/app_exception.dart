/// Application-level failure mapped to the standard API error envelope.
class AppException implements Exception {
  const AppException(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  static AppException badRequest(String code, String msg) => AppException(400, code, msg);
  static const unauthorized = AppException(401, 'UNAUTHORIZED', 'Missing or invalid token.');
  static const forbidden = AppException(403, 'FORBIDDEN', 'You cannot access this resource.');
  static AppException notFound(String what) => AppException(404, 'NOT_FOUND', '$what not found.');
  static AppException conflict(String code, String msg) => AppException(409, code, msg);
  static const rateLimited = AppException(429, 'RATE_LIMITED', 'Too many requests.');

  @override
  String toString() => 'AppException($status $code: $message)';
}
