-- MaiTribe Connect schema (phase 3/4)
-- Depends on public.users

begin;

create extension if not exists pgcrypto;

-- ---------------------------------------------------------
-- connect_profiles: opt-in and matching preferences
-- ---------------------------------------------------------
create table if not exists public.connect_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,

  is_active boolean not null default false,
  consent_version text not null default 'v1',
  consented_at timestamptz,

  mode text not null default 'both' check (mode in ('friends', 'love', 'both')),
  min_age integer check (min_age between 18 and 100),
  max_age integer check (max_age between 18 and 100),
  distance_km integer default 100 check (distance_km between 1 and 20000),

  preferred_genders text[] default '{}',
  excluded_genders text[] default '{}',

  language_pref text[] default '{}',
  timezone_pref text[] default '{}',

  values_vector jsonb,
  communication_vector jsonb,
  life_goals_vector jsonb,
  emotional_readiness_score numeric(4,2),
  vector_updated_at timestamptz,

  pseudonym_seed text,
  pause_reason text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_connect_profiles_active on public.connect_profiles(is_active);
create index if not exists idx_connect_profiles_user on public.connect_profiles(user_id);

-- ---------------------------------------------------------
-- matches: computed by engine
-- ---------------------------------------------------------
create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),

  user_a uuid not null references public.users(id) on delete cascade,
  user_b uuid not null references public.users(id) on delete cascade,

  status text not null default 'proposed' check (
    status in (
      'proposed',
      'accepted_a',
      'accepted_b',
      'accepted_both',
      'declined_a',
      'declined_b',
      'expired',
      'blind_chat_active',
      'revealed',
      'closed'
    )
  ),

  astro_score integer check (astro_score between 0 and 100),
  hd_score integer check (hd_score between 0 and 100),
  values_score integer check (values_score between 0 and 100),
  communication_score integer check (communication_score between 0 and 100),
  readiness_score integer check (readiness_score between 0 and 100),
  total_score integer check (total_score between 0 and 100),

  score_breakdown jsonb,
  explanation jsonb,
  engine_version text,

  proposed_at timestamptz not null default now(),
  expires_at timestamptz,
  accepted_at_a timestamptz,
  accepted_at_b timestamptz,
  closed_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint matches_users_not_same check (user_a <> user_b)
);

create index if not exists idx_matches_user_a_status on public.matches(user_a, status, created_at desc);
create index if not exists idx_matches_user_b_status on public.matches(user_b, status, created_at desc);
create index if not exists idx_matches_total_score on public.matches(total_score desc);

-- ---------------------------------------------------------
-- blind_chats: anonymous room for accepted matches
-- ---------------------------------------------------------
create table if not exists public.blind_chats (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null unique references public.matches(id) on delete cascade,

  pseudonym_a text not null,
  pseudonym_b text not null,

  is_active boolean not null default true,
  reveal_state text not null default 'none' check (reveal_state in ('none', 'requested', 'one_sided', 'mutual', 'done')),

  created_at timestamptz not null default now(),
  ended_at timestamptz,
  updated_at timestamptz not null default now()
);

create index if not exists idx_blind_chats_active on public.blind_chats(is_active, created_at desc);

-- ---------------------------------------------------------
-- blind_chat_messages: message stream inside blind chat
-- ---------------------------------------------------------
create table if not exists public.blind_chat_messages (
  id uuid primary key default gen_random_uuid(),
  blind_chat_id uuid not null references public.blind_chats(id) on delete cascade,
  sender_user_id uuid not null references public.users(id) on delete cascade,

  content_ciphertext text not null,
  content_preview text,

  created_at timestamptz not null default now()
);

create index if not exists idx_blind_chat_messages_chat_time on public.blind_chat_messages(blind_chat_id, created_at asc);
create index if not exists idx_blind_chat_messages_sender on public.blind_chat_messages(sender_user_id, created_at desc);

-- ---------------------------------------------------------
-- reveals: explicit reveal handshake
-- ---------------------------------------------------------
create table if not exists public.reveals (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  requested_by uuid not null references public.users(id) on delete cascade,
  requested_to uuid not null references public.users(id) on delete cascade,

  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'expired', 'cancelled')),

  requested_at timestamptz not null default now(),
  responded_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),

  constraint reveal_users_not_same check (requested_by <> requested_to)
);

create index if not exists idx_reveals_match on public.reveals(match_id, created_at desc);
create index if not exists idx_reveals_requested_to_status on public.reveals(requested_to, status, created_at desc);

-- ---------------------------------------------------------
-- match_feedback: post-match learning signals
-- ---------------------------------------------------------
create table if not exists public.match_feedback (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,

  rating integer check (rating between 1 and 5),
  fit_score integer check (fit_score between 0 and 100),
  safety_score integer check (safety_score between 0 and 100),
  communication_score integer check (communication_score between 0 and 100),

  reasons text[],
  notes text,

  vector_delta jsonb,
  created_at timestamptz not null default now(),

  unique (match_id, user_id)
);

create index if not exists idx_match_feedback_match on public.match_feedback(match_id);
create index if not exists idx_match_feedback_user on public.match_feedback(user_id, created_at desc);

-- ---------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------
create or replace function public.is_match_participant(match_row public.matches, uid uuid)
returns boolean
language sql
stable
as $$
  select uid = match_row.user_a or uid = match_row.user_b;
$$;

create or replace function public.is_blind_chat_participant(chat_id uuid, uid uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.blind_chats bc
    join public.matches m on m.id = bc.match_id
    where bc.id = chat_id
      and (m.user_a = uid or m.user_b = uid)
  );
$$;

-- ---------------------------------------------------------
-- RLS
-- ---------------------------------------------------------
alter table public.connect_profiles enable row level security;
alter table public.matches enable row level security;
alter table public.blind_chats enable row level security;
alter table public.blind_chat_messages enable row level security;
alter table public.reveals enable row level security;
alter table public.match_feedback enable row level security;

-- connect_profiles
drop policy if exists connect_profiles_select_own on public.connect_profiles;
create policy connect_profiles_select_own on public.connect_profiles
for select using (auth.uid() = user_id);

drop policy if exists connect_profiles_insert_own on public.connect_profiles;
create policy connect_profiles_insert_own on public.connect_profiles
for insert with check (auth.uid() = user_id);

drop policy if exists connect_profiles_update_own on public.connect_profiles;
create policy connect_profiles_update_own on public.connect_profiles
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists connect_profiles_delete_own on public.connect_profiles;
create policy connect_profiles_delete_own on public.connect_profiles
for delete using (auth.uid() = user_id);

drop policy if exists connect_profiles_service_all on public.connect_profiles;
create policy connect_profiles_service_all on public.connect_profiles
for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- matches
drop policy if exists matches_select_participant on public.matches;
create policy matches_select_participant on public.matches
for select using (auth.uid() = user_a or auth.uid() = user_b);

drop policy if exists matches_update_participant on public.matches;
create policy matches_update_participant on public.matches
for update using (auth.uid() = user_a or auth.uid() = user_b)
with check (auth.uid() = user_a or auth.uid() = user_b);

drop policy if exists matches_service_all on public.matches;
create policy matches_service_all on public.matches
for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- blind_chats
drop policy if exists blind_chats_select_participant on public.blind_chats;
create policy blind_chats_select_participant on public.blind_chats
for select using (
  exists (
    select 1 from public.matches m
    where m.id = blind_chats.match_id
      and (m.user_a = auth.uid() or m.user_b = auth.uid())
  )
);

drop policy if exists blind_chats_update_participant on public.blind_chats;
create policy blind_chats_update_participant on public.blind_chats
for update using (
  exists (
    select 1 from public.matches m
    where m.id = blind_chats.match_id
      and (m.user_a = auth.uid() or m.user_b = auth.uid())
  )
)
with check (
  exists (
    select 1 from public.matches m
    where m.id = blind_chats.match_id
      and (m.user_a = auth.uid() or m.user_b = auth.uid())
  )
);

drop policy if exists blind_chats_service_all on public.blind_chats;
create policy blind_chats_service_all on public.blind_chats
for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- blind_chat_messages
drop policy if exists blind_chat_messages_select_participant on public.blind_chat_messages;
create policy blind_chat_messages_select_participant on public.blind_chat_messages
for select using (public.is_blind_chat_participant(blind_chat_id, auth.uid()));

drop policy if exists blind_chat_messages_insert_sender on public.blind_chat_messages;
create policy blind_chat_messages_insert_sender on public.blind_chat_messages
for insert with check (
  auth.uid() = sender_user_id
  and public.is_blind_chat_participant(blind_chat_id, auth.uid())
);

drop policy if exists blind_chat_messages_service_all on public.blind_chat_messages;
create policy blind_chat_messages_service_all on public.blind_chat_messages
for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- reveals
drop policy if exists reveals_select_participant on public.reveals;
create policy reveals_select_participant on public.reveals
for select using (auth.uid() = requested_by or auth.uid() = requested_to);

drop policy if exists reveals_insert_requester on public.reveals;
create policy reveals_insert_requester on public.reveals
for insert with check (auth.uid() = requested_by);

drop policy if exists reveals_update_participant on public.reveals;
create policy reveals_update_participant on public.reveals
for update using (auth.uid() = requested_by or auth.uid() = requested_to)
with check (auth.uid() = requested_by or auth.uid() = requested_to);

drop policy if exists reveals_service_all on public.reveals;
create policy reveals_service_all on public.reveals
for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

-- match_feedback
drop policy if exists match_feedback_select_own on public.match_feedback;
create policy match_feedback_select_own on public.match_feedback
for select using (auth.uid() = user_id);

drop policy if exists match_feedback_insert_own on public.match_feedback;
create policy match_feedback_insert_own on public.match_feedback
for insert with check (auth.uid() = user_id);

drop policy if exists match_feedback_update_own on public.match_feedback;
create policy match_feedback_update_own on public.match_feedback
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists match_feedback_service_all on public.match_feedback;
create policy match_feedback_service_all on public.match_feedback
for all using (auth.role() = 'service_role') with check (auth.role() = 'service_role');

commit;
