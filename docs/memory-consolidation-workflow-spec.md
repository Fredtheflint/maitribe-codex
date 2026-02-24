# Memory Consolidation Workflow Spec (n8n)

## Objective
Prevent memory bloat and improve long-term relevance by weekly consolidation.

## Trigger
- Cron: weekly on Sunday at 03:00 UTC

## Step 1: select users with memory load
```sql
select user_id, count(*)::int as memory_count
from public.memories
group by user_id
having count(*) > 20;
```

## Step 2: load user memories
```sql
select id, content, category, importance, created_at
from public.memories
where user_id = $1
order by category, created_at;
```

## Step 3: Gemini consolidation prompt

### EN prompt
```text
You receive a memory list for one user.
Consolidate similar memories. Keep unique ones separate.
Increase importance for repeated patterns.
Delete outdated or irrelevant memories.

Rules:
- Keep at most 50 memories after consolidation.
- Preserve key details.
- If a goal has been achieved, transform from "plans" to "achieved".
- If an emotion is older than 4 weeks and not repeated, delete it.

Return JSON only:
{
  "keep": [{"id": "...", "reason": "unique"}],
  "merge": [{"ids": ["...", "..."], "merged_content": "...", "category": "...", "importance": 8}],
  "delete": [{"id": "...", "reason": "outdated"}]
}
```

### DE prompt
```text
Du bekommst eine Liste von Memories zu einem User.
Fasse aehnliche Memories zusammen. Behalte einzigartige Memories einzeln.
Erhoehe die Importance bei haeufigen Mustern.
Loesche veraltete oder irrelevante Memories.

Regeln:
- Maximal 50 Memories nach der Konsolidierung.
- Wichtigste Details behalten.
- Wenn ein Ziel erreicht wurde: von "plant" auf "hat erreicht" umstellen.
- Wenn eine Emotion aelter als 4 Wochen ist und sich nicht wiederholt hat: loeschen.

Antworte nur als JSON:
{
  "keep": [{"id": "...", "reason": "unique"}],
  "merge": [{"ids": ["...", "..."], "merged_content": "...", "category": "...", "importance": 8}],
  "delete": [{"id": "...", "reason": "outdated"}]
}
```

## Step 4: execute changes

Keep:
- no action

Delete:
```sql
delete from public.memories
where id = any($1::uuid[]);
```

Merge:
1. delete old ids
2. insert consolidated memory rows

Delete merge-ids:
```sql
delete from public.memories
where id = any($1::uuid[]);
```

Insert merged row:
```sql
insert into public.memories (user_id, content, category, importance, source, created_at)
values ($1, $2, $3, $4, 'consolidation', now());
```

## Safety gates
- If Gemini output fails JSON parse -> skip user, log error
- If merge payload empty -> keep all
- Never delete all memories for a user in one run unless explicit rule output includes keep=0 with valid merge coverage

## Logging recommendation
Create execution log table or write to n8n execution notes:
- user_id
- before_count
- after_count
- deleted_count
- merged_count
- timestamp
