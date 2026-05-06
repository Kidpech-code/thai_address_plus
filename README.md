# thai_address_plus

[![pub.dev](https://img.shields.io/pub/v/thai_address_plus.svg)](https://pub.dev/packages/thai_address_plus)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Flutter SDK สำหรับ **Thailand Geographic API** — จังหวัด / อำเภอ / ตำบล / หมู่บ้าน / GeoJSON / Reverse-geocode / Autocomplete

---

## Features

| หมวด         | รายละเอียด                                                       |
| ------------ | ---------------------------------------------------------------- |
| Admin lookup | Provinces, Districts, Sub-districts, Villages                    |
| Search       | Fuzzy full-text search + prefix autocomplete                     |
| Spatial      | Reverse geocode, batch reverse, within-radius, bounding box      |
| GeoJSON      | ขอบเขตรายหน่วย, FeatureCollection, country boundary              |
| Vector tiles | URL template สำหรับ MapLibre / Mapbox                            |
| Network      | Gzip อัตโนมัติ, retry (429 + Retry-After / 5xx), in-memory cache |
| Widget       | `ThaiAddressSearchField` — debounced typeahead พร้อมใช้          |

---

## Installation

```yaml
dependencies:
  thai_address_plus: ^0.1.0
```

```bash
flutter pub get
```

---

## Quick Start

```dart
import 'package:thai_address_plus/thai_address_plus.dart';

final geo = ThaiGeoApi();

// ดึง 77 จังหวัด (cache 24h อัตโนมัติ)
final provinces = await geo.listProvinces();

// ดึงตำบล + หมู่บ้าน + GeoJSON ใน 1 คำสั่ง
final detail = await geo.subDistrictWithVillages('TH100101');
print(detail.subDistrict.nameTh);   // ตำบลพระบรมมหาราชวัง
print(detail.villages.length);      // จำนวนหมู่บ้าน
```

---

## Usage

### Provinces

```dart
// ทุกจังหวัด
final all = await geo.listProvinces();

// กรองตามภาค
final north = await geo.listProvinces(region: 'north');

// จังหวัดที่มีทะเล
final coastal = await geo.listProvinces(isCoastal: true);

// ดึงจังหวัดเดียว
final bkk = await geo.getProvince('TH10');

// จังหวัดเพื่อนบ้าน (depth 1 = ติดกัน, depth 2 = ห่าง 2 ชั้น)
final neighbors = await geo.listProvinceNeighbors('TH10', depth: 1);

// อำเภอในจังหวัด
final districts = await geo.listDistrictsOfProvince('TH10');
```

### Districts & Sub-districts

```dart
// ข้อมูลอำเภอ
final district = await geo.getDistrict('TH1001');

// ตำบลในอำเภอ
final subDistricts = await geo.listSubDistrictsOfDistrict('TH1001');

// ตำบลเดียว
final tambon = await geo.getSubDistrict('TH100101');

// ตำบลแบบกรองหลายเงื่อนไข
final islands = await geo.listSubDistricts(isIsland: true, limit: 20);

// ตำบลตามรหัสไปรษณีย์
final byZip = await geo.listByZip('10200');
```

### Villages

```dart
// หมู่บ้านในตำบล (ใช้กับ dropdown 4 ระดับ)
final villages = await geo.listVillagesOfSubDistrict('TH100101');

// หมู่บ้านเดียว
final village = await geo.getVillage(12345);
```

### Reverse Geocode

```dart
// จุดเดียว
final result = await geo.reverse(13.7563, 100.5018);
print(result.subDistrictNameTh);

// Batch (≤ 1 000 จุด/request, rate limit 10/min)
final results = await geo.reverseBatch([
  (lat: 13.7563, lng: 100.5018),
  (lat: 18.7883, lng: 98.9853),
]);
```

### Search & Autocomplete

```dart
// Fuzzy full-text search (ต้องการ ≥ 2 ตัวอักษร)
final hits = await geo.search('สีลม', level: 'sub_district');

// Prefix autocomplete (เร็วกว่า, แนะนำ debounce 200-300ms)
final suggestions = await geo.autocomplete('สีล', limit: 8);
for (final h in suggestions) {
  print('${h.pcode}  ${h.displayTh}');
}
```

### Spatial Queries

```dart
// หน่วยการปกครองในรัศมี 5 กม.
final nearby = await geo.within(
  lat: 13.7563, lng: 100.5018,
  radiusKm: 5.0,
  level: 'sub_district',
);

// Bounding box
final inBox = await geo.bbox(
  minLng: 100.4, minLat: 13.6,
  maxLng: 100.6, maxLat: 13.9,
  level: 'district',
);
```

### GeoJSON & Map Tiles

```dart
// ขอบเขต GeoJSON ของตำบล
final feature = await geo.geometryOf(GeoLevel.subDistrict, 'TH100101');

// FeatureCollection ทุกจังหวัด
final fc = await geo.featureCollection(GeoLevel.province);

// ขอบเขตประเทศไทย
final country = await geo.country(simplified: true);

// Vector tile URL สำหรับ MapLibre
final tileUrl = geo.tilesUrlTemplate(GeoLevel.subDistrict);
// → "https://api.kidpech.app/api/v1/geo/tiles/sub_districts/{z}/{x}/{y}.mvt"
```

---

## ThaiAddressSearchField Widget

Widget สำเร็จรูปพร้อม debounce + cancel token — วางได้ทันทีในฟอร์ม:

```dart
ThaiAddressSearchField(
  api: ThaiGeoApi(),
  level: 'sub_district',  // 'province' | 'district' | 'sub_district' | null (all)
  lang: 'th',
  limit: 8,
  minLength: 2,
  debounce: Duration(milliseconds: 250),
  decoration: InputDecoration(
    labelText: 'ค้นหาตำบล / อำเภอ / จังหวัด',
    prefixIcon: Icon(Icons.search),
  ),
  onSelected: (hit) {
    debugPrint('${hit.pcode}  ${hit.displayTh}');
  },
  onError: (e) => debugPrint('Error: $e'),
)
```

---

## Custom Configuration

```dart
final geo = ThaiGeoApi(
  config: ThaiGeoConfig(
    baseUrl: 'https://api.kidpech.app/api/v1/geo',
    connectTimeout: Duration(seconds: 10),
    maxRetries: 5,
    enableLogging: true,              // print request/response
    defaultStaleTime: Duration(hours: 12),
    autocompleteStaleTime: Duration(minutes: 3),
  ),
);
```

### Custom Cache Store

```dart
class MyHiveCache implements CacheStore {
  // implement get / set / remove / clear
}

final geo = ThaiGeoApi(cacheStore: MyHiveCache());
```

### Inject Mock Dio (for testing)

```dart
final mockDio = MockDio();
final client = ThaiGeoClient(dio: mockDio);
final geo = ThaiGeoApi(client: client);
```

---

## Error Handling

```dart
try {
  final provinces = await geo.listProvinces();
} on GeoApiException catch (e) {
  switch (e.code) {
    case GeoErrorCode.network:
      print('No internet: ${e.message}');
    case GeoErrorCode.rateLimited:
      print('Rate limited, retry after: ${e.retryAfter}');
    case GeoErrorCode.notFound:
      print('Not found: ${e.requestPath}');
    default:
      print('Error ${e.statusCode}: ${e.message}');
  }
}
```

---

## API Reference

Full API documentation: [pub.dev/packages/thai_address_plus](https://pub.dev/packages/thai_address_plus)

Thailand Geographic API docs: [api.kidpech.app](https://api.kidpech.app)

---

## License

MIT © 2026 [kidpech.app](https://kidpech.app)
