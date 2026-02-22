# MaiTribe Astro Compatibility Engine - Technical Specification

Last updated: 2026-02-21
Status: Architecture spec (Phase 2 foundation)

## 1) Goal
Build a compatibility engine that compares two birth profiles and outputs:
- Dimension scores (0-100)
- Weighted total score (0-100)
- Confidence score
- Human-readable interpretation

Supported dimensions:
1. Sun Sign Harmony
2. Moon Sign Resonance
3. Venus-Mars Dynamic
4. Rising Sign Compatibility
5. Saturn Aspects (long-term growth)
6. Current Transit Timing (near-term support)

## 2) Inputs and Outputs

## Input profile schema
```json
{
  "birth_date": "1990-04-18",
  "birth_time": "07:35",
  "birth_place": {
    "lat": 52.5200,
    "lng": 13.4050,
    "timezone": "Europe/Berlin"
  }
}
```

`birth_time` is optional. If missing, fallback logic applies.

## Output schema
```json
{
  "ok": true,
  "overall_score": 78,
  "confidence": 0.86,
  "dimensions": {
    "sun_sign_harmony": { "score": 82, "weight": 0.15, "signals": ["same element"] },
    "moon_sign_resonance": { "score": 74, "weight": 0.20, "signals": ["moon trine moon"] },
    "venus_mars_dynamic": { "score": 69, "weight": 0.20, "signals": ["venus-mars sextile"] },
    "rising_sign_compatibility": { "score": 80, "weight": 0.15, "signals": ["complementary modality"] },
    "saturn_aspects": { "score": 71, "weight": 0.15, "signals": ["saturn trine sun"] },
    "current_transit_timing": { "score": 90, "weight": 0.15, "signals": ["jupiter support window"] }
  },
  "interpretation": {
    "summary": "Warm long-term potential with strong emotional resonance.",
    "strengths": ["emotional safety", "timing support"],
    "growth_edges": ["pace mismatch during stress"],
    "timing_note": "Next 14 days favor clarity and gentle commitment."
  },
  "meta": {
    "engine_version": "1.0.0",
    "ephemeris": "Swiss Ephemeris",
    "fallback_used": false
  }
}
```

## 3) API Endpoint Design

## Option A: Standalone microservice (recommended)
- `POST /v1/compatibility/astro`
- `POST /v1/compatibility/astro/batch`
- `GET /v1/compatibility/astro/:id`

## Option B: Supabase Edge Function facade
- `POST /functions/v1/astro-compatibility`
- Edge function validates auth and forwards to astro microservice.

## Request
```json
{
  "personA": { "birth_date": "...", "birth_time": "...", "birth_place": { "lat": 0, "lng": 0, "timezone": "UTC" } },
  "personB": { "birth_date": "...", "birth_time": "...", "birth_place": { "lat": 0, "lng": 0, "timezone": "UTC" } },
  "language": "en",
  "include_transits": true
}
```

## Response codes
- `200` success
- `400` validation error
- `401/403` auth error
- `422` insufficient data
- `500` compute error

## 4) Algorithm by Dimension

## 4.1 Sun Sign Harmony (weight 15%)
Signals:
- Element compatibility (Fire/Earth/Air/Water)
- Modality compatibility (Cardinal/Fixed/Mutable)

Element base matrix:
- Same element: +18
- Fire-Air or Earth-Water: +14
- Fire-Water or Air-Earth: +6

Modality adjustment:
- Same modality: +6 (or +2 if both Fixed)
- Complementary modality: +4
- Friction pattern: -4

Score formula:
- `score = clamp(50 + element_points + modality_points, 0, 100)`

## 4.2 Moon Sign Resonance (weight 20%)
Signals:
- Moon-Moon aspect
- Moon to partner Sun/Venus aspects
- Elemental emotional style match

Aspects and orbs:
- Conjunction, Trine, Sextile (supportive)
- Square, Opposition (tension)
- Orb: 8 deg for luminaries

Aspect points:
- Conjunction +16, Trine +14, Sextile +10
- Square -10, Opposition -8
- Quincunx -4

Formula:
- Start 50, add strongest Moon-Moon + best 2 supportive cross-aspects, clamp 0..100.

## 4.3 Venus-Mars Dynamic (weight 20%)
Signals:
- Venus(A) to Mars(B)
- Venus(B) to Mars(A)
- Venus-Venus and Mars-Mars secondary texture

Aspects and orb:
- Orb 6 deg

Points:
- Conjunction +18
- Trine +14
- Sextile +10
- Square +4 (chemistry with friction)
- Opposition +7 (polarity)
- No strong aspect: -6

Formula:
- Weighted mean of both cross directions (70%) + same-planet texture (30%).

## 4.4 Rising Sign Compatibility (weight 15%)
Requires known birth times for both.
Signals:
- Ascendant sign element/modality compatibility
- Ascendant ruler compatibility (optional advanced pass)

Points:
- Similar structure + complementary element: +16
- Same modality fixed/fixed stress: -5
- Strong sign friction pairs: -8

If rising unavailable for one/both users:
- Dimension excluded from weighted total.
- Weight redistributed to Sun and Moon dimensions.

## 4.5 Saturn Aspects (weight 15%)
Purpose: long-term durability and growth.
Signals:
- Saturn(A) aspect to Sun/Moon/Venus/Mars/Asc(B)
- Saturn(B) aspect to Sun/Moon/Venus/Mars/Asc(A)

Orb:
- 5 deg for Saturn aspects

Points:
- Trine/Sextile: +10 / +8
- Conjunction: +6 (stabilizing but heavy)
- Square/Opposition: -6 / -8

Scoring nuance:
- Do not over-penalize hard Saturn aspects; include "growth challenge" tag instead.

## 4.6 Current Transit Timing (weight 15%)
Goal: detect whether near-term transits support connection quality.
Window:
- Next 30 days

Signals:
- Jupiter/Venus supportive transits to both natal Moons/Suns
- Saturn heavy transits simultaneous to both charts
- Mercury retrograde-like communication friction window (optional)

Timing score:
- Base 50
- Add supportive window points (+0..30)
- Subtract pressure cluster points (-0..25)

## 5) Total Score
Default weights:
- Sun 0.15
- Moon 0.20
- Venus-Mars 0.20
- Rising 0.15
- Saturn 0.15
- Transit 0.15

Computation:
- `overall = sum(score_i * weight_i) / sum(active_weights)`
- Round to integer 0..100.

Confidence:
- Base 0.9 with full birth-time data
- -0.12 if one birth time missing
- -0.22 if both missing
- -0.08 if timezone uncertain

## 6) Swiss Ephemeris Integration Plan

## Recommended architecture
Use **Node microservice** for ephemeris computation and keep Supabase Edge Function as authenticated gateway.

Why:
- Swiss Ephemeris Node wrappers are mature in Node runtime.
- Deno native support for swisseph is limited compared to Node.
- Easier local file access for ephemeris data (`.se1` files).

## Packages/runtime
- Node 20+
- `swisseph-v2` or maintained Swiss Ephemeris Node binding
- Optional fallback: `astronomia` for coarse backup (lower precision)

## Deployment options
1. Fly.io/Render/Railway microservice (recommended)
2. Supabase Edge Function calls microservice via internal API key
3. Future: WASM port once production-stable and benchmarked

## 7) Data Model Extensions

Create table: `public.astro_profiles`
- `id uuid pk`
- `user_id uuid fk users`
- `birth_date date`
- `birth_time time null`
- `birth_time_known boolean default false`
- `birth_lat numeric(10,7)`
- `birth_lng numeric(10,7)`
- `timezone text`
- `sun_sign text`
- `moon_sign text`
- `venus_sign text`
- `mars_sign text`
- `rising_sign text null`
- `saturn_sign text`
- `natal_longitudes jsonb` (planet -> degree)
- `houses jsonb null`
- `calculated_at timestamptz`

Create table: `public.astro_compatibility_results`
- `id uuid pk`
- `user_a uuid fk users`
- `user_b uuid fk users`
- `overall_score int`
- `confidence numeric(4,3)`
- `dimension_scores jsonb`
- `interpretation jsonb`
- `transit_window_start date`
- `transit_window_end date`
- `engine_version text`
- `created_at timestamptz`
- unique key on sorted pair + engine version + transit window

## 8) Performance and Caching
- Cache natal chart computation by hash:
  - `sha256(date|time|lat|lng|tz|engine_version)`
- Cache transit day snapshots by date and geo bucket.
- Keep ephemeris files in persistent disk volume for warm reads.
- Precompute daily transits in batch job at 02:00 UTC.
- Use read-through Redis cache for hot compatibility pairs.

Latency targets:
- Cold compute: < 1500ms
- Warm cache: < 200ms

## 9) Fallback Logic (Missing Birth Time)
If birth time missing:
- Compute Sun/Moon/Venus/Mars/Saturn by noon-time approximation plus uncertainty tag.
- Disable Rising + Houses + Ascendant-based aspects.
- Reduce confidence and redistribute weights:
  - Rising weight goes to Sun (60%) and Moon (40%).

If only one profile lacks time:
- Use known rising for one side as weak signal only.
- mark `fallback_used=true` and `time_precision="mixed"`.

## 10) Security and Privacy
- API requires authenticated caller or signed service key.
- Never store raw partner personal notes in compatibility table.
- Keep interpretation text generated from scored signals, not from conversation history.
- Add audit columns: `computed_by`, `request_id`.

## 11) Versioning
- Engine version semantic: `astro-compat-v1.x.y`
- Any weight matrix change increments minor version.
- Store version in each result row for reproducibility.
