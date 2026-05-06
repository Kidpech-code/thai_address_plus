import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

import '../../config/thai_geo_config.dart';

/// Auto-retry สำหรับ:
/// - HTTP 429 (Too Many Requests) → อ่าน `Retry-After` (วินาที หรือ HTTP-date) ก่อน
/// - HTTP 5xx
/// - Network/Timeout error
///
/// ใช้ exponential backoff + jitter: `delay = base * 2^attempt + rand(0..200ms)`
/// ถูกจำกัดด้วย [ThaiGeoConfig.maxRetryDelay].
class RateLimitRetryInterceptor extends Interceptor {
  RateLimitRetryInterceptor(this.config, this.dio);

  final ThaiGeoConfig config;
  final Dio dio;
  final Random _rng = Random();

  static const _attemptKey = '_thai_geo_retry_attempt';

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final attempt = (req.extra[_attemptKey] as int?) ?? 0;

    if (!_shouldRetry(err) || attempt >= config.maxRetries) {
      return handler.next(err);
    }

    final delay = _computeDelay(err, attempt);
    await Future<void>.delayed(delay);

    // ถ้า user cancel ระหว่าง delay → propagate cancel แทนที่จะยิง request ใหม่
    if (req.cancelToken?.isCancelled == true) {
      return handler.next(DioException(requestOptions: req, type: DioExceptionType.cancel, message: 'Cancelled during retry delay'));
    }

    req.extra[_attemptKey] = attempt + 1;

    try {
      // รวม cancel token เดิมไว้
      final response = await dio.fetch<dynamic>(req);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  bool _shouldRetry(DioException err) {
    // ห้าม retry สำหรับ POST /reverse/batch (rate limit แยก 10/min,
    // และเป็น mutation-ish call ที่ผู้ใช้ควรคุมเอง)
    final path = err.requestOptions.path;
    if (err.requestOptions.method.toUpperCase() == 'POST' && path.contains('/reverse/batch')) {
      // อนุญาตเฉพาะกรณี network/timeout เท่านั้น
      switch (err.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return true;
        default:
          return false;
      }
    }

    final status = err.response?.statusCode;
    if (status == 429) return true;
    if (status != null && status >= 500 && status < 600) return true;

    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return true;
      default:
        return false;
    }
  }

  Duration _computeDelay(DioException err, int attempt) {
    // 1) ให้เกียรติ Retry-After ของ server ก่อน
    final ra = err.response?.headers.value('retry-after');
    final fromHeader = _parseRetryAfter(ra);
    if (fromHeader != null) {
      final capped = fromHeader > config.maxRetryDelay ? config.maxRetryDelay : fromHeader;
      return capped;
    }

    // 2) Exponential backoff + jitter
    final baseMs = config.baseRetryDelay.inMilliseconds;
    final expMs = baseMs * pow(2, attempt).toInt();
    final jitter = _rng.nextInt(200);
    final total = expMs + jitter;
    final maxMs = config.maxRetryDelay.inMilliseconds;
    return Duration(milliseconds: total > maxMs ? maxMs : total);
  }

  Duration? _parseRetryAfter(String? value) {
    if (value == null || value.isEmpty) return null;
    // 1) ตัวเลขวินาที (รูปแบบที่ API ส่งมาบ่อยที่สุด)
    final asInt = int.tryParse(value.trim());
    if (asInt != null) return Duration(seconds: asInt);
    // 2) RFC 1123 HTTP-date: "Mon, 01 Jan 2024 00:00:00 GMT"
    final m = RegExp(r'\w+,\s+(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+GMT').firstMatch(value.trim());
    if (m != null) {
      const months = {'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12};
      final month = months[m.group(2)!];
      if (month != null) {
        final date = DateTime.utc(
          int.parse(m.group(3)!),
          month,
          int.parse(m.group(1)!),
          int.parse(m.group(4)!),
          int.parse(m.group(5)!),
          int.parse(m.group(6)!),
        );
        final diff = date.difference(DateTime.now().toUtc());
        return diff.isNegative ? Duration.zero : diff;
      }
    }
    // 3) ISO 8601 fallback
    final iso = DateTime.tryParse(value.trim());
    if (iso != null) {
      final diff = iso.toUtc().difference(DateTime.now().toUtc());
      return diff.isNegative ? Duration.zero : diff;
    }
    return null;
  }
}
