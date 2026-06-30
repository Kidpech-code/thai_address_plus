# CONTEXT.md — thai_address_plus

Flutter SDK wrapping `api.kidpech.app` — typed access to Thailand's administrative hierarchy (77 provinces, 928 districts, 7,425 sub-districts, villages), reverse geocoding, fuzzy search, autocomplete, spatial queries, and GeoJSON boundaries.

Version: **1.0.3** · Pub: `thai_address_plus` · API: `https://api.kidpech.app/api/v1/geo`

## Why this package exists

The raw API requires gzip headers, wraps every response in an envelope, enforces rate limits, and serves large GeoJSON blobs. This package hides all of it. App code calls `await geo.getProvince('10')` and gets a typed `Province`.

## Runtime deps

`dio ^5.9.2` (HTTP + interceptors), `meta ^1.16.0` (`@immutable`). That's it.

## Repo layout

```
lib/        Dart source (see ARCHITECTURE.md for layer breakdown)
test/       Unit tests — fake HTTP adapter, no network
example/    Minimal demo app (autocomplete + village list)
docs/       Swagger spec, Postman collection, backend notes
```

## API contract

- Full spec: `docs/geo/swagger.yaml`
- Postman: `docs/geo-api.postman_collection.json`
- Backend notes: `docs/TH_GEO_API.md`
