# MaiTribe n8n Import Runbook

Last updated: 2026-02-21  
Scope: Import and verify push workflows

Files covered:
- `/Users/freddy/Downloads/NEW PROJECTS/MAITRIBE Codex/n8n/workflows/push-workflow-1-morning-identity.json`
- `/Users/freddy/Downloads/NEW PROJECTS/MAITRIBE Codex/n8n/workflows/push-workflow-2-mindful-reminders.json`
- `/Users/freddy/Downloads/NEW PROJECTS/MAITRIBE Codex/n8n/workflows/push-workflow-3-checkin-followup.json`

## 1) Import in n8n (UI)
1. Open n8n UI.
2. Go to `Workflows`.
3. Click `Import from File`.
4. Import these 3 files one by one:
- `push-workflow-1-morning-identity.json`
- `push-workflow-2-mindful-reminders.json`
- `push-workflow-3-checkin-followup.json`
5. Save each workflow after import.
6. Keep each workflow `Inactive` until manual tests pass.

## 2) Credential + Env Mapping (Node by Node)

## Important distinction
- `Postgres` nodes use an n8n **Postgres credential**.
- `HTTP Request` nodes in these workflows use **env vars** (`$env...`) for Supabase/Gemini.
- VAPID keys are **not entered in n8n UI** for these workflows; they are read by Supabase Edge Function `send-push`.

## 2.1 Create Postgres credential in n8n
In n8n UI:
1. `Credentials` -> `New` -> `Postgres`.
2. Fill from Supabase DB connection string:
- Host
- Port (`5432`)
- Database (`postgres`)
- User
- Password
- SSL/TLS enabled
3. Save as e.g. `Supabase Postgres`.
4. Open each workflow and assign this credential to every `Postgres` node.

Where exactly in UI per node:
1. Open workflow.
2. Click a `Postgres` node.
3. In the right panel, open `Credentials`.
4. Select `Supabase Postgres`.

## 2.2 Environment variables required in n8n runtime
Set before starting n8n process (or in your n8n host env config):
- `SUPABASE_URL=https://<project-ref>.supabase.co`
- `SUPABASE_SERVICE_ROLE_KEY=<service-role-key>`
- `GEMINI_API_KEY=<gemini-key>`

Optional:
- `INTERNAL_WEBHOOK_SECRET=<secret>` (not required by these 3 cron workflows)

Where exactly to set:
- Self-hosted n8n: in host/container environment (`.env`, Docker env, systemd env).
- n8n UI does not store `$env.*` keys inside workflow nodes; nodes only read already-available runtime env.

## 2.3 VAPID keys (where to set)
For this architecture, VAPID is used by Supabase Edge Function `send-push`, not by n8n directly.

Set in Supabase project env:
- `VAPID_PUBLIC_KEY`
- `VAPID_PRIVATE_KEY`
- `VAPID_SUBJECT` (e.g. `mailto:hello@maitribe.ai`)

Then in MaiTribe app UI:
- Paste `VAPID_PUBLIC_KEY` in app settings.
- Click "Register push notifications" so `users.push_token` gets populated.

Where exactly in n8n UI:
- Nowhere. No n8n node in these workflows requires direct VAPID input.

## 2.4 Node mapping by workflow

WF1 `MaiTribe - Push WF1 Morning Identity Reminder`
- Postgres nodes (need Postgres credential):
- `Select Due Users + Identity`
- `Insert Reminder (Sent Path)`
- `Insert Reminder (Skipped Path)`
- HTTP nodes using env vars:
- `Send Push via Edge Function` -> `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`

WF2 `MaiTribe - Push WF2 Mindful Reminders`
- Postgres nodes:
- `Select Due Mindful Users`
- `Load Recent 7 Days`
- `Insert Reminder (Sent Path)`
- `Insert Reminder (Skipped Path)`
- HTTP nodes:
- `Gemini Mindful Text` -> `GEMINI_API_KEY`
- `Send Push via Edge Function` -> `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`

WF3 `MaiTribe - Push WF3 Check-in Follow-up`
- Postgres nodes:
- `Select Low Check-ins`
- `Insert Reminder (Sent Path)`
- `Insert Reminder (Skipped Path)`
- HTTP nodes:
- `Gemini Follow-up Text` -> `GEMINI_API_KEY`
- `Send Push via Edge Function` -> `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`

## 3) Manual Test Before Activating Cron

## 3.1 General test prep (SQL)
Run in Supabase SQL Editor (replace `<USER_UUID>`):
```sql
-- check baseline user
select id, onboarding_completed, timezone, push_token,
       morning_reminder_enabled, morning_reminder_time,
       mindful_reminders_enabled, event_followup_enabled
from public.users
where id = '<USER_UUID>';
```

If `push_token` is null, register push once from app settings.

## 3.2 WF1 test (Morning Identity)
Seed test state:
```sql
update public.users
set onboarding_completed = true,
    morning_reminder_enabled = true,
    morning_reminder_time = (now() at time zone timezone)::time
where id = '<USER_UUID>';

insert into public.identities (user_id, full_text, one_liner, sentences, language, is_active, version)
values (
  '<USER_UUID>',
  'I move through this day with calm and honesty.',
  'I move through this day with calm and honesty.',
  '["I move through this day with calm and honesty."]'::jsonb,
  'en',
  true,
  1
)
on conflict do nothing;
```

Manual execute in n8n:
1. Open WF1.
2. Click `Execute workflow`.
3. Verify:
- Push sent on test device.
- New row in `public.reminders` with `type='morning_identity'`.

Validation SQL:
```sql
select user_id, type, content, variation_type, sent, sent_at, scheduled_for
from public.reminders
where user_id = '<USER_UUID>'
  and type = 'morning_identity'
order by created_at desc
limit 5;
```

## 3.3 WF2 test (Mindful)
Seed test state:
```sql
update public.users
set onboarding_completed = true,
    mindful_reminders_enabled = true
where id = '<USER_UUID>';
```

Manual execute WF2 and verify:
- Push sent.
- Reminder row with `type='mindful_reminder'`.

Validation SQL:
```sql
select user_id, type, content, variation_type, sent, sent_at
from public.reminders
where user_id = '<USER_UUID>'
  and type = 'mindful_reminder'
order by created_at desc
limit 5;
```

## 3.4 WF3 test (Check-in Follow-up)
Seed low check-in:
```sql
insert into public.checkins (user_id, body, mind, soul, energy, note)
values ('<USER_UUID>', 3, 6, 2, 5, 'I feel overloaded today');
```

Manual execute WF3 and verify:
- Push sent.
- Reminder row with `type='custom'` and `variation_type='checkin_followup'`.

Validation SQL:
```sql
select user_id, type, variation_type, content, sent, sent_at
from public.reminders
where user_id = '<USER_UUID>'
  and variation_type = 'checkin_followup'
order by created_at desc
limit 5;
```

## 4) Activation Sequence
1. Import workflows.
2. Attach Postgres credentials.
3. Ensure env vars are loaded.
4. Run manual tests for all 3 workflows.
5. Activate WF1.
6. Activate WF2.
7. Activate WF3.

## 5) Troubleshooting

## `CORS` errors on `send-push`
Symptoms:
- HTTP node returns preflight/CORS-related error.

Checks:
- Ensure `send-push` function returns CORS headers.
- Ensure request includes `Authorization` and `apikey` headers.
- Validate `SUPABASE_URL` points to correct project.

## Auth errors (`401/403`)
Symptoms:
- `send-push` call unauthorized.

Checks:
- Verify `SUPABASE_SERVICE_ROLE_KEY` in n8n env.
- Confirm key belongs to same project as `SUPABASE_URL`.

## Gemini quota / rate limit
Symptoms:
- HTTP node returns 429 / API error.

Behavior:
- Workflows fallback to local template text where implemented.

Actions:
- Increase quota / move to paid plan.
- Add retry/backoff branch in n8n if needed.

## Push permission denied
Symptoms:
- No push despite workflow success.

Checks:
- User must grant notification permission in browser/device.
- `users.push_token` must be non-null and valid JSON.
- If endpoint expired, refresh subscription from app settings.

## No rows selected in workflow
Symptoms:
- Workflow runs but does nothing.

Checks:
- User flags enabled (`onboarding_completed`, reminder toggles).
- Timezone and local-time slot conditions currently match.
- Test by temporarily widening SQL time window.
