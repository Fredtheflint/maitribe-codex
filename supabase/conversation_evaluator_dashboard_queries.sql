-- MaiTribe Conversation Evaluator dashboard queries
-- Run in Supabase SQL Editor for quick quality monitoring.

-- Average score by week (last 8 weeks)
SELECT
  DATE_TRUNC('week', created_at) AS week,
  ROUND(AVG(total_score), 1) AS avg_score,
  COUNT(*) AS eval_count
FROM public.conversation_evals
GROUP BY week
ORDER BY week DESC
LIMIT 8;

-- Average category scores over the last 30 days
SELECT
  ROUND(AVG(score_listening), 1) AS listening,
  ROUND(AVG(score_specificity), 1) AS specificity,
  ROUND(AVG(score_chart_usage), 1) AS chart_usage,
  ROUND(AVG(score_length), 1) AS length,
  ROUND(AVG(score_aha_moment), 1) AS aha_moment,
  ROUND(AVG(score_epe_rhythm), 1) AS epe_rhythm,
  ROUND(AVG(score_vulnerability), 1) AS vulnerability
FROM public.conversation_evals
WHERE created_at > NOW() - INTERVAL '30 days';
