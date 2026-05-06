import 'package:meta/meta.dart';

@immutable
class SubDistrict {
  const SubDistrict({
    required this.pcode,
    required this.districtPcode,
    required this.provincePcode,
    required this.nameTh,
    required this.nameEn,
    required this.zipCode,
    required this.areaSqkm,
    required this.centroidLng,
    required this.centroidLat,
    required this.bboxMinLng,
    required this.bboxMinLat,
    required this.bboxMaxLng,
    required this.bboxMaxLat,
    required this.distanceToBangkokKm,
    required this.isCoastal,
    required this.isIsland,
  });

  final String pcode;
  final String districtPcode;
  final String provincePcode;
  final String nameTh;
  final String nameEn;
  final String zipCode;
  final double areaSqkm;
  final double centroidLng;
  final double centroidLat;
  final double bboxMinLng;
  final double bboxMinLat;
  final double bboxMaxLng;
  final double bboxMaxLat;
  final double distanceToBangkokKm;
  final bool isCoastal;
  final bool isIsland;

  factory SubDistrict.fromJson(Map<String, dynamic> j) => SubDistrict(
    pcode: (j['pcode'] ?? '').toString(),
    districtPcode: (j['district_pcode'] ?? '').toString(),
    provincePcode: (j['province_pcode'] ?? '').toString(),
    nameTh: (j['name_th'] ?? '').toString(),
    nameEn: (j['name_en'] ?? '').toString(),
    zipCode: (j['zip_code'] ?? '').toString(),
    areaSqkm: (j['area_sqkm'] as num?)?.toDouble() ?? 0,
    centroidLng: (j['centroid_lng'] as num?)?.toDouble() ?? 0,
    centroidLat: (j['centroid_lat'] as num?)?.toDouble() ?? 0,
    bboxMinLng: (j['bbox_min_lng'] as num?)?.toDouble() ?? 0,
    bboxMinLat: (j['bbox_min_lat'] as num?)?.toDouble() ?? 0,
    bboxMaxLng: (j['bbox_max_lng'] as num?)?.toDouble() ?? 0,
    bboxMaxLat: (j['bbox_max_lat'] as num?)?.toDouble() ?? 0,
    distanceToBangkokKm: (j['distance_to_bangkok_km'] as num?)?.toDouble() ?? 0,
    isCoastal: j['is_coastal'] == true,
    isIsland: j['is_island'] == true,
  );
}
