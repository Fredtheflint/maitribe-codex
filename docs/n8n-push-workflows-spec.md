# MaiTribe n8n Push Notification Workflows - Specification

Last updated: 2026-02-21
Status: Ready for import and credential mapping

## 1) Deliverables
Importable workflow JSON files:
- `/Users/freddy/Downloads/NEW PROJECTS/MAITRIBE Codex/n8n/workflows/push-workflow-1-morning-identity.json`
- `/Users/freddy/Downloads/NEW PROJECTS/MAITRIBE Codex/n8n/workflows/push-workflow-2-mindful-reminders.json`
- `/Users/freddy/Downloads/NEW PROJECTS/MAITRIBE Codex/n8n/workflows/push-workflow-3-checkin-followup.json`

## 2) Required Environment Variables in n8n
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `GEMINI_API_KEY`

Optional:
- `INTERNAL_WEBHOOK_SECRET` (only needed if you later expose webhook-triggered variants)

## 3) VAPID Key Generation Guide
MaiTribe currently sends push through Supabase Edge Function `send-push` using VAPID.

Generate keys:
```bash
npx web-push generate-vapid-keys
```

Expected output:
- Public Key
- Private Key

Set in Supabase project env:
- `VAPID_PUBLIC_KEY`
- `VAPID_PRIVATE_KEY`
- `VAPID_SUBJECT` (example: `mailto:hello@maitribe.ai`)

App setup:
- Put `VAPID_PUBLIC_KEY` in MaiTribe settings UI.
- User clicks "Register push notifications".
- Subscription JSON stored in `users.push_token`.

## 4) Workflow 1 - Morning Identity Reminder
Trigger:
- Cron every 5 minutes.
- SQL checks user-local time against `users.morning_reminder_time`.

Core SQL (from workflow):
```sql
with due_users as (
  select u.id as user_id, u.language, u.timezone, u.push_token, u.morning_reminder_time
  from public.users u
  where u.onboarding_completed = true
    and u.morning_reminder_enabled = true
    and u.push_token is not null
    and ((now() at time zone u.timezone)::time >= u.morning_reminder_time)
    and ((now() at time zone u.timezone)::time < (u.morning_reminder_time + interval '5 minutes'))
    and not exists (
      select 1
      from public.reminders r
      where r.user_id = u.id
        and r.type = 'morning_identity'
        and (r.scheduled_for at time zone u.timezone)::date = (now() at time zone u.timezone)::date
    )
)
select ...
```

Message logic:
- Rotations A-E:
  - A full identity
  - B one-liner + question
  - C body focus
  - D present anchor
  - E dream vision

Push payload:
```json
{
  "userId": "...",
  "subscription": {"endpoint": "..."},
  "title": "MaiTribe",
  "body": "...",
  "data": {"type": "morning_identity", "variation": "A"}
}
```

## 5) Workflow 2 - Mindful Reminders (3x Daily)
Trigger:
- Cron every 10 minutes.
- SQL selects users in local slots 10:00, 14:00, 19:00.

Core SQL (from workflow):
```sql
select u.id as user_id, u.language, u.timezone, u.push_token
from public.users u
where u.onboarding_completed = true
  and u.mindful_reminders_enabled = true
  and u.push_token is not null
  and extract(hour from (now() at time zone u.timezone)) in (10, 14, 19)
  and extract(minute from (now() at time zone u.timezone)) between 0 and 9
  and not exists (
    select 1
    from public.reminders r
    where r.user_id = u.id
      and r.type = 'mindful_reminder'
      and date_trunc('hour', r.scheduled_for at time zone u.timezone) = date_trunc('hour', now() at time zone u.timezone)
  );
```

Gemini prompt template:
```text
You are Mai. Generate exactly one short mindful reminder in English.
Style: warm, clear, present.
8-18 words. No emojis. No bullet points.
Avoid repeating these texts: {{recent_7d_reminders}}
Return only the final sentence.
```

German variant uses `du` form and same constraints.

No-repeat handling:
- Loads last 7 days `mindful_reminder` content.
- Normalizes generated text.
- If duplicate/empty, uses fallback text.

## 6) Workflow 3 - Check-in Follow-up (Low Scores)
Trigger:
- Cron every 15 minutes.

Core SQL (from workflow):
```sql
select c.id as checkin_id, c.user_id, c.body, c.mind, c.soul, c.energy, c.note, c.created_at,
       u.language, u.timezone, u.push_token
from public.checkins c
join public.users u on u.id = c.user_id
where c.created_at > now() - interval '75 minutes'
  and (c.body < 4 or c.mind < 4 or c.soul < 4)
  and u.push_token is not null
  and not exists (
    select 1
    from public.reminders r
    where r.user_id = c.user_id
      and r.variation_type = 'checkin_followup'
      and r.scheduled_for > c.created_at
      and r.scheduled_for < c.created_at + interval '2 hours'
  );
```

Gemini prompt template:
```text
You are Mai. Write a short caring follow-up after a difficult check-in.
Scores: Body {{body}}/10, Mind {{mind}}/10, Soul {{soul}}/10, Energy {{energy}}/10.
Optional note: {{note}}
Rules: 1-2 sentences, max 28 words, warm and non-clinical, no tips list, end with one gentle question.
Return final text only.
```

Insert behavior:
- Saves reminder as `type='custom'` with `variation_type='checkin_followup'`.

## 7) Push API Integration
All workflows call:
- `POST {{SUPABASE_URL}}/functions/v1/send-push`

Headers:
- `Authorization: Bearer {{SUPABASE_SERVICE_ROLE_KEY}}`
- `apikey: {{SUPABASE_SERVICE_ROLE_KEY}}`
- `Content-Type: application/json`

Body:
- `{ userId, subscription, title, body, data }`

## 8) Error Handling Strategy

## Missing push subscription
- Branch to skipped path.
- Insert reminder row with `sent=false` for observability.

## Gemini failure/quota/timeout
- `continueOnFail=true` on HTTP node.
- Fallback local template text used.
- Workflow still sends push if fallback available.

## Push failure (410/500)
- Mark `sent=false`.
- Keep row in `reminders` for retry analytics.
- Optional extension: clear invalid `users.push_token` when 410 detected.

## Database failure
- n8n execution logs capture failed insert/update.
- Recommend alerting via n8n error workflow.

## 9) Recommended Post-Import Checks
1. Import all 3 JSON workflows in n8n.
2. Attach Postgres credentials to each Postgres node.
3. Ensure env vars exist.
4. Run each workflow manually with test item.
5. Validate rows in `public.reminders`.
6. Validate push receipt on a subscribed test device.

## 10) Notes
- Workflows are designed for local n8n runner and Supabase backend.
- For production scale, move to queue-based throttling and segmented batch execution.
