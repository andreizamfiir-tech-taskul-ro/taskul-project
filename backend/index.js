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

const emailRegex =
  /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i;

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

  const result = await pool.query(
    `INSERT INTO users (name, email, password_hash, phone)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [name, normalizedEmail, passwordHash, phone || null]
  );
  return result.rows[0];
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
  const { title, description, creator_id } = req.body;

  try {
    const result = await pool.query(
      'INSERT INTO tasks (title, description, creator_id) VALUES ($1, $2, $3) RETURNING *',
      [title, description, creator_id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Task insert failed' });
  }
});

app.get('/tasks', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT tasks.*, users.name AS creator_name
      FROM tasks
      JOIN users ON users.id = tasks.creator_id
      ORDER BY tasks.id DESC
    `);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Fetch tasks failed' });
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

app.listen(3000, () => {
  console.log('Server running on http://localhost:3000');
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
