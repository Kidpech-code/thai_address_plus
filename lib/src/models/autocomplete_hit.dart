import 'package:meta/meta.dart';

/// ผลลัพธ์ของ /search หรือ /autocomplete (1 hit).
@immutable
class AddressHit {
  const AddressHit({required this.pcode, required this.nameTh, required this.nameEn, required this.level, this.parentTh, this.zipCode, this.score});

  final String pcode;
  final String nameTh;
  final String nameEn;

  /// `province` | `district` | `sub_district`
  final String level;
  final String? parentTh;
  final String? zipCode;
  final double? score;

  factory AddressHit.fromJson(Map<String, dynamic> j) => AddressHit(
    pcode: (j['pcode'] ?? '').toString(),
    nameTh: (j['name_th'] ?? '').toString(),
    nameEn: (j['name_en'] ?? '').toString(),
    level: (j['level'] ?? '').toString(),
    parentTh: j['parent_th']?.toString(),
    zipCode: j['zip_code']?.toString(),
    score: (j['score'] as num?)?.toDouble(),
  );

  /// ข้อความรวมสำหรับแสดงใน list (ภาษาไทย).
  String get displayTh => parentTh == null || parentTh!.isEmpty ? nameTh : '$nameTh, $parentTh';
}
