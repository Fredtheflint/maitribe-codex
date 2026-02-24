# Push Notification System - Technical Spec (PWA)

## Architecture
`n8n Cron -> Supabase (user + memory + identity context) -> Gemini message generation -> Web Push delivery`

## Components

## 1) Service Worker (`sw.js`) handlers
```js
self.addEventListener("push", function(event) {
  const data = event.data ? event.data.json() : {};
  const options = {
    body: data.body || "Mai hat etwas fuer dich.",
    icon: "/icons/icon-192x192.svg",
    badge: "/icons/icon-72x72.svg",
    tag: data.tag || "mai-notification",
    data: { url: data.url || "/index.html" },
    actions: data.actions || []
  };
  event.waitUntil(
    self.registration.showNotification(data.title || "MaiTribe", options)
  );
});

self.addEventListener("notificationclick", function(event) {
  event.notification.close();
  event.waitUntil(clients.openWindow(event.notification.data.url || "/index.html"));
});
```

## 2) Frontend subscription flow
```js
async function subscribeToPush(currentUserId, vapidPublicKey, supabase) {
  if (!("PushManager" in window) || !("serviceWorker" in navigator)) return null;

  const registration = await navigator.serviceWorker.ready;
  const subscription = await registration.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: urlBase64ToUint8Array(vapidPublicKey)
  });

  await supabase.from("push_subscriptions").upsert({
    user_id: currentUserId,
    subscription,
    active: true,
    updated_at: new Date().toISOString()
  });

  return subscription;
}
```

## 3) SQL migrations

Primary migration:
- `/Users/freddy/Downloads/NEW PROJECTS/MAITRIBE Codex/supabase/migration_2026_02_24_push_subscriptions.sql`

Includes:
- `push_subscriptions` table
- RLS policies
- optional `users.push_declined`

## 4) Server-side push sender

Use either:
- Supabase Edge Function (`send-push`) OR
- n8n HTTP call to same Edge Function

Node-style example:
```js
const webpush = require("web-push");

webpush.setVapidDetails(
  "mailto:f.stutt@icloud.com",
  process.env.VAPID_PUBLIC_KEY,
  process.env.VAPID_PRIVATE_KEY
);

async function sendPushToUser(supabase, userId, title, body, tag) {
  const { data } = await supabase
    .from("push_subscriptions")
    .select("subscription")
    .eq("user_id", userId)
    .eq("active", true)
    .single();

  if (!data) return;
  await webpush.sendNotification(data.subscription, JSON.stringify({
    title,
    body,
    tag,
    url: "/index.html"
  }));
}
```

## 5) n8n workflow (dispatch spec)

Recommended flow:
1. Trigger (`Cron` or event)
2. Postgres: load eligible users + subscriptions
3. Optional Gemini generation node
4. HTTP Request node to Supabase Edge Function `/functions/v1/send-push`
5. Log notification result in `reminders`
6. On HTTP 410: mark subscription inactive

SQL for inactive on 410:
```sql
update public.push_subscriptions
set active = false, updated_at = now()
where user_id = $1;
```

## 6) iOS constraints (critical)
- Web Push only from iOS 16.4+
- User must install PWA on Home Screen
- User must explicitly allow notifications
- Push does not work in Safari tab mode
- No true silent push
- Badge behavior is limited compared to native apps

## 7) Permission Flow UX

Step 1:
- App detects PWA installation state.

Step 2:
- Ask contextually (after first meaningful interaction):
  - DE: `Mai kann dir zwischen Gespraechen kleine Impulse schicken. Moechtest du das?`
  - EN: `Mai can send small prompts between conversations. Do you want that?`

Step 3:
- If user accepts -> trigger browser permission + subscribe.
- If user declines -> set `users.push_declined = true`, do not prompt repeatedly.

Step 4:
- Let user manage push in Settings anytime.

## 8) VAPID key generation
```bash
npx web-push generate-vapid-keys
```

Store:
- `VAPID_PUBLIC_KEY`
- `VAPID_PRIVATE_KEY`
- `VAPID_SUBJECT=mailto:f.stutt@icloud.com`

## 9) Failure handling
- 410 Gone: deactivate subscription
- 429/5xx from AI generation: fallback static message
- Delivery timeout: retry once, then log fail

## 10) Security notes
- Never expose private VAPID key in frontend.
- Keep push send logic server-side only.
- Keep RLS on subscription table enabled at all times.
