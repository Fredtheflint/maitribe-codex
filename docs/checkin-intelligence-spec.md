# Check-in Intelligence Spec

## Goal
Turn repeated check-ins into gentle pattern awareness, not clinical alarms.

## Core Model
`checkin + history + memory -> pattern recognition -> softer, contextual reflection`

## Table
Migration file:
- `/Users/freddy/Downloads/NEW PROJECTS/MAITRIBE Codex/supabase/migration_2026_02_24_checkin_patterns.sql`

Supported pattern types:
- `declining_trend`
- `improving_trend`
- `recurring_low`
- `energy_correlation`
- `weekday_pattern`
- `body_mind_disconnect`

## Pattern Detection Logic (JavaScript)
Use after each successful check-in insert.

```js
async function detectCheckinPatterns(supabase, userId, currentCheckin) {
  const { data: history } = await supabase
    .from("checkins")
    .select("body, mind, soul, energy, created_at")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(14);

  if (!history || history.length < 3) return [];

  const dims = ["body", "mind", "soul", "energy"];
  const patterns = [];

  // Pattern 1: Declining trend over last 3 check-ins
  for (const dim of dims) {
    const last3 = history.slice(0, 3).map((c) => Number(c[dim]));
    if (last3[0] < last3[1] && last3[1] < last3[2]) {
      patterns.push({
        pattern_type: "declining_trend",
        description: `${dim} is declining across the last 3 check-ins (${last3[2]}->${last3[1]}->${last3[0]})`,
        data: { dimension: dim, values: last3, trend: "declining" }
      });
    }
  }

  // Pattern 2: Recurring low in last 7
  for (const dim of dims) {
    const lowCount = history.slice(0, 7).filter((c) => Number(c[dim]) <= 3).length;
    if (lowCount >= 3) {
      patterns.push({
        pattern_type: "recurring_low",
        description: `${dim} was low (<=3) ${lowCount} times in the last 7 check-ins`,
        data: { dimension: dim, low_count: lowCount, period_checkins: 7 }
      });
    }
  }

  // Pattern 3: Body-Mind disconnect in current check-in
  const diff = Math.abs(Number(currentCheckin.body) - Number(currentCheckin.mind));
  if (diff >= 4) {
    patterns.push({
      pattern_type: "body_mind_disconnect",
      description: `Large body/mind gap (body ${currentCheckin.body}, mind ${currentCheckin.mind})`,
      data: { body: currentCheckin.body, mind: currentCheckin.mind, diff }
    });
  }

  // Optional Pattern 4: Improving trend over last 3
  for (const dim of dims) {
    const last3 = history.slice(0, 3).map((c) => Number(c[dim]));
    if (last3[0] > last3[1] && last3[1] > last3[2]) {
      patterns.push({
        pattern_type: "improving_trend",
        description: `${dim} is improving across the last 3 check-ins (${last3[2]}->${last3[1]}->${last3[0]})`,
        data: { dimension: dim, values: last3, trend: "improving" }
      });
    }
  }

  // Persist
  for (const p of patterns) {
    await supabase.from("checkin_patterns").insert({
      user_id: userId,
      pattern_type: p.pattern_type,
      description: p.description,
      data: p.data
    });
  }

  return patterns;
}
```

## Prompt Addition for Check-in Reflection

Append this block to `buildCheckinPrompt(args)` when patterns exist.

### DE
```text
ERKANNTE MUSTER:
{pattern_lines}

Wenn du Muster erwaehnst, dann behutsam. Nicht alarmierend, nicht klinisch.
Beispiel:
"Mir faellt auf, dass dein Soul-Wert die letzten Tage runtergeht. Beschaeftigt dich etwas?"
"Dein Koerper sagt 8, aber dein Kopf sagt 3 - das ist ein interessanter Kontrast. Was steckt da dahinter?"
```

### EN
```text
DETECTED PATTERNS:
{pattern_lines}

If you mention patterns, do it gently. Not alarming, not clinical.
Example:
"I notice your soul score has been drifting down over the last days. Is something weighing on you?"
"Your body says 8 but your mind says 3 - that contrast feels important. What do you think is behind it?"
```

## Retrieval Query for Prompt Context
```sql
select pattern_type, description, data, detected_at
from public.checkin_patterns
where user_id = :user_id
order by detected_at desc
limit 5;
```

## UX Rules
- Mention max 1 pattern per reflection.
- No diagnostic wording.
- No deterministic statements.
- If user rejects pattern interpretation, drop it immediately.

## QA Cases
- 3 descending scores -> one declining pattern created
- 3 lows in 7 -> recurring_low created
- body/mind delta >= 4 -> disconnect created
- reflection remains under 80 words and calm tone
