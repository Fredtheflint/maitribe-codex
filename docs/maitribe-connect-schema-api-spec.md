# MaiTribe Connect - Database Schema and API Design

Last updated: 2026-02-21
Status: Phase 3/4 architecture spec

## 1) Scope
MaiTribe Connect is an opt-in, privacy-first matching system inspired by "Love is Blind" flow:
- Consent-based profile activation
- Compatibility-based matching (Astro + HD + values + communication + readiness)
- Anonymous blind chat
- Mutual reveal handshake
- Post-match feedback loop

## 2) Existing Data Model Mapping
Briefing mentions `profiles`; current app schema uses `public.users`.

Mapping:
- `profiles` -> `public.users`
- `conversations` in briefing is message-like; current app already has `public.conversations` + `public.messages`

Connect layer references `public.users(id)` as canonical user FK.

## 3) New Tables
Implemented in SQL file:
- `/Users/freddy/Downloads/NEW PROJECTS/MAITRIBE Codex/supabase/connect_schema.sql`

Required tables from briefing:
- `connect_profiles`
- `matches`
- `blind_chats`
- `reveals`
- `match_feedback`

Support table (needed for `/connect/chat`):
- `blind_chat_messages`

## 4) Table Responsibilities

## `connect_profiles`
Stores opt-in state, preferences, and abstracted vectors only.

Key fields:
- `user_id` unique
- `is_active`, `consented_at`, `consent_version`
- preference filters (age, distance, gender, mode)
- abstract vectors (`values_vector`, `communication_vector`, `life_goals_vector`)
- `emotional_readiness_score`

## `matches`
Stores engine-computed candidate pair and score decomposition.

Key fields:
- `user_a`, `user_b`
- status lifecycle (`proposed` -> `accepted_both` -> `blind_chat_active` -> `revealed`/`closed`)
- score dimensions (`astro_score`, `hd_score`, `values_score`, `communication_score`, `readiness_score`, `total_score`)
- `score_breakdown`, `explanation`, `engine_version`

## `blind_chats`
Anonymous room metadata for an accepted match.

Key fields:
- `match_id` unique
- pseudonyms per side
- `reveal_state`

## `blind_chat_messages`
Message stream for blind chat.

Key fields:
- `blind_chat_id`
- `sender_user_id`
- `content_ciphertext` (or server-side encrypted payload)
- `content_preview` (optional low-risk teaser text)

## `reveals`
Mutual reveal requests and responses.

Key fields:
- `match_id`
- `requested_by`, `requested_to`
- `status` (`pending`, `accepted`, `declined`, ...)

## `match_feedback`
Private per-user feedback for ranking improvement.

Key fields:
- one row per `(match_id, user_id)`
- quality/safety/fit scores + reason tags
- optional `vector_delta` to tune future matching

## 5) RLS Policy Design
Goal: user sees only own rows or rows where user is one of the two match participants.

Policy summary:
- `connect_profiles`: own row only + service role full
- `matches`: select/update only if `auth.uid()` is `user_a` or `user_b`; insert via service role
- `blind_chats`: only both participants of linked match
- `blind_chat_messages`: only participants of parent blind chat; insert only if sender is auth user
- `reveals`: only requester/requested participant
- `match_feedback`: own feedback row only

Important:
- Background matching job uses service role key.
- Client never receives internal vectors of other user, only match-safe summaries.

## 6) Privacy Architecture

## 6.1 Data minimization
Never expose or persist partner's raw conversation text in Connect tables.

Allowed in Connect storage:
- Numeric vectors
- Aggregate compatibility scores
- Abstract labels (e.g., "communication style compatible")

Not allowed:
- Raw chat excerpts
- Verbatim quotes from private Mai conversations
- Full psychological narratives

## 6.2 Abstraction boundary
Values extraction pipeline writes only compact vectors to `connect_profiles`.
Matching engine reads vectors and scores only.

## 6.3 Blind chat privacy
- Use pseudonyms (`pseudonym_a`, `pseudonym_b`) until mutual reveal.
- Encrypt `blind_chat_messages.content_ciphertext` at rest.
- Reveal endpoint switches identity exposure only after dual consent.

## 7) API Endpoint Design

## 7.1 `POST /connect/activate`
Opt-in + preferences save.

Request:
```json
{
  "mode": "both",
  "minAge": 27,
  "maxAge": 42,
  "distanceKm": 120,
  "preferredGenders": ["female"],
  "languagePref": ["en", "de"],
  "consentVersion": "v1"
}
```

Response:
```json
{ "ok": true, "status": "active", "profileId": "..." }
```

## 7.2 `GET /connect/status`
Returns current connect state.

Response:
```json
{
  "ok": true,
  "active": true,
  "current": {
    "stage": "match_found",
    "matchId": "...",
    "blindChatId": "...",
    "revealState": "none"
  }
}
```

## 7.3 `POST /connect/respond`
Accept/decline proposed match.

Request:
```json
{ "matchId": "...", "action": "accept" }
```

Response:
```json
{ "ok": true, "status": "accepted_a" }
```

## 7.4 `POST /connect/chat`
Send blind chat message.

Request:
```json
{ "blindChatId": "...", "message": "Hey, I felt your calm energy today." }
```

Response:
```json
{ "ok": true, "messageId": "...", "createdAt": "..." }
```

## 7.5 `POST /connect/reveal`
Request or respond to reveal.

Request examples:
```json
{ "matchId": "...", "action": "request" }
```
```json
{ "revealId": "...", "action": "accept" }
```

Response:
```json
{ "ok": true, "revealState": "mutual" }
```

## 7.6 `POST /connect/feedback`
Submit post-match feedback.

Request:
```json
{
  "matchId": "...",
  "rating": 4,
  "fitScore": 78,
  "safetyScore": 90,
  "communicationScore": 70,
  "reasons": ["shared_values", "timing"],
  "notes": "Felt respectful and aligned."
}
```

Response:
```json
{ "ok": true }
```

## 8) Matching Job Design

## Recommended rollout

Phase 1 (MVP): n8n workflow + Supabase SQL/RPC
- Run every 30-60 minutes
- Select active pool from `connect_profiles`
- Compute pair scores via Astro/HD/Values services
- Insert top proposals into `matches`
- Trigger push notification via `send-push`

Phase 2 (scale): dedicated matching service
- Queue-based scoring
- Precomputed vector index
- Parallel pair evaluation workers

## Candidate filtering pipeline
1. Hard filters (age, distance, language, mode, gender preferences)
2. Blocklist/safety filters
3. Deduplicate recent declines/exhausted pairs
4. Score ranking
5. Fairness pass (avoid repeatedly favoring same subset)

## 9) Scaling Strategy

## At ~100 users
- O(n^2) pairing is acceptable in periodic jobs.
- n8n + SQL filtering sufficient.

## At ~1,000 users
- Need prefilter buckets (region, age bands, language).
- Candidate shortlist per user (top 50) before expensive scoring.
- Cache Astro/HD compatibility per pair hash.

## At ~10,000 users
- Move to dedicated service with queue workers.
- Use vector index (pgvector or external ANN service).
- Incremental scoring and freshness windows.
- Strict rate limits and abuse controls for chat/reveal endpoints.

## 10) Security Controls
- JWT auth required on all `/connect/*` endpoints.
- Service role used only in backend workers.
- Enforce anti-spam throttles for blind chat messages.
- Add moderation hooks (keyword risk scoring + report endpoint).

## 11) Implementation Notes
- Keep Connect as optional module: no impact on core Mai chat data path.
- Store engine versions in all score-bearing tables for reproducibility.
- Add observability: match funnel metrics (proposed -> accepted -> blind chat -> reveal -> feedback).
