# Error Handling & Offline Mode Concept

## Goal
Keep MaiTribe usable and emotionally safe during offline states, API failures, and backend issues.

## 1) Offline Behavior by Surface

## Home
- Render from last known cached profile/identity/check-in insight.
- Show unobtrusive status chip:
  - DE: `Offline - letzte Daten angezeigt`
  - EN: `Offline - showing last synced data`

## Check-in
- Sliders always usable offline.
- Save check-in locally (queue entry).
- User message:
  - DE: `Mai ist gerade offline - dein Check-in wurde gespeichert und Mai antwortet, sobald du wieder online bist.`
  - EN: `Mai is offline right now - your check-in is saved and Mai will respond once you're back online.`

## Chat
- User message appears immediately in chat UI.
- Message stored in local queue with `status: pending`.
- On reconnect, queued messages are sent in order.
- Pending marker:
  - DE: `Wird gesendet...`
  - EN: `Sending...`

## Identity
- Edits allowed offline.
- Save local draft + queue sync action.
- On reconnect, sync to Supabase and clear draft marker.

## 2) API Error States

## Gemini 429
- DE: `Mai braucht kurz eine Pause. Versuch es in ein paar Minuten nochmal.`
- EN: `Mai needs a short pause. Please try again in a few minutes.`

## Gemini 500/5xx
- DE: `Da ist was schiefgegangen. Kein Stress - probier es gleich nochmal.`
- EN: `Something went wrong. No stress - please try again in a moment.`

## Supabase errors
- DE: `Verbindungsproblem. Deine Daten sind sicher - sie werden synchronisiert, sobald die Verbindung steht.`
- EN: `Connection issue. Your data is safe - it will sync once you're connected again.`

## No internet
- DE: `Du bist offline. Kein Problem - Mai ist gleich wieder da.`
- EN: `You are offline. No problem - Mai will be back in a moment.`

## 3) Suggested Code Patterns

## A) Unified guard wrapper
```js
async function withAppGuard(task, fallback, contextLabel) {
  try {
    return await task();
  } catch (error) {
    console.error("[MaiTribe] " + contextLabel + " error:", error);
    return fallback;
  }
}
```

## B) Queue-first writes
```js
function enqueueSync(item) {
  const queue = JSON.parse(localStorage.getItem("maitribe.sync.queue") || "[]");
  queue.push({ ...item, queuedAt: new Date().toISOString() });
  localStorage.setItem("maitribe.sync.queue", JSON.stringify(queue));
}
```

## C) Reconnect flush
```js
window.addEventListener("online", flushSyncQueue);
async function flushSyncQueue() {
  // process queue FIFO, remove only after successful write
}
```

## D) Cached read model
```js
function setCached(key, data) { localStorage.setItem(key, JSON.stringify(data)); }
function getCached(key, fallback) { try { return JSON.parse(localStorage.getItem(key) || ""); } catch { return fallback; } }
```

## 4) UX Messaging Matrix

| State | Placement | DE | EN |
|---|---|---|---|
| Offline detected | global status | Du bist offline. Kein Problem - Mai ist gleich wieder da. | You are offline. No problem - Mai will be back in a moment. |
| Check-in queued | check-in status | Check-in lokal gespeichert. Sync folgt automatisch. | Check-in saved locally. Sync will happen automatically. |
| Chat queued | message bubble footer | Wird gesendet... | Sending... |
| Gemini rate limit | chat response fallback | Mai braucht kurz eine Pause. Versuch es in ein paar Minuten nochmal. | Mai needs a short pause. Please try again in a few minutes. |
| Backend failure | toast/status | Verbindungsproblem. Deine Daten sind sicher - sie werden synchronisiert, sobald die Verbindung steht. | Connection issue. Your data is safe - it will sync once you're connected again. |

## 5) Sync Priority

Order on reconnect:
1. Profile updates
2. Identity edits
3. Check-ins
4. Chat messages
5. Derived writes (events/reminders)

Rationale:
- Preserve user identity and profile state first
- Then emotional journal/check-in continuity

## 6) Acceptance Criteria
- App remains usable offline for core journaling/check-in flow
- No user-generated text is lost across reload
- Pending operations retry automatically after reconnect
- Error copy stays calm, non-technical, bilingual
