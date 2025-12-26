-- Task categories
CREATE TABLE IF NOT EXISTS task_categories (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Link tasks to categories (optional / nullable for existing rows)
ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS category_id INTEGER REFERENCES task_categories(id);
CREATE INDEX IF NOT EXISTS idx_tasks_category_id ON tasks(category_id);

-- User profile details
CREATE TABLE IF NOT EXISTS user_profiles (
  user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  display_name TEXT,
  avatar_url TEXT,
  background_url TEXT,
  bio TEXT,
  location TEXT,
  level INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Business data for users (CUI etc.)
CREATE TABLE IF NOT EXISTS user_businesses (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  cui TEXT NOT NULL,
  company_name TEXT NOT NULL,
  company_address TEXT,
  verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id),
  UNIQUE (cui)
);

-- Reviews about users
CREATE TABLE IF NOT EXISTS user_reviews (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reviewer_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_user_reviews_user ON user_reviews(user_id);
CREATE INDEX IF NOT EXISTS idx_user_reviews_reviewer ON user_reviews(reviewer_id);

-- Notifications for users
CREATE TABLE IF NOT EXISTS notifications (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT,
  type TEXT,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, read_at);
