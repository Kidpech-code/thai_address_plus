import 'dart:collection';

import 'cache_store.dart';

/// Default LRU + TTL in-memory cache. ขนาดเล็ก (เหมาะกับ mobile).
///
/// ถ้าต้องการ persist ข้าม session — ผู้ใช้สามารถ implement [CacheStore]
/// เองด้วย Hive / SharedPreferences / sqflite แล้วส่งให้ [ThaiGeoClient].
class MemoryCacheStore implements CacheStore {
  MemoryCacheStore({this.maxEntries = 256});

  final int maxEntries;
  final LinkedHashMap<String, CacheEntry> _store = LinkedHashMap<String, CacheEntry>();

  @override
  CacheEntry? get(String key) {
    final v = _store.remove(key);
    if (v == null) return null;
    _store[key] = v; // mark as recently used
    return v;
  }

  @override
  void set(String key, CacheEntry entry) {
    if (_store.containsKey(key)) {
      _store.remove(key);
    } else if (_store.length >= maxEntries) {
      _store.remove(_store.keys.first);
    }
    _store[key] = entry;
  }

  @override
  void remove(String key) => _store.remove(key);

  @override
  void clear() => _store.clear();
}
