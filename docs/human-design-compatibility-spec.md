# MaiTribe Human Design Compatibility - Technical Specification

Last updated: 2026-02-21
Status: Architecture spec (Phase 2 foundation)

## 1) Goal
Compute Human Design compatibility between two users from birth data and return:
- HD chart for each person
- Dimension scores (0-100)
- Total HD compatibility score
- Interpretation text

Dimensions:
1. Type Compatibility
2. Profile Match
3. Authority Harmony
4. Defined/Undefined Centers Complementarity
5. Incarnation Cross Resonance

## 2) API Endpoint Design

## Recommended
- `POST /v1/compatibility/hd`
- `POST /functions/v1/hd-compatibility` (Supabase proxy)

## Request schema
```json
{
  "personA": {
    "birth_date": "1991-03-14",
    "birth_time": "08:20",
    "birth_place": { "lat": 48.137, "lng": 11.575, "timezone": "Europe/Berlin" }
  },
  "personB": {
    "birth_date": "1993-08-30",
    "birth_time": "22:05",
    "birth_place": { "lat": 40.7128, "lng": -74.006, "timezone": "America/New_York" }
  },
  "language": "en"
}
```

## Response schema
```json
{
  "ok": true,
  "overall_score": 81,
  "dimensions": {
    "type_compatibility": { "score": 84, "weight": 0.25 },
    "profile_match": { "score": 76, "weight": 0.20 },
    "authority_harmony": { "score": 79, "weight": 0.20 },
    "centers_complementarity": { "score": 88, "weight": 0.20 },
    "incarnation_cross_resonance": { "score": 73, "weight": 0.15 }
  },
  "charts": {
    "personA": { "type": "Generator", "authority": "Emotional", "profile": "4/6" },
    "personB": { "type": "Projector", "authority": "Splenic", "profile": "2/4" }
  },
  "interpretation": {
    "summary": "Strong complementarity with healthy energetic polarity.",
    "strengths": ["center complementarity", "role balance"],
    "growth_edges": ["decision pacing mismatch"]
  },
  "meta": {
    "engine_version": "1.0.0",
    "fallback_used": false
  }
}
```

## 3) HD Chart Calculation Algorithm

## 3.1 Personality vs Design
Human Design needs two snapshots:
- Personality calculation at birth datetime
- Design calculation when Sun is approx. 88 degrees before natal Sun

Procedure:
1. Compute natal Sun longitude at birth via Swiss Ephemeris.
2. Solve for datetime where transiting Sun longitude = natal Sun - 88 deg (mod 360).
3. Compute planetary longitudes at both datetimes.
4. Convert longitudes to Gate + Line for each body.

Gate/Line derivation:
- 360 / 64 gates = 5.625 deg per gate.
- Gate index = `floor(longitude / 5.625) + 1`.
- Each gate split into 6 lines.
- Line index from fractional segment inside the gate.

## 3.2 Planet set
Minimum set:
- Sun, Earth, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune, Pluto

Store both personality and design activations.

## 4) Gate -> Center Mapping (64 gates -> 9 centers)

- Head: 64, 61, 63
- Ajna: 47, 24, 4, 17, 11, 43
- Throat: 62, 23, 56, 35, 12, 45, 33, 8, 31, 20, 16
- G/Identity: 1, 13, 10, 25, 46, 15, 2, 7
- Heart/Ego: 21, 51, 26, 40
- Spleen: 48, 57, 44, 50, 32, 28, 18
- Solar Plexus: 36, 22, 37, 6, 49, 55, 30
- Sacral: 5, 14, 29, 59, 9, 3, 42, 34, 27
- Root: 53, 60, 52, 54, 38, 58, 41, 19, 39

Center definition:
- A center is defined when at least one full channel connecting that center is activated.
- Single hanging gate is not enough for definition.

## 5) Type Determination Logic
Based on defined centers and motor-to-throat connectivity:

1. Reflector
- No defined centers

2. Manifestor
- Not Sacral-defined
- Has motor (Heart, Solar Plexus, Root, or Sacral) connected to Throat

3. Generator
- Sacral defined
- No motor-to-throat direct manifesting path

4. Manifesting Generator
- Sacral defined
- Has motor-to-throat path

5. Projector
- Not Sacral-defined
- No motor-to-throat path
- At least one defined center

## 6) Authority Determination (priority order)
1. Emotional (Solar Plexus defined)
2. Sacral (Sacral defined, not Emotional)
3. Splenic
4. Ego/Heart
5. Self-Projected (G center)
6. Mental/Environmental (no inner authority)
7. Lunar (Reflector)

## 7) Compatibility Scoring

Weights:
- Type Compatibility: 25%
- Profile Match: 20%
- Authority Harmony: 20%
- Center Complementarity: 20%
- Incarnation Cross Resonance: 15%

## 7.1 Type Compatibility (25)
Matrix examples:
- Generator + Projector: 85
- Generator + Generator: 78
- MG + Projector: 83
- Manifestor + Projector: 76
- Reflector with any type: contextual baseline 70

Adjustments:
- +5 if one partner has naturally guiding role and other has sustainable life-force role
- -8 if both profiles indicate high initiation friction without receptive pattern

## 7.2 Profile Match (20)
Inputs:
- Profile lines (e.g., 4/6, 2/4)

Scoring:
- Shared line synergy (same line appears): +8
- Complementary social mechanics (e.g., 2/4 + 4/6): +10
- Strong friction patterns (e.g., highly incompatible role expectations): -8

## 7.3 Authority Harmony (20)
Scoring examples:
- Emotional + Emotional: 78 (needs pacing agreement)
- Emotional + Splenic: 74 (depth + instinct)
- Sacral + Projector authority (Splenic/Ego): 82
- Ego + Emotional without communication maturity: 65

## 7.4 Defined/Undefined Centers Complementarity (20)
Method:
- Build center vectors `A[9]` and `B[9]` (defined=true/false)
- Count:
  - Shared defined centers (stability)
  - Complementary definitions (magnetic learning)
  - Potential amplification risk centers (both undefined in volatile domains)

Formula:
- `score = 50 + (shared_defined * 4) + (complementary_pairs * 3) - (risk_pairs * 3)`
- Clamp 0..100

## 7.5 Incarnation Cross Resonance (15)
Inputs:
- Personality Sun/Earth gates and Design Sun/Earth gates

Scoring:
- Shared thematic axis: +12
- Complementary thematic direction: +8
- Orthogonal/competing mission vectors: -6

## 8) Integration with Astro Engine
Recommended API structure:
- `POST /v1/compatibility/astro`
- `POST /v1/compatibility/hd`
- `POST /v1/compatibility/combined`

Combined endpoint returns:
- `astro_score`
- `hd_score`
- `composite_score` (weighted blend, e.g. 55% astro, 45% HD)

## 9) Database Schema Extensions

Create table: `public.hd_profiles`
- `id uuid pk`
- `user_id uuid fk users unique`
- `birth_date date`
- `birth_time time`
- `birth_lat numeric(10,7)`
- `birth_lng numeric(10,7)`
- `timezone text`
- `type text`
- `authority text`
- `profile text`
- `incarnation_cross text`
- `defined_centers jsonb`
- `active_gates jsonb`
- `active_channels jsonb`
- `personality_activations jsonb`
- `design_activations jsonb`
- `calculated_at timestamptz`

Create table: `public.hd_compatibility_results`
- `id uuid pk`
- `user_a uuid fk users`
- `user_b uuid fk users`
- `overall_score int`
- `dimension_scores jsonb`
- `interpretation jsonb`
- `engine_version text`
- `created_at timestamptz`

## 10) Fallback Rules
If birth time missing:
- Return `422` by default (HD needs accurate time).
- Optional degraded mode (feature flag):
  - Use noon-time estimate
  - mark `fallback_used=true`
  - confidence <= 0.45
  - hide Type/Authority certainty labels

## 11) Performance
- Cache computed HD profile by `sha256(date|time|lat|lng|tz|engine_version)`
- Cache compatibility pairs by sorted user pair + engine version
- Target latency:
  - warm profile + warm pair: < 150ms
  - full fresh compute: < 1200ms

## 12) Security and Data Handling
- Auth required for non-service requests.
- Do not expose raw planetary technical payloads to other users.
- Store only derived compatibility outputs in matching layer.
