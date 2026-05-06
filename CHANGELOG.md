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
