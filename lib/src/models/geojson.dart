/// Lightweight typedef สำหรับ GeoJSON.
///
/// Package นี้ไม่ parse GeoJSON ลึก (เพราะเสี่ยง schema drift และทำให้
/// payload ใหญ่กว่าจำเป็น) — เปิดเป็น Map เพื่อให้ผู้ใช้ส่งต่อให้
/// `flutter_map`, `mapbox_gl` ฯลฯ ได้ทันที.
typedef GeoJsonFeature = Map<String, dynamic>;
typedef GeoJsonFeatureCollection = Map<String, dynamic>;
typedef GeoJsonGeometry = Map<String, dynamic>;
