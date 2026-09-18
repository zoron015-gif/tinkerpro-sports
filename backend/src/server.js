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
app.use(express.json({ limit: '12mb' }));

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
    phone: user.phone || null,
    avatarUrl: user.avatar_url || null,
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
      `SELECT id, email, first_name, last_name, phone, avatar_url, role, status
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
      `SELECT id, business_type AS businessType, name, category, address,
              facility_type AS facilityType, price_per_hour AS pricePerHour,
              opening_hours AS hours, availability,
              amenities_json AS tags, details, image_url AS imageUrl,
              created_at AS createdAt
       FROM merchant_businesses
       WHERE merchant_id = ?
       ORDER BY created_at DESC`,
      [req.auth.sub],
    );
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

app.post('/api/merchant/businesses', requireAuth, async (req, res, next) => {
  const text = (value, max = 255) =>
    typeof value === 'string' ? value.trim().slice(0, max) : '';
  const businessType = text(req.body.businessType, 50);
  const name = text(req.body.name);
  const category = text(req.body.category, 100);
  const address = text(req.body.address, 500);
  const facilityType = text(req.body.facilityType, 50);
  const pricePerHour = Number(req.body.pricePerHour);
  const hours = text(req.body.hours, 100);
  const availability = text(req.body.availability, 50);
  const amenities = Array.isArray(req.body.tags)
    ? req.body.tags.filter((item) => typeof item === 'string').slice(0, 20)
    : [];
  const details = text(req.body.details, 1000);
  const imageUrl = text(req.body.imageUrl, 10 * 1024 * 1024);
  const allowedBusinessTypes = new Set([
    'Sports',
    'Event',
    'Fitness & Wellness',
  ]);
  if (
    !allowedBusinessTypes.has(businessType) ||
    !name ||
    !category ||
    !address ||
    !facilityType ||
    !hours ||
    !Number.isFinite(pricePerHour) ||
    pricePerHour <= 0
  ) {
    return res.status(400).json({
      error:
        'Booking type, business name, category, address, and facility type are required.',
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
    await pool.execute(
      `INSERT INTO merchant_businesses
       (merchant_id, business_type, name, category, address, facility_type,
        price_per_hour, opening_hours, availability, amenities_json,
        details, image_url)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        req.auth.sub,
        businessType,
        name,
        category,
        address,
        facilityType,
        pricePerHour,
        hours,
        availability || 'Any',
        JSON.stringify(amenities),
        details || null,
        imageUrl || null,
      ],
    );
    return res.status(201).json({ message: 'Business added.' });
  } catch (error) {
    return next(error);
  }
});

app.get('/api/saved-items', requireAuth, async (req, res, next) => {
  try {
    const [items] = await pool.execute(
      `SELECT id, item_type AS itemType, item_key AS itemKey,
              title, subtitle, image_url AS imageUrl, created_at AS createdAt
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
    await pool.execute(
      `INSERT INTO saved_items
       (user_id, item_type, item_key, title, subtitle, image_url)
       VALUES (?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE title = VALUES(title), subtitle = VALUES(subtitle),
                               image_url = VALUES(image_url)`,
      [req.auth.sub, itemType, itemKey, title, subtitle || null, imageUrl],
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

async function ensureMerchantBusinessesSchema() {
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS merchant_businesses (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      merchant_id BIGINT UNSIGNED NOT NULL,
      business_type VARCHAR(50) NOT NULL,
      name VARCHAR(255) NOT NULL,
      category VARCHAR(100) NOT NULL,
      address VARCHAR(500) NOT NULL,
      facility_type VARCHAR(50) NOT NULL,
      price_per_hour DECIMAL(10, 2) NOT NULL DEFAULT 0,
      opening_hours VARCHAR(100) NOT NULL DEFAULT 'Open hours',
      availability VARCHAR(50) NOT NULL DEFAULT 'Any',
      amenities_json JSON NULL,
      details VARCHAR(1000) NULL,
      image_url LONGTEXT NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_merchant_businesses_merchant (merchant_id, created_at),
      CONSTRAINT fk_merchant_businesses_user
        FOREIGN KEY (merchant_id) REFERENCES users (id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
    ) ENGINE=InnoDB
  `);

  const columns = [
    ['price_per_hour', 'DECIMAL(10, 2) NOT NULL DEFAULT 0'],
    ['opening_hours', "VARCHAR(100) NOT NULL DEFAULT 'Open hours'"],
    ['availability', "VARCHAR(50) NOT NULL DEFAULT 'Any'"],
    ['amenities_json', 'JSON NULL'],
  ];

  for (const [name, definition] of columns) {
    try {
      await pool.execute(
        `ALTER TABLE merchant_businesses ADD COLUMN ${name} ${definition}`,
      );
    } catch (error) {
      if (error.code !== 'ER_DUP_FIELDNAME') throw error;
    }
  }
}

ensureMerchantBusinessesSchema()
  .then(() => {
    app.listen(port, () => {
      console.log(`TinkerPro Sports API listening on http://localhost:${port}`);
    });
  })
  .catch((error) => {
    console.error('Could not initialize merchant business schema.', error);
    process.exitCode = 1;
  });
