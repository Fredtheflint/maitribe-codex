# MaiTribe Values Extraction System - Design Specification

Last updated: 2026-02-21
Status: Phase 3 matching foundation

## 1) Goal
Extract abstract compatibility vectors from a user's historical Mai conversations and check-ins, without storing or sharing raw message content.

Outputs are stored in `connect_profiles` and used by matching engine only.

## 2) Input Data Sources
- `public.messages` (user + assistant content)
- `public.checkins` (Body/Mind/Soul/Energy + optional note)
- optional `public.identities` latest statement

Extraction window:
- Last 90 days by default
- Minimum threshold: 20 user messages OR 5 check-ins

## 3) Output Dimensions

## 3.1 Core Values (0-10 each)
Example taxonomy:
- freedom
- safety
- creativity
- family
- spirituality
- growth
- stability
- contribution
- authenticity

## 3.2 Communication Style (0-10 each)
- directness
- emotional_expression
- analytical_style
- depth_preference
- pace_preference

## 3.3 Love Language Tendencies (0-10 each)
- words_of_affirmation
- quality_time
- acts_of_service
- physical_touch
- gifts

## 3.4 Conflict Style (0-10 each)
- confrontation
- avoidance
- collaboration
- compromise

## 3.5 Life Goals (0-10 each)
- career
- family
- travel
- freedom
- creative_work
- impact

## 3.6 Emotional Readiness
- `emotional_readiness_score` (0-100)
- confidence (0-1)

## 4) JSON Output Schema
```json
{
  "version": "values-v1",
  "core_values": {
    "freedom": 8,
    "safety": 6,
    "creativity": 9,
    "family": 4,
    "spirituality": 7,
    "growth": 9,
    "stability": 5,
    "contribution": 6,
    "authenticity": 9
  },
  "communication_style": {
    "directness": 7,
    "emotional_expression": 8,
    "analytical_style": 5,
    "depth_preference": 9,
    "pace_preference": 4
  },
  "love_languages": {
    "words_of_affirmation": 8,
    "quality_time": 7,
    "acts_of_service": 5,
    "physical_touch": 6,
    "gifts": 2
  },
  "conflict_style": {
    "confrontation": 3,
    "avoidance": 4,
    "collaboration": 9,
    "compromise": 8
  },
  "life_goals": {
    "career": 7,
    "family": 5,
    "travel": 8,
    "freedom": 9,
    "creative_work": 8,
    "impact": 6
  },
  "emotional_readiness": {
    "score": 72,
    "confidence": 0.81,
    "trend_30d": "improving"
  },
  "meta": {
    "input_messages": 143,
    "input_checkins": 21,
    "extracted_at": "2026-02-21T12:00:00Z"
  }
}
```

## 5) Gemini Extraction Prompt Design

## System prompt template
```text
You are a strict data abstraction engine for MaiTribe.

Task:
Convert private wellness conversations into abstract numeric vectors only.

Critical rules:
- Output JSON only.
- Never include quotes, examples, or specific personal facts from conversations.
- Never include names, places, events, employers, or unique identifiers.
- No prose explanations.
- Use only the required keys and integer scores.
- If confidence is low, still output schema and set lower confidence values.
```

## User prompt template
```text
Input summary:
- user language: {{language}}
- recent check-in trend: {{trend_json}}
- conversation sample (internal processing only): {{message_blob}}

Return this schema exactly:
{{output_schema}}

Scoring rules:
- 0 = no evidence
- 5 = mixed/unclear
- 10 = strong repeated evidence

Never include raw message fragments or personal facts.
```

## 6) Job Scheduling Design

## Trigger strategy
- Scheduled run: weekly (e.g., Sunday 03:00 user timezone)
- Incremental trigger: if >= 30 new user messages since last extraction
- Manual trigger: user updates Connect profile preferences

## Runtime options
- n8n scheduled workflow (fastest MVP)
- Supabase Edge Function invoked by pg_cron (later)

## Pseudocode
1. Select active `connect_profiles` users.
2. Pull messages/checkins within extraction window.
3. Build sanitized extraction context.
4. Call Gemini with strict JSON schema prompt.
5. Validate schema + score bounds.
6. Upsert vectors into `connect_profiles`.
7. Log extraction metadata.

## 7) Privacy Guarantee Architecture

## 7.1 Technical controls
- Extraction service has read access to raw messages; matching service does not.
- Persist only vectors and aggregate trend labels.
- Do not persist prompts/responses containing raw message text.
- Ephemeral processing memory only; no debug logs with user content.

## 7.2 Data separation
- Raw conversations remain in `messages` table under strict RLS.
- Connect tables store derived vectors only.
- Match API returns compatibility summary only.

## 7.3 Redaction gate
Before sending text to model:
- Strip emails, URLs, phone numbers.
- Mask named entities if possible.
- Truncate to max token budget and remove oldest data first.

## 8) Vector Similarity Algorithm

## 8.1 Candidate model
Use weighted cosine similarity over concatenated normalized vectors.

Vector groups and weights:
- Core values: 35%
- Communication style: 25%
- Love languages: 15%
- Conflict style: 15%
- Life goals: 10%

Formula:
- `score = 100 * weighted_cosine(vA, vB)`

## 8.2 Readiness gating
Apply multiplicative readiness factor:
- `final_values_score = base_similarity * readiness_factor`
- `readiness_factor = min(readinessA, readinessB) / 100`

## 8.3 Hard constraints
Before similarity scoring, enforce opt-in and preference filters:
- mode compatibility
- age range
- distance
- language compatibility threshold

## 9) Validation and Error Handling
- If LLM output is invalid JSON: retry once with strict "repair" prompt.
- If still invalid: keep previous vectors and mark extraction failure.
- If no prior vector exists: set neutral defaults (5/10) + low confidence.

## 10) Observability
Track metrics:
- extraction_success_rate
- schema_validation_failure_rate
- average_confidence
- vector_shift_magnitude over time
- downstream correlation with match acceptance

## 11) Versioning
- Store `vector_version` in `connect_profiles`.
- Any taxonomy changes require version bump and re-extraction migration.
