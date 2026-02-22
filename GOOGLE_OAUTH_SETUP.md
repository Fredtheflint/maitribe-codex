# Google OAuth Setup for MaiTribe

This guide walks you through enabling "Continue with Google" login in MaiTribe.

## Overview

You need to:
1. Create a Google Cloud project with OAuth credentials
2. Configure Google as an auth provider in Supabase
3. Add your redirect URLs

---

## Step 1: Google Cloud Console

### 1.1 Create or select a project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click the project dropdown (top-left) and select **New Project**
3. Name it `MaiTribe` (or use an existing project)
4. Click **Create**

### 1.2 Configure OAuth Consent Screen

1. Go to [OAuth Consent Screen](https://console.cloud.google.com/apis/credentials/consent)
2. Select **External** user type, click **Create**
3. Fill in:
   - **App name**: `MaiTribe`
   - **User support email**: your email
   - **Developer contact email**: your email
4. Click **Save and Continue**
5. **Scopes**: Click **Add or Remove Scopes**, select:
   - `openid`
   - `email`
   - `profile`
6. Click **Save and Continue**
7. **Test users**: Add your email address
8. Click **Save and Continue**, then **Back to Dashboard**

> **Note**: While in "Testing" mode, only test users can log in. Once ready for production, click **Publish App** on the consent screen.

### 1.3 Create OAuth Credentials

1. Go to [Credentials](https://console.cloud.google.com/apis/credentials)
2. Click **+ Create Credentials** > **OAuth client ID**
3. Application type: **Web application**
4. Name: `MaiTribe Web`
5. **Authorized JavaScript origins**:
   - `https://maitribe-codex.netlify.app`
   - `http://localhost:8081` (for local dev)
6. **Authorized redirect URIs**:
   - `https://<your-supabase-project-ref>.supabase.co/auth/v1/callback`
   - (Find this URL in Supabase Dashboard > Authentication > Providers > Google)
7. Click **Create**
8. Copy the **Client ID** and **Client Secret** — you'll need them next

---

## Step 2: Supabase Dashboard

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your MaiTribe project
3. Navigate to **Authentication** > **Providers**
   - Direct link: `https://supabase.com/dashboard/project/<your-project-ref>/auth/providers`
4. Find **Google** in the list, click to expand
5. Toggle **Enable Sign in with Google** to ON
6. Paste:
   - **Client ID**: from Google Cloud Console
   - **Client Secret**: from Google Cloud Console
7. Copy the **Redirect URL** shown (looks like `https://<ref>.supabase.co/auth/v1/callback`)
   - Make sure this URL is in your Google OAuth **Authorized redirect URIs** (Step 1.3.6)
8. Click **Save**

---

## Step 3: Add Redirect URLs in Supabase

1. In Supabase Dashboard, go to **Authentication** > **URL Configuration**
   - Direct link: `https://supabase.com/dashboard/project/<your-project-ref>/auth/url-configuration`
2. **Site URL**: `https://maitribe-codex.netlify.app`
3. **Redirect URLs** (add all of these):
   - `https://maitribe-codex.netlify.app`
   - `https://maitribe-codex.netlify.app/index.html`
   - `http://localhost:8081`
   - `http://localhost:8081/index.html`
4. Click **Save**

---

## Step 4: Test

1. Open `https://maitribe-codex.netlify.app`
2. Click **Continue with Google**
3. Sign in with your Google account
4. You should be redirected back and logged in

### Troubleshooting

| Problem | Solution |
|---------|----------|
| "redirect_uri_mismatch" error | Make sure the Supabase callback URL is in Google's Authorized redirect URIs (exact match) |
| "Access blocked: app has not been verified" | Add your email as a test user in Google OAuth Consent Screen |
| Login succeeds but app shows auth screen | Check that `https://maitribe-codex.netlify.app` is in Supabase Redirect URLs |
| "popup_closed_by_user" | Try in incognito or disable popup blockers |

---

## Optional: Custom Domain

If you later use a custom domain (e.g. `app.maitribe.ai`), add it to:
1. Google OAuth **Authorized JavaScript origins**
2. Google OAuth **Authorized redirect URIs** (Supabase callback URL stays the same)
3. Supabase **Redirect URLs**
4. Supabase **Site URL** (update to your custom domain)
