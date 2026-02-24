-- MaiTribe Daily Calibration migration
-- Adds per-day behavioral mode fields to users table.
-- Safe to run multiple times.

alter table public.users
  add column if not exists daily_mode text default 'soft';

alter table public.users
  add column if not exists daily_mode_set_at timestamptz;

-- Optional data hygiene: enforce allowed values
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'users_daily_mode_check'
  ) then
    alter table public.users
      add constraint users_daily_mode_check
      check (daily_mode in ('soft', 'clear', 'pushy', 'silent'));
  end if;
end $$;

-- Backfill nulls
update public.users
set daily_mode = 'soft'
where daily_mode is null;

-- Optional index for n8n filtering
create index if not exists idx_users_daily_mode
  on public.users (daily_mode);
