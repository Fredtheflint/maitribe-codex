-- MaiTribe AlphaEvolve loop: per-conversation evaluation + aggregated user learnings
-- Date: 2026-02-27

CREATE TABLE IF NOT EXISTS public.conversation_evals (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  summary_id uuid REFERENCES public.chat_summaries(id) ON DELETE SET NULL,
  score_listening integer CHECK (score_listening BETWEEN 1 AND 5),
  score_specificity integer CHECK (score_specificity BETWEEN 1 AND 5),
  score_chart_usage integer CHECK (score_chart_usage BETWEEN 1 AND 5),
  score_length integer CHECK (score_length BETWEEN 1 AND 5),
  score_aha_moment integer CHECK (score_aha_moment BETWEEN 1 AND 5),
  score_epe_rhythm integer CHECK (score_epe_rhythm BETWEEN 1 AND 5),
  score_vulnerability integer CHECK (score_vulnerability BETWEEN 1 AND 5),
  total_score numeric(3,1),
  what_worked text,
  what_to_improve text,
  user_preferred_style text,
  effective_topics text[],
  message_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_conversation_evals_user_created
  ON public.conversation_evals (user_id, created_at DESC);

ALTER TABLE public.conversation_evals ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'conversation_evals'
      AND policyname = 'Users read own evals'
  ) THEN
    CREATE POLICY "Users read own evals"
      ON public.conversation_evals
      FOR SELECT
      USING (auth.uid() = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'conversation_evals'
      AND policyname = 'Users insert own evals'
  ) THEN
    CREATE POLICY "Users insert own evals"
      ON public.conversation_evals
      FOR INSERT
      WITH CHECK (auth.uid() = user_id);
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.user_learnings (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  effective_approaches text[],
  ineffective_approaches text[],
  preferred_style text,
  strong_topics text[],
  weak_topics text[],
  avg_score numeric(3,1),
  eval_count integer DEFAULT 0,
  prompt_block text,
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.user_learnings ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_learnings'
      AND policyname = 'Users read own learnings'
  ) THEN
    CREATE POLICY "Users read own learnings"
      ON public.user_learnings
      FOR SELECT
      USING (auth.uid() = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_learnings'
      AND policyname = 'Users upsert own learnings'
  ) THEN
    CREATE POLICY "Users upsert own learnings"
      ON public.user_learnings
      FOR INSERT
      WITH CHECK (auth.uid() = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_learnings'
      AND policyname = 'Users update own learnings'
  ) THEN
    CREATE POLICY "Users update own learnings"
      ON public.user_learnings
      FOR UPDATE
      USING (auth.uid() = user_id);
  END IF;
END
$$;
