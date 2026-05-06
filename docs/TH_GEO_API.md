# Thailand Geographic API (`/api/v1/geo/*`)

Free, anonymous, read-only public API serving the Thailand administrative
hierarchy (77 provinces / 928 districts / 7,425 sub-districts) and PostGIS
spatial queries. Built into `my-api` and powered by a **separate** PostGIS
service on Railway.

## Architecture

```
HTTP                     ┌────────── application DB (mydb)
  ▼                      │           ↳ users / queue / orders / …
┌─────────────────────┐  │
│  my-api (Gin)       │──┤
│                     │  │
│  /api/v1/geo/*      │  └────────── geo DB (PostGIS)
│  ↳ gzip + RL 60/min │              ↳ provinces / districts / sub_districts
└─────────────────────┘                ↳ mv_geo_full / *_neighbors
        │
        └── Redis (shared) — hot cache + rate-limit
```

## Layers (DDD-ish)

| Layer                        | File                                                                             |
| ---------------------------- | -------------------------------------------------------------------------------- |
| HTTP                         | [`internal/handler/geo.go`](internal/handler/geo.go)                             |
| Service / validation / cache | [`internal/service/geo_service.go`](internal/service/geo_service.go)             |
| Repository / SQL             | [`internal/repository/geo_repository.go`](internal/repository/geo_repository.go) |
| DTO                          | [`internal/model/geo.go`](internal/model/geo.go)                                 |
| Connection                   | [`internal/database/geo_database.go`](internal/database/geo_database.go)         |
| Migrations                   | [`migrations/geo/`](migrations/geo)                                              |

## Endpoints

```
GET  /api/v1/geo/provinces                      list 77 provinces (filters: region, is_coastal)
GET  /api/v1/geo/provinces/:pcode
GET  /api/v1/geo/provinces/:pcode/districts
GET  /api/v1/geo/provinces/:pcode/neighbors     ?depth=1..3
GET  /api/v1/geo/provinces/:pcode/geojson       ?simplified=true|false

GET  /api/v1/geo/districts/:pcode
GET  /api/v1/geo/districts/:pcode/sub-districts
GET  /api/v1/geo/districts/:pcode/neighbors
GET  /api/v1/geo/districts/:pcode/geojson

GET  /api/v1/geo/sub-districts                  faceted: province, district, is_coastal, is_island, max_distance_bkk_km
GET  /api/v1/geo/sub-districts/:pcode
GET  /api/v1/geo/sub-districts/:pcode/neighbors
GET  /api/v1/geo/sub-districts/:pcode/geojson

GET  /api/v1/geo/zip/:zip                       sub-districts sharing a ZIP
GET  /api/v1/geo/regions/:region                provinces in a region

GET  /api/v1/geo/reverse?lat=&lng=
POST /api/v1/geo/reverse/batch                  body: [{"lng":..,"lat":..}, …] (≤ 1000)

GET  /api/v1/geo/search?q=&level=&lang=&limit=  pg_trgm fuzzy
GET  /api/v1/geo/autocomplete?q=&level=&lang=

GET  /api/v1/geo/within?lat=&lng=&radius_km=&level=&limit=
GET  /api/v1/geo/bbox?minLng=&minLat=&maxLng=&maxLat=&level=&limit=

GET  /api/v1/geo/geojson/:level                 whole-level FeatureCollection (simplified)
GET  /api/v1/geo/tiles/:level/:z/:x/:y          Mapbox Vector Tile

GET  /api/v1/geo/stats
```

All responses set `Cache-Control: public, max-age=…` (1h–1d depending on
endpoint) and are gzipped automatically.

## Setup

1. Provision PostGIS and load the OCHA dataset (out of scope for this repo).
2. Run the bootstrap SQL with the **DB owner**:

   ```bash
   cd migrations/geo
   psql "$GEO_OWNER_DSN" -v ON_ERROR_STOP=1 \
       -f 001_extensions_and_indexes.sql \
       -f 002_neighbors.sql \
       -f 003_readonly_role.sql
   ```

3. Set the read-only password and configure env:

   ```bash
   psql "$GEO_OWNER_DSN" -c "ALTER ROLE geo_readonly WITH LOGIN PASSWORD 'xxx';"
   ```

   ```env
   GEO_DB_HOST=monorail.proxy.rlwy.net
   GEO_DB_PORT=12345
   GEO_DB_USER=geo_readonly
   GEO_DB_PASSWORD=xxx
   GEO_DB_NAME=railway
   GEO_DB_SSLMODE=require
   ```

4. Boot. The API logs `GeoDB connected (PostGIS …)` on success and exposes
   the new routes under `/api/v1/geo/*`. If `GEO_DB_HOST` is empty, the
   feature stays disabled and the rest of the app boots normally.

## Performance budget (P95, warm cache)

| Class                                        | Target                            |
| -------------------------------------------- | --------------------------------- |
| Lookup by PK                                 | < 5 ms                            |
| Reverse geocode (single)                     | < 10 ms                           |
| Autocomplete                                 | < 20 ms                           |
| `/within`, `/bbox`                           | < 50 ms                           |
| FeatureCollection (77 provinces, simplified) | < 200 ms (then served from Redis) |

## Caveats

- The `/v1/geo/reverse/batch` endpoint runs a single LATERAL join per request;
  a 1,000-point batch is ≈ 80–150 ms. The route is rate-limited at 10 req/min/IP.
- `/api/v1/geo/sub-districts/:pcode/geojson?simplified=false` ships full
  geometry (potentially > 1 MB for some sub-districts) — gzip + 24 h
  immutable cache makes this acceptable but consider Cloudflare in front.
- Vector tiles are served at zoom 0–18; intersection uses `geom_simplified`
  so tiles below ≈ z6 may show smoothed boundaries. Acceptable trade-off
  for free tier.
