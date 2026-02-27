-- MaiTribe: Morning/Evening Identity Loop + Evidence Vault
-- Date: 2026-02-27

CREATE TABLE IF NOT EXISTS public.identity_proofs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  statement_id text NOT NULL,
  statement_text text NOT NULL,
  morning_question text,
  morning_response text,
  evening_result text CHECK (evening_result IN ('done', 'not_done', 'skipped', NULL)),
  evening_reflection text,
  date date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_proofs_user_date
  ON public.identity_proofs(user_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_proofs_statement
  ON public.identity_proofs(statement_id, evening_result);

-- Ensure one proof row per user/day so morning generation is idempotent.
CREATE UNIQUE INDEX IF NOT EXISTS uq_identity_proofs_user_date
  ON public.identity_proofs(user_id, date);

ALTER TABLE public.identity_proofs ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'identity_proofs'
      AND policyname = 'Users can manage own proofs'
  ) THEN
    CREATE POLICY "Users can manage own proofs"
      ON public.identity_proofs
      FOR ALL
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END
$$;
