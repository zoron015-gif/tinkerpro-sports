require('dotenv').config();

const bcrypt = require('bcryptjs');
const cors = require('cors');
const crypto = require('crypto');
const { AsyncLocalStorage } = require('node:async_hooks');
const express = require('express');
const jwt = require('jsonwebtoken');
const pool = require('./db');
const { sendPasswordResetCode, sendVerificationCode } = require('./mailer');
const { createRateLimiter } = require('./rate_limit');
const readCache = require('./read_cache');
const {
  fitnessDetailsFromBody,
  saveEventDetails,
  saveFitnessDetails,
} = require('./business_details');
const {
  createBookingToken,
  createVerificationCode,
  hashBookingToken,
  hashVerificationCode,
  isNumericInput,
  isValidEmail,
  isValidRole,
  normalizeEmail,
  normalizeText,
  parseBusinessCoordinates,
  parseJsonArray,
  publicMessageUser,
  publicUser,
} = require('./normalizers');

const {
  newsPostResponse,
  registerMerchantNewsRoutes,
} = require('./routes/merchant_news_routes');
const { registerAuthRoutes } = require('./routes/auth_routes');

const app = express();
app.set('json escape', true);
const auditContextStorage = new AsyncLocalStorage();
const port = Number(process.env.PORT || 3000);
const customerBusinessesCacheKey = 'customer-businesses';
const customerBusinessesCacheTtlMs = 30_000;

function bookingTransactionId(bookingId) {
  return `TP-TXN-${String(bookingId).padStart(8, '0')}`;
}

function positiveIntegerId(value) {
  if (
    (typeof value !== 'string' && typeof value !== 'number') ||
    (typeof value === 'string' && !/^[1-9]\d*$/.test(value))
  ) {
    return null;
  }
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null;
}

function venueCheckInCode(venueId) {
  const issuedAt = Math.floor(Date.now() / 60_000) * 60_000;
  const payload = `v1:${venueId}:${issuedAt}`;
  const signature = crypto
    .createHmac('sha256', process.env.JWT_SECRET)
    .update(payload)
    .digest('hex');
  return {
    type: 'tinkerpro.checkin',
    version: 1,
    venueId,
    issuedAt,
    signature,
  };
}

function verifyVenueCheckInCode(value) {
  if (typeof value !== 'string' || value.length > 512) return null;
  let code;
  try {
    code = JSON.parse(value);
  } catch {
    return null;
  }
  if (
    !code ||
    code.type !== 'tinkerpro.checkin' ||
    code.version !== 1 ||
    !Number.isSafeInteger(code.venueId) ||
    code.venueId <= 0 ||
    !Number.isSafeInteger(code.issuedAt) ||
    code.issuedAt % 60_000 !== 0 ||
    typeof code.signature !== 'string' ||
    !/^[a-f0-9]{64}$/i.test(code.signature)
  ) {
    return null;
  }
  const now = Date.now();
  if (code.issuedAt > now + 30_000 || now - code.issuedAt > 120_000) {
    return null;
  }
  const expected = crypto
    .createHmac('sha256', process.env.JWT_SECRET)
    .update(`v1:${code.venueId}:${code.issuedAt}`)
    .digest();
  const supplied = Buffer.from(code.signature, 'hex');
  if (!crypto.timingSafeEqual(expected, supplied)) return null;
  return { venueId: code.venueId, issuedAt: code.issuedAt };
}

function manilaDateTime(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Manila',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map(({ type, value }) => [type, value]));
  return {
    date: `${values.year}-${values.month}-${values.day}`,
    minutes: Number(values.hour) * 60 + Number(values.minute),
  };
}

function bookingCheckInWindowIncludesNow(booking, currentMinutes) {
  const time = String(booking.startTime ?? '').match(/^([01]\d|2[0-3]):([0-5]\d)/);
  const durationHours = Number(booking.durationHours);
  if (!time || !Number.isFinite(durationHours) || durationHours <= 0) {
    return false;
  }
  const startMinutes = Number(time[1]) * 60 + Number(time[2]);
  return currentMinutes >= startMinutes - 30 &&
    currentMinutes <= startMinutes + durationHours * 60 + 15;
}

function normalizeBusinessType(value) {
  if (typeof value !== 'string') return null;
  return {
    sports: 'sports',
    fitness: 'fitness & wellness',
    'fitness & wellness': 'fitness & wellness',
    event: 'event',
  }[value.trim().toLowerCase()] ?? null;
}

async function isConversationForBusinessType(conversationId, userId, businessType) {
  const [rows] = await pool.execute(
    `SELECT 1
     FROM conversation_members cm
     JOIN conversations c ON c.id = cm.conversation_id
     JOIN bookings b ON c.title = CONCAT('Booking ', b.id)
     JOIN merchant_businesses v ON v.id = b.venue_id
     WHERE cm.conversation_id = ? AND cm.user_id = ?
       AND cm.deleted_at IS NULL AND LOWER(v.business_type) = ?
     LIMIT 1`,
    [conversationId, userId, businessType],
  );
  return rows.length > 0;
}

function invalidateCustomerBusinesses() {
  readCache.invalidate(customerBusinessesCacheKey);
}

function setAuditActor(userId, role) {
  const auditContext = auditContextStorage.getStore();
  if (!auditContext) return;
  auditContext.actorUserId = userId == null ? null : String(userId);
  auditContext.actorRole = typeof role === 'string' ? role : null;
}

if (!process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET must be set in the backend .env file.');
}
app.use((req, res, next) => {
  res.set('X-Content-Type-Options', 'nosniff');
  const userAgent = (req.get('user-agent') || '')
    .replace(/[\u0000-\u001f\u007f]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const context = {
    requestId: crypto.randomUUID(),
    actorUserId: null,
    actorRole: null,
    ipAddress: typeof req.ip === 'string' ? req.ip.slice(0, 45) : null,
    userAgent: userAgent.slice(0, 500) || null,
  };
  res.set('X-Request-Id', context.requestId);
  auditContextStorage.run(context, next);
});
app.use(cors({
  origin: process.env.CLIENT_ORIGIN || true,
  exposedHeaders: ['X-Request-Id'],
}));
app.use(express.json({
  limit: '20mb',
  verify: (req, _res, buffer) => {
    if (req.originalUrl.startsWith('/api/payments/paymongo/webhook')) {
      req.rawBody = Buffer.from(buffer);
    }
  },
}));
app.use((req, res, next) => {
  if (
    req.body === undefined &&
    req.path.startsWith('/api/') &&
    ['POST', 'PUT', 'PATCH'].includes(req.method)
  ) {
    req.body = {};
  }
  if (
    req.body !== undefined &&
    (req.body === null ||
      typeof req.body !== 'object' ||
      Array.isArray(req.body))
  ) {
    return res.status(400).json({
      error: 'The request body must be a JSON object.',
    });
  }
  next();
});

function validateBusinessPayload(body) {
  const errors = [];
  const textLimits = {
    businessType: 50,
    name: 255,
    category: 100,
    address: 500,
    facilityType: 50,
    hours: 100,
    availability: 255,
    visitUrl: 1000,
    details: 1000,
    imageUrl: 10 * 1024 * 1024,
  };
  for (const [field, limit] of Object.entries(textLimits)) {
    const value = body[field];
    if (value !== undefined && value !== null &&
        (typeof value !== 'string' || value.length > limit)) {
      errors.push(field);
    }
  }

  for (const field of ['pricePerHour', 'eventFee', 'additionalPlayerFee']) {
    const value = body[field];
    if (
      value !== undefined &&
      value !== null &&
      value !== '' &&
      (!isNumericInput(value) ||
        Number(value) < 0 ||
        Number(value) > 99999999.99)
    ) {
      errors.push(field);
    }
  }
  for (const [field, min, max] of [
    ['includedPlayers', 0, 30],
    ['slotCount', 1, 100],
    ['attendanceMin', 1, 100000],
    ['attendanceMax', 1, 100000],
  ]) {
    const value = body[field];
    if (
      value !== undefined &&
      value !== null &&
      value !== '' &&
      (!isNumericInput(value) ||
        !Number.isInteger(Number(value)) ||
        Number(value) < min ||
        Number(value) > max)
    ) {
      errors.push(field);
    }
  }
  if (
    isNumericInput(body.attendanceMin) &&
    isNumericInput(body.attendanceMax) &&
    Number(body.attendanceMin) > Number(body.attendanceMax)
  ) {
    errors.push('attendanceMin', 'attendanceMax');
  }

  for (const [field, maxItems, maxLength] of [
    ['tags', 20, 255],
    ['imageUrls', 20, 10 * 1024 * 1024],
    ['eventTypes', 20, 100],
    ['accessibilityNeeds', 20, 255],
    ['parkingNeeds', 20, 255],
    ['securityNeeds', 20, 255],
  ]) {
    const value = body[field];
    if (
      value !== undefined &&
      (!Array.isArray(value) ||
        value.length > maxItems ||
        value.some(
          (item) => typeof item !== 'string' || item.length > maxLength,
        ))
    ) {
      errors.push(field);
    }
  }
  for (const field of ['ratePeriods', 'sportsSlots', 'fitnessCategories', 'fitnessCoaches']) {
    const value = body[field];
    if (value !== undefined && (!Array.isArray(value) || value.length > 20)) {
      errors.push(field);
    }
  }
  if (body.ratePeriods !== undefined && Array.isArray(body.ratePeriods)) {
    for (const period of body.ratePeriods) {
      if (
        !period ||
        typeof period !== 'object' ||
        Array.isArray(period) ||
        typeof period.start !== 'string' ||
        !/^([01]\d|2[0-3]):[0-5]\d$/.test(period.start) ||
        typeof period.end !== 'string' ||
        !/^([01]\d|2[0-3]):[0-5]\d$/.test(period.end) ||
        Number(period.end.replace(':', '')) <=
          Number(period.start.replace(':', '')) ||
        !isNumericInput(period.pricePerHour) ||
        Number(period.pricePerHour) <= 0 ||
        Number(period.pricePerHour) > 99999999.99
      ) {
        errors.push('ratePeriods');
        break;
      }
    }
  }
  if (
    body.visitUrl !== undefined &&
    body.visitUrl !== null &&
    body.visitUrl !== ''
  ) {
    try {
      const url = new URL(body.visitUrl);
      if (!['http:', 'https:'].includes(url.protocol) || !url.hostname) {
        errors.push('visitUrl');
      }
    } catch {
      errors.push('visitUrl');
    }
  }
  return [...new Set(errors)];
}

function hasValidPaymongoSignature(rawBody, signatureHeader, liveMode, secret) {
  if (!rawBody || !signatureHeader || !secret) return false;
  const signatureParts = Object.fromEntries(
    signatureHeader
      .split(',')
      .map((part) => part.trim().split('=', 2))
      .filter(([key, value]) => key && value),
  );
  const timestamp = signatureParts.t;
  const providedSignature = signatureParts[liveMode ? 'li' : 'te'];
  if (!timestamp || !providedSignature) return false;

  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(`${timestamp}.${rawBody.toString('utf8')}`)
    .digest('hex');
  const expected = Buffer.from(expectedSignature, 'hex');
  const provided = Buffer.from(providedSignature, 'hex');
  return expected.length === provided.length &&
    crypto.timingSafeEqual(expected, provided);
}

function isConfiguredPaymentValue(value) {
  return typeof value === 'string' &&
    value.trim().length > 0 &&
    !/^(your_|replace-with|sk_test_your|whsk_your)/i.test(value.trim());
}

function paymongoIsConfigured() {
  return [
    process.env.PAYMONGO_SECRET_KEY,
    process.env.PAYMONGO_WEBHOOK_SECRET,
    process.env.PAYMONGO_SUCCESS_URL,
    process.env.PAYMONGO_CANCEL_URL,
  ].every(isConfiguredPaymentValue);
}

function bookingStartsAtLeastSixHoursAway(booking, now = new Date()) {
  const date = dateOnly(booking.bookingDate);
  const time = String(booking.startTime ?? '').slice(0, 8);
  if (!validCalendarDate(date) || !/^\d{2}:\d{2}:\d{2}$/.test(time)) {
    return false;
  }
  const startTimestamp = Date.parse(`${date}T${time}+08:00`);
  return Number.isFinite(startTimestamp) &&
    startTimestamp - now.getTime() >= 6 * 60 * 60 * 1000;
}

async function requestPaymongoBookingRefund(booking) {
  const bookingId = Number(booking.id);
  const paymentReference = String(booking.paymentReference ?? '');
  const amount = Number(booking.paidAmount);
  try {
    if (!isConfiguredPaymentValue(process.env.PAYMONGO_SECRET_KEY)) {
      throw new Error('PayMongo refunds are not configured.');
    }
    if (!/^pay_[A-Za-z0-9_-]+$/.test(paymentReference)) {
      throw new Error('The booking has no refundable PayMongo payment reference.');
    }
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new Error('The booking has no paid amount to refund.');
    }
    const response = await fetch('https://api.paymongo.com/v1/refunds', {
      method: 'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(`${process.env.PAYMONGO_SECRET_KEY}:`).toString('base64')}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
        'Idempotency-Key': `booking-cancellation-refund-${bookingId}`,
      },
      body: JSON.stringify({
        data: {
          attributes: {
            amount: Math.round(amount * 100),
            payment_id: paymentReference,
            reason: 'others',
            notes: `Customer cancelled booking ${bookingId}.`,
          },
        },
      }),
    });
    const payload = await response.json();
    if (!response.ok) {
      throw new Error(
        payload?.errors?.[0]?.detail || 'PayMongo could not process the refund.',
      );
    }
    const refundId = payload?.data?.id;
    if (typeof refundId !== 'string' || refundId.trim().length === 0) {
      throw new Error('PayMongo returned no refund reference.');
    }
    const refundStatus =
      payload?.data?.attributes?.status === 'succeeded' ? 'succeeded' : 'pending';
    await pool.execute(
      `UPDATE bookings
       SET payment_refund_status = ?, payment_refund_id = ?
       WHERE id = ? AND payment_refund_status = 'pending'`,
      [refundStatus, refundId, bookingId],
    );
    return refundStatus;
  } catch (error) {
    console.error('Booking payment refund failed.', {
      bookingId,
      error,
    });
    await pool.execute(
      `UPDATE bookings
       SET payment_refund_status = 'failed'
       WHERE id = ? AND payment_refund_status = 'pending'`,
      [bookingId],
    );
    return 'failed';
  }
}

async function recordUserActivity(
  executor,
  userId,
  activityType,
  title,
  description,
  venueDetails = null,
) {
  const auditContext = auditContextStorage.getStore() || {};
  await executor.execute(
    `INSERT INTO user_activity_logs
       (user_id, activity_type, title, description, venue_id, venue_name,
        sport_type, details_json, actor_user_id, actor_role, request_id,
        ip_address, user_agent)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      userId,
      activityType,
      title,
      description,
      venueDetails?.venueId ?? null,
      venueDetails?.venueName ?? null,
      venueDetails?.sportType ?? null,
      venueDetails ? JSON.stringify(venueDetails.details ?? {}) : null,
      auditContext.actorUserId ?? null,
      auditContext.actorRole ?? null,
      auditContext.requestId ?? null,
      auditContext.ipAddress ?? null,
      auditContext.userAgent ?? null,
    ],
  );
}

function requireAuth(req, res, next) {
  const header = req.get('authorization') || '';
  const [scheme, value] = header.split(' ');

  if (scheme !== 'Bearer' || !value) {
    return res.status(401).json({ error: 'A Bearer token is required.' });
  }

  try {
    req.auth = jwt.verify(value, process.env.JWT_SECRET);
    setAuditActor(req.auth.sub, req.auth.role);
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
  const conversationId = positiveIntegerId(req.params.id);
  if (conversationId === null) {
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
  const conversationId = positiveIntegerId(req.params.id);
  if (conversationId === null) {
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
  const blockedUserId = positiveIntegerId(req.params.userId);
  if (blockedUserId === null ||
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
  const blockedUserId = positiveIntegerId(req.params.userId);
  if (blockedUserId === null) {
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

registerAuthRoutes({
  app,
  pool,
  bcrypt,
  jwt,
  createRateLimiter,
  sendPasswordResetCode,
  sendVerificationCode,
  requireAuth,
  normalizeEmail,
  isValidEmail,
  isValidRole,
  createVerificationCode,
  hashVerificationCode,
  normalizeText,
  publicUser,
  recordUserActivity,
  setAuditActor,
  invalidateCustomerBusinesses,
  fetch,
  googleClientId: process.env.GOOGLE_CLIENT_ID ||
    '451592121635-f7hgfk7plbi3mngvor1eenrup21mlbg5.apps.googleusercontent.com',
  environment: process.env,
});

app.get('/api/activity-logs', requireAuth, async (req, res, next) => {
  try {
    const [activities] = await pool.execute(
      `SELECT id, activity_type AS activityType, title, description,
              venue_id AS venueId, venue_name AS venueName,
              sport_type AS sportType, details_json AS details,
              actor_role AS actorRole, request_id AS requestId,
              created_at AS createdAt
       FROM user_activity_logs
       WHERE user_id = ?
       ORDER BY created_at DESC, id DESC`,
      [req.auth.sub],
    );
    return res.json({ activities });
  } catch (error) {
    return next(error);
  }
});

app.get('/api/messages/owner', requireAuth, async (req, res, next) => {
  const key = typeof req.query.businessKey === 'string'
    ? req.query.businessKey.trim()
    : '';
  if (!key || key.length > 255) {
    return res.status(400).json({ error: 'A valid business key is required.' });
  }
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
    const params = [
      req.auth.sub,
      req.auth.sub,
      req.auth.sub,
      req.auth.sub,
      req.auth.sub,
    ];
    let bookingTypeFilter = '';
    if (req.query.businessType !== undefined) {
      const businessType = normalizeBusinessType(req.query.businessType);
      if (!businessType) {
        return res.status(400).json({ error: 'Invalid business type filter.' });
      }
      bookingTypeFilter = `AND EXISTS (
        SELECT 1
        FROM bookings b
        JOIN merchant_businesses v ON v.id = b.venue_id
        WHERE c.title = CONCAT('Booking ', b.id)
          AND LOWER(v.business_type) = ?
      )`;
      params.push(businessType);
    }
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
         ${bookingTypeFilter}
       ORDER BY COALESCE(m.created_at, c.created_at) DESC`,
      params,
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
  const rawParticipantIds = req.body.participantIds;
  const participantIdsValid = rawParticipantIds === undefined ||
    (Array.isArray(rawParticipantIds) &&
      rawParticipantIds.length <= 20 &&
      rawParticipantIds.every((id) => positiveIntegerId(id) !== null));
  const requestedIds = Array.isArray(rawParticipantIds)
    ? rawParticipantIds.map(positiveIntegerId)
    : [];
  const recipientId = req.body.recipientId === undefined
    ? null
    : positiveIntegerId(req.body.recipientId);
  if (recipientId !== null) requestedIds.push(recipientId);
  const participantIds = [...new Set(requestedIds)].filter(
    (id) => id !== Number(req.auth.sub),
  );
  const requestedType = req.body.type;
  const isGroup = req.body.type === 'group' || participantIds.length > 1;
  const title = typeof req.body.title === 'string'
    ? req.body.title.trim().slice(0, 120)
    : null;
  if (
    !participantIdsValid ||
    (req.body.recipientId !== undefined && recipientId === null) ||
    (requestedType !== undefined &&
      !['direct', 'group'].includes(requestedType)) ||
    (req.body.title !== undefined &&
      (typeof req.body.title !== 'string' || req.body.title.length > 120)) ||
    (requestedType === 'direct' && participantIds.length > 1) ||
    participantIds.length === 0
  ) {
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
    const conversationId = positiveIntegerId(req.params.id);
    if (conversationId === null) {
      return res.status(400).json({ error: 'The conversation is invalid.' });
    }
    const businessType = req.query.businessType === undefined
      ? null
      : normalizeBusinessType(req.query.businessType);
    if (req.query.businessType !== undefined && !businessType) {
      return res.status(400).json({ error: 'Invalid business type filter.' });
    }
    const [members] = await pool.execute(
      `SELECT 1 FROM conversation_members
       WHERE conversation_id = ? AND user_id = ? AND deleted_at IS NULL`,
      [conversationId, req.auth.sub],
    );
    if (members.length === 0) {
      return res.status(403).json({ error: 'You are not a member of this conversation.' });
    }
    if (
      businessType &&
      !(await isConversationForBusinessType(
        conversationId,
        req.auth.sub,
        businessType,
      ))
    ) {
      return res.status(404).json({ error: 'Conversation not found.' });
    }
    const [readScopeRows] = await pool.execute(
      `SELECT c.type, cm.archived_at AS archivedAt,
              (SELECT peer.user_id FROM conversation_members peer
               WHERE peer.conversation_id = c.id
                 AND peer.user_id <> cm.user_id
                 AND peer.deleted_at IS NULL
               LIMIT 1) AS peerId
       FROM conversations c
       JOIN conversation_members cm ON cm.conversation_id = c.id
       WHERE c.id = ? AND cm.user_id = ? AND cm.deleted_at IS NULL`,
      [conversationId, req.auth.sub],
    );
    const readScope = readScopeRows[0];
    let readConversationIds = [conversationId];
    const peerId = positiveIntegerId(readScope?.peerId);
    if (readScope?.type === 'direct' && peerId !== null) {
      const businessTypeFilter = businessType
        ? `AND EXISTS (
             SELECT 1 FROM bookings b
             JOIN merchant_businesses v ON v.id = b.venue_id
             WHERE c.title = CONCAT('Booking ', b.id)
               AND LOWER(v.business_type) = ?
           )`
        : '';
      const duplicateParams = [
        req.auth.sub,
        peerId,
        readScope.archivedAt,
        req.auth.sub,
        peerId,
      ];
      if (businessType) duplicateParams.push(businessType);
      const [duplicateConversations] = await pool.execute(
        `SELECT c.id
         FROM conversations c
         JOIN conversation_members viewer
           ON viewer.conversation_id = c.id
          AND viewer.user_id = ? AND viewer.deleted_at IS NULL
         JOIN conversation_members peer
           ON peer.conversation_id = c.id
          AND peer.user_id = ? AND peer.deleted_at IS NULL
         WHERE c.type = 'direct'
           AND viewer.archived_at <=> ?
           AND NOT EXISTS (
             SELECT 1 FROM conversation_members extra
             WHERE extra.conversation_id = c.id
               AND extra.deleted_at IS NULL
               AND extra.user_id NOT IN (?, ?)
           )
           ${businessTypeFilter}`,
        duplicateParams,
      );
      readConversationIds = [
        ...new Set([
          conversationId,
          ...duplicateConversations.map((row) => Number(row.id)),
        ]),
      ];
    }
    const readConversationPlaceholders = readConversationIds
      .map(() => '?')
      .join(', ');
    await pool.execute(
      `UPDATE conversation_members SET manually_unread_at = NULL
       WHERE conversation_id IN (${readConversationPlaceholders})
         AND user_id = ?`,
      [...readConversationIds, req.auth.sub],
    );
    await pool.execute(
      `INSERT IGNORE INTO message_reads (message_id, user_id)
       SELECT id, ? FROM messages
       WHERE conversation_id IN (${readConversationPlaceholders})
         AND sender_id <> ?`,
      [req.auth.sub, ...readConversationIds, req.auth.sub],
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
  const conversationId = positiveIntegerId(req.params.conversationId);
  const messageId = positiveIntegerId(req.params.messageId);
  if (conversationId === null || messageId === null) {
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
  const businessType = req.body.businessType === undefined
    ? null
    : normalizeBusinessType(req.body.businessType);
  if (req.body.businessType !== undefined && !businessType) {
    return res.status(400).json({ error: 'Invalid business type filter.' });
  }
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
    const conversationId = positiveIntegerId(req.params.id);
    if (conversationId === null) {
      return res.status(400).json({ error: 'The conversation is invalid.' });
    }
    const [members] = await pool.execute(
      `SELECT 1 FROM conversation_members
       WHERE conversation_id = ? AND user_id = ? AND deleted_at IS NULL`,
      [conversationId, req.auth.sub],
    );
    if (members.length === 0) {
      return res.status(403).json({ error: 'You are not a member of this conversation.' });
    }
    if (
      businessType &&
      !(await isConversationForBusinessType(
        conversationId,
        req.auth.sub,
        businessType,
      ))
    ) {
      return res.status(404).json({ error: 'Conversation not found.' });
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
    await recordUserActivity(
      pool,
      req.auth.sub,
      'message_sent',
      'Message sent',
      'You sent a message in a conversation.',
    );
    return res.status(201).json({ message: 'Message sent.' });
  } catch (error) {
    return next(error);
  }
});

app.get('/api/merchant/profile', requireAuth, requireRole('merchant'), async (req, res, next) => {
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

app.put('/api/merchant/profile', requireAuth, requireRole('merchant'), async (req, res, next) => {
  const text = (value, max = 255) =>
    typeof value === 'string' ? value.trim().slice(0, max) : '';
  const profileTextLimits = {
    businessName: 255,
    businessType: 255,
    registrationNumber: 255,
    facilityType: 255,
    address: 500,
    contactEmail: 254,
    ownerDesignation: 255,
    firstName: 100,
    lastName: 100,
    phone: 30,
    profileImage: 10 * 1024 * 1024,
    businessImage: 10 * 1024 * 1024,
  };
  const invalidProfileText = Object.entries(profileTextLimits).some(
    ([field, maxLength]) => req.body[field] != null &&
      (typeof req.body[field] !== 'string' ||
        req.body[field].length > maxLength),
  );
  const invalidCategories = req.body.categories !== undefined &&
    (!Array.isArray(req.body.categories) ||
      req.body.categories.length > 12 ||
      req.body.categories.some(
        (category) => typeof category !== 'string' || category.length > 100,
      ));
  if (
    invalidProfileText ||
    invalidCategories ||
    (typeof req.body.contactEmail === 'string' &&
      req.body.contactEmail.trim() !== '' &&
      !isValidEmail(req.body.contactEmail.trim()))
  ) {
    return res.status(400).json({ error: 'One or more merchant profile fields are invalid.' });
  }
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
    invalidateCustomerBusinesses();
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
    await recordUserActivity(
      pool,
      req.auth.sub,
      'merchant_profile_updated',
      'Merchant profile updated',
      'Your merchant profile details were changed.',
      {
        details: {
          businessName,
          businessType,
          categoriesCount: categories.length,
        },
      },
    );
    return res.json({ message: 'Merchant profile saved.' });
  } catch (error) {
    return next(error);
  }
});

app.get('/api/merchant/businesses', requireAuth, requireRole('merchant'), async (req, res, next) => {
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
              b.slot_count AS slotCount,
              b.sports_slots_json AS sportsSlots,
              b.visit_url AS visitUrl,
              b.opening_hours AS hours, b.availability,
              b.enabled,
              b.rate_periods AS ratePeriods,
              e.event_types_json AS eventTypes, e.attendance_min AS attendanceMin,
              e.attendance_max AS attendanceMax,
              e.accessibility_needs AS accessibilityNeeds,
              e.parking_needs AS parkingNeeds, e.security_needs AS securityNeeds,
              f.fitness_categories_json AS fitnessCategories,
              f.fitness_coaches_json AS fitnessCoaches,
              COALESCE((SELECT AVG(r.rating) FROM venue_reviews r
                        WHERE r.business_id = b.id), 0) AS averageRating,
              (SELECT COUNT(*) FROM venue_reviews r
               WHERE r.business_id = b.id) AS reviewCount,
              (SELECT COUNT(DISTINCT r.customer_id) FROM venue_reviews r
               WHERE r.business_id = b.id) AS ratingUserCount,
              EXISTS (
                SELECT 1 FROM merchant_news n
                WHERE n.business_id = b.id
                  AND n.status = 'published'
                  AND NULLIF(TRIM(n.title), '') IS NOT NULL
                  AND NULLIF(TRIM(n.body), '') IS NOT NULL
                  AND COALESCE(NULLIF(TRIM(n.image_url), ''),
                               NULLIF(TRIM(b.image_url), '')) IS NOT NULL
              ) AS hasPublishedNewsCard,
              b.amenities_json AS tags, b.details, b.image_url AS imageUrl,
              b.image_urls AS imageUrls,
              b.created_at AS createdAt
       FROM merchant_businesses b
       JOIN users u ON u.id = b.merchant_id
       LEFT JOIN event_business_details e ON e.business_id = b.id
       LEFT JOIN fitness_business_details f ON f.business_id = b.id
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
        'fitnessCategories',
        'fitnessCoaches',
      ]) {
        business[field] = parseJsonArray(business[field], field);
      }
      business.sportsSlots = parseJsonArray(business.sportsSlots, 'sportsSlots');
      business.imageUrls = parseJsonArray(business.imageUrls, 'imageUrls');
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
    const businesses = await readCache.getOrLoad(
      customerBusinessesCacheKey,
      customerBusinessesCacheTtlMs,
      async () => {
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
              b.slot_count AS slotCount,
              b.sports_slots_json AS sportsSlots,
              b.visit_url AS visitUrl,
              b.opening_hours AS hours, b.availability, b.enabled,
              b.rate_periods AS ratePeriods,
              e.event_types_json AS eventTypes, e.attendance_min AS attendanceMin,
              e.attendance_max AS attendanceMax,
              e.accessibility_needs AS accessibilityNeeds,
              e.parking_needs AS parkingNeeds, e.security_needs AS securityNeeds,
              f.fitness_categories_json AS fitnessCategories,
              f.fitness_coaches_json AS fitnessCoaches,
              COALESCE((SELECT AVG(r.rating) FROM venue_reviews r
                        WHERE r.business_id = b.id), 0) AS averageRating,
              (SELECT COUNT(*) FROM venue_reviews r
               WHERE r.business_id = b.id) AS reviewCount,
              (SELECT COUNT(DISTINCT r.customer_id) FROM venue_reviews r
               WHERE r.business_id = b.id) AS ratingUserCount,
              (SELECT COUNT(*) FROM venue_hearts h
               WHERE h.business_id = b.id) AS heartCount,
              b.amenities_json AS tags, b.details, b.image_url AS imageUrl,
              b.image_urls AS imageUrls,
              b.created_at AS createdAt
       FROM merchant_businesses b
       JOIN users u ON u.id = b.merchant_id
       LEFT JOIN event_business_details e ON e.business_id = b.id
       LEFT JOIN fitness_business_details f ON f.business_id = b.id
       WHERE (b.enabled = 1 OR b.business_type = 'Event')
         AND u.status = 'active'
         AND (
           b.business_type = 'Event'
           OR EXISTS (
           SELECT 1 FROM merchant_news n
           WHERE n.business_id = b.id
             AND n.status = 'published'
             AND NULLIF(TRIM(n.title), '') IS NOT NULL
             AND NULLIF(TRIM(n.body), '') IS NOT NULL
             AND COALESCE(NULLIF(TRIM(n.image_url), ''),
                          NULLIF(TRIM(b.image_url), '')) IS NOT NULL
           )
         )
       ORDER BY b.created_at DESC`,
        );
        for (const business of businesses) {
          for (const field of [
            'eventTypes',
            'accessibilityNeeds',
            'parkingNeeds',
            'securityNeeds',
            'fitnessCategories',
            'fitnessCoaches',
          ]) {
            business[field] = parseJsonArray(business[field], field);
          }
          for (const field of ['ratePeriods', 'tags']) {
            business[field] = parseJsonArray(business[field], field);
          }
          business.sportsSlots = parseJsonArray(
            business.sportsSlots,
            'sportsSlots',
          );
          business.imageUrls = parseJsonArray(business.imageUrls, 'imageUrls');
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
          if (business.imageUrls.length > 0) {
            business.imageUrl = business.imageUrls[0];
          }
        }
        return businesses;
      },
    );
    return res.json({ businesses });
  } catch (error) {
    return next(error);
  }
});

app.delete('/api/merchant/businesses/:id', requireAuth, requireRole('merchant'), async (req, res, next) => {
  const id = positiveIntegerId(req.params.id);
  if (id === null) {
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
    invalidateCustomerBusinesses();
    await recordUserActivity(
      pool,
      req.auth.sub,
      'business_deleted',
      'Business deleted',
      `Business #${id} was deleted.`,
      { details: { businessId: id } },
    );
    return res.json({ message: 'Business deleted.' });
  } catch (error) {
    return next(error);
  }
});

app.put('/api/merchant/businesses/:id/status', requireAuth, requireRole('merchant'), async (req, res, next) => {
  const id = positiveIntegerId(req.params.id);
  if (id === null || typeof req.body.enabled !== 'boolean') {
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
    invalidateCustomerBusinesses();
    await recordUserActivity(
      pool,
      req.auth.sub,
      req.body.enabled ? 'business_enabled' : 'business_disabled',
      req.body.enabled ? 'Business enabled' : 'Business disabled',
      `Business #${id} was ${req.body.enabled ? 'enabled' : 'disabled'}.`,
      { details: { businessId: id, enabled: req.body.enabled } },
    );
    return res.json({ message: req.body.enabled ? 'Business enabled.' : 'Business disabled.' });
  } catch (error) {
    return next(error);
  }
});

app.put('/api/merchant/businesses/:id/images', requireAuth, requireRole('merchant'), async (req, res, next) => {
  const id = positiveIntegerId(req.params.id);
  const imageUrls = req.body.imageUrls;
  if (
    id === null ||
    !Array.isArray(imageUrls) ||
    imageUrls.length === 0 ||
    imageUrls.length > 20 ||
    imageUrls.some((image) =>
      typeof image !== 'string' ||
      image.trim().length === 0 ||
      image.length > 10 * 1024 * 1024
    )
  ) {
    return res.status(400).json({ error: 'A valid business id and venue images are required.' });
  }
  const normalizedImages = imageUrls.map((image) => image.trim());
  try {
    const [result] = await pool.execute(
      `UPDATE merchant_businesses
       SET image_url = ?, image_urls = ?
       WHERE id = ? AND merchant_id = ?`,
      [
        normalizedImages[0],
        JSON.stringify(normalizedImages),
        id,
        req.auth.sub,
      ],
    );
    if (!result.affectedRows) {
      return res.status(404).json({ error: 'Business not found.' });
    }
    invalidateCustomerBusinesses();
    await recordUserActivity(
      pool,
      req.auth.sub,
      'business_image_updated',
      'Business image updated',
      `Images for business #${id} were updated.`,
      { details: { businessId: id } },
    );
    return res.json({ message: 'Business images updated.' });
  } catch (error) {
    return next(error);
  }
});

app.put('/api/merchant/businesses/:id', requireAuth, requireRole('merchant'), async (req, res, next) => {
  const id = positiveIntegerId(req.params.id);
  if (id === null) {
    return res.status(400).json({ error: 'Invalid business id.' });
  }
  const payloadErrors = validateBusinessPayload(req.body);
  if (payloadErrors.length > 0) {
    return res.status(400).json({
      error: `Please correct the business fields: ${payloadErrors.join(', ')}.`,
      validationErrors: payloadErrors,
    });
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
  const slotCount = Number(req.body.slotCount ?? 1);
  const sportsSlots = req.body.sportsSlots === undefined
    ? null : normalizeSportsSlots(req.body.sportsSlots, slotCount);
  const ratePeriods = Array.isArray(req.body.ratePeriods)
    ? req.body.ratePeriods.slice(0, 20)
    : [];
  const fitnessDetails = fitnessDetailsFromBody(req.body);
  const tags = Array.isArray(req.body.tags)
    ? req.body.tags.filter((item) => typeof item === 'string').slice(0, 20)
    : [];
  const imageUrls = Array.isArray(req.body.imageUrls)
    ? req.body.imageUrls
        .filter((item) => typeof item === 'string')
        .map((item) => item.trim())
        .filter(Boolean)
        .slice(0, 20)
    : [];
  const imageUrl = text(req.body.imageUrl, 10 * 1024 * 1024) || imageUrls[0] || '';
  const hasVenueImage = Boolean(imageUrl.trim()) ||
    imageUrls.some((item) => item.trim().length > 0);
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
      (businessType === 'Sports' && includedPlayers > 0)) &&
    (businessType !== 'Sports' || req.body.sportsSlots === undefined ||
      sportsSlots !== null) &&
    hasVenueImage &&
    fitnessDetails.valid;
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
           additional_player_fee = ?, slot_count = ?, sports_slots_json = ?,
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
        businessType === 'Sports' ? slotCount : 1,
        businessType === 'Sports' && sportsSlots
          ? JSON.stringify(sportsSlots) : null,
        coordinates.provided, coordinates.latitude,
        coordinates.provided, coordinates.longitude,
        id, req.auth.sub,
      ],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Business not found.' });
    }
    invalidateCustomerBusinesses();
    await saveEventDetails(pool, id, req.body);
    await saveFitnessDetails(pool, id, req.body, fitnessDetails);
    await recordUserActivity(
      pool,
      req.auth.sub,
      'business_updated',
      'Business updated',
      `${businessType} business "${name}" was updated.`,
      {
        venueId: id,
        venueName: name,
        sportType: category,
        details: { businessId: id, businessType },
      },
    );
    return res.json({ message: 'Business updated.' });
  } catch (error) {
    return next(error);
  }
});

app.post('/api/merchant/businesses', requireAuth, requireRole('merchant'), async (req, res, next) => {
  const payloadErrors = validateBusinessPayload(req.body);
  if (payloadErrors.length > 0) {
    return res.status(400).json({
      error: `Please correct the business fields: ${payloadErrors.join(', ')}.`,
      validationErrors: payloadErrors,
    });
  }
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
  const slotCount = Number(req.body.slotCount ?? 1);
  const sportsSlots = req.body.sportsSlots === undefined
    ? null : normalizeSportsSlots(req.body.sportsSlots, slotCount);
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
  const fitnessDetails = fitnessDetailsFromBody(req.body);
  const amenities = Array.isArray(req.body.tags)
    ? req.body.tags.filter((item) => typeof item === 'string').slice(0, 20)
    : [];
  const details = text(req.body.details, 1000);
  const imageUrl = text(req.body.imageUrl, 10 * 1024 * 1024);
  const imageUrls = Array.isArray(req.body.imageUrls)
    ? req.body.imageUrls
        .filter((item) => typeof item === 'string')
        .map((item) => item.trim())
        .filter(Boolean)
        .slice(0, 20)
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
  if (!primaryImageUrl.trim()) validationErrors.push('venue image');
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
  if (businessType === 'Sports' && req.body.sportsSlots !== undefined &&
      sportsSlots === null) {
    validationErrors.push('sport slot and pricing settings');
  }
  if (!fitnessDetails.valid) {
    validationErrors.push('fitness category pricing and coach settings');
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
        included_players, additional_player_fee, slot_count, sports_slots_json,
        latitude, longitude)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)` ,
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
        businessType === 'Sports' ? slotCount : 1,
        businessType === 'Sports' && sportsSlots
          ? JSON.stringify(sportsSlots) : null,
        coordinates.latitude,
        coordinates.longitude,
      ],
    );
    invalidateCustomerBusinesses();
    await saveEventDetails(pool, result.insertId, req.body);
    await saveFitnessDetails(pool, result.insertId, req.body, fitnessDetails);
    await recordUserActivity(
      pool,
      req.auth.sub,
      'business_created',
      'Business created',
      `${businessType} business "${name}" was created.`,
      {
        venueId: result.insertId,
        venueName: name,
        sportType: category,
        details: { businessId: result.insertId, businessType },
      },
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
      !itemKey || !title || itemKey.length > 255 || title.length > 255 ||
      (req.body.subtitle != null &&
        (typeof req.body.subtitle !== 'string' ||
          req.body.subtitle.length > 500)) ||
      (req.body.imageUrl != null &&
        (typeof req.body.imageUrl !== 'string' ||
          req.body.imageUrl.length > 10 * 1024 * 1024))) {
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
    await recordUserActivity(
      pool,
      req.auth.sub,
      'item_saved',
      'Saved an item',
      `Saved ${itemType} item: ${title.slice(0, 200)}.`,
    );
    return res.status(201).json({ message: 'Item saved.' });
  } catch (error) {
    return next(error);
  }
});

app.delete('/api/saved-items/:itemType/:itemKey', requireAuth, async (req, res, next) => {
  if (!['sports', 'event', 'fitness'].includes(req.params.itemType) ||
      !req.params.itemKey || req.params.itemKey.length > 255) {
    return res.status(400).json({ error: 'Invalid saved item type.' });
  }
  try {
    const [result] = await pool.execute(
      'DELETE FROM saved_items WHERE user_id = ? AND item_type = ? AND item_key = ?',
      [req.auth.sub, req.params.itemType, req.params.itemKey],
    );
    if (result.affectedRows > 0) {
      await recordUserActivity(
        pool,
        req.auth.sub,
        'item_removed',
        'Removed a saved item',
        `Removed a saved ${req.params.itemType} item.`,
      );
    }
    return res.json({ message: 'Item removed.' });
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

function validCalendarDate(value) {
  if (!validDate(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(parsed.getTime()) &&
    parsed.toISOString().slice(0, 10) === value;
}

function dateOnly(value) {
  return value instanceof Date
    ? value.toISOString().slice(0, 10)
    : String(value).slice(0, 10);
}

function fitnessPlanEndDate(startDate, planType) {
  const start = new Date(`${dateOnly(startDate)}T00:00:00.000Z`);
  const months = planType === 'monthly' ? 1 : planType === 'yearly' ? 12 : 0;
  if (months === 0) return start.toISOString().slice(0, 10);
  const targetMonth = new Date(Date.UTC(
    start.getUTCFullYear(),
    start.getUTCMonth() + months,
    1,
  ));
  const lastDay = new Date(Date.UTC(
    targetMonth.getUTCFullYear(),
    targetMonth.getUTCMonth() + 1,
    0,
  )).getUTCDate();
  return new Date(Date.UTC(
    targetMonth.getUTCFullYear(),
    targetMonth.getUTCMonth(),
    Math.min(start.getUTCDate(), lastDay),
  )).toISOString().slice(0, 10);
}

function fitnessAvailabilityIncludesDate(availability, date) {
  const normalized = String(availability ?? '').trim().toLowerCase();
  if (!normalized || normalized === 'any') return true;
  const availableDays = new Set(
    normalized.split(/[,;]/).map((day) => day.trim()).filter(Boolean),
  );
  if (availableDays.size === 0) return true;
  const weekdayNames = [
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
  ];
  const weekday = new Date(`${date}T00:00:00.000Z`).getUTCDay();
  const name = weekdayNames[weekday];
  const abbreviation = name.slice(0, 3);
  return availableDays.has(name) || availableDays.has(abbreviation);
}

function validTime(value) {
  return typeof value === 'string' && /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(value);
}

function normalizeSportsSlots(value, totalSlots) {
  if (!Array.isArray(value) || value.length < 1 || value.length > 20 ||
      !Number.isInteger(totalSlots) || totalSlots < 1 || totalSlots > 100) {
    return null;
  }
  const names = new Set();
  const normalized = [];
  for (const item of value) {
    if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
    const sportType = typeof item.sportType === 'string'
      ? item.sportType.trim() : '';
    if (
      typeof item.sportType !== 'string' ||
      item.sportType.length > 100 ||
      (item.fullStudio !== undefined &&
        typeof item.fullStudio !== 'boolean') ||
      !isNumericInput(item.pricePerHour) ||
      !isNumericInput(item.slotCount) ||
      (item.includedPlayers !== undefined &&
        !isNumericInput(item.includedPlayers)) ||
      (item.additionalPlayerFee !== undefined &&
        !isNumericInput(item.additionalPlayerFee))
    ) {
      return null;
    }
    const pricePerHour = Number(item.pricePerHour);
    const fullStudio = item.fullStudio === true;
    const slotCount = Number(item.slotCount);
    const includedPlayers = Number(item.includedPlayers ?? 0);
    const additionalPlayerFee = Number(item.additionalPlayerFee ?? 0);
    const key = sportType.toLowerCase();
    if (!sportType || names.has(key) || !Number.isFinite(pricePerHour) ||
        pricePerHour <= 0 || !Number.isInteger(slotCount) ||
        slotCount < 1 || slotCount > totalSlots ||
        (fullStudio && slotCount !== totalSlots) ||
        !Number.isInteger(includedPlayers) || includedPlayers < 0 ||
        includedPlayers > 1000 || !Number.isFinite(additionalPlayerFee) ||
        additionalPlayerFee < 0 || additionalPlayerFee > 99999999.99 ||
        (additionalPlayerFee > 0 && includedPlayers < 1)) {
      return null;
    }
    names.add(key);
    normalized.push({
      sportType,
      pricePerHour,
      fullStudio,
      slotCount,
      includedPlayers,
      additionalPlayerFee,
    });
  }
  return normalized;
}

function configuredSportsSlots(venue) {
  let sportsSlots = venue.sports_slots_json ?? venue.sportsSlots;
  if (typeof sportsSlots === 'string') {
    try {
      sportsSlots = JSON.parse(sportsSlots);
    } catch {
      sportsSlots = null;
    }
  }
  if (Array.isArray(sportsSlots) && sportsSlots.length > 0) {
    return sportsSlots;
  }
  return [{
    sportType: venue.category || 'Sports',
    pricePerHour: Number(venue.price_per_hour ?? venue.pricePerHour),
    fullStudio: true,
    slotCount: 1,
  }];
}

app.get('/api/bookings/availability', requireAuth, requireRole('customer'), async (req, res, next) => {
  const venueId = Number(req.query.venueId);
  const bookingDate = req.query.date;
  if (!isNumericInput(req.query.venueId) ||
      !Number.isSafeInteger(venueId) || venueId <= 0 || !validDate(bookingDate)) {
    return res.status(400).json({ error: 'venueId and a valid date are required.' });
  }
  try {
    const [bookings] = await pool.execute(
      `SELECT start_time AS startTime, duration_hours AS durationHours,
              sport_type AS sportType, slot_number AS slotNumber,
              occupies_full_studio AS occupiesFullStudio
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

app.get(
  '/api/payments/paymongo/config',
  requireAuth,
  requireRole('customer'),
  (_req, res) => {
    return res.json({ onlinePaymentsEnabled: paymongoIsConfigured() });
  },
);

app.post('/api/payments/paymongo/checkout', requireAuth, requireRole('customer'), async (req, res, next) => {
  const bookingId = Number(req.body.bookingId);
  const paymentMethod = typeof req.body.paymentMethod === 'string'
    ? req.body.paymentMethod.trim() : '';
  const paymentType = typeof req.body.paymentType === 'string'
    ? req.body.paymentType.trim() : 'full';
  if (!isNumericInput(req.body.bookingId) ||
      !Number.isSafeInteger(bookingId) || bookingId <= 0 ||
      !['gcash', 'paymaya'].includes(paymentMethod) ||
      paymentType !== 'full') {
    return res.status(400).json({
      error: 'Choose a valid GCash or PayMaya payment before starting checkout.',
    });
  }
  if (!paymongoIsConfigured()) {
    return res.status(503).json({
      error: 'Online payment is not fully configured. Ask the app administrator to configure PayMongo checkout and its payment webhook.',
    });
  }
  try {
    const [rows] = await pool.execute(
      `SELECT id, total_amount AS totalAmount,
              downpayment_amount AS downpaymentAmount,
              payment_method AS paymentMethod,
              payment_status AS paymentStatus, paid_amount AS paidAmount, status
         FROM bookings
        WHERE id = ? AND customer_id = ?
        LIMIT 1`,
      [bookingId, req.auth.sub],
    );
    const booking = rows[0];
    if (!booking) return res.status(404).json({ error: 'Booking not found.' });
    if (
      booking.status !== 'pending' ||
      booking.paymentMethod !== 'online'
    ) {
      return res.status(409).json({
        error: 'Payment type does not match the pending booking.',
      });
    }
    if (booking.paymentStatus === 'paid') {
      return res.status(409).json({ error: 'This booking amount has already been paid.' });
    }
    const checkoutAmount = Number(booking.totalAmount);
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
              amount: Math.round(checkoutAmount * 100),
              name: `TinkerPro booking #${booking.id}`,
              quantity: 1,
            }],
            payment_method_types: [paymentMethod],
            success_url: process.env.PAYMONGO_SUCCESS_URL,
            cancel_url: process.env.PAYMONGO_CANCEL_URL,
            description: `TinkerPro booking #${booking.id}`,
            reference_number: bookingTransactionId(booking.id),
            metadata: {
              booking_id: String(booking.id),
              transaction_id: bookingTransactionId(booking.id),
              payment_type: 'full',
            },
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
    const checkoutSessionId = payload?.data?.id;
    const checkoutUrl = payload?.data?.attributes?.checkout_url;
    if (
      typeof checkoutSessionId !== 'string' ||
      checkoutSessionId.trim().length === 0 ||
      typeof checkoutUrl !== 'string' ||
      checkoutUrl.trim().length === 0
    ) {
      return res.status(502).json({ error: 'PayMongo returned no checkout URL.' });
    }
    await pool.execute(
      `UPDATE bookings
       SET payment_checkout_session_id = ?
       WHERE id = ? AND customer_id = ? AND status = 'pending'
         AND payment_status <> 'paid'`,
      [checkoutSessionId, booking.id, req.auth.sub],
    );
    return res.json({ checkoutUrl });
  } catch (error) {
    return next(error);
  }
});

app.post('/api/payments/paymongo/webhook', async (req, res, next) => {
  const webhookSecret = process.env.PAYMONGO_WEBHOOK_SECRET;
  if (!webhookSecret) {
    return res.status(503).json({ error: 'Payment webhook is not configured.' });
  }
  if (
    !hasValidPaymongoSignature(
      req.rawBody,
      req.get('paymongo-signature'),
      req.body?.data?.livemode === true,
      webhookSecret,
    )
  ) {
    return res.status(401).json({ error: 'Invalid payment webhook signature.' });
  }

  const event = req.body?.data;
  if (event?.type !== 'checkout_session.payment.paid') {
    return res.json({ received: true, ignored: true });
  }
  const checkoutSession = event.data;
  const checkoutSessionId = checkoutSession?.id;
  const attributes = checkoutSession?.attributes;
  const payments = Array.isArray(attributes?.payments)
    ? attributes.payments
    : [];
  const paidPayment = payments.find(
    (payment) => payment?.attributes?.status === 'paid',
  );
  if (
    typeof checkoutSessionId !== 'string' ||
    !paidPayment ||
    !Number.isSafeInteger(Number(paidPayment.attributes.amount)) ||
    String(paidPayment.attributes.currency).toUpperCase() !== 'PHP'
  ) {
    return res.status(400).json({ error: 'Paid checkout details are invalid.' });
  }

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [rows] = await connection.execute(
      `SELECT b.id, b.customer_id AS customerId, b.venue_id AS venueId,
              b.booking_date AS bookingDate, b.start_time AS startTime,
              b.duration_hours AS durationHours, b.players,
              b.sport_type AS sportType, b.slot_number AS slotNumber,
              b.event_type AS eventType,
              b.fitness_plan_type AS fitnessPlanType,
              b.fitness_category AS fitnessCategory,
              b.fitness_coach_name AS fitnessCoachName,
              b.fitness_coach_duration_months AS fitnessCoachDurationMonths,
              b.fitness_plan_price AS fitnessPlanPrice,
              b.fitness_coach_price AS fitnessCoachPrice,
              b.occupies_full_studio AS occupiesFullStudio,
              b.total_amount AS totalAmount, b.payment_method AS paymentMethod,
              b.downpayment_amount AS downpaymentAmount,
              b.paid_amount AS paidAmount,
              b.payment_status AS paymentStatus,
              b.payment_refund_status AS paymentRefundStatus,
              b.payment_refund_id AS paymentRefundId, b.status,
              v.business_type AS businessType,
              v.name AS venueName,
              COALESCE(b.sport_type, v.category) AS sportType,
              v.merchant_id AS merchantId
       FROM bookings b
       JOIN merchant_businesses v ON v.id = b.venue_id
       WHERE b.payment_checkout_session_id = ? LIMIT 1 FOR UPDATE`,
      [checkoutSessionId],
    );
    const booking = rows[0];
    if (!booking) {
      await connection.rollback();
      return res.status(404).json({ error: 'Checkout session is not linked to a booking.' });
    }
    const expectedBookingId = String(booking.id);
    const transactionId = bookingTransactionId(booking.id);
    const metadataBookingId = attributes?.metadata?.booking_id;
    const referenceNumber = attributes?.reference_number;
    const metadataTransactionId = attributes?.metadata?.transaction_id;
    if (
      (metadataBookingId != null &&
        String(metadataBookingId) !== expectedBookingId) ||
      (metadataTransactionId != null &&
        String(metadataTransactionId) !== transactionId) ||
      (referenceNumber != null &&
        referenceNumber !== transactionId &&
        referenceNumber !== `BOOKING-${expectedBookingId}`)
    ) {
      await connection.rollback();
      return res.status(400).json({ error: 'Checkout does not match its booking.' });
    }
    const expectedPaymentAmount = Number(booking.totalAmount);
    if (
      booking.paymentMethod !== 'online' ||
      !['pending', 'cancelled'].includes(booking.status) ||
      attributes?.metadata?.payment_type !== 'full' ||
      Number(paidPayment.attributes.amount) !== Math.round(expectedPaymentAmount * 100)
    ) {
      await connection.rollback();
      return res.status(409).json({ error: 'Paid checkout does not match the booking.' });
    }
    if (booking.paymentStatus === 'paid') {
      await connection.commit();
      const paymentRefundStatus =
        booking.status === 'cancelled' &&
        booking.paymentRefundStatus === 'pending' &&
        !booking.paymentRefundId
          ? await requestPaymongoBookingRefund(booking)
          : booking.paymentRefundStatus;
      return res.json({
        received: true,
        duplicate: true,
        bookingId: booking.id,
        transactionId,
        paymentRefundStatus,
      });
    }

    const nextPaymentStatus = 'paid';
    const bookingWasCancelled = booking.status === 'cancelled';
    const paymentReference = paidPayment.id ?? attributes?.payment_intent?.id ?? checkoutSessionId;
    await connection.execute(
      `UPDATE bookings
       SET payment_status = ?, paid_amount = ?, payment_reference = ?,
           paid_at = CURRENT_TIMESTAMP
       WHERE id = ? AND payment_status <> 'paid'`,
      [nextPaymentStatus, expectedPaymentAmount, paymentReference, booking.id],
    );
    const [conversations] = await connection.execute(
      'SELECT id FROM conversations WHERE type = ? AND title = ? LIMIT 1',
      ['direct', `Booking ${booking.id}`],
    );
    let conversationId = conversations[0]?.id;
    if (!conversationId) {
      const [conversation] = await connection.execute(
        'INSERT INTO conversations (type, title, created_by) VALUES (?, ?, ?)',
        ['direct', `Booking ${booking.id}`, booking.customerId],
      );
      conversationId = conversation.insertId;
      await connection.execute(
        'INSERT INTO conversation_members (conversation_id, user_id) VALUES (?, ?), (?, ?)',
        [
          conversationId,
          booking.customerId,
          conversationId,
          booking.merchantId,
        ],
      );
    }
    const ticketDetails = {
      type: 'booking_payment_ticket',
      bookingId: booking.id,
      transactionId,
      businessType: booking.businessType,
      eventType: booking.eventType,
      status: 'payment_received',
      approvalStatus: bookingWasCancelled ? 'cancelled' : 'pending',
      venueName: booking.venueName,
      sportType: booking.sportType,
      fitnessPlanType: booking.fitnessPlanType,
      fitnessCategory: booking.fitnessCategory,
      fitnessCoachName: booking.fitnessCoachName,
      fitnessCoachDurationMonths: booking.fitnessCoachDurationMonths,
      fitnessPlanPrice: booking.fitnessPlanPrice,
      fitnessCoachPrice: booking.fitnessCoachPrice,
      slotNumber: booking.slotNumber,
      fullStudio: Number(booking.occupiesFullStudio) === 1,
      bookingDate: booking.bookingDate,
      startTime: booking.startTime,
      durationHours: booking.durationHours,
      players: booking.players,
      amount: expectedPaymentAmount,
      totalAmount: Number(booking.totalAmount),
      downpaymentAmount: Number(booking.downpaymentAmount),
      paidAmount: expectedPaymentAmount,
      paymentStatus: nextPaymentStatus,
      remainingBalance: Math.max(0, Number(booking.totalAmount) - expectedPaymentAmount),
      paymentReference,
      checkoutSessionId,
    };
    await connection.execute(
      `INSERT INTO messages (conversation_id, sender_id, body, attachment_json)
       VALUES (?, ?, ?, ?)`,
      [
        conversationId,
        booking.merchantId,
        bookingWasCancelled
          ? `Payment received for cancelled booking #${booking.id}. The applicable cancellation refund is being processed separately.`
          : `Payment received for booking #${booking.id}. The venue is reviewing your booking.`,
        JSON.stringify(ticketDetails),
      ],
    );
    await recordUserActivity(
      connection,
      booking.customerId,
      'booking_paid',
      'Payment received',
      bookingWasCancelled
        ? `Payment received for cancelled booking #${booking.id} at ${booking.venueName}. The applicable cancellation refund is being processed separately.`
        : `Payment received for booking #${booking.id} at ${booking.venueName}.`,
      {
        venueId: booking.venueId,
        venueName: booking.venueName,
        sportType: booking.sportType,
        details: {
          bookingId: booking.id,
          transactionId,
          bookingDate: booking.bookingDate,
          startTime: booking.startTime,
          durationHours: booking.durationHours,
          players: booking.players,
          amount: booking.totalAmount,
          paymentReference,
        },
      },
    );
    await connection.commit();
    const paymentRefundStatus =
      bookingWasCancelled &&
      booking.paymentRefundStatus === 'pending' &&
      !booking.paymentRefundId
        ? await requestPaymongoBookingRefund({
            ...booking,
            paymentReference,
            paidAmount: expectedPaymentAmount,
          })
        : booking.paymentRefundStatus;
    return res.json({
      received: true,
      bookingId: booking.id,
      transactionId,
      paymentRefundStatus,
    });
  } catch (error) {
    if (connection) await connection.rollback();
    return next(error);
  } finally {
    connection?.release();
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
  const sportType = typeof req.body.sportType === 'string'
    ? req.body.sportType.trim().slice(0, 100) : '';
  const fitnessPlanType = typeof req.body.fitnessPlanType === 'string'
    ? req.body.fitnessPlanType.trim().toLowerCase() : '';
  const fitnessCoachName = typeof req.body.fitnessCoachName === 'string'
    ? req.body.fitnessCoachName.trim().slice(0, 100) : '';
  const fitnessCoachDurationMonths =
    req.body.fitnessCoachDurationMonths === undefined
      ? fitnessCoachName
        ? fitnessPlanType === 'yearly' ? 12 : 1
        : 0
      : Number(req.body.fitnessCoachDurationMonths);
  const requestedEventType = typeof req.body.eventType === 'string'
    ? req.body.eventType.trim().slice(0, 100) : '';
  const requestedSlot = Number(req.body.slotNumber);
  const allowedPaymentMethods = new Set(['online', 'cash_on_arrival']);
  const optionalTextFields = [
    ['sportType', 100],
    ['fitnessPlanType', 50],
    ['fitnessCoachName', 100],
    ['eventType', 100],
  ];
  const invalidOptionalText = optionalTextFields.some(([field, maxLength]) =>
    req.body[field] !== undefined &&
    (typeof req.body[field] !== 'string' ||
      req.body[field].length > maxLength),
  );
  if (!isNumericInput(req.body.venueId ?? req.body.businessId) ||
      !isNumericInput(req.body.durationHours ?? req.body.duration) ||
      !isNumericInput(req.body.players) ||
      (req.body.slotNumber !== undefined &&
        !isNumericInput(req.body.slotNumber)) ||
        (req.body.fitnessCoachDurationMonths !== undefined &&
          (!isNumericInput(req.body.fitnessCoachDurationMonths) ||
            !Number.isSafeInteger(fitnessCoachDurationMonths) ||
            fitnessCoachDurationMonths < 0 ||
            fitnessCoachDurationMonths > 4294967295)) ||
        !Number.isSafeInteger(venueId) || venueId <= 0 || !validDate(bookingDate) ||
      !validTime(startTime) || !Number.isFinite(durationHours) ||
      durationHours <= 0 || durationHours > 24 || !Number.isSafeInteger(players) ||
      players <= 0 || players > 1000 || !allowedPaymentMethods.has(paymentMethod) ||
      typeof req.body.paymentMethod !== 'string' ||
      req.body.paymentMethod.length > 50 || invalidOptionalText) {
    return res.status(400).json({
      error: 'Choose Online payment or Cash on Arrival (COA).',
    });
  }
  const idempotencyKey = req.get('Idempotency-Key')?.trim() ?? '';
  if (!/^[A-Za-z0-9._:-]{16,100}$/.test(idempotencyKey)) {
    return res.status(400).json({
      error: 'A valid Idempotency-Key header is required for booking requests.',
    });
  }
  const idempotencyRequestHash = crypto.createHash('sha256')
    .update(JSON.stringify({
      venueId,
      bookingDate,
      startTime,
      durationHours,
      players,
      paymentMethod,
      sportType,
      slotNumber: Number.isFinite(requestedSlot) ? requestedSlot : null,
      fitnessPlanType,
      fitnessCoachName,
      fitnessCoachDurationMonths,
      eventType: requestedEventType,
    }))
    .digest('hex');

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [priorRequests] = await connection.execute(
      `SELECT idempotency_request_hash AS requestHash,
              idempotency_response_json AS responseJson,
              idempotency_response_status AS responseStatus
       FROM bookings
       WHERE customer_id = ? AND idempotency_key = ?
       LIMIT 1 FOR UPDATE`,
      [req.auth.sub, idempotencyKey],
    );
    if (priorRequests.length > 0) {
      await connection.rollback();
      return sendBookingIdempotencyReplay(
        res,
        priorRequests[0],
        idempotencyRequestHash,
      );
    }
    const [venues] = await connection.execute(
      `SELECT b.id, b.merchant_id, b.name, b.category, b.business_type AS businessType,
              b.price_per_hour, b.event_fee AS eventFee,
              b.slot_count AS slotCount, b.sports_slots_json AS sportsSlots,
              b.included_players, b.additional_player_fee, b.enabled,
              u.status AS merchant_status
       FROM merchant_businesses b JOIN users u ON u.id = b.merchant_id
       WHERE b.id = ? FOR UPDATE`,
      [venueId],
    );
    const venue = venues[0];
    if (!venue || !venue.enabled || venue.merchant_status !== 'active') {
      await connection.rollback();
      return res.status(404).json({ error: 'The venue is unavailable.' });
    }
    const businessType = String(venue.businessType).trim().toLowerCase();
    const isFitness = businessType === 'fitness & wellness';
    const isEvent = businessType === 'event';
    let selectedEventType = null;
    let sportConfig = null;
    let fitnessCategory = null;
    let fitnessCoach = null;
    let fitnessPlanPrice = 0;
    let fitnessCoachPrice = 0;
    let selectedSportType = sportType || venue.category || '';
    let fullStudio = true;
    let slotNumber = null;
    if (isFitness) {
      if (durationHours !== 1 || players !== 1) {
        await connection.rollback();
        return res.status(400).json({
          error: 'Fitness first visits must reserve one hour for one attendee.',
        });
      }
      if (!['session', 'monthly', 'yearly'].includes(fitnessPlanType)) {
        await connection.rollback();
        return res.status(400).json({ error: 'Choose a valid Fitness plan.' });
      }
      const [fitnessRows] = await connection.execute(
        `SELECT fitness_categories_json AS fitnessCategories,
                fitness_coaches_json AS fitnessCoaches
         FROM fitness_business_details WHERE business_id = ?`,
        [venueId],
      );
      const fitnessDetails = fitnessRows[0] || {};
      const fitnessCategories = parseJsonArray(
        fitnessDetails.fitnessCategories,
        'fitnessCategories',
      );
      const fitnessCoaches = parseJsonArray(
        fitnessDetails.fitnessCoaches,
        'fitnessCoaches',
      );
      fitnessCategory = fitnessCategories.find(
        (item) =>
          typeof item.category === 'string' &&
          item.category.toLowerCase() === sportType.toLowerCase(),
      );
      if (!fitnessCategory) {
        await connection.rollback();
        return res.status(400).json({ error: 'Choose a Fitness category offered by this venue.' });
      }
      const priceKey = `${fitnessPlanType}Price`;
      fitnessPlanPrice = Number(fitnessCategory[priceKey]);
      if (!Number.isFinite(fitnessPlanPrice) || fitnessPlanPrice <= 0) {
        await connection.rollback();
        return res.status(400).json({ error: 'The selected Fitness plan is not available.' });
      }
      if (fitnessPlanType === 'yearly') {
        if (fitnessCategory.yearlyDiscountType === 'freeMonths') {
          fitnessPlanPrice = Math.max(
            0,
            fitnessPlanPrice -
              Number(fitnessCategory.monthlyPrice) *
                Number(fitnessCategory.yearlyDiscountValue),
          );
        } else if (fitnessCategory.yearlyDiscountType === 'percentage') {
          fitnessPlanPrice *=
            1 - Number(fitnessCategory.yearlyDiscountValue) / 100;
        }
      }
      if (fitnessCoachName) {
        if (fitnessCoachDurationMonths < 1) {
          await connection.rollback();
          return res.status(400).json({
            error: 'Coach duration must be at least one month.',
          });
        }
        fitnessCoach = fitnessCoaches.find(
          (item) =>
            typeof item.name === 'string' &&
            item.name.toLowerCase() === fitnessCoachName.toLowerCase(),
        );
        if (!fitnessCoach) {
          await connection.rollback();
          return res.status(400).json({ error: 'Choose a coach offered by this venue.' });
        }
        fitnessCoachPrice =
          Number(fitnessCoach.monthlyPrice) * fitnessCoachDurationMonths;
        if (
          !Number.isFinite(fitnessCoachPrice) ||
          fitnessCoachPrice <= 0 ||
          fitnessCoachPrice > 99999999.99
        ) {
          await connection.rollback();
          return res.status(400).json({
            error: 'The selected coach duration price is unavailable.',
          });
        }
      }
      fitnessPlanPrice = Number(fitnessPlanPrice.toFixed(2));
      fitnessCoachPrice = Number(fitnessCoachPrice.toFixed(2));
      selectedSportType = fitnessCategory.category;
    } else if (isEvent) {
      const [eventRows] = await connection.execute(
        `SELECT event_types_json AS eventTypes,
                attendance_min AS attendanceMin,
                attendance_max AS attendanceMax
         FROM event_business_details WHERE business_id = ?`,
        [venueId],
      );
      const eventDetails = eventRows[0] || {};
      const eventTypes = parseJsonArray(eventDetails.eventTypes, 'eventTypes');
      const configuredEventType = eventTypes.find(
        (item) =>
          typeof item === 'string' &&
          item.toLowerCase() === requestedEventType.toLowerCase(),
      );
      if (!configuredEventType) {
        await connection.rollback();
        return res.status(400).json({
          error: 'Choose an event type offered by this venue.',
        });
      }
      const attendanceMin = Number(eventDetails.attendanceMin ?? 0);
      const attendanceMax = Number(eventDetails.attendanceMax ?? 0);
      if (
        (attendanceMin > 0 && players < attendanceMin) ||
        (attendanceMax > 0 && players > attendanceMax)
      ) {
        await connection.rollback();
        return res.status(400).json({
          error: 'Guest count is outside this venue’s event capacity.',
        });
      }
      selectedEventType = configuredEventType;
      selectedSportType = venue.category || 'Event';
      fullStudio = true;
    } else {
      const sportsSlots = configuredSportsSlots(venue);
      sportConfig = sportsSlots.find(
        (sport) =>
          sport.sportType.toLowerCase() === selectedSportType.toLowerCase(),
      );
      fullStudio = sportConfig?.fullStudio === true;
      slotNumber = fullStudio ? null : requestedSlot;
      if (!sportConfig || (!fullStudio &&
          (!Number.isInteger(slotNumber) || slotNumber < 1 ||
           slotNumber > Number(sportConfig.slotCount)))) {
        await connection.rollback();
        return res.status(400).json({ error: 'Choose a valid sport and available slot.' });
      }
    }
    const [overlaps] = await connection.execute(
      `SELECT slot_number AS slotNumber,
              occupies_full_studio AS occupiesFullStudio
       FROM bookings
       WHERE venue_id = ? AND booking_date = ?
         AND status IN ('pending', 'approved')
         AND start_time < ADDTIME(?, SEC_TO_TIME(? * 3600))
         AND ADDTIME(start_time, SEC_TO_TIME(duration_hours * 3600)) > ?`,
      [venueId, bookingDate, startTime, durationHours, startTime],
    );
    const hasConflict = overlaps.some((booking) =>
      isEvent ||
      fullStudio ||
      Number(booking.occupiesFullStudio) === 1 ||
      Number(booking.slotNumber) === slotNumber,
    );
    if (hasConflict) {
      await connection.rollback();
      return res.status(409).json({
        error: isFitness
          ? 'That Fitness session time is already booked.'
          : isEvent
          ? 'That event time is already booked at this venue.'
          : 'That sport slot is already booked for the selected time.',
      });
    }
    const pricePerHour = isFitness
      ? fitnessPlanPrice
      : isEvent
      ? Number(venue.eventFee)
      : Number(sportConfig.pricePerHour);
    if (isEvent && (!Number.isFinite(pricePerHour) || pricePerHour <= 0)) {
      await connection.rollback();
      return res.status(400).json({ error: 'The venue event fee is unavailable.' });
    }
    const includedPlayers = isFitness
      ? 0
      : isEvent
      ? players
      : Number(sportConfig.includedPlayers ?? venue.included_players);
    const additionalPlayerFee = isFitness
      ? 0
      : isEvent
      ? 0
      : Number(sportConfig.additionalPlayerFee ?? venue.additional_player_fee);
    const extraPlayers = Math.max(0, players - includedPlayers);
    const extraPlayerCharge = Number(
      (extraPlayers * additionalPlayerFee).toFixed(2),
    );
    const total = Number(
      (isFitness
        ? fitnessPlanPrice + fitnessCoachPrice
        : isEvent
        ? pricePerHour
        : pricePerHour * durationHours + extraPlayerCharge
      ).toFixed(2),
    );
    const downpayment = Number(
      (paymentMethod === 'cash_on_arrival' ? total * 0.50 : total).toFixed(2),
    );
    const bookingToken = createBookingToken();
    const [result] = await connection.execute(
      `INSERT INTO bookings
       (customer_id, venue_id, booking_date, start_time, duration_hours, players,
        payment_method, sport_type, slot_number, occupies_full_studio,
        price_per_hour, total_amount, downpayment_amount,
        extra_player_charge, event_type, fitness_plan_type, fitness_category,
        fitness_coach_name, fitness_plan_price, fitness_coach_price,
        fitness_coach_duration_months,
        booking_token_hash, payment_status, idempotency_key,
        idempotency_request_hash, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
      [req.auth.sub, venueId, bookingDate, startTime, durationHours, players,
       paymentMethod, selectedSportType, slotNumber, fullStudio ? 1 : 0,
       pricePerHour, total, downpayment, extraPlayerCharge,
       selectedEventType,
       isFitness ? fitnessPlanType : null,
       isFitness ? selectedSportType : null,
       isFitness ? fitnessCoach?.name ?? null : null,
       isFitness ? fitnessPlanPrice : null,
       isFitness ? fitnessCoachPrice : null,
       isFitness && fitnessCoach ? fitnessCoachDurationMonths : null,
       hashBookingToken(bookingToken),
       'unpaid',
       idempotencyKey, idempotencyRequestHash],
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
          transactionId: bookingTransactionId(result.insertId),
          businessType: venue.businessType,
          status: 'pending',
          extraPlayerCharge,
          sportType: selectedSportType,
          eventType: selectedEventType,
          bookingDate,
          startTime,
          durationHours,
          players,
          total,
          downpayment,
          paymentMethod,
          slotNumber,
          fullStudio,
          includedPlayers,
          additionalPlayerFee,
          ...(isFitness
            ? {
                fitnessPlanType,
                fitnessPlanPrice,
                fitnessCoachName: fitnessCoach?.name ?? null,
                fitnessCoachPrice,
                fitnessCoachDurationMonths: fitnessCoach
                  ? fitnessCoachDurationMonths
                  : null,
              }
            : {}),
          bookingToken,
        }),
      ],
    );
    await recordUserActivity(
      connection,
      req.auth.sub,
      'booking_requested',
      'Booking requested',
      `Booking #${result.insertId} was requested for ${bookingDate}.`,
      {
        venueId,
        venueName: venue.name,
        sportType: selectedSportType,
        details: {
          bookingId: result.insertId,
          bookingDate,
          startTime,
          durationHours,
          players,
          businessType: venue.businessType,
          eventType: selectedEventType,
          paymentMethod,
          total,
          downpayment,
          ...(isFitness
            ? {
                fitnessPlanType,
                fitnessPlanPrice,
                fitnessCoachName: fitnessCoach?.name ?? null,
                fitnessCoachPrice,
                fitnessCoachDurationMonths: fitnessCoach
                  ? fitnessCoachDurationMonths
                  : null,
              }
            : {}),
        },
      },
    );
    const responseBody = {
      booking: { id: result.insertId, transactionId: bookingTransactionId(result.insertId),
        businessType: venue.businessType, venueId, date: bookingDate, startTime,
        durationHours, players, sportType: selectedSportType,
        eventType: selectedEventType,
        slotNumber, fullStudio, paymentMethod, pricePerHour, total, downpayment,
        extraPlayers, extraPlayerCharge, includedPlayers,
        additionalPlayerFee, fitnessPlanType: isFitness ? fitnessPlanType : null,
        fitnessCategory: isFitness ? selectedSportType : null,
        fitnessCoachName: isFitness ? fitnessCoach?.name ?? null : null,
        fitnessCoachDurationMonths: isFitness && fitnessCoach
          ? fitnessCoachDurationMonths
          : null,
        fitnessPlanPrice: isFitness ? fitnessPlanPrice : null,
        fitnessCoachPrice: isFitness ? fitnessCoachPrice : null,
        status: 'pending', bookingToken },
    };
    const [idempotencyUpdate] = await connection.execute(
      `UPDATE bookings
       SET idempotency_response_json = ?, idempotency_response_status = 201
       WHERE id = ? AND customer_id = ?`,
      [JSON.stringify(responseBody), result.insertId, req.auth.sub],
    );
    if (idempotencyUpdate.affectedRows !== 1) {
      throw new Error('Could not persist the booking idempotency response.');
    }
    await connection.commit();
    return res.status(201).json(responseBody);
  } catch (error) {
    if (connection) await connection.rollback();
    if (
      error.code === 'ER_DUP_ENTRY' &&
      String(error.message ?? '').includes('uq_bookings_customer_idempotency')
    ) {
      const [priorRequests] = await pool.execute(
        `SELECT idempotency_request_hash AS requestHash,
                idempotency_response_json AS responseJson,
                idempotency_response_status AS responseStatus
         FROM bookings
         WHERE customer_id = ? AND idempotency_key = ?
         LIMIT 1`,
        [req.auth.sub, idempotencyKey],
      );
      if (priorRequests.length > 0) {
        return sendBookingIdempotencyReplay(
          res,
          priorRequests[0],
          idempotencyRequestHash,
        );
      }
    }
    return next(error);
  } finally {
    connection?.release();
  }
});

function sendBookingIdempotencyReplay(res, priorRequest, requestHash) {
  if (priorRequest.requestHash !== requestHash) {
    return res.status(409).json({
      error: 'This Idempotency-Key was already used for a different booking request.',
    });
  }
  let responseBody = priorRequest.responseJson;
  if (typeof responseBody === 'string') responseBody = JSON.parse(responseBody);
  if (!responseBody || typeof responseBody !== 'object') {
    throw new Error('Stored booking idempotency response is unavailable.');
  }
  return res.status(Number(priorRequest.responseStatus) || 201).json(responseBody);
}

app.get('/api/bookings', requireAuth, requireRole('customer'), async (req, res, next) => {
  try {
    const businessType = req.query.businessType;
    let businessTypeFilter = '';
    const params = [req.auth.sub];
    if (businessType !== undefined) {
      if (typeof businessType !== 'string') {
        return res.status(400).json({ error: 'Invalid business type filter.' });
      }
      const normalizedBusinessType = businessType.trim().toLowerCase();
      const businessTypeAliases = {
        sports: 'sports',
        fitness: 'fitness & wellness',
        'fitness & wellness': 'fitness & wellness',
        event: 'event',
      };
      const businessTypeValue = businessTypeAliases[normalizedBusinessType];
      if (!businessTypeValue) {
        return res.status(400).json({ error: 'Invalid business type filter.' });
      }
      businessTypeFilter = ' AND LOWER(v.business_type) = ?';
      params.push(businessTypeValue);
    }
    const [bookings] = await pool.execute(
      `SELECT b.id, b.venue_id AS venueId, v.name AS venueName, v.address,
              CONCAT_WS(' ', u.first_name, u.last_name) AS ownerName,
              v.business_type AS businessType, v.category, v.facility_type AS facilityType,
              v.opening_hours AS hours, v.availability, v.rate_periods AS ratePeriods,
              e.event_types_json AS eventTypes, e.attendance_min AS attendanceMin,
              e.attendance_max AS attendanceMax,
              e.accessibility_needs AS accessibilityNeeds,
              e.parking_needs AS parkingNeeds, e.security_needs AS securityNeeds,
              f.class_capacity AS classCapacity,
              f.session_duration_minutes AS sessionDurationMinutes,
              f.instructor_name AS instructorName,
              f.class_schedule AS classSchedule,
              v.details, v.visit_url AS visitUrl,
              v.price_per_hour AS venuePricePerHour, v.event_fee AS eventFee,
              v.amenities_json AS amenities,
              v.image_url AS imageUrl, v.image_urls AS imageUrls,
              b.booking_date AS date, b.start_time AS startTime,
              b.duration_hours AS durationHours, b.players, b.payment_method AS paymentMethod,
              b.sport_type AS sportType, b.slot_number AS slotNumber,
              b.event_type AS eventType,
              b.fitness_plan_type AS fitnessPlanType,
              b.fitness_category AS fitnessCategory,
              b.fitness_coach_name AS fitnessCoachName,
              b.fitness_coach_duration_months AS fitnessCoachDurationMonths,
              b.fitness_plan_price AS fitnessPlanPrice,
              b.fitness_coach_price AS fitnessCoachPrice,
              b.occupies_full_studio AS occupiesFullStudio,
              b.price_per_hour AS pricePerHour, b.total_amount AS total,
              b.extra_player_charge AS extraPlayerCharge,
              b.downpayment_amount AS downpayment,
              b.payment_status AS paymentStatus,
              b.paid_amount AS paidAmount,
              b.payment_refund_status AS paymentRefundStatus,
              b.payment_refund_id AS paymentRefundId,
              b.payment_reference AS paymentReference,
              ci.checked_in_at AS checkedInAt,
              b.status, b.created_at AS createdAt,
              r.id AS reviewId, r.rating AS reviewRating
       FROM bookings b
       JOIN merchant_businesses v ON v.id = b.venue_id
       JOIN users u ON u.id = v.merchant_id
       LEFT JOIN event_business_details e ON e.business_id = v.id
       LEFT JOIN fitness_business_details f ON f.business_id = v.id
       LEFT JOIN booking_check_ins ci ON ci.booking_id = b.id
       LEFT JOIN venue_reviews r ON r.booking_id = b.id AND r.customer_id = b.customer_id
       WHERE b.customer_id = ?${businessTypeFilter}
       ORDER BY b.booking_date DESC, b.start_time DESC`,
      params,
    );
    for (const booking of bookings) {
      booking.transactionId = bookingTransactionId(booking.id);
      for (const field of [
        'eventTypes',
        'accessibilityNeeds',
        'parkingNeeds',
        'securityNeeds',
      ]) {
        booking[field] = parseJsonArray(booking[field], field);
      }
      for (const field of ['ratePeriods', 'amenities']) {
        booking[field] = parseJsonArray(booking[field], field);
      }
      booking.imageUrls = parseJsonArray(booking.imageUrls, 'imageUrls');
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

app.patch('/api/bookings/:bookingId/cancel', requireAuth, requireRole('customer'), async (req, res, next) => {
  let connection;
  try {
    const bookingId = positiveIntegerId(req.params.bookingId);
    if (bookingId === null) {
      return res.status(400).json({ error: 'Invalid booking ID.' });
    }
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [bookings] = await connection.execute(
      `SELECT id, booking_date AS bookingDate, start_time AS startTime,
              payment_method AS paymentMethod, payment_status AS paymentStatus,
              paid_amount AS paidAmount, payment_reference AS paymentReference,
              payment_checkout_session_id AS checkoutSessionId
       FROM bookings
       WHERE id = ? AND customer_id = ? AND status IN ('pending', 'approved')
       LIMIT 1 FOR UPDATE`,
      [bookingId, req.auth.sub],
    );
    const booking = bookings[0];
    if (!booking) {
      await connection.rollback();
      return res.status(404).json({
        error: 'Booking not found or can no longer be cancelled.',
      });
    }
    const refundEligible = bookingStartsAtLeastSixHoursAway(booking);
    const isOnline = booking.paymentMethod === 'online';
    const hasPayment = Number(booking.paidAmount) > 0;
    let paymentRefundStatus = 'not_requested';
    if (isOnline && refundEligible && (hasPayment || booking.checkoutSessionId)) {
      paymentRefundStatus = 'pending';
    } else if (isOnline && hasPayment) {
      paymentRefundStatus = 'not_eligible';
    } else if (!isOnline && hasPayment) {
      paymentRefundStatus = 'manual_cash_return';
    }
    const [result] = await connection.execute(
      `UPDATE bookings
       SET status = 'cancelled', payment_refund_status = ?
       WHERE id = ? AND customer_id = ? AND status IN ('pending', 'approved')`,
      [paymentRefundStatus, bookingId, req.auth.sub],
    );
    if (!result.affectedRows) {
      await connection.rollback();
      return res.status(404).json({
        error: 'Booking not found or can no longer be cancelled.',
      });
    }
    await connection.commit();

    if (paymentRefundStatus === 'pending' && hasPayment) {
      paymentRefundStatus = await requestPaymongoBookingRefund(booking);
    }
    const message = paymentRefundStatus === 'succeeded'
      ? 'Booking cancelled. The online payment refund was completed.'
      : paymentRefundStatus === 'pending'
      ? 'Booking cancelled. The online payment refund is being processed.'
      : paymentRefundStatus === 'failed'
      ? 'Booking cancelled, but the online payment refund could not be confirmed. Please contact support.'
      : paymentRefundStatus === 'not_eligible'
      ? 'Booking cancelled. It is within 6 hours of the start time or has started, so the online payment was not refunded.'
      : paymentRefundStatus === 'manual_cash_return'
      ? 'Booking cancelled. Cash already collected must be returned manually; it cannot be voided by the app.'
      : 'Booking cancelled.';
    return res.json({ message, status: 'cancelled', paymentRefundStatus });
  } catch (error) {
    if (connection) await connection.rollback();
    return next(error);
  } finally {
    connection?.release();
  }
});

app.delete('/api/bookings/:bookingId', requireAuth, requireRole('customer'), async (req, res, next) => {
  try {
    const [result] = await pool.execute(
      `DELETE FROM bookings
       WHERE id = ? AND customer_id = ? AND status = 'finished'`,
      [req.params.bookingId, req.auth.sub],
    );
    if (!result.affectedRows) {
      return res.status(404).json({ error: 'Completed booking not found.' });
    }
    return res.json({ message: 'Completed booking permanently deleted.' });
  } catch (error) { return next(error); }
});

async function customerFitnessBookingForAttendance(bookingId, customerId) {
  const [bookings] = await pool.execute(
    `SELECT b.id, b.booking_date AS bookingDate, v.availability,
            b.fitness_plan_type AS fitnessPlanType,
            v.business_type AS businessType
     FROM bookings b
     JOIN merchant_businesses v ON v.id = b.venue_id
     WHERE b.id = ? AND b.customer_id = ?
       AND b.status IN ('approved', 'finished')
     LIMIT 1`,
    [bookingId, customerId],
  );
  const booking = bookings[0];
  if (!booking || String(booking.businessType).trim().toLowerCase() !== 'fitness & wellness') {
    return null;
  }
  return {
    ...booking,
    startDate: dateOnly(booking.bookingDate),
    endDate: fitnessPlanEndDate(
      booking.bookingDate,
      booking.fitnessPlanType,
    ),
  };
}

function validAttendanceDate(booking, date) {
  return validCalendarDate(date) &&
    date >= booking.startDate &&
    date <= booking.endDate;
}

app.get(
  '/api/bookings/:bookingId/attendance',
  requireAuth,
  requireRole('customer'),
  async (req, res, next) => {
    try {
      const bookingId = positiveIntegerId(req.params.bookingId);
      if (bookingId === null) {
        return res.status(400).json({ error: 'Invalid booking ID.' });
      }
      const booking = await customerFitnessBookingForAttendance(
        bookingId,
        req.auth.sub,
      );
      if (!booking) return res.status(404).json({ error: 'Fitness booking not found.' });
      const [attendance] = await pool.execute(
        `SELECT DATE_FORMAT(attendance_date, '%Y-%m-%d') AS date, status
         FROM fitness_booking_attendance
         WHERE booking_id = ? AND customer_id = ?
         ORDER BY attendance_date`,
        [bookingId, req.auth.sub],
      );
      return res.json({ attendance });
    } catch (error) { return next(error); }
  },
);

app.put(
  '/api/bookings/:bookingId/attendance/:date',
  requireAuth,
  requireRole('customer'),
  async (req, res, next) => {
    try {
      const bookingId = positiveIntegerId(req.params.bookingId);
      const { date, status } = req.params;
      if (bookingId === null) {
        return res.status(400).json({ error: 'Invalid booking ID.' });
      }
      if (!['present', 'absent'].includes(req.body?.status)) {
        return res.status(400).json({ error: 'Attendance status must be present or absent.' });
      }
      const booking = await customerFitnessBookingForAttendance(
        bookingId,
        req.auth.sub,
      );
      if (!booking) return res.status(404).json({ error: 'Fitness booking not found.' });
      if (!validAttendanceDate(booking, date)) {
        return res.status(400).json({ error: 'Attendance date must be within the booking period.' });
      }
      if (!fitnessAvailabilityIncludesDate(booking.availability, date)) {
        return res.status(400).json({ error: 'The fitness venue is closed on this day.' });
      }
      const today = new Date().toISOString().slice(0, 10);
      if (req.body.status === 'present' && date > today) {
        return res.status(400).json({ error: 'Future dates cannot be marked present.' });
      }
      await pool.execute(
        `INSERT INTO fitness_booking_attendance
           (booking_id, customer_id, attendance_date, status)
         VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE status = VALUES(status)`,
        [bookingId, req.auth.sub, date, req.body.status],
      );
      return res.json({ attendance: { date, status: req.body.status } });
    } catch (error) { return next(error); }
  },
);

app.delete(
  '/api/bookings/:bookingId/attendance/:date',
  requireAuth,
  requireRole('customer'),
  async (req, res, next) => {
    try {
      const bookingId = positiveIntegerId(req.params.bookingId);
      const { date } = req.params;
      if (bookingId === null) {
        return res.status(400).json({ error: 'Invalid booking ID.' });
      }
      const booking = await customerFitnessBookingForAttendance(
        bookingId,
        req.auth.sub,
      );
      if (!booking) return res.status(404).json({ error: 'Fitness booking not found.' });
      if (!validAttendanceDate(booking, date)) {
        return res.status(400).json({ error: 'Attendance date must be within the booking period.' });
      }
      await pool.execute(
        `DELETE FROM fitness_booking_attendance
         WHERE booking_id = ? AND customer_id = ? AND attendance_date = ?`,
        [bookingId, req.auth.sub, date],
      );
      return res.json({ message: 'Attendance cleared.' });
    } catch (error) { return next(error); }
  },
);

app.get(
  '/api/merchant/businesses/:venueId/check-in-code',
  requireAuth,
  requireRole('merchant'),
  async (req, res, next) => {
    try {
      const venueId = positiveIntegerId(req.params.venueId);
      if (venueId === null) {
        return res.status(400).json({ error: 'Invalid venue ID.' });
      }
      const [venues] = await pool.execute(
        `SELECT id, name
         FROM merchant_businesses
         WHERE id = ? AND merchant_id = ?
         LIMIT 1`,
        [venueId, req.auth.sub],
      );
      if (venues.length === 0) {
        return res.status(404).json({ error: 'Venue not found.' });
      }
      const code = venueCheckInCode(venueId);
      return res.json({
        qrCode: JSON.stringify(code),
        expiresAt: code.issuedAt + 120_000,
        venueName: venues[0].name,
      });
    } catch (error) {
      return next(error);
    }
  },
);

app.post(
  '/api/bookings/check-in',
  requireAuth,
  requireRole('customer'),
  async (req, res, next) => {
    const code = verifyVenueCheckInCode(req.body?.qrCode);
    if (!code) {
      return res.status(400).json({ error: 'This venue check-in QR code is invalid or expired.' });
    }
    const current = manilaDateTime();
    let connection;
    try {
      connection = await pool.getConnection();
      await connection.beginTransaction();
      const [bookings] = await connection.execute(
        `SELECT b.id AS bookingId, b.booking_date AS date,
                b.start_time AS startTime, b.duration_hours AS durationHours,
                v.name AS venueName
         FROM bookings b
         JOIN merchant_businesses v ON v.id = b.venue_id
         WHERE b.customer_id = ? AND b.venue_id = ?
           AND b.booking_date = ? AND b.status = 'approved'
         ORDER BY b.start_time
         FOR UPDATE`,
        [req.auth.sub, code.venueId, current.date],
      );
      const booking = bookings.find((candidate) =>
        bookingCheckInWindowIncludesNow(candidate, current.minutes),
      );
      if (!booking) {
        await connection.rollback();
        return res.status(409).json({
          error: 'No approved booking at this venue is scheduled for check-in right now.',
        });
      }

      const [existing] = await connection.execute(
        `SELECT DATE_FORMAT(checked_in_at, '%Y-%m-%dT%H:%i:%s') AS checkedInAt
         FROM booking_check_ins
         WHERE booking_id = ? AND customer_id = ?
         LIMIT 1
         FOR UPDATE`,
        [booking.bookingId, req.auth.sub],
      );
      if (existing.length > 0) {
        await connection.commit();
        return res.json({
          checkIn: {
            ...booking,
            checkedInAt: existing[0].checkedInAt,
          },
          alreadyCheckedIn: true,
        });
      }

      await connection.execute(
        `INSERT INTO booking_check_ins (booking_id, customer_id, qr_issued_at)
         VALUES (?, ?, FROM_UNIXTIME(? / 1000))`,
        [booking.bookingId, req.auth.sub, code.issuedAt],
      );
      const [checkIns] = await connection.execute(
        `SELECT DATE_FORMAT(checked_in_at, '%Y-%m-%dT%H:%i:%s') AS checkedInAt
         FROM booking_check_ins
         WHERE booking_id = ? AND customer_id = ?
         LIMIT 1`,
        [booking.bookingId, req.auth.sub],
      );
      await connection.commit();
      return res.status(201).json({
        checkIn: {
          ...booking,
          checkedInAt: checkIns[0]?.checkedInAt ?? null,
        },
        alreadyCheckedIn: false,
      });
    } catch (error) {
      if (connection) await connection.rollback();
      return next(error);
    } finally {
      connection?.release();
    }
  },
);

app.get('/api/merchant/bookings', requireAuth, requireRole('merchant'), async (req, res, next) => {
  try {
    await completeDueBookings();
    const [bookings] = await pool.execute(
      `SELECT b.id, b.customer_id AS customerId,
              CONCAT_WS(' ', u.first_name, u.last_name) AS customerName, u.email AS customerEmail,
              b.venue_id AS venueId, v.name AS venueName,
              v.address, v.facility_type AS facilityType, v.details,
              v.business_type AS businessType, b.booking_date AS date,
              b.start_time AS startTime, b.duration_hours AS durationHours, b.players,
              b.sport_type AS sportType, b.slot_number AS slotNumber,
              b.event_type AS eventType,
              b.fitness_plan_type AS fitnessPlanType,
              b.fitness_category AS fitnessCategory,
              b.fitness_coach_name AS fitnessCoachName,
              b.fitness_coach_duration_months AS fitnessCoachDurationMonths,
              b.fitness_plan_price AS fitnessPlanPrice,
              b.fitness_coach_price AS fitnessCoachPrice,
              b.occupies_full_studio AS occupiesFullStudio,
              b.payment_method AS paymentMethod, b.price_per_hour AS pricePerHour,
              b.extra_player_charge AS extraPlayerCharge,
              b.total_amount AS total, b.downpayment_amount AS downpayment,
              b.payment_status AS paymentStatus,
              b.paid_amount AS paidAmount,
              b.payment_refund_status AS paymentRefundStatus,
              b.payment_refund_id AS paymentRefundId,
              b.payment_reference AS paymentReference,
              ci.checked_in_at AS checkedInAt,
              b.status, b.created_at AS createdAt
       FROM bookings b JOIN merchant_businesses v ON v.id = b.venue_id
       JOIN users u ON u.id = b.customer_id
       LEFT JOIN booking_check_ins ci ON ci.booking_id = b.id
       WHERE v.merchant_id = ? ORDER BY b.booking_date, b.start_time`,
      [req.auth.sub],
    );
    return res.json({ bookings });
  } catch (error) { return next(error); }
});

app.patch('/api/merchant/bookings/:id/decline', requireAuth, requireRole('merchant'), async (req, res, next) => {
  try {
    const [result] = await pool.execute(
      `UPDATE bookings b JOIN merchant_businesses v ON v.id = b.venue_id
       SET b.status = 'cancelled'
       WHERE b.id = ? AND v.merchant_id = ? AND b.status = 'pending'
         AND b.paid_amount = 0`,
      [req.params.id, req.auth.sub],
    );
    if (!result.affectedRows) {
      const [paidOnline] = await pool.execute(
        `SELECT b.id FROM bookings b
         JOIN merchant_businesses v ON v.id = b.venue_id
         WHERE b.id = ? AND v.merchant_id = ? AND b.status = 'pending'
           AND b.paid_amount > 0
         LIMIT 1`,
        [req.params.id, req.auth.sub],
      );
      if (paidOnline.length > 0) {
        return res.status(409).json({
          error: 'Return the received payment before declining this booking.',
        });
      }
      return res.status(404).json({ error: 'Pending booking not found.' });
    }
    return res.json({ message: 'Booking declined.', status: 'cancelled' });
  } catch (error) { return next(error); }
});

app.delete('/api/merchant/bookings/:id', requireAuth, requireRole('merchant'), async (req, res, next) => {
  try {
    const [result] = await pool.execute(
      `DELETE b FROM bookings b
       JOIN merchant_businesses v ON v.id = b.venue_id
       WHERE b.id = ? AND v.merchant_id = ? AND b.status = 'finished'`,
      [req.params.id, req.auth.sub],
    );
    if (!result.affectedRows) {
      return res.status(404).json({ error: 'Completed booking not found.' });
    }
    return res.json({ message: 'Completed booking permanently deleted.' });
  } catch (error) { return next(error); }
});

app.patch('/api/merchant/bookings/:id/payment', requireAuth, requireRole('merchant'), async (req, res, next) => {
  try {
    const paymentStatus = req.body?.paymentStatus;
    if (!['partial', 'paid'].includes(paymentStatus)) {
      return res.status(400).json({
        error: 'Record the cash downpayment first, then the remaining balance.',
      });
    }
    const [result] = await pool.execute(
      paymentStatus === 'partial'
        ? `UPDATE bookings b JOIN merchant_businesses v ON v.id = b.venue_id
           SET b.payment_status = 'partial',
               b.paid_amount = b.downpayment_amount,
               b.paid_at = CURRENT_TIMESTAMP
           WHERE b.id = ? AND v.merchant_id = ?
             AND b.payment_method = 'cash_on_arrival'
             AND b.status <> 'cancelled' AND b.payment_status = 'unpaid'
             AND b.downpayment_amount > 0`
        : `UPDATE bookings b JOIN merchant_businesses v ON v.id = b.venue_id
           SET b.payment_status = 'paid', b.paid_amount = b.total_amount,
               b.paid_at = CURRENT_TIMESTAMP
           WHERE b.id = ? AND v.merchant_id = ?
             AND b.payment_method = 'cash_on_arrival'
             AND b.status <> 'cancelled' AND b.payment_status = 'partial'`,
      [req.params.id, req.auth.sub],
    );
    if (!result.affectedRows) {
      return res.status(404).json({
        error: 'Cash-on-arrival booking not found.',
      });
    }
    return res.json({ message: 'Payment status updated.', paymentStatus });
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
       WHERE b.id = ? AND v.merchant_id = ? AND b.status = 'pending'
         AND (
           (b.payment_method = 'online' AND b.payment_status = 'paid')
           OR b.payment_method = 'cash_on_arrival'
         )`,
      [hashBookingToken(ticketCode), req.params.id, req.auth.sub],
    );
    if (!result.affectedRows) {
      const [unpaid] = await connection.execute(
        `SELECT b.id FROM bookings b
         JOIN merchant_businesses v ON v.id = b.venue_id
         WHERE b.id = ? AND v.merchant_id = ? AND b.status = 'pending'
           AND b.payment_method = 'online' AND b.payment_status <> 'paid'
         LIMIT 1`,
        [req.params.id, req.auth.sub],
      );
      await connection.rollback();
      if (unpaid.length > 0) {
        return res.status(409).json({
          error: 'The required online payment must be verified before approving this booking.',
        });
      }
      return res.status(404).json({ error: 'Pending booking not found.' });
    }
    const [rows] = await connection.execute(
      `SELECT b.id, b.customer_id AS customerId, b.venue_id AS venueId,
              b.booking_date AS bookingDate, b.start_time AS startTime,
              b.duration_hours AS durationHours, b.players,
              b.total_amount AS totalAmount,
              b.payment_reference AS paymentReference,
              b.payment_method AS paymentMethod,
              b.payment_status AS paymentStatus,
              v.business_type AS businessType,
              v.name AS venueName,
              COALESCE(b.sport_type, v.category) AS sportType,
              b.event_type AS eventType,
              b.fitness_plan_type AS fitnessPlanType,
              b.fitness_category AS fitnessCategory,
              b.fitness_coach_name AS fitnessCoachName,
              b.fitness_coach_duration_months AS fitnessCoachDurationMonths,
              b.fitness_plan_price AS fitnessPlanPrice,
              b.fitness_coach_price AS fitnessCoachPrice,
              b.slot_number AS slotNumber,
              b.occupies_full_studio AS occupiesFullStudio
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
          transactionId: bookingTransactionId(booking.id),
          businessType: booking.businessType,
          eventType: booking.eventType,
          status: 'approved',
          ticketCode,
          venueName: booking.venueName,
          sportType: booking.sportType,
          fitnessPlanType: booking.fitnessPlanType,
          fitnessCategory: booking.fitnessCategory,
          fitnessCoachName: booking.fitnessCoachName,
          fitnessPlanPrice: booking.fitnessPlanPrice,
          fitnessCoachPrice: booking.fitnessCoachPrice,
          slotNumber: booking.slotNumber,
          fullStudio: Number(booking.occupiesFullStudio) === 1,
          bookingDate: booking.bookingDate,
          startTime: booking.startTime,
          durationHours: booking.durationHours,
          players: booking.players,
          amount: booking.totalAmount,
          paymentMethod: booking.paymentMethod,
          paymentStatus: booking.paymentStatus,
          paymentReference: booking.paymentReference,
        }),
      ],
    );
    await recordUserActivity(
      connection,
      req.auth.sub,
      'booking_approved',
      'Booking approved',
      `Booking #${booking.id} for ${booking.venueName} was approved.`,
      {
        venueId: booking.venueId,
        venueName: booking.venueName,
        sportType: booking.sportType,
        details: {
          bookingId: booking.id,
          bookingDate: booking.bookingDate,
          startTime: booking.startTime,
          durationHours: booking.durationHours,
          players: booking.players,
        },
      },
    );
    await recordUserActivity(
      connection,
      booking.customerId,
      'booking_approved',
      'Booking approved',
      `Booking #${booking.id} for ${booking.venueName} was approved.`,
      {
        venueId: booking.venueId,
        venueName: booking.venueName,
        sportType: booking.sportType,
        details: {
          bookingId: booking.id,
          bookingDate: booking.bookingDate,
          startTime: booking.startTime,
          durationHours: booking.durationHours,
          players: booking.players,
        },
      },
    );
    await connection.commit();
    return res.json({
      message: 'Booking approved and ticket issued.',
      status: 'approved',
      transactionId: bookingTransactionId(req.params.id),
      ticketCode,
    });
  } catch (error) {
    if (connection) await connection.rollback();
    return next(error);
  } finally {
    connection?.release();
  }
});

const dueBookingPredicate = `(
  (
    LOWER(v.business_type) = 'fitness & wellness'
    AND b.fitness_plan_type = 'monthly'
    AND CURRENT_DATE >= DATE_ADD(b.booking_date, INTERVAL 1 MONTH)
  )
  OR (
    LOWER(v.business_type) = 'fitness & wellness'
    AND b.fitness_plan_type = 'yearly'
    AND CURRENT_DATE >= DATE_ADD(b.booking_date, INTERVAL 1 YEAR)
  )
  OR (
    (
      LOWER(v.business_type) = 'fitness & wellness'
      AND b.fitness_plan_type = 'session'
    )
    AND TIMESTAMP(b.booking_date, b.start_time)
        + INTERVAL COALESCE(
            f.session_duration_minutes,
            ROUND(b.duration_hours * 60)
          ) MINUTE <= CURRENT_TIMESTAMP
  )
  OR (
    (
      LOWER(v.business_type) <> 'fitness & wellness'
      OR b.fitness_plan_type IS NULL
    )
    AND TIMESTAMP(b.booking_date, b.start_time)
        + INTERVAL ROUND(b.duration_hours * 60) MINUTE <= CURRENT_TIMESTAMP
  )
)`;

let dueBookingCompletionRunning = false;

async function completeDueBookings() {
  if (dueBookingCompletionRunning) return;
  dueBookingCompletionRunning = true;
  try {
    const [dueBookings] = await pool.execute(
      `SELECT b.id, b.customer_id AS customerId, v.merchant_id AS merchantId,
              b.venue_id AS venueId, v.name AS venueName,
              b.booking_date AS bookingDate, b.start_time AS startTime,
              b.duration_hours AS durationHours,
              COALESCE(b.sport_type, v.category) AS sportType
       FROM bookings b
       JOIN merchant_businesses v ON v.id = b.venue_id
       LEFT JOIN fitness_business_details f ON f.business_id = v.id
       WHERE b.status = 'approved' AND ${dueBookingPredicate}
       ORDER BY b.id`,
    );

    for (const booking of dueBookings) {
      const connection = await pool.getConnection();
      try {
        await connection.beginTransaction();
        const [result] = await connection.execute(
          `UPDATE bookings b
           JOIN merchant_businesses v ON v.id = b.venue_id
           LEFT JOIN fitness_business_details f ON f.business_id = v.id
           SET b.status = 'finished'
           WHERE b.id = ? AND b.status = 'approved'
             AND ${dueBookingPredicate}`,
          [booking.id],
        );
        if (!result.affectedRows) {
          await connection.rollback();
          continue;
        }
        const description =
          `Booking #${booking.id} for ${booking.venueName} was completed automatically at its scheduled end.`;
        const activityDetails = {
          venueId: booking.venueId,
          venueName: booking.venueName,
          sportType: booking.sportType,
          details: {
            bookingId: booking.id,
            bookingDate: booking.bookingDate,
            startTime: booking.startTime,
            durationHours: booking.durationHours,
          },
        };
        await recordUserActivity(
          connection,
          booking.merchantId,
          'booking_finished',
          'Booking completed automatically',
          description,
          activityDetails,
        );
        await recordUserActivity(
          connection,
          booking.customerId,
          'booking_finished',
          'Booking completed',
          description,
          activityDetails,
        );
        await connection.commit();
      } catch (error) {
        await connection.rollback();
        throw error;
      } finally {
        connection.release();
      }
    }
  } finally {
    dueBookingCompletionRunning = false;
  }
}

app.patch('/api/merchant/bookings/:id/finish', requireAuth, requireRole('merchant'), async (req, res, next) => {
  try {
    const [result] = await pool.execute(
      `UPDATE bookings b JOIN merchant_businesses v ON v.id = b.venue_id
       SET b.status = 'finished' WHERE b.id = ? AND v.merchant_id = ? AND b.status = 'approved'`,
      [req.params.id, req.auth.sub],
    );
    if (!result.affectedRows) return res.status(404).json({ error: 'Approved booking not found.' });
    const [bookings] = await pool.execute(
      `SELECT b.customer_id AS customerId, b.venue_id AS venueId,
              b.booking_date AS bookingDate, b.start_time AS startTime,
              b.duration_hours AS durationHours, b.players,
              v.name AS venueName,
              COALESCE(b.sport_type, v.category) AS sportType
       FROM bookings b JOIN merchant_businesses v ON v.id = b.venue_id
       WHERE b.id = ? AND v.merchant_id = ? LIMIT 1`,
      [req.params.id, req.auth.sub],
    );
    const booking = bookings[0];
    if (booking) {
      await recordUserActivity(
        pool,
        req.auth.sub,
        'booking_finished',
        'Booking marked finished',
        `Booking #${req.params.id} for ${booking.venueName} was marked finished.`,
        {
          venueId: booking.venueId,
          venueName: booking.venueName,
          sportType: booking.sportType,
          details: {
            bookingId: req.params.id,
            bookingDate: booking.bookingDate,
            startTime: booking.startTime,
            durationHours: booking.durationHours,
            players: booking.players,
          },
        },
      );
      await recordUserActivity(
        pool,
        booking.customerId,
        'booking_finished',
        'Booking completed',
        `Booking #${req.params.id} for ${booking.venueName} was marked finished.`,
        {
          venueId: booking.venueId,
          venueName: booking.venueName,
          sportType: booking.sportType,
          details: {
            bookingId: req.params.id,
            bookingDate: booking.bookingDate,
            startTime: booking.startTime,
            durationHours: booking.durationHours,
            players: booking.players,
          },
        },
      );
    }
    return res.json({ message: 'Booking marked finished.', status: 'finished' });
  } catch (error) { return next(error); }
});

registerMerchantNewsRoutes({
  app,
  pool,
  requireAuth,
  requireRole,
  positiveIntegerId,
  normalizeText,
  invalidateCustomerBusinesses,
  recordUserActivity,
});

async function customerNewsFeed(req, res, next) {
  const businessType = req.query.businessType === undefined
    ? null
    : normalizeBusinessType(req.query.businessType);
  if (req.query.businessType !== undefined && !businessType) {
    return res.status(400).json({ error: 'Invalid business type filter.' });
  }
  const businessTypeFilter = businessType
    ? ' AND LOWER(b.business_type) = ?'
    : '';
  const params = businessType
    ? [req.auth.sub, businessType]
    : [req.auth.sub];
  try {
    const [rows] = await pool.execute(
      `SELECT n.*, b.name AS business_name, b.business_type,
              b.category AS business_category, b.address AS business_address,
              b.latitude, b.longitude,
              b.facility_type, b.opening_hours, b.availability,
              b.price_per_hour, b.event_fee, b.rate_periods,
              b.slot_count, b.sports_slots_json,
              b.amenities_json, b.details AS business_details,
              b.image_url AS business_image_url, b.image_urls, b.enabled,
              b.visit_url, e.event_types_json,
              u.first_name AS merchant_first_name, u.last_name AS merchant_last_name,
              u.email AS merchant_email, u.phone AS merchant_phone,
              u.avatar_url AS merchant_avatar_url,
              COALESCE((SELECT AVG(r.rating) FROM venue_reviews r WHERE r.business_id = b.id), 0) AS average_rating,
              (SELECT COUNT(*) FROM venue_reviews r WHERE r.business_id = b.id) AS review_count,
              (SELECT COUNT(DISTINCT r.customer_id) FROM venue_reviews r WHERE r.business_id = b.id) AS rating_user_count,
              (SELECT COUNT(*) FROM venue_hearts h WHERE h.business_id = b.id) AS heart_count,
              EXISTS(SELECT 1 FROM venue_hearts h
                     WHERE h.business_id = b.id AND h.user_id = ?) AS hearted_by_me
       FROM merchant_news n
       INNER JOIN merchant_businesses b ON b.id = n.business_id
       INNER JOIN users u ON u.id = b.merchant_id
       LEFT JOIN event_business_details e ON e.business_id = b.id
       WHERE n.status = 'published'
         AND n.id = (
           SELECT MAX(latest.id)
           FROM merchant_news latest
           WHERE latest.business_id = n.business_id
             AND latest.status = 'published'
         )
         AND b.enabled = 1
         AND u.status = 'active'
         AND NULLIF(TRIM(n.title), '') IS NOT NULL
         AND NULLIF(TRIM(n.body), '') IS NOT NULL
         AND COALESCE(NULLIF(TRIM(n.image_url), ''),
                      NULLIF(TRIM(b.image_url), '')) IS NOT NULL${businessTypeFilter}
       ORDER BY n.created_at DESC`,
      params,
    );
    return res.json({ posts: rows.map(newsPostResponse) });
  } catch (error) { return next(error); }
}

async function setVenueHeart(req, res, next, hearted) {
  const businessId = positiveIntegerId(req.params.businessId);
  if (businessId === null) {
    return res.status(400).json({ error: 'A valid venue is required.' });
  }
  try {
    const [venues] = await pool.execute(
      `SELECT id, name, category FROM merchant_businesses
       WHERE id = ? AND enabled = 1 LIMIT 1`,
      [businessId],
    );
    if (venues.length === 0) {
      return res.status(404).json({ error: 'Venue not found.' });
    }
    let changed = false;
    if (hearted) {
      const [result] = await pool.execute(
        `INSERT IGNORE INTO venue_hearts (business_id, user_id)
         VALUES (?, ?)`,
        [businessId, req.auth.sub],
      );
      changed = result.affectedRows > 0;
    } else {
      const [result] = await pool.execute(
        'DELETE FROM venue_hearts WHERE business_id = ? AND user_id = ?',
        [businessId, req.auth.sub],
      );
      changed = result.affectedRows > 0;
    }
    if (changed) invalidateCustomerBusinesses();
    if (changed) {
      await recordUserActivity(
        pool,
        req.auth.sub,
        hearted ? 'venue_hearted' : 'venue_unhearted',
        hearted ? 'Venue hearted' : 'Venue unhearted',
        hearted
          ? 'You hearted a venue.'
          : 'You removed your heart from a venue.',
        {
          venueId: venues[0].id,
          venueName: venues[0].name,
          sportType: venues[0].category,
        },
      );
    }
    const [counts] = await pool.execute(
      'SELECT COUNT(*) AS heartCount FROM venue_hearts WHERE business_id = ?',
      [businessId],
    );
    return res.json({
      heartCount: Number(counts[0]?.heartCount || 0),
      heartedByMe: hearted,
    });
  } catch (error) {
    return next(error);
  }
}

app.get(
  '/api/customer/venue-hearts',
  requireAuth,
  requireRole('customer'),
  async (req, res, next) => {
    try {
      const [rows] = await pool.execute(
        `SELECT business_id AS businessId
         FROM venue_hearts WHERE user_id = ?`,
        [req.auth.sub],
      );
      return res.json({ businesses: rows });
    } catch (error) {
      return next(error);
    }
  },
);

app.put(
  '/api/businesses/:businessId/heart',
  requireAuth,
  requireRole('customer'),
  (req, res, next) => setVenueHeart(req, res, next, true),
);
app.delete(
  '/api/businesses/:businessId/heart',
  requireAuth,
  requireRole('customer'),
  (req, res, next) => setVenueHeart(req, res, next, false),
);

app.get('/api/news/feed', requireAuth, requireRole('customer'), customerNewsFeed);
app.get('/api/customer/news', requireAuth, requireRole('customer'), customerNewsFeed);
app.get('/api/news-feed', requireAuth, requireRole('customer'), customerNewsFeed);

async function submitCustomerReview(req, res, next) {
  const bookingId = positiveIntegerId(req.body.bookingId);
  const rating = Number(req.body.rating);
  const comment = normalizeText(req.body.comment, 2000) || null;
  if (bookingId === null ||
      !isNumericInput(req.body.rating) ||
      !Number.isInteger(rating) || rating < 1 || rating > 5 ||
      (req.body.comment != null &&
        (typeof req.body.comment !== 'string' ||
          req.body.comment.length > 2000))) {
    return res.status(400).json({ error: 'A valid bookingId and rating from 1 to 5 are required.' });
  }
  try {
    const [bookings] = await pool.execute(
      `SELECT b.id, b.venue_id AS venueId, v.name AS venueName,
              COALESCE(b.sport_type, v.category) AS sportType,
              b.booking_date AS bookingDate,
              b.start_time AS startTime
       FROM bookings b
       JOIN merchant_businesses v ON v.id = b.venue_id
       WHERE b.id = ? AND b.customer_id = ? AND b.status = 'finished' LIMIT 1`,
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
      [bookings[0].venueId, bookingId, req.auth.sub, rating, comment],
    );
    invalidateCustomerBusinesses();
    return res.status(201).json({ id: result.insertId, message: 'Review submitted.' });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'You have already reviewed this booking.' });
    return next(error);
  }
}

async function listBusinessReviews(req, res, next) {
  const businessId = positiveIntegerId(req.params.businessId);
  if (businessId === null) {
    return res.status(400).json({ error: 'Invalid business id.' });
  }
  try {
    const [rows] = await pool.execute(
      `SELECT r.id, r.business_id AS businessId, r.booking_id AS bookingId,
              r.customer_id AS customerId, r.rating, r.comment, r.created_at AS createdAt,
              u.first_name AS firstName, u.last_name AS lastName,
              u.avatar_url AS avatarUrl
       FROM venue_reviews r INNER JOIN users u ON u.id = r.customer_id
       WHERE r.business_id = ? ORDER BY r.created_at DESC`,
      [businessId],
    );
    return res.json({ reviews: rows });
  } catch (error) { return next(error); }
}

async function submitBusinessReview(req, res, next) {
  const businessId = positiveIntegerId(req.params.businessId);
  const rating = Number(req.body.rating);
  const comment = normalizeText(req.body.comment, 2000) || null;
  if (businessId === null ||
      !isNumericInput(req.body.rating) ||
      !Number.isInteger(rating) || rating < 1 || rating > 5 ||
      (req.body.comment != null &&
        (typeof req.body.comment !== 'string' ||
          req.body.comment.length > 2000))) {
    return res.status(400).json({ error: 'A valid business id and rating from 1 to 5 are required.' });
  }
  try {
    const [bookings] = await pool.execute(
      `SELECT b.id, b.venue_id AS venueId, v.name AS venueName,
              COALESCE(b.sport_type, v.category) AS sportType,
              b.booking_date AS bookingDate, b.start_time AS startTime
       FROM bookings b
       INNER JOIN merchant_businesses v ON v.id = b.venue_id
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
    invalidateCustomerBusinesses();
    const [reviews] = await pool.execute(
      `SELECT id, business_id AS businessId, booking_id AS bookingId, customer_id AS customerId,
              rating, comment, created_at AS createdAt
       FROM venue_reviews WHERE id = ?`,
      [result.insertId],
    );
    await recordUserActivity(
      pool,
      req.auth.sub,
      'review_submitted',
      'Review submitted',
      `You reviewed a venue with ${rating} star${rating === 1 ? '' : 's'}.`,
      {
        venueId: bookings[0].venueId,
        venueName: bookings[0].venueName,
        sportType: bookings[0].sportType,
        details: {
          bookingId: bookings[0].id,
          bookingDate: bookings[0].bookingDate,
          startTime: bookings[0].startTime,
          rating,
        },
      },
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
  const requestId = auditContextStorage.getStore()?.requestId;
  console.error('API request failed.', {
    requestId,
    method: req.method,
    path: req.path,
    error,
  });
  if (error.type === 'entity.too.large') {
    return res.status(413).json({
      error: 'The selected images are too large. Choose fewer or smaller images.',
    });
  }
  if (error.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'The request body contains invalid JSON.' });
  }
  if (
    error.code === 'EAUTH' ||
    error.code === 'ESOCKET' ||
    error.code === 'ECONNECTION' ||
    error.responseCode === 535
  ) {
    return res.status(503).json({
      error: 'We could not send the verification email. Please try again later.',
    });
  }
  return res.status(500).json({ error: 'An unexpected server error occurred.' });
});

function startServer() {
  const server = app.listen(port, () => {
    console.log(`TinkerPro Sports API listening on http://localhost:${port}`);
  });
  const completionInterval = setInterval(() => {
    completeDueBookings().catch((error) => {
      console.error('Could not automatically finish due bookings.', error);
    });
  }, 10_000);
  completionInterval.unref();
  completeDueBookings().catch((error) => {
    console.error('Could not automatically finish due bookings.', error);
  });
  return server;
}

startServer();
