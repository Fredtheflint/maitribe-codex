# MaiTribe Netlify Deployment Specification

Last updated: 2026-02-21  
Goal: Deploy the single-file MaiTribe PWA (`index.html`) for real-world testing on Netlify with production-safe routing, headers, and Supabase Auth redirects.

## 1) Deployment Artifacts
The following files are required in project root:
- `netlify.toml`
- `manifest.json`
- `_headers`
- `_redirects`

Current behavior configured:
- SPA routing fallback to `/index.html`
- Service worker safety headers
- Manifest content-type + cache headers
- Basic static file caching strategy

## 2) Netlify Setup Options

## Option A: Git-based (recommended)
1. Push project to GitHub/GitLab/Bitbucket.
2. In Netlify: "Add new site" -> "Import an existing project".
3. Select repo and branch.
4. Build settings:
- Build command: (leave empty)
- Publish directory: `.`
5. Deploy site.

## Option B: Netlify CLI
```bash
npm i -g netlify-cli
netlify login
netlify init
netlify deploy --dir .
netlify deploy --prod --dir .
```

## 3) Domain and SSL Setup

## 3.1 Recommended domain layout
- Landing page: `maitribe.ai`
- App: `app.maitribe.ai`

Reason: clean separation between marketing and authenticated product app.

## 3.2 Netlify domain steps
1. Netlify -> Site settings -> Domain management.
2. Add custom domain (`app.maitribe.ai` or `maitribe.ai`).
3. Configure DNS records at domain provider:
- CNAME `app` -> `<your-netlify-subdomain>.netlify.app`
4. Verify DNS propagation.
5. Enable HTTPS (Netlify-managed certificate / Let's Encrypt).

## 3.3 SSL checks
- Ensure `https://app.maitribe.ai` loads without warnings.
- Ensure magic links always use HTTPS URLs.

## 4) Supabase Auth Redirect Configuration
Supabase Dashboard -> Authentication -> URL Configuration:

## 4.1 Site URL
Set production Site URL:
- `https://app.maitribe.ai`

## 4.2 Additional Redirect URLs
Add all environments that may receive magic links:
- `https://app.maitribe.ai`
- `https://app.maitribe.ai/index.html`
- `https://maitribe.ai` (if app also served at apex)
- `http://localhost:8080`
- `http://localhost:8080/index.html`

## 4.3 In-app redirect behavior
Current app uses:
- `emailRedirectTo: window.location.origin + window.location.pathname`

This is compatible once production origin is Netlify/custom-domain.

## 5) PWA Requirements
`manifest.json` now includes:
- Name: `MaiTribe`
- Theme color: `#131814`
- Display mode: `standalone`
- Start URL: `/index.html`

Service worker:
- `sw.js` must be served at root (`/sw.js`) to keep full scope.
- Header `Service-Worker-Allowed: /` is configured.

## 6) Cache Strategy
- `index.html` and `sw.js`: no-store / must-revalidate
- `manifest.json`: short cache window
- static JS/CSS: short-lived public cache (5 min)

This avoids stale app shell issues during active iteration.

## 7) Pre-Launch Checklist
1. Deploy to Netlify production URL.
2. Confirm magic-link login roundtrip on production domain.
3. Confirm service worker registration (without `?no_sw=1`).
4. Confirm install prompt / add-to-home-screen.
5. Confirm offline fallback page (`offline.html`).
6. Confirm Supabase RLS-protected reads/writes still pass with production origin.
7. Test iOS Safari + Android Chrome install behavior.

## 8) Rollback Plan
If production deploy causes auth/session or cache regressions:
1. Disable service worker quickly by shipping `?no_sw=1` in test links.
2. Re-deploy previous stable build from Netlify deploy history.
3. Keep Supabase redirect URLs for both production and localhost until stable.

## 9) Notes
- No server-side secrets are required for the current PWA deployment model.
- Client-side keys remain user-supplied/local, as per current architecture.
