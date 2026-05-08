import 'dart:async';

import 'package:dio/dio.dart';

import '../../config/thai_geo_config.dart';
import '../cache/cache_store.dart';

/// Read-through cache สำหรับ GET requests.
///
/// กลยุทธ์:
/// 1. ก่อนยิง: ถ้ามี entry **ที่ยัง fresh** ใน [store] → resolve ทันที (0ms)
/// 2. ถ้าไม่มี/หมดอายุ: ปล่อยไปยิง upstream
/// 3. หลังได้ response 2xx → เก็บลง cache โดยใช้ TTL ตาม [ttlResolver]
///    (หรือใช้ค่าจาก `Cache-Control: max-age=...` ถ้ามี)
/// 4. ถ้ายิงพลาด: หาก [ThaiGeoConfig.staleWhileError] = true และมี stale entry
///    → คืน stale แทนที่จะ throw (stale-while-error)
class CacheInterceptor extends Interceptor {
  CacheInterceptor(
      {required this.config, required this.store, required this.ttlResolver});

  final ThaiGeoConfig config;
  final CacheStore store;

  /// Resolver ที่คืน TTL ของ request นี้. คืน `null` = ไม่ cache.
  final Duration? Function(RequestOptions options) ttlResolver;

  static const _ttlKey = '_thai_geo_ttl';

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.method.toUpperCase() != 'GET') return handler.next(options);

    final ttl = ttlResolver(options);
    if (ttl == null || ttl == Duration.zero) return handler.next(options);
    options.extra[_ttlKey] = ttl;

    final key = _cacheKey(options);
    CacheEntry? entry;
    try {
      entry = await store.get(key);
    } catch (_) {
      // store error — bypass cache and go straight to network
      return handler.next(options);
    }
    if (entry != null && entry.isFresh) {
      final response = Response<dynamic>(
        requestOptions: options,
        data: entry.body,
        statusCode: 200,
        statusMessage: 'OK (cache)',
        headers: Headers.fromMap({
          'x-thai-geo-cache': ['HIT'],
          if (entry.contentType != null)
            Headers.contentTypeHeader: [entry.contentType!],
        }),
        extra: {
          'fromCache': true,
          'cachedAt': entry.storedAt.toIso8601String()
        },
      );
      return handler.resolve(response);
    }

    handler.next(options);
  }

  @override
  Future<void> onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) async {
    final options = response.requestOptions;
    if (options.method.toUpperCase() != 'GET') return handler.next(response);
    if (response.extra['fromCache'] == true) return handler.next(response);

    final code = response.statusCode ?? 0;
    if (code < 200 || code >= 300) return handler.next(response);

    final ttl = _resolveTtl(options, response);
    if (ttl == null || ttl == Duration.zero) return handler.next(response);

    final now = DateTime.now();
    try {
      await store.set(
        _cacheKey(options),
        CacheEntry(
            body: response.data,
            storedAt: now,
            staleAt: now.add(ttl),
            contentType: response.headers.value(Headers.contentTypeHeader)),
      );
    } catch (_) {
      // store write failed — silently skip caching, response still delivered
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (!config.staleWhileError) return handler.next(err);
    // ห้ามแทนที่ cancelled request ด้วย stale — caller ต้องได้รับ cancel exception
    if (err.type == DioExceptionType.cancel) return handler.next(err);
    final options = err.requestOptions;
    if (options.method.toUpperCase() != 'GET') return handler.next(err);

    CacheEntry? entry;
    try {
      entry = await store.get(_cacheKey(options));
    } catch (_) {
      // store error — propagate original network error
      return handler.next(err);
    }
    if (entry == null) return handler.next(err);

    final response = Response<dynamic>(
      requestOptions: options,
      data: entry.body,
      statusCode: 200,
      statusMessage: 'OK (stale)',
      headers: Headers.fromMap({
        'x-thai-geo-cache': ['STALE'],
        if (entry.contentType != null)
          Headers.contentTypeHeader: [entry.contentType!],
      }),
      extra: {'fromCache': true, 'stale': true},
    );
    handler.resolve(response);
  }

  Duration? _resolveTtl(RequestOptions options, Response<dynamic> response) {
    // 1) ใช้ค่าที่ resolver เสนอไว้ตอน request (สูงสุด)
    final hinted = options.extra[_ttlKey];
    if (hinted is Duration) return hinted;
    // 2) อ่าน max-age จาก Cache-Control
    final cc = response.headers.value('cache-control');
    if (cc != null) {
      final m = RegExp(r'max-age\s*=\s*(\d+)').firstMatch(cc);
      if (m != null) {
        final secs = int.tryParse(m.group(1)!);
        if (secs != null && secs > 0) return Duration(seconds: secs);
      }
    }
    return null;
  }

  String _cacheKey(RequestOptions options) {
    final query = options.queryParameters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final qs = query.map((e) => '${e.key}=${e.value}').join('&');
    return '${options.method} ${options.path}${qs.isEmpty ? '' : '?$qs'}';
  }
}
