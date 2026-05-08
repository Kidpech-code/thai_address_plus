import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thai_address_plus/thai_address_plus.dart';

/// Lightweight HttpClientAdapter ที่ตอบ canned responses
/// — ใช้ทดสอบ caching + retry โดยไม่ยิง network จริง.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions o) handler;
  int callCount = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    callCount++;
    return handler(options);
  }
}

ResponseBody _json(Object body,
    {int status = 200, Map<String, List<String>>? headers}) {
  final bytes = utf8.encode(jsonEncode(body));
  return ResponseBody.fromBytes(
    bytes,
    status,
    headers: {
      'content-type': ['application/json'],
      ...?headers,
    },
  );
}

void main() {
  group('ThaiGeoApi', () {
    test('listProvinces unwraps envelope', () async {
      final adapter = _FakeAdapter((o) async {
        expect(o.path, '/provinces');
        expect(o.headers['Accept-Encoding'], 'gzip');
        return _json({
          'status': 'success',
          'message': 'ok',
          'data': [
            {
              'pcode': 'TH10',
              'name_th': 'กรุงเทพมหานคร',
              'name_en': 'Bangkok',
              'region': 'central',
              'area_sqkm': 1568.7,
              'centroid_lng': 100.5,
              'centroid_lat': 13.7,
              'bbox_min_lng': 100.3,
              'bbox_min_lat': 13.5,
              'bbox_max_lng': 100.9,
              'bbox_max_lat': 13.9,
              'distance_to_bangkok_km': 0.0,
              'is_coastal': false,
            },
          ],
        });
      });

      final dio = Dio()..httpClientAdapter = adapter;
      final api = ThaiGeoApi(client: ThaiGeoClient(dio: dio));
      final list = await api.listProvinces();
      expect(list, hasLength(1));
      expect(list.first.pcode, 'TH10');
    });

    test('second GET served from cache', () async {
      final adapter = _FakeAdapter((o) async =>
          _json({'status': 'success', 'message': 'ok', 'data': []}));
      final dio = Dio()..httpClientAdapter = adapter;
      final api = ThaiGeoApi(client: ThaiGeoClient(dio: dio));
      await api.listProvinces();
      await api.listProvinces();
      expect(adapter.callCount, 1);
    });

    test('NOT_FOUND on 404', () async {
      final adapter = _FakeAdapter(
        (o) async => _json({
          'status': 'error',
          'message': 'not found',
          'error': {'code': 'NOT_FOUND', 'message': 'pcode missing'},
        }, status: 404),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final api = ThaiGeoApi(client: ThaiGeoClient(dio: dio));
      await expectLater(
          api.getProvince('TH99'),
          throwsA(isA<GeoApiException>()
              .having((e) => e.code, 'code', GeoErrorCode.notFound)));
    });

    test('retries on 429 then succeeds', () async {
      var calls = 0;
      final adapter = _FakeAdapter((o) async {
        calls++;
        if (calls == 1) {
          return _json(
            {
              'status': 'error',
              'message': 'rl',
              'error': {'code': 'RATE_LIMITED', 'message': 'slow down'},
            },
            status: 429,
            headers: {
              'retry-after': ['0'],
            },
          );
        }
        return _json({'status': 'success', 'message': 'ok', 'data': []});
      });
      final dio = Dio()..httpClientAdapter = adapter;
      final api = ThaiGeoApi(
        client: ThaiGeoClient(
          dio: dio,
          config: const ThaiGeoConfig(
              maxRetries: 2, baseRetryDelay: Duration(milliseconds: 1)),
        ),
      );
      final list = await api.listProvinces();
      expect(list, isEmpty);
      expect(calls, 2);
    });
  });
}
