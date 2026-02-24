# Daily Calibration: Schema + UI + Prompt Integration

## Feature Goal
Every morning, the user chooses how Mai should show up today.

Modes:
- `soft` (holding): extra gentle, validating, no pressure
- `clear` (sorting): clarifying questions, structured thinking
- `pushy` (lovingly direct): more challenge, honest direction, identity push
- `silent` (reminder-only): only evening proof reminder, otherwise quiet

## 1) Schema

Migration:
- `/Users/freddy/Downloads/NEW PROJECTS/MAITRIBE Codex/supabase/migration_2026_02_23_daily_calibration.sql`

Fields:
- `users.daily_mode text default 'soft'`
- `users.daily_mode_set_at timestamptz`

Allowed values:
- `soft`, `clear`, `pushy`, `silent`

## 2) UI Concept

## Morning Calibration Surface
- Show once on first app open each day.
- Presentation: modal or bottom sheet above home.
- 4 full-width cards with icon + title + one-line explanation.

Card copy example (DE):
- `SOFT` - "Heute bitte sanft. Mehr halten, weniger fordern."
- `CLEAR` - "Hilf mir zu sortieren. Stell klare Fragen."
- `PUSHY` - "Du darfst mich heute liebevoll fordern."
- `SILENT` - "Heute moechte ich Ruhe. Nur Abend-Reminder."

Interactions:
- Tap card -> immediate selection highlight
- `Speichern` CTA commits choice
- Optional `Erinnern` secondary action if user closes without choosing

## Home Badge
- Add small badge under greeting:
  - `Heute: SOFT`
  - color-coded by mode

## Settings
- Add `Daily mode` selector to settings for manual override.
- Change here updates `daily_mode` and `daily_mode_set_at`.

## 3) Data Flow

Morning open:
1. App checks local date vs. last shown date
2. If not shown today -> show calibration sheet
3. On selection:
```sql
update public.users
set daily_mode = :mode,
    daily_mode_set_at = now(),
    updated_at = now()
where id = :user_id;
```
4. Cache locally for same-day UX:
- `localStorage.maitribe.daily_mode_today`
- `localStorage.maitribe.daily_mode_date`

## 4) Prompt Additions (DE + EN)

Append to `buildSystemPrompt(context)` after user context is loaded:

### DE
```text
TAGESEINSTELLUNG: SOFT
Heute ist ein sanfter Tag. Sei besonders einfuehlsam, stelle keine Forderungen, validiere mehr als sonst. Wenn der User nichts tun will, ist das okay.
```

```text
TAGESEINSTELLUNG: CLEAR
Heute ist ein Klarheits-Tag. Hilf beim Sortieren. Stelle fokussierte, klaerende Fragen und bring Struktur in Gedankenchaos. Bleib warm, aber praezise.
```

```text
TAGESEINSTELLUNG: PUSHY
Heute darf Mai herausfordern. Sei liebevoll direkt. "Du weisst was du tun musst" ist erlaubt. Push Richtung Identity-Proof. Aber nie respektlos.
```

```text
TAGESEINSTELLUNG: SILENT
Heute braucht der User Ruhe. Keine zusaetzlichen Impulse, kein Coaching-Druck. Antworte nur wenn der User aktiv schreibt, dann kurz und respektvoll.
```

### EN
```text
DAILY MODE: SOFT
Today is a gentle day. Be especially validating, make no demands, and prioritize emotional safety. If the user does not want action, that is okay.
```

```text
DAILY MODE: CLEAR
Today is a clarity day. Help organize thoughts with focused questions and simple structure. Stay warm, but be precise.
```

```text
DAILY MODE: PUSHY
Today Mai may challenge the user lovingly. Direct language is allowed. Push toward identity-proof and concrete action, never disrespectfully.
```

```text
DAILY MODE: SILENT
Today the user wants quiet. No extra nudges or pressure. Respond only when the user initiates, and keep it brief and respectful.
```

## 5) Implementation Guide for `buildSystemPrompt()`

1. Extend context query to include:
- `users.daily_mode`
- `users.daily_mode_set_at`

2. Map mode to prompt append:
```js
const mode = (user.daily_mode || "soft").toLowerCase();
prompt += "\n\n=== DAILY CALIBRATION ===\n" + getDailyModeInstruction(mode, langCode);
```

3. Add helper:
```js
function getDailyModeInstruction(mode, langCode) {
  // return localized block from the snippets above
}
```

4. n8n integration:
- For `silent`, skip non-evening workflows.
- For `pushy`, allow stronger proactive reminders within cap rules.

## 6) QA Checklist
- Morning sheet appears once per day
- Mode persists after reload
- Home badge updates instantly
- Settings change overrides current mode
- Prompt behavior changes per mode in live chat
