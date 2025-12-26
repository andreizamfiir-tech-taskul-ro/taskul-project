-- Add password hash column for users (store hashed password, not plaintext)
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS password_hash TEXT;

-- Optional phone number
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS phone TEXT;

-- Ensure unique emails (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE tablename = 'users' AND indexname = 'users_email_key'
  ) THEN
    ALTER TABLE users
      ADD CONSTRAINT users_email_key UNIQUE (email);
  END IF;
END$$;

-- Case-insensitive unique email safeguard
CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_idx
  ON users (LOWER(email));

-- Ensure created_at exists
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
