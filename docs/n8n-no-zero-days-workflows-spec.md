# MaiTribe n8n Specs: No Zero Days Push System

## Goal
Context-aware notifications that feel personal, with strict frequency limits and user mode control.

## Core Rule
"Mai reacts to your life, not just to a timer."

## Prerequisites
- Supabase credentials in n8n (service role key)
- Gemini API key credential in n8n
- Push delivery endpoint (Edge Function `send-push`) available
- `users.push_token` contains valid web push subscription JSON

## Global Frequency Guardrails

### User modes
- `soft`: max 2/day (morning + evening)
- `clear`: max 3/day
- `pushy`: max 4/day
- `silent`: max 1/day (evening only)

### Hard cap
- Never send more than 5 notifications/day per user.

### Guard query (shared in all workflows)
```sql
select count(*)::int as sent_today
from public.reminders
where user_id = $1
  and date_trunc('day', created_at at time zone coalesce($2, 'UTC'))
      = date_trunc('day', now() at time zone coalesce($2, 'UTC'));
```

## Workflow 1: Morning Identity Anchor

## Trigger
- Cron every 15 minutes from 07:00-09:00 UTC
- Filter in SQL by user timezone and configured wake window

## Supabase query
```sql
with active_users as (
  select
    u.id as user_id,
    u.display_name,
    u.name,
    u.language,
    u.timezone,
    u.push_token,
    coalesce(u.daily_mode, 'soft') as daily_mode,
    coalesce(u.morning_reminder_enabled, true) as morning_enabled,
    coalesce(u.morning_reminder_time::text, '07:00:00') as morning_time
  from public.users u
  where u.push_token is not null
    and coalesce(u.morning_reminder_enabled, true) = true
),
latest_identity as (
  select distinct on (i.user_id)
    i.user_id, i.full_text, i.one_liner
  from public.identities i
  where i.is_active = true
  order by i.user_id, i.created_at desc
),
latest_checkin as (
  select distinct on (c.user_id)
    c.user_id, c.body, c.mind, c.soul, c.energy, c.created_at
  from public.checkins c
  order by c.user_id, c.created_at desc
)
select
  au.*,
  li.one_liner,
  li.full_text,
  lc.body, lc.mind, lc.soul, lc.energy
from active_users au
left join latest_identity li on li.user_id = au.user_id
left join latest_checkin lc on lc.user_id = au.user_id;
```

## Gemini prompt template
```text
You are Mai. Generate a short morning identity anchor in {{language}}.
User name: {{display_name_or_name}}
Identity: {{one_liner_or_full_text}}
Latest check-in: body {{body}}, mind {{mind}}, soul {{soul}}, energy {{energy}}

Constraints:
- Max 2 sentences
- Warm and grounded
- No emojis
- Invite one tiny proof action for today
```

## Push payload template
```json
{
  "title": "Mai",
  "body": "{{gemini_message}}",
  "data": { "type": "morning_anchor" }
}
```

## Logging query
```sql
insert into public.reminders (user_id, type, content, variation_type, created_at)
values ($1, 'morning_identity', $2, 'anchor', now());
```

## JSON template (import starter)
```json
{
  "name": "No Zero Days - Morning Identity Anchor",
  "nodes": [
    { "id": "n1", "name": "Cron", "type": "n8n-nodes-base.cron", "typeVersion": 1, "position": [200, 300], "parameters": { "triggerTimes": { "item": [{ "mode": "everyX", "unit": "minutes", "value": 15 }] } } },
    { "id": "n2", "name": "Fetch Candidates", "type": "n8n-nodes-base.postgres", "typeVersion": 2, "position": [440, 300], "parameters": { "operation": "executeQuery", "query": "-- paste query above" } },
    { "id": "n3", "name": "Frequency Guard", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [680, 300], "parameters": { "jsCode": "// filter by sent_today and daily_mode limits" } },
    { "id": "n4", "name": "Gemini Morning Text", "type": "n8n-nodes-base.httpRequest", "typeVersion": 4, "position": [920, 300], "parameters": { "method": "POST", "url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" } },
    { "id": "n5", "name": "Send Push", "type": "n8n-nodes-base.httpRequest", "typeVersion": 4, "position": [1160, 300], "parameters": { "method": "POST", "url": "https://<project-ref>.supabase.co/functions/v1/send-push" } },
    { "id": "n6", "name": "Log Reminder", "type": "n8n-nodes-base.postgres", "typeVersion": 2, "position": [1400, 300], "parameters": { "operation": "executeQuery", "query": "-- insert reminder log" } }
  ],
  "connections": {
    "Cron": { "main": [[{ "node": "Fetch Candidates", "type": "main", "index": 0 }]] },
    "Fetch Candidates": { "main": [[{ "node": "Frequency Guard", "type": "main", "index": 0 }]] },
    "Frequency Guard": { "main": [[{ "node": "Gemini Morning Text", "type": "main", "index": 0 }]] },
    "Gemini Morning Text": { "main": [[{ "node": "Send Push", "type": "main", "index": 0 }]] },
    "Send Push": { "main": [[{ "node": "Log Reminder", "type": "main", "index": 0 }]] }
  },
  "active": false,
  "settings": {}
}
```

## Workflow 2: Context-Aware Nudge (Pre-Event + Follow-Up)

## Trigger
- Cron every 10 minutes
- Finds events near pre-window (`event_time - 30m`) and post-window (`event_time + 2h`)

## Supabase query
```sql
select
  e.id as event_id,
  e.user_id,
  e.title,
  e.event_time,
  u.display_name,
  u.name,
  u.language,
  u.timezone,
  u.push_token,
  coalesce(u.daily_mode, 'soft') as daily_mode,
  case
    when now() between (e.event_time - interval '35 min') and (e.event_time - interval '25 min') then 'pre_event'
    when now() between (e.event_time + interval '115 min') and (e.event_time + interval '125 min') then 'post_event'
    else null
  end as phase
from public.events e
join public.users u on u.id = e.user_id
where u.push_token is not null
  and e.event_time is not null
  and e.status is distinct from 'done';
```

## Gemini prompt template
```text
You are Mai. Write one short {{phase}} nudge in {{language}}.
User: {{display_name_or_name}}
Event title: {{event_title}}

Rules:
- 1-2 sentences
- calm and personal
- no generic motivation phrases
- no emojis

If pre_event: help user arrive grounded.
If post_event: ask one caring follow-up question.
```

## Idempotency check query
```sql
select exists(
  select 1 from public.reminders
  where user_id = $1
    and type = 'event_nudge'
    and event_id = $2
    and variation_type = $3
) as already_sent;
```

## Logging query
```sql
insert into public.reminders (user_id, type, event_id, variation_type, content, created_at)
values ($1, 'event_nudge', $2, $3, $4, now());
```

## JSON template
```json
{
  "name": "No Zero Days - Context-Aware Nudge",
  "nodes": [
    { "id": "n1", "name": "Cron", "type": "n8n-nodes-base.cron", "typeVersion": 1, "position": [200, 500], "parameters": { "triggerTimes": { "item": [{ "mode": "everyX", "unit": "minutes", "value": 10 }] } } },
    { "id": "n2", "name": "Fetch Event Windows", "type": "n8n-nodes-base.postgres", "typeVersion": 2, "position": [450, 500], "parameters": { "operation": "executeQuery", "query": "-- paste query above" } },
    { "id": "n3", "name": "Skip Duplicates", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [700, 500], "parameters": { "jsCode": "// check reminders table for event+phase idempotency" } },
    { "id": "n4", "name": "Gemini Nudge", "type": "n8n-nodes-base.httpRequest", "typeVersion": 4, "position": [940, 500], "parameters": { "method": "POST", "url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" } },
    { "id": "n5", "name": "Send Push", "type": "n8n-nodes-base.httpRequest", "typeVersion": 4, "position": [1180, 500], "parameters": { "method": "POST", "url": "https://<project-ref>.supabase.co/functions/v1/send-push" } },
    { "id": "n6", "name": "Log Reminder", "type": "n8n-nodes-base.postgres", "typeVersion": 2, "position": [1420, 500], "parameters": { "operation": "executeQuery", "query": "-- insert reminder log" } }
  ],
  "connections": {
    "Cron": { "main": [[{ "node": "Fetch Event Windows", "type": "main", "index": 0 }]] },
    "Fetch Event Windows": { "main": [[{ "node": "Skip Duplicates", "type": "main", "index": 0 }]] },
    "Skip Duplicates": { "main": [[{ "node": "Gemini Nudge", "type": "main", "index": 0 }]] },
    "Gemini Nudge": { "main": [[{ "node": "Send Push", "type": "main", "index": 0 }]] },
    "Send Push": { "main": [[{ "node": "Log Reminder", "type": "main", "index": 0 }]] }
  },
  "active": false,
  "settings": {}
}
```

## Workflow 3: Evening Proof Collection

## Trigger
- Cron every 20 minutes from 20:00-21:00 local user time

## Supabase query
```sql
with today_proof as (
  select
    m.user_id,
    max(m.content) filter (where m.role = 'assistant' and m.content ilike '%proved%') as proof_line
  from public.messages m
  where m.created_at >= date_trunc('day', now())
  group by m.user_id
)
select
  u.id as user_id,
  u.display_name,
  u.name,
  u.language,
  u.timezone,
  u.push_token,
  coalesce(u.daily_mode, 'soft') as daily_mode,
  tp.proof_line
from public.users u
left join today_proof tp on tp.user_id = u.id
where u.push_token is not null;
```

## Gemini prompt template
```text
You are Mai. Write a short evening identity-proof message in {{language}}.
User: {{display_name_or_name}}
Proof today: {{proof_line_or_none}}

If proof exists: reinforce gently ("this counts").
If no proof: ask for one small proof moment before day ends.

Constraints:
- max 2 sentences
- no guilt tone
- no emojis
```

## Logging query
```sql
insert into public.reminders (user_id, type, variation_type, content, created_at)
values ($1, 'evening_proof', case when $2 = true then 'proof_exists' else 'proof_missing' end, $3, now());
```

## JSON template
```json
{
  "name": "No Zero Days - Evening Proof Collection",
  "nodes": [
    { "id": "n1", "name": "Cron", "type": "n8n-nodes-base.cron", "typeVersion": 1, "position": [200, 700], "parameters": { "triggerTimes": { "item": [{ "mode": "everyX", "unit": "minutes", "value": 20 }] } } },
    { "id": "n2", "name": "Fetch Evening Candidates", "type": "n8n-nodes-base.postgres", "typeVersion": 2, "position": [450, 700], "parameters": { "operation": "executeQuery", "query": "-- paste query above" } },
    { "id": "n3", "name": "Frequency Guard", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [700, 700], "parameters": { "jsCode": "// enforce mode and hard cap" } },
    { "id": "n4", "name": "Gemini Evening Text", "type": "n8n-nodes-base.httpRequest", "typeVersion": 4, "position": [940, 700], "parameters": { "method": "POST", "url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" } },
    { "id": "n5", "name": "Send Push", "type": "n8n-nodes-base.httpRequest", "typeVersion": 4, "position": [1180, 700], "parameters": { "method": "POST", "url": "https://<project-ref>.supabase.co/functions/v1/send-push" } },
    { "id": "n6", "name": "Log Reminder", "type": "n8n-nodes-base.postgres", "typeVersion": 2, "position": [1420, 700], "parameters": { "operation": "executeQuery", "query": "-- insert reminder log" } }
  ],
  "connections": {
    "Cron": { "main": [[{ "node": "Fetch Evening Candidates", "type": "main", "index": 0 }]] },
    "Fetch Evening Candidates": { "main": [[{ "node": "Frequency Guard", "type": "main", "index": 0 }]] },
    "Frequency Guard": { "main": [[{ "node": "Gemini Evening Text", "type": "main", "index": 0 }]] },
    "Gemini Evening Text": { "main": [[{ "node": "Send Push", "type": "main", "index": 0 }]] },
    "Send Push": { "main": [[{ "node": "Log Reminder", "type": "main", "index": 0 }]] }
  },
  "active": false,
  "settings": {}
}
```

## Workflow 4: Daily Calibration Prompt

## Trigger
- Cron at 07:30 local user time (after morning anchor)

## Supabase query
```sql
select
  u.id as user_id,
  u.display_name,
  u.name,
  u.language,
  u.timezone,
  u.push_token
from public.users u
where u.push_token is not null
  and coalesce(u.morning_reminder_enabled, true) = true;
```

## Prompt payload
No Gemini required. Static multilingual copy:

- DE: "Wie soll Mai heute fuer dich da sein? Soft, Klar, Pushy oder Silent?"
- EN: "How should Mai support you today? Soft, Clear, Pushy, or Silent?"

Push `data` must include selectable mode options:
```json
{
  "type": "daily_calibration",
  "options": ["soft", "clear", "pushy", "silent"]
}
```

## User response handling
- Response endpoint writes:
```sql
update public.users
set daily_mode = $2, updated_at = now()
where id = $1;
```

## JSON template
```json
{
  "name": "No Zero Days - Daily Calibration Prompt",
  "nodes": [
    { "id": "n1", "name": "Cron", "type": "n8n-nodes-base.cron", "typeVersion": 1, "position": [200, 900], "parameters": { "triggerTimes": { "item": [{ "hour": 7, "minute": 30 }] } } },
    { "id": "n2", "name": "Fetch Users", "type": "n8n-nodes-base.postgres", "typeVersion": 2, "position": [450, 900], "parameters": { "operation": "executeQuery", "query": "-- paste query above" } },
    { "id": "n3", "name": "Build Prompt Payload", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [700, 900], "parameters": { "jsCode": "// create localized text + options array" } },
    { "id": "n4", "name": "Send Push", "type": "n8n-nodes-base.httpRequest", "typeVersion": 4, "position": [940, 900], "parameters": { "method": "POST", "url": "https://<project-ref>.supabase.co/functions/v1/send-push" } },
    { "id": "n5", "name": "Log Reminder", "type": "n8n-nodes-base.postgres", "typeVersion": 2, "position": [1180, 900], "parameters": { "operation": "executeQuery", "query": "-- insert reminder log with type daily_calibration" } }
  ],
  "connections": {
    "Cron": { "main": [[{ "node": "Fetch Users", "type": "main", "index": 0 }]] },
    "Fetch Users": { "main": [[{ "node": "Build Prompt Payload", "type": "main", "index": 0 }]] },
    "Build Prompt Payload": { "main": [[{ "node": "Send Push", "type": "main", "index": 0 }]] },
    "Send Push": { "main": [[{ "node": "Log Reminder", "type": "main", "index": 0 }]] }
  },
  "active": false,
  "settings": {}
}
```

## Error Handling (All Workflows)
- Missing `push_token`: skip user
- Push endpoint `410 Gone`: mark token invalid
  ```sql
  update public.users set push_token = null where id = $1;
  ```
- Gemini quota/timeout:
  - fallback to static message per language
  - still log reminder with `variation_type = 'fallback'`
- Supabase query failures:
  - retry once in n8n
  - send alert to ops channel/email

## Recommended Rollout
1. Start with Workflow 1 + 3 only (soft mode defaults)
2. Add Workflow 2 once event extraction quality is stable
3. Enable Workflow 4 after frontend mode selection UI is live
