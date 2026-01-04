-- Link generic reviews table to tasks
ALTER TABLE reviews
  ADD COLUMN IF NOT EXISTS task_id INTEGER REFERENCES tasks(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_reviews_task ON reviews(task_id);
