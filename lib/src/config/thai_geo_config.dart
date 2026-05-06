import 'package:meta/meta.dart';

/// Configuration สำหรับ [ThaiGeoClient].
///
/// ค่า default ทั้งหมดถูกจูนให้เหมาะกับ "Thailand Geographic API"
/// โดยอ้างอิงตาม `docs/geo/FRONTEND_GUIDE.md`:
/// - Rate limit 60 req/min/IP (10 req/min สำหรับ /reverse/batch)
/// - GeoJSON response ขนาดใหญ่ → ต้องเปิด gzip
/// - Static lookup ส่วนใหญ่ TTL ฝั่ง server 24h → cache ฝั่ง client ก็ใช้ค่าเดียวกัน
@immutable
class ThaiGeoConfig {
  const ThaiGeoConfig({
    this.baseUrl = 'https://api.kidpech.app/api/v1/geo',
    this.connectTimeout = const Duration(seconds: 8),
    this.receiveTimeout = const Duration(seconds: 30),
    this.sendTimeout = const Duration(seconds: 15),
    this.userAgent = 'thai_address_plus/0.1 (+https://pub.dev)',
    this.maxRetries = 3,
    this.baseRetryDelay = const Duration(milliseconds: 300),
    this.maxRetryDelay = const Duration(seconds: 8),
    this.staleWhileError = true,
    this.defaultStaleTime = const Duration(hours: 24),
    this.autocompleteStaleTime = const Duration(minutes: 5),
    this.searchStaleTime = const Duration(minutes: 10),
    this.reverseStaleTime = const Duration(minutes: 10),
    this.enableLogging = false,
  });

  /// Base URL ของ API. ตัด `/` ท้ายออก.
  final String baseUrl;

  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;

  final String userAgent;

  /// จำนวนครั้งสูงสุดที่จะ retry เมื่อเจอ 429 / 5xx.
  final int maxRetries;

  /// ค่า base ของ exponential backoff. delay = base * 2^attempt + jitter.
  /// ถ้า server ส่ง `Retry-After` มา จะใช้ค่านั้นแทน.
  final Duration baseRetryDelay;
  final Duration maxRetryDelay;

  /// ถ้า `true` และเกิด network error: client จะคืน cached value ที่ "หมดอายุ"
  /// แทน throw exception (stale-while-error pattern).
  final bool staleWhileError;

  /// TTL default สำหรับ static lookup (provinces, districts, sub-districts, villages).
  final Duration defaultStaleTime;

  /// TTL สำหรับ /autocomplete (server cache 5 นาที).
  final Duration autocompleteStaleTime;

  /// TTL สำหรับ /search (server cache 10 นาที).
  final Duration searchStaleTime;

  /// TTL สำหรับ /reverse, /within, /bbox.
  final Duration reverseStaleTime;

  /// เปิด log request/response (debug only).
  final bool enableLogging;

  ThaiGeoConfig copyWith({
    String? baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    String? userAgent,
    int? maxRetries,
    Duration? baseRetryDelay,
    Duration? maxRetryDelay,
    bool? staleWhileError,
    Duration? defaultStaleTime,
    Duration? autocompleteStaleTime,
    Duration? searchStaleTime,
    Duration? reverseStaleTime,
    bool? enableLogging,
  }) => ThaiGeoConfig(
    baseUrl: baseUrl ?? this.baseUrl,
    connectTimeout: connectTimeout ?? this.connectTimeout,
    receiveTimeout: receiveTimeout ?? this.receiveTimeout,
    sendTimeout: sendTimeout ?? this.sendTimeout,
    userAgent: userAgent ?? this.userAgent,
    maxRetries: maxRetries ?? this.maxRetries,
    baseRetryDelay: baseRetryDelay ?? this.baseRetryDelay,
    maxRetryDelay: maxRetryDelay ?? this.maxRetryDelay,
    staleWhileError: staleWhileError ?? this.staleWhileError,
    defaultStaleTime: defaultStaleTime ?? this.defaultStaleTime,
    autocompleteStaleTime: autocompleteStaleTime ?? this.autocompleteStaleTime,
    searchStaleTime: searchStaleTime ?? this.searchStaleTime,
    reverseStaleTime: reverseStaleTime ?? this.reverseStaleTime,
    enableLogging: enableLogging ?? this.enableLogging,
  );
}
