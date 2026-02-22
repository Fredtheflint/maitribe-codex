# MaiTribe – COMPLETE Codex Briefing (22. Feb 2026)
## All Tasks: Bugs + Features + Database + Deployment + Architecture

---

## Context & Tech Stack
- **App**: Single-file PWA (`index.html`, all HTML/CSS/JS in one file)
- **Backend**: Supabase (PostgreSQL + Auth via Magic Link + Realtime)
- **AI**: Gemini 2.0 Flash via REST API (generativelanguage.googleapis.com)
- **Storage**: `localStorage` for API keys/settings (keys prefixed with `maitribe.`)
- **Supabase Project URL**: `https://eiupfoliycebnmoivqps.supabase.co`
- **Gemini Billing**: Tier 1 (Paid, active as of Feb 22, 2026)
- **Local Dev**: `python3 -m http.server 8080`, access via `http://localhost:8080/index.html?no_sw=1&v=1001`

---

## PART A: DATABASE FIXES (Run in Supabase SQL Editor FIRST)

These SQL statements must be executed before the code fixes will work.

```sql
-- 1. Add missing 'name' column (code references it but it doesn't exist)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS name TEXT;

-- 2. Verify the complete schema
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'users' AND table_schema = 'public' 
ORDER BY ordinal_position;

-- 3. Verify all app tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

### Current `public.users` schema (after fix):
```
id (uuid PK), email (text), display_name (text), name (text), language (text), 
birth_date (date), birth_time (time), birth_location (text), 
push_token (text), push_enabled (boolean), morning_reminder_enabled (boolean),
morning_reminder_time (time), mindful_reminders_enabled (boolean), 
mindful_reminder_count (integer), event_followup_enabled (boolean),
astrology_enabled (boolean), human_design_enabled (boolean), 
natal_chart_json (jsonb), onboarding_completed (boolean), 
created_at (timestamptz), updated_at (timestamptz), last_active_at (timestamptz)
```

### Other tables that should exist:
- `checkins` (not `check_ins` — was renamed)
- `conversations`
- `identities`
- `astro_transits`

---

## PART B: CRITICAL BUGS (Blocking — app doesn't work without these)

### BUG 1: `ensureUserProfile` upsert fails with 400
**Symptom**: On page load, console shows `ensureUserProfile upsert error` + HTTP 400
**Root Cause**: Code tries to upsert columns that don't exist or don't match the actual schema. Specifically, `name` column was missing (now added via SQL above).
**Fix**:
1. Audit the `ensureUserProfile` function — every column it references must exist in `public.users`
2. The upsert should use `on_conflict: 'id'` 
3. Map `name` ↔ `display_name` correctly (or use both — `name` for the code, `display_name` as the user-facing name)
4. Add try/catch with meaningful error logging

### BUG 2: Gemini API Key invalid after save
**Symptom**: Chat shows fallback "Mai ruht sich gerade kurz aus..."
**Console**: `Gemini error (gemini-2.0-flash): API Key not found. Please pass a valid API key.`
**Root Cause**: The Profil save function crashes (due to BUG 1) before it can save the new API key. Old invalid key stays in localStorage.
**Fix**:
1. Fix BUG 1 first so Profil can save
2. When saving API key, validate it first with a test call to Gemini
3. Show clear success/error message: "✅ API Key gültig" or "❌ API Key ungültig"
4. If key is invalid on chat send, show: "Dein API Key ist ungültig. Bitte geh zu Profil und gib einen neuen ein." instead of generic fallback

### BUG 3: Profil save crashes on `name` column
**Symptom**: "Could not find the 'name' column of 'users' in the schema cache"
**Root Cause**: Supabase schema cache is stale. The `name` column now exists (added via SQL) but the client cache doesn't know yet.
**Fix**:
1. After adding the column, the Supabase client needs to reload its schema cache
2. Consider: After any schema change, the app should handle stale cache gracefully
3. Quick fix: Hard reload the page after DB migration, or use `.throwOnError()` with proper catch

---

## PART C: MEDIUM BUGS (UX issues)

### BUG 4: Chat greeting in English instead of German
**Symptom**: Chat screen shows "🌿 I am here with you. Share what is on your mind."
**Expected**: "🌿 Ich bin bei dir. Teile, was dich bewegt."
**Root Cause**: Greeting is hardcoded in English. Doesn't read user's `language` setting.
**Fix**: Read `language` from user profile or localStorage. Use i18n lookup for greeting:
- `de`: "🌿 Ich bin bei dir. Teile, was dich bewegt."
- `en`: "🌿 I am here with you. Share what is on your mind."

### BUG 5: Home screen shows email prefix instead of name
**Symptom**: Shows "Guten Nachmittag, f.stutt" 
**Expected**: Show display_name, or just "Guten Nachmittag" if no name set
**Fix**: Use `display_name || name || null` — if null, show greeting without name. Don't parse email.

### BUG 6: No typing indicator in chat
**Symptom**: After sending message, no visual feedback while waiting for Gemini
**Fix**: Add "Mai tippt..." indicator with animated dots after user sends message. Remove when response arrives or on timeout.

### BUG 7: Check-in hangs waiting for Gemini reflection
**Symptom**: After check-in submit, shows "wird gespeichert..." forever if Gemini fails
**Fix**:
1. Save check-in to DB immediately → show "✅ Check-in gespeichert"
2. Request Gemini reflection as background task
3. Timeout after 15 seconds → "Mai's Reflexion kommt später" → return to home
4. Show reflection when/if it arrives

### BUG 8: Chat input field overlapped by navbar
**Symptom**: Placeholder text "Teile, was dich be..." is cut off by bottom nav
**Fix**: Add `padding-bottom: 80px` to chat container or input area

---

## PART D: FEATURES (Important improvements)

### FEATURE 1: Gemini Model String Update [DEADLINE: March 3, 2026]
**Problem**: App uses `gemini-2.0-flash` — being retired March 3, 2026
**Fix**: Find ALL references to `gemini-2.0-flash` and replace with `gemini-2.5-flash`
**Search for**: `generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash`
**Replace with**: `generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash`
**Test**: Verify response format is identical after change

### FEATURE 2: Gemini Error Handling
**Problem**: App hangs forever on Gemini API failures (429, 500, timeout, invalid key)
**Fix for Chat**:
- Add 20-second timeout with `AbortController`
- On 400 (invalid key): "Dein API Key ist ungültig. Bitte überprüfe ihn in den Einstellungen."
- On 429 (rate limit): "Mai braucht einen Moment. Versuch es in einer Minute nochmal."
- On timeout/500: "Mai kann gerade nicht antworten. Bitte versuche es später."
- Always remove typing indicator on error

**Fix for Check-in**:
- Decouple DB save from Gemini reflection
- DB save = synchronous, must succeed
- Gemini reflection = async background task, can fail gracefully

### FEATURE 3: API Key Validation on Save
**When**: User enters new Gemini API key in Profil
**Action**: Before saving, make a test call: `POST /v1beta/models/gemini-2.5-flash:generateContent` with a simple prompt
- If 200: Save key + show "✅ API Key ist gültig und gespeichert"
- If 400/403: Show "❌ Dieser Key ist ungültig. Bitte überprüfe ihn auf aistudio.google.com/apikey"
- If 429: Save key + show "⚠️ Key gespeichert, aber gerade rate-limited. Versuche es in einer Minute."

### FEATURE 4: AI Abstraction Layer (Future-Proofing)
**Why**: Currently Gemini is hardcoded everywhere. Need flexibility to switch models.
**Fix**: Create a central function:
```javascript
async function callAI(systemPrompt, userMessage, options = {}) {
  const model = options.model || localStorage.getItem('maitribe.ai.model') || 'gemini-2.5-flash';
  const apiKey = localStorage.getItem('maitribe.gemini.key');
  const timeout = options.timeout || 20000;
  
  // AbortController for timeout
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeout);
  
  try {
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      signal: controller.signal,
      body: JSON.stringify({
        contents: [{ parts: [{ text: userMessage }] }],
        systemInstruction: { parts: [{ text: systemPrompt }] }
      })
    });
    clearTimeout(timer);
    
    if (!response.ok) {
      const err = await response.json();
      throw { status: response.status, message: err.error?.message || 'Unknown error' };
    }
    
    const data = await response.json();
    return data.candidates?.[0]?.content?.parts?.[0]?.text || '';
  } catch (error) {
    clearTimeout(timer);
    if (error.name === 'AbortError') throw { status: 408, message: 'Timeout' };
    throw error;
  }
}
```
Then replace ALL direct Gemini fetch calls with `callAI()`.

---

## PART E: DEPLOYMENT (Netlify)

### Files needed (Codex already created specs for these — see previous deliverables):
- `netlify.toml` — build config
- `manifest.json` — PWA manifest (name: "MaiTribe", theme: #131814, display: standalone)
- `_headers` — Service Worker scope, cache-control, CORS
- `_redirects` — SPA routing (`/* /index.html 200`)

### Critical deployment step:
After deploying to Netlify, update Supabase Auth settings:
- Go to Supabase → Authentication → URL Configuration
- Add the Netlify domain (e.g. `https://app.maitribe.ai`) to Redirect URLs
- Remove or keep `http://localhost:8080` for local dev

### Domain:
- Primary: `maitribe.ai`
- App subdomain: `app.maitribe.ai` (recommended to separate from landing page)

---

## PART F: SCHEMA AUDIT CHECKLIST

Every database operation in the code must be verified against the actual schema. Common patterns to search for and verify:

```javascript
// Search the code for these patterns and verify column names:
.from('users').upsert(...)     // → verify all columns in upsert object
.from('users').select(...)     // → verify all selected columns exist
.from('users').update(...)     // → verify all updated columns exist
.from('checkins').insert(...)  // → table is 'checkins' NOT 'check_ins'
.from('conversations').insert(...) // → verify table + columns
.from('identities').select(...)    // → verify table + columns
.from('astro_transits').select(...) // → verify table exists
```

---

## PRIORITY ORDER (Recommended execution sequence)

| Priority | Task | Type | Estimated Effort |
|----------|------|------|-----------------|
| 🔴 1 | SQL: Add `name` column | Database | 1 min |
| 🔴 2 | BUG 1: Fix ensureUserProfile upsert | Code | 20 min |
| 🔴 3 | BUG 2+3: Fix Profil save + API key flow | Code | 20 min |
| 🔴 4 | FEATURE 1: Gemini 2.0→2.5 model string | Code | 5 min |
| 🔴 5 | FEATURE 2: Gemini error handling | Code | 30 min |
| 🔴 6 | FEATURE 4: callAI abstraction layer | Code | 30 min |
| 🟡 7 | BUG 4: Chat greeting language | Code | 15 min |
| 🟡 8 | BUG 5: Name display on home | Code | 10 min |
| 🟡 9 | BUG 6: Typing indicator | Code | 20 min |
| 🟡 10 | BUG 7: Check-in Gemini decoupling | Code | 25 min |
| 🟢 11 | BUG 8: Input navbar overlap | Code | 5 min |
| 🟢 12 | FEATURE 3: API key validation | Code | 15 min |
| 🟢 13 | Schema audit (all DB calls) | Code | 30 min |
| 🟢 14 | Deployment files (Netlify) | Config | 20 min |

**Total estimated**: ~4 hours

---

## HOW TO TEST

1. Run SQL from Part A in Supabase SQL Editor
2. Start local server: `python3 -m http.server 8080`
3. Open: `http://localhost:8080/index.html?no_sw=1&v=1001`
4. Login with existing account (Magic Link)
5. Go to Profil → enter valid Gemini API key from aistudio.google.com/apikey → save → should succeed
6. Go to Chat → send message → Mai should respond in German
7. Go to Check-in → submit → should save immediately + show reflection or graceful timeout
8. Home screen should show display_name or generic greeting (not email prefix)
9. Console should have zero red errors

---

## DELIVERABLES EXPECTED

1. Updated `index.html` with ALL fixes applied
2. SQL migration file with any additional schema changes needed
3. Updated `manifest.json` for PWA
4. `netlify.toml`, `_headers`, `_redirects` for deployment
5. Brief changelog documenting all changes made

---

*Created by Claude (Strategy/CEO) for Codex (CTO/Architecture)*
*22. February 2026*
