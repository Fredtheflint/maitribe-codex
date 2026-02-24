-- MaiTribe push subscriptions migration
-- Web Push subscription storage + RLS.
-- Safe to run multiple times.

create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  subscription jsonb not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.push_subscriptions enable row level security;

drop policy if exists push_sub_select_own on public.push_subscriptions;
create policy push_sub_select_own
  on public.push_subscriptions
  for select
  using (auth.uid() = user_id);

drop policy if exists push_sub_upsert_own on public.push_subscriptions;
create policy push_sub_upsert_own
  on public.push_subscriptions
  for insert
  with check (auth.uid() = user_id);

drop policy if exists push_sub_update_own on public.push_subscriptions;
create policy push_sub_update_own
  on public.push_subscriptions
  for update
  using (auth.uid() = user_id);

create index if not exists idx_push_subscriptions_active
  on public.push_subscriptions (active);

-- Optional user-level flag for permission flow
alter table public.users
  add column if not exists push_declined boolean default false;

create or replace function public.set_push_subscriptions_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_push_subscriptions_updated_at on public.push_subscriptions;
create trigger trg_push_subscriptions_updated_at
before update on public.push_subscriptions
for each row execute function public.set_push_subscriptions_updated_at();
