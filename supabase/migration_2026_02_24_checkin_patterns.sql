-- MaiTribe checkin intelligence migration
-- Adds checkin_patterns table with RLS.
-- Safe to run multiple times.

create table if not exists public.checkin_patterns (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  pattern_type text not null,
  description text not null,
  data jsonb,
  detected_at timestamptz not null default now(),
  acknowledged boolean not null default false,
  created_at timestamptz not null default now(),
  constraint checkin_patterns_type_check check (
    pattern_type in (
      'declining_trend',
      'improving_trend',
      'recurring_low',
      'energy_correlation',
      'weekday_pattern',
      'body_mind_disconnect'
    )
  )
);

create index if not exists idx_checkin_patterns_user_detected
  on public.checkin_patterns (user_id, detected_at desc);

create index if not exists idx_checkin_patterns_user_type
  on public.checkin_patterns (user_id, pattern_type);

alter table public.checkin_patterns enable row level security;

drop policy if exists checkin_patterns_select_own on public.checkin_patterns;
create policy checkin_patterns_select_own
  on public.checkin_patterns
  for select
  using (auth.uid() = user_id);

drop policy if exists checkin_patterns_insert_own on public.checkin_patterns;
create policy checkin_patterns_insert_own
  on public.checkin_patterns
  for insert
  with check (auth.uid() = user_id);

drop policy if exists checkin_patterns_update_own on public.checkin_patterns;
create policy checkin_patterns_update_own
  on public.checkin_patterns
  for update
  using (auth.uid() = user_id);
