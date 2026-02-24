# Evidence Bank: Schema, UI Concept, and Prompt Integration

## Goal
Make identity growth visible through daily micro-evidence.

Example:
- Identity: "Ich bin jemand der mutig handelt."
- Evidence: "Heute habe ich im Meeting meine Meinung gesagt."

## 1) Database Scope

Migration file:
- `/Users/freddy/Downloads/NEW PROJECTS/MAITRIBE Codex/supabase/migration_2026_02_23_evidence_bank.sql`

Table:
- `public.evidence`
  - `id`
  - `user_id`
  - `identity_id`
  - `content`
  - `category` (`body|mind|soul|spirit`)
  - `energy_level` (`1..5`)
  - `source` (`manual|checkin|chat|push_response`)
  - `created_at`
  - `updated_at`

RLS:
- select/insert/update/delete only for own rows via `auth.uid() = user_id`

## 2) UI Concept

## Home card enhancement
- Existing card: "Deine Identitaet"
- Add secondary line:
  - `3 Beweise diese Woche`

Source query:
```sql
select count(*)::int as weekly_count
from public.evidence
where user_id = :user_id
  and created_at >= now() - interval '7 days';
```

## Evidence Bank screen

Entry point:
- Tap on identity card or the "X Beweise diese Woche" label

Layout:
1. Header: `Evidence Bank`
2. Weekly summary chips:
  - `Diese Woche: 3`
  - `Kategorie-Top: Mind`
3. Chronological list (newest first):
  - date
  - content
  - category badge
  - optional energy chip
4. Composer at bottom:
  - input: `Was hast du heute bewiesen?`
  - category selector: `Body/Mind/Soul/Spirit`
  - optional energy slider: `1..5`
  - button: `Beweis speichern`

## Wireframe (text)
```text
[< Zurueck]  Evidence Bank
Diese Woche: 3   Top: Mind

23 Feb  | "Heute habe ich im Meeting meine Meinung gesagt."
         [Mind] [Energie 3]

22 Feb  | "Ich habe mich fuer den Kurs angemeldet."
         [Soul] [Energie 4]

20 Feb  | "Ich habe Nein gesagt, als ich ueberfordert war."
         [Spirit] [Energie 2]

-----------------------------------
Was hast du heute bewiesen?
[_________________________________]
[Body] [Mind] [Soul] [Spirit]
Energie: (1)---(5)
[Beweis speichern]
```

## UX behavior
- Save success:
  - optimistic insert
  - append to list immediately
  - update weekly counter in home
- Empty state:
  - `Noch kein Beweis gespeichert. Ein kleiner Moment reicht.`
- Validation:
  - content min length 3, max length 280
  - category optional
  - energy optional

## 3) System Prompt Addition (Mai + Evidence Bank)

Add to `buildSystemPrompt(context)` after identity context:

### DE snippet
```text
EVIDENCE BANK KONTEXT:
- Weekly evidence count: {evidence_week_count}
- Letzter Beweis: "{evidence_last_content}" (falls vorhanden)

NUTZUNG:
- Wenn passend, erinnere kurz an bereits gesammelte Beweise.
- Formulierung warm und konkret, nie manipulierend.
- Kein Druck, kein schlechtes Gewissen.
- Wenn keine Beweise vorhanden sind, lade zu einem kleinen Beweis fuer heute ein.
Beispiel:
"Du hast diese Woche schon {evidence_week_count} Beweise gesammelt. Das letzte war: {evidence_last_content}. Das zaehlt."
```

### EN snippet
```text
EVIDENCE BANK CONTEXT:
- Weekly evidence count: {evidence_week_count}
- Latest evidence: "{evidence_last_content}" (if present)

USAGE:
- Reference evidence only when contextually helpful.
- Keep tone warm and grounded, never pushy.
- No guilt framing.
- If no evidence exists, invite one tiny proof for today.
Example:
"You already collected {evidence_week_count} proof moments this week. The latest was: {evidence_last_content}. That counts."
```

## 4) Context Query Add-on

Extend user context loader:
```sql
with latest_evidence as (
  select content, created_at
  from public.evidence
  where user_id = :user_id
  order by created_at desc
  limit 1
),
weekly_count as (
  select count(*)::int as cnt
  from public.evidence
  where user_id = :user_id
    and created_at >= now() - interval '7 days'
)
select
  (select cnt from weekly_count) as evidence_week_count,
  (select content from latest_evidence) as evidence_last_content;
```

## 5) Chat Behavior Rules
- If user is discouraged:
  - cite one real evidence moment (if available)
- If user asks "I did nothing today":
  - suggest capturing micro-proof ("I paused before reacting", "I asked for help")
- Avoid repetition:
  - do not repeat the same evidence sentence multiple turns in a row
