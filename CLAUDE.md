# MaiTribe Codex

## What This Is
A holistic AI wellness app — single-file PWA (`index.html`). Mai is a calm, emotionally intelligent companion for body, mind, and soul.

## Tech Stack
- **Frontend**: Single `index.html` file (HTML + CSS + JS, no build step)
- **Backend**: Supabase (auth, Postgres, push notifications)
- **AI**: Gemini 2.0 Flash via REST API (falls back to Flash Lite on 429)
- **Deployment**: Static hosting / PWA with service worker

## Design System
- **Colors**: Deep Forest `#1a2f1a`, Sage Green `#7c9a6e`, Cream `#e8e4df`, Gold `#c9b88c`
- **Fonts**: Cormorant Garamond (headings), DM Sans (body)
- **Style**: Glassmorphism cards, soft gradients, breathing space between elements

## Mai's Personality
Mai is a quiet, caring presence — like a thoughtful friend who truly sees you. NOT a chatbot, NOT a coach, NOT a therapist.

Three invisible pillars (never named to the user):
1. **Observer** (Michael Singer) — You are not your thoughts. Notice, stay open, let energy flow.
2. **Presence** (Eckhart Tolle) — Peace lives in now. Recognize old pain without becoming it.
3. **Meaning** (Viktor Frankl) — Between stimulus and response lies freedom. Choose meaning.

Response rules: Acknowledge first, then clarify, then one small step, then empower. Under 80 words. No bullet points. No therapy jargon. Write like a poet, not a life coach.

## Critical Gotchas

1. **German umlauts require unicode escapes** in JS strings: `\u00E4` (ä), `\u00F6` (ö), `\u00FC` (ü), `\u00C4` (Ä), `\u00D6` (Ö), `\u00DC` (Ü), `\u00DF` (ß). Plain characters get corrupted.

2. **Gemini free tier hits 429 quota fast.** Always provide fallback text for every API call — chat opening, chat replies, check-in reflections, identity generation. `callGemini()` retries up to 2x on 429 with 15s/30s delays, falling back from `gemini-2.0-flash` to `gemini-2.0-flash-lite` on retries to reduce quota pressure.

3. **Magic Link auth needs hash token processing before session check.** The URL hash fragment (`#access_token=...`) is captured at script load into `_capturedHash` before Supabase SDK can consume it. `processAuthRedirect()` handles PKCE codes, hash tokens, hash OTP, query OTP, and error params. The Supabase client uses `lock: false` in auth config to avoid BroadcastChannel/navigator.locks issues on mobile PWAs.

4. **All UI strings must use the `t()` function** with translations in the `i18n` object (`en` + `de`). Never hardcode user-facing text. `applyI18n()` is called on every screen switch and language change.

5. **Everything stays in the single `index.html` file.** No splitting into separate JS/CSS files. The only external files are `sw.js`, `manifest.webmanifest`, and icons.

## Key Architecture
- `appState` — global state (session, profile, identity, onboarding, config)
- `showScreen(id)` — screen navigation + calls `applyI18n()`
- `callGemini(options, retryCount)` — all AI calls go through this with retry logic
- `buildSystemPrompt(context)` — Mai's full personality + user context for chat
- `processAuthRedirect()` — handles all Supabase auth callback flows
- `syncOnboardingInBackground(payload)` — local-first, then cloud sync

## i18n
Two languages: `en` (English), `de` (German). German is the primary user language. The `getCurrentLanguage()` function checks onboarding select, then profile, then defaults to `en`.
