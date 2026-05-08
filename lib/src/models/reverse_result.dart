import 'package:meta/meta.dart';

enum GeoLevel {
  province,
  district,
  subDistrict;

  String toApi() => switch (this) {
        GeoLevel.province => 'province',
        GeoLevel.district => 'district',
        GeoLevel.subDistrict => 'sub_district',
      };

  /// ใช้ใน path segment ที่เป็นพหูพจน์ (เช่น `/provinces/`)
  String toPathSegment() => switch (this) {
        GeoLevel.province => 'provinces',
        GeoLevel.district => 'districts',
        GeoLevel.subDistrict => 'sub-districts',
      };
}

@immutable
class HierarchyNode {
  const HierarchyNode(
      {required this.pcode,
      required this.nameTh,
      required this.nameEn,
      this.region,
      this.zipCode});
  final String pcode;
  final String nameTh;
  final String nameEn;
  final String? region;
  final String? zipCode;

  factory HierarchyNode.fromJson(Map<String, dynamic> j) => HierarchyNode(
        pcode: (j['pcode'] ?? '').toString(),
        nameTh: (j['name_th'] ?? '').toString(),
        nameEn: (j['name_en'] ?? '').toString(),
        region: j['region']?.toString(),
        zipCode: j['zip_code']?.toString(),
      );
}

@immutable
class ReverseMatch {
  const ReverseMatch(
      {required this.pcode,
      required this.nameTh,
      required this.nameEn,
      required this.level});
  final String pcode;
  final String nameTh;
  final String nameEn;
  final String level;

  factory ReverseMatch.fromJson(Map<String, dynamic> j) => ReverseMatch(
        pcode: (j['pcode'] ?? '').toString(),
        nameTh: (j['name_th'] ?? '').toString(),
        nameEn: (j['name_en'] ?? '').toString(),
        level: (j['level'] ?? '').toString(),
      );
}

@immutable
class ReverseResult {
  const ReverseResult({
    required this.lng,
    required this.lat,
    required this.match,
    required this.province,
    required this.district,
    required this.subDistrict,
    required this.addressLineTh,
    required this.addressLineEn,
  });

  final double lng;
  final double lat;
  final ReverseMatch match;
  final HierarchyNode? province;
  final HierarchyNode? district;
  final HierarchyNode? subDistrict;
  final String addressLineTh;
  final String addressLineEn;

  factory ReverseResult.fromJson(Map<String, dynamic> j) {
    final hier = (j['hierarchy'] as Map?)?.cast<String, dynamic>() ?? const {};
    HierarchyNode? read(String k) {
      final v = hier[k];
      return v is Map
          ? HierarchyNode.fromJson(v.cast<String, dynamic>())
          : null;
    }

    return ReverseResult(
      lng: (j['lng'] as num?)?.toDouble() ?? 0,
      lat: (j['lat'] as num?)?.toDouble() ?? 0,
      match: ReverseMatch.fromJson(
          (j['match'] as Map?)?.cast<String, dynamic>() ?? const {}),
      province: read('province'),
      district: read('district'),
      subDistrict: read('sub_district'),
      addressLineTh: (j['address_line_th'] ?? '').toString(),
      addressLineEn: (j['address_line_en'] ?? '').toString(),
    );
  }
}
