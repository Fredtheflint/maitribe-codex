# MaiTribe Facilitator/Coach Platform Specification

## 1. Product Intent
The Facilitator Platform extends MaiTribe into B2B by enabling coaches, workshop leaders, and retreat facilitators to run guided pre-event and post-event participant support flows.

Core principle:
**Facilitators receive anonymized group-level insights, while individual private conversations remain private.**

## 2. Primary Use Cases
1. Facilitator creates an event and invites participants.
2. Participants complete pre-event intention flow with Mai.
3. Participants optionally receive contextual prompts before event start.
4. Post-event integration prompts help convert insight into action.
5. Facilitator receives anonymized aggregate insights (never private chat transcripts).

## 3. Personas
- **Facilitator:** Runs workshops/retreats/coaching cohorts.
- **Participant:** Joins event and receives guided support.
- **Platform Admin:** Handles safety, billing, and support escalations.

## 4. Feature Scope (MVP)
## 4.1 Facilitator Event Management
- Create/edit events
- Define event type, date/time, description
- Configure pre-event and post-event guidance prompts
- Invite participants via link/email token

## 4.2 Participant Flows
- Join event with consent screen
- Pre-event preparation chat/check-in
- Post-event integration reflection and action commitment

## 4.3 Insights Dashboard
- Mood distribution and trend before/after event
- Frequent themes (aggregated topic clusters)
- Intention completion rates and post-event follow-through rates

## 4.4 Privacy and Controls
- Participant identities masked in insights by default
- Minimum cohort threshold before showing aggregates (e.g., `n >= 5`)
- No raw conversation export for facilitator

## 5. Data Model
## 5.1 Proposed SQL Schema
```sql
CREATE TABLE IF NOT EXISTS public.facilitated_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  facilitator_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  event_date TIMESTAMPTZ NOT NULL,
  event_type TEXT NOT NULL CHECK (event_type IN ('workshop','retreat','coaching','ceremony')),
  timezone TEXT,
  pre_event_prompt TEXT,
  post_event_prompt TEXT,
  max_participants INTEGER DEFAULT 50,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft','active','completed','archived')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.event_participants (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID REFERENCES public.facilitated_events(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role TEXT DEFAULT 'participant' CHECK (role IN ('participant','facilitator','assistant')),
  pre_completed BOOLEAN DEFAULT false,
  post_completed BOOLEAN DEFAULT false,
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(event_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.event_insights (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID REFERENCES public.facilitated_events(id) ON DELETE CASCADE NOT NULL,
  insight_type TEXT NOT NULL CHECK (insight_type IN ('mood_average','common_theme','intention_cloud','completion_rate','risk_flag')),
  data JSONB NOT NULL,
  generated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_facilitated_events_facilitator ON public.facilitated_events(facilitator_id, event_date DESC);
CREATE INDEX IF NOT EXISTS idx_event_participants_event ON public.event_participants(event_id);
CREATE INDEX IF NOT EXISTS idx_event_participants_user ON public.event_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_event_insights_event ON public.event_insights(event_id, generated_at DESC);
```

## 5.2 Recommended Supporting Tables
```sql
CREATE TABLE IF NOT EXISTS public.facilitator_profiles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  display_name TEXT,
  bio TEXT,
  website TEXT,
  certification_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.facilitator_subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  facilitator_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  plan TEXT NOT NULL CHECK (plan IN ('facilitator','facilitator_pro','enterprise')),
  status TEXT NOT NULL CHECK (status IN ('active','past_due','canceled','trial')),
  participant_limit INTEGER NOT NULL,
  event_limit INTEGER,
  renews_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

## 6. RLS Policy Design
```sql
ALTER TABLE public.facilitated_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.facilitator_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.facilitator_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY facilitated_events_owner_rw
ON public.facilitated_events
FOR ALL
USING (auth.uid() = facilitator_id)
WITH CHECK (auth.uid() = facilitator_id);

CREATE POLICY event_participants_view_own_or_event_owner
ON public.event_participants
FOR SELECT
USING (
  auth.uid() = user_id OR
  EXISTS (
    SELECT 1 FROM public.facilitated_events fe
    WHERE fe.id = event_participants.event_id
      AND fe.facilitator_id = auth.uid()
  )
);

CREATE POLICY event_participants_insert_self
ON public.event_participants
FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY event_participants_update_own
ON public.event_participants
FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY event_insights_select_event_owner
ON public.event_insights
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.facilitated_events fe
    WHERE fe.id = event_insights.event_id
      AND fe.facilitator_id = auth.uid()
  )
);

CREATE POLICY facilitator_profiles_owner_rw
ON public.facilitator_profiles
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY facilitator_subscriptions_owner_rw
ON public.facilitator_subscriptions
FOR ALL
USING (auth.uid() = facilitator_id)
WITH CHECK (auth.uid() = facilitator_id);
```

## 7. API Design
## 7.1 Facilitator APIs
- `POST /facilitator/events` — create event
- `GET /facilitator/events` — list own events
- `PATCH /facilitator/events/:eventId` — update event
- `POST /facilitator/events/:eventId/invite` — generate invite links
- `GET /facilitator/events/:eventId/insights` — fetch aggregated insights

## 7.2 Participant APIs
- `POST /events/:eventId/join` — join with token/consent
- `POST /events/:eventId/pre` — submit pre-event reflection
- `POST /events/:eventId/post` — submit post-event integration
- `GET /events/:eventId/status` — completion state

## 7.3 Internal jobs
- `POST /internal/events/:eventId/generate-insights` — aggregate anonymized stats

## 8. Facilitator Dashboard UI Concept
## 8.1 Dashboard Sections
1. **Today**
   - Upcoming active events
   - Participant completion status
2. **Events**
   - Draft, active, completed tabs
3. **Insights**
   - Mood trend chart
   - Common themes cloud
   - Action follow-through rates
4. **Participants**
   - Count and engagement (no private transcript access)
5. **Billing**
   - Current plan, limits, upgrade options

## 8.2 Event Detail Page
- Header: title, date, status
- Pre-event completion meter
- Post-event completion meter
- Aggregate mood baseline vs post-event shift
- Key anonymized themes

## 8.3 UX Guardrails
- Show insight cards only when anonymization threshold met
- Explicit messaging: “Private participant chats are never visible here.”

## 9. Pricing Model
## 9.1 Plans
- **Facilitator:** EUR 49/month
  - Up to 5 active events
  - Up to 50 participants total
  - Standard insights
- **Facilitator Pro:** EUR 149/month
  - Unlimited events
  - Up to 200 participants
  - Advanced analytics and exports
- **Enterprise:** custom pricing
  - SSO, custom privacy controls, support SLA

## 9.2 Add-ons
- Additional participant bundles
- White-label report exports
- Multi-facilitator workspace seats

## 10. Go-To-Market (B2B)
## 10.1 ICP (Ideal Customer Profile)
- Independent coaches with group programs
- Retreat operators
- Workshop facilitators in personal development/wellness spaces

## 10.2 Entry Strategy
1. 10 design-partner facilitators
2. Case-study generation with measurable outcomes
3. Referral loops through facilitator communities

## 10.3 Success Metrics
- Event activation rate
- Pre and post completion rates
- Facilitator retention (monthly)
- Plan upgrades from Facilitator to Pro

## 11. Risks and Mitigations
- **Risk:** Privacy trust erosion if insights feel too specific.
  - **Mitigation:** strict aggregation thresholds and no transcript visibility.
- **Risk:** B2B support burden.
  - **Mitigation:** templates and self-serve onboarding toolkit.
- **Risk:** Feature complexity.
  - **Mitigation:** phased rollout with MVP insight cards first.

## 12. Rollout Plan
### Phase A (4-6 weeks)
- Schema + RLS
- Event CRUD and participant join
- Pre/post flows

### Phase B (4 weeks)
- Insight generation pipeline
- Dashboard visualization
- Billing gates

### Phase C (4-8 weeks)
- Pro analytics, exports, enterprise controls

## 13. Open Implementation Decisions
1. Use Supabase Edge Functions vs n8n for insight generation cadence.
2. Decide anonymization thresholds per event size.
3. Determine facilitator invite experience (magic links vs token codes).
4. Decide whether event-specific AI prompts are sandboxed by moderation policy.
