import 'dart:async';

/// Entry หนึ่งใน cache.
class CacheEntry {
  CacheEntry(
      {required this.body,
      required this.storedAt,
      required this.staleAt,
      this.etag,
      this.contentType});

  /// raw response (Map / List / String / Uint8List)
  final Object? body;
  final DateTime storedAt;
  final DateTime staleAt;
  final String? etag;
  final String? contentType;

  bool get isFresh => DateTime.now().isBefore(staleAt);
}

/// Abstraction ของ cache เพื่อให้ผู้ใช้ swap ไป Hive / SharedPreferences ได้.
abstract class CacheStore {
  FutureOr<CacheEntry?> get(String key);
  FutureOr<void> set(String key, CacheEntry entry);
  FutureOr<void> remove(String key);
  FutureOr<void> clear();
}
