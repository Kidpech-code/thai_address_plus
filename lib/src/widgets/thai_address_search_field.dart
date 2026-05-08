import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';

import '../api/thai_geo_api.dart';
import '../core/api_exception.dart';
import '../models/autocomplete_hit.dart';

/// Debounced typeahead field ที่เชื่อมตรงกับ `/autocomplete`.
///
/// รับประกัน:
/// - **Debounce** ก่อนยิงทุกตัวอักษร (default 250ms)
/// - **Cancel** request เก่าทันทีเมื่อมี keystroke ใหม่ (กัน race condition)
/// - **Min length** กันยิงตอนพิมพ์ตัวอักษรเดียว
/// - แสดง suggestion ผ่าน `Autocomplete` ของ Flutter
///
/// ```dart
/// ThaiAddressSearchField(
///   api: ThaiGeoApi(),
///   level: 'sub_district',
///   onSelected: (hit) => debugPrint('${hit.pcode} ${hit.displayTh}'),
/// )
/// ```
class ThaiAddressSearchField extends StatefulWidget {
  const ThaiAddressSearchField({
    super.key,
    required this.api,
    this.level,
    this.lang = 'th',
    this.limit = 8,
    this.minLength = 2,
    this.debounce = const Duration(milliseconds: 250),
    this.decoration,
    this.onSelected,
    this.onError,
  });

  final ThaiGeoApi api;

  /// `province` | `district` | `sub_district` (null = all).
  final String? level;
  final String lang;
  final int limit;
  final int minLength;
  final Duration debounce;
  final InputDecoration? decoration;

  final ValueChanged<AddressHit>? onSelected;
  final ValueChanged<GeoApiException>? onError;

  @override
  State<ThaiAddressSearchField> createState() => _ThaiAddressSearchFieldState();
}

class _ThaiAddressSearchFieldState extends State<ThaiAddressSearchField> {
  /// Monotonically-increasing sequence number.
  /// แต่ละ keystroke เพิ่ม 1 — ใช้ guard ว่า Future นี้ยังเป็น "latest" อยู่ไหม.
  int _seq = 0;

  /// Cancel token ของ in-flight network request.
  CancelToken? _cancelToken;

  @override
  void dispose() {
    ++_seq; // invalidate any pending debounce Future.delayed
    _cancelToken?.cancel('widget disposed');
    super.dispose();
  }

  /// Debounce ด้วย [Future.delayed] + sequence guard:
  ///
  /// - ทุก keystroke ยิง Future.delayed ตัวใหม่ (แต่ละตัวมี seq ของตัวเอง)
  /// - หลัง delay: ตรวจว่าตัวเองยัง "latest" ไหม (seq == _seq)
  ///   - ใช่ → ยิง network request
  ///   - ไม่ใช่ → return [] เงียบ ๆ (keystroke ใหม่กว่าชนะ)
  /// - ก่อน delay: cancel CancelToken ของ request เก่าทันที
  ///
  /// ไม่มี Completer → ไม่มี Future ค้างใน heap ถาวร
  Future<List<AddressHit>> _fetch(String q) async {
    final mySeq = ++_seq;
    _cancelToken?.cancel('superseded');

    if (q.trim().length < widget.minLength) return const [];

    await Future<void>.delayed(widget.debounce);
    if (mySeq != _seq) return const [];

    final ct = CancelToken();
    _cancelToken = ct;
    try {
      final hits = await widget.api.autocomplete(q.trim(),
          level: widget.level,
          lang: widget.lang,
          limit: widget.limit,
          cancelToken: ct);
      // ตรวจซ้ำหลัง await เพื่อกัน race จาก request ที่ใช้เวลานาน
      return mySeq == _seq ? hits : const [];
    } on GeoApiException catch (e) {
      if (e.code != GeoErrorCode.cancelled) widget.onError?.call(e);
      return const [];
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<AddressHit>(
      displayStringForOption: (h) => h.displayTh,
      optionsBuilder: (TextEditingValue v) => _fetch(v.text),
      onSelected: (h) => widget.onSelected?.call(h),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onSubmitted: (_) => onFieldSubmitted(),
          decoration: widget.decoration ??
              const InputDecoration(
                hintText: 'ค้นหาที่อยู่ (จังหวัด/อำเภอ/ตำบล/รหัสไปรษณีย์)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 480),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final h = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(h.displayTh),
                    subtitle: Text(
                        [h.level, if (h.zipCode != null) h.zipCode].join(' • '),
                        style: const TextStyle(fontSize: 11)),
                    onTap: () => onSelected(h),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
