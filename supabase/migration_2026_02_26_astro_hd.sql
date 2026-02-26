-- Migration: Astro & Human Design
-- Date: 2026-02-26
-- Description: Add birth data and astro/HD profile columns to users table

-- Add birth data columns to users
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS birth_date DATE,
  ADD COLUMN IF NOT EXISTS birth_time TIME,
  ADD COLUMN IF NOT EXISTS birth_place TEXT,
  ADD COLUMN IF NOT EXISTS birth_lat DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS birth_lng DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS astro_profile JSONB,
  ADD COLUMN IF NOT EXISTS human_design JSONB,
  ADD COLUMN IF NOT EXISTS wisdom_preferences JSONB DEFAULT '{"mode":"off"}'::jsonb;

-- Index for users with astro data (for future transit jobs)
CREATE INDEX IF NOT EXISTS idx_users_has_astro ON public.users(id)
  WHERE birth_date IS NOT NULL AND astro_profile IS NOT NULL;
