-- MaiTribe Codex — Migration 2026-02-22
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor > New query)

-- 1. Add 'name' column to users table (for profile name storage)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS name TEXT;

-- 2. Add 'onboarding_step' column to users table (tracks onboarding progress)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS onboarding_step INTEGER DEFAULT 1;

-- 3. Add 'push_token' column to users table (stores push notification subscription)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS push_token JSONB;

-- Verification queries (run these after the migration to confirm):

-- Check that 'name' column exists
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'users'
  AND column_name IN ('name', 'onboarding_step', 'push_token')
ORDER BY column_name;

-- Quick sanity check: count users
SELECT COUNT(*) AS total_users FROM public.users;
