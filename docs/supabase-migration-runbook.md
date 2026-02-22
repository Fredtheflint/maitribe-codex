# Supabase Migration Runbook (Connect + Safe Checks)

Last updated: 2026-02-21  
Scope: Safe rollout for `/Users/freddy/Downloads/NEW PROJECTS/MAITRIBE Codex/supabase/connect_schema.sql`

## 1) Recommendation: Staging vs Production
Recommended rollout:
1. Apply and validate in **staging** first.
2. Production only after validation queries pass.

Product recommendation (aligned with your proposal):
- **Now**: keep/add astro-related profile fields (birth time/place consistency) in `public.users`.
- **Later**: apply full Connect tables when Connect implementation starts.

Reason:
- Avoid exposing unused match tables/policies early.
- Reduce operational and moderation surface before feature launch.

## 2) Pre-Migration Safe Checks
Run before any migration.

## 2.1 Confirm existing core tables
```sql
select
  to_regclass('public.users') as users,
  to_regclass('public.checkins') as checkins,
  to_regclass('public.identities') as identities,
  to_regclass('public.conversations') as conversations,
  to_regclass('public.messages') as messages,
  to_regclass('public.events') as events,
  to_regclass('public.reminders') as reminders;
```

## 2.2 Check whether Connect tables already exist
```sql
select
  to_regclass('public.connect_profiles') as connect_profiles,
  to_regclass('public.matches') as matches,
  to_regclass('public.blind_chats') as blind_chats,
  to_regclass('public.blind_chat_messages') as blind_chat_messages,
  to_regclass('public.reveals') as reveals,
  to_regclass('public.match_feedback') as match_feedback;
```

Explicit `SELECT EXISTS` variant (copy-paste):
```sql
select
  exists (select 1 from information_schema.tables where table_schema='public' and table_name='connect_profiles') as has_connect_profiles,
  exists (select 1 from information_schema.tables where table_schema='public' and table_name='matches') as has_matches,
  exists (select 1 from information_schema.tables where table_schema='public' and table_name='blind_chats') as has_blind_chats,
  exists (select 1 from information_schema.tables where table_schema='public' and table_name='blind_chat_messages') as has_blind_chat_messages,
  exists (select 1 from information_schema.tables where table_schema='public' and table_name='reveals') as has_reveals,
  exists (select 1 from information_schema.tables where table_schema='public' and table_name='match_feedback') as has_match_feedback;
```

## 2.3 Backup recommendation
Before production migration:
1. Supabase Dashboard -> `Database` -> `Backups`.
2. Create on-demand backup/snapshot.
3. Record timestamp + migration filename in release notes.

## 3) Migration Order (Foreign-Key Safe)
If running as a single file, `connect_schema.sql` already uses a transaction and safe order.

Dependency order:
1. `connect_profiles` (depends on `users`)
2. `matches` (depends on `users`)
3. `blind_chats` (depends on `matches`)
4. `blind_chat_messages` (depends on `blind_chats` + `users`)
5. `reveals` (depends on `matches` + `users`)
6. `match_feedback` (depends on `matches` + `users`)
7. helper functions
8. RLS + policies

Execution command (SQL Editor):
```sql
-- paste entire file:
-- /Users/freddy/Downloads/NEW PROJECTS/MAITRIBE Codex/supabase/connect_schema.sql
```

## 4) Optional "Astro Fields Now" Migration (Safe to run now)
Project uses `public.users` (not `profiles`).

```sql
alter table public.users
  add column if not exists birth_time_known boolean default false,
  add column if not exists birth_city text,
  add column if not exists birth_country text,
  add column if not exists birth_latitude numeric(10,7),
  add column if not exists birth_longitude numeric(10,7),
  add column if not exists astrology_enabled boolean default false,
  add column if not exists human_design_enabled boolean default false,
  add column if not exists hd_type text,
  add column if not exists hd_profile text,
  add column if not exists hd_authority text,
  add column if not exists hd_strategy text;
```

## 5) Rollback SQL (Connect Tables)
Use reverse dependency order.

```sql
begin;

-- drop policies first (optional; drop table cascade would also remove them)

drop table if exists public.blind_chat_messages;
drop table if exists public.match_feedback;
drop table if exists public.reveals;
drop table if exists public.blind_chats;
drop table if exists public.matches;
drop table if exists public.connect_profiles;

drop function if exists public.is_blind_chat_participant(uuid, uuid);
drop function if exists public.is_match_participant(public.matches, uuid);

commit;
```

Note: if `public.matches` is dropped first, `is_match_participant(public.matches, uuid)` may fail to resolve. Keep function drop after table drop only if signature still resolvable; otherwise drop function before dropping `matches`.

Safer variant:
```sql
begin;

-- drop helper functions first
-- if needed, use CASCADE on function drop

drop function if exists public.is_blind_chat_participant(uuid, uuid) cascade;
drop function if exists public.is_match_participant(public.matches, uuid) cascade;

drop table if exists public.blind_chat_messages;
drop table if exists public.match_feedback;
drop table if exists public.reveals;
drop table if exists public.blind_chats;
drop table if exists public.matches;
drop table if exists public.connect_profiles;

commit;
```

## 6) Post-Migration Validation

## 6.1 Table existence check
```sql
select
  to_regclass('public.connect_profiles') as connect_profiles,
  to_regclass('public.matches') as matches,
  to_regclass('public.blind_chats') as blind_chats,
  to_regclass('public.blind_chat_messages') as blind_chat_messages,
  to_regclass('public.reveals') as reveals,
  to_regclass('public.match_feedback') as match_feedback;
```

## 6.2 Constraint + FK sanity check
```sql
select
  tc.table_name,
  tc.constraint_name,
  tc.constraint_type
from information_schema.table_constraints tc
where tc.table_schema = 'public'
  and tc.table_name in ('connect_profiles','matches','blind_chats','blind_chat_messages','reveals','match_feedback')
order by tc.table_name, tc.constraint_type, tc.constraint_name;
```

## 6.3 RLS enabled check
```sql
select
  schemaname,
  tablename,
  rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in ('connect_profiles','matches','blind_chats','blind_chat_messages','reveals','match_feedback')
order by tablename;
```

## 6.4 Policy check
```sql
select
  schemaname,
  tablename,
  policyname,
  cmd
from pg_policies
where schemaname = 'public'
  and tablename in ('connect_profiles','matches','blind_chats','blind_chat_messages','reveals','match_feedback')
order by tablename, policyname;
```

Expected: owner/participant policies + service role policies present.

## 7) Test Insert + Test Select (Staging)
Run with SQL editor in a transaction so you can rollback.

```sql
begin;

-- Replace with 2 real users from public.users
-- select id from public.users limit 2;

-- Example placeholders
-- USER_A = '00000000-0000-0000-0000-000000000001'
-- USER_B = '00000000-0000-0000-0000-000000000002'

insert into public.connect_profiles (user_id, is_active, consented_at, mode)
values
  ('<USER_A>', true, now(), 'both'),
  ('<USER_B>', true, now(), 'both')
on conflict (user_id) do update set is_active = excluded.is_active, updated_at = now();

insert into public.matches (user_a, user_b, status, total_score, engine_version)
values ('<USER_A>', '<USER_B>', 'proposed', 80, 'connect-v1')
returning id;

-- Use returned match id
insert into public.blind_chats (match_id, pseudonym_a, pseudonym_b)
values ('<MATCH_ID>', 'North Star', 'Quiet River')
returning id;

insert into public.blind_chat_messages (blind_chat_id, sender_user_id, content_ciphertext, content_preview)
values ('<BLIND_CHAT_ID>', '<USER_A>', 'ciphertext-placeholder', 'hello');

insert into public.reveals (match_id, requested_by, requested_to, status)
values ('<MATCH_ID>', '<USER_A>', '<USER_B>', 'pending');

insert into public.match_feedback (match_id, user_id, rating, fit_score, safety_score, communication_score)
values ('<MATCH_ID>', '<USER_A>', 4, 78, 88, 74)
on conflict (match_id, user_id) do update
set rating = excluded.rating;

-- validation reads
select * from public.connect_profiles where user_id in ('<USER_A>','<USER_B>');
select * from public.matches where id = '<MATCH_ID>';
select * from public.blind_chats where match_id = '<MATCH_ID>';
select * from public.blind_chat_messages where blind_chat_id = '<BLIND_CHAT_ID>';
select * from public.reveals where match_id = '<MATCH_ID>';
select * from public.match_feedback where match_id = '<MATCH_ID>';

rollback;
```

## 8) Production Cutover Checklist
1. Backup created.
2. Migration run in staging and validated.
3. Policy checks passed.
4. App/API layer for Connect not yet exposed publicly unless feature-flagged.
5. Production migration window + rollback owner assigned.

## 9) Go-Live Recommendation
- Apply only astro/user-profile extension now if needed for upcoming features.
- Keep `connect_schema.sql` queued until Connect implementation and moderation guardrails are ready.
