-- Backfill profile rows for existing users
INSERT INTO profile (user_id, full_name, email, phone, created_at, updated_at, rtg_avg)
SELECT u.id,
       u.name,
       u.email,
       u.phone,
       COALESCE(u.created_at, NOW()),
       NOW(),
       0
FROM users u
LEFT JOIN profile p ON p.user_id = u.id
WHERE p.user_id IS NULL;
