/// Error code ที่ API นิยามไว้ (ดู `FRONTEND_GUIDE.md` หัวข้อ Error & rate-limit).
class GeoErrorCode {
  const GeoErrorCode._();

  static const String badRequest = 'BAD_REQUEST';
  static const String notFound = 'NOT_FOUND';
  static const String rateLimited = 'RATE_LIMITED';
  static const String internal = 'INTERNAL';

  /// Code เพิ่มเติมฝั่ง SDK
  static const String network = 'NETWORK';
  static const String timeout = 'TIMEOUT';
  static const String cancelled = 'CANCELLED';
  static const String parse = 'PARSE_ERROR';
  static const String unknown = 'UNKNOWN';
}

/// Exception เดียวที่ทุก method ของ SDK จะ throw.
///
/// - HTTP 429 → [code] = `RATE_LIMITED`, [retryAfter] อ่านจาก header
/// - HTTP 4xx/5xx → ใช้ค่าใน envelope `error.code`
/// - Network/Timeout → ใช้ code ฝั่ง SDK
class GeoApiException implements Exception {
  GeoApiException({required this.code, required this.message, this.statusCode, this.retryAfter, this.requestPath, this.cause});

  final String code;
  final String message;
  final int? statusCode;
  final Duration? retryAfter;
  final String? requestPath;
  final Object? cause;

  bool get isRateLimited => code == GeoErrorCode.rateLimited;
  bool get isNotFound => code == GeoErrorCode.notFound;
  bool get isRetryable => isRateLimited || (statusCode != null && statusCode! >= 500) || code == GeoErrorCode.network || code == GeoErrorCode.timeout;

  @override
  String toString() => 'GeoApiException($code, status=$statusCode, path=$requestPath): $message';
}
