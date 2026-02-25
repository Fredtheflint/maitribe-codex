# MaiTribe Connect — Detailed Technical Feature Specification

## 1. Product Summary
MaiTribe Connect is a privacy-first, no-photo-first matching system inspired by “Love is Blind” mechanics, adapted for emotional compatibility and growth orientation.

Core principle:
**Compatibility before aesthetics. Conversation before reveal. Consent before identity disclosure.**

Modes:
- Friends
- Love

## 2. User Journey
1. User opts into Connect and configures preferences.
2. User completes values/interests/deal-breakers profile.
3. Matching engine computes compatibility across six layers.
4. User receives curated match suggestions with compatibility narrative.
5. If both accept, blind chat starts (pseudonyms only).
6. Reveal unlocks only after mutual consent and gating criteria.
7. Post-match feedback improves ranking quality.

## 3. Compatibility Layers (Scored 0-100)
1. Astro Compatibility (synastry layer)
2. Human Design Compatibility
3. Values Alignment
4. Communication Style Match
5. Life Goals Alignment
6. Emotional Readiness Score

Weighted total (initial recommendation):
- Values: 25%
- Communication style: 20%
- Emotional readiness: 20%
- Life goals: 15%
- Astro: 10%
- Human Design: 10%

## 4. Privacy and Trust Architecture
### 4.1 Privacy Guarantees
- No photos before reveal
- No legal names shown in blind mode
- No raw Mai private conversation text exposed for matching output
- User can block/report at any time

### 4.2 Data Minimization
- Store vectorized preference and compatibility features where possible
- Keep sensitive profile data encrypted at rest (application layer optional)
- Separate matching features from public profile render objects

### 4.3 “Zero-Knowledge” Practical Interpretation
True cryptographic zero-knowledge is expensive for MVP. Practical implementation should be:
- Server processes structured vectors, not narrative transcripts
- Internal admins cannot view full compatibility raw payloads by default
- Strict RBAC and audit log on any privileged data access

## 5. Database Schema
```sql
CREATE TABLE IF NOT EXISTS public.connect_profiles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  mode TEXT NOT NULL DEFAULT 'friends_and_love' CHECK (mode IN ('friends','love','friends_and_love')),
  values JSONB NOT NULL DEFAULT '{}',
  interests JSONB NOT NULL DEFAULT '[]',
  deal_breakers JSONB NOT NULL DEFAULT '[]',
  communication_style JSONB NOT NULL DEFAULT '{}',
  life_goals JSONB NOT NULL DEFAULT '{}',
  emotional_readiness JSONB NOT NULL DEFAULT '{}',
  astro_data JSONB,
  hd_data JSONB,
  profile_status TEXT NOT NULL DEFAULT 'active' CHECK (profile_status IN ('active','paused','hidden')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.connect_preferences (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  mode TEXT NOT NULL DEFAULT 'friends_and_love' CHECK (mode IN ('friends','love','friends_and_love')),
  gender_preference JSONB DEFAULT '[]',
  age_range INT4RANGE,
  distance_km INTEGER DEFAULT 100,
  language_preference JSONB DEFAULT '[]',
  deal_breaker_enforcement TEXT DEFAULT 'strict' CHECK (deal_breaker_enforcement IN ('strict','flexible')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.connect_matches (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_a UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  user_b UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  compatibility_score NUMERIC(5,2) NOT NULL,
  compatibility_breakdown JSONB NOT NULL,
  explanation TEXT,
  status TEXT NOT NULL DEFAULT 'proposed' CHECK (status IN ('proposed','accepted_a','accepted_b','matched','rejected','expired','blocked')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_a, user_b)
);

CREATE TABLE IF NOT EXISTS public.connect_chats (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  match_id UUID REFERENCES public.connect_matches(id) ON DELETE CASCADE UNIQUE NOT NULL,
  revealed BOOLEAN DEFAULT false,
  reveal_requested_by UUID REFERENCES auth.users(id),
  reveal_requested_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.connect_chat_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  chat_id UUID REFERENCES public.connect_chats(id) ON DELETE CASCADE NOT NULL,
  sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  moderation_status TEXT DEFAULT 'ok' CHECK (moderation_status IN ('ok','flagged','blocked')),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.connect_reveals (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  match_id UUID REFERENCES public.connect_matches(id) ON DELETE CASCADE UNIQUE NOT NULL,
  requested_by_a BOOLEAN DEFAULT false,
  requested_by_b BOOLEAN DEFAULT false,
  revealed_at TIMESTAMPTZ,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','revealed','declined')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.connect_feedback (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  match_id UUID REFERENCES public.connect_matches(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  rating INTEGER CHECK (rating BETWEEN 1 AND 5),
  tags JSONB DEFAULT '[]',
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(match_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.connect_moderation_reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  match_id UUID REFERENCES public.connect_matches(id) ON DELETE CASCADE,
  reporter_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  reported_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  reason TEXT NOT NULL,
  notes TEXT,
  status TEXT DEFAULT 'open' CHECK (status IN ('open','reviewing','resolved','dismissed')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_connect_matches_status_score ON public.connect_matches(status, compatibility_score DESC);
CREATE INDEX IF NOT EXISTS idx_connect_matches_user_a ON public.connect_matches(user_a, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_connect_matches_user_b ON public.connect_matches(user_b, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_connect_messages_chat_created ON public.connect_chat_messages(chat_id, created_at);
```

## 6. RLS Policies
```sql
ALTER TABLE public.connect_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connect_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connect_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connect_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connect_chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connect_reveals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connect_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connect_moderation_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY connect_profiles_own_rw
ON public.connect_profiles
FOR ALL USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY connect_preferences_own_rw
ON public.connect_preferences
FOR ALL USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY connect_matches_participant_select
ON public.connect_matches
FOR SELECT
USING (auth.uid() = user_a OR auth.uid() = user_b);

CREATE POLICY connect_matches_participant_update
ON public.connect_matches
FOR UPDATE
USING (auth.uid() = user_a OR auth.uid() = user_b);

CREATE POLICY connect_chats_participant_select
ON public.connect_chats
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.connect_matches m
    WHERE m.id = connect_chats.match_id
      AND (m.user_a = auth.uid() OR m.user_b = auth.uid())
  )
);

CREATE POLICY connect_messages_participant_select
ON public.connect_chat_messages
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.connect_chats c
    JOIN public.connect_matches m ON m.id = c.match_id
    WHERE c.id = connect_chat_messages.chat_id
      AND (m.user_a = auth.uid() OR m.user_b = auth.uid())
  )
);

CREATE POLICY connect_messages_participant_insert
ON public.connect_chat_messages
FOR INSERT
WITH CHECK (
  sender_id = auth.uid()
  AND EXISTS (
    SELECT 1
    FROM public.connect_chats c
    JOIN public.connect_matches m ON m.id = c.match_id
    WHERE c.id = connect_chat_messages.chat_id
      AND (m.user_a = auth.uid() OR m.user_b = auth.uid())
  )
);

CREATE POLICY connect_reveals_participant_rw
ON public.connect_reveals
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.connect_matches m
    WHERE m.id = connect_reveals.match_id
      AND (m.user_a = auth.uid() OR m.user_b = auth.uid())
  )
);

CREATE POLICY connect_feedback_own_rw
ON public.connect_feedback
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY connect_reports_reporter_insert_select
ON public.connect_moderation_reports
FOR ALL
USING (auth.uid() = reporter_id)
WITH CHECK (auth.uid() = reporter_id);
```

## 7. API Endpoints
- `POST /connect/activate`
- `GET /connect/status`
- `POST /connect/respond`
- `POST /connect/chat`
- `POST /connect/reveal`
- `POST /connect/feedback`
- `POST /connect/report`

### 7.1 Request/Response Sketch
#### `POST /connect/activate`
Request:
```json
{
  "mode": "friends_and_love",
  "values": {"freedom": 8, "family": 7},
  "interests": ["nature", "books"],
  "dealBreakers": ["smoking"],
  "preferences": {
    "ageRange": [28, 45],
    "distanceKm": 80,
    "genderPreference": ["male"]
  }
}
```
Response:
```json
{"ok": true, "status": "active"}
```

#### `POST /connect/respond`
Request:
```json
{"matchId": "...", "decision": "accept"}
```
Response:
```json
{"ok": true, "matchStatus": "matched"}
```

#### `POST /connect/chat`
Request:
```json
{"matchId": "...", "message": "Nice to meet you in this space."}
```
Response:
```json
{"ok": true, "messageId": "..."}
```

## 8. Matching Algorithm (Pseudo-Code)
```text
for each active user U:
  candidates = users filtered by mode compatibility + hard preferences
  candidates = candidates excluding blocked/rejected/recently_expired

  for each candidate C:
    score_values = cosine(values_vector(U), values_vector(C)) * 100
    score_comm = comm_style_similarity(U, C)
    score_goals = weighted_overlap(U.life_goals, C.life_goals)
    score_readiness = readiness_alignment(U, C)
    score_astro = astro_compat(U.astro_data, C.astro_data) or neutral_default
    score_hd = hd_compat(U.hd_data, C.hd_data) or neutral_default

    hard_fail = deal_breaker_conflict(U, C)
    if hard_fail: continue

    total = 0.25*score_values + 0.20*score_comm + 0.15*score_goals +
            0.20*score_readiness + 0.10*score_astro + 0.10*score_hd

    if total >= threshold:
      create_or_refresh_proposed_match(U, C, breakdown, explanation)

rank proposed matches by total + freshness + diversity factors
```

## 9. Blind Chat UX Concept
## 9.1 Chat Identity Layer
- Pseudonym generated per match (e.g., “North Star”, “Quiet River”)
- No profile photo pre-reveal
- Optional identity hints unlocked gradually (interests, values tags)

## 9.2 Reveal Rules
Default reveal gate:
- At least X exchanged messages (e.g., 20 total)
- Both users explicitly consent
- No active safety flags

## 9.3 UI States
- Proposed match card
- Waiting for other side response
- Blind chat active
- Reveal pending
- Revealed
- Closed/reported

## 10. Moderation Rules
1. Real-time toxicity and harassment checks on outbound messages.
2. Soft block for mild violations + warning.
3. Hard block/report for abuse, coercion, hate, explicit harm.
4. Safety escalation path with account sanctions.
5. Repeat offender controls with shadow cooldown.

## 11. Safety and Abuse Prevention
- Rate limits on first messages
- Duplicate account controls
- Block lists and shared suppression across modes
- Manual moderator queue for severe reports

## 12. Scalability Considerations
### 12.1 100 Users
- Nightly matching job via n8n or edge cron sufficient

### 12.2 1,000 Users
- Move to incremental matching queue
- Candidate prefiltering by vector index and preference constraints

### 12.3 10,000+ Users
- Dedicated matching service
- Approximate nearest-neighbor vector search
- Async scoring and explainability cache

## 13. Rollout Plan
### Phase 1 (MVP)
- Profile creation, matching, accept/reject, blind chat

### Phase 2
- Reveal flow, feedback loop, moderation dashboard

### Phase 3
- Astro/HD deeper scoring and adaptive ranking improvements

## 14. KPIs
- Connect opt-in rate
- Match acceptance rate
- First 10-message completion rate
- Reveal rate
- Report rate per 1,000 messages
- Post-match satisfaction score

## 15. Open Decisions
1. Exact reveal threshold and optional timer.
2. Whether Friends and Love pools are fully isolated.
3. How strongly to weight astro/HD in first versions.
4. Whether compatibility explanation is fully visible or summarized.
