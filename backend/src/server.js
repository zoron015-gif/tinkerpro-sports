require('dotenv').config();

const bcrypt = require('bcryptjs');
const cors = require('cors');
const express = require('express');
const jwt = require('jsonwebtoken');
const pool = require('./db');

const app = express();
const port = Number(process.env.PORT || 3000);

if (!process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET must be set in the backend .env file.');
}

app.use(cors({ origin: process.env.CLIENT_ORIGIN || true }));
app.use(express.json({ limit: '20kb' }));

function normalizeEmail(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function isValidRole(role) {
  return role === 'user' || role === 'merchant';
}

function createToken(user) {
  return jwt.sign(
    { sub: String(user.id), email: user.email, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' },
  );
}

function publicUser(user) {
  return {
    id: user.id,
    email: user.email,
    firstName: user.first_name,
    lastName: user.last_name,
    role: user.role,
    status: user.status,
  };
}

function requireAuth(req, res, next) {
  const header = req.get('authorization') || '';
  const [scheme, value] = header.split(' ');

  if (scheme !== 'Bearer' || !value) {
    return res.status(401).json({ error: 'A Bearer token is required.' });
  }

  try {
    req.auth = jwt.verify(value, process.env.JWT_SECRET);
    return next();
  } catch (error) {
    return res.status(401).json({ error: 'The access token is invalid or expired.' });
  }
}

app.get('/health', async (req, res, next) => {
  try {
    await pool.query('SELECT 1');
    return res.json({ status: 'ok', database: 'connected' });
  } catch (error) {
    return next(error);
  }
});

app.post('/api/auth/register', async (req, res, next) => {
  const email = normalizeEmail(req.body.email);
  const password = req.body.password;
  const role = req.body.role || 'user';
  const firstName = typeof req.body.firstName === 'string' ? req.body.firstName.trim() : null;
  const lastName = typeof req.body.lastName === 'string' ? req.body.lastName.trim() : null;

  if (!email || !email.includes('@') || typeof password !== 'string' || password.length < 8) {
    return res.status(400).json({ error: 'A valid email and password of at least 8 characters are required.' });
  }
  if (!isValidRole(role)) {
    return res.status(400).json({ error: 'Role must be user or merchant.' });
  }

  try {
    const [existing] = await pool.execute('SELECT id FROM users WHERE email = ? LIMIT 1', [email]);
    if (existing.length > 0) {
      return res.status(409).json({ error: 'An account with this email already exists.' });
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const [result] = await pool.execute(
      `INSERT INTO users
       (email, password_hash, first_name, last_name, role, status, email_verified_at)
       VALUES (?, ?, ?, ?, ?, 'active', NULL)`,
      [email, passwordHash, firstName, lastName, role],
    );
    const user = { id: result.insertId, email, first_name: firstName, last_name: lastName, role, status: 'active' };
    return res.status(201).json({ user: publicUser(user), token: createToken(user) });
  } catch (error) {
    return next(error);
  }
});

app.post('/api/auth/login', async (req, res, next) => {
  const email = normalizeEmail(req.body.email);
  const password = req.body.password;

  if (!email || typeof password !== 'string') {
    return res.status(400).json({ error: 'Email and password are required.' });
  }

  try {
    const [rows] = await pool.execute(
      `SELECT id, email, password_hash, first_name, last_name, role, status
       FROM users WHERE email = ? LIMIT 1`,
      [email],
    );
    const user = rows[0];
    const passwordMatches = user?.password_hash
      ? await bcrypt.compare(password, user.password_hash)
      : false;

    if (!user || !passwordMatches) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }
    if (user.status !== 'active') {
      return res.status(403).json({ error: `This account is ${user.status}.` });
    }

    await pool.execute('UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE id = ?', [user.id]);
    return res.json({ user: publicUser(user), token: createToken(user) });
  } catch (error) {
    return next(error);
  }
});

app.get('/api/auth/me', requireAuth, async (req, res, next) => {
  try {
    const [rows] = await pool.execute(
      `SELECT id, email, first_name, last_name, role, status
       FROM users WHERE id = ? LIMIT 1`,
      [req.auth.sub],
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: 'User account not found.' });
    }
    return res.json({ user: publicUser(rows[0]) });
  } catch (error) {
    return next(error);
  }
});

app.use((error, req, res, next) => {
  console.error(error);
  return res.status(500).json({ error: 'An unexpected server error occurred.' });
});

app.listen(port, () => {
  console.log(`TinkerPro Sports API listening on http://localhost:${port}`);
});
