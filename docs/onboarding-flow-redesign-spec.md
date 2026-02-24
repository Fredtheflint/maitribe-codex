# Onboarding Flow Redesign (5 Steps)

## Product Intent
Create a calm first-run experience with one question per screen, low pressure, and immediate emotional value.

## Design Principles
- One question per screen
- Large, quiet typography
- Skip always available
- No pressure language
- Fast path to first meaningful response from Mai

## Step 1: Welcome

UI:
- Title: "Hey, ich bin Mai."
- Body copy (max 3 sentences):
  - "Ich bin keine App, die dich bewertet."
  - "Ich bin deine Begleiterin fuer Body, Mind, Soul und Spirit."
  - "Wir gehen Schritt fuer Schritt."
- CTA: `Weiter`
- Secondary: `Ueberspringen`

DB writes:
- none required

## Step 2: Name

UI:
- Prompt: "Wie soll ich dich nennen?"
- Single text input
- CTA: `Weiter`
- Secondary: `Ueberspringen`

Validation:
- min 1 char for save
- trim whitespace

DB writes:
```sql
update public.users
set name = :name,
    display_name = :name,
    updated_at = now()
where id = :user_id;
```

## Step 3: Language

UI:
- Prompt: "In welcher Sprache soll ich mit dir sprechen?"
- Dropdown: `DE, EN, ES, FR, IT, PT, AR`
- Preselect from browser locale
- CTA: `Weiter`
- Secondary: `Ueberspringen`

DB writes:
```sql
update public.users
set language = :language,
    updated_at = now()
where id = :user_id;
```

## Step 4: Identity (optional)

UI:
- Prompt: "Wer willst du sein?"
- Helper: "Beschreibe in einem Satz die Person, die du sein moechtest."
- Single textarea
- Primary: `Speichern`
- Secondary: `Spaeter`

DB writes if provided:
```sql
insert into public.identities (user_id, full_text, one_liner, sentences, is_active)
values (:user_id, :full_text, :one_liner, :sentences_json, true);
```

If skipping:
- no write

## Step 5: First Check-in

UI:
- 4 sliders only:
  - Body
  - Mind
  - Soul
  - Energy
- Optional note input
- CTA: `Check-in abschicken`

After submit:
- show first personalized reflection from Mai
- final line:
  - "Alles klar, ich bin fuer dich da. Immer wenn du mich brauchst."

DB writes:
```sql
insert into public.checkins (user_id, body, mind, soul, energy, note)
values (:user_id, :body, :mind, :soul, :energy, :note);
```

Then:
```sql
update public.users
set onboarding_completed = true,
    onboarding_step = 5,
    updated_at = now()
where id = :user_id;
```

## State Model

Local onboarding state:
```json
{
  "step": 1,
  "name": "",
  "language": "de",
  "identity": "",
  "checkin": { "body": 5, "mind": 5, "soul": 5, "energy": 5, "note": "" }
}
```

## Screen-to-Data Mapping
- Step 1 -> no write
- Step 2 -> `users.name`, `users.display_name`
- Step 3 -> `users.language`
- Step 4 -> `identities`
- Step 5 -> `checkins`, `users.onboarding_completed`

## Implementation Guide (index.html)

1. Keep one active `.onboard-step` at a time.
2. Persist each completed step with resilient write helpers.
3. On skip:
- advance UI step
- do not block flow
4. After step 5:
- call `submitCheckinFromScreen("onboard")`
- route to home
5. Add a completion guard:
- if user reloads mid-onboarding, resume at next incomplete step.

## UX Copy Notes
- Avoid "should" language
- Keep CTA verbs simple
- Always allow continuation despite partial data
