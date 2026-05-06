import 'package:dio/dio.dart';

/// บังคับ header `Accept-Encoding: gzip` ให้ทุก request
/// (Dio บน VM/Flutter mobile จะ negotiate ให้อยู่แล้ว แต่บางแพลตฟอร์ม
/// — เช่น Web/CORS proxy — ต้องระบุชัดเพื่อให้ payload GeoJSON ลด 70-90%).
class GzipHeadersInterceptor extends Interceptor {
  GzipHeadersInterceptor({required this.userAgent});

  final String userAgent;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent('Accept-Encoding', () => 'gzip');
    options.headers.putIfAbsent('Accept', () => 'application/json');
    options.headers.putIfAbsent('User-Agent', () => userAgent);
    handler.next(options);
  }
}
