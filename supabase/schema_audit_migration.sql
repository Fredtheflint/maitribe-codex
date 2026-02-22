-- MaiTribe schema audit + reconciliation migration
-- Purpose:
-- 1) Ensure required tables exist:
--    users, checkins, identities, conversations, messages, events, reminders, waitlist, astro_transits
-- 2) Add missing columns expected by app code
-- 3) Ensure RLS is enabled and "own data only" policies are present
-- 4) Create common performance indexes (user lookups, date range filters)
--
-- Safe to run multiple times (idempotent).

begin;

create extension if not exists pgcrypto;

-- =========================================================
-- Utility trigger for updated_at
-- =========================================================
create or replace function public.update_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =========================================================
-- Base tables (create if missing)
-- =========================================================

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text,
  display_name text,
  created_at timestamptz default now()
);

create table if not exists public.checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  body integer not null,
  mind integer not null,
  soul integer not null,
  energy integer not null,
  created_at timestamptz default now()
);

create table if not exists public.identities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  full_text text not null,
  created_at timestamptz default now()
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null,
  content text not null,
  created_at timestamptz default now()
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  event_time timestamptz,
  created_at timestamptz default now()
);

create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  type text not null,
  content text not null,
  scheduled_for timestamptz not null,
  created_at timestamptz default now()
);

-- Used by landing page signup (unauthenticated insert path)
create table if not exists public.waitlist (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  name text,
  source text default 'landing',
  user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz default now()
);

-- Requested definition (kept backward compatible with existing installs)
create table if not exists public.astro_transits (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.users(id) on delete cascade not null,
  transit_date date not null,
  daily_insight text,
  hd_daily_gate text,
  hd_gate_description text,
  sun_sign text,
  moon_sign text,
  rising_sign text,
  raw_data jsonb,
  created_at timestamptz default now(),
  unique(user_id, transit_date)
);

-- =========================================================
-- users: app-required columns
-- =========================================================
alter table public.users
  add column if not exists avatar_url text,
  add column if not exists language text default 'en',
  add column if not exists timezone text default 'UTC',
  add column if not exists theme text default 'dark',
  add column if not exists subscription_tier text default 'free',
  add column if not exists subscription_started_at timestamptz,
  add column if not exists subscription_expires_at timestamptz,
  add column if not exists onboarding_completed boolean default false,
  add column if not exists onboarding_step integer default 0,
  add column if not exists birth_date date,
  add column if not exists birth_time time,
  add column if not exists birth_time_known boolean default false,
  add column if not exists birth_city text,
  add column if not exists birth_country text,
  add column if not exists birth_latitude decimal(10, 7),
  add column if not exists birth_longitude decimal(10, 7),
  add column if not exists astrology_enabled boolean default false,
  add column if not exists human_design_enabled boolean default false,
  add column if not exists hd_type text,
  add column if not exists hd_profile text,
  add column if not exists hd_authority text,
  add column if not exists hd_strategy text,
  add column if not exists sun_sign text,
  add column if not exists moon_sign text,
  add column if not exists rising_sign text,
  add column if not exists mc_sign text,
  add column if not exists natal_chart_json jsonb,
  add column if not exists morning_reminder_time time default '07:00',
  add column if not exists morning_reminder_enabled boolean default true,
  add column if not exists mindful_reminders_enabled boolean default true,
  add column if not exists mindful_reminder_count integer default 3,
  add column if not exists event_followup_enabled boolean default true,
  add column if not exists push_token text,
  add column if not exists updated_at timestamptz default now(),
  add column if not exists last_active_at timestamptz default now();

update public.users
set mindful_reminder_count = 3
where mindful_reminder_count is null;

update public.users
set mindful_reminder_count = least(5, greatest(0, mindful_reminder_count))
where mindful_reminder_count < 0 or mindful_reminder_count > 5;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'users_language_check'
  ) then
    alter table public.users
      add constraint users_language_check check (language in ('en', 'de', 'es', 'fr', 'pt', 'it', 'nl'));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'users_theme_check'
  ) then
    alter table public.users
      add constraint users_theme_check check (theme in ('dark', 'light'));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'users_subscription_tier_check'
  ) then
    alter table public.users
      add constraint users_subscription_tier_check check (subscription_tier in ('free', 'premium', 'founding'));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'users_mindful_reminder_count_check'
  ) then
    alter table public.users
      add constraint users_mindful_reminder_count_check check (mindful_reminder_count between 0 and 5);
  end if;
end $$;

drop trigger if exists users_updated_at on public.users;
create trigger users_updated_at
before update on public.users
for each row execute function public.update_updated_at();

-- =========================================================
-- identities: app-required columns
-- =========================================================
alter table public.identities
  add column if not exists one_liner text,
  add column if not exists sentences jsonb,
  add column if not exists language text default 'en',
  add column if not exists is_active boolean default true,
  add column if not exists version integer default 1,
  add column if not exists updated_at timestamptz default now();

drop trigger if exists identities_updated_at on public.identities;
create trigger identities_updated_at
before update on public.identities
for each row execute function public.update_updated_at();

-- =========================================================
-- checkins: app-required columns + constraints
-- =========================================================
alter table public.checkins
  add column if not exists note text,
  add column if not exists mai_response text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'checkins_body_check'
  ) then
    alter table public.checkins
      add constraint checkins_body_check check (body between 1 and 10);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'checkins_mind_check'
  ) then
    alter table public.checkins
      add constraint checkins_mind_check check (mind between 1 and 10);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'checkins_soul_check'
  ) then
    alter table public.checkins
      add constraint checkins_soul_check check (soul between 1 and 10);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'checkins_energy_check'
  ) then
    alter table public.checkins
      add constraint checkins_energy_check check (energy between 1 and 10);
  end if;
end $$;

-- =========================================================
-- conversations: app-required columns
-- =========================================================
alter table public.conversations
  add column if not exists title text,
  add column if not exists summary text,
  add column if not exists topics jsonb default '[]'::jsonb,
  add column if not exists mood text,
  add column if not exists is_active boolean default true,
  add column if not exists updated_at timestamptz default now(),
  add column if not exists ended_at timestamptz;

update public.conversations
set topics = '[]'::jsonb
where topics is null;

drop trigger if exists conversations_updated_at on public.conversations;
create trigger conversations_updated_at
before update on public.conversations
for each row execute function public.update_updated_at();

-- =========================================================
-- messages: app-required columns + constraints
-- =========================================================
alter table public.messages
  add column if not exists input_type text default 'text';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'messages_role_check'
  ) then
    alter table public.messages
      add constraint messages_role_check check (role in ('user', 'assistant'));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'messages_input_type_check'
  ) then
    alter table public.messages
      add constraint messages_input_type_check check (input_type in ('text', 'voice'));
  end if;
end $$;

-- =========================================================
-- events: app-required columns + constraints
-- =========================================================
alter table public.events
  add column if not exists description text,
  add column if not exists source text default 'chat',
  add column if not exists extracted_from_message_id uuid,
  add column if not exists pre_reminder_sent boolean default false,
  add column if not exists pre_reminder_time timestamptz,
  add column if not exists followup_sent boolean default false,
  add column if not exists followup_time timestamptz,
  add column if not exists followup_response text,
  add column if not exists status text default 'upcoming';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'events_extracted_from_message_id_fkey'
  ) then
    alter table public.events
      add constraint events_extracted_from_message_id_fkey
      foreign key (extracted_from_message_id) references public.messages(id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'events_source_check'
  ) then
    alter table public.events
      add constraint events_source_check check (source in ('chat', 'manual', 'calendar'));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'events_status_check'
  ) then
    alter table public.events
      add constraint events_status_check check (status in ('upcoming', 'completed', 'cancelled'));
  end if;
end $$;

-- =========================================================
-- reminders: app-required columns + constraints
-- =========================================================
alter table public.reminders
  add column if not exists variation_type text,
  add column if not exists sent boolean default false,
  add column if not exists sent_at timestamptz,
  add column if not exists delivery_method text default 'push',
  add column if not exists event_id uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'reminders_event_id_fkey'
  ) then
    alter table public.reminders
      add constraint reminders_event_id_fkey
      foreign key (event_id) references public.events(id);
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'reminders_type_check'
  ) then
    alter table public.reminders
      add constraint reminders_type_check
      check (type in ('morning_identity', 'mindful_reminder', 'event_pre', 'event_followup', 'custom'));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'reminders_delivery_method_check'
  ) then
    alter table public.reminders
      add constraint reminders_delivery_method_check
      check (delivery_method in ('push', 'in_app', 'email'));
  end if;
end $$;

-- =========================================================
-- waitlist: ensure app-supported columns
-- =========================================================
alter table public.waitlist
  add column if not exists name text,
  add column if not exists source text default 'landing',
  add column if not exists user_id uuid references auth.users(id) on delete set null,
  add column if not exists created_at timestamptz default now();

-- =========================================================
-- astro_transits: reconcile with requested structure
-- =========================================================
alter table public.astro_transits
  add column if not exists daily_insight text,
  add column if not exists hd_daily_gate text,
  add column if not exists hd_gate_description text,
  add column if not exists sun_sign text,
  add column if not exists moon_sign text,
  add column if not exists rising_sign text,
  add column if not exists raw_data jsonb,
  add column if not exists created_at timestamptz default now();

-- Backward-compat: existing installs may have `transits jsonb`
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'astro_transits'
      and column_name = 'transits'
  ) then
    execute 'update public.astro_transits set raw_data = coalesce(raw_data, transits) where raw_data is null';
  end if;
end $$;

-- If hd_daily_gate exists as integer on older installs, convert to text
do $$
declare
  gate_type text;
begin
  select data_type into gate_type
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'astro_transits'
    and column_name = 'hd_daily_gate';

  if gate_type is not null and gate_type <> 'text' then
    alter table public.astro_transits
      alter column hd_daily_gate type text
      using hd_daily_gate::text;
  end if;
end $$;

-- Ensure uniqueness on (user_id, transit_date)
create unique index if not exists idx_astro_user_date_unique
  on public.astro_transits(user_id, transit_date);

-- =========================================================
-- Indexes for common query paths
-- =========================================================
create index if not exists idx_users_last_active on public.users(last_active_at desc);
create index if not exists idx_users_language on public.users(language);

create index if not exists idx_identities_user_active_created
  on public.identities(user_id, is_active, created_at desc);

create index if not exists idx_checkins_user_date
  on public.checkins(user_id, created_at desc);

create index if not exists idx_conversations_user_created
  on public.conversations(user_id, created_at desc);
create index if not exists idx_conversations_user_active
  on public.conversations(user_id, is_active);
create index if not exists idx_conversations_user_updated
  on public.conversations(user_id, updated_at desc);

create index if not exists idx_messages_conversation_date
  on public.messages(conversation_id, created_at asc);
create index if not exists idx_messages_user_date
  on public.messages(user_id, created_at desc);

create index if not exists idx_events_user_event_time
  on public.events(user_id, event_time asc);
create index if not exists idx_events_followup_due
  on public.events(event_time)
  where followup_sent = false and status in ('upcoming', 'completed');

create index if not exists idx_reminders_pending
  on public.reminders(scheduled_for asc)
  where sent = false;
create index if not exists idx_reminders_user_date
  on public.reminders(user_id, scheduled_for desc);
create index if not exists idx_reminders_event_id
  on public.reminders(event_id);

create index if not exists idx_waitlist_email_lower
  on public.waitlist(lower(email));
create index if not exists idx_waitlist_created_at
  on public.waitlist(created_at desc);

create index if not exists idx_astro_user_date
  on public.astro_transits(user_id, transit_date desc);

-- =========================================================
-- RLS + policies
-- =========================================================
alter table public.users enable row level security;
alter table public.checkins enable row level security;
alter table public.identities enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.events enable row level security;
alter table public.reminders enable row level security;
alter table public.waitlist enable row level security;
alter table public.astro_transits enable row level security;

-- Drop old policy variants if they exist
drop policy if exists "Users can view own profile" on public.users;
drop policy if exists "Users can update own profile" on public.users;
drop policy if exists "Users can insert own profile" on public.users;
drop policy if exists "Users can manage own identities" on public.identities;
drop policy if exists "Users can manage own checkins" on public.checkins;
drop policy if exists "Users can manage own conversations" on public.conversations;
drop policy if exists "Users can manage own messages" on public.messages;
drop policy if exists "Users can manage own events" on public.events;
drop policy if exists "Users can view own reminders" on public.reminders;
drop policy if exists "Users can view own transits" on public.astro_transits;
drop policy if exists "Users read own transits" on public.astro_transits;
drop policy if exists "Service role manages transits" on public.astro_transits;
drop policy if exists "Anyone can insert" on public.waitlist;
drop policy if exists "No anonymous reads" on public.waitlist;
drop policy if exists "Service role manages waitlist" on public.waitlist;
drop policy if exists "users_select_own" on public.users;
drop policy if exists "users_insert_own" on public.users;
drop policy if exists "users_update_own" on public.users;
drop policy if exists "users_delete_own" on public.users;
drop policy if exists "identities_select_own" on public.identities;
drop policy if exists "identities_insert_own" on public.identities;
drop policy if exists "identities_update_own" on public.identities;
drop policy if exists "identities_delete_own" on public.identities;
drop policy if exists "checkins_select_own" on public.checkins;
drop policy if exists "checkins_insert_own" on public.checkins;
drop policy if exists "checkins_update_own" on public.checkins;
drop policy if exists "checkins_delete_own" on public.checkins;
drop policy if exists "conversations_select_own" on public.conversations;
drop policy if exists "conversations_insert_own" on public.conversations;
drop policy if exists "conversations_update_own" on public.conversations;
drop policy if exists "conversations_delete_own" on public.conversations;
drop policy if exists "messages_select_own" on public.messages;
drop policy if exists "messages_insert_own" on public.messages;
drop policy if exists "messages_update_own" on public.messages;
drop policy if exists "messages_delete_own" on public.messages;
drop policy if exists "events_select_own" on public.events;
drop policy if exists "events_insert_own" on public.events;
drop policy if exists "events_update_own" on public.events;
drop policy if exists "events_delete_own" on public.events;
drop policy if exists "reminders_select_own" on public.reminders;
drop policy if exists "reminders_insert_own" on public.reminders;
drop policy if exists "reminders_update_own" on public.reminders;
drop policy if exists "reminders_delete_own" on public.reminders;
drop policy if exists "waitlist_insert_public" on public.waitlist;
drop policy if exists "waitlist_select_own" on public.waitlist;
drop policy if exists "waitlist_update_own" on public.waitlist;
drop policy if exists "astro_transits_insert_own" on public.astro_transits;
drop policy if exists "astro_transits_update_own" on public.astro_transits;
drop policy if exists "astro_transits_delete_own" on public.astro_transits;

-- users
create policy "users_select_own" on public.users
for select using (auth.uid() = id);

create policy "users_insert_own" on public.users
for insert with check (auth.uid() = id);

create policy "users_update_own" on public.users
for update using (auth.uid() = id) with check (auth.uid() = id);

create policy "users_delete_own" on public.users
for delete using (auth.uid() = id);

-- identities
create policy "identities_select_own" on public.identities
for select using (auth.uid() = user_id);

create policy "identities_insert_own" on public.identities
for insert with check (auth.uid() = user_id);

create policy "identities_update_own" on public.identities
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "identities_delete_own" on public.identities
for delete using (auth.uid() = user_id);

-- checkins
create policy "checkins_select_own" on public.checkins
for select using (auth.uid() = user_id);

create policy "checkins_insert_own" on public.checkins
for insert with check (auth.uid() = user_id);

create policy "checkins_update_own" on public.checkins
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "checkins_delete_own" on public.checkins
for delete using (auth.uid() = user_id);

-- conversations
create policy "conversations_select_own" on public.conversations
for select using (auth.uid() = user_id);

create policy "conversations_insert_own" on public.conversations
for insert with check (auth.uid() = user_id);

create policy "conversations_update_own" on public.conversations
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "conversations_delete_own" on public.conversations
for delete using (auth.uid() = user_id);

-- messages (enforce both user_id and parent conversation ownership)
create policy "messages_select_own" on public.messages
for select using (
  auth.uid() = user_id
  and exists (
    select 1
    from public.conversations c
    where c.id = messages.conversation_id
      and c.user_id = auth.uid()
  )
);

create policy "messages_insert_own" on public.messages
for insert with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.conversations c
    where c.id = messages.conversation_id
      and c.user_id = auth.uid()
  )
);

create policy "messages_update_own" on public.messages
for update using (
  auth.uid() = user_id
  and exists (
    select 1
    from public.conversations c
    where c.id = messages.conversation_id
      and c.user_id = auth.uid()
  )
)
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.conversations c
    where c.id = messages.conversation_id
      and c.user_id = auth.uid()
  )
);

create policy "messages_delete_own" on public.messages
for delete using (
  auth.uid() = user_id
  and exists (
    select 1
    from public.conversations c
    where c.id = messages.conversation_id
      and c.user_id = auth.uid()
  )
);

-- events
create policy "events_select_own" on public.events
for select using (auth.uid() = user_id);

create policy "events_insert_own" on public.events
for insert with check (auth.uid() = user_id);

create policy "events_update_own" on public.events
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "events_delete_own" on public.events
for delete using (auth.uid() = user_id);

-- reminders
create policy "reminders_select_own" on public.reminders
for select using (auth.uid() = user_id);

create policy "reminders_insert_own" on public.reminders
for insert with check (auth.uid() = user_id);

create policy "reminders_update_own" on public.reminders
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "reminders_delete_own" on public.reminders
for delete using (auth.uid() = user_id);

-- waitlist
-- Public insert allowed for landing page signup; authenticated users can read/update only own row.
create policy "waitlist_insert_public" on public.waitlist
for insert with check (true);

create policy "waitlist_select_own" on public.waitlist
for select using (auth.uid() is not null and auth.uid() = user_id);

create policy "waitlist_update_own" on public.waitlist
for update using (auth.uid() is not null and auth.uid() = user_id)
with check (auth.uid() is not null and auth.uid() = user_id);

create policy "Service role manages waitlist" on public.waitlist
for all using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

-- astro_transits (as requested)
create policy "Users read own transits" on public.astro_transits
for select using (auth.uid() = user_id);

create policy "astro_transits_insert_own" on public.astro_transits
for insert with check (auth.uid() = user_id);

create policy "astro_transits_update_own" on public.astro_transits
for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "astro_transits_delete_own" on public.astro_transits
for delete using (auth.uid() = user_id);

create policy "Service role manages transits" on public.astro_transits
for all using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

-- =========================================================
-- Final verification notices (table existence)
-- =========================================================
do $$
declare
  tbl text;
  required_tables text[] := array[
    'users',
    'checkins',
    'identities',
    'conversations',
    'messages',
    'events',
    'reminders',
    'waitlist',
    'astro_transits'
  ];
begin
  foreach tbl in array required_tables loop
    if to_regclass('public.' || tbl) is null then
      raise exception 'Required table public.% is missing after migration', tbl;
    else
      raise notice 'Verified table public.%', tbl;
    end if;
  end loop;
end $$;

commit;
