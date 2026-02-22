# MaiTribe One-Page Execution Checklist

Last updated: 2026-02-21
Use this checklist for a clean rollout run (staging first, then production).

## 0) Scope for this run
- Deploy latest PWA to Netlify
- Validate Supabase config and auth redirects
- Validate n8n push workflows
- Keep Connect tables optional (recommended later)

## 1) Preflight (5-10 min)
- [ ] Confirm latest files exist:
  - `netlify.toml`
  - `_headers`
  - `_redirects`
  - `manifest.json`
  - `docs/n8n-import-runbook.md`
  - `docs/supabase-migration-runbook.md`
- [ ] Confirm Supabase project target (staging vs production)
- [ ] Create Supabase backup snapshot (production)
- [ ] Confirm n8n runtime env vars:
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `GEMINI_API_KEY`

## 2) Supabase Safe Checks (SQL)
```sql
select
  to_regclass('public.users') as users,
  to_regclass('public.checkins') as checkins,
  to_regclass('public.identities') as identities,
  to_regclass('public.reminders') as reminders;
```

```sql
select
  exists (select 1 from information_schema.tables where table_schema='public' and table_name='connect_profiles') as has_connect_profiles,
  exists (select 1 from information_schema.tables where table_schema='public' and table_name='matches') as has_matches;
```

- [ ] If doing astro-fields-now only, run the optional SQL from `docs/supabase-migration-runbook.md`
- [ ] If doing full Connect schema, run `supabase/connect_schema.sql` in staging first

## 3) Netlify Deploy (10-20 min)
- [ ] Deploy via Git or CLI
- [ ] Confirm app loads over HTTPS
- [ ] Confirm service worker file is reachable: `/sw.js`
- [ ] Confirm manifest is reachable: `/manifest.json`
- [ ] Confirm custom domain resolves (`app.maitribe.ai` recommended)

## 4) Supabase Auth Redirects (critical)
In Supabase Auth URL config:
- [ ] `Site URL` set to production app domain
- [ ] Redirect URLs include:
  - `https://app.maitribe.ai`
  - `https://app.maitribe.ai/index.html`
  - `http://localhost:8080`
  - `http://localhost:8080/index.html`

## 5) Push Readiness
- [ ] VAPID keys present in Supabase env:
  - `VAPID_PUBLIC_KEY`
  - `VAPID_PRIVATE_KEY`
  - `VAPID_SUBJECT`
- [ ] Test user has granted browser push permission
- [ ] `users.push_token` is non-null for test user

Check:
```sql
select id, push_token, timezone, morning_reminder_enabled, mindful_reminders_enabled
from public.users
where id = '<TEST_USER_UUID>';
```

## 6) n8n Import + Manual Workflow Tests
- [ ] Import 3 workflows:
  - `n8n/workflows/push-workflow-1-morning-identity.json`
  - `n8n/workflows/push-workflow-2-mindful-reminders.json`
  - `n8n/workflows/push-workflow-3-checkin-followup.json`
- [ ] Attach Postgres credential to all Postgres nodes
- [ ] Keep workflows inactive
- [ ] Run manual execute for each workflow once
- [ ] Verify push arrives on test device
- [ ] Verify `public.reminders` rows inserted

Check:
```sql
select user_id, type, variation_type, sent, sent_at, created_at
from public.reminders
where user_id = '<TEST_USER_UUID>'
order by created_at desc
limit 20;
```

## 7) Gemini Migration Guardrail
- [ ] Prefer `gemini-2.5-flash` in active workflows/code
- [ ] If quota/rate limit hits, fallback text path still works
- [ ] No user-facing hard failure on Gemini error

## 8) Smoke Test (App)
- [ ] Magic link login works on production domain
- [ ] Onboarding completes without timeout
- [ ] Check-in save works
- [ ] Chat message send/receive works
- [ ] Settings save works
- [ ] Push registration works

## 9) Go/No-Go Criteria
Go only if all are true:
- [ ] Auth stable
- [ ] DB writes stable
- [ ] At least 1 successful push from each workflow path
- [ ] No blocking errors in n8n execution logs

## 10) Rollback Plan (quick)
- [ ] Netlify: redeploy previous known-good deploy
- [ ] n8n: deactivate new workflows
- [ ] Supabase: if needed, run rollback block from `docs/supabase-migration-runbook.md`
- [ ] Keep incident notes: timestamp, error, fix, owner

## 11) Recommended rollout order
1. Staging end-to-end pass
2. Production deploy
3. Production manual push test (single user)
4. Activate WF1
5. Activate WF2
6. Activate WF3
7. Monitor 24h
