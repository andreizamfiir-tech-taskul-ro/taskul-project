-- Store average task review rating on profile
ALTER TABLE profile
  ADD COLUMN IF NOT EXISTS rtg_avg NUMERIC DEFAULT 0;

UPDATE profile p
SET rtg_avg = COALESCE(tr.avg_rating, 0)
FROM (
  SELECT target_id, AVG(rating) AS avg_rating
  FROM task_reviews
  GROUP BY target_id
) tr
WHERE p.user_id = tr.target_id;
