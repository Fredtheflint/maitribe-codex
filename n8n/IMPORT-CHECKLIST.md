# MaiTribe n8n Import-Reihenfolge + Credential-Mapping

## 1) Import-Reihenfolge (empfohlen)
1. `workflow-1-morning-identity-reminder.json`
2. `workflow-2-mindful-reminders.json`
3. `workflow-3-event-followup.json`
4. `workflow-4-conversation-summarizer.json`

Dateien liegen unter:
- `/Users/freddy/Downloads/NEW PROJECTS/MAITRIBE Codex/n8n/workflows/workflow-1-morning-identity-reminder.json`
- `/Users/freddy/Downloads/NEW PROJECTS/MAITRIBE Codex/n8n/workflows/workflow-2-mindful-reminders.json`
- `/Users/freddy/Downloads/NEW PROJECTS/MAITRIBE Codex/n8n/workflows/workflow-3-event-followup.json`
- `/Users/freddy/Downloads/NEW PROJECTS/MAITRIBE Codex/n8n/workflows/workflow-4-conversation-summarizer.json`

## 2) Pflicht-Variablen in n8n (Environment)
Setze diese ENV-Variablen in n8n:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `GEMINI_API_KEY`
- `INTERNAL_WEBHOOK_SECRET` (für WF3)

Hinweis:
- WF1/WF2/WF3 rufen `POST $SUPABASE_URL/functions/v1/send-push` auf.
- Die Edge Function `send-push` muss deployed sein und VAPID private key serverseitig halten.

## 3) Credential-Mapping

### A. Postgres Credential (für alle Postgres-Nodes)
Typ: `Postgres`
- Host: `<your-supabase-db-host>` (z. B. `db.<project-ref>.supabase.co`)
- Port: `5432`
- Database: `postgres`
- User: `postgres`
- Password: dein DB Password
- SSL: `require`

Dieses Credential in **allen** `Postgres`-Nodes der 4 Workflows auswählen.

### B. HTTP Nodes
Die HTTP Nodes nutzen ENV-Expressions (`$env...`) und brauchen kein separates Credential, solange ENV gesetzt ist.

## 4) Workflow-spezifische Checks

### WF1 Morning Identity Reminder
- Cron: alle 5 Minuten.
- Prüfe, dass `users.morning_reminder_enabled = true` und `morning_reminder_time` gesetzt ist.
- Prüfe Push-Edge-Function erreichbar.

### WF2 Mindful Reminders
- Cron: alle 10 Minuten.
- Prüfe `users.mindful_reminders_enabled = true` und `mindful_reminder_count` 2-5.
- Prüfe Gemini API Key gesetzt.

### WF3 Event Follow-Up
- Webhook Path: `/webhook/maitribe/event-followup` (oder `/webhook-test/...` im Testmodus).
- Header beim Aufruf setzen: `x-internal-secret: <INTERNAL_WEBHOOK_SECRET>`
- Payload: `{ "event_id": "<uuid>" }`

### WF4 Conversation Summarizer
- Cron: alle 10 Minuten.
- Summarisiert nur `conversations.is_active = true` und `updated_at < now() - 30 minutes`.

## 5) Aktivierungsreihenfolge
1. WF4 aktivieren (niedriges Risiko, nur Summaries)
2. WF1 aktivieren
3. WF2 aktivieren
4. WF3 aktivieren (erst nach End-to-End Event-Test)

## 6) Schnelltests nach Import
1. WF1 manuell ausführen -> neue Zeile in `public.reminders` mit `type='morning_identity'`.
2. WF2 manuell ausführen -> neue Zeile mit `type='mindful_reminder'`.
3. WF3 Webhook mit gültigem Secret + Event-ID aufrufen -> `events.followup_sent` wird aktualisiert.
4. WF4 manuell ausführen -> `conversations.summary/topics/mood` gesetzt.

## 7) Typische Fehlerquellen
- Falsches Postgres Credential (RLS/Permission/SSL).
- Fehlende ENV-Variablen in n8n Runtime.
- `send-push` Edge Function nicht deployed oder ohne Service-Auth konfiguriert.
- `INTERNAL_WEBHOOK_SECRET` mismatch bei WF3.
