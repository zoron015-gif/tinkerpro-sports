require('dotenv').config();

const bcrypt = require('bcryptjs');
const cors = require('cors');
const crypto = require('crypto');
const express = require('express');
const jwt = require('jsonwebtoken');
const pool = require('./db');
const { sendPasswordResetCode, sendVerificationCode } = require('./mailer');

const app = express();
const port = Number(process.env.PORT || 3000);
const googleClientId = process.env.GOOGLE_CLIENT_ID ||
  '451592121635-f7hgfk7plbi3mngvor1eenrup21mlbg5.apps.googleusercontent.com';

if (!process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET must be set in the backend .env file.');
}

app.use(cors({ origin: process.env.CLIENT_ORIGIN || true }));
app.use(express.json({ limit: '20kb' }));

function normalizeEmail(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function isValidRole(role) {
  return role === 'customer' || role === 'merchant';
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

function createVerificationCode() {
  return String(crypto.randomInt(100000, 1000000));
}

function hashVerificationCode(code) {
  return crypto.createHash('sha256').update(code).digest('hex');
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
  const role = req.body.role || 'customer';
  const firstName = typeof req.body.firstName === 'string' ? req.body.firstName.trim() : null;
  const lastName = typeof req.body.lastName === 'string' ? req.body.lastName.trim() : null;

  if (!email || !email.includes('@') || typeof password !== 'string' || password.length < 8) {
    return res.status(400).json({ error: 'A valid email and password of at least 8 characters are required.' });
  }
  if (role !== undefined && !isValidRole(role)) {
    return res.status(400).json({ error: 'Role must be customer or merchant.' });
  }

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [existing] = await connection.execute(
      'SELECT id, status FROM users WHERE email = ? LIMIT 1',
      [email],
    );
    if (existing.length > 0) {
      if (existing[0].status !== 'pending') {
        await connection.rollback();
        return res.status(409).json({ error: 'An account with this email already exists.' });
      }

      const passwordHash = await bcrypt.hash(password, 12);
      await connection.execute(
        `UPDATE users
         SET password_hash = ?, role = ?, status = 'pending',
             email_verified_at = NULL
         WHERE id = ?`,
        [passwordHash, role, existing[0].id],
      );
      await connection.execute(
        `UPDATE email_verification_tokens
         SET used_at = CURRENT_TIMESTAMP
         WHERE user_id = ? AND used_at IS NULL`,
        [existing[0].id],
      );

      const code = createVerificationCode();
      await connection.execute(
        `INSERT INTO email_verification_tokens
         (user_id, token_hash, expires_at)
         VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 10 MINUTE))`,
        [existing[0].id, hashVerificationCode(code)],
      );
      await sendVerificationCode(email, code);
      await connection.commit();

      return res.status(200).json({
        message: 'Registration restarted. Check your email for the new verification code.',
        user: publicUser({
          id: existing[0].id,
          email,
          first_name: null,
          last_name: null,
          role,
          status: 'pending',
        }),
      });
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const [result] = await connection.execute(
      `INSERT INTO users
       (email, password_hash, first_name, last_name, role, status, email_verified_at)
       VALUES (?, ?, ?, ?, ?, 'pending', NULL)`,
      [email, passwordHash, firstName, lastName, role],
    );
    const code = createVerificationCode();
    await connection.execute(
      `INSERT INTO email_verification_tokens
       (user_id, token_hash, expires_at)
       VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 10 MINUTE))`,
      [result.insertId, hashVerificationCode(code)],
    );
    await sendVerificationCode(email, code);
    await connection.commit();

    const user = { id: result.insertId, email, first_name: firstName, last_name: lastName, role, status: 'pending' };
    return res.status(201).json({
      message: 'Registration successful. Check your email for the verification code.',
      user: publicUser(user),
    });
  } catch (error) {
    if (connection) {
      await connection.rollback();
    }
    return next(error);
  } finally {
    connection?.release();
  }
});

app.post('/api/auth/verify-email', async (req, res, next) => {
  const email = normalizeEmail(req.body.email);
  const code = typeof req.body.code === 'string' ? req.body.code.trim() : '';

  if (!email || !/^\d{6}$/.test(code)) {
    return res.status(400).json({ error: 'A valid email and 6-digit verification code are required.' });
  }

  try {
    const [rows] = await pool.execute(
      `SELECT t.id AS token_id, t.token_hash, u.id, u.email, u.first_name, u.last_name, u.role
       FROM email_verification_tokens t
       INNER JOIN users u ON u.id = t.user_id
       WHERE u.email = ? AND t.used_at IS NULL AND t.expires_at > NOW()
       ORDER BY t.created_at DESC LIMIT 1`,
      [email],
    );
    const token = rows[0];
    if (!token || token.token_hash !== hashVerificationCode(code)) {
      return res.status(400).json({ error: 'The verification code is invalid or expired.' });
    }

    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();
      await connection.execute('UPDATE users SET status = ?, email_verified_at = CURRENT_TIMESTAMP WHERE id = ?', ['active', token.id]);
      await connection.execute('UPDATE email_verification_tokens SET used_at = CURRENT_TIMESTAMP WHERE id = ?', [token.token_id]);
      await connection.commit();
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
    const user = { ...token, status: 'active' };
    return res.json({ message: 'Email verified successfully.', user: publicUser(user), token: createToken(user) });
  } catch (error) {
    return next(error);
  }
});

app.post('/api/auth/resend-verification', async (req, res, next) => {
  const email = normalizeEmail(req.body.email);
  if (!email) {
    return res.status(400).json({ error: 'Email is required.' });
  }

  let connection;
  try {
    connection = await pool.getConnection();
    const [users] = await connection.execute(
      `SELECT id FROM users
       WHERE email = ? AND status = 'pending' AND email_verified_at IS NULL
       LIMIT 1`,
      [email],
    );
    if (users.length === 0) {
      return res.status(404).json({ error: 'No pending account was found for this email.' });
    }

    const code = createVerificationCode();
    await connection.beginTransaction();
    await connection.execute(
      `UPDATE email_verification_tokens
       SET used_at = CURRENT_TIMESTAMP
       WHERE user_id = ? AND used_at IS NULL`,
      [users[0].id],
    );
    await connection.execute(
      `INSERT INTO email_verification_tokens
       (user_id, token_hash, expires_at)
       VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 10 MINUTE))`,
      [users[0].id, hashVerificationCode(code)],
    );
    await sendVerificationCode(email, code);
    await connection.commit();
    return res.json({ message: 'A new verification code was sent.' });
  } catch (error) {
    if (connection) {
      await connection.rollback();
    }
    return next(error);
  } finally {
    connection?.release();
  }
});

app.post('/api/auth/forgot-password', async (req, res, next) => {
  const email = normalizeEmail(req.body.email);
  if (!email || !email.includes('@')) {
    return res.status(400).json({ error: 'A valid email is required.' });
  }

  let connection;
  try {
    connection = await pool.getConnection();
    const [users] = await connection.execute(
      'SELECT id FROM users WHERE email = ? AND status != ? LIMIT 1',
      [email, 'deleted'],
    );
    if (users.length === 0) {
      return res.status(404).json({ error: 'No account was found for this email.' });
    }

    const code = createVerificationCode();
    await connection.beginTransaction();
    await connection.execute(
      `UPDATE password_reset_tokens
       SET used_at = CURRENT_TIMESTAMP
       WHERE user_id = ? AND used_at IS NULL`,
      [users[0].id],
    );
    await connection.execute(
      `INSERT INTO password_reset_tokens
       (user_id, token_hash, expires_at)
       VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 10 MINUTE))`,
      [users[0].id, hashVerificationCode(code)],
    );
    await sendPasswordResetCode(email, code);
    await connection.commit();
    return res.json({ message: 'A password reset code was sent to your email.' });
  } catch (error) {
    if (connection) await connection.rollback();
    return next(error);
  } finally {
    connection?.release();
  }
});

app.post('/api/auth/reset-password', async (req, res, next) => {
  const email = normalizeEmail(req.body.email);
  const code = typeof req.body.code === 'string' ? req.body.code.trim() : '';
  const password = req.body.password;
  if (!email || !/^\d{6}$/.test(code) ||
      typeof password !== 'string' || password.length < 8) {
    return res.status(400).json({
      error: 'Email, a 6-digit code, and a password of at least 8 characters are required.',
    });
  }

  let connection;
  try {
    connection = await pool.getConnection();
    const [tokens] = await connection.execute(
      `SELECT t.id AS token_id, t.token_hash, u.id AS user_id
       FROM password_reset_tokens t
       INNER JOIN users u ON u.id = t.user_id
       WHERE u.email = ? AND t.used_at IS NULL AND t.expires_at > NOW()
       ORDER BY t.created_at DESC LIMIT 1`,
      [email],
    );
    const token = tokens[0];
    if (!token || token.token_hash !== hashVerificationCode(code)) {
      return res.status(400).json({ error: 'The password reset code is invalid or expired.' });
    }

    const passwordHash = await bcrypt.hash(password, 12);
    await connection.beginTransaction();
    await connection.execute(
      'UPDATE users SET password_hash = ?, status = ?, email_verified_at = COALESCE(email_verified_at, CURRENT_TIMESTAMP) WHERE id = ?',
      [passwordHash, 'active', token.user_id],
    );
    await connection.execute(
      'UPDATE password_reset_tokens SET used_at = CURRENT_TIMESTAMP WHERE id = ?',
      [token.token_id],
    );
    await connection.commit();
    return res.json({ message: 'Your password has been changed. You can now sign in.' });
  } catch (error) {
    if (connection) await connection.rollback();
    return next(error);
  } finally {
    connection?.release();
  }
});

app.post('/api/auth/verify-password-reset-code', async (req, res, next) => {
  const email = normalizeEmail(req.body.email);
  const code = typeof req.body.code === 'string' ? req.body.code.trim() : '';
  if (!email || !/^\d{6}$/.test(code)) {
    return res.status(400).json({
      error: 'A valid email and 6-digit verification code are required.',
    });
  }

  try {
    const [tokens] = await pool.execute(
      `SELECT t.token_hash
       FROM password_reset_tokens t
       INNER JOIN users u ON u.id = t.user_id
       WHERE u.email = ? AND t.used_at IS NULL AND t.expires_at > NOW()
       ORDER BY t.created_at DESC LIMIT 1`,
      [email],
    );
    const token = tokens[0];
    if (!token || token.token_hash !== hashVerificationCode(code)) {
      return res.status(400).json({
        error: 'The password reset code is invalid or expired.',
      });
    }
    return res.json({ message: 'Verification code accepted.' });
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

// Google OAuth: verify ID token from client and create or find user
app.post('/api/auth/oauth/google', async (req, res, next) => {
  const idToken = req.body.idToken || req.body.id_token;
  const role = typeof req.body.role === 'string'
    ? req.body.role.trim().toLowerCase()
    : undefined;
  if (!idToken || typeof idToken !== 'string') {
    return res.status(400).json({ error: 'idToken is required.' });
  }
  if (role !== undefined && !isValidRole(role)) {
    return res.status(400).json({ error: 'Role must be customer or merchant.' });
  }

  try {
    // Use Google's tokeninfo endpoint to validate the ID token. This avoids adding a new dependency.
    const verifyUrl = `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`;
    const resp = await fetch(verifyUrl);
    if (!resp.ok) {
      return res.status(400).json({ error: 'Invalid Google ID token.' });
    }
    const payload = await resp.json();

    if (payload.aud !== googleClientId) {
      return res.status(400).json({ error: 'Google ID token was not issued for this application.' });
    }

    // Require verified email
    const emailVerified = payload.email_verified === true || payload.email_verified === 'true';
    if (!payload.email || !emailVerified) {
      return res.status(400).json({ error: 'Google account email is not verified.' });
    }

    const email = normalizeEmail(payload.email);
    const firstName = payload.given_name || null;
    const lastName = payload.family_name || null;
    const providerUserId = typeof payload.sub === 'string' ? payload.sub : '';
    if (!providerUserId) {
      return res.status(400).json({ error: 'Google ID token has no subject.' });
    }

    // Find or create the user
    const [rows] = await pool.execute(
      `SELECT id, email, first_name, last_name, role, status
       FROM users WHERE email = ? LIMIT 1`,
      [email],
    );

    let user;
    if (rows.length === 0) {
      if (!role) {
        return res.status(409).json({
          code: 'role_required',
          error: 'Choose customer or merchant for this Google account.',
        });
      }
      // Create a new user with active status and no password
      const connection = await pool.getConnection();
      try {
        await connection.beginTransaction();
        const [result] = await connection.execute(
          `INSERT INTO users
           (email, password_hash, first_name, last_name, role, status, email_verified_at)
           VALUES (?, NULL, ?, ?, ?, 'active', CURRENT_TIMESTAMP)`,
          [email, firstName, lastName, role],
        );
        await connection.commit();
        user = { id: result.insertId, email, first_name: firstName, last_name: lastName, role, status: 'active' };
      } catch (err) {
        await connection.rollback();
        throw err;
      } finally {
        connection.release();
      }
    } else {
      user = rows[0];
      if (!isValidRole(user.role)) {
        if (!role) {
          return res.status(409).json({
            code: 'role_required',
            error: 'Choose customer or merchant for this Google account.',
          });
        }
        await pool.execute('UPDATE users SET role = ? WHERE id = ?', [
          role,
          user.id,
        ]);
        user.role = role;
      }
      // A Google account keeps the role chosen when it was first created.
      // The role sent by a later login is intentionally ignored.
      // If account exists but is not active, activate it (social sign-ins typically verify email)
      if (user.status !== 'active') {
        await pool.execute('UPDATE users SET status = ?, email_verified_at = CURRENT_TIMESTAMP WHERE id = ?', ['active', user.id]);
        user.status = 'active';
      }
    }

    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();
      await connection.execute(
        'UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE id = ?',
        [user.id],
      );
      await connection.execute(
        `INSERT INTO user_identities
         (user_id, provider, provider_user_id, provider_email, last_used_at)
         VALUES (?, 'google', ?, ?, CURRENT_TIMESTAMP)
         ON DUPLICATE KEY UPDATE
           user_id = VALUES(user_id),
           provider_email = VALUES(provider_email),
           last_used_at = CURRENT_TIMESTAMP`,
        [user.id, providerUserId, email],
      );
      await connection.commit();
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
    return res.json({ user: publicUser(user), token: createToken(user) });
  } catch (error) {
    return next(error);
  }
});

app.use((error, req, res, next) => {
  console.error(error);
  if (
    error.code === 'EAUTH' ||
    error.code === 'ESOCKET' ||
    error.code === 'ECONNECTION' ||
    error.responseCode === 535
  ) {
    return res.status(503).json({
      error:
        'We could not send the verification email. Check that SMTP_USER is the Gmail sender address and SMTP_APP_PASSWORD is a valid 16-character Gmail app password.',
    });
  }
  return res.status(500).json({ error: 'An unexpected server error occurred.' });
});

app.listen(port, () => {
  console.log(`TinkerPro Sports API listening on http://localhost:${port}`);
});
