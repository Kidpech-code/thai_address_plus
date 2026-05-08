import 'package:flutter/material.dart';
import 'package:thai_address_plus/thai_address_plus.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'thai_address_plus demo',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ThaiGeoApi geo = ThaiGeoApi(
    config: const ThaiGeoConfig(enableLogging: true),
  );

  AddressHit? selected;
  SubDistrictDetail? detail;
  String status = '';

  Future<void> _loadDetail(String pcode) async {
    setState(() => status = 'Loading boundary + villages...');
    try {
      final d = await geo.subDistrictWithVillages(pcode);
      if (!mounted) return;
      setState(() {
        detail = d;
        status = 'OK • ${d.villages.length} villages • '
            'boundary type=${d.boundary['geometry']?['type'] ?? '?'}';
      });
    } on GeoApiException catch (e) {
      if (!mounted) return;
      setState(() => status = 'Error: ${e.code} — ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thai Address Plus — Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1) Debounced typeahead (autocomplete)
            ThaiAddressSearchField(
              api: geo,
              level: 'sub_district',
              onSelected: (hit) {
                setState(() => selected = hit);
                _loadDetail(hit.pcode);
              },
              onError: (e) => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${e.code}: ${e.message}')),
              ),
            ),
            const SizedBox(height: 16),
            if (selected != null)
              Card(
                child: ListTile(
                  title: Text(selected!.displayTh),
                  subtitle: Text('pcode: ${selected!.pcode} • '
                      'level: ${selected!.level} • '
                      'zip: ${selected!.zipCode ?? '-'}'),
                ),
              ),
            const SizedBox(height: 12),
            Text(status),
            const SizedBox(height: 12),
            Expanded(
              child: detail == null
                  ? const Center(child: Text('เลือกตำบลจากช่องค้นหา'))
                  : ListView.separated(
                      itemCount: detail!.villages.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final v = detail!.villages[i];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            child: Text((v.mooNumber ?? i + 1).toString()),
                          ),
                          title: Text(v.nameTh),
                          subtitle: Text(
                              'main_id ${v.mainId ?? '-'} • ${v.lat.toStringAsFixed(5)}, '
                              '${v.lng.toStringAsFixed(5)}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
