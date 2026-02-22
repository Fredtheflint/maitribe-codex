-- MaiTribe workflow schema update (idempotent)
-- Adds all fields required by n8n workflows (WF1-WF4)

begin;

-- =========================================================
-- users
-- =========================================================
alter table public.users
  add column if not exists morning_reminder_time time default '07:00',
  add column if not exists morning_reminder_enabled boolean default true,
  add column if not exists mindful_reminders_enabled boolean default true,
  add column if not exists mindful_reminder_count integer default 3,
  add column if not exists event_followup_enabled boolean default true;

update public.users
set mindful_reminder_count = 3
where mindful_reminder_count is null;

update public.users
set mindful_reminder_count = least(5, greatest(0, mindful_reminder_count))
where mindful_reminder_count < 0 or mindful_reminder_count > 5;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'users_mindful_reminder_count_check'
  ) then
    alter table public.users
      add constraint users_mindful_reminder_count_check
      check (mindful_reminder_count between 0 and 5);
  end if;
end $$;

-- =========================================================
-- identities
-- =========================================================
alter table public.identities
  add column if not exists one_liner text,
  add column if not exists sentences jsonb;

-- =========================================================
-- events
-- =========================================================
alter table public.events
  add column if not exists followup_sent boolean default false,
  add column if not exists followup_time timestamptz,
  add column if not exists followup_response text;

create index if not exists idx_events_followup_due
  on public.events(event_time)
  where followup_sent = false and status in ('upcoming', 'completed');

-- =========================================================
-- conversations
-- =========================================================
alter table public.conversations
  add column if not exists mood text,
  add column if not exists topics jsonb default '[]'::jsonb;

update public.conversations
set topics = '[]'::jsonb
where topics is null;

-- =========================================================
-- reminders
-- =========================================================
alter table public.reminders
  add column if not exists variation_type text,
  add column if not exists event_id uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'reminders_event_id_fkey'
  ) then
    alter table public.reminders
      add constraint reminders_event_id_fkey
      foreign key (event_id) references public.events(id);
  end if;
end $$;

create index if not exists idx_reminders_event_id
  on public.reminders(event_id);

commit;
