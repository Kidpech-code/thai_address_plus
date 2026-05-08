import 'dart:async' show unawaited;

import 'package:dio/dio.dart' show CancelToken;

import '../config/thai_geo_config.dart';
import '../core/api_exception.dart';
import '../models/autocomplete_hit.dart';
import '../models/district.dart';
import '../models/geojson.dart';
import '../models/province.dart';
import '../models/reverse_result.dart';
import '../models/sub_district.dart';
import '../models/village.dart';
import '../network/cache/cache_store.dart';
import '../network/thai_geo_client.dart';

/// **High-level facade** ของ Thailand Geographic API.
///
/// ทุก method:
/// - ส่ง `Accept-Encoding: gzip` ให้อัตโนมัติ
/// - cache GET responses ตาม TTL ของแต่ละกลุ่ม endpoint
/// - retry เมื่อเจอ 429 / 5xx ด้วย exponential backoff + Retry-After
///
/// ```dart
/// final geo = ThaiGeoApi();
/// final provinces = await geo.listProvinces();          // 0ms hit ครั้งที่สอง
/// final tambons   = await geo.listSubDistrictsOfDistrict('TH1001');
/// final villages  = await geo.listVillagesOfSubDistrict('TH100101');
/// ```
class ThaiGeoApi {
  ThaiGeoApi(
      {ThaiGeoConfig? config, CacheStore? cacheStore, ThaiGeoClient? client})
      : assert(
          client == null || (config == null && cacheStore == null),
          'Do not pass config/cacheStore together with a pre-built client — they will be ignored.',
        ),
        client =
            client ?? ThaiGeoClient(config: config, cacheStore: cacheStore);

  final ThaiGeoClient client;

  // ────────── PROVINCES ──────────

  /// คืน 77 จังหวัด (cache 24h ฝั่ง client โดย default).
  /// [region]: `north` | `northeast` | `central` | `east` | `west` | `south`
  Future<List<Province>> listProvinces(
          {String? region, bool? isCoastal, CancelToken? cancelToken}) =>
      client.getEnvelope<List<Province>>(
        '/provinces',
        query: {
          if (region != null) 'region': region,
          if (isCoastal != null) 'is_coastal': isCoastal
        },
        decode: (raw) => _list(raw, Province.fromJson),
        cancelToken: cancelToken,
      );

  Future<Province> getProvince(String pcode, {CancelToken? cancelToken}) =>
      client.getEnvelope<Province>(
        '/provinces/$pcode',
        decode: (raw) => Province.fromJson(_asMap(raw, 'Province')),
        cancelToken: cancelToken,
      );

  Future<List<District>> listDistrictsOfProvince(String pcode,
          {CancelToken? cancelToken}) =>
      client.getEnvelope<List<District>>('/provinces/$pcode/districts',
          decode: (raw) => _list(raw, District.fromJson),
          cancelToken: cancelToken);

  Future<List<Province>> listProvinceNeighbors(String pcode,
          {int depth = 1, CancelToken? cancelToken}) =>
      client.getEnvelope<List<Province>>(
        '/provinces/$pcode/neighbors',
        query: {'depth': depth},
        decode: (raw) => _list(raw, Province.fromJson),
        cancelToken: cancelToken,
      );

  // ────────── DISTRICTS ──────────

  Future<District> getDistrict(String pcode, {CancelToken? cancelToken}) =>
      client.getEnvelope<District>(
        '/districts/$pcode',
        decode: (raw) => District.fromJson(_asMap(raw, 'District')),
        cancelToken: cancelToken,
      );

  Future<List<SubDistrict>> listSubDistrictsOfDistrict(String pcode,
          {CancelToken? cancelToken}) =>
      client.getEnvelope<List<SubDistrict>>(
        '/districts/$pcode/sub-districts',
        decode: (raw) => _list(raw, SubDistrict.fromJson),
        cancelToken: cancelToken,
      );

  // ────────── SUB-DISTRICTS ──────────

  Future<SubDistrict> getSubDistrict(String pcode,
          {CancelToken? cancelToken}) =>
      client.getEnvelope<SubDistrict>(
        '/sub-districts/$pcode',
        decode: (raw) => SubDistrict.fromJson(_asMap(raw, 'SubDistrict')),
        cancelToken: cancelToken,
      );

  Future<List<SubDistrict>> listSubDistricts({
    String? province,
    String? district,
    bool? isCoastal,
    bool? isIsland,
    double? maxDistanceBkkKm,
    int? limit,
    int? offset,
    CancelToken? cancelToken,
  }) =>
      client.getEnvelope<List<SubDistrict>>(
        '/sub-districts',
        query: {
          if (province != null) 'province': province,
          if (district != null) 'district': district,
          if (isCoastal != null) 'is_coastal': isCoastal,
          if (isIsland != null) 'is_island': isIsland,
          if (maxDistanceBkkKm != null) 'max_distance_bkk_km': maxDistanceBkkKm,
          if (limit != null) 'limit': limit,
          if (offset != null) 'offset': offset,
        },
        decode: (raw) => _list(raw, SubDistrict.fromJson),
        cancelToken: cancelToken,
      );

  // ────────── VILLAGES (หมู่บ้าน) ──────────

  /// ดึงหมู่บ้านทั้งหมดในตำบลที่ระบุ — เหมาะกับ dropdown 4 ระดับ
  /// (จังหวัด → อำเภอ → ตำบล → **หมู่บ้าน**).
  Future<List<Village>> listVillagesOfSubDistrict(String pcode,
          {CancelToken? cancelToken}) =>
      client.getEnvelope<List<Village>>('/sub-districts/$pcode/villages',
          decode: (raw) => _list(raw, Village.fromJson),
          cancelToken: cancelToken);

  Future<Village> getVillage(int mainId, {CancelToken? cancelToken}) =>
      client.getEnvelope<Village>(
        '/villages/$mainId',
        decode: (raw) => Village.fromJson(_asMap(raw, 'Village')),
        cancelToken: cancelToken,
      );

  // ────────── ZIP / REGION ──────────

  Future<List<SubDistrict>> listByZip(String zip, {CancelToken? cancelToken}) =>
      client.getEnvelope<List<SubDistrict>>('/zip/$zip',
          decode: (raw) => _list(raw, SubDistrict.fromJson),
          cancelToken: cancelToken);

  Future<List<Province>> listByRegion(String region,
          {CancelToken? cancelToken}) =>
      client.getEnvelope<List<Province>>('/regions/$region',
          decode: (raw) => _list(raw, Province.fromJson),
          cancelToken: cancelToken);

  // ────────── REVERSE GEOCODE ──────────

  Future<ReverseResult> reverse(double lat, double lng,
          {CancelToken? cancelToken}) =>
      client.getEnvelope<ReverseResult>(
        '/reverse',
        query: {'lat': lat, 'lng': lng},
        decode: (raw) => ReverseResult.fromJson(_asMap(raw, 'ReverseResult')),
        cancelToken: cancelToken,
      );

  /// Batch reverse — ใช้ระวัง rate limit 10/min, ≤ 1000 จุด/request.
  Future<List<ReverseResult>> reverseBatch(
          List<({double lat, double lng})> points,
          {CancelToken? cancelToken}) =>
      client.postEnvelope<List<ReverseResult>>(
        '/reverse/batch',
        body: points.map((p) => {'lat': p.lat, 'lng': p.lng}).toList(),
        decode: (raw) => _list(raw, ReverseResult.fromJson),
        cancelToken: cancelToken,
      );

  // ────────── SEARCH / AUTOCOMPLETE ──────────

  /// trigram fuzzy. ต้องมี [q] อย่างน้อย 2 ตัวอักษร.
  Future<List<AddressHit>> search(String q,
          {String? level,
          String lang = 'th',
          int limit = 20,
          CancelToken? cancelToken}) =>
      client.getEnvelope<List<AddressHit>>(
        '/search',
        query: {
          'q': q,
          if (level != null) 'level': level,
          'lang': lang,
          'limit': limit
        },
        decode: (raw) => _list(raw, AddressHit.fromJson),
        cancelToken: cancelToken,
      );

  /// **Prefix typeahead** — เร็ว, server cache 5 นาที.
  /// แนะนำ debounce 200-300ms ที่ฝั่ง UI (ดู `ThaiAddressSearchField`).
  Future<List<AddressHit>> autocomplete(String q,
          {String? level,
          String lang = 'th',
          int limit = 8,
          CancelToken? cancelToken}) =>
      client.getEnvelope<List<AddressHit>>(
        '/autocomplete',
        query: {
          'q': q,
          if (level != null) 'level': level,
          'lang': lang,
          'limit': limit
        },
        decode: (raw) => _list(raw, AddressHit.fromJson),
        cancelToken: cancelToken,
      );

  // ────────── SPATIAL ──────────

  Future<List<Map<String, dynamic>>> within({
    required double lat,
    required double lng,
    required double radiusKm,
    String level = 'sub_district',
    int limit = 100,
    CancelToken? cancelToken,
  }) =>
      client.getEnvelope<List<Map<String, dynamic>>>(
        '/within',
        query: {
          'lat': lat,
          'lng': lng,
          'radius_km': radiusKm,
          'level': level,
          'limit': limit
        },
        decode: (raw) => raw is List
            ? raw.cast<Map>().map((e) => e.cast<String, dynamic>()).toList()
            : <Map<String, dynamic>>[],
        cancelToken: cancelToken,
      );

  Future<List<Map<String, dynamic>>> bbox({
    required double minLng,
    required double minLat,
    required double maxLng,
    required double maxLat,
    String level = 'sub_district',
    int limit = 200,
    CancelToken? cancelToken,
  }) =>
      client.getEnvelope<List<Map<String, dynamic>>>(
        '/bbox',
        query: {
          'minLng': minLng,
          'minLat': minLat,
          'maxLng': maxLng,
          'maxLat': maxLat,
          'level': level,
          'limit': limit
        },
        decode: (raw) => raw is List
            ? raw.cast<Map>().map((e) => e.cast<String, dynamic>()).toList()
            : <Map<String, dynamic>>[],
        cancelToken: cancelToken,
      );

  // ────────── GEOJSON / MAP DATA ──────────

  /// ขอบเขตของ "หน่วยใดหน่วยหนึ่ง" คืน raw GeoJSON `Feature`.
  Future<GeoJsonFeature> geometryOf(GeoLevel level, String pcode,
          {bool simplified = true, CancelToken? cancelToken}) =>
      client.getRaw<GeoJsonFeature>('/${level.toPathSegment()}/$pcode/geojson',
          query: {'simplified': simplified}, cancelToken: cancelToken);

  /// FeatureCollection ทั้งระดับ (เช่น 77 จังหวัด).
  Future<GeoJsonFeatureCollection> featureCollection(GeoLevel level,
          {CancelToken? cancelToken}) =>
      client.getRaw<GeoJsonFeatureCollection>('/geojson/${level.toApi()}',
          cancelToken: cancelToken);

  Future<GeoJsonFeature> country(
          {bool simplified = true, CancelToken? cancelToken}) =>
      client.getRaw<GeoJsonFeature>('/country',
          query: {'simplified': simplified}, cancelToken: cancelToken);

  Future<GeoJsonFeatureCollection> find(String q,
          {bool simplified = true, int limit = 10, CancelToken? cancelToken}) =>
      client.getRaw<GeoJsonFeatureCollection>('/find',
          query: {'q': q, 'simplified': simplified, 'limit': limit},
          cancelToken: cancelToken);

  /// URL template สำหรับ MapLibre/Mapbox.
  String tilesUrlTemplate(GeoLevel level) =>
      '${client.config.baseUrl.replaceAll(RegExp(r'/+$'), '')}/tiles/${level.toApi()}/{z}/{x}/{y}.mvt';

  // ────────── COMPOSITE HELPER ──────────

  /// **ฟีเจอร์เด่น**: ดึง "ขอบเขตตำบล + หมู่บ้านทุกหลัง" ใน 2 round-trips
  /// (ขอแบบ parallel, gzip + cache เปิดให้อัตโนมัติ).
  ///
  /// ตัวอย่าง:
  /// ```dart
  /// final detail = await geo.subDistrictWithVillages('TH100101');
  /// detail.boundary;  // GeoJSON Feature
  /// detail.villages;  // List<Village> พร้อม lat/lng
  /// ```
  Future<SubDistrictDetail> subDistrictWithVillages(String pcode,
      {bool simplified = true, CancelToken? cancelToken}) async {
    // ใช้ shared token เพื่อให้ทั้ง 3 requests cancel พร้อมกันถ้าตัวใดตัวหนึ่งล้มเหลว
    final sharedToken = CancelToken();
    if (cancelToken != null) {
      unawaited(cancelToken.whenCancel
          .then((_) => sharedToken.cancel(), onError: (_) {}));
    }
    try {
      final results = await Future.wait([
        getSubDistrict(pcode, cancelToken: sharedToken),
        geometryOf(GeoLevel.subDistrict, pcode,
            simplified: simplified, cancelToken: sharedToken),
        listVillagesOfSubDistrict(pcode, cancelToken: sharedToken),
      ], eagerError: true);
      return SubDistrictDetail(
          subDistrict: results[0] as SubDistrict,
          boundary: results[1] as GeoJsonFeature,
          villages: results[2] as List<Village>);
    } catch (_) {
      sharedToken.cancel('subDistrictWithVillages partial failure');
      rethrow;
    }
  }

  // ────────── DECODER HELPERS ──────────

  /// Safely extracts a [Map<String, dynamic>] from [raw].
  ///
  /// Handles:
  /// - `Map<String, dynamic>` — returned as-is
  /// - `Map` (untyped) — cast to typed
  /// - `List` with a single Map element — unwraps first item
  ///   (server returned array for a single-object endpoint)
  ///
  /// Throws [GeoApiException] with a clear message for any other shape.
  static Map<String, dynamic> _asMap(Object? raw, String entityName) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return (raw.first as Map).cast<String, dynamic>();
    }
    throw GeoApiException(
      code: GeoErrorCode.parse,
      message:
          'Expected JSON object for $entityName but got ${raw?.runtimeType ?? "null"}',
    );
  }

  static List<E> _list<E>(Object? raw, E Function(Map<String, dynamic>) item) {
    if (raw is! List) return <E>[];
    return raw.cast<Map>().map((m) => item(m.cast<String, dynamic>())).toList();
  }
}

class SubDistrictDetail {
  const SubDistrictDetail(
      {required this.subDistrict,
      required this.boundary,
      required this.villages});
  final SubDistrict subDistrict;
  final GeoJsonFeature boundary;
  final List<Village> villages;
}
