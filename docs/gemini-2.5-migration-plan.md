# Gemini 2.0 Flash -> Gemini 2.5 Flash Migration Plan

Last updated: 2026-02-21  
Deadline context: Gemini 2.0 Flash / Flash-Lite retirement target given in project brief: **2026-03-03**.

## 1) Scope of Migration
Migrate all MaiTribe AI calls from:
- `gemini-2.0-flash`
- `gemini-2.0-flash-lite`

to:
- `gemini-2.5-flash`
- `gemini-2.5-flash-lite` (fallback, if available in your Google AI project)

Affected surfaces:
- Main chat with Mai (client-side in `index.html`)
- Check-in reflections (`index.html`)
- Identity generation Edge Function (`supabase/functions/generate-identity/index.ts`)
- n8n workflows for reminders / follow-ups (Gemini HTTP nodes)
- Planned transit interpretation generation

## 2) Code Changes (Exact Targets)

## 2.1 Client app (`index.html`)
Current model selection logic uses 2.0 models.

Action:
- Replace primary model string `gemini-2.0-flash` -> `gemini-2.5-flash`
- Replace fallback model string `gemini-2.0-flash-lite` -> `gemini-2.5-flash-lite`
- Keep existing retry/backoff behavior.

Also verify all direct model URL paths use:
- `https://generativelanguage.googleapis.com/v1beta/models/<model>:generateContent`

## 2.2 Edge Function (`supabase/functions/generate-identity/index.ts`)
Current fallback array:
- `gemini-2.0-flash`
- `gemini-2.0-flash-lite`

Action:
- Update array to 2.5 equivalents.
- Keep 429 fallback flow unchanged.

## 2.3 n8n workflows
Action:
- In each Gemini HTTP Request node, update endpoint path model segment to `gemini-2.5-flash`.
- If fallback branch exists, set to `gemini-2.5-flash-lite`.

## 3) API Compatibility Review
In current MaiTribe usage pattern, requests use:
- `system_instruction`
- `contents` with `parts`
- `generationConfig` (`temperature`, `topP`, `maxOutputTokens`)

Expected migration impact: **low**, because schema remains `generateContent` style.

Potential compatibility checks:
- Output style/verbosity may shift under 2.5.
- Safety filtering behavior may differ for emotional-language prompts.
- Latency profile and quota behavior can change.

## 4) Prompt Adaptation Guidance
No mandatory structural prompt rewrite is required, but tune for consistency:
- Keep hard constraints explicit in prompt (under 80 words, no bullet points, no diagnosis).
- Keep language directive explicit (`Always respond in <language>`).
- Keep response-order instruction explicit (acknowledge -> clarify -> guide -> empower).

If 2.5 outputs become too long:
- Lower `maxOutputTokens`
- Add stricter line: "If in doubt, choose fewer words over more words."

If tone drifts too generic:
- Strengthen context anchoring line (identity + recent check-in pattern + event references).

## 5) Testing Checklist (Post-Migration)

## 5.1 Functional smoke tests
1. Chat response returns normally for EN + DE users.
2. Check-in reflection generation still stores `mai_response`.
3. Identity generation function returns and persists `full_text`, `one_liner`, `sentences`.
4. n8n reminder workflows generate valid reminder text.

## 5.2 Behavioral quality tests
1. Response length generally under 80 words.
2. No bullet points in user-facing responses.
3. German output stays in `du` form.
4. No medical or diagnostic phrasing appears.

## 5.3 Failure-path tests
1. Simulate 429 and verify fallback model path executes.
2. Simulate Gemini outage and verify local fallback text path.
3. Verify user-facing error states are graceful (no raw stack traces).

## 5.4 Performance tests
1. Median response latency before/after migration.
2. Timeout frequency before/after migration.
3. Cost-per-1k calls estimate using production prompt sizes.

## 6) Rollout Strategy
- Phase 1: Dev/staging switch to 2.5 models, keep 2.0 in production.
- Phase 2: Production canary (small traffic slice / founder-only testing).
- Phase 3: Full cutover once behavioral parity is acceptable.

## 7) Rollback Plan
If 2.5 output quality or reliability regresses:
1. Revert model constants back to 2.0 strings (if still available during grace period).
2. If 2.0 no longer available, keep 2.5 and switch to stricter prompts + lower token limits.
3. Enable deterministic local fallback for high-risk flows (identity/check-in) until stable.
4. Re-run behavioral QA checklist.

## 8) Suggested Implementation Pattern
Define central model constants (single source of truth) and consume everywhere:
- `GEMINI_PRIMARY_MODEL`
- `GEMINI_FALLBACK_MODEL`

This avoids future deprecation churn across multiple files.

## 9) Execution Checklist
- [ ] Update model strings in `index.html`
- [ ] Update model strings in `supabase/functions/generate-identity/index.ts`
- [ ] Update n8n workflow Gemini endpoints
- [ ] QA checklist pass
- [ ] Production cutover before 2026-03-03
