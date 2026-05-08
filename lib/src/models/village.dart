import 'package:meta/meta.dart';

/// หมู่บ้าน — ระดับความละเอียดสูงสุดที่ API ให้ (lat/lng พิกัดเดี่ยว).
@immutable
class Village {
  const Village({
    required this.mainId,
    required this.subDistrictPcode,
    required this.nameTh,
    required this.nameEn,
    required this.mooNumber,
    required this.lat,
    required this.lng,
  });

  /// `main_id` ตาม API (เช่น 100101001). `null` ถ้า server ไม่ส่งมา.
  final int? mainId;

  /// pcode ของตำบลที่หมู่บ้านนี้สังกัด.
  final String subDistrictPcode;

  final String nameTh;
  final String nameEn;

  /// "หมู่ที่ X" — ถ้า API คืนเป็น string จะ parse ให้
  final int? mooNumber;

  final double lat;
  final double lng;

  factory Village.fromJson(Map<String, dynamic> j) {
    final moo = j['moo_number'] ?? j['moo'];
    return Village(
      mainId: j['main_id'] is num
          ? (j['main_id'] as num).toInt()
          : int.tryParse(j['main_id']?.toString() ?? ''),
      subDistrictPcode: (j['sub_district_pcode'] ??
              j['subdistrict_pcode'] ??
              j['pcode'] ??
              '')
          .toString(),
      nameTh: (j['name_th'] ?? '').toString(),
      nameEn: (j['name_en'] ?? '').toString(),
      mooNumber: moo is num ? moo.toInt() : int.tryParse(moo?.toString() ?? ''),
      lat: (j['lat'] as num?)?.toDouble() ??
          (j['centroid_lat'] as num?)?.toDouble() ??
          0,
      lng: (j['lng'] as num?)?.toDouble() ??
          (j['centroid_lng'] as num?)?.toDouble() ??
          0,
    );
  }
}
