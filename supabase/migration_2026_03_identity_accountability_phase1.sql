-- Identity Accountability Phase 1 - Task 1
-- Erweiterung des Identity Profiles

ALTER TABLE public.identities
  ADD COLUMN IF NOT EXISTS dimensions jsonb DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS values_hierarchy jsonb DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS trigger_map jsonb DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS important_people jsonb DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS identity_version integer DEFAULT 1,
  ADD COLUMN IF NOT EXISTS evolution_notes text[];

CREATE INDEX IF NOT EXISTS idx_identities_user_active
  ON public.identities (user_id, is_active) WHERE is_active = true;

COMMENT ON COLUMN public.identities.dimensions IS
  'Fokus-Bereiche: {"body": 0-10, "mind": 0-10, "relationships": 0-10, "creativity": 0-10, "career": 0-10}';

COMMENT ON COLUMN public.identities.values_hierarchy IS
  'Sortierte Werte aus Gesprächen inferiert: ["authenticity", "growth", "connection", ...]';

COMMENT ON COLUMN public.identities.trigger_map IS
  'Situationen die zu ungewolltem Verhalten führen: [{"trigger": "...", "pattern": "...", "noted_at": "..."}]';

COMMENT ON COLUMN public.identities.important_people IS
  'Wichtige Menschen: [{"name": "...", "relation": "...", "context": "..."}]';

COMMENT ON COLUMN public.identities.identity_version IS
  'Wie oft wurde das Identity Statement verändert';

COMMENT ON COLUMN public.identities.evolution_notes IS
  'Notizen zur Identitätsentwicklung: ["Woche 1: Fokus auf...", "Woche 3: Shift zu..."]';
