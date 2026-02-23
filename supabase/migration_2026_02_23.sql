-- MaiTribe Codex — Migration 2026-02-23
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor > New query)
-- This migration fixes RLS policies for ALL tables and the name display bug.

-- ============================================================
-- 1. Ensure identities table matches real schema
-- ============================================================

CREATE TABLE IF NOT EXISTS public.identities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  full_text text NOT NULL,
  one_liner text,
  sentences jsonb,
  is_active boolean DEFAULT true,
  answers jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_identities_user_active ON public.identities(user_id, is_active);

-- ============================================================
-- 2. Ensure columns exist on users table
-- ============================================================

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS push_token JSONB;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS onboarding_step INTEGER DEFAULT 1;

-- ============================================================
-- 3. RLS Policies for ALL tables
--    Drop + recreate each to ensure correct state
-- ============================================================

-- --- users ---
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own row" ON public.users;
CREATE POLICY "Users can read own row" ON public.users
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own row" ON public.users;
CREATE POLICY "Users can update own row" ON public.users
  FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own row" ON public.users;
CREATE POLICY "Users can insert own row" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- --- identities ---
ALTER TABLE public.identities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own identities" ON public.identities;
DROP POLICY IF EXISTS "Users can read own identities" ON public.identities;
CREATE POLICY "Users can read own identities" ON public.identities
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own identities" ON public.identities;
CREATE POLICY "Users can insert own identities" ON public.identities
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own identities" ON public.identities;
CREATE POLICY "Users can update own identities" ON public.identities
  FOR UPDATE USING (auth.uid() = user_id);

-- --- checkins ---
ALTER TABLE public.checkins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own checkins" ON public.checkins;
CREATE POLICY "Users can read own checkins" ON public.checkins
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own checkins" ON public.checkins;
CREATE POLICY "Users can insert own checkins" ON public.checkins
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own checkins" ON public.checkins;
CREATE POLICY "Users can update own checkins" ON public.checkins
  FOR UPDATE USING (auth.uid() = user_id);

-- --- conversations ---
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own conversations" ON public.conversations;
CREATE POLICY "Users can read own conversations" ON public.conversations
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own conversations" ON public.conversations;
CREATE POLICY "Users can insert own conversations" ON public.conversations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own conversations" ON public.conversations;
CREATE POLICY "Users can update own conversations" ON public.conversations
  FOR UPDATE USING (auth.uid() = user_id);

-- --- messages ---
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own messages" ON public.messages;
CREATE POLICY "Users can read own messages" ON public.messages
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own messages" ON public.messages;
CREATE POLICY "Users can insert own messages" ON public.messages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- --- events ---
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own events" ON public.events;
CREATE POLICY "Users can read own events" ON public.events
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own events" ON public.events;
CREATE POLICY "Users can insert own events" ON public.events
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own events" ON public.events;
CREATE POLICY "Users can update own events" ON public.events
  FOR UPDATE USING (auth.uid() = user_id);

-- --- astro_transits (if exists) ---
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'astro_transits') THEN
    ALTER TABLE public.astro_transits ENABLE ROW LEVEL SECURITY;
    EXECUTE 'DROP POLICY IF EXISTS "Users can read own transits" ON public.astro_transits';
    EXECUTE 'CREATE POLICY "Users can read own transits" ON public.astro_transits FOR SELECT USING (auth.uid() = user_id)';
  END IF;
END $$;

-- ============================================================
-- 4. Fix name bug: display_name = email prefix → use name
-- ============================================================

-- Show current state (debug)
SELECT id, email, name, display_name, onboarding_completed
FROM public.users
ORDER BY created_at DESC;

-- Fix: Where display_name is the email prefix but name was set during onboarding
UPDATE public.users
SET display_name = name
WHERE name IS NOT NULL
  AND name != ''
  AND (display_name IS NULL OR display_name = split_part(email, '@', 1))
  AND name != split_part(email, '@', 1);

-- Also: Where display_name is still the email prefix and no name exists, clear it
UPDATE public.users
SET display_name = NULL
WHERE (name IS NULL OR name = '' OR name = split_part(email, '@', 1))
  AND display_name = split_part(email, '@', 1);

-- ============================================================
-- 5. Verification
-- ============================================================

-- Check RLS status for all tables
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- Check all RLS policies
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Check identities columns
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'identities'
ORDER BY ordinal_position;

-- Check users after name fix
SELECT id, email, name, display_name, onboarding_completed
FROM public.users
ORDER BY created_at DESC;
