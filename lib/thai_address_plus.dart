/// **thai_address_plus** — Production-ready Flutter SDK สำหรับ
/// Thailand Geographic API (provinces / districts / sub-districts /
/// villages / GeoJSON / reverse-geocode / autocomplete).
///
/// Quick start:
/// ```dart
/// import 'package:thai_address_plus/thai_address_plus.dart';
///
/// final geo = ThaiGeoApi();
/// final provinces = await geo.listProvinces();           // cached 24h
/// final detail    = await geo.subDistrictWithVillages('TH100101');
/// ```
library;

export 'src/config/thai_geo_config.dart';
export 'src/core/api_envelope.dart';
export 'src/core/api_exception.dart';

export 'src/models/autocomplete_hit.dart';
export 'src/models/district.dart';
export 'src/models/geojson.dart';
export 'src/models/province.dart';
export 'src/models/reverse_result.dart';
export 'src/models/sub_district.dart';
export 'src/models/village.dart';

export 'src/network/cache/cache_store.dart';
export 'src/network/cache/memory_cache_store.dart';
export 'src/network/thai_geo_client.dart';

export 'src/api/thai_geo_api.dart';
export 'src/widgets/thai_address_search_field.dart';
