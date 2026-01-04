-- Status note for completion
ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS status_note TEXT;

-- Reviews per task (author -> target)
CREATE TABLE IF NOT EXISTS task_reviews (
  id SERIAL PRIMARY KEY,
  task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  author_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (task_id, author_id)
);
CREATE INDEX IF NOT EXISTS idx_task_reviews_task ON task_reviews(task_id);
CREATE INDEX IF NOT EXISTS idx_task_reviews_target ON task_reviews(target_id);
