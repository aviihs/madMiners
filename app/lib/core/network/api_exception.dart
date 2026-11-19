class ApiException implements Exception {
  const ApiException(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($status $code: $message)';
}

class OfflineException implements Exception {
  const OfflineException(this.cause);
  final Object cause;
}
