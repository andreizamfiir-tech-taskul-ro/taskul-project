require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');



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

app.post('/users', async (req, res) => {
  const { name, email } = req.body;

  try {
    const result = await pool.query(
      'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *',
      [name, email]
    );

    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Insert failed' });
  }
});

app.get('/users', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM users ORDER BY id DESC');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Fetch failed' });
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
