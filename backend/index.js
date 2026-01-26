require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');



const app = express();
app.use(express.json());

const cors = require('cors');  /*„E ok, acest frontend are voie să citească răspunsurile mele.” */
app.use(cors());

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

const emailRegex = /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i;

const statusLabels = {
  0: 'Disponibil',
  1: 'Acceptat',
  2: 'In desfasurare',
  3: 'Finalizat',
  4: 'Anulat',
  5: 'Expirat',
};

async function resolveProfileId(userId) {
  const result = await pool.query(
    'SELECT * FROM profile WHERE user_id = $1 LIMIT 1',
    [userId]
  );
  if (result.rows.length === 0) return null;
  const row = result.rows[0];
  return row.id ?? row.user_id ?? userId;
}

async function insertNotification(profileId, type, payload) {
  await pool.query(
    `INSERT INTO notifications (profile_id, type, payload, is_read, created_at)
     VALUES ($1, $2, $3, FALSE, NOW())`,
    [profileId, type, payload]
  );
}

async function ensureNotification(profileId, type, payload, key) {
  const res = await pool.query(
    `SELECT id FROM notifications
     WHERE profile_id = $1 AND type = $2
       AND payload->>'task_id' = $3
       AND payload->>'kind' = $4
       AND payload->>'role' = $5
     LIMIT 1`,
    [
      profileId,
      type,
      String(key.taskId),
      key.kind,
      key.role,
    ]
  );
  if (res.rows.length === 0) {
    await insertNotification(profileId, type, payload);
  }
}

async function createTaskEventNotifications(taskId) {
  const taskRes = await pool.query(
    `SELECT tasks.id,
            tasks.title,
            tasks.creator_id,
            tasks.assigned_user_id,
            u_creator.name AS creator_name,
            u_assignee.name AS assignee_name
     FROM tasks
     LEFT JOIN users u_creator ON u_creator.id = tasks.creator_id
     LEFT JOIN users u_assignee ON u_assignee.id = tasks.assigned_user_id
     WHERE tasks.id = $1
     LIMIT 1`,
    [taskId]
  );
  if (taskRes.rows.length === 0) return;
  const task = taskRes.rows[0];
  if (!task.assigned_user_id) return;

  const creatorProfileId = await resolveProfileId(task.creator_id);
  const assigneeProfileId = await resolveProfileId(task.assigned_user_id);

  if (creatorProfileId) {
    await insertNotification(creatorProfileId, 'task_accepted', {
      task_id: task.id,
      title: task.title,
      assignee_id: task.assigned_user_id,
      assignee_name: task.assignee_name || null,
    });
  }

  if (assigneeProfileId) {
    await insertNotification(assigneeProfileId, 'task_assigned', {
      task_id: task.id,
      title: task.title,
      creator_id: task.creator_id,
      creator_name: task.creator_name || null,
    });
  }
}

async function createReminderNotifications() {
  const reminderWindows = [
    { kind: '1h', min: 55, max: 60 },
    { kind: '45m', min: 40, max: 45 },
  ];

  for (const window of reminderWindows) {
    const tasksRes = await pool.query(
      `SELECT id, title, creator_id, assigned_user_id, start_time
       FROM tasks
       WHERE start_time BETWEEN NOW() + INTERVAL '${window.min} minutes'
                         AND NOW() + INTERVAL '${window.max} minutes'`,
    );

    for (const task of tasksRes.rows) {
      if (task.assigned_user_id) {
        const assigneeProfileId = await resolveProfileId(task.assigned_user_id);
        if (assigneeProfileId) {
          await ensureNotification(
            assigneeProfileId,
            'task_reminder',
            {
              task_id: task.id,
              title: task.title,
              kind: window.kind,
              role: 'assignee',
              start_time: task.start_time,
            },
            { taskId: task.id, kind: window.kind, role: 'assignee' }
          );
        }

        const creatorProfileId = await resolveProfileId(task.creator_id);
        if (creatorProfileId) {
          await ensureNotification(
            creatorProfileId,
            'task_reminder',
            {
              task_id: task.id,
              title: task.title,
              kind: window.kind,
              role: 'creator',
              start_time: task.start_time,
            },
            { taskId: task.id, kind: window.kind, role: 'creator' }
          );
        }
      } else if (window.kind === '1h') {
        const creatorProfileId = await resolveProfileId(task.creator_id);
        if (creatorProfileId) {
          await ensureNotification(
            creatorProfileId,
            'task_unassigned_warning',
            {
              task_id: task.id,
              title: task.title,
              kind: window.kind,
              role: 'creator',
              start_time: task.start_time,
            },
            { taskId: task.id, kind: window.kind, role: 'creator' }
          );
        }
      }
    }
  }
}

async function fetchTaskWithLocation(taskId) {
  const result = await pool.query(
    `
    SELECT tasks.*,
           cities.name AS city_name,
           counties.name AS county_name,
           countries.name AS country_name
    FROM tasks
    LEFT JOIN cities ON cities.id = tasks.city_id
    LEFT JOIN counties ON counties.id = tasks.county_id
    LEFT JOIN countries ON countries.id = tasks.country_id
    WHERE tasks.id = $1
    LIMIT 1
  `,
    [taskId]
  );
  return result.rows[0];
}

function buildLocationLabel(row) {
  const addressPart = row.address ? row.address.toString() : '';
  const areaPart = [row.city_name, row.county_name, row.country_name]
    .filter(Boolean)
    .map((v) => v.toString())
    .join(', ');
  if (addressPart && areaPart) return `${addressPart}, ${areaPart}`;
  if (addressPart) return addressPart;
  if (areaPart) return areaPart;
  if (row.lat && row.lng) {
    return `Lat ${Number(row.lat).toFixed(3)}, Lng ${Number(row.lng).toFixed(3)}`;
  }
  return 'Locatie indisponibila';
}

function generateCode(length = 4) {
  const n = crypto.randomInt(0, 10 ** length);
  return n.toString().padStart(length, '0');
}

async function createVerificationCode({ userId, type, target, expiresMinutes = 10 }) {
  const code = generateCode(4);
  const expiresAt = new Date(Date.now() + expiresMinutes * 60_000);
  const result = await pool.query(
    `INSERT INTO verification_codes (user_id, type, target, code, expires_at)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [userId, type, target, code, expiresAt]
  );
  return result.rows[0];
}

async function verifyCode({ userId, type, code }) {
  const result = await pool.query(
    `SELECT * FROM verification_codes
     WHERE user_id = $1 AND type = $2 AND consumed_at IS NULL
       AND expires_at > NOW()
     ORDER BY created_at DESC
     LIMIT 1`,
    [userId, type]
  );

  if (result.rows.length === 0) {
    const err = new Error('Cod expirat sau inexistent');
    err.status = 400;
    throw err;
  }

  const entry = result.rows[0];
  if (entry.code !== code) {
    const err = new Error('Cod invalid');
    err.status = 400;
    throw err;
  }

  await pool.query(
    `UPDATE verification_codes
     SET consumed_at = NOW()
     WHERE id = $1`,
    [entry.id]
  );

  const column = type === 'email' ? 'email_verified_at' : 'phone_verified_at';
  await pool.query(
    `UPDATE users
     SET ${column} = NOW()
     WHERE id = $1`,
    [userId]
  );

  return entry;
}

const sanitizeUser = (row) => ({
  id: row.id,
  name: row.name,
  email: row.email,
  created_at: row.created_at,
  phone: row.phone || null,
  email_verified_at: row.email_verified_at,
  phone_verified_at: row.phone_verified_at,
});

async function createUser({ name, email, password, phone }) {
  if (!name || !email || !password) {
    const err = new Error('name, email si password sunt obligatorii');
    err.status = 400;
    throw err;
  }

  const normalizedEmail = email.trim().toLowerCase();
  if (!emailRegex.test(normalizedEmail)) {
    const err = new Error('Email invalid');
    err.status = 400;
    throw err;
  }

  const existing = await pool.query('SELECT id FROM users WHERE email = $1', [normalizedEmail]);
  if (existing.rows.length > 0) {
    const err = new Error('Email deja folosit');
    err.status = 409;
    throw err;
  }

  const passwordHash = await bcrypt.hash(password, 10);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query(
      `INSERT INTO users (name, email, password_hash, phone)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [name, normalizedEmail, passwordHash, phone || null]
    );
    const user = result.rows[0];

    await client.query(
      `INSERT INTO profile (user_id, full_name, email, phone, created_at, updated_at, rtg_avg)
       VALUES ($1, $2, $3, $4, NOW(), NOW(), 0)
       ON CONFLICT (user_id) DO NOTHING`,
      [user.id, user.name, user.email, user.phone || null]
    );

    await client.query('COMMIT');
    return user;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

app.post('/users', async (req, res) => {
  const { name, email, password, phone } = req.body;

  try {
    const created = await createUser({ name, email, password, phone });

    res.json(sanitizeUser(created));
  } catch (err) {
    console.error(err);
    res
      .status(err.status || 500)
      .json({ error: err.message || 'Insert failed' });
  }
});

app.get('/users', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, name, email, phone, created_at, email_verified_at, phone_verified_at
       FROM users ORDER BY id DESC`
    );
    res.json(result.rows.map(sanitizeUser));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Fetch failed' });
  }
});

app.post('/auth/register', async (req, res) => {
  const { name, email, password, phone } = req.body;
  try {
    const created = await createUser({ name, email, password, phone });
    res.json(sanitizeUser(created));
  } catch (err) {
    console.error(err);
    res
      .status(err.status || 500)
      .json({ error: err.message || 'Register failed' });
  }
});

app.post('/auth/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Email si parola sunt obligatorii' });
  }

  const normalizedEmail = email.trim().toLowerCase();
  if (!emailRegex.test(normalizedEmail)) {
    return res.status(400).json({ error: 'Email invalid' });
  }

  try {
    const result = await pool.query(
      'SELECT * FROM users WHERE LOWER(email) = LOWER($1) LIMIT 1',
      [normalizedEmail]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Utilizator inexistent' });
    }

    const user = result.rows[0];
    let isMatch = false;
    if (user.password_hash) {
      isMatch = await bcrypt.compare(password, user.password_hash);
    } else {
      // Compat: user creat fara parola_hash anterior. Setam acum hash-ul cu parola curenta.
      const newHash = await bcrypt.hash(password, 10);
      await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [
        newHash,
        user.id,
      ]);
      isMatch = true;
    }

    if (!isMatch) {
      return res.status(401).json({ error: 'Parola incorecta' });
    }

    res.json(sanitizeUser(user));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Login failed' });
  }
});

app.get('/business/:userId', async (req, res) => {
  const userId = Number(req.params.userId);
  if (!userId) {
    return res.status(400).json({ error: 'userId invalid' });
  }

  try {
    const profileId = await resolveProfileId(userId);
    if (!profileId) {
      return res.status(404).json({ error: 'Profil inexistent' });
    }

    const result = await pool.query(
      'SELECT * FROM business WHERE owner_profile_id = $1 LIMIT 1',
      [profileId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Business inexistent' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Fetch business failed' });
  }
});

app.get('/notifications/:userId/unread-count', async (req, res) => {
  const userId = Number(req.params.userId);
  if (!userId) {
    return res.status(400).json({ error: 'userId invalid' });
  }

  try {
    const profileId = await resolveProfileId(userId);
    if (!profileId) {
      return res.status(404).json({ error: 'Profil inexistent' });
    }
    const result = await pool.query(
      'SELECT COUNT(*)::int AS count FROM notifications WHERE profile_id = $1 AND is_read = FALSE',
      [profileId]
    );
    res.json({ count: result.rows[0]?.count ?? 0 });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Fetch notifications failed' });
  }
});

app.get('/notifications/:userId', async (req, res) => {
  const userId = Number(req.params.userId);
  if (!userId) {
    return res.status(400).json({ error: 'userId invalid' });
  }

  try {
    const profileId = await resolveProfileId(userId);
    if (!profileId) {
      return res.status(404).json({ error: 'Profil inexistent' });
    }
    const result = await pool.query(
      `SELECT id, profile_id, type, payload, is_read, created_at
       FROM notifications
       WHERE profile_id = $1
       ORDER BY created_at DESC
       LIMIT 100`,
      [profileId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Fetch notifications failed' });
  }
});

app.post('/notifications/:userId/mark-read', async (req, res) => {
  const userId = Number(req.params.userId);
  if (!userId) {
    return res.status(400).json({ error: 'userId invalid' });
  }

  try {
    const profileId = await resolveProfileId(userId);
    if (!profileId) {
      return res.status(404).json({ error: 'Profil inexistent' });
    }
    await pool.query(
      `UPDATE notifications
       SET is_read = TRUE
       WHERE profile_id = $1`,
      [profileId]
    );
    res.json({ ok: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Mark read failed' });
  }
});

app.post('/notifications/:userId/:notificationId/read', async (req, res) => {
  const userId = Number(req.params.userId);
  const notificationId = Number(req.params.notificationId);
  if (!userId || !notificationId) {
    return res.status(400).json({ error: 'userId sau notificationId invalid' });
  }

  try {
    const profileId = await resolveProfileId(userId);
    if (!profileId) {
      return res.status(404).json({ error: 'Profil inexistent' });
    }
    await pool.query(
      `UPDATE notifications
       SET is_read = TRUE
       WHERE id = $1 AND profile_id = $2`,
      [notificationId, profileId]
    );
    res.json({ ok: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Mark read failed' });
  }
});

app.delete('/business/:userId', async (req, res) => {
  const userId = Number(req.params.userId);
  if (!userId) {
    return res.status(400).json({ error: 'userId invalid' });
  }

  try {
    const profileId = await resolveProfileId(userId);
    if (!profileId) {
      return res.status(404).json({ error: 'Profil inexistent' });
    }

    await pool.query('DELETE FROM business WHERE owner_profile_id = $1', [
      profileId,
    ]);
    res.json({ deleted: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Delete business failed' });
  }
});

app.post('/business', async (req, res) => {
  const {
    user_id,
    category_id,
    name,
    description,
    address,
    city,
    country,
    website,
    email,
    phone,
  } = req.body;

  if (!user_id || !name) {
    return res.status(400).json({ error: 'user_id si name sunt obligatorii' });
  }

  try {
    const profileId = await resolveProfileId(Number(user_id));
    if (!profileId) {
      return res.status(404).json({ error: 'Profil inexistent' });
    }

    const existing = await pool.query(
      'SELECT id FROM business WHERE owner_profile_id = $1 LIMIT 1',
      [profileId]
    );

    const values = [
      profileId,
      category_id ?? null,
      name,
      description || null,
      address || null,
      city || null,
      country || null,
      website || null,
      email || null,
      phone || null,
    ];

    if (existing.rows.length > 0) {
      const updateRes = await pool.query(
        `UPDATE business
         SET category_id = $2,
             name = $3,
             description = $4,
             address = $5,
             city = $6,
             country = $7,
             website = $8,
             email = $9,
             phone = $10,
             updated_at = NOW()
         WHERE owner_profile_id = $1
         RETURNING *`,
        values
      );
      return res.json(updateRes.rows[0]);
    }

    const insertRes = await pool.query(
      `INSERT INTO business
       (owner_profile_id, category_id, name, description, address, city, country, website, email, phone, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW(), NOW())
       RETURNING *`,
      values
    );
    return res.json(insertRes.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Save business failed' });
  }
});

// Dev helper: reset parola pentru un email (overwrite hash)
app.post('/auth/reset-password', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ error: 'Email si parola sunt obligatorii' });
  }
  const normalizedEmail = email.trim().toLowerCase();
  if (!emailRegex.test(normalizedEmail)) {
    return res.status(400).json({ error: 'Email invalid' });
  }
  try {
    const result = await pool.query(
      'SELECT * FROM users WHERE LOWER(email) = LOWER($1) LIMIT 1',
      [normalizedEmail]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Utilizator inexistent' });
    }
    const newHash = await bcrypt.hash(password, 10);
    const updated = await pool.query(
      'UPDATE users SET password_hash = $1 WHERE id = $2 RETURNING *',
      [newHash, result.rows[0].id]
    );
    res.json(sanitizeUser(updated.rows[0]));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Reset parola a esuat' });
  }
});

app.post('/tasks', async (req, res) => {
  const {
    title,
    description,
    creator_id,
    price,
    lat,
    lng,
    estimated_duration_minutes,
    start_time,
    auto_assign_at,
    address,
    city_id,
    county_id,
    country_id,
  } = req.body;

  if (!title || !creator_id) {
    return res.status(400).json({ error: 'title si creator_id sunt obligatorii' });
  }

  try {
    const startTime = start_time ? new Date(start_time) : new Date();
    const autoAssignAt = auto_assign_at ? new Date(auto_assign_at) : startTime;

    const result = await pool.query(
      `INSERT INTO tasks
         (title, description, creator_id, price, lat, lng,
          estimated_duration_minutes, start_time, auto_assign_at,
          address, city_id, county_id, country_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
       RETURNING *`,
      [
        title,
        description || null,
        creator_id,
        price || null,
        lat || null,
        lng || null,
        estimated_duration_minutes || null,
        startTime,
        autoAssignAt,
        address || null,
        city_id || null,
        county_id || null,
        country_id || null,
      ]
    );
    const row = result.rows[0];
    res.json({
      ...row,
      status_label: statusLabels[row.status_id] || 'Necunoscut',
      location_label: buildLocationLabel(row),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Task insert failed' });
  }
});

app.get('/tasks', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT tasks.*,
             users.name AS creator_name,
             assignee.name AS assigned_name,
             cities.name AS city_name,
             counties.name AS county_name,
             countries.name AS country_name
      FROM tasks
      JOIN users ON users.id = tasks.creator_id
      LEFT JOIN users assignee ON assignee.id = tasks.assigned_user_id
      LEFT JOIN cities ON cities.id = tasks.city_id
      LEFT JOIN counties ON counties.id = tasks.county_id
      LEFT JOIN countries ON countries.id = tasks.country_id
      ORDER BY tasks.id DESC
    `);
    res.json(
      result.rows.map((row) => ({
        ...row,
        status_label: statusLabels[row.status_id] || 'Necunoscut',
        location_label: buildLocationLabel(row),
      }))
    );
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Fetch tasks failed' });
  }
});

app.get('/tasks/my/:userId', async (req, res) => {
  const { userId } = req.params;
  try {
    const result = await pool.query(
      `
      SELECT tasks.*,
             users.name AS creator_name,
             assignee.name AS assigned_name,
             cities.name AS city_name,
             counties.name AS county_name,
             countries.name AS country_name
      FROM tasks
      JOIN users ON users.id = tasks.creator_id
      LEFT JOIN users assignee ON assignee.id = tasks.assigned_user_id
      LEFT JOIN cities ON cities.id = tasks.city_id
      LEFT JOIN counties ON counties.id = tasks.county_id
      LEFT JOIN countries ON countries.id = tasks.country_id
      WHERE tasks.creator_id = $1 OR tasks.assigned_user_id = $1
      ORDER BY tasks.id DESC
    `,
      [userId]
    );
    res.json(
      result.rows.map((row) => ({
        ...row,
        status_label: statusLabels[row.status_id] || 'Necunoscut',
        location_label: buildLocationLabel(row),
      }))
    );
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Fetch my tasks failed' });
  }
});

app.post('/tasks/:id/accept', async (req, res) => {
  const { id } = req.params;
  const { user_id } = req.body;
  if (!user_id) {
    return res.status(400).json({ error: 'user_id obligatoriu' });
  }

  try {
    const result = await pool.query(
      `UPDATE tasks
       SET assigned_user_id = $1,
           status_id = 1
       WHERE id = $2
       RETURNING *`,
      [user_id, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Task inexistent' });
    }
    const row = await fetchTaskWithLocation(id);
    res.json({
      ...row,
      status_label: statusLabels[row.status_id] || 'Necunoscut',
      location_label: buildLocationLabel(row),
    });

    createTaskEventNotifications(id).catch((err) => {
      console.error('Notification error:', err);
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Accept task failed' });
  }
});

app.post('/tasks/:id/refuse', async (req, res) => {
  const { id } = req.params;
  const { user_id } = req.body;
  if (!user_id) {
    return res.status(400).json({ error: 'user_id obligatoriu' });
  }

  try {
    const result = await pool.query(
      `UPDATE tasks
       SET assigned_user_id = CASE WHEN assigned_user_id = $1 THEN NULL ELSE assigned_user_id END,
           status_id = 0
       WHERE id = $2
       RETURNING *`,
      [user_id, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Task inexistent' });
    }
    const row = await fetchTaskWithLocation(id);
    res.json({
      ...row,
      status_label: statusLabels[row.status_id] || 'Necunoscut',
      location_label: buildLocationLabel(row),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Refuse task failed' });
  }
});

app.post('/tasks/:id/status', async (req, res) => {
  const { id } = req.params;
  const { status_id, note } = req.body;
  if (status_id === undefined || status_id === null) {
    return res.status(400).json({ error: 'status_id obligatoriu' });
  }

  if (![0, 1, 2, 3, 4, 5].includes(Number(status_id))) {
    return res.status(400).json({ error: 'status_id trebuie sa fie 0-5' });
  }

  try {
    try {
      await pool.query(
        `UPDATE tasks
         SET status_id = $1,
             status_note = COALESCE($2, status_note)
         WHERE id = $3`,
        [status_id, note || null, id]
      );
    } catch (err) {
      // Fallback if status_note column does not exist
      if (err.message && err.message.includes('status_note')) {
        await pool.query(
          `UPDATE tasks
           SET status_id = $1
           WHERE id = $2`,
          [status_id, id]
        );
      } else {
        throw err;
      }
    }

    const row = await fetchTaskWithLocation(id);
    if (!row) {
      return res.status(404).json({ error: 'Task inexistent' });
    }

    res.json({
      ...row,
      status_label: statusLabels[row.status_id] || 'Necunoscut',
      location_label: buildLocationLabel(row),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Update status failed' });
  }
});

app.post('/tasks/:id/reviews', async (req, res) => {
  const { id } = req.params;
  const { author_id, target_id, rating, comment } = req.body;

  if (!author_id || !rating) {
    return res
      .status(400)
      .json({ error: 'author_id si rating sunt obligatorii' });
  }

  if (rating < 1 || rating > 5) {
    return res.status(400).json({ error: 'Rating invalid (1-5)' });
  }

  try {
    const taskRes = await pool.query(
      'SELECT id, creator_id, assigned_user_id, status_id FROM tasks WHERE id = $1',
      [id]
    );
    if (taskRes.rows.length === 0) {
      return res.status(404).json({ error: 'Task inexistent' });
    }
    const task = taskRes.rows[0];

    if (Number(task.status_id) !== 3) {
      return res.status(400).json({ error: 'Taskul nu este finalizat' });
    }

    if (!task.assigned_user_id) {
      return res.status(400).json({ error: 'Taskul nu are executant asignat' });
    }

    if (Number(author_id) !== Number(task.creator_id)) {
      return res.status(403).json({ error: 'Doar creatorul poate lasa review' });
    }

    if (target_id && Number(target_id) !== Number(task.assigned_user_id)) {
      return res.status(400).json({ error: 'Destinatar invalid pentru acest task' });
    }

    const result = await pool.query(
      `INSERT INTO task_reviews (task_id, author_id, target_id, rating, comment)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [id, author_id, task.assigned_user_id, rating, comment || null]
    );

    const avgRes = await pool.query(
      `SELECT COALESCE(AVG(rating), 0) AS avg_rating
       FROM task_reviews
       WHERE target_id = $1`,
      [task.assigned_user_id]
    );
    await pool.query(
      `UPDATE profile
       SET rtg_avg = $1
       WHERE user_id = $2`,
      [avgRes.rows[0].avg_rating, task.assigned_user_id]
    );

    res.json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Review deja trimis pentru acest task' });
    }
    console.error(err);
    res.status(500).json({ error: 'Review save failed' });
  }
});

app.get('/tasks/:id/reviews', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `SELECT tr.*,
              pa.full_name AS author_name,
              pt.full_name AS target_name
       FROM task_reviews tr
       LEFT JOIN profile pa ON pa.user_id = tr.author_id
       LEFT JOIN profile pt ON pt.user_id = tr.target_id
       WHERE tr.task_id = $1
       ORDER BY tr.id DESC`,
      [id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Fetch reviews failed' });
  }
});


app.get('/', async (req, res) => {
  try {
    const result = await pool.query('SELECT NOW()');
    res.json({
      status: 'Backend + DB alive',
      time: result.rows[0].now,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'DB connection failed' });
  }
});

app.listen(3000, '127.0.0.1', () => {
  console.log('Server running on http://localhost:3000');
});

const NOTIFICATION_INTERVAL_MS = 5 * 60 * 1000;
setInterval(() => {
  createReminderNotifications().catch((err) => {
    console.error('Reminder notifications error:', err);
  });
}, NOTIFICATION_INTERVAL_MS);
createReminderNotifications().catch((err) => {
  console.error('Reminder notifications error:', err);
});

/**
 * EMAIL + PHONE verification endpoints
 * These are "dev" friendly: codes are returned in response for easy testing.
 */
app.post('/verify/send-email', async (req, res) => {
  const { user_id, email } = req.body;
  if (!user_id || !email) {
    return res.status(400).json({ error: 'user_id si email sunt obligatorii' });
  }
  if (!emailRegex.test(email.trim().toLowerCase())) {
    return res.status(400).json({ error: 'Email invalid' });
  }

  try {
    const userRes = await pool.query('SELECT id FROM users WHERE id = $1', [user_id]);
    if (userRes.rows.length === 0) {
      return res.status(404).json({ error: 'User inexistent' });
    }

    const codeEntry = await createVerificationCode({
      userId: user_id,
      type: 'email',
      target: email.trim().toLowerCase(),
    });

    res.json({
      message: 'Cod email generat (dev mode)',
      code: codeEntry.code,
      expires_at: codeEntry.expires_at,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Nu am putut trimite codul' });
  }
});

app.post('/verify/check-email', async (req, res) => {
  const { user_id, code } = req.body;
  if (!user_id || !code) {
    return res.status(400).json({ error: 'user_id si code sunt obligatorii' });
  }
  try {
    await verifyCode({ userId: user_id, type: 'email', code });
    res.json({ message: 'Email verificat' });
  } catch (err) {
    console.error(err);
    res.status(err.status || 500).json({ error: err.message || 'Verificare esuata' });
  }
});

app.post('/verify/send-phone', async (req, res) => {
  const { user_id, phone } = req.body;
  if (!user_id || !phone) {
    return res.status(400).json({ error: 'user_id si phone sunt obligatorii' });
  }

  try {
    const userRes = await pool.query('SELECT id FROM users WHERE id = $1', [user_id]);
    if (userRes.rows.length === 0) {
      return res.status(404).json({ error: 'User inexistent' });
    }

    const codeEntry = await createVerificationCode({
      userId: user_id,
      type: 'phone',
      target: phone,
    });

    res.json({
      message: 'Cod telefon generat (dev mode)',
      code: codeEntry.code,
      expires_at: codeEntry.expires_at,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Nu am putut trimite codul' });
  }
});

app.post('/verify/check-phone', async (req, res) => {
  const { user_id, code } = req.body;
  if (!user_id || !code) {
    return res.status(400).json({ error: 'user_id si code sunt obligatorii' });
  }
  try {
    await verifyCode({ userId: user_id, type: 'phone', code });
    res.json({ message: 'Telefon verificat' });
  } catch (err) {
    console.error(err);
    res.status(err.status || 500).json({ error: err.message || 'Verificare esuata' });
  }
});
