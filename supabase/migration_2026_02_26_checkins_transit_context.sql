-- MaiTribe: Transit-aware check-in enrichment
-- Date: 2026-02-26 (updated 2026-02-27)

ALTER TABLE public.checkins
  ADD COLUMN IF NOT EXISTS transit_context jsonb,
  ADD COLUMN IF NOT EXISTS mai_interpretation text,
  ADD COLUMN IF NOT EXISTS body_tip text,
  ADD COLUMN IF NOT EXISTS mind_tip text,
  ADD COLUMN IF NOT EXISTS soul_tip text,
  ADD COLUMN IF NOT EXISTS spirit_tip text;

-- Also add birth_tz to users for transit recalculation
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS birth_tz numeric;

CREATE INDEX IF NOT EXISTS idx_checkins_user_created_at
  ON public.checkins(user_id, created_at DESC);
