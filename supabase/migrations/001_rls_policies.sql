-- MaiTribe Codex — RLS Policies for ALL tables
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor > New query)
--
-- WITHOUT these policies, authenticated users cannot read or write ANY data,
-- even if the code and schema are correct. This is the #1 cause of
-- "identity can't be saved" and similar bugs.
--
-- Safe to run multiple times — uses DROP IF EXISTS + CREATE.

-- ═══════════════════════════════════════════════════
-- USERS
-- ═══════════════════════════════════════════════════
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own" ON public.users;
CREATE POLICY "Users read own" ON public.users
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users insert own" ON public.users;
CREATE POLICY "Users insert own" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users update own" ON public.users;
CREATE POLICY "Users update own" ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- ═══════════════════════════════════════════════════
-- IDENTITIES
-- ═══════════════════════════════════════════════════
ALTER TABLE public.identities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own identities" ON public.identities;
DROP POLICY IF EXISTS "Users can read own identities" ON public.identities;
DROP POLICY IF EXISTS "Identities read own" ON public.identities;
CREATE POLICY "Identities read own" ON public.identities
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own identities" ON public.identities;
DROP POLICY IF EXISTS "Identities insert own" ON public.identities;
CREATE POLICY "Identities insert own" ON public.identities
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own identities" ON public.identities;
DROP POLICY IF EXISTS "Identities update own" ON public.identities;
CREATE POLICY "Identities update own" ON public.identities
  FOR UPDATE USING (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════
-- CONVERSATIONS
-- ═══════════════════════════════════════════════════
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own conversations" ON public.conversations;
DROP POLICY IF EXISTS "Conversations read own" ON public.conversations;
CREATE POLICY "Conversations read own" ON public.conversations
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own conversations" ON public.conversations;
DROP POLICY IF EXISTS "Conversations insert own" ON public.conversations;
CREATE POLICY "Conversations insert own" ON public.conversations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own conversations" ON public.conversations;
DROP POLICY IF EXISTS "Conversations update own" ON public.conversations;
CREATE POLICY "Conversations update own" ON public.conversations
  FOR UPDATE USING (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════
-- MESSAGES
-- ═══════════════════════════════════════════════════
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own messages" ON public.messages;
DROP POLICY IF EXISTS "Messages read own" ON public.messages;
CREATE POLICY "Messages read own" ON public.messages
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own messages" ON public.messages;
DROP POLICY IF EXISTS "Messages insert own" ON public.messages;
CREATE POLICY "Messages insert own" ON public.messages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════
-- CHECKINS
-- ═══════════════════════════════════════════════════
ALTER TABLE public.checkins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own checkins" ON public.checkins;
DROP POLICY IF EXISTS "Checkins read own" ON public.checkins;
CREATE POLICY "Checkins read own" ON public.checkins
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own checkins" ON public.checkins;
DROP POLICY IF EXISTS "Checkins insert own" ON public.checkins;
CREATE POLICY "Checkins insert own" ON public.checkins
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own events" ON public.events;
DROP POLICY IF EXISTS "Events read own" ON public.events;
CREATE POLICY "Events read own" ON public.events
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own events" ON public.events;
DROP POLICY IF EXISTS "Events insert own" ON public.events;
CREATE POLICY "Events insert own" ON public.events
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own events" ON public.events;
DROP POLICY IF EXISTS "Events update own" ON public.events;
CREATE POLICY "Events update own" ON public.events
  FOR UPDATE USING (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════
-- REMINDERS (if exists)
-- ═══════════════════════════════════════════════════
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'reminders') THEN
    ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;
    EXECUTE 'DROP POLICY IF EXISTS "Reminders read own" ON public.reminders';
    EXECUTE 'CREATE POLICY "Reminders read own" ON public.reminders FOR SELECT USING (auth.uid() = user_id)';
    EXECUTE 'DROP POLICY IF EXISTS "Reminders insert own" ON public.reminders';
    EXECUTE 'CREATE POLICY "Reminders insert own" ON public.reminders FOR INSERT WITH CHECK (auth.uid() = user_id)';
    EXECUTE 'DROP POLICY IF EXISTS "Reminders update own" ON public.reminders';
    EXECUTE 'CREATE POLICY "Reminders update own" ON public.reminders FOR UPDATE USING (auth.uid() = user_id)';
    EXECUTE 'DROP POLICY IF EXISTS "Reminders delete own" ON public.reminders';
    EXECUTE 'CREATE POLICY "Reminders delete own" ON public.reminders FOR DELETE USING (auth.uid() = user_id)';
  END IF;
END $$;

-- ═══════════════════════════════════════════════════
-- ASTRO_TRANSITS (if exists)
-- ═══════════════════════════════════════════════════
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'astro_transits') THEN
    ALTER TABLE public.astro_transits ENABLE ROW LEVEL SECURITY;
    EXECUTE 'DROP POLICY IF EXISTS "Transits read own" ON public.astro_transits';
    EXECUTE 'CREATE POLICY "Transits read own" ON public.astro_transits FOR SELECT USING (auth.uid() = user_id)';
  END IF;
END $$;

-- ═══════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════

-- Check RLS is enabled on all tables
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- Check all policies
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
