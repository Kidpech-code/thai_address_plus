## 0.1.3

* Fix: `ApiEnvelope` now correctly handles `"success": true` (boolean) response
  format in addition to `"status": "success"` string format.

## 0.1.2

- Fix: `ApiEnvelope.isSuccess` now accepts `status: "ok"` in addition to `"success"`,
  resolving `[UNKNOWN] ok` errors on all API calls.

## 0.1.1

- Tighten dependency lower bounds (`dio ^5.9.2`, `meta ^1.16.0`) to pass pub.dev downgrade analysis.

## 0.1.0

### Features

- `ThaiGeoApi` – high-level facade covering all Thailand Geographic API endpoints:
  - Provinces – list (with region/coastal filter), get, neighbors
  - Districts – get, list sub-districts
  - Sub-districts – get, list (with province/district/coastal/island filters), list by ZIP
  - Villages – list of sub-district, get by ID
  - Reverse geocode – single point & batch (≤ 1 000 points)
  - Search – trigram fuzzy full-text search
  - Autocomplete – fast prefix typeahead
  - Spatial – `within` radius, `bbox` bounding-box
  - GeoJSON – geometry of any admin unit, FeatureCollection, country boundary, `/find`
  - Vector tiles – URL template for MapLibre / Mapbox
  - Composite helper – `subDistrictWithVillages` (parallel 3-request fetch)
- `ThaiAddressSearchField` – debounced Flutter widget backed by `/autocomplete`
- `ThaiGeoConfig` – fully configurable: base URL, timeouts, retry, cache TTLs, logging
- `MemoryCacheStore` – in-memory LRU-style response cache with stale-while-error
- Automatic gzip (`Accept-Encoding: gzip`) on every request
- Exponential-backoff retry on HTTP 429 + `Retry-After` header and 5xx errors
