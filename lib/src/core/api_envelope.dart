/// Standard envelope ของ Thailand Geographic API.
///
/// ```json
/// {
///   "status": "success" | "error",
///   "message": "...",
///   "data":    <T>,
///   "error":   { "code": "...", "message": "..." }   // optional
/// }
/// ```
class ApiEnvelope<T> {
  const ApiEnvelope({required this.status, required this.message, this.data, this.errorCode, this.errorMessage});

  final String status;
  final String message;
  final T? data;
  final String? errorCode;
  final String? errorMessage;

  bool get isSuccess => status == 'success' || status == 'ok' || status == 'true';

  /// แกะ envelope ทั่วไป โดย caller จะ map `data` เองภายหลัง.
  factory ApiEnvelope.fromJson(Map<String, dynamic> json, T Function(Object? raw)? mapData) {
    final err = json['error'];
    // Server อาจส่ง success เป็น bool (true/false) หรือ string ("success"/"ok")
    final rawSuccess = json['success'];
    final String status;
    if (rawSuccess is bool) {
      status = rawSuccess ? 'true' : 'false';
    } else {
      status = (json['status'] ?? '').toString();
    }
    return ApiEnvelope<T>(
      status: status,
      message: (json['message'] ?? '').toString(),
      data: (mapData != null && json['data'] != null) ? mapData(json['data']) : json['data'] as T?,
      errorCode: err is Map ? err['code']?.toString() : null,
      errorMessage: err is Map ? err['message']?.toString() : null,
    );
  }
}
