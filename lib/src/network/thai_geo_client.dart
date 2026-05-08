import 'package:dio/dio.dart';

import '../config/thai_geo_config.dart';
import '../core/api_envelope.dart';
import '../core/api_exception.dart';
import 'cache/cache_store.dart';
import 'cache/memory_cache_store.dart';
import 'interceptors/cache_interceptor.dart';
import 'interceptors/gzip_headers_interceptor.dart';
import 'interceptors/rate_limit_retry_interceptor.dart';

/// Low-level network client.
///
/// คนทั่วไปไม่ต้องใช้ตรง ๆ — ให้ใช้ [ThaiGeoApi] แทน.
/// แต่เปิด public ไว้กรณีต้อง fine-tune หรือ inject mock dio ใน test.
class ThaiGeoClient {
  ThaiGeoClient({ThaiGeoConfig? config, Dio? dio, CacheStore? cacheStore})
      : config = config ?? const ThaiGeoConfig(),
        cacheStore = cacheStore ?? MemoryCacheStore(),
        _dio = dio ?? Dio() {
    _bootstrap();
  }

  final ThaiGeoConfig config;
  final CacheStore cacheStore;
  final Dio _dio;

  Dio get dio => _dio;

  void _bootstrap() {
    _dio.options
      ..baseUrl = config.baseUrl.replaceAll(RegExp(r'/+$'), '')
      ..connectTimeout = config.connectTimeout
      ..receiveTimeout = config.receiveTimeout
      ..sendTimeout = config.sendTimeout
      ..responseType = ResponseType.json
      ..validateStatus = (s) => s != null && s >= 200 && s < 400;

    _dio.interceptors
      ..clear()
      ..add(GzipHeadersInterceptor(userAgent: config.userAgent))
      ..add(CacheInterceptor(
          config: config, store: cacheStore, ttlResolver: _resolveTtl))
      ..add(RateLimitRetryInterceptor(config, _dio));

    if (config.enableLogging) {
      _dio.interceptors
          .add(LogInterceptor(requestBody: false, responseBody: false));
    }
  }

  /// Map endpoint → TTL ตาม `FRONTEND_GUIDE.md` ตาราง Caching strategy.
  Duration? _resolveTtl(RequestOptions options) {
    final p = options.path;
    // GeoJSON / vector tile / country / find: 24h immutable
    if (p.contains('/geojson') ||
        p.contains('/tiles/') ||
        p.endsWith('/country') ||
        p.startsWith('/find')) {
      return config.defaultStaleTime;
    }
    if (p.startsWith('/autocomplete')) return config.autocompleteStaleTime;
    if (p.startsWith('/search')) return config.searchStaleTime;
    if (p.startsWith('/reverse') ||
        p.startsWith('/within') ||
        p.startsWith('/bbox') ||
        p.startsWith('/areas')) {
      return config.reverseStaleTime;
    }
    // Static lookups: provinces / districts / sub-districts / villages / zip / regions / stats
    return config.defaultStaleTime;
  }

  /// GET ที่ unwrap envelope ให้อัตโนมัติ. ใช้กับทุก endpoint ปกติ.
  Future<T> getEnvelope<T>(String path,
      {Map<String, dynamic>? query,
      required T Function(Object? raw) decode,
      CancelToken? cancelToken}) async {
    try {
      final res = await _dio.get<dynamic>(path,
          queryParameters: _stripNulls(query), cancelToken: cancelToken);
      final body = res.data;
      if (body is! Map<String, dynamic>) {
        throw GeoApiException(
            code: GeoErrorCode.parse,
            message: 'Expected JSON object envelope, got ${body.runtimeType}',
            requestPath: path);
      }
      final env = ApiEnvelope<T>.fromJson(body, decode);
      if (!env.isSuccess) {
        throw GeoApiException(
          code: env.errorCode ?? GeoErrorCode.unknown,
          message: env.errorMessage ?? env.message,
          statusCode: res.statusCode,
          requestPath: path,
        );
      }
      if (env.data == null) {
        throw GeoApiException(
            code: GeoErrorCode.parse,
            message: 'Envelope success but data is null',
            requestPath: path);
      }
      return env.data as T;
    } on DioException catch (e) {
      throw _mapDioError(e, path);
    } on GeoApiException {
      rethrow;
    } catch (e) {
      throw GeoApiException(
          code: GeoErrorCode.parse,
          message: e.toString(),
          requestPath: path,
          cause: e);
    }
  }

  /// GET raw (สำหรับ GeoJSON / MVT ที่ไม่ใช้ envelope).
  Future<T> getRaw<T>(String path,
      {Map<String, dynamic>? query,
      ResponseType responseType = ResponseType.json,
      CancelToken? cancelToken}) async {
    try {
      final res = await _dio.get<dynamic>(
        path,
        queryParameters: _stripNulls(query),
        options: Options(responseType: responseType),
        cancelToken: cancelToken,
      );
      if (res.data is! T) {
        throw GeoApiException(
            code: GeoErrorCode.parse,
            message: 'Expected ${T}, got ${res.data.runtimeType}',
            requestPath: path);
      }
      return res.data as T;
    } on DioException catch (e) {
      throw _mapDioError(e, path);
    } on GeoApiException {
      rethrow;
    } catch (e) {
      throw GeoApiException(
          code: GeoErrorCode.parse,
          message: e.toString(),
          requestPath: path,
          cause: e);
    }
  }

  /// POST envelope (ใช้กับ /reverse/batch).
  Future<T> postEnvelope<T>(String path,
      {required Object body,
      required T Function(Object? raw) decode,
      CancelToken? cancelToken}) async {
    try {
      final res = await _dio.post<dynamic>(
        path,
        data: body,
        cancelToken: cancelToken,
        options:
            Options(headers: {Headers.contentTypeHeader: 'application/json'}),
      );
      final raw = res.data;
      if (raw is! Map<String, dynamic>) {
        throw GeoApiException(
            code: GeoErrorCode.parse,
            message: 'Expected JSON object envelope, got ${raw.runtimeType}',
            requestPath: path);
      }
      final env = ApiEnvelope<T>.fromJson(raw, decode);
      if (!env.isSuccess) {
        throw GeoApiException(
          code: env.errorCode ?? GeoErrorCode.unknown,
          message: env.errorMessage ?? env.message,
          statusCode: res.statusCode,
          requestPath: path,
        );
      }
      if (env.data == null) {
        throw GeoApiException(
            code: GeoErrorCode.parse,
            message: 'Envelope success but data is null',
            requestPath: path);
      }
      return env.data as T;
    } on DioException catch (e) {
      throw _mapDioError(e, path);
    } on GeoApiException {
      rethrow;
    } catch (e) {
      throw GeoApiException(
          code: GeoErrorCode.parse,
          message: e.toString(),
          requestPath: path,
          cause: e);
    }
  }

  GeoApiException _mapDioError(DioException e, String path) {
    final status = e.response?.statusCode;
    String? code;
    String? message;
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final err = data['error'];
      if (err is Map) {
        code = err['code']?.toString();
        message = err['message']?.toString();
      }
      message ??= data['message']?.toString();
    }

    if (status == 429) {
      return GeoApiException(
        code: GeoErrorCode.rateLimited,
        message: message ?? 'Too many requests',
        statusCode: 429,
        retryAfter: _retryAfter(e),
        requestPath: path,
        cause: e,
      );
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return GeoApiException(
            code: GeoErrorCode.timeout,
            message: message ?? 'Request timed out',
            statusCode: status,
            requestPath: path,
            cause: e);
      case DioExceptionType.cancel:
        return GeoApiException(
            code: GeoErrorCode.cancelled,
            message: 'Request cancelled',
            requestPath: path,
            cause: e);
      case DioExceptionType.connectionError:
        return GeoApiException(
            code: GeoErrorCode.network,
            message: message ?? 'Network error',
            statusCode: status,
            requestPath: path,
            cause: e);
      case DioExceptionType.badResponse:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return GeoApiException(
          code: code ?? _codeFromStatus(status),
          message: message ?? (e.message ?? 'Unknown error'),
          statusCode: status,
          requestPath: path,
          cause: e,
        );
    }
  }

  String _codeFromStatus(int? status) {
    if (status == null) return GeoErrorCode.unknown;
    if (status == 400) return GeoErrorCode.badRequest;
    if (status == 404) return GeoErrorCode.notFound;
    if (status >= 500) return GeoErrorCode.internal;
    return GeoErrorCode.unknown;
  }

  Duration? _retryAfter(DioException e) {
    final v = e.response?.headers.value('retry-after');
    if (v == null || v.isEmpty) return null;
    // 1) integer seconds
    final asInt = int.tryParse(v.trim());
    if (asInt != null) return Duration(seconds: asInt);
    // 2) RFC 1123: "Mon, 01 Jan 2024 00:00:00 GMT"
    final m = RegExp(
            r'\w+,\s+(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+GMT')
        .firstMatch(v.trim());
    if (m != null) {
      const months = {
        'Jan': 1,
        'Feb': 2,
        'Mar': 3,
        'Apr': 4,
        'May': 5,
        'Jun': 6,
        'Jul': 7,
        'Aug': 8,
        'Sep': 9,
        'Oct': 10,
        'Nov': 11,
        'Dec': 12
      };
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
    final iso = DateTime.tryParse(v.trim());
    if (iso != null) {
      final diff = iso.toUtc().difference(DateTime.now().toUtc());
      return diff.isNegative ? Duration.zero : diff;
    }
    return null;
  }

  Map<String, dynamic>? _stripNulls(Map<String, dynamic>? q) {
    if (q == null) return null;
    final out = <String, dynamic>{};
    q.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      out[k] = v;
    });
    return out.isEmpty ? null : out;
  }
}
