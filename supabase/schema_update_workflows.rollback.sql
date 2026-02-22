-- Rollback for: supabase/schema_update_workflows.sql
-- WARNING: This removes columns and data introduced for WF1-WF4.

begin;

-- Drop indexes created by migration

drop index if exists idx_events_followup_due;
drop index if exists idx_reminders_event_id;

-- Drop FK/constraints created by migration

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'reminders_event_id_fkey'
  ) then
    alter table public.reminders
      drop constraint reminders_event_id_fkey;
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'users_mindful_reminder_count_check'
  ) then
    alter table public.users
      drop constraint users_mindful_reminder_count_check;
  end if;
end $$;

-- Drop columns added by migration

alter table public.reminders
  drop column if exists event_id,
  drop column if exists variation_type;

alter table public.conversations
  drop column if exists topics,
  drop column if exists mood;

alter table public.events
  drop column if exists followup_response,
  drop column if exists followup_time,
  drop column if exists followup_sent;

alter table public.identities
  drop column if exists sentences,
  drop column if exists one_liner;

alter table public.users
  drop column if exists event_followup_enabled,
  drop column if exists mindful_reminder_count,
  drop column if exists mindful_reminders_enabled,
  drop column if exists morning_reminder_enabled,
  drop column if exists morning_reminder_time;

commit;
