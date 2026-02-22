-- MaiTribe Supabase schema (MVP + Phase 2 ready)
-- Run this in Supabase SQL editor.

create extension if not exists pgcrypto;

create or replace function public.update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text,
  display_name text,
  avatar_url text,

  language text default 'en' check (language in ('en', 'de', 'es', 'fr', 'pt', 'it', 'nl')),
  timezone text default 'UTC',
  theme text default 'dark' check (theme in ('dark', 'light')),

  subscription_tier text default 'free' check (subscription_tier in ('free', 'premium', 'founding')),
  subscription_started_at timestamptz,
  subscription_expires_at timestamptz,

  onboarding_completed boolean default false,
  onboarding_step integer default 0,

  birth_date date,
  birth_time time,
  birth_time_known boolean default false,
  birth_city text,
  birth_country text,
  birth_latitude decimal(10, 7),
  birth_longitude decimal(10, 7),

  astrology_enabled boolean default false,
  human_design_enabled boolean default false,

  hd_type text,
  hd_profile text,
  hd_authority text,
  hd_strategy text,

  sun_sign text,
  moon_sign text,
  rising_sign text,
  mc_sign text,
  natal_chart_json jsonb,

  morning_reminder_enabled boolean default true,
  morning_reminder_time time default '07:00',
  mindful_reminders_enabled boolean default true,
  mindful_reminder_count integer default 3 check (mindful_reminder_count between 0 and 5),
  event_followup_enabled boolean default true,
  push_token text,

  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  last_active_at timestamptz default now()
);

create index if not exists idx_users_last_active on public.users(last_active_at desc);
create index if not exists idx_users_subscription on public.users(subscription_tier);

drop trigger if exists users_updated_at on public.users;
create trigger users_updated_at
before update on public.users
for each row execute function public.update_updated_at();

create table if not exists public.identities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,

  full_text text not null,
  sentences jsonb,
  one_liner text,
  language text default 'en',

  is_active boolean default true,
  version integer default 1,

  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_identities_user_active on public.identities(user_id, is_active);

drop trigger if exists identities_updated_at on public.identities;
create trigger identities_updated_at
before update on public.identities
for each row execute function public.update_updated_at();

create table if not exists public.checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,

  body integer not null check (body between 1 and 10),
  mind integer not null check (mind between 1 and 10),
  soul integer not null check (soul between 1 and 10),
  energy integer not null check (energy between 1 and 10),

  note text,
  mai_response text,
  created_at timestamptz default now()
);

create index if not exists idx_checkins_user_date on public.checkins(user_id, created_at desc);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,

  title text,
  summary text,
  topics jsonb default '[]'::jsonb,
  mood text,

  is_active boolean default true,

  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  ended_at timestamptz
);

create index if not exists idx_conversations_user on public.conversations(user_id, created_at desc);
create index if not exists idx_conversations_active on public.conversations(user_id, is_active);

drop trigger if exists conversations_updated_at on public.conversations;
create trigger conversations_updated_at
before update on public.conversations
for each row execute function public.update_updated_at();

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,

  role text not null check (role in ('user', 'assistant')),
  content text not null,
  input_type text default 'text' check (input_type in ('text', 'voice')),

  created_at timestamptz default now()
);

create index if not exists idx_messages_conversation on public.messages(conversation_id, created_at asc);
create index if not exists idx_messages_user on public.messages(user_id, created_at desc);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,

  title text not null,
  description text,
  event_time timestamptz,

  source text default 'chat' check (source in ('chat', 'manual', 'calendar')),
  extracted_from_message_id uuid references public.messages(id),

  pre_reminder_sent boolean default false,
  pre_reminder_time timestamptz,
  followup_sent boolean default false,
  followup_time timestamptz,
  followup_response text,

  status text default 'upcoming' check (status in ('upcoming', 'completed', 'cancelled')),

  created_at timestamptz default now()
);

create index if not exists idx_events_user_upcoming on public.events(user_id, event_time asc) where status = 'upcoming';

create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,

  type text not null check (type in ('morning_identity', 'mindful_reminder', 'event_pre', 'event_followup', 'custom')),
  content text not null,
  variation_type text,

  scheduled_for timestamptz not null,

  sent boolean default false,
  sent_at timestamptz,
  delivery_method text default 'push' check (delivery_method in ('push', 'in_app', 'email')),

  event_id uuid references public.events(id),
  created_at timestamptz default now()
);

create index if not exists idx_reminders_pending on public.reminders(scheduled_for asc) where sent = false;
create index if not exists idx_reminders_user on public.reminders(user_id, scheduled_for desc);

create table if not exists public.astro_transits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,

  transit_date date not null,
  transits jsonb not null,
  daily_insight text,

  hd_daily_gate integer,
  hd_gate_description text,

  created_at timestamptz default now(),
  unique(user_id, transit_date)
);

create index if not exists idx_astro_user_date on public.astro_transits(user_id, transit_date desc);

-- RLS
alter table public.users enable row level security;
alter table public.identities enable row level security;
alter table public.checkins enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.events enable row level security;
alter table public.reminders enable row level security;
alter table public.astro_transits enable row level security;

drop policy if exists "Users can view own profile" on public.users;
create policy "Users can view own profile" on public.users
for select using (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.users;
create policy "Users can update own profile" on public.users
for update using (auth.uid() = id);

drop policy if exists "Users can insert own profile" on public.users;
create policy "Users can insert own profile" on public.users
for insert with check (auth.uid() = id);

drop policy if exists "Users can manage own identities" on public.identities;
create policy "Users can manage own identities" on public.identities
for all using (auth.uid() = user_id);

drop policy if exists "Users can manage own checkins" on public.checkins;
create policy "Users can manage own checkins" on public.checkins
for all using (auth.uid() = user_id);

drop policy if exists "Users can manage own conversations" on public.conversations;
create policy "Users can manage own conversations" on public.conversations
for all using (auth.uid() = user_id);

drop policy if exists "Users can manage own messages" on public.messages;
create policy "Users can manage own messages" on public.messages
for all using (auth.uid() = user_id);

drop policy if exists "Users can manage own events" on public.events;
create policy "Users can manage own events" on public.events
for all using (auth.uid() = user_id);

drop policy if exists "Users can view own reminders" on public.reminders;
create policy "Users can view own reminders" on public.reminders
for select using (auth.uid() = user_id);

drop policy if exists "Users can view own transits" on public.astro_transits;
create policy "Users can view own transits" on public.astro_transits
for select using (auth.uid() = user_id);

-- Auto-create user profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, email, name, display_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();
