-- MaiTribe Memory Phase 1: cross-session chat summaries
-- Date: 2026-02-27

CREATE TABLE IF NOT EXISTS public.chat_summaries (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  summary jsonb NOT NULL,
  message_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_summaries_user_created
  ON public.chat_summaries (user_id, created_at DESC);

ALTER TABLE public.chat_summaries ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'chat_summaries'
      AND policyname = 'Users read own summaries'
  ) THEN
    CREATE POLICY "Users read own summaries"
      ON public.chat_summaries
      FOR SELECT
      USING (auth.uid() = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'chat_summaries'
      AND policyname = 'Users insert own summaries'
  ) THEN
    CREATE POLICY "Users insert own summaries"
      ON public.chat_summaries
      FOR INSERT
      WITH CHECK (auth.uid() = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'chat_summaries'
      AND policyname = 'Users delete own summaries'
  ) THEN
    CREATE POLICY "Users delete own summaries"
      ON public.chat_summaries
      FOR DELETE
      USING (auth.uid() = user_id);
  END IF;
END
$$;
