# MaiTribe Codex

## Architektur
- Single-File PWA: `index.html` (~3500 lines)
- Backend: Supabase (Auth + PostgreSQL + RLS)
- AI: Google Gemini 2.5 Flash via REST API
- Hosting: Netlify (auto-deploy from GitHub `main`)
- Notifications: planned via n8n (partially specified, not fully live)

## Datenbank-Tabellen
- `users` (`id`, `name`, `display_name`, `email`, `language`, `onboarding_completed`, reminder flags/settings)
- `identities` (`id`, `user_id`, `full_text`, `one_liner`, `sentences`, `is_active`, `answers`)
- `conversations` (`id`, `user_id`, `title`, `language`, `summary`, `topics`)
- `messages` (`id`, `user_id`, `conversation_id`, `role`, `content`)
- `checkins` (`id`, `user_id`, `body`, `mind`, `soul`, `energy`, `note`)
- `events` (`id`, `user_id`, `type/source`, `event_time`, `data`)
- `reminders` (`id`, `user_id`, `type`, `scheduled_for`, `content`, `sent`)
- `astro_transits` (`id`, `user_id`, `transit_data`, `daily_insight`)
- `waitlist` (`id`, `email`, `created_at`)

## RLS Policies
All core tables are RLS-enabled with `auth.uid()`-scoped access.
Project currently uses ~20 active policies across SELECT/INSERT/UPDATE (table dependent).

## Wichtige Funktionen
- `buildSystemPrompt(context)` — main chat system prompt + user context
- `buildCheckinPrompt(args)` — check-in reflection prompt from slider scores
- `callGeminiRaw(promptText, maxOutputTokens)` — low-level Gemini helper with logs
- `callAI(options, retryCount)` — Gemini wrapper with fallback and retry behavior
- `ensureUserProfile(user)` — create/update user row after auth

## Gotchas
- Prefer direct UTF-8 in strings for multilingual prompts; avoid mixing escaped/unescaped styles in the same prompt block.
- Gemini API: keep `maxOutputTokens >= 1024` as baseline; chat path uses `2048`.
- Supabase magic link redirect must include active app URL (localhost for local, Netlify domain for prod).
- Service worker may serve stale cache; use `?no_sw=1&v=XXXX` during debugging.
- Template literals in long prompts: avoid accidental backticks or `${...}` collisions.

## Dev Workflow
1. Plan mode before larger changes
2. Keep changes scoped per feature/fix
3. Run syntax check after `index.html` edits:
   `awk '/<script>/{flag=1;next}/<\/script>/{if(flag){flag=0;exit}}flag' index.html > /tmp/check.js && node --check /tmp/check.js`
4. Commit and deploy:
   `git push origin main && netlify deploy --prod --dir=.`
