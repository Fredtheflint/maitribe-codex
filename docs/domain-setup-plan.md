# MaiTribe Domain Setup Plan

## Current State

| Site | Netlify URL | Custom Domain | Content |
|------|-------------|---------------|---------|
| `maitribe` | maitribe.netlify.app | none | Landing page (not deployed) |
| `maitribe-codex` | maitribe-codex.netlify.app | none | Full app (PWA) |

## Recommended Setup: Two Subdomains

Use your `maitribe.ai` domain with two subdomains:

| URL | Points to | Content |
|-----|-----------|---------|
| `maitribe.ai` (root) | `maitribe` Netlify site | Landing page with waitlist |
| `app.maitribe.ai` | `maitribe-codex` Netlify site | Full PWA app |

### Why separate sites?

- Landing page is public-facing marketing — different caching, SEO, analytics
- App is a PWA with service worker, auth, and API calls — needs different headers
- Keeps the app URL clean (`app.maitribe.ai`) for homescreen installs
- Can update landing page without touching the app and vice versa

---

## Step-by-Step Setup

### 1. Deploy landing page to `maitribe` Netlify site

```bash
# From the project directory
netlify link --id aec01f94-bb28-4708-b098-99a3ffb46437
netlify deploy --prod --dir=. --filter=landing.html
```

Or manually: Netlify Dashboard > maitribe > Deploys > drag & drop `landing.html`

### 2. Add root domain (`maitribe.ai`) to the landing page site

1. Go to [Netlify Dashboard > maitribe > Domain management](https://app.netlify.com/projects/maitribe/domain-management)
2. Click **Add custom domain**
3. Enter `maitribe.ai`
4. Follow DNS instructions (add CNAME or configure Netlify DNS)

### 3. Add subdomain (`app.maitribe.ai`) to the app site

1. Go to [Netlify Dashboard > maitribe-codex > Domain management](https://app.netlify.com/projects/maitribe-codex/domain-management)
2. Click **Add custom domain**
3. Enter `app.maitribe.ai`
4. Add a DNS CNAME record:
   - **Host**: `app`
   - **Value**: `maitribe-codex.netlify.app`
   - **TTL**: 3600

### 4. Update Supabase redirect URLs

In Supabase Dashboard > Authentication > URL Configuration:
- **Site URL**: `https://app.maitribe.ai`
- **Redirect URLs** (add):
  - `https://app.maitribe.ai`
  - `https://app.maitribe.ai/index.html`

### 5. Update Google OAuth (if configured)

In Google Cloud Console > Credentials > OAuth client:
- Add `https://app.maitribe.ai` to **Authorized JavaScript origins**
- Authorized redirect URI stays the same (Supabase callback URL)

### 6. Update landing page CTA link

In `landing.html`, update the "Open App" / "Get Started" button to link to:
```
https://app.maitribe.ai
```

---

## DNS Configuration

If your domain is managed by a registrar (not Netlify DNS):

| Type | Host | Value | Purpose |
|------|------|-------|---------|
| A | @ | 75.2.60.5 | Root domain to Netlify |
| CNAME | app | maitribe-codex.netlify.app | App subdomain |
| CNAME | www | maitribe.netlify.app | www redirect |

If using **Netlify DNS** (recommended — enables automatic SSL):
1. Go to Netlify Dashboard > Domains
2. Add `maitribe.ai`
3. Update your registrar's nameservers to Netlify's

---

## Alternative: Single Site

If you prefer keeping everything on one site, you could:
- Deploy both `landing.html` and `index.html` to `maitribe-codex`
- Use `maitribe.ai` as the domain
- Set `landing.html` as a redirect for `/` and `index.html` as `/app`

**Not recommended** because the service worker and PWA manifest would interfere with the landing page.
