-- MaiTribe Evidence Bank migration
-- Creates public.evidence with RLS + indexes.
-- Safe to run multiple times.

create table if not exists public.evidence (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  identity_id uuid not null references public.identities(id) on delete cascade,
  content text not null,
  category text,
  energy_level int,
  source text not null default 'manual',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint evidence_category_check check (
    category is null or category in ('body', 'mind', 'soul', 'spirit')
  ),
  constraint evidence_energy_level_check check (
    energy_level is null or (energy_level between 1 and 5)
  ),
  constraint evidence_source_check check (
    source in ('manual', 'checkin', 'chat', 'push_response')
  )
);

create index if not exists idx_evidence_user_created_at
  on public.evidence (user_id, created_at desc);

create index if not exists idx_evidence_identity_created_at
  on public.evidence (identity_id, created_at desc);

alter table public.evidence enable row level security;

drop policy if exists evidence_select_own on public.evidence;
create policy evidence_select_own
  on public.evidence
  for select
  using (auth.uid() = user_id);

drop policy if exists evidence_insert_own on public.evidence;
create policy evidence_insert_own
  on public.evidence
  for insert
  with check (auth.uid() = user_id);

drop policy if exists evidence_update_own on public.evidence;
create policy evidence_update_own
  on public.evidence
  for update
  using (auth.uid() = user_id);

drop policy if exists evidence_delete_own on public.evidence;
create policy evidence_delete_own
  on public.evidence
  for delete
  using (auth.uid() = user_id);

create or replace function public.set_evidence_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_evidence_set_updated_at on public.evidence;
create trigger trg_evidence_set_updated_at
before update on public.evidence
for each row
execute function public.set_evidence_updated_at();

-- Verification snippets
-- select * from pg_policies where schemaname='public' and tablename='evidence';
-- select column_name, data_type from information_schema.columns where table_schema='public' and table_name='evidence';
