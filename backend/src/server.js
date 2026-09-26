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
app.use(express.json({ limit: '20mb' }));

function normalizeEmail(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function normalizeText(value, max = 255) {
  return typeof value === 'string' ? value.trim().slice(0, max) : '';
}

function parseBusinessCoordinates(body) {
  const hasLatitude = Object.prototype.hasOwnProperty.call(body, 'latitude');
  const hasLongitude = Object.prototype.hasOwnProperty.call(body, 'longitude');
  if (!hasLatitude && !hasLongitude) {
    return { provided: false, valid: true, latitude: null, longitude: null };
  }
  const rawLatitude = body.latitude;
  const rawLongitude = body.longitude;
  if (
    (rawLatitude === null || rawLatitude === '') &&
    (rawLongitude === null || rawLongitude === '')
  ) {
    return { provided: true, valid: true, latitude: null, longitude: null };
  }
  const latitude = Number(rawLatitude);
  const longitude = Number(rawLongitude);
  const valid =
    Number.isFinite(latitude) &&
    latitude >= -90 &&
    latitude <= 90 &&
    Number.isFinite(longitude) &&
    longitude >= -180 &&
    longitude <= 180;
  return {
    provided: true,
    valid,
    latitude: valid ? latitude : null,
    longitude: valid ? longitude : null,
  };
}

function eventDetailsFromBody(body) {
  const list = (value) =>
    Array.isArray(value)
      ? value.filter((item) => typeof item === 'string').slice(0, 20)
      : [];
  const integer = (value) => {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
  };
  return {
    eventTypes: list(body.eventTypes),
    attendanceMin: integer(body.attendanceMin),
    attendanceMax: integer(body.attendanceMax),
    accessibilityNeeds: list(body.accessibilityNeeds),
    parkingNeeds: list(body.parkingNeeds),
    securityNeeds: list(body.securityNeeds),
  };
}

async function saveEventDetails(businessId, body) {
  if (body.businessType !== 'Event') {
    await pool.execute(
      'DELETE FROM event_business_details WHERE business_id = ?',
      [businessId],
    );
    return;
  }
  const details = eventDetailsFromBody(body);
  await pool.execute(
    `INSERT INTO event_business_details
       (business_id, event_types_json, attendance_min, attendance_max,
        accessibility_needs, parking_needs, security_needs)
     VALUES (?, ?, ?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
       event_types_json = VALUES(event_types_json),
       attendance_min = VALUES(attendance_min),
       attendance_max = VALUES(attendance_max),
       accessibility_needs = VALUES(accessibility_needs),
       parking_needs = VALUES(parking_needs),
       security_needs = VALUES(security_needs)`,
    [
      businessId,
      JSON.stringify(details.eventTypes),
      details.attendanceMin,
      details.attendanceMax,
      JSON.stringify(details.accessibilityNeeds),
      JSON.stringify(details.parkingNeeds),
      JSON.stringify(details.securityNeeds),
    ],
  );
}

function parseJsonArray(value) {
  if (Array.isArray(value)) return value;
  if (typeof value !== 'string' || value.trim() === '') return [];
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
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
    phone: user.phone || null,
    avatarUrl: user.avatar_url || null,
    address: user.address || null,
    hobby: user.hobby || null,
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

function createBookingToken() {
  return crypto.randomBytes(18).toString('hex').toUpperCase();
}

function hashBookingToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function publicMessageUser(user) {
  return {
    id: user.id,
    email: user.email,
    firstName: user.first_name,
    lastName: user.last_name,
    phone: user.phone || null,
    avatarUrl: user.avatar_url || null,
    role: user.role,
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

app.patch('/api/messages/conversations/:id/state', requireAuth, async (req, res, next) => {
  const conversationId = Number(req.params.id);
  if (!Number.isSafeInteger(conversationId) || conversationId <= 0) {
    return res.status(400).json({ error: 'The conversation is invalid.' });
  }
  const hasArchived = typeof req.body.archived === 'boolean';
  const hasUnread = typeof req.body.unread === 'boolean';
  if (!hasArchived && !hasUnread) {
    return res.status(400).json({ error: 'A valid conversation state is required.' });
  }
  try {
    const [members] = await pool.execute(
      `SELECT conversation_id FROM conversation_members
       WHERE conversation_id = ? AND user_id = ? AND deleted_at IS NULL`,
      [conversationId, req.auth.sub],
    );
    if (members.length === 0) {
      return res.status(404).json({ error: 'Conversation not found.' });
    }
    const updates = [];
    const values = [];
    if (hasArchived) {
      updates.push('archived_at = ?');
      values.push(req.body.archived ? new Date() : null);
    }
    if (hasUnread) {
      updates.push('manually_unread_at = ?');
      values.push(req.body.unread ? new Date() : null);
    }
    values.push(conversationId, req.auth.sub);
    await pool.execute(
      `UPDATE conversation_members SET ${updates.join(', ')}
       WHERE conversation_id = ? AND user_id = ?`,
      values,
    );
    if (req.body.unread === false) {
      await pool.execute(
        `INSERT IGNORE INTO message_reads (message_id, user_id)
         SELECT id, ? FROM messages
         WHERE conversation_id = ? AND sender_id <> ?`,
        [req.auth.sub, conversationId, req.auth.sub],
      );
    }
    return res.json({ message: 'Conversation updated.' });
  } catch (error) {
    return next(error);
  }
});

app.delete('/api/messages/conversations/:id', requireAuth, async (req, res, next) => {
  const conversationId = Number(req.params.id);
  if (!Number.isSafeInteger(conversationId) || conversationId <= 0) {
    return res.status(400).json({ error: 'The conversation is invalid.' });
  }
  try {
    const [result] = await pool.execute(
      `UPDATE conversation_members SET deleted_at = CURRENT_TIMESTAMP
       WHERE conversation_id = ? AND user_id = ? AND deleted_at IS NULL`,
      [conversationId, req.auth.sub],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Conversation not found.' });
    }
    return res.json({ message: 'Conversation deleted for you.' });
  } catch (error) {
    return next(error);
  }
});

app.post('/api/messages/blocks/:userId', requireAuth, async (req, res, next) => {
  const blockedUserId = Number(req.params.userId);
  if (!Number.isSafeInteger(blockedUserId) ||
      blockedUserId <= 0 ||
      blockedUserId === Number(req.auth.sub)) {
    return res.status(400).json({ error: 'The user to block is invalid.' });
  }
  try {
    const [users] = await pool.execute(
      `SELECT id FROM users WHERE id = ? AND status = 'active' LIMIT 1`,
      [blockedUserId],
    );
    if (users.length === 0) {
      return res.status(404).json({ error: 'User not found.' });
    }
    await pool.execute(
      `INSERT IGNORE INTO user_blocks (blocker_id, blocked_user_id)
       VALUES (?, ?)`,
      [req.auth.sub, blockedUserId],
    );
    return res.json({ message: 'User blocked.' });
  } catch (error) {
    return next(error);
  }
});

app.delete('/api/messages/blocks/:userId', requireAuth, async (req, res, next) => {
  const blockedUserId = Number(req.params.userId);
  if (!Number.isSafeInteger(blockedUserId) || blockedUserId <= 0) {
    return res.status(400).json({ error: 'The user to unblock is invalid.' });
  }
  try {
    await pool.execute(
      `DELETE FROM user_blocks WHERE blocker_id = ? AND blocked_user_id = ?`,
      [req.auth.sub, blockedUserId],
    );
    return res.json({ message: 'User unblocked.' });
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
      `SELECT id, email, first_name, last_name, phone, avatar_url, address, hobby, role, status
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

app.put('/api/auth/profile', requireAuth, async (req, res, next) => {
  const firstName = normalizeText(req.body.firstName, 100);
  const lastName = normalizeText(req.body.lastName, 100);
  const phone = normalizeText(req.body.phone, 30);
  const address = normalizeText(req.body.address, 500);
  const hobby = normalizeText(req.body.hobby, 255);
  const avatarUrl = normalizeText(req.body.avatarUrl, 10 * 1024 * 1024);
  if (!firstName) {
    return res.status(400).json({ error: 'First name is required.' });
  }

  try {
    await pool.execute(
      'UPDATE users SET first_name = ?, last_name = ?, phone = ?, address = ?, hobby = ?, avatar_url = ? WHERE id = ?',
      [firstName, lastName || null, phone || null, address || null, hobby || null, avatarUrl || null, req.auth.sub],
    );
    const [rows] = await pool.execute(
      `SELECT id, email, first_name, last_name, phone, avatar_url, address, hobby, role, status
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

app.get('/api/messages/owner', requireAuth, async (req, res, next) => {
  const key = typeof req.query.businessKey === 'string'
    ? req.query.businessKey.trim()
    : '';
  if (!key) return res.status(400).json({ error: 'A business key is required.' });
  try {
    const [rows] = await pool.execute(
      `SELECT u.id, u.email, u.first_name, u.last_name, u.avatar_url, u.role
       FROM merchant_businesses b
       JOIN users u ON u.id = b.merchant_id
       WHERE (CAST(b.id AS CHAR) = ? OR b.name = ?) AND u.status = 'active'
       LIMIT 1`,
      [key, key],
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: 'The venue owner is no longer available.' });
    }
    return res.json({ owner: publicMessageUser(rows[0]) });
  } catch (error) {
    return next(error);
  }
});

app.get('/api/messages/contacts', requireAuth, async (req, res, next) => {
  try {
    const [rows] = await pool.execute(
      `SELECT id, email, first_name, last_name, avatar_url, role
       FROM users
       WHERE id <> ? AND status = 'active'
       ORDER BY first_name, last_name, email`,
      [req.auth.sub],
    );
    return res.json({ contacts: rows.map(publicMessageUser) });
  } catch (error) {
    return next(error);
  }
});

app.get('/api/messages/conversations', requireAuth, async (req, res, next) => {
  try {
    const [rows] = await pool.execute(
      `SELECT c.id, c.type, c.title, c.created_at AS createdAt,
              m.body AS lastMessage, m.created_at AS lastMessageAt,
              cm.archived_at IS NOT NULL AS archived,
              cm.manually_unread_at IS NOT NULL AS manuallyUnread,
              (cm.manually_unread_at IS NOT NULL OR
               (SELECT COUNT(*) FROM messages unread
                WHERE unread.conversation_id = c.id
                  AND unread.sender_id <> ?
                  AND NOT EXISTS (
                    SELECT 1 FROM message_reads mr
                    WHERE mr.message_id = unread.id AND mr.user_id = ?
                  )) > 0)
                AS unreadCount,
              EXISTS (
                SELECT 1
                FROM conversation_members other
                JOIN user_blocks ub
                  ON ub.blocker_id = ? AND ub.blocked_user_id = other.user_id
                WHERE other.conversation_id = c.id
                  AND other.user_id <> ?
              ) AS blockedByMe
       FROM conversations c
       JOIN conversation_members cm ON cm.conversation_id = c.id AND cm.user_id = ?
       LEFT JOIN messages m ON m.id = (
         SELECT MAX(latest.id) FROM messages latest
         WHERE latest.conversation_id = c.id
       )
       WHERE cm.deleted_at IS NULL
       ORDER BY COALESCE(m.created_at, c.created_at) DESC`,
      [
        req.auth.sub,
        req.auth.sub,
        req.auth.sub,
        req.auth.sub,
        req.auth.sub,
      ],
    );
    for (const conversation of rows) {
      const [members] = await pool.execute(
        `SELECT u.id, u.email, u.first_name, u.last_name, u.avatar_url, u.role
         FROM conversation_members cm JOIN users u ON u.id = cm.user_id
         WHERE cm.conversation_id = ?`,
        [conversation.id],
      );
      conversation.members = members.map(publicMessageUser);
    }
    return res.json({ conversations: rows });
  } catch (error) {
    return next(error);
  }
});

app.post('/api/messages/conversations', requireAuth, async (req, res, next) => {
  const requestedIds = Array.isArray(req.body.participantIds)
    ? req.body.participantIds.map(Number).filter(Number.isInteger)
    : [];
  const recipientId = Number(req.body.recipientId);
  if (Number.isInteger(recipientId)) requestedIds.push(recipientId);
  const participantIds = [...new Set(requestedIds)].filter(
    (id) => id !== Number(req.auth.sub),
  );
  const isGroup = req.body.type === 'group' || participantIds.length > 1;
  const title = typeof req.body.title === 'string'
    ? req.body.title.trim().slice(0, 120)
    : null;
  if (participantIds.length === 0) {
    return res.status(400).json({ error: 'A valid recipient is required.' });
  }
  try {
    if (!isGroup) {
      const [blocks] = await pool.execute(
        `SELECT 1 FROM user_blocks
         WHERE (blocker_id = ? AND blocked_user_id = ?)
            OR (blocker_id = ? AND blocked_user_id = ?)
         LIMIT 1`,
        [req.auth.sub, participantIds[0], participantIds[0], req.auth.sub],
      );
      if (blocks.length > 0) {
        return res.status(403).json({ error: 'This conversation is blocked.' });
      }
    }
    const placeholders = participantIds.map(() => '?').join(', ');
    const [users] = await pool.execute(
      `SELECT id FROM users
       WHERE id IN (${placeholders}) AND status = 'active'`,
      participantIds,
    );
    if (users.length !== participantIds.length) {
      return res.status(404).json({ error: 'One or more user accounts are unavailable.' });
    }
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();
      if (!isGroup) {
        const directParticipants = [Number(req.auth.sub), participantIds[0]];
        await connection.execute(
          `SELECT id FROM users
           WHERE id IN (?, ?) ORDER BY id FOR UPDATE`,
          directParticipants,
        );
        const [existing] = await connection.execute(
          `SELECT c.id FROM conversations c
           JOIN conversation_members cm ON cm.conversation_id = c.id
           WHERE c.type = 'direct' AND cm.user_id IN (?, ?)
           GROUP BY c.id
           HAVING COUNT(DISTINCT cm.user_id) = 2 AND COUNT(*) = 2
           ORDER BY COALESCE(
             (SELECT MAX(m.created_at) FROM messages m
              WHERE m.conversation_id = c.id),
             c.created_at
           ) DESC, c.id DESC
           LIMIT 1`,
          directParticipants,
        );
        if (existing.length > 0) {
          await connection.execute(
            `UPDATE conversation_members
             SET archived_at = NULL, deleted_at = NULL, manually_unread_at = NULL
             WHERE conversation_id = ? AND user_id = ?`,
            [existing[0].id, req.auth.sub],
          );
          await connection.commit();
          return res.json({ conversationId: existing[0].id });
        }
      }
      const [result] = await connection.execute(
        'INSERT INTO conversations (type, title, created_by) VALUES (?, ?, ?)',
        [isGroup ? 'group' : 'direct', title, req.auth.sub],
      );
      const allParticipants = [Number(req.auth.sub), ...participantIds];
      for (const userId of allParticipants) {
        await connection.execute(
          'INSERT INTO conversation_members (conversation_id, user_id) VALUES (?, ?)',
          [result.insertId, userId],
        );
      }
      await connection.commit();
      return res.status(201).json({ conversationId: result.insertId });
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  } catch (error) {
    return next(error);
  }
});

async function isConversationMember(conversationId, userId) {
  const [rows] = await pool.execute(
    'SELECT 1 FROM conversation_members WHERE conversation_id = ? AND user_id = ? LIMIT 1',
    [conversationId, userId],
  );
  return rows.length > 0;
}

app.get('/api/messages/conversations/:id', requireAuth, async (req, res, next) => {
  try {
    const conversationId = Number(req.params.id);
    const [members] = await pool.execute(
      `SELECT 1 FROM conversation_members
       WHERE conversation_id = ? AND user_id = ? AND deleted_at IS NULL`,
      [conversationId, req.auth.sub],
    );
    if (members.length === 0) {
      return res.status(403).json({ error: 'You are not a member of this conversation.' });
    }
    await pool.execute(
      `UPDATE conversation_members SET manually_unread_at = NULL
       WHERE conversation_id = ? AND user_id = ?`,
      [conversationId, req.auth.sub],
    );
    await pool.execute(
      `INSERT IGNORE INTO message_reads (message_id, user_id)
       SELECT id, ? FROM messages
       WHERE conversation_id = ? AND sender_id <> ?`,
      [req.auth.sub, conversationId, req.auth.sub],
    );
    const [rows] = await pool.execute(
      `SELECT m.id, m.sender_id AS senderId, m.body, m.created_at AS createdAt,
              m.attachment_json AS attachmentJson,
              EXISTS (
                SELECT 1 FROM message_reads mr
                WHERE mr.message_id = m.id AND mr.user_id <> ?
              ) AS isSeen,
              u.first_name AS senderFirstName,
              u.last_name AS senderLastName
       FROM messages m JOIN users u ON u.id = m.sender_id
       WHERE m.conversation_id = ? ORDER BY m.created_at ASC`,
      [req.auth.sub, conversationId],
    );
    for (const message of rows) {
      if (typeof message.attachmentJson === 'string') {
        try {
          message.attachment = JSON.parse(message.attachmentJson);
        } catch {
          message.attachment = null;
        }
      } else {
        message.attachment = message.attachmentJson || null;
      }
      delete message.attachmentJson;
    }
    return res.json({ messages: rows });
  } catch (error) {
    return next(error);
  }
});

app.delete('/api/messages/conversations/:conversationId/messages/:messageId', requireAuth, async (req, res, next) => {
  const conversationId = Number(req.params.conversationId);
  const messageId = Number(req.params.messageId);
  if (!Number.isInteger(conversationId) || !Number.isInteger(messageId)) {
    return res.status(400).json({ error: 'The conversation and message are invalid.' });
  }
  try {
    const [result] = await pool.execute(
      `DELETE FROM messages
       WHERE id = ? AND conversation_id = ? AND sender_id = ?
       AND EXISTS (
         SELECT 1 FROM conversation_members
         WHERE conversation_id = ? AND user_id = ?
       )`,
      [messageId, conversationId, req.auth.sub, conversationId, req.auth.sub],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Message not found or cannot be deleted.' });
    }
    return res.json({ message: 'Message deleted.' });
  } catch (error) {
    return next(error);
  }
});

app.post('/api/messages/conversations/:id', requireAuth, async (req, res, next) => {
  const body = typeof req.body.body === 'string' ? req.body.body.trim() : '';
  const attachment = req.body.attachment;
  const hasImage = attachment &&
    typeof attachment === 'object' &&
    attachment.type === 'image' &&
    typeof attachment.data === 'string' &&
    /^data:image\/(jpeg|jpg|png|webp|gif);base64,[A-Za-z0-9+/=]+$/.test(attachment.data) &&
    attachment.data.length <= 7 * 1024 * 1024;
  if ((!body && !hasImage) || body.length > 4000) {
    return res.status(400).json({
      error: 'Add a message or a valid image attachment. Images must be smaller than 5 MB.',
    });
  }
  if (attachment != null && !hasImage) {
    return res.status(400).json({ error: 'The image attachment is invalid or too large.' });
  }
  try {
    const conversationId = Number(req.params.id);
    const [members] = await pool.execute(
      `SELECT 1 FROM conversation_members
       WHERE conversation_id = ? AND user_id = ? AND deleted_at IS NULL`,
      [conversationId, req.auth.sub],
    );
    if (members.length === 0) {
      return res.status(403).json({ error: 'You are not a member of this conversation.' });
    }
    const [blocked] = await pool.execute(
      `SELECT 1
       FROM conversation_members sender
       JOIN conversations c
         ON c.id = sender.conversation_id AND c.type = 'direct'
       JOIN conversation_members recipient
         ON recipient.conversation_id = sender.conversation_id
        AND recipient.user_id <> sender.user_id
       JOIN user_blocks ub
         ON (ub.blocker_id = sender.user_id AND ub.blocked_user_id = recipient.user_id)
         OR (ub.blocker_id = recipient.user_id AND ub.blocked_user_id = sender.user_id)
       WHERE sender.conversation_id = ? AND sender.user_id = ?
       LIMIT 1`,
      [conversationId, req.auth.sub],
    );
    if (blocked.length > 0) {
      return res.status(403).json({ error: 'Messages cannot be sent in this blocked conversation.' });
    }
    await pool.execute(
      `UPDATE conversation_members
       SET archived_at = NULL, deleted_at = NULL
       WHERE conversation_id = ?`,
      [conversationId],
    );
    await pool.execute(
      'INSERT INTO messages (conversation_id, sender_id, body, attachment_json) VALUES (?, ?, ?, ?)',
      [
        conversationId,
        req.auth.sub,
        body || null,
        hasImage
          ? JSON.stringify({
              type: 'image',
              name: typeof attachment.name === 'string'
                ? attachment.name.slice(0, 255)
                : 'image',
              data: attachment.data,
            })
          : null,
      ],
    );
    return res.status(201).json({ message: 'Message sent.' });
  } catch (error) {
    return next(error);
  }
});

app.get('/api/merchant/profile', requireAuth, async (req, res, next) => {
  try {
    const [rows] = await pool.execute(
      `SELECT u.id, u.email, u.first_name AS firstName, u.last_name AS lastName,
              u.phone, u.avatar_url AS avatarUrl, u.role, u.status,
              mp.business_name AS businessName, mp.business_type AS businessType,
              mp.registration_number AS registrationNumber,
              mp.categories_json AS categoriesJson, mp.facility_type AS facilityType,
              mp.address, mp.contact_email AS contactEmail,
              mp.owner_designation AS ownerDesignation,
              mp.business_image AS businessImage,
              CASE WHEN mp.user_id IS NULL THEN 0 ELSE 1 END AS profileExists
       FROM users u
       LEFT JOIN merchant_profiles mp ON mp.user_id = u.id
       WHERE u.id = ? AND u.role = 'merchant'
       LIMIT 1`,
      [req.auth.sub],
    );
    if (rows.length === 0) {
      return res.status(403).json({ error: 'Only merchant accounts can access this profile.' });
    }
    const profile = rows[0];
    let categories = [];
    if (profile.categoriesJson) {
      try {
        const parsedCategories = JSON.parse(profile.categoriesJson);
        if (Array.isArray(parsedCategories)) {
          categories = parsedCategories.filter(
            (category) => typeof category === 'string',
          );
        }
      } catch (error) {
        // Keep the saved merchant profile usable when older data contains
        // invalid category JSON. Categories can be edited and saved again.
        categories = [];
      }
    }
    delete profile.categoriesJson;
    return res.json({
      profile: {
        ...profile,
        categories,
        profileExists: Boolean(profile.profileExists),
      },
    });
  } catch (error) {
    return next(error);
  }
});

app.put('/api/merchant/profile', requireAuth, async (req, res, next) => {
  const text = (value, max = 255) =>
    typeof value === 'string' ? value.trim().slice(0, max) : '';
  const businessName = text(req.body.businessName);
  const businessType = text(req.body.businessType);
  const registrationNumber = text(req.body.registrationNumber);
  const facilityType = text(req.body.facilityType);
  const address = text(req.body.address, 500);
  const contactEmail = text(req.body.contactEmail);
  const ownerDesignation = text(req.body.ownerDesignation);
  const firstName = text(req.body.firstName, 100);
  const lastName = text(req.body.lastName, 100);
  const phone = text(req.body.phone, 30);
  const profileImage = text(req.body.profileImage, 10 * 1024 * 1024);
  const businessImage = text(req.body.businessImage, 10 * 1024 * 1024);
  const categories = Array.isArray(req.body.categories)
    ? req.body.categories.filter((value) => typeof value === 'string').slice(0, 12)
    : [];

  try {
    const [users] = await pool.execute(
      'SELECT id FROM users WHERE id = ? AND role = \'merchant\' LIMIT 1',
      [req.auth.sub],
    );
    if (users.length === 0) {
      return res.status(403).json({ error: 'Only merchant accounts can save this profile.' });
    }
    await pool.execute(
      `UPDATE users SET first_name = ?, last_name = ?, phone = ?, avatar_url = ?
       WHERE id = ?`,
      [firstName || null, lastName || null, phone || null, profileImage || null, req.auth.sub],
    );
    await pool.execute(
      `INSERT INTO merchant_profiles
       (user_id, business_name, business_type, registration_number,
        categories_json, facility_type, address, contact_email, owner_designation,
        business_image)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE business_name = VALUES(business_name),
         business_type = VALUES(business_type),
         registration_number = VALUES(registration_number),
         categories_json = VALUES(categories_json),
         facility_type = VALUES(facility_type),
         address = VALUES(address),
         contact_email = VALUES(contact_email),
         owner_designation = VALUES(owner_designation),
         business_image = VALUES(business_image)`,
      [
        req.auth.sub,
        businessName,
        businessType,
        registrationNumber || null,
        JSON.stringify(categories),
        facilityType,
        address,
        contactEmail,
        ownerDesignation || null,
        businessImage || null,
      ],
    );
    return res.json({ message: 'Merchant profile saved.' });
  } catch (error) {
    return next(error);
  }
});

app.get('/api/merchant/businesses', requireAuth, async (req, res, next) => {
  try {
    const [merchants] = await pool.execute(
      'SELECT id FROM users WHERE id = ? AND role = \'merchant\' LIMIT 1',
      [req.auth.sub],
    );
    if (merchants.length === 0) {
      return res.status(403).json({ error: 'Only merchant accounts can access businesses.' });
    }
    const [businesses] = await pool.execute(
      `SELECT b.id, b.business_type AS businessType, b.name, b.category, b.address,
              b.latitude AS latitude, b.longitude AS longitude,
              u.first_name AS ownerFirstName, u.last_name AS ownerLastName,
              CONCAT_WS(' ', u.first_name, u.last_name) AS ownerName,
              b.facility_type AS facilityType, b.price_per_hour AS pricePerHour,
              b.event_fee AS eventFee,
              b.included_players AS includedPlayers,
              b.additional_player_fee AS additionalPlayerFee,
              b.visit_url AS visitUrl,
              b.opening_hours AS hours, b.availability,
              b.enabled,
              b.rate_periods AS ratePeriods,
              e.event_types_json AS eventTypes, e.attendance_min AS attendanceMin,
              e.attendance_max AS attendanceMax,
              e.accessibility_needs AS accessibilityNeeds,
              e.parking_needs AS parkingNeeds, e.security_needs AS securityNeeds,
              COALESCE((SELECT AVG(r.rating) FROM venue_reviews r
                        WHERE r.business_id = b.id), 0) AS averageRating,
              (SELECT COUNT(*) FROM venue_reviews r
               WHERE r.business_id = b.id) AS reviewCount,
              (SELECT COUNT(DISTINCT r.customer_id) FROM venue_reviews r
               WHERE r.business_id = b.id) AS ratingUserCount,
              b.amenities_json AS tags, b.details, b.image_url AS imageUrl,
              b.image_urls AS imageUrls,
              b.created_at AS createdAt
       FROM merchant_businesses b
       JOIN users u ON u.id = b.merchant_id
       LEFT JOIN event_business_details e ON e.business_id = b.id
       WHERE b.merchant_id = ? AND u.role = 'merchant'
       ORDER BY b.created_at DESC`,
      [req.auth.sub],
    );
    for (const business of businesses) {
      for (const field of [
        'eventTypes',
        'accessibilityNeeds',
        'parkingNeeds',
        'securityNeeds',
      ]) {
        business[field] = parseJsonArray(business[field]);
      }
      if (typeof business.imageUrls === 'string') {
        try {
          business.imageUrls = JSON.parse(business.imageUrls);
        } catch {
          business.imageUrls = [];
        }
      }
      if (!Array.isArray(business.imageUrls)) business.imageUrls = [];
      if (business.imageUrls.length === 0 && business.imageUrl) {
        try {
          const legacyImages = JSON.parse(business.imageUrl);
          if (Array.isArray(legacyImages)) {
            business.imageUrls = legacyImages.filter(
              (image) => typeof image === 'string' && image.length > 0,
            );
          }
        } catch {}
      }
      if (business.imageUrls.length === 0 && business.imageUrl) {
        business.imageUrls = [business.imageUrl];
      }
      if (business.imageUrls.length > 0) business.imageUrl = business.imageUrls[0];
    }
    return res.json({ businesses });
  } catch (error) {
    return next(error);
  }
});

app.get('/api/businesses', async (req, res, next) => {
  try {
    const [businesses] = await pool.execute(
      `SELECT b.id, b.business_type AS businessType, b.name, b.category, b.address,
              b.latitude AS latitude, b.longitude AS longitude,
              CONCAT_WS(' ', u.first_name, u.last_name) AS ownerName,
              u.first_name AS ownerFirstName, u.last_name AS ownerLastName,
              u.email AS ownerEmail, u.phone AS ownerPhone,
              u.avatar_url AS ownerAvatarUrl,
              b.facility_type AS facilityType, b.price_per_hour AS pricePerHour,
              b.event_fee AS eventFee,
              b.included_players AS includedPlayers,
              b.additional_player_fee AS additionalPlayerFee,
              b.visit_url AS visitUrl,
              b.opening_hours AS hours, b.availability, b.enabled,
              b.rate_periods AS ratePeriods,
              e.event_types_json AS eventTypes, e.attendance_min AS attendanceMin,
              e.attendance_max AS attendanceMax,
              e.accessibility_needs AS accessibilityNeeds,
              e.parking_needs AS parkingNeeds, e.security_needs AS securityNeeds,
              COALESCE((SELECT AVG(r.rating) FROM venue_reviews r
                        WHERE r.business_id = b.id), 0) AS averageRating,
              (SELECT COUNT(*) FROM venue_reviews r
               WHERE r.business_id = b.id) AS reviewCount,
              (SELECT COUNT(DISTINCT r.customer_id) FROM venue_reviews r
               WHERE r.business_id = b.id) AS ratingUserCount,
              b.amenities_json AS tags, b.details, b.image_url AS imageUrl,
              b.image_urls AS imageUrls,
              b.created_at AS createdAt
       FROM merchant_businesses b
       JOIN users u ON u.id = b.merchant_id
       LEFT JOIN event_business_details e ON e.business_id = b.id
       WHERE b.enabled = 1 AND u.status = 'active'
       ORDER BY b.created_at DESC`,
    );
    for (const business of businesses) {
      for (const field of [
        'eventTypes',
        'accessibilityNeeds',
        'parkingNeeds',
        'securityNeeds',
      ]) {
        business[field] = parseJsonArray(business[field]);
      }
      for (const field of ['ratePeriods', 'tags']) {
        if (typeof business[field] === 'string') {
          try {
            business[field] = JSON.parse(business[field]);
          } catch {
            business[field] = [];
          }
        }
        if (!Array.isArray(business[field])) business[field] = [];
      }
      if (typeof business.imageUrls === 'string') {
        try {
          business.imageUrls = JSON.parse(business.imageUrls);
        } catch {
          business.imageUrls = [];
        }
      }
      if (!Array.isArray(business.imageUrls)) business.imageUrls = [];
      if (business.imageUrls.length === 0 && business.imageUrl) {
        try {
          const legacyImages = JSON.parse(business.imageUrl);
          if (Array.isArray(legacyImages)) {
            business.imageUrls = legacyImages.filter(
              (image) => typeof image === 'string' && image.length > 0,
            );
          }
        } catch {}
      }
      if (business.imageUrls.length === 0 && business.imageUrl) {
        business.imageUrls = [business.imageUrl];
      }
      if (business.imageUrls.length > 0) business.imageUrl = business.imageUrls[0];
    }
    return res.json({ businesses });
  } catch (error) {
    return next(error);
  }
});

app.delete('/api/merchant/businesses/:id', requireAuth, async (req, res, next) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isSafeInteger(id)) {
    return res.status(400).json({ error: 'Invalid business id.' });
  }
  try {
    const [result] = await pool.execute(
      'DELETE FROM merchant_businesses WHERE id = ? AND merchant_id = ?',
      [id, req.auth.sub],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Business not found.' });
    }
    return res.json({ message: 'Business deleted.' });
  } catch (error) {
    return next(error);
  }
});

app.put('/api/merchant/businesses/:id/status', requireAuth, async (req, res, next) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isSafeInteger(id) || typeof req.body.enabled !== 'boolean') {
    return res.status(400).json({ error: 'Invalid business status.' });
  }
  try {
    const [result] = await pool.execute(
      'UPDATE merchant_businesses SET enabled = ? WHERE id = ? AND merchant_id = ?',
      [req.body.enabled ? 1 : 0, id, req.auth.sub],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Business not found.' });
    }
    return res.json({ message: req.body.enabled ? 'Business enabled.' : 'Business disabled.' });
  } catch (error) {
    return next(error);
  }
});

app.put('/api/merchant/businesses/:id', requireAuth, async (req, res, next) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isSafeInteger(id)) {
    return res.status(400).json({ error: 'Invalid business id.' });
  }
  const text = (value, max = 255) =>
    typeof value === 'string' ? value.trim().slice(0, max) : '';
  const businessType = text(req.body.businessType, 50);
  const name = text(req.body.name);
  const category = text(req.body.category, 100);
  const address = text(req.body.address, 500);
  const facilityType = text(req.body.facilityType, 50);
  const hours = text(req.body.hours, 100);
  const visitUrl = text(req.body.visitUrl, 1000);
  const coordinates = parseBusinessCoordinates(req.body);
  const availability = text(req.body.availability, 255) || 'Any';
  const pricePerHour = Number(req.body.pricePerHour);
  const eventFee = Number(req.body.eventFee);
  const includedPlayers = Number(req.body.includedPlayers ?? 0);
  const additionalPlayerFee = Number(req.body.additionalPlayerFee ?? 0);
  const ratePeriods = Array.isArray(req.body.ratePeriods)
    ? req.body.ratePeriods.slice(0, 20)
    : [];
  const tags = Array.isArray(req.body.tags)
    ? req.body.tags.filter((item) => typeof item === 'string').slice(0, 20)
    : [];
  const imageUrls = Array.isArray(req.body.imageUrls)
    ? req.body.imageUrls.filter((item) => typeof item === 'string').slice(0, 20)
    : [];
  const imageUrl = text(req.body.imageUrl, 10 * 1024 * 1024) || imageUrls[0] || '';
  const valid =
    coordinates.valid &&
    ['Sports', 'Event', 'Fitness & Wellness'].includes(businessType) &&
    name && category && address && facilityType && hours &&
    (businessType === 'Event'
      ? Number.isFinite(eventFee) && eventFee > 0
      : Number.isFinite(pricePerHour) &&
        (pricePerHour > 0 || ratePeriods.length > 0)) &&
    Number.isInteger(includedPlayers) &&
    includedPlayers >= 0 &&
    includedPlayers <= 30 &&
    Number.isFinite(additionalPlayerFee) &&
    additionalPlayerFee >= 0 &&
    additionalPlayerFee <= 99999999.99 &&
    (additionalPlayerFee === 0 ||
      (businessType === 'Sports' && includedPlayers > 0));
  if (!valid) {
    return res.status(400).json({ error: 'Please check the business details.' });
  }
  try {
    const [result] = await pool.execute(
      `UPDATE merchant_businesses
       SET business_type = ?, name = ?, category = ?, address = ?, facility_type = ?,
           price_per_hour = ?, event_fee = ?, opening_hours = ?, availability = ?,
           rate_periods = ?, amenities_json = ?, details = ?, image_url = ?,
           image_urls = ?, visit_url = ?, included_players = ?,
           additional_player_fee = ?,
           latitude = IF(?, ?, latitude), longitude = IF(?, ?, longitude)
       WHERE id = ? AND merchant_id = ?`,
      [
        businessType, name, category, address, facilityType,
        businessType === 'Event' ? eventFee : pricePerHour,
        businessType === 'Event' ? eventFee : 0,
        hours, availability, JSON.stringify(ratePeriods), JSON.stringify(tags),
        text(req.body.details, 1000) || null, imageUrl || null,
        JSON.stringify(imageUrls), visitUrl || null,
        businessType === 'Sports' ? includedPlayers : 0,
        businessType === 'Sports' ? additionalPlayerFee : 0,
        coordinates.provided, coordinates.latitude,
        coordinates.provided, coordinates.longitude,
        id, req.auth.sub,
      ],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Business not found.' });
    }
    await saveEventDetails(id, req.body);
    return res.json({ message: 'Business updated.' });
  } catch (error) {
    return next(error);
  }
});

app.post('/api/merchant/businesses', requireAuth, async (req, res, next) => {
  const text = (value, max = 255) =>
    typeof value === 'string' ? value.trim().slice(0, max) : '';
  const businessType = text(req.body.businessType, 50);
  const name = text(req.body.name);
  const category = text(req.body.category, 100);
  const address = text(req.body.address, 500);
  const visitUrl = text(req.body.visitUrl, 1000);
  const coordinates = parseBusinessCoordinates(req.body);
  const facilityType = text(req.body.facilityType, 50);
  const pricePerHour = Number(req.body.pricePerHour);
  const eventFee = Number(req.body.eventFee);
  const includedPlayers = Number(req.body.includedPlayers ?? 0);
  const additionalPlayerFee = Number(req.body.additionalPlayerFee ?? 0);
  const hours = text(req.body.hours, 100);
  const availability = text(req.body.availability, 255);
  const ratePeriods = Array.isArray(req.body.ratePeriods)
    ? req.body.ratePeriods
        .filter(
          (item) =>
            item &&
            typeof item === 'object' &&
            typeof item.start === 'string' &&
            typeof item.end === 'string' &&
            Number.isFinite(Number(item.pricePerHour)) &&
            Number(item.pricePerHour) > 0,
        )
        .slice(0, 20)
        .map((item) => ({
          start: text(item.start, 20),
          end: text(item.end, 20),
          pricePerHour: Number(item.pricePerHour),
        }))
    : [];
  const amenities = Array.isArray(req.body.tags)
    ? req.body.tags.filter((item) => typeof item === 'string').slice(0, 20)
    : [];
  const details = text(req.body.details, 1000);
  const imageUrl = text(req.body.imageUrl, 10 * 1024 * 1024);
  const imageUrls = Array.isArray(req.body.imageUrls)
    ? req.body.imageUrls.filter((item) => typeof item === 'string').slice(0, 20)
    : imageUrl ? [imageUrl] : [];
  const primaryImageUrl = imageUrl || imageUrls[0] || '';
  const allowedBusinessTypes = new Set([
    'Sports',
    'Event',
    'Fitness & Wellness',
  ]);
  const validationErrors = [];
  if (!coordinates.valid) validationErrors.push('map location');
  if (!allowedBusinessTypes.has(businessType)) {
    validationErrors.push('booking type');
  }
  if (!name) validationErrors.push('business name');
  if (!category) validationErrors.push('category');
  if (!address) validationErrors.push('address');
  if (!facilityType) validationErrors.push('facility type');
  if (!hours) validationErrors.push('opening and closing hours');
  if (visitUrl && !/^https?:\/\/\S+$/i.test(visitUrl)) validationErrors.push('visit link');
  const amountIsValid = businessType === 'Event'
    ? Number.isFinite(eventFee) && eventFee > 0
    : Number.isFinite(pricePerHour) &&
      (pricePerHour > 0 || ratePeriods.length > 0);
  if (!amountIsValid) {
    validationErrors.push(
      businessType === 'Event'
        ? 'event fee'
        : ratePeriods.length > 0 ? 'rate periods' : 'price per hour',
    );
  }
  if (
    !Number.isInteger(includedPlayers) ||
    includedPlayers < 0 ||
    includedPlayers > 30 ||
    !Number.isFinite(additionalPlayerFee) ||
    additionalPlayerFee < 0 ||
    additionalPlayerFee > 99999999.99 ||
    (additionalPlayerFee > 0 &&
      (businessType !== 'Sports' || includedPlayers < 1))
  ) {
    validationErrors.push('extra-player fee settings');
  }
  if (validationErrors.length > 0) {
    return res.status(400).json({
      error: `Please check: ${validationErrors.join(', ')}.`,
      validationErrors,
    });

  }
  try {
    const [merchants] = await pool.execute(
      'SELECT id FROM users WHERE id = ? AND role = \'merchant\' LIMIT 1',
      [req.auth.sub],
    );
    if (merchants.length === 0) {
      return res.status(403).json({ error: 'Only merchant accounts can add businesses.' });
    }
    const [result] = await pool.execute(
      `INSERT INTO merchant_businesses
       (merchant_id, business_type, name, category, address, facility_type,
        price_per_hour, event_fee, opening_hours, availability, rate_periods,
        amenities_json, details, image_url, image_urls, visit_url,
        included_players, additional_player_fee, latitude, longitude)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)` ,
      [
        req.auth.sub,
        businessType,
        name,
        category,
        address,
        facilityType,
        businessType === 'Event' ? eventFee : pricePerHour,
        businessType === 'Event' ? eventFee : 0,
        hours,
        availability || 'Any',
        ratePeriods.length > 0 ? JSON.stringify(ratePeriods) : null,
        JSON.stringify(amenities),
        details || null,
        primaryImageUrl || null,
        JSON.stringify(imageUrls),
        visitUrl || null,
        businessType === 'Sports' ? includedPlayers : 0,
        businessType === 'Sports' ? additionalPlayerFee : 0,
        coordinates.latitude,
        coordinates.longitude,
      ],
    );
    await saveEventDetails(result.insertId, req.body);
    return res.status(201).json({ message: 'Business added.' });
  } catch (error) {
    return next(error);
  }
});

app.get('/api/saved-items', requireAuth, async (req, res, next) => {
  try {
    const [items] = await pool.execute(
      `SELECT id, item_type AS itemType, item_key AS itemKey,
              title, subtitle, image_url AS imageUrl,
              owner_email AS ownerEmail, owner_phone AS ownerPhone,
              created_at AS createdAt
       FROM saved_items
       WHERE user_id = ?
       ORDER BY created_at DESC`,
      [req.auth.sub],
    );
    return res.json({ items });
  } catch (error) {
    return next(error);
  }
});

app.get('/api/saved-item-counts', requireAuth, async (req, res, next) => {
  const itemType = req.query.itemType;
  if (!['sports', 'event', 'fitness'].includes(itemType)) {
    return res.status(400).json({ error: 'Invalid saved item type.' });
  }
  try {
    const [rows] = await pool.execute(
      `SELECT item_key AS itemKey, COUNT(*) AS saveCount
       FROM saved_items
       WHERE item_type = ?
       GROUP BY item_key`,
      [itemType],
    );
    return res.json({
      counts: Object.fromEntries(
        rows.map((row) => [row.itemKey, Number(row.saveCount)]),
      ),
    });
  } catch (error) {
    return next(error);
  }
});

app.post('/api/saved-items', requireAuth, async (req, res, next) => {
  const itemType = req.body.itemType;
  const itemKey = typeof req.body.itemKey === 'string' ? req.body.itemKey.trim() : '';
  const title = typeof req.body.title === 'string' ? req.body.title.trim() : '';
  const subtitle = typeof req.body.subtitle === 'string' ? req.body.subtitle.trim() : '';
  const imageUrl = typeof req.body.imageUrl === 'string' ? req.body.imageUrl.trim() : null;

  if (!['sports', 'event', 'fitness'].includes(itemType) ||
      !itemKey || !title || itemKey.length > 255 || title.length > 255) {
    return res.status(400).json({ error: 'A valid saved item is required.' });
  }

  try {
    const [owners] = await pool.execute(
      `SELECT u.email, u.phone, mp.contact_email AS contactEmail
       FROM merchant_businesses b
       JOIN users u ON u.id = b.merchant_id
       LEFT JOIN merchant_profiles mp ON mp.user_id = u.id
       WHERE b.id = ? OR b.name = ?
       LIMIT 1`,
      [itemKey, itemKey],
    );
    const owner = owners[0];
    const ownerEmail = owner?.contactEmail || owner?.email || null;
    const ownerPhone = owner?.phone || null;
    await pool.execute(
      `INSERT INTO saved_items
       (user_id, item_type, item_key, title, subtitle, image_url,
        owner_email, owner_phone)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE title = VALUES(title), subtitle = VALUES(subtitle),
                               image_url = VALUES(image_url),
                               owner_email = COALESCE(VALUES(owner_email), owner_email),
                               owner_phone = COALESCE(VALUES(owner_phone), owner_phone)`,
      [req.auth.sub, itemType, itemKey, title, subtitle || null, imageUrl,
       ownerEmail, ownerPhone],
    );
    return res.status(201).json({ message: 'Item saved.' });
  } catch (error) {
    return next(error);
  }
});

app.delete('/api/saved-items/:itemType/:itemKey', requireAuth, async (req, res, next) => {
  if (!['sports', 'event', 'fitness'].includes(req.params.itemType)) {
    return res.status(400).json({ error: 'Invalid saved item type.' });
  }
  try {
    await pool.execute(
      'DELETE FROM saved_items WHERE user_id = ? AND item_type = ? AND item_key = ?',
      [req.auth.sub, req.params.itemType, req.params.itemKey],
    );
    return res.json({ message: 'Item removed.' });
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

function requireRole(role) {
  return async (req, res, next) => {
    try {
      const [users] = await pool.execute(
        'SELECT role, status FROM users WHERE id = ? LIMIT 1',
        [req.auth.sub],
      );
      if (!users[0] || users[0].role !== role || users[0].status !== 'active') {
        return res.status(403).json({ error: `Only active ${role} accounts can access this endpoint.` });
      }
      return next();
    } catch (error) {
      return next(error);
    }
  };
}

function validDate(value) {
  return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value);
}

function validTime(value) {
  return typeof value === 'string' && /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(value);
}

app.get('/api/bookings/availability', requireAuth, requireRole('customer'), async (req, res, next) => {
  const venueId = Number(req.query.venueId);
  const bookingDate = req.query.date;
  if (!Number.isSafeInteger(venueId) || venueId <= 0 || !validDate(bookingDate)) {
    return res.status(400).json({ error: 'venueId and a valid date are required.' });
  }
  try {
    const [bookings] = await pool.execute(
      `SELECT start_time AS startTime, duration_hours AS durationHours
       FROM bookings
       WHERE venue_id = ? AND booking_date = ?
         AND status IN ('pending', 'approved')
       ORDER BY start_time`,
      [venueId, bookingDate],
    );
    return res.json({ bookings });
  } catch (error) {
    return next(error);
  }
});

app.post('/api/bookings', requireAuth, requireRole('customer'), async (req, res, next) => {
  const venueId = Number(req.body.venueId ?? req.body.businessId);
  const bookingDate = req.body.date;
  const startTime = req.body.startTime;
  const durationHours = Number(req.body.durationHours ?? req.body.duration);
  const players = Number(req.body.players);
  const paymentMethod = typeof req.body.paymentMethod === 'string'
    ? req.body.paymentMethod.trim().slice(0, 50) : '';
  const allowedPaymentMethods = new Set(['online', 'cash_on_arrival']);
  if (!Number.isSafeInteger(venueId) || venueId <= 0 || !validDate(bookingDate) ||
      !validTime(startTime) || !Number.isFinite(durationHours) ||
      durationHours <= 0 || durationHours > 24 || !Number.isSafeInteger(players) ||
      players <= 0 || players > 1000 || !allowedPaymentMethods.has(paymentMethod)) {
    return res.status(400).json({
      error: 'Choose Online payment or Cash on Arrival (COA).',
    });

    app.post('/api/payments/paymongo/checkout', requireAuth, requireRole('customer'), async (req, res, next) => {
      const bookingId = Number(req.body.bookingId);
      const paymentMethod = typeof req.body.paymentMethod === 'string'
        ? req.body.paymentMethod.trim() : '';
      if (!Number.isSafeInteger(bookingId) || bookingId <= 0 ||
          !['gcash', 'paymaya'].includes(paymentMethod)) {
        return res.status(400).json({
          error: 'Choose GCash or PayMaya before starting online payment.',
        });
      }
      if (!process.env.PAYMONGO_SECRET_KEY) {
        return res.status(503).json({
          error: 'Online payment is not configured. Add PAYMONGO_SECRET_KEY to the backend environment.',
        });
      }
      try {
        const [rows] = await pool.execute(
          `SELECT id, total_amount AS totalAmount
             FROM bookings
            WHERE id = ? AND customer_id = ?
            LIMIT 1`,
          [bookingId, req.auth.sub],
        );
        const booking = rows[0];
        if (!booking) return res.status(404).json({ error: 'Booking not found.' });
        const response = await fetch('https://api.paymongo.com/v1/checkout_sessions', {
          method: 'POST',
          headers: {
            Authorization: `Basic ${Buffer.from(`${process.env.PAYMONGO_SECRET_KEY}:`).toString('base64')}`,
            'Content-Type': 'application/json',
            Accept: 'application/json',
          },
          body: JSON.stringify({
            data: {
              attributes: {
                line_items: [{
                  currency: 'PHP',
                  amount: Math.round(Number(booking.totalAmount) * 100),
                  name: `TinkerPro booking #${booking.id}`,
                  quantity: 1,
                }],
                payment_method_types: [paymentMethod],
                success_url: process.env.PAYMONGO_SUCCESS_URL,
                cancel_url: process.env.PAYMONGO_CANCEL_URL,
                description: `TinkerPro booking #${booking.id}`,
                metadata: { booking_id: String(booking.id) },
              },
            },
          }),
        });
        const payload = await response.json();
        if (!response.ok) {
          return res.status(502).json({
            error: payload?.errors?.[0]?.detail || 'PayMongo could not create checkout.',
          });
        }
        const checkoutUrl = payload?.data?.attributes?.checkout_url;
        if (typeof checkoutUrl !== 'string' || checkoutUrl.trim().length === 0) {
          return res.status(502).json({ error: 'PayMongo returned no checkout URL.' });
        }
        return res.json({ checkoutUrl });
      } catch (error) {
        return next(error);
      }
    });
  }

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [venues] = await connection.execute(
      `SELECT b.id, b.merchant_id, b.price_per_hour, b.included_players,
              b.additional_player_fee, b.enabled, u.status AS merchant_status
       FROM merchant_businesses b JOIN users u ON u.id = b.merchant_id
       WHERE b.id = ? FOR UPDATE`,
      [venueId],
    );
    const venue = venues[0];
    if (!venue || !venue.enabled || venue.merchant_status !== 'active') {
      await connection.rollback();
      return res.status(404).json({ error: 'The venue is unavailable.' });
    }
    const [overlaps] = await connection.execute(
      `SELECT id FROM bookings
       WHERE venue_id = ? AND booking_date = ?
         AND status IN ('pending', 'approved')
         AND start_time < ADDTIME(?, SEC_TO_TIME(? * 3600))
         AND ADDTIME(start_time, SEC_TO_TIME(duration_hours * 3600)) > ? LIMIT 1`,
      [venueId, bookingDate, startTime, durationHours, startTime],
    );
    if (overlaps.length) {
      await connection.rollback();
      return res.status(409).json({ error: 'The venue is already booked for that time.' });
    }
    const pricePerHour = Number(venue.price_per_hour);
    const includedPlayers = Number(venue.included_players);
    const additionalPlayerFee = Number(venue.additional_player_fee);
    const extraPlayers = Math.max(0, players - includedPlayers);
    const extraPlayerCharge = Number(
      (extraPlayers * additionalPlayerFee).toFixed(2),
    );
    const total = Number(
      (pricePerHour * durationHours + extraPlayerCharge).toFixed(2),
    );
    const downpayment = Number((total * 0.50).toFixed(2));
    const bookingToken = createBookingToken();
    const [result] = await connection.execute(
      `INSERT INTO bookings
       (customer_id, venue_id, booking_date, start_time, duration_hours, players,
        payment_method, price_per_hour, total_amount, downpayment_amount,
        extra_player_charge, booking_token_hash, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
      [req.auth.sub, venueId, bookingDate, startTime, durationHours, players,
       paymentMethod, pricePerHour, total, downpayment, extraPlayerCharge,
       hashBookingToken(bookingToken)],
    );
    const [conversation] = await connection.execute(
      'INSERT INTO conversations (type, title, created_by) VALUES (?, ?, ?)',
      ['direct', `Booking ${result.insertId}`, req.auth.sub],
    );
    const conversationId = conversation.insertId;
    await connection.execute(
      'INSERT INTO conversation_members (conversation_id, user_id) VALUES (?, ?), (?, ?)',
      [conversationId, req.auth.sub, conversationId, venue.merchant_id],
    );
    await connection.execute(
      `INSERT INTO messages (conversation_id, sender_id, body, attachment_json)
       VALUES (?, ?, ?, ?)`,
      [
        conversationId,
        req.auth.sub,
        `New booking request #${result.insertId} submitted. Booking token: ${bookingToken}`,
        JSON.stringify({
          type: 'booking',
          bookingId: result.insertId,
          status: 'pending',
          extraPlayerCharge,
          bookingToken,
        }),
      ],
    );
    await connection.commit();
    return res.status(201).json({
      booking: { id: result.insertId, venueId, date: bookingDate, startTime,
        durationHours, players, paymentMethod, pricePerHour, total, downpayment,
        extraPlayers, extraPlayerCharge, status: 'pending', bookingToken },
    });
  } catch (error) {
    if (connection) await connection.rollback();
    return next(error);
  } finally {
    connection?.release();
  }
});

app.get('/api/bookings', requireAuth, requireRole('customer'), async (req, res, next) => {
  try {
    const [bookings] = await pool.execute(
      `SELECT b.id, b.venue_id AS venueId, v.name AS venueName, v.address,
              CONCAT_WS(' ', u.first_name, u.last_name) AS ownerName,
              v.business_type AS businessType, v.category, v.facility_type AS facilityType,
              v.opening_hours AS hours, v.availability, v.rate_periods AS ratePeriods,
              e.event_types_json AS eventTypes, e.attendance_min AS attendanceMin,
              e.attendance_max AS attendanceMax,
              e.accessibility_needs AS accessibilityNeeds,
              e.parking_needs AS parkingNeeds, e.security_needs AS securityNeeds,
              v.details, v.visit_url AS visitUrl,
              v.price_per_hour AS venuePricePerHour, v.event_fee AS eventFee,
              v.amenities_json AS amenities,
              v.image_url AS imageUrl, v.image_urls AS imageUrls,
              b.booking_date AS date, b.start_time AS startTime,
              b.duration_hours AS durationHours, b.players, b.payment_method AS paymentMethod,
              b.price_per_hour AS pricePerHour, b.total_amount AS total,
              b.extra_player_charge AS extraPlayerCharge,
              b.downpayment_amount AS downpayment, b.status, b.created_at AS createdAt,
              r.id AS reviewId, r.rating AS reviewRating
       FROM bookings b
       JOIN merchant_businesses v ON v.id = b.venue_id
       JOIN users u ON u.id = v.merchant_id
       LEFT JOIN event_business_details e ON e.business_id = v.id
       LEFT JOIN venue_reviews r ON r.booking_id = b.id AND r.customer_id = b.customer_id
       WHERE b.customer_id = ? ORDER BY b.booking_date DESC, b.start_time DESC`,
      [req.auth.sub],
    );
    for (const booking of bookings) {
      for (const field of [
        'eventTypes',
        'accessibilityNeeds',
        'parkingNeeds',
        'securityNeeds',
      ]) {
        booking[field] = parseJsonArray(booking[field]);
      }
      for (const field of ['ratePeriods', 'amenities']) {
        if (typeof booking[field] === 'string') {
          try {
            booking[field] = JSON.parse(booking[field]);
          } catch {
            booking[field] = [];
          }
        }
        if (!Array.isArray(booking[field])) booking[field] = [];
      }
      if (typeof booking.imageUrls === 'string') {
        try {
          booking.imageUrls = JSON.parse(booking.imageUrls);
        } catch {
          booking.imageUrls = [];
        }
      }
      if (!Array.isArray(booking.imageUrls)) booking.imageUrls = [];
      if (booking.imageUrls.length === 0 && booking.imageUrl) {
        try {
          const legacyImages = JSON.parse(booking.imageUrl);
          if (Array.isArray(legacyImages)) {
            booking.imageUrls = legacyImages.filter(
              (image) => typeof image === 'string' && image.length > 0,
            );
          }
        } catch {}
      }
      if (booking.imageUrls.length === 0 && booking.imageUrl) {
        booking.imageUrls = [booking.imageUrl];
      }
      if (booking.imageUrls.length > 0) {
        booking.imageUrl = booking.imageUrls[0];
      }
    }
    return res.json({ bookings });
  } catch (error) { return next(error); }
});

app.get('/api/merchant/bookings', requireAuth, requireRole('merchant'), async (req, res, next) => {
  try {
    const [bookings] = await pool.execute(
      `SELECT b.id, b.customer_id AS customerId,
              CONCAT_WS(' ', u.first_name, u.last_name) AS customerName, u.email AS customerEmail,
              b.venue_id AS venueId, v.name AS venueName,
              v.business_type AS businessType, b.booking_date AS date,
              b.start_time AS startTime, b.duration_hours AS durationHours, b.players,
              b.payment_method AS paymentMethod, b.price_per_hour AS pricePerHour,
              b.extra_player_charge AS extraPlayerCharge,
              b.total_amount AS total, b.downpayment_amount AS downpayment,
              b.status, b.created_at AS createdAt
       FROM bookings b JOIN merchant_businesses v ON v.id = b.venue_id
       JOIN users u ON u.id = b.customer_id
       WHERE v.merchant_id = ? ORDER BY b.booking_date, b.start_time`,
      [req.auth.sub],
    );
    return res.json({ bookings });
  } catch (error) { return next(error); }
});

app.patch('/api/merchant/bookings/:id/approve', requireAuth, requireRole('merchant'), async (req, res, next) => {
  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const ticketCode = createBookingToken();
    const [result] = await connection.execute(
      `UPDATE bookings b JOIN merchant_businesses v ON v.id = b.venue_id
       SET b.status = 'approved', b.ticket_token_hash = ?
       WHERE b.id = ? AND v.merchant_id = ? AND b.status = 'pending'`,
      [hashBookingToken(ticketCode), req.params.id, req.auth.sub],
    );
    if (!result.affectedRows) {
      await connection.rollback();
      return res.status(404).json({ error: 'Pending booking not found.' });
    }
    const [rows] = await connection.execute(
      `SELECT b.id, b.customer_id AS customerId, v.name AS venueName
       FROM bookings b JOIN merchant_businesses v ON v.id = b.venue_id
       WHERE b.id = ? AND v.merchant_id = ? LIMIT 1`,
      [req.params.id, req.auth.sub],
    );
    const booking = rows[0];
    const [existingConversation] = await connection.execute(
      'SELECT id FROM conversations WHERE type = ? AND title = ? LIMIT 1',
      ['direct', `Booking ${booking.id}`],
    );
    let conversationId = existingConversation[0]?.id;
    if (!conversationId) {
      const [conversation] = await connection.execute(
        'INSERT INTO conversations (type, title, created_by) VALUES (?, ?, ?)',
        ['direct', `Booking ${booking.id}`, req.auth.sub],
      );
      conversationId = conversation.insertId;
      await connection.execute(
        'INSERT INTO conversation_members (conversation_id, user_id) VALUES (?, ?), (?, ?)',
        [conversationId, req.auth.sub, conversationId, booking.customerId],
      );
    }
    await connection.execute(
      `INSERT INTO messages (conversation_id, sender_id, body, attachment_json)
       VALUES (?, ?, ?, ?)`,
      [
        conversationId,
        req.auth.sub,
        `Booking #${booking.id} for ${booking.venueName} approved. Your ticket: ${ticketCode}`,
        JSON.stringify({
          type: 'booking_ticket',
          bookingId: booking.id,
          status: 'approved',
          ticketCode,
        }),
      ],
    );
    await connection.commit();
    return res.json({
      message: 'Booking approved and ticket issued.',
      status: 'approved',
      ticketCode,
    });
  } catch (error) {
    if (connection) await connection.rollback();
    return next(error);
  } finally {
    connection?.release();
  }
});

app.patch('/api/merchant/bookings/:id/finish', requireAuth, requireRole('merchant'), async (req, res, next) => {
  try {
    const [result] = await pool.execute(
      `UPDATE bookings b JOIN merchant_businesses v ON v.id = b.venue_id
       SET b.status = 'finished' WHERE b.id = ? AND v.merchant_id = ? AND b.status = 'approved'`,
      [req.params.id, req.auth.sub],
    );
    if (!result.affectedRows) return res.status(404).json({ error: 'Approved booking not found.' });
    return res.json({ message: 'Booking marked finished.', status: 'finished' });
  } catch (error) { return next(error); }
});

// Merchant news posts and the customer news feed.
function newsPostResponse(row) {
  const parseArray = (value) => {
    if (Array.isArray(value)) return value;
    if (typeof value !== 'string' || value.trim() === '') return [];
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  };
  return {
    id: Number(row.id),
    businessId: Number(row.business_id),
    title: row.title,
    body: row.body,
    imageUrl: row.image_url || null,
    businessName: row.business_name || row.venue_name,
    businessType: row.business_type || null,
    category: row.business_category || null,
    address: row.business_address || row.venue_address,
    facilityType: row.facility_type || null,
    hours: row.opening_hours || null,
    availability: row.availability || null,
    pricePerHour: row.price_per_hour ?? null,
    eventFee: row.event_fee ?? null,
    ratePeriods: parseArray(row.rate_periods),
    tags: parseArray(row.amenities_json),
    details: row.business_details || null,
    imageUrls: parseArray(row.image_urls),
    businessImageUrl: row.business_image_url || null,
    visitUrl: row.visit_url || null,
    latitude:
      row.latitude === null || row.latitude === undefined
        ? null
        : Number(row.latitude),
    longitude:
      row.longitude === null || row.longitude === undefined
        ? null
        : Number(row.longitude),
    merchantName: [row.merchant_first_name, row.merchant_last_name]
      .filter(Boolean)
      .join(' ') || 'Venue owner',
    merchantEmail: row.merchant_email || null,
    merchantPhone: row.merchant_phone || null,
    merchantAvatarUrl: row.merchant_avatar_url || null,
    enabled: !(
      row.enabled === false ||
      row.enabled === 0 ||
      row.enabled === '0' ||
      row.enabled === 'false' ||
      row.enabled === 'FALSE'
    ),
    businessEnabled: !(
      row.enabled === false ||
      row.enabled === 0 ||
      row.enabled === '0' ||
      row.enabled === 'false' ||
      row.enabled === 'FALSE'
    ),
    averageRating: Number(row.average_rating || 0),
    reviewCount: Number(row.review_count || 0),
    ratingUserCount: Number(row.rating_user_count || 0),
  };
}

async function merchantNewsPosts(req, res, next) {
  try {
    const [rows] = await pool.execute(
      `SELECT n.*, b.name AS business_name, b.business_type,
              b.category AS business_category, b.address AS business_address,
              b.latitude, b.longitude,
              b.facility_type, b.opening_hours, b.availability,
              b.price_per_hour, b.event_fee, b.rate_periods,
              b.amenities_json, b.details AS business_details,
              b.image_url AS business_image_url, b.image_urls, b.enabled,
              b.visit_url
       FROM merchant_news n
       INNER JOIN merchant_businesses b ON b.id = n.business_id
       WHERE b.merchant_id = ? ORDER BY n.created_at DESC`,
      [req.auth.sub],
    );
    return res.json({ posts: rows.map(newsPostResponse) });
  } catch (error) { return next(error); }
}

async function createMerchantNewsPost(req, res, next) {
  const businessId = Number(req.body.businessId ?? req.body.venueId);
  const title = normalizeText(req.body.title, 255);
  const body = normalizeText(req.body.body, 5000);
  const status = req.body.status || 'published';
  if (!Number.isSafeInteger(businessId) || businessId <= 0 || !title || !body ||
      !['draft', 'published', 'archived'].includes(status)) {
    return res.status(400).json({ error: 'businessId, title, body, and a valid status are required.' });
  }
  try {
    const [businesses] = await pool.execute(
      'SELECT id, image_url FROM merchant_businesses WHERE id = ? AND merchant_id = ? LIMIT 1',
      [businessId, req.auth.sub],
    );
    if (!businesses[0]) return res.status(404).json({ error: 'Business not found.' });
    const imageUrl = normalizeText(req.body.imageUrl, 10 * 1024 * 1024) || businesses[0].image_url || null;
    const [result] = await pool.execute(
      `INSERT INTO merchant_news (business_id, title, body, image_url, status)
       VALUES (?, ?, ?, ?, ?)`,
      [businessId, title, body, imageUrl, status],
    );
    return res.status(201).json({ id: result.insertId, message: 'News post created.' });
  } catch (error) { return next(error); }
}

async function updateMerchantNewsPost(req, res, next) {
  const id = Number(req.params.id);
  const title = normalizeText(req.body.title, 255);
  const body = normalizeText(req.body.body, 5000);
  const status = req.body.status || 'draft';
  if (!Number.isSafeInteger(id) || id <= 0 || !title || !body ||
      !['draft', 'published', 'archived'].includes(status)) {
    return res.status(400).json({ error: 'A valid title, body, and status are required.' });
  }
  try {
    const imageUrl = normalizeText(req.body.imageUrl, 10 * 1024 * 1024);
    const [result] = await pool.execute(
      `UPDATE merchant_news n INNER JOIN merchant_businesses b ON b.id = n.business_id
       SET n.title = ?, n.body = ?, n.status = ?, n.image_url = COALESCE(NULLIF(?, ''), b.image_url)
       WHERE n.id = ? AND b.merchant_id = ?`,
      [title, body, status, imageUrl, id, req.auth.sub],
    );
    if (!result.affectedRows) return res.status(404).json({ error: 'News post not found.' });
    return res.json({ message: 'News post updated.' });
  } catch (error) { return next(error); }
}

async function deleteMerchantNewsPost(req, res, next) {
  const id = Number(req.params.id);
  if (!Number.isSafeInteger(id) || id <= 0) return res.status(400).json({ error: 'Invalid news post id.' });
  try {
    const [result] = await pool.execute(
      `DELETE n FROM merchant_news n INNER JOIN merchant_businesses b ON b.id = n.business_id
       WHERE n.id = ? AND b.merchant_id = ?`,
      [id, req.auth.sub],
    );
    if (!result.affectedRows) return res.status(404).json({ error: 'News post not found.' });
    return res.json({ message: 'News post deleted.' });
  } catch (error) { return next(error); }
}

app.get('/api/merchant/news', requireAuth, requireRole('merchant'), merchantNewsPosts);
app.post('/api/merchant/news', requireAuth, requireRole('merchant'), createMerchantNewsPost);
app.put('/api/merchant/news/:id', requireAuth, requireRole('merchant'), updateMerchantNewsPost);
app.delete('/api/merchant/news/:id', requireAuth, requireRole('merchant'), deleteMerchantNewsPost);
app.get('/api/merchant/news-posts', requireAuth, requireRole('merchant'), merchantNewsPosts);
app.post('/api/merchant/news-posts', requireAuth, requireRole('merchant'), createMerchantNewsPost);
app.put('/api/merchant/news-posts/:id', requireAuth, requireRole('merchant'), updateMerchantNewsPost);
app.delete('/api/merchant/news-posts/:id', requireAuth, requireRole('merchant'), deleteMerchantNewsPost);

async function customerNewsFeed(req, res, next) {
  try {
    const [rows] = await pool.execute(
      `SELECT n.*, b.name AS business_name, b.business_type,
              b.category AS business_category, b.address AS business_address,
              b.latitude, b.longitude,
              b.facility_type, b.opening_hours, b.availability,
              b.price_per_hour, b.event_fee, b.rate_periods,
              b.amenities_json, b.details AS business_details,
              b.image_url AS business_image_url, b.image_urls, b.enabled,
              b.visit_url,
              u.first_name AS merchant_first_name, u.last_name AS merchant_last_name,
              u.email AS merchant_email, u.phone AS merchant_phone,
              u.avatar_url AS merchant_avatar_url,
              COALESCE((SELECT AVG(r.rating) FROM venue_reviews r WHERE r.business_id = b.id), 0) AS average_rating,
              (SELECT COUNT(*) FROM venue_reviews r WHERE r.business_id = b.id) AS review_count,
              (SELECT COUNT(DISTINCT r.customer_id) FROM venue_reviews r WHERE r.business_id = b.id) AS rating_user_count
       FROM merchant_news n
       INNER JOIN merchant_businesses b ON b.id = n.business_id
       INNER JOIN users u ON u.id = b.merchant_id
       WHERE n.status = 'published'
       ORDER BY n.created_at DESC`,
    );
    return res.json({ posts: rows.map(newsPostResponse) });
  } catch (error) { return next(error); }
}

app.get('/api/news/feed', requireAuth, requireRole('customer'), customerNewsFeed);
app.get('/api/customer/news', requireAuth, requireRole('customer'), customerNewsFeed);
app.get('/api/news-feed', requireAuth, requireRole('customer'), customerNewsFeed);

async function submitCustomerReview(req, res, next) {
  const bookingId = Number(req.body.bookingId);
  const rating = Number(req.body.rating);
  const comment = normalizeText(req.body.comment, 2000) || null;
  if (!Number.isSafeInteger(bookingId) || bookingId <= 0 || !Number.isInteger(rating) || rating < 1 || rating > 5) {
    return res.status(400).json({ error: 'A valid bookingId and rating from 1 to 5 are required.' });
  }
  try {
    const [bookings] = await pool.execute(
      `SELECT id, venue_id FROM bookings
       WHERE id = ? AND customer_id = ? AND status = 'finished' LIMIT 1`,
      [bookingId, req.auth.sub],
    );
    if (!bookings[0]) return res.status(403).json({ error: 'Reviews are only allowed for your completed bookings.' });
    const [existing] = await pool.execute(
      'SELECT id FROM venue_reviews WHERE booking_id = ? AND customer_id = ? LIMIT 1',
      [bookingId, req.auth.sub],
    );
    if (existing[0]) return res.status(409).json({ error: 'You have already reviewed this booking.' });
    const [result] = await pool.execute(
      `INSERT INTO venue_reviews (business_id, booking_id, customer_id, rating, comment)
       VALUES (?, ?, ?, ?, ?)`,
      [bookings[0].venue_id, bookingId, req.auth.sub, rating, comment],
    );
    return res.status(201).json({ id: result.insertId, message: 'Review submitted.' });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'You have already reviewed this booking.' });
    return next(error);
  }
}

async function listBusinessReviews(req, res, next) {
  const businessId = Number(req.params.businessId);
  if (!Number.isSafeInteger(businessId) || businessId <= 0) {
    return res.status(400).json({ error: 'Invalid business id.' });
  }
  try {
    const [rows] = await pool.execute(
      `SELECT r.id, r.business_id AS businessId, r.booking_id AS bookingId,
              r.customer_id AS customerId, r.rating, r.comment, r.created_at AS createdAt,
              u.first_name AS firstName, u.last_name AS lastName
       FROM venue_reviews r INNER JOIN users u ON u.id = r.customer_id
       WHERE r.business_id = ? ORDER BY r.created_at DESC`,
      [businessId],
    );
    return res.json({ reviews: rows });
  } catch (error) { return next(error); }
}

async function submitBusinessReview(req, res, next) {
  const businessId = Number(req.params.businessId);
  const rating = Number(req.body.rating);
  const comment = normalizeText(req.body.comment, 2000) || null;
  if (!Number.isSafeInteger(businessId) || businessId <= 0 ||
      !Number.isInteger(rating) || rating < 1 || rating > 5) {
    return res.status(400).json({ error: 'A valid business id and rating from 1 to 5 are required.' });
  }
  try {
    const [bookings] = await pool.execute(
      `SELECT b.id FROM bookings b
       LEFT JOIN venue_reviews r ON r.booking_id = b.id AND r.customer_id = b.customer_id
       WHERE b.venue_id = ? AND b.customer_id = ? AND b.status = 'finished'
         AND r.id IS NULL ORDER BY b.booking_date DESC, b.id DESC LIMIT 1`,
      [businessId, req.auth.sub],
    );
    if (!bookings[0]) {
      return res.status(403).json({ error: 'A completed, not-yet-reviewed booking is required.' });
    }
    const [result] = await pool.execute(
      `INSERT INTO venue_reviews (business_id, booking_id, customer_id, rating, comment)
       VALUES (?, ?, ?, ?, ?)`,
      [businessId, bookings[0].id, req.auth.sub, rating, comment],
    );
    const [reviews] = await pool.execute(
      `SELECT id, business_id AS businessId, booking_id AS bookingId, customer_id AS customerId,
              rating, comment, created_at AS createdAt
       FROM venue_reviews WHERE id = ?`,
      [result.insertId],
    );
    return res.status(201).json({ review: reviews[0] });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'You have already reviewed this booking.' });
    return next(error);
  }
}

app.get('/api/news-feed/:businessId/reviews', requireAuth, requireRole('customer'), listBusinessReviews);
app.post('/api/news-feed/:businessId/reviews', requireAuth, requireRole('customer'), submitBusinessReview);
app.post('/api/reviews', requireAuth, requireRole('customer'), submitCustomerReview);
app.post('/api/customer/reviews', requireAuth, requireRole('customer'), submitCustomerReview);

app.use((error, req, res, next) => {
  console.error(error);
  if (error.type === 'entity.too.large') {
    return res.status(413).json({
      error: 'The selected images are too large. Choose fewer or smaller images.',
    });
  }
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

async function ensureMerchantBusinessesSchema() {
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS merchant_businesses (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      merchant_id BIGINT UNSIGNED NOT NULL,
      business_type VARCHAR(50) NOT NULL,
      name VARCHAR(255) NOT NULL,
      category VARCHAR(100) NOT NULL,
      address VARCHAR(500) NOT NULL,
      latitude DOUBLE NULL,
      longitude DOUBLE NULL,
      facility_type VARCHAR(50) NOT NULL,
      price_per_hour DECIMAL(10, 2) NOT NULL DEFAULT 0,
      event_fee DECIMAL(10, 2) NOT NULL DEFAULT 0,
      opening_hours VARCHAR(100) NOT NULL DEFAULT 'Open hours',
      availability VARCHAR(255) NOT NULL DEFAULT 'Any',
      enabled TINYINT(1) NOT NULL DEFAULT 1,
      rate_periods JSON NULL,
      included_players INT UNSIGNED NOT NULL DEFAULT 0,
      additional_player_fee DECIMAL(10, 2) NOT NULL DEFAULT 0,
      amenities_json JSON NULL,
      details VARCHAR(1000) NULL,
      image_url LONGTEXT NULL,
      image_urls JSON NULL,
      visit_url VARCHAR(1000) NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_merchant_businesses_merchant (merchant_id, created_at),
      CONSTRAINT fk_merchant_businesses_user
        FOREIGN KEY (merchant_id) REFERENCES users (id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  await ensureTableColumn(
    'merchant_businesses',
    'included_players',
    'INT UNSIGNED NOT NULL DEFAULT 0',
  );
  await ensureTableColumn(
    'merchant_businesses',
    'additional_player_fee',
    'DECIMAL(10, 2) NOT NULL DEFAULT 0',
  );
  await ensureTableColumn('conversation_members', 'archived_at', 'DATETIME NULL');
  await ensureTableColumn('conversation_members', 'deleted_at', 'DATETIME NULL');
  await ensureTableColumn(
    'conversation_members',
    'manually_unread_at',
    'DATETIME NULL',
  );
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS user_blocks (
      blocker_id BIGINT UNSIGNED NOT NULL,
      blocked_user_id BIGINT UNSIGNED NOT NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (blocker_id, blocked_user_id),
      KEY idx_user_blocks_blocked (blocked_user_id),
      CONSTRAINT fk_user_blocks_blocker FOREIGN KEY (blocker_id) REFERENCES users (id)
        ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT fk_user_blocks_blocked FOREIGN KEY (blocked_user_id) REFERENCES users (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);

  const columns = [
    ['price_per_hour', 'DECIMAL(10, 2) NOT NULL DEFAULT 0'],
    ['event_fee', 'DECIMAL(10, 2) NOT NULL DEFAULT 0'],
    ['opening_hours', "VARCHAR(100) NOT NULL DEFAULT 'Open hours'"],
    ['rate_periods', 'JSON NULL'],
    ['amenities_json', 'JSON NULL'],
    ['image_urls', 'JSON NULL'],
    ['visit_url', 'VARCHAR(1000) NULL'],
    ['latitude', 'DOUBLE NULL'],
    ['longitude', 'DOUBLE NULL'],
    ['enabled', 'TINYINT(1) NOT NULL DEFAULT 1'],
  ];

  for (const [name, definition] of columns) {
    try {
      await pool.execute(
        `ALTER TABLE merchant_businesses ADD COLUMN ${name} ${definition}`,
      );
    } catch (error) {
      if (error.code !== 'ER_DUP_FIELDNAME') throw error;
    }
    for (const [name, definition] of [
      ['owner_email', 'VARCHAR(255) NULL'],
      ['owner_phone', 'VARCHAR(30) NULL'],
    ]) {
      try {
        await pool.execute(
          `ALTER TABLE saved_items ADD COLUMN ${name} ${definition}`,
        );
      } catch (error) {
        if (error.code !== 'ER_DUP_FIELDNAME') throw error;
      }
    }
  }
  await pool.execute(
    "ALTER TABLE merchant_businesses MODIFY COLUMN availability VARCHAR(255) NOT NULL DEFAULT 'Any'",
  );
  try {
    await pool.execute(
      'ALTER TABLE merchant_businesses ADD INDEX idx_merchant_businesses_type_enabled (business_type, enabled)',
    );
  } catch (error) {
    if (error.code !== 'ER_DUP_KEYNAME') throw error;
  }
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS sports_business_details (
      business_id BIGINT UNSIGNED NOT NULL,
      player_capacity INT UNSIGNED NULL,
      court_type VARCHAR(100) NULL,
      equipment TEXT NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (business_id),
      CONSTRAINT fk_sports_business_details_business
        FOREIGN KEY (business_id) REFERENCES merchant_businesses (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS event_business_details (
      business_id BIGINT UNSIGNED NOT NULL,
      event_name VARCHAR(255) NULL,
      event_type VARCHAR(100) NULL,
      event_types_json JSON NULL,
      event_date DATE NULL,
      start_time TIME NULL,
      end_time TIME NULL,
      setup_hours DECIMAL(5, 2) NULL,
      teardown_hours DECIMAL(5, 2) NULL,
      estimated_attendance INT UNSIGNED NULL,
      accessibility_needs TEXT NULL,
      parking_security TEXT NULL,
      attendance_min INT UNSIGNED NULL,
      attendance_max INT UNSIGNED NULL,
      parking_needs JSON NULL,
      security_needs JSON NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (business_id),
      CONSTRAINT fk_event_business_details_business
        FOREIGN KEY (business_id) REFERENCES merchant_businesses (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS fitness_business_details (
      business_id BIGINT UNSIGNED NOT NULL,
      class_capacity INT UNSIGNED NULL,
      session_duration_minutes INT UNSIGNED NULL,
      instructor_name VARCHAR(255) NULL,
      class_schedule TEXT NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (business_id),
      CONSTRAINT fk_fitness_business_details_business
        FOREIGN KEY (business_id) REFERENCES merchant_businesses (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  for (const [name, definition] of [
    ['event_types_json', 'JSON NULL'],
    ['attendance_min', 'INT UNSIGNED NULL'],
    ['attendance_max', 'INT UNSIGNED NULL'],
    ['accessibility_needs', 'JSON NULL'],
    ['parking_needs', 'JSON NULL'],
    ['security_needs', 'JSON NULL'],
  ]) {
    await ensureTableColumn('event_business_details', name, definition);
  }
}

async function ensureMessagingSchema() {
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS conversations (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      type ENUM('direct', 'group') NOT NULL DEFAULT 'direct',
      title VARCHAR(120) NULL,
      created_by BIGINT UNSIGNED NOT NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_conversations_created (created_at),
      CONSTRAINT fk_conversations_creator FOREIGN KEY (created_by) REFERENCES users (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS conversation_members (
      conversation_id BIGINT UNSIGNED NOT NULL,
      user_id BIGINT UNSIGNED NOT NULL,
      joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      archived_at DATETIME NULL,
      deleted_at DATETIME NULL,
      manually_unread_at DATETIME NULL,
      PRIMARY KEY (conversation_id, user_id),
      KEY idx_conversation_members_user (user_id),
      CONSTRAINT fk_conversation_members_conversation FOREIGN KEY (conversation_id)
        REFERENCES conversations (id) ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT fk_conversation_members_user FOREIGN KEY (user_id) REFERENCES users (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS messages (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      conversation_id BIGINT UNSIGNED NOT NULL,
      sender_id BIGINT UNSIGNED NOT NULL,
      body TEXT NULL,
      attachment_json LONGTEXT NULL,
      read_at DATETIME NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_messages_conversation_created (conversation_id, created_at),
      KEY idx_messages_unread (conversation_id, read_at),
      CONSTRAINT fk_messages_conversation FOREIGN KEY (conversation_id)
        REFERENCES conversations (id) ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT fk_messages_sender FOREIGN KEY (sender_id) REFERENCES users (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS message_reads (
      message_id BIGINT UNSIGNED NOT NULL,
      user_id BIGINT UNSIGNED NOT NULL,
      read_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (message_id, user_id),
      KEY idx_message_reads_user (user_id, read_at),
      CONSTRAINT fk_message_reads_message FOREIGN KEY (message_id)
        REFERENCES messages (id) ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT fk_message_reads_user FOREIGN KEY (user_id) REFERENCES users (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  try {
    await pool.execute(
      'ALTER TABLE messages ADD COLUMN attachment_json LONGTEXT NULL AFTER body',
    );
  } catch (error) {
    if (error.code !== 'ER_DUP_FIELDNAME') throw error;
  }
  await pool.execute('ALTER TABLE messages MODIFY COLUMN body TEXT NULL');
}

async function ensureBookingsSchema() {
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS bookings (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      customer_id BIGINT UNSIGNED NOT NULL,
      venue_id BIGINT UNSIGNED NOT NULL,
      booking_date DATE NOT NULL,
      start_time TIME NOT NULL,
      duration_hours DECIMAL(5, 2) NOT NULL,
      players INT UNSIGNED NOT NULL,
      payment_method VARCHAR(50) NOT NULL,
      price_per_hour DECIMAL(10, 2) NOT NULL,
      total_amount DECIMAL(10, 2) NOT NULL,
      downpayment_amount DECIMAL(10, 2) NOT NULL,
      extra_player_charge DECIMAL(10, 2) NOT NULL DEFAULT 0,
      booking_token_hash CHAR(64) NULL,
      ticket_token_hash CHAR(64) NULL,
      status ENUM('pending', 'approved', 'finished', 'cancelled') NOT NULL DEFAULT 'pending',
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_bookings_customer (customer_id, booking_date, start_time),
      KEY idx_bookings_venue_time (venue_id, booking_date, start_time, status),
      CONSTRAINT fk_bookings_customer FOREIGN KEY (customer_id) REFERENCES users (id)
        ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT fk_bookings_venue FOREIGN KEY (venue_id) REFERENCES merchant_businesses (id)
        ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  for (const [name, definition] of [
    ['booking_token_hash', 'CHAR(64) NULL'],
    ['ticket_token_hash', 'CHAR(64) NULL'],
    ['extra_player_charge', 'DECIMAL(10, 2) NOT NULL DEFAULT 0'],
  ]) {
    await ensureTableColumn('bookings', name, definition);
  }
}

async function ensureTableColumn(tableName, columnName, definition) {
  const [rows] = await pool.execute(
    `SELECT 1
       FROM information_schema.columns
      WHERE table_schema = DATABASE()
        AND table_name = ?
        AND column_name = ?
      LIMIT 1`,
    [tableName, columnName],
  );
  if (rows.length > 0) return;
  await pool.execute(
    `ALTER TABLE \`${tableName}\` ADD COLUMN \`${columnName}\` ${definition}`,
  );
}

async function ensureCustomerProfileSchema() {
  await pool.execute('ALTER TABLE users MODIFY COLUMN avatar_url LONGTEXT NULL');
  await ensureTableColumn('users', 'address', 'VARCHAR(500) NULL');
  await ensureTableColumn('users', 'hobby', 'VARCHAR(255) NULL');
}

async function ensureNewsAndReviewsSchema() {
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS merchant_news (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      business_id BIGINT UNSIGNED NOT NULL,
      title VARCHAR(255) NOT NULL,
      body TEXT NOT NULL,
      image_url LONGTEXT NULL,
      status ENUM('draft', 'published', 'archived') NOT NULL DEFAULT 'draft',
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_merchant_news_business_status (business_id, status, created_at),
      CONSTRAINT fk_merchant_news_business FOREIGN KEY (business_id)
        REFERENCES merchant_businesses (id) ON UPDATE CASCADE ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS venue_reviews (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      business_id BIGINT UNSIGNED NOT NULL,
      booking_id BIGINT UNSIGNED NOT NULL,
      customer_id BIGINT UNSIGNED NOT NULL,
      rating TINYINT UNSIGNED NOT NULL,
      comment VARCHAR(2000) NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uq_venue_reviews_booking_customer (booking_id, customer_id),
      KEY idx_venue_reviews_business (business_id, created_at),
      CONSTRAINT fk_venue_reviews_business FOREIGN KEY (business_id)
        REFERENCES merchant_businesses (id) ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT fk_venue_reviews_booking FOREIGN KEY (booking_id)
        REFERENCES bookings (id) ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT fk_venue_reviews_customer FOREIGN KEY (customer_id)
        REFERENCES users (id) ON UPDATE CASCADE ON DELETE CASCADE,
      CONSTRAINT chk_venue_reviews_rating CHECK (rating BETWEEN 1 AND 5)
    ) ENGINE=InnoDB
  `);
}

Promise.all([ensureMerchantBusinessesSchema(), ensureMessagingSchema()])
  .then(() => ensureBookingsSchema())
  .then(() => ensureCustomerProfileSchema())
  .then(() => ensureNewsAndReviewsSchema())
  .then(() => {
    app.listen(port, () => {
      console.log(`TinkerPro Sports API listening on http://localhost:${port}`);
    });
  })
  .catch((error) => {
    console.error('Could not initialize merchant business schema.', error);
    process.exitCode = 1;
  });
