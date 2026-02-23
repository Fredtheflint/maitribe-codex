-- MaiTribe Codex — Migration 2026-02-23
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor > New query)

-- ============================================================
-- 1. Verify identities table exists and has correct schema
-- ============================================================

-- Create identities table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.identities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  full_text text NOT NULL,
  sentences jsonb,
  one_liner text,
  language text DEFAULT 'en',
  is_active boolean DEFAULT true,
  version integer DEFAULT 1,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Ensure index exists
CREATE INDEX IF NOT EXISTS idx_identities_user_active ON public.identities(user_id, is_active);

-- Ensure RLS is enabled
ALTER TABLE public.identities ENABLE ROW LEVEL SECURITY;

-- Ensure RLS policy exists (drop + recreate to be safe)
DROP POLICY IF EXISTS "Users can manage own identities" ON public.identities;
CREATE POLICY "Users can manage own identities" ON public.identities
FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- 2. Ensure push_token column exists on users table
-- ============================================================
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS push_token JSONB;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS onboarding_step INTEGER DEFAULT 1;

-- ============================================================
-- 3. Fix name bug: if display_name looks like an email prefix
--    and name is different, copy name to display_name
--    OR if display_name = email prefix, clear it so the app
--    shows a clean greeting without a name
-- ============================================================

-- Show current state of all users (name vs display_name vs email)
SELECT id, email, name, display_name, onboarding_completed
FROM public.users
ORDER BY created_at DESC;

-- Fix: Update display_name to match the onboarding name if it
-- looks like it was overwritten with the email prefix
-- (Only run this if the SELECT above shows wrong display_names)
UPDATE public.users
SET display_name = name
WHERE name IS NOT NULL
  AND name != ''
  AND (display_name IS NULL OR display_name = split_part(email, '@', 1))
  AND name != split_part(email, '@', 1);

-- ============================================================
-- 4. Verification queries
-- ============================================================

-- Check identities table columns
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'identities'
ORDER BY ordinal_position;

-- Check users table has all needed columns
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'users'
  AND column_name IN ('name', 'display_name', 'push_token', 'onboarding_step', 'onboarding_completed')
ORDER BY column_name;

-- Check RLS policies on identities
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'identities';

-- Count identities per user
SELECT user_id, COUNT(*) as total, COUNT(*) FILTER (WHERE is_active) as active
FROM public.identities
GROUP BY user_id;
