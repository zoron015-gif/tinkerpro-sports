const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const bcrypt = require('bcryptjs');
const { after, before, beforeEach, test } = require('node:test');
const Module = require('node:module');
const path = require('node:path');
const express = require('express');
const jwt = require('jsonwebtoken');
const readCache = require('../src/read_cache');
const { hashVerificationCode } = require('../src/normalizers');

const serverFile = path.join(__dirname, '..', 'src', 'server.js');
const originalLoad = Module._load;
const originalListen = express.application.listen;
let server;
let originalJwtSecret;
let originalPaymongoSecret;
let originalPaymongoWebhookSecret;
let db;
let sentVerificationCodes;
let sentResetCodes;
let paymentBooking;
let attendanceBooking;
let attendanceRecords;

function response(rows = []) {
  return [rows, []];
}

function bookingStartAfterHours(hours) {
  const manilaTime = new Date(
    Date.now() + hours * 60 * 60 * 1000 + 8 * 60 * 60 * 1000,
  ).toISOString();
  return {
    bookingDate: manilaTime.slice(0, 10),
    startTime: `${manilaTime.slice(11, 19)}`,
  };
}

function makeConnection() {
  return {
    beginTransaction: async () => {},
    commit: async () => {},
    rollback: async () => {},
    release: () => {},
    execute: async (sql, params = []) => {
      db.calls.push({ sql, params });

      if (
        sql.includes('FROM bookings b') &&
        sql.includes('b.customer_id = ? AND b.venue_id = ?') &&
        sql.includes("b.status = 'approved'")
      ) {
        return response(
          db.checkInBookings.filter(
            (booking) =>
              String(booking.customerId) === String(params[0]) &&
              Number(booking.venueId) === Number(params[1]) &&
              booking.date === params[2],
          ),
        );
      }
      if (sql.includes('FROM booking_check_ins')) {
        const checkIn = db.checkIns.get(Number(params[0]));
        return response(checkIn ? [checkIn] : []);
      }
      if (sql.includes('INSERT INTO booking_check_ins')) {
        db.checkIns.set(Number(params[0]), {
          checkedInAt: new Date().toISOString().slice(0, 19),
        });
        return [{ affectedRows: 1 }, []];
      }
      if (
        sql.includes('FROM bookings') &&
        sql.includes('payment_method AS paymentMethod') &&
        sql.includes("status IN ('pending', 'approved')") &&
        sql.includes('FOR UPDATE')
      ) {
        return response(
          db.cancellationBooking &&
            Number(params[0]) === db.cancellationBooking.id &&
            String(params[1]) === '42'
            ? [db.cancellationBooking]
            : [],
        );
      }
      if (sql.includes('FROM users WHERE email = ? LIMIT 1')) {
        return response(db.existingRegistrationUser ? [db.existingRegistrationUser] : []);
      }
      if (sql.includes('INSERT INTO users')) return [{ insertId: 71 }, []];
      if (sql.includes('SELECT id FROM users WHERE email = ? AND status != ?')) {
        return response(db.resetUser ? [{ id: db.resetUser.id }] : []);
      }
      if (sql.includes('SELECT t.id AS token_id, t.token_hash, u.id, u.email')) {
        return response(db.verificationToken ? [db.verificationToken] : []);
      }
      if (sql.includes('SELECT t.id AS token_id, t.token_hash, u.id AS user_id')) {
        return response(db.resetToken ? [db.resetToken] : []);
      }
      if (sql.includes('FROM merchant_businesses b JOIN users u')) {
        return response(db.venue ? [db.venue] : []);
      }
      if (sql.includes('FROM fitness_business_details WHERE business_id = ?')) {
        return response(db.fitnessDetails ? [db.fitnessDetails] : []);
      }
      if (sql.includes('FROM event_business_details WHERE business_id = ?')) {
        return response(db.eventDetails ? [db.eventDetails] : []);
      }
      if (
        sql.includes('SELECT idempotency_request_hash AS requestHash') &&
        sql.includes('FROM bookings')
      ) {
        const stored = db.idempotencyRecords.get(`${params[0]}:${params[1]}`);
        return response(stored ? [stored] : []);
      }
      if (sql.includes('FROM merchant_news n')) {
        return response(db.newsFeedRows);
      }
      if (sql.includes('FROM bookings') && sql.includes('AND start_time <')) {
        return response(db.overlapRows ?? (
          db.overlap
            ? [{ slotNumber: null, occupiesFullStudio: 1 }]
            : []
        ));
      }
      if (
        sql.includes('SELECT b.id, b.customer_id AS customerId') &&
        sql.includes('CURRENT_DATE >= DATE_ADD(b.booking_date')
      ) {
        return response(db.dueBookings);
      }
      if (sql.includes('WHERE b.payment_checkout_session_id = ?')) {
        return response(
          db.webhookBooking?.paymentCheckoutSessionId === params[0]
            ? [db.webhookBooking]
            : [],
        );
      }
      if (
        sql.includes("JOIN bookings b ON c.title = CONCAT('Booking ', b.id)") &&
        sql.includes('cm.deleted_at IS NULL')
      ) {
        return response(
          db.conversationBusinessType === params[2] ? [{ id: 601 }] : [],
        );
      }
      if (
        sql.includes('JOIN user_blocks ub') &&
        sql.includes('sender.conversation_id')
      ) {
        return response([]);
      }
      if (sql.includes('SELECT 1 FROM conversation_members')) {
        return response([{}]);
      }
      if (sql.includes('INSERT INTO bookings')) {
        const recordKey = `${params[0]}:${params[23]}`;
        if (db.idempotencyRecords.has(recordKey)) {
          const error = new Error(
            'Duplicate entry for uq_bookings_customer_idempotency',
          );
          error.code = 'ER_DUP_ENTRY';
          throw error;
        }
        db.idempotencyRecords.set(recordKey, {
          customerId: params[0],
          bookingId: 601,
          requestHash: params[24],
          responseJson: null,
          responseStatus: null,
        });
        return [{ insertId: 601 }, []];
      }
      if (sql.includes('SET idempotency_response_json = ?')) {
        const record = [...db.idempotencyRecords.values()].find((item) =>
          item.bookingId === params[1] &&
          String(item.customerId) === String(params[2]),
        );
        if (record) {
          record.responseJson = params[0];
          record.responseStatus = 201;
        }
        return [{ affectedRows: 1 }, []];
      }
      if (sql.includes('SELECT b.id, b.customer_id AS customerId')) {
        return response([{
          id: Number(params[0]),
          customerId: 42,
          venueId: 7,
          venueName: 'Test Court',
          sportType: 'Basketball',
          bookingDate: '2026-10-01',
          startTime: '09:00:00',
          durationHours: 2,
          players: 6,
          businessType: 'Sports',
        }]);
      }
      if (sql.includes('SELECT id FROM conversations WHERE type = ?')) {
        return response([]);
      }
      if (sql.includes('INSERT INTO conversations')) return [{ insertId: 601 }, []];
      if (sql.includes('UPDATE bookings b JOIN merchant_businesses')) {
        return [{ affectedRows: db.transitionAffected ? 1 : 0 }, []];
      }
      if (sql.includes('DELETE b FROM bookings b')) {
        return [{ affectedRows: db.deleteAffected ? 1 : 0 }, []];
      }
      if (sql.includes('DELETE FROM bookings')) {
        return [{ affectedRows: db.deleteAffected ? 1 : 0 }, []];
      }
      if (sql.includes("SET status = 'cancelled', payment_refund_status = ?")) {
        if (db.cancellationBooking) {
          db.cancellationBooking.paymentRefundStatus = params[0];
          db.cancellationBooking.status = 'cancelled';
        }
        return [{ affectedRows: db.cancelAffected ? 1 : 0 }, []];
      }
      if (
        sql.includes("UPDATE bookings") &&
        sql.includes("SET b.status = 'cancelled'")
      ) {
        return [{ affectedRows: db.cancelAffected ? 1 : 0 }, []];
      }
      return [{ affectedRows: 1, insertId: 601 }, []];
    },
  };
}

function resetDatabase() {
  readCache.clear();
  db = {
    calls: [],
    idempotencyRecords: new Map(),
    accountStatus: 'active',
    venueReviews: [],
    customerHeartedBusinessRows: [],
    reviewEligibleBookings: [],
    newsFeedRows: [],
    newsWriteResults: [],
    customerBusinessRows: [],
    existingRegistrationUser: null,
    loginUser: null,
    resetUser: null,
    verificationToken: null,
    resetToken: null,
    availabilityRows: [],
    availabilityError: null,
    customerBookings: [],
    dueBookings: [],
    checkInBookings: [],
    checkIns: new Map(),
    venue: {
      id: 7,
      merchant_id: 88,
      name: 'Test Court',
      image_url: 'https://example.test/test-court.jpg',
      businessType: 'Sports',
      category: 'Basketball',
      price_per_hour: 120,
      slot_count: 5,
      sports_slots_json: [
        {
          sportType: 'Basketball',
          pricePerHour: 120,
          fullStudio: true,
          slotCount: 5,
        },
        {
          sportType: 'Badminton',
          pricePerHour: 90,
          fullStudio: false,
          slotCount: 4,
          includedPlayers: 2,
          additionalPlayerFee: 5,
        },
      ],
      included_players: 4,
      additional_player_fee: 15,
      enabled: 1,
      merchant_status: 'active',
    },
    fitnessDetails: {
      fitnessCategories: [{
        category: 'Yoga',
        sessionPrice: 500,
        monthlyPrice: 1200,
        yearlyPrice: 12000,
        yearlyDiscountType: 'freeMonths',
        yearlyDiscountValue: 2,
      }],
      fitnessCoaches: [{ name: 'Alex Coach', monthlyPrice: 300 }],
    },
    eventDetails: {
      eventTypes: ['Wedding', 'Birthday', 'Party'],
      attendanceMin: 50,
      attendanceMax: 250,
    },
    overlap: false,
    overlapRows: null,
    transitionAffected: true,
    deleteAffected: true,
    cancelAffected: true,
    cancellationBooking: null,
    conversationBusinessType: 'sports',
    messageReadScope: null,
    duplicateDirectConversationIds: [],
    paymentBooking: {
      id: 501,
      totalAmount: 270,
      downpaymentAmount: 135,
      paymentMethod: 'online',
      paymentStatus: 'unpaid',
      paidAmount: 0,
      status: 'pending',
    },
    webhookBooking: null,
  };
  paymentBooking = db.paymentBooking;
  attendanceBooking = {
    id: 501,
    bookingDate: '2026-09-08',
    fitnessPlanType: 'monthly',
    businessType: 'Fitness & Wellness',
    availability: 'Monday, Tuesday, Wednesday, Thursday, Friday, Saturday',
  };
  attendanceRecords = [{ date: '2026-09-09', status: 'present' }];
  sentVerificationCodes = [];
  sentResetCodes = [];
}

function bearer(role = 'customer', id = role === 'merchant' ? '88' : '42') {
  return jwt.sign({ sub: id, email: `${role}@example.test`, role }, process.env.JWT_SECRET);
}

async function request(
  url,
  { role, id, idempotencyKey = 'test-idempotency-key-0001', ...options } = {},
) {
  const headers = new Headers(options.headers);
  headers.set('authorization', `Bearer ${bearer(role, id)}`);
  if (options.body !== undefined) headers.set('content-type', 'application/json');
  if (
    url === '/api/bookings' &&
    options.method === 'POST' &&
    idempotencyKey !== null
  ) {
    headers.set('idempotency-key', idempotencyKey);
  }
  return fetch(`http://127.0.0.1:${server.address().port}${url}`, {
    ...options,
    headers,
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });
}

before(async () => {
  originalJwtSecret = process.env.JWT_SECRET;
  originalPaymongoSecret = process.env.PAYMONGO_SECRET_KEY;
  originalPaymongoWebhookSecret = process.env.PAYMONGO_WEBHOOK_SECRET;
  process.env.JWT_SECRET = 'backend-test-only-secret';
  delete process.env.PAYMONGO_SECRET_KEY;
  resetDatabase();

  const fakePool = {
    execute: async (sql, params = []) => {
      db.calls.push({ sql, params });
      if (
        sql.includes('FROM merchant_businesses') &&
        sql.includes('WHERE id = ? AND merchant_id = ?')
      ) {
        return response(
          Number(params[0]) === db.venue.id &&
            String(params[1]) === String(db.venue.merchant_id)
            ? [{
              id: db.venue.id,
              name: db.venue.name,
              image_url: db.venue.image_url,
            }]
            : [],
        );
      }
      if (
        sql.includes('SELECT idempotency_request_hash AS requestHash') &&
        sql.includes('FROM bookings')
      ) {
        const stored = db.idempotencyRecords.get(`${params[0]}:${params[1]}`);
        return response(stored ? [stored] : []);
      }
      if (sql.includes('SELECT id, email, password_hash, first_name')) {
        return response(db.loginUser ? [db.loginUser] : []);
      }
      if (sql.includes('SELECT role, status FROM users WHERE id = ?')) {
        const role = String(params[0]) === '88' ? 'merchant' : 'customer';
        return response([{ role, status: db.accountStatus }]);
      }
      if (sql.includes('SELECT id FROM users WHERE id = ? AND role = \'merchant\'')) {
        return response([{ id: Number(params[0]) }]);
      }
      if (sql.includes('INSERT INTO merchant_businesses')) {
        return [{ insertId: 702 }, []];
      }
      if (sql.includes('INSERT INTO merchant_news')) {
        return [db.newsWriteResults.shift() || { insertId: 500, affectedRows: 1 }, []];
      }
      if (
        sql.includes('UPDATE merchant_businesses') &&
        sql.includes('SET image_url = ?, image_urls = ?')
      ) {
        return [{ affectedRows: db.imageUpdateAffected ?? 1 }, []];
      }
      if (
        sql.includes('SELECT b.id, b.customer_id AS customerId') &&
        sql.includes('CURRENT_DATE >= DATE_ADD(b.booking_date')
      ) {
        return response(db.dueBookings);
      }
      if (sql.includes('SELECT id, name, category FROM merchant_businesses') && sql.includes('enabled = 1')) {
        return response([{
          id: Number(params[0]),
          name: 'Test Court',
          category: 'Basketball',
        }]);
      }
      if (sql.includes('SELECT id, total_amount AS totalAmount')) {
        return response(paymentBooking ? [paymentBooking] : []);
      }
      if (sql.includes('FROM venue_reviews r INNER JOIN users u')) {
        return response(db.venueReviews);
      }
      if (
        sql.includes('FROM merchant_businesses b') &&
        sql.includes('LEFT JOIN event_business_details e') &&
        sql.includes('ORDER BY b.created_at DESC')
      ) {
        return response(db.customerBusinessRows);
      }
      if (sql.includes('FROM venue_hearts WHERE user_id = ?')) {
        return response(db.customerHeartedBusinessRows);
      }
      if (
        sql.includes('LEFT JOIN venue_reviews r ON r.booking_id = b.id') &&
        sql.includes('b.venue_id = ?')
      ) {
        return response(db.reviewEligibleBookings);
      }
      if (sql.includes('FROM merchant_news n')) {
        return response(db.newsFeedRows);
      }
      if (
        sql.includes('FROM bookings b') &&
        sql.includes('LEFT JOIN fitness_business_details')
      ) {
        return response(db.customerBookings);
      }
      if (
        sql.includes('FROM bookings b') &&
        sql.includes('b.id = ? AND b.customer_id = ?')
      ) {
        return response(
          attendanceBooking &&
            Number(params[0]) === attendanceBooking.id &&
            String(params[1]) === '42'
            ? [attendanceBooking]
            : [],
        );
      }
      if (sql.includes('FROM fitness_booking_attendance')) {
        return response(attendanceRecords);
      }
      if (sql.includes('SELECT start_time AS startTime')) {
        if (db.availabilityError) throw db.availabilityError;
        return response(db.availabilityRows);
      }
      if (sql.includes('FROM email_verification_tokens t')) {
        return response(db.verificationToken ? [db.verificationToken] : []);
      }
      if (sql.includes('FROM password_reset_tokens t')) {
        return response(db.resetToken ? [db.resetToken] : []);
      }
      if (sql.includes('UPDATE bookings b JOIN merchant_businesses')) {
        return [{ affectedRows: db.transitionAffected ? 1 : 0 }, []];
      }
      if (sql.includes('DELETE b FROM bookings b')) {
        return [{ affectedRows: db.deleteAffected ? 1 : 0 }, []];
      }
      if (sql.includes('DELETE FROM bookings')) {
        return [{ affectedRows: db.deleteAffected ? 1 : 0 }, []];
      }
      if (sql.includes('SET payment_refund_status = ?')) {
        const bookingId = Number(params[2]);
        if (db.cancellationBooking?.id === bookingId) {
          db.cancellationBooking.paymentRefundStatus = params[0];
          db.cancellationBooking.paymentRefundId = params[1];
        }
        if (db.webhookBooking?.id === bookingId) {
          db.webhookBooking.paymentRefundStatus = params[0];
          db.webhookBooking.paymentRefundId = params[1];
        }
        return [{ affectedRows: 1 }, []];
      }
      if (sql.includes("SET payment_refund_status = 'failed'")) {
        if (db.cancellationBooking) {
          db.cancellationBooking.paymentRefundStatus = 'failed';
        }
        return [{ affectedRows: 1 }, []];
      }
      if (sql.includes("UPDATE bookings") && sql.includes("SET status = 'cancelled'")) {
        return [{ affectedRows: db.cancelAffected ? 1 : 0 }, []];
      }
      if (
        sql.includes("JOIN bookings b ON c.title = CONCAT('Booking ', b.id)") &&
        sql.includes('cm.deleted_at IS NULL')
      ) {
        return response(
          db.conversationBusinessType === params[2] ? [{ id: 601 }] : [],
        );
      }
      if (sql.includes('SELECT c.type, cm.archived_at AS archivedAt')) {
        return response(
          db.messageReadScope ? [db.messageReadScope] : [],
        );
      }
      if (
        sql.includes('JOIN conversation_members viewer') &&
        sql.includes('JOIN conversation_members peer')
      ) {
        return response(
          db.duplicateDirectConversationIds.map((id) => ({ id })),
        );
      }
      if (sql.includes('SELECT 1 FROM conversation_members')) {
        return response([{}]);
      }
      return response([]);
    },
    query: async () => response([]),
    getConnection: async () => makeConnection(),
  };

  let resolveListening;
  const listening = new Promise((resolve) => {
    resolveListening = resolve;
  });

  Module._load = function (requestName, parent, isMain) {
    if (parent?.filename === serverFile && requestName === 'dotenv') {
      return { config: () => ({}) };
    }
    if (parent?.filename === serverFile && requestName === './db') return fakePool;
    if (parent?.filename === serverFile && requestName === './mailer') {
      return {
        sendPasswordResetCode: async (_email, code) => sentResetCodes.push(code),
        sendVerificationCode: async (_email, code) => sentVerificationCodes.push(code),
      };
    }
    return originalLoad.call(this, requestName, parent, isMain);
  };
  express.application.listen = function () {
    server = originalListen.call(this, 0, resolveListening);
    return server;
  };

  try {
    require(serverFile);
    await listening;
  } finally {
    Module._load = originalLoad;
    express.application.listen = originalListen;
  }
});

beforeEach(() => resetDatabase());

after(async () => {
  if (server) {
    await new Promise((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
  if (originalJwtSecret === undefined) delete process.env.JWT_SECRET;
  else process.env.JWT_SECRET = originalJwtSecret;
  if (originalPaymongoSecret === undefined) delete process.env.PAYMONGO_SECRET_KEY;
  else process.env.PAYMONGO_SECRET_KEY = originalPaymongoSecret;
  if (originalPaymongoWebhookSecret === undefined) {
    delete process.env.PAYMONGO_WEBHOOK_SECRET;
  } else {
    process.env.PAYMONGO_WEBHOOK_SECRET = originalPaymongoWebhookSecret;
  }
});

test('venue QR codes create one verified customer booking check-in', async () => {
  const codeResponse = await request(
    '/api/merchant/businesses/7/check-in-code',
    { role: 'merchant' },
  );
  assert.equal(codeResponse.status, 200);
  const codeBody = await codeResponse.json();
  const qrCode = JSON.parse(codeBody.qrCode);
  assert.equal(qrCode.type, 'tinkerpro.checkin');
  assert.equal(qrCode.venueId, 7);
  assert.ok(codeBody.expiresAt > Date.now());

  const unknownVenueResponse = await request(
    '/api/merchant/businesses/999/check-in-code',
    { role: 'merchant' },
  );
  assert.equal(unknownVenueResponse.status, 404);

  const bookingTime = bookingStartAfterHours(0);
  db.checkInBookings = [{
    bookingId: 501,
    customerId: 42,
    venueId: 7,
    date: bookingTime.bookingDate,
    startTime: bookingTime.startTime,
    durationHours: 2,
    venueName: 'Test Court',
  }];
  const firstCheckIn = await request('/api/bookings/check-in', {
    method: 'POST',
    body: { qrCode: codeBody.qrCode },
  });
  assert.equal(firstCheckIn.status, 201);
  const firstBody = await firstCheckIn.json();
  assert.equal(firstBody.checkIn.bookingId, 501);
  assert.equal(firstBody.checkIn.venueName, 'Test Court');
  assert.equal(firstBody.alreadyCheckedIn, false);
  assert.equal(db.checkIns.size, 1);

  const repeatCheckIn = await request('/api/bookings/check-in', {
    method: 'POST',
    body: { qrCode: codeBody.qrCode },
  });
  assert.equal(repeatCheckIn.status, 200);
  assert.equal((await repeatCheckIn.json()).alreadyCheckedIn, true);
  assert.equal(db.checkIns.size, 1);

  const noBooking = await request('/api/bookings/check-in', {
    method: 'POST',
    role: 'customer',
    id: '43',
    body: { qrCode: codeBody.qrCode },
  });
  assert.equal(noBooking.status, 409);

  const alteredCode = JSON.stringify({ ...qrCode, venueId: 8 });
  const forgedCheckIn = await request('/api/bookings/check-in', {
    method: 'POST',
    body: { qrCode: alteredCode },
  });
  assert.equal(forgedCheckIn.status, 400);
});

test('booking rejects malformed input without opening a transaction', async () => {
  const response = await request('/api/bookings', {
    method: 'POST',
    body: {
      venueId: 7,
      date: 'not-a-date',
      startTime: '25:00',
      durationHours: 1,
      players: 2,
      paymentMethod: 'online',
    },
  });

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    error: 'Choose Online payment or Cash on Arrival (COA).',
  });
  assert.equal(db.calls.filter(({ sql }) => sql.includes('FOR UPDATE')).length, 0);
});

test('mutating API routes reject non-object JSON bodies', async () => {
  const response = await request('/api/auth/register', {
    method: 'POST',
    body: ['player@example.test', 'Password123'],
  });

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    error: 'The request body must be a JSON object.',
  });
  assert.equal(
    db.calls.some(({ sql }) => sql.includes('FROM users WHERE email = ?')),
    false,
  );
});

test('profile routes reject invalid field types before database writes', async () => {
  const response = await request('/api/auth/profile', {
    method: 'PUT',
    body: { firstName: { value: 'Taylor' } },
  });

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    error: 'One or more profile fields are invalid.',
  });
  assert.equal(db.calls.length, 0);
});

test('conversation routes reject malformed identifiers without querying', async () => {
  const response = await request('/api/messages/conversations/12abc');

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    error: 'The conversation is invalid.',
  });
  assert.equal(db.calls.length, 0);
});

test('deleting a conversation is per-user and new messages restore it for both members', async () => {
  const deleted = await request('/api/messages/conversations/601', {
    method: 'DELETE',
  });

  assert.equal(deleted.status, 200);
  const deleteUpdate = db.calls.find(({ sql }) =>
    sql.includes('UPDATE conversation_members SET deleted_at = CURRENT_TIMESTAMP'),
  );
  assert.ok(deleteUpdate);
  assert.match(deleteUpdate.sql, /conversation_id = \? AND user_id = \?/);
  assert.deepEqual(deleteUpdate.params, [601, '42']);

  db.calls = [];
  const sent = await request('/api/messages/conversations/601', {
    method: 'POST',
    role: 'merchant',
    id: '88',
    body: { body: 'Your booking is confirmed.' },
  });

  assert.equal(sent.status, 201);
  const restoreUpdate = db.calls.find(({ sql }) =>
    sql.includes('UPDATE conversation_members') &&
    sql.includes('SET archived_at = NULL, deleted_at = NULL'),
  );
  assert.ok(restoreUpdate);
  assert.match(restoreUpdate.sql, /WHERE conversation_id = \?/);
  assert.doesNotMatch(restoreUpdate.sql, /AND user_id = \?/);
  assert.deepEqual(restoreUpdate.params, [601]);
  assert.ok(
    db.calls.some(({ sql, params }) =>
      sql.includes('INSERT INTO messages') &&
      params[0] === 601 &&
      params[1] === '88',
    ),
  );
});

test('opening a direct conversation marks its merged duplicate chats as read', async () => {
  db.messageReadScope = {
    type: 'direct',
    archivedAt: null,
    peerId: 84,
  };
  db.duplicateDirectConversationIds = [601, 602];

  const response = await request('/api/messages/conversations/601');

  assert.equal(response.status, 200);
  const unreadUpdate = db.calls.find(({ sql }) =>
    sql.includes('UPDATE conversation_members SET manually_unread_at = NULL'),
  );
  assert.deepEqual(unreadUpdate.params, [601, 602, '42']);
  const readInsert = db.calls.find(({ sql }) =>
    sql.includes('INSERT IGNORE INTO message_reads (message_id, user_id)'),
  );
  assert.deepEqual(readInsert.params, ['42', 601, 602, '42']);
});

test('booking numeric fields reject booleans and blank numeric strings', async () => {
  const response = await request('/api/bookings', {
    method: 'POST',
    body: {
      venueId: true,
      date: '2026-10-01',
      startTime: '09:00',
      durationHours: 1,
      players: 2,
      paymentMethod: 'online',
    },
  });

  assert.equal(response.status, 400);
  assert.equal(
    db.calls.some(({ sql }) => sql.includes('FROM merchant_businesses b JOIN users u')),
    false,
  );
});

test('merchant business payload validation rejects invalid numeric and list types', async () => {
  const response = await request('/api/merchant/businesses', {
    method: 'POST',
    role: 'merchant',
    body: {
      businessType: 'Sports',
      name: 'Court',
      category: 'Basketball',
      address: 'Cebu',
      facilityType: 'Indoor',
      hours: '9 AM - 9 PM',
      pricePerHour: true,
      includedPlayers: 4,
      additionalPlayerFee: 10,
      tags: ['Parking', false],
    },
  });

  assert.equal(response.status, 400);
  const body = await response.json();
  assert.deepEqual(body.validationErrors, ['pricePerHour', 'tags']);
  assert.equal(
    db.calls.some(({ sql }) => sql.includes('INSERT INTO merchant_businesses')),
    false,
  );
});

test('new merchant businesses require at least one venue image', async () => {
  const response = await request('/api/merchant/businesses', {
    method: 'POST',
    role: 'merchant',
    body: {
      businessType: 'Sports',
      name: 'Court',
      category: 'Basketball',
      address: 'Cebu',
      facilityType: 'Indoor',
      hours: '9 AM - 9 PM',
      pricePerHour: 120,
      latitude: 10.3,
      longitude: 123.9,
    },
  });

  assert.equal(response.status, 400);
  assert.match((await response.json()).error, /venue image/);
  assert.equal(
    db.calls.some(({ sql }) => sql.includes('INSERT INTO merchant_businesses')),
    false,
  );
});

test('merchant business edits cannot clear all venue images', async () => {
  const response = await request('/api/merchant/businesses/7', {
    method: 'PUT',
    role: 'merchant',
    body: {
      businessType: 'Sports',
      name: 'Test Court',
      category: 'Basketball',
      address: 'Cebu',
      facilityType: 'Indoor',
      hours: '9 AM - 9 PM',
      pricePerHour: 120,
      latitude: 10.3,
      longitude: 123.9,
      imageUrls: [],
    },
  });

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    error: 'Please check the business details.',
  });
  assert.equal(
    db.calls.some(({ sql }) => sql.includes('UPDATE merchant_businesses') &&
      sql.includes('SET business_type = ?')),
    false,
  );
});

test('merchant business routes deny customers and inactive merchants', async () => {
  const customerResponse = await request('/api/merchant/businesses', {
    role: 'customer',
  });
  assert.equal(customerResponse.status, 403);
  assert.deepEqual(await customerResponse.json(), {
    error: 'Only active merchant accounts can access this endpoint.',
  });

  db.calls = [];
  db.accountStatus = 'suspended';
  const inactiveMerchantResponse = await request('/api/merchant/businesses', {
    role: 'merchant',
  });
  assert.equal(inactiveMerchantResponse.status, 403);
  assert.deepEqual(await inactiveMerchantResponse.json(), {
    error: 'Only active merchant accounts can access this endpoint.',
  });
  assert.equal(
    db.calls.some(({ sql }) => sql.includes('INSERT INTO merchant_businesses')),
    false,
  );
});

test('booking requests require an idempotency key', async () => {
  const response = await request('/api/bookings', {
    method: 'POST',
    idempotencyKey: null,
    body: {
      venueId: 7,
      date: '2026-10-01',
      startTime: '09:00',
      durationHours: 1,
      players: 2,
      paymentMethod: 'online',
    },
  });

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    error: 'A valid Idempotency-Key header is required for booking requests.',
  });
  assert.equal(db.calls.some(({ sql }) => sql.includes('START TRANSACTION')), false);
});

test('booking retries with the same idempotency key return the original result', async () => {
  const key = 'booking-attempt-identifier-0001';
  const body = {
    venueId: 7,
    date: '2026-10-01',
    startTime: '09:00',
    durationHours: 2,
    players: 6,
    paymentMethod: 'online',
  };
  const firstResponse = await request('/api/bookings', {
    method: 'POST',
    idempotencyKey: key,
    body,
  });
  const firstResult = await firstResponse.json();
  const retryResponse = await request('/api/bookings', {
    method: 'POST',
    idempotencyKey: key,
    body,
  });

  assert.equal(firstResponse.status, 201);
  assert.equal(retryResponse.status, 201);
  assert.deepEqual(await retryResponse.json(), firstResult);
  assert.equal(
    db.calls.filter(({ sql }) => sql.includes('INSERT INTO bookings')).length,
    1,
  );
  assert.equal(
    db.calls.filter(({ sql }) => sql.includes('INSERT INTO conversations')).length,
    1,
  );
});

test('booking idempotency keys cannot be reused with different booking details', async () => {
  const key = 'booking-attempt-identifier-0002';
  const body = {
    venueId: 7,
    date: '2026-10-01',
    startTime: '09:00',
    durationHours: 2,
    players: 6,
    paymentMethod: 'online',
  };
  const firstResponse = await request('/api/bookings', {
    method: 'POST',
    idempotencyKey: key,
    body,
  });
  assert.equal(firstResponse.status, 201);

  const changedResponse = await request('/api/bookings', {
    method: 'POST',
    idempotencyKey: key,
    body: {...body, players: 7},
  });

  assert.equal(changedResponse.status, 409);
  assert.deepEqual(await changedResponse.json(), {
    error: 'This Idempotency-Key was already used for a different booking request.',
  });
  assert.equal(
    db.calls.filter(({ sql }) => sql.includes('INSERT INTO bookings')).length,
    1,
  );
});

test('activity log reads are scoped to the authenticated user', async () => {
  const response = await request('/api/activity-logs?userId=88');

  assert.equal(response.status, 200);
  assert.match(response.headers.get('x-request-id'), /^[0-9a-f-]{36}$/i);
  assert.deepEqual(await response.json(), { activities: [] });
  const activityQuery = db.calls.find(({ sql }) =>
    sql.includes('FROM user_activity_logs') && sql.includes('WHERE user_id = ?'),
  );
  assert.ok(activityQuery);
  assert.match(activityQuery.sql, /actor_role AS actorRole/);
  assert.match(activityQuery.sql, /request_id AS requestId/);
  assert.doesNotMatch(activityQuery.sql, /ip_address|user_agent/);
  assert.deepEqual(activityQuery.params, ['42']);
  assert.doesNotMatch(activityQuery.sql, /userId/i);
});

test('known-account failed sign-ins are audited without storing the password', async () => {
  db.loginUser = {
    id: 42,
    email: 'customer@example.test',
    password_hash: await bcrypt.hash('CorrectPassword1!', 4),
    first_name: 'Test',
    last_name: 'Customer',
    role: 'customer',
    status: 'active',
  };
  const response = await request('/api/auth/login', {
    method: 'POST',
    body: {
      email: 'customer@example.test',
      password: 'IncorrectPassword1!',
    },
  });

  assert.equal(response.status, 401);
  const failedLogin = db.calls.find(({ sql, params }) =>
    sql.includes('INSERT INTO user_activity_logs') &&
    params[1] === 'login_failed',
  );
  assert.ok(failedLogin);
  assert.equal(failedLogin.params[8], '42');
  assert.equal(failedLogin.params[9], 'customer');
  assert.equal(failedLogin.params[10], response.headers.get('x-request-id'));
  assert.equal(JSON.stringify(failedLogin.params).includes('IncorrectPassword1!'), false);
});

test('customer conversation filter limits results to the selected business type', async () => {
  const response = await request(
    '/api/messages/conversations?businessType=Fitness%20%26%20Wellness',
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { conversations: [] });
  const conversationQuery = db.calls.find(({ sql }) =>
    sql.includes('FROM conversations c') &&
    sql.includes('JOIN conversation_members cm'),
  );
  assert.ok(conversationQuery);
  assert.match(conversationQuery.sql, /c\.title = CONCAT\('Booking ', b\.id\)/);
  assert.deepEqual(conversationQuery.params, ['42', '42', '42', '42', '42', 'fitness & wellness']);
});

test('customer conversation filter rejects unsupported business types', async () => {
  const response = await request(
    '/api/messages/conversations?businessType=unsupported',
  );

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    error: 'Invalid business type filter.',
  });
  assert.equal(
    db.calls.filter(({ sql }) =>
      sql.includes('FROM conversations c') &&
      sql.includes('JOIN conversation_members cm'),
    ).length,
    0,
  );
});

test('typed inbox cannot read or send in another business type conversation', async () => {
  const read = await request(
    '/api/messages/conversations/601?businessType=Fitness',
  );
  assert.equal(read.status, 404);
  assert.deepEqual(await read.json(), { error: 'Conversation not found.' });

  const send = await request('/api/messages/conversations/601', {
    method: 'POST',
    body: { body: 'Hello', businessType: 'Event' },
  });
  assert.equal(send.status, 404);
  assert.deepEqual(await send.json(), { error: 'Conversation not found.' });

  const scopedQueries = db.calls.filter(({ sql }) =>
    sql.includes("JOIN bookings b ON c.title = CONCAT('Booking ', b.id)") &&
    sql.includes('cm.deleted_at IS NULL'),
  );
  assert.deepEqual(scopedQueries.map(({ params }) => params[2]), [
    'fitness & wellness',
    'event',
  ]);
});

test('customer booking responses include fitness class details', async () => {
  db.customerBookings = [{
    id: 901,
    businessType: 'Fitness & Wellness',
    venueName: 'Studio Flow',
    classCapacity: 18,
    sessionDurationMinutes: 45,
    instructorName: 'Alex',
    classSchedule: 'Weekdays',
    checkedInAt: '2026-10-09T10:30:00',
    eventTypes: null,
    accessibilityNeeds: null,
    parkingNeeds: null,
    securityNeeds: null,
    ratePeriods: null,
    amenities: null,
    imageUrls: null,
    imageUrl: null,
  }];

  const response = await request('/api/bookings?businessType=Fitness');

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.bookings[0].businessType, 'Fitness & Wellness');
  assert.equal(body.bookings[0].classCapacity, 18);
  assert.equal(body.bookings[0].sessionDurationMinutes, 45);
  assert.equal(body.bookings[0].instructorName, 'Alex');
  assert.equal(body.bookings[0].classSchedule, 'Weekdays');
  assert.equal(body.bookings[0].checkedInAt, '2026-10-09T10:30:00');
  const bookingQuery = db.calls.find(({ sql }) =>
    sql.includes('FROM bookings b') &&
    sql.includes('LEFT JOIN fitness_business_details') &&
    sql.includes('LEFT JOIN booking_check_ins'),
  );
  assert.ok(bookingQuery);
  assert.match(bookingQuery.sql, /LOWER\(v\.business_type\) = \?/);
  assert.deepEqual(bookingQuery.params, ['42', 'fitness & wellness']);
});

test('customer booking business type filter rejects unsupported values', async () => {
  const response = await request('/api/bookings?businessType=unknown');

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    error: 'Invalid business type filter.',
  });
  assert.equal(
    db.calls.some(({ sql }) => sql.includes('LEFT JOIN fitness_business_details')),
    false,
  );
});

test('fitness businesses persist category plans and optional coaches', async () => {
  const response = await request('/api/merchant/businesses', {
    role: 'merchant',
    method: 'POST',
    body: {
      businessType: 'Fitness & Wellness',
      name: 'Studio Flow',
      category: 'Pilates',
      address: 'Cebu City',
      facilityType: 'Studio',
      hours: '8:00 AM - 8:00 PM',
      pricePerHour: 500,
      imageUrls: ['https://example.test/studio.jpg'],
      latitude: 10.3,
      longitude: 123.9,
      fitnessCategories: [{
        category: 'Pilates',
        sessionPrice: 500,
        monthlyPrice: 4000,
        yearlyPrice: 40000,
        yearlyDiscountType: 'freeMonths',
        yearlyDiscountValue: 2,
      }, {
        category: 'Yoga',
        sessionPrice: 450,
        monthlyPrice: 3500,
        yearlyPrice: 35000,
        yearlyDiscountType: 'percentage',
        yearlyDiscountValue: 10,
      }],
      fitnessCoaches: [{
        name: 'Jamie Coach',
        monthlyPrice: 6500,
        profileImageUrl: null,
      }, {
        name: 'Alex Trainer',
        monthlyPrice: 7200,
        profileImageUrl: 'https://example.test/coach.png',
      }],
    },
  });

  assert.equal(response.status, 201);
  const saveQuery = db.calls.find(({ sql }) =>
    sql.includes('INSERT INTO fitness_business_details'),
  );
  assert.ok(saveQuery);
  assert.deepEqual(JSON.parse(saveQuery.params[1]), [{
    category: 'Pilates',
    sessionPrice: 500,
    monthlyPrice: 4000,
    yearlyPrice: 40000,
    yearlyDiscountType: 'freeMonths',
    yearlyDiscountValue: 2,
  }, {
    category: 'Yoga',
    sessionPrice: 450,
    monthlyPrice: 3500,
    yearlyPrice: 35000,
    yearlyDiscountType: 'percentage',
    yearlyDiscountValue: 10,
  }]);
  assert.deepEqual(JSON.parse(saveQuery.params[2]), [{
    name: 'Jamie Coach',
    monthlyPrice: 6500,
    profileImageUrl: null,
  }, {
    name: 'Alex Trainer',
    monthlyPrice: 7200,
    profileImageUrl: 'https://example.test/coach.png',
  }]);
  const businessActivity = db.calls.find(({ sql, params }) =>
    sql.includes('INSERT INTO user_activity_logs') &&
    params[1] === 'business_created',
  );
  assert.ok(businessActivity);
  assert.equal(businessActivity.params[8], '88');
  assert.equal(businessActivity.params[9], 'merchant');
  assert.equal(businessActivity.params[10], response.headers.get('x-request-id'));
  assert.deepEqual(JSON.parse(businessActivity.params[7]), {
    businessId: 702,
    businessType: 'Fitness & Wellness',
  });
});

test('fitness businesses reject invalid annual discounts and coach pricing', async () => {
  const response = await request('/api/merchant/businesses', {
    role: 'merchant',
    method: 'POST',
    body: {
      businessType: 'Fitness & Wellness',
      name: 'Studio Flow',
      category: 'Pilates',
      address: 'Cebu City',
      facilityType: 'Studio',
      hours: '8:00 AM - 8:00 PM',
      pricePerHour: 500,
      latitude: 10.3,
      longitude: 123.9,
      fitnessCategories: [{
        category: 'Pilates',
        sessionPrice: 500,
        monthlyPrice: 4000,
        yearlyPrice: 40000,
        yearlyDiscountType: 'freeMonths',
        yearlyDiscountValue: 12,
      }],
      fitnessCoaches: [{
        name: 'Jamie Coach',
        monthlyPrice: 0,
      }],
    },
  });

  assert.equal(response.status, 400);
  assert.match((await response.json()).error, /fitness category pricing and coach settings/);
  assert.equal(
    db.calls.some(({ sql }) => sql.includes('INSERT INTO merchant_businesses')),
    false,
  );
});

test('venue heart updates validate the venue and remain scoped to the user', async () => {
  const response = await request('/api/businesses/7/heart', {
    method: 'PUT',
  });

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    heartCount: 0,
    heartedByMe: true,
  });
  const heartInsert = db.calls.find(({ sql }) =>
    sql.includes('INSERT IGNORE INTO venue_hearts'),
  );
  assert.ok(heartInsert);
  assert.deepEqual(heartInsert.params, [7, '42']);
  const countQuery = db.calls.find(({ sql }) =>
    sql.includes('SELECT COUNT(*) AS heartCount FROM venue_hearts'),
  );
  assert.ok(countQuery);
  assert.deepEqual(countQuery.params, [7]);
});

test('customers can read only their own venue hearts', async () => {
  db.customerHeartedBusinessRows = [{ businessId: 7 }, { businessId: 92 }];

  const response = await request('/api/customer/venue-hearts');

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    businesses: [{ businessId: 7 }, { businessId: 92 }],
  });
  const query = db.calls.find(({ sql }) =>
    sql.includes('FROM venue_hearts WHERE user_id = ?'),
  );
  assert.ok(query);
  assert.deepEqual(query.params, ['42']);
});

test('customer feed reports aggregate hearts and the authenticated user heart state', async () => {
  const response = await request('/api/news-feed');

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { posts: [] });
  const feedQuery = db.calls.find(({ sql }) =>
    sql.includes('heart_count') && sql.includes('hearted_by_me'),
  );
  assert.ok(feedQuery);
  assert.deepEqual(feedQuery.params, ['42']);
});

test('customer feed can restrict results to one booking type', async () => {
  const response = await request('/api/news-feed?businessType=Fitness');

  assert.equal(response.status, 200);
  const feedQuery = db.calls.find(({ sql }) =>
    sql.includes('heart_count') && sql.includes('hearted_by_me'),
  );
  assert.ok(feedQuery);
  assert.match(feedQuery.sql, /LOWER\(b\.business_type\) = \?/);
  assert.deepEqual(feedQuery.params, ['42', 'fitness & wellness']);
});

test('customer feed rejects unsupported booking type filters', async () => {
  const response = await request('/api/news-feed?businessType=Unknown');

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    error: 'Invalid business type filter.',
  });
  assert.equal(
    db.calls.some(({ sql }) => sql.includes('FROM merchant_news n')),
    false,
  );
});

test('customer feed includes merchant-configured event types', async () => {
  db.newsFeedRows = [{
    id: 15,
    business_id: 7,
    business_type: 'Event',
    business_category: 'Garden',
    event_types_json: '["Wedding","Birthday"]',
    image_url: 'https://example.test/venue-one.jpg',
    business_image_url: 'https://example.test/venue-one.jpg',
    image_urls: '["https://example.test/venue-one.jpg","https://example.test/venue-two.jpg"]',
  }];

  const response = await request('/api/news-feed');

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.deepEqual(body.posts[0].eventTypes, ['Wedding', 'Birthday']);
  assert.deepEqual(body.posts[0].imageUrls, [
    'https://example.test/venue-one.jpg',
    'https://example.test/venue-two.jpg',
  ]);
  const feedQuery = db.calls.find(({ sql }) =>
    sql.includes('FROM merchant_news n'),
  );
  assert.ok(feedQuery);
  assert.match(feedQuery.sql, /event_types_json/);
  assert.match(feedQuery.sql, /latest\.status = 'published'/);
});

test('creating a News Card repeatedly updates one record per business', async () => {
  db.newsWriteResults = [
    { insertId: 500, affectedRows: 1 },
    { insertId: 500, affectedRows: 2 },
  ];
  const payload = {
    businessId: 7,
    title: 'Test Court update',
    body: 'New court hours.',
    status: 'published',
  };

  const first = await request('/api/merchant/news-posts', {
    method: 'POST',
    role: 'merchant',
    body: payload,
  });
  const second = await request('/api/merchant/news-posts', {
    method: 'POST',
    role: 'merchant',
    body: payload,
  });

  assert.equal(first.status, 201);
  assert.equal(second.status, 200);
  assert.equal((await first.json()).id, 500);
  assert.equal((await second.json()).id, 500);
  const writes = db.calls.filter(({ sql }) => sql.includes('INSERT INTO merchant_news'));
  assert.equal(writes.length, 2);
  assert.ok(writes.every(({ sql }) => sql.includes('ON DUPLICATE KEY UPDATE')));
  assert.ok(writes.every(({ params }) => params[3] === db.venue.image_url));
});

test('News Card creation requires the Booking Card image', async () => {
  db.venue.image_url = null;
  const response = await request('/api/merchant/news-posts', {
    method: 'POST',
    role: 'merchant',
    body: {
      businessId: 7,
      title: 'Test Court update',
      body: 'New court hours.',
      imageUrl: 'https://example.test/news-only-image.jpg',
      status: 'published',
    },
  });

  assert.equal(response.status, 400);
  assert.match((await response.json()).error, /Booking Card/);
  assert.equal(
    db.calls.some(({ sql }) => sql.includes('INSERT INTO merchant_news')),
    false,
  );
});

test('customer businesses include Event venues without published news, including disabled ones', async () => {
  db.customerBusinessRows = [{
    id: 92,
    businessType: 'Event',
    name: 'Garden Event Place',
    category: 'Garden',
    ownerName: 'Maya Santos',
    ownerEmail: 'maya@example.test',
    ownerPhone: '+639171234567',
    ownerAvatarUrl: 'https://example.test/maya.jpg',
    eventTypes: '["Wedding","Birthday"]',
    enabled: 0,
    heartCount: 0,
  }];

  const response = await request('/api/businesses');

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.deepEqual(body.businesses[0].eventTypes, ['Wedding', 'Birthday']);
  assert.equal(body.businesses[0].ownerName, 'Maya Santos');
  assert.equal(body.businesses[0].ownerEmail, 'maya@example.test');
  assert.equal(body.businesses[0].ownerPhone, '+639171234567');
  assert.equal(
    body.businesses[0].ownerAvatarUrl,
    'https://example.test/maya.jpg',
  );
  assert.equal(body.businesses[0].enabled, 0);
  const businessesQuery = db.calls.find(({ sql }) =>
    sql.includes('LEFT JOIN event_business_details e') &&
    sql.includes('ORDER BY b.created_at DESC'),
  );
  assert.ok(businessesQuery);
  assert.match(
    businessesQuery.sql,
    /WHERE \(b\.enabled = 1 OR b\.business_type = 'Event'\)\s+AND u\.status = 'active'/,
  );
  assert.match(businessesQuery.sql, /b\.business_type = 'Event'\s+OR EXISTS/);
  assert.match(businessesQuery.sql, /AS heartCount/);
});

test('event venue review records its booking and venue details in activity history', async () => {
  db.reviewEligibleBookings = [{
    id: 180,
    venueId: 92,
    venueName: 'Garden Event Place',
    sportType: 'Wedding',
    bookingDate: '2026-09-28',
    startTime: '10:00:00',
  }];

  const response = await request('/api/news-feed/92/reviews', {
    method: 'POST',
    body: { rating: 5, comment: 'Wonderful event venue.' },
  });

  assert.equal(response.status, 201);
  const bookingQuery = db.calls.find(({ sql }) =>
    sql.includes('LEFT JOIN venue_reviews r ON r.booking_id = b.id') &&
    sql.includes('b.venue_id = ?'),
  );
  assert.ok(bookingQuery);
  assert.match(bookingQuery.sql, /b\.venue_id AS venueId/);
  assert.match(bookingQuery.sql, /v\.name AS venueName/);
  assert.deepEqual(bookingQuery.params, [92, '42']);
  const activity = db.calls.find(({ sql, params }) =>
    sql.includes('INSERT INTO user_activity_logs') &&
    params.includes('Garden Event Place'),
  );
  assert.ok(activity);
});

test('customer business catalog is cached and invalidated after merchant changes', async () => {
  db.customerBusinessRows = [{
    id: 92,
    businessType: 'Sports',
    name: 'First Court',
    eventTypes: null,
    enabled: 1,
  }];

  const first = await request('/api/businesses');
  assert.equal(first.status, 200);
  assert.equal((await first.json()).businesses[0].name, 'First Court');

  db.customerBusinessRows[0].name = 'Updated Court';
  const cached = await request('/api/businesses');
  assert.equal(cached.status, 200);
  assert.equal((await cached.json()).businesses[0].name, 'First Court');
  const catalogQueryCount = () => db.calls.filter(({ sql }) =>
    sql.includes('LEFT JOIN event_business_details e') &&
    sql.includes('ORDER BY b.created_at DESC'),
  ).length;
  assert.equal(catalogQueryCount(), 1);

  const update = await request('/api/merchant/businesses/92/status', {
    method: 'PUT',
    role: 'merchant',
    body: { enabled: false },
  });
  assert.equal(update.status, 200);

  const refreshed = await request('/api/businesses');
  assert.equal(refreshed.status, 200);
  assert.equal((await refreshed.json()).businesses[0].name, 'Updated Court');
  assert.equal(catalogQueryCount(), 2);

  const imageUrl = 'data:image/jpeg;base64,dGVzdA==';
  const imageUpdate = await request('/api/merchant/businesses/92/images', {
    method: 'PUT',
    role: 'merchant',
    body: { imageUrls: [imageUrl, 'https://example.test/other.jpg'] },
  });
  assert.equal(imageUpdate.status, 200);
  const imageUpdateQuery = db.calls.find(({ sql }) =>
    sql.includes('SET image_url = ?, image_urls = ?'),
  );
  assert.deepEqual(imageUpdateQuery.params, [
    imageUrl,
    JSON.stringify([imageUrl, 'https://example.test/other.jpg']),
    92,
    '88',
  ]);
  const refreshedAfterImageUpdate = await request('/api/businesses');
  assert.equal(refreshedAfterImageUpdate.status, 200);
  assert.equal(catalogQueryCount(), 3);
});

test('merchant business image update validates image lists', async () => {
  db.calls = [];
  const response = await request('/api/merchant/businesses/92/images', {
    method: 'PUT',
    role: 'merchant',
    body: { imageUrls: [] },
  });

  assert.equal(response.status, 400);
  assert.equal(
    db.calls.some(({ sql }) => sql.includes('SET image_url = ?, image_urls = ?')),
    false,
  );
});

test('availability returns bookings and validates its required inputs', async () => {
  db.availabilityRows = [{ startTime: '09:00:00', durationHours: 1 }];
  const response = await request('/api/bookings/availability?venueId=7&date=2026-10-01');
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { bookings: db.availabilityRows });

  const invalid = await request('/api/bookings/availability?venueId=0&date=bad');
  assert.equal(invalid.status, 400);
  assert.equal(db.calls.filter(({ sql }) => sql.includes('SELECT start_time AS startTime')).length, 1);
});

test('availability database failures return the generic server error', async () => {
  db.availabilityError = new Error('simulated database failure');
  const originalConsoleError = console.error;
  let loggedError;
  console.error = (...args) => { loggedError = args; };
  try {
    const response = await request('/api/bookings/availability?venueId=7&date=2026-10-01');
    const requestId = response.headers.get('x-request-id');
    assert.equal(response.status, 500);
    assert.deepEqual(await response.json(), { error: 'An unexpected server error occurred.' });
    assert.equal(loggedError[0], 'API request failed.');
    assert.equal(loggedError[1].requestId, requestId);
    assert.equal(loggedError[1].error, db.availabilityError);
  } finally {
    console.error = originalConsoleError;
  }
});

test('booking rejects an occupied interval and does not persist a booking', async () => {
  db.overlap = true;
  const response = await request('/api/bookings', {
    method: 'POST',
    body: {
      venueId: 7,
      date: '2026-10-01',
      startTime: '09:00',
      durationHours: 2,
      players: 6,
      paymentMethod: 'cash_on_arrival',
    },
  });

  assert.equal(response.status, 409);
  assert.deepEqual(await response.json(), {
    error: 'That sport slot is already booked for the selected time.',
  });
  assert.ok(db.calls.some(({ sql }) => sql.includes('FROM bookings') && sql.includes('AND start_time <')));
  assert.equal(db.calls.some(({ sql }) => sql.includes('INSERT INTO bookings')), false);
});

test('booking success calculates add-on charges and downpayment', async () => {
  const response = await request('/api/bookings', {
    method: 'POST',
    headers: { 'user-agent': 'LifecycleAuditTest/1.0' },
    body: {
      venueId: 7,
      date: '2026-10-01',
      startTime: '09:00',
      durationHours: 2,
      players: 6,
      paymentMethod: 'online',
    },
  });

  assert.equal(response.status, 201);
  const { booking } = await response.json();
  assert.equal(booking.total, 270);
  assert.equal(booking.downpayment, 270);
  assert.equal(booking.extraPlayers, 2);
  assert.equal(booking.extraPlayerCharge, 30);
  assert.equal(booking.status, 'pending');
  assert.equal(booking.transactionId, 'TP-TXN-00000601');
  assert.equal(typeof booking.bookingToken, 'string');
  assert.match(response.headers.get('x-request-id'), /^[0-9a-f-]{36}$/i);
  assert.ok(db.calls.some(({ sql }) => sql.includes('INSERT INTO bookings')));
  const bookingInsert = db.calls.find(({ sql }) =>
    sql.includes('INSERT INTO bookings'),
  );
  assert.equal(bookingInsert.params[22], 'unpaid');
  const activityInsert = db.calls.find(({ sql }) =>
    sql.includes('INSERT INTO user_activity_logs'),
  );
  assert.ok(activityInsert);
  assert.equal(activityInsert.params[4], 7);
  assert.equal(activityInsert.params[5], 'Test Court');
  assert.equal(activityInsert.params[6], 'Basketball');
  assert.deepEqual(JSON.parse(activityInsert.params[7]), {
    bookingId: 601,
    bookingDate: '2026-10-01',
    startTime: '09:00',
    durationHours: 2,
    players: 6,
    businessType: 'Sports',
    eventType: null,
    paymentMethod: 'online',
    total: 270,
    downpayment: 270,
  });
  assert.equal(activityInsert.params[8], '42');
  assert.equal(activityInsert.params[9], 'customer');
  assert.equal(activityInsert.params[10], response.headers.get('x-request-id'));
  assert.ok(activityInsert.params[11]);
  assert.equal(activityInsert.params[12], 'LifecycleAuditTest/1.0');
});

test('Event booking validates event type and guest capacity and charges the event fee once', async () => {
  db.venue.businessType = 'Event';
  db.venue.eventFee = 10000;

  const response = await request('/api/bookings', {
    method: 'POST',
    body: {
      venueId: 7,
      date: '2026-10-01',
      startTime: '09:00',
      durationHours: 4,
      players: 120,
      paymentMethod: 'cash_on_arrival',
      eventType: 'Wedding',
    },
  });

  assert.equal(response.status, 201);
  const { booking } = await response.json();
  assert.equal(booking.businessType, 'Event');
  assert.equal(booking.eventType, 'Wedding');
  assert.equal(booking.total, 10000);
  assert.equal(booking.downpayment, 5000);
  const insert = db.calls.find(({ sql }) => sql.includes('INSERT INTO bookings'));
  assert.ok(insert.sql.includes('event_type'));
  assert.equal(insert.params[14], 'Wedding');
  const requestMessage = db.calls.find(({ sql }) =>
    sql.includes('INSERT INTO messages') && sql.includes('attachment_json'),
  );
  assert.ok(requestMessage);
  const ticket = JSON.parse(requestMessage.params[3]);
  assert.equal(ticket.businessType, 'Event');
  assert.equal(ticket.eventType, 'Wedding');
  assert.equal(ticket.players, 120);
});

test('Event booking rejects event types and guest counts outside venue configuration', async () => {
  db.venue.businessType = 'Event';
  db.venue.eventFee = 10000;
  const invalidType = await request('/api/bookings', {
    method: 'POST',
    body: {
      venueId: 7,
      date: '2026-10-01',
      startTime: '09:00',
      durationHours: 4,
      players: 120,
      paymentMethod: 'cash_on_arrival',
      eventType: 'Concert',
    },
  });
  assert.equal(invalidType.status, 400);
  assert.equal(
    db.calls.some(({ sql }) => sql.includes('INSERT INTO bookings')),
    false,
  );

  const invalidCapacity = await request('/api/bookings', {
    method: 'POST',
    body: {
      venueId: 7,
      date: '2026-10-01',
      startTime: '09:00',
      durationHours: 4,
      players: 251,
      paymentMethod: 'cash_on_arrival',
      eventType: 'Wedding',
    },
  });
  assert.equal(invalidCapacity.status, 400);
  assert.equal(
    db.calls.some(({ sql }) => sql.includes('INSERT INTO bookings')),
    false,
  );

  db.overlap = true;
  const overlappingBooking = await request('/api/bookings', {
    method: 'POST',
    body: {
      venueId: 7,
      date: '2026-10-01',
      startTime: '09:00',
      durationHours: 4,
      players: 120,
      paymentMethod: 'cash_on_arrival',
      eventType: 'Wedding',
    },
  });
  assert.equal(overlappingBooking.status, 409);
  assert.equal(
    db.calls.some(({ sql }) => sql.includes('INSERT INTO bookings')),
    false,
  );
});

test('Fitness bookings price coach duration from the requested month count', async () => {
  db.venue.businessType = 'Fitness & Wellness';
  const response = await request('/api/bookings', {
    method: 'POST',
    body: {
      venueId: 7,
      date: '2026-10-01',
      startTime: '09:00',
      durationHours: 1,
      players: 1,
      paymentMethod: 'online',
      sportType: 'Yoga',
      fitnessPlanType: 'yearly',
      fitnessCoachName: 'Alex Coach',
      fitnessCoachDurationMonths: 3,
    },
  });

  assert.equal(response.status, 201);
  const { booking } = await response.json();
  assert.equal(booking.fitnessCategory, 'Yoga');
  assert.equal(booking.fitnessPlanType, 'yearly');
  assert.equal(booking.fitnessPlanPrice, 9600);
  assert.equal(booking.fitnessCoachPrice, 900);
  assert.equal(booking.fitnessCoachDurationMonths, 3);
  assert.equal(booking.total, 10500);
  assert.equal(booking.downpayment, 10500);
  const insert = db.calls.find(({ sql }) => sql.includes('INSERT INTO bookings'));
  assert.ok(insert.sql.includes('fitness_plan_type'));
  assert.equal(insert.params[15], 'yearly');
  assert.equal(insert.params[16], 'Yoga');
  assert.equal(insert.params[17], 'Alex Coach');
  assert.equal(insert.params[20], 3);
});

test('Fitness cash-on-arrival bookings require half the plan total upfront', async () => {
  db.venue.businessType = 'Fitness & Wellness';
  const response = await request('/api/bookings', {
    method: 'POST',
    body: {
      venueId: 7,
      date: '2026-10-01',
      startTime: '09:00',
      durationHours: 1,
      players: 1,
      paymentMethod: 'cash_on_arrival',
      sportType: 'Yoga',
      fitnessPlanType: 'monthly',
      fitnessCoachName: 'Alex Coach',
      fitnessCoachDurationMonths: 1,
    },
  });

  assert.equal(response.status, 201);
  const { booking } = await response.json();
  assert.equal(booking.total, 1500);
  assert.equal(booking.downpayment, 750);
});

test('Fitness bookings reject coach durations shorter than one month', async () => {
  db.venue.businessType = 'Fitness & Wellness';
  const response = await request('/api/bookings', {
    method: 'POST',
    body: {
      venueId: 7,
      date: '2026-10-01',
      startTime: '09:00',
      durationHours: 1,
      players: 1,
      paymentMethod: 'online',
      sportType: 'Yoga',
      fitnessPlanType: 'monthly',
      fitnessCoachName: 'Alex Coach',
      fitnessCoachDurationMonths: 0,
    },
  });

  assert.equal(response.status, 400);
  assert.equal(
    db.calls.some(({ sql }) => sql.includes('INSERT INTO bookings')),
    false,
  );
});

test('customers can read, record, and clear attendance for fitness bookings', async () => {
  const loaded = await request('/api/bookings/501/attendance');
  assert.equal(loaded.status, 200);
  assert.deepEqual(await loaded.json(), {
    attendance: [{ date: '2026-09-09', status: 'present' }],
  });

  const marked = await request('/api/bookings/501/attendance/2026-10-01', {
    method: 'PUT',
    body: { status: 'absent' },
  });
  assert.equal(marked.status, 200);
  assert.deepEqual(await marked.json(), {
    attendance: { date: '2026-10-01', status: 'absent' },
  });
  const insert = db.calls.find(({ sql }) =>
    sql.includes('INSERT INTO fitness_booking_attendance'),
  );
  assert.deepEqual(insert.params, [501, '42', '2026-10-01', 'absent']);

  const cleared = await request('/api/bookings/501/attendance/2026-10-01', {
    method: 'DELETE',
  });
  assert.equal(cleared.status, 200);
  assert.deepEqual(await cleared.json(), { message: 'Attendance cleared.' });
});

test('attendance rejects invalid dates, out-of-period dates, and future presence', async () => {
  const invalidDate = await request('/api/bookings/501/attendance/2026-02-30', {
    method: 'PUT',
    body: { status: 'absent' },
  });
  assert.equal(invalidDate.status, 400);

  const outOfPeriod = await request('/api/bookings/501/attendance/2026-10-09', {
    method: 'PUT',
    body: { status: 'absent' },
  });
  assert.equal(outOfPeriod.status, 400);

  const today = new Date().toISOString().slice(0, 10);
  attendanceBooking.bookingDate = today;
  const tomorrow = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
  const futurePresent = await request(
    `/api/bookings/501/attendance/${tomorrow}`,
    {
      method: 'PUT',
      body: { status: 'present' },
    },
  );
  assert.equal(futurePresent.status, 400);
  assert.equal(
    db.calls.some(({ sql, params }) =>
      sql.includes('INSERT INTO fitness_booking_attendance') &&
      params[3] === 'present',
    ),
    false,
  );
});

test('attendance rejects dates omitted from the merchant available days', async () => {
  const closedSunday = await request(
    '/api/bookings/501/attendance/2026-09-13',
    {
      method: 'PUT',
      body: { status: 'absent' },
    },
  );
  assert.equal(closedSunday.status, 400);
  assert.deepEqual(await closedSunday.json(), {
    error: 'The fitness venue is closed on this day.',
  });
  assert.equal(
    db.calls.some(({ sql, params }) =>
      sql.includes('INSERT INTO fitness_booking_attendance') &&
      params[2] === '2026-09-13',
    ),
    false,
  );
});

test('attendance is unavailable for bookings outside the customer fitness plan', async () => {
  attendanceBooking.businessType = 'Sports';
  const otherBusiness = await request('/api/bookings/501/attendance');
  assert.equal(otherBusiness.status, 404);

  attendanceBooking.businessType = 'Fitness & Wellness';
  const otherCustomer = await fetch(
    `http://127.0.0.1:${server.address().port}/api/bookings/501/attendance`,
    {
      headers: {
        authorization: `Bearer ${bearer('customer', '99')}`,
      },
    },
  );
  assert.equal(otherCustomer.status, 404);
});

test('Fitness booking rejects a category or coach not configured by the venue', async () => {
  db.venue.businessType = 'Fitness & Wellness';
  const invalidCategory = await request('/api/bookings', {
    method: 'POST',
    body: {
      venueId: 7,
      date: '2026-10-01',
      startTime: '09:00',
      durationHours: 1,
      players: 1,
      paymentMethod: 'cash_on_arrival',
      sportType: 'Unlisted class',
      fitnessPlanType: 'monthly',
    },
  });
  assert.equal(invalidCategory.status, 400);
  assert.equal(db.calls.some(({ sql }) => sql.includes('INSERT INTO bookings')), false);

  const invalidCoach = await request('/api/bookings', {
    method: 'POST',
    body: {
      venueId: 7,
      date: '2026-10-01',
      startTime: '09:00',
      durationHours: 1,
      players: 1,
      paymentMethod: 'cash_on_arrival',
      sportType: 'Yoga',
      fitnessPlanType: 'monthly',
      fitnessCoachName: 'Not our coach',
    },
  });
  assert.equal(invalidCoach.status, 400);
  assert.equal(db.calls.some(({ sql }) => sql.includes('INSERT INTO bookings')), false);
});

test('Fitness first visits cannot be used to reserve extra hours or attendees', async () => {
  db.venue.businessType = 'Fitness & Wellness';
  const response = await request('/api/bookings', {
    method: 'POST',
    body: {
      venueId: 7,
      date: '2026-10-01',
      startTime: '09:00',
      durationHours: 3,
      players: 1,
      paymentMethod: 'cash_on_arrival',
      sportType: 'Yoga',
      fitnessPlanType: 'session',
    },
  });
  assert.equal(response.status, 400);
  assert.equal(db.calls.some(({ sql }) => sql.includes('INSERT INTO bookings')), false);
});

test('bookings on separate small slots can overlap and use the selected sport rate', async () => {
  db.overlapRows = [{ slotNumber: 1, occupiesFullStudio: 0 }];
  const response = await request('/api/bookings', {
    method: 'POST',
    body: {
      venueId: 7,
      date: '2026-10-01',
      startTime: '09:00',
      durationHours: 2,
      players: 5,
      paymentMethod: 'cash_on_arrival',
      sportType: 'Badminton',
      slotNumber: 2,
    },
  });

  assert.equal(response.status, 201);
  const { booking } = await response.json();
  assert.equal(booking.sportType, 'Badminton');
  assert.equal(booking.slotNumber, 2);
  assert.equal(booking.pricePerHour, 90);
  assert.equal(booking.extraPlayerCharge, 15);
  assert.equal(booking.includedPlayers, 2);
  assert.equal(booking.additionalPlayerFee, 5);
  assert.equal(booking.total, 195);
});

test('two overlapping bookings cannot use the same small slot', async () => {
  db.overlapRows = [{ slotNumber: 2, occupiesFullStudio: 0 }];
  const response = await request('/api/bookings', {
    method: 'POST',
    body: {
      venueId: 7,
      date: '2026-10-01',
      startTime: '09:00',
      durationHours: 1,
      players: 2,
      paymentMethod: 'cash_on_arrival',
      sportType: 'Badminton',
      slotNumber: 2,
    },
  });

  assert.equal(response.status, 409);
  assert.equal(db.calls.some(({ sql }) => sql.includes('INSERT INTO bookings')), false);
});

test('whole-studio bookings conflict with an occupied small slot', async () => {
  db.overlapRows = [{ slotNumber: 2, occupiesFullStudio: 0 }];
  const response = await request('/api/bookings', {
    method: 'POST',
    body: {
      venueId: 7,
      date: '2026-10-01',
      startTime: '09:00',
      durationHours: 2,
      players: 4,
      paymentMethod: 'cash_on_arrival',
      sportType: 'Basketball',
    },
  });

  assert.equal(response.status, 409);
});

test('merchant approval issues a booking ticket', async () => {
  const response = await request('/api/merchant/bookings/501/approve', {
    method: 'PATCH',
    role: 'merchant',
  });

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.status, 'approved');
  assert.equal(body.message, 'Booking approved and ticket issued.');
  assert.equal(typeof body.ticketCode, 'string');
  assert.equal(body.transactionId, 'TP-TXN-00000501');
  const ticketMessage = db.calls.find(({ sql }) =>
    sql.includes('INSERT INTO messages') && sql.includes('attachment_json'),
  );
  assert.ok(ticketMessage);
  const ticket = JSON.parse(ticketMessage.params[3]);
  assert.equal(ticket.transactionId, body.transactionId);
  assert.equal(ticket.ticketCode, body.ticketCode);
  const approvalUpdate = db.calls.find(({ sql }) =>
    sql.includes("SET b.status = 'approved'"),
  );
  assert.ok(approvalUpdate);
  assert.match(
    approvalUpdate.sql,
    /\(b\.payment_method = 'online' AND b\.payment_status = 'paid'\)/,
  );
  assert.match(
    approvalUpdate.sql,
    /OR b\.payment_method = 'cash_on_arrival'/,
  );
});

test('separate booking transactions receive separate ticket codes', async () => {
  const firstResponse = await request('/api/merchant/bookings/501/approve', {
    method: 'PATCH',
    role: 'merchant',
  });
  const secondResponse = await request('/api/merchant/bookings/502/approve', {
    method: 'PATCH',
    role: 'merchant',
  });

  assert.equal(firstResponse.status, 200);
  assert.equal(secondResponse.status, 200);
  const first = await firstResponse.json();
  const second = await secondResponse.json();
  assert.equal(first.transactionId, 'TP-TXN-00000501');
  assert.equal(second.transactionId, 'TP-TXN-00000502');
  assert.notEqual(first.ticketCode, second.ticketCode);

  const ticketMessages = db.calls
    .filter(({ sql }) =>
      sql.includes('INSERT INTO messages') && sql.includes('attachment_json'),
    )
    .map(({ params }) => JSON.parse(params[3]));
  assert.deepEqual(
    ticketMessages.map((ticket) => ticket.transactionId),
    [first.transactionId, second.transactionId],
  );
  assert.deepEqual(
    ticketMessages.map((ticket) => ticket.ticketCode),
    [first.ticketCode, second.ticketCode],
  );
});

test('merchant approval rejects bookings outside the pending state', async () => {
  db.transitionAffected = false;
  const response = await request('/api/merchant/bookings/501/approve', {
    method: 'PATCH',
    role: 'merchant',
  });

  assert.equal(response.status, 404);
  assert.deepEqual(await response.json(), { error: 'Pending booking not found.' });
});

test('merchant can decline a pending booking', async () => {
  const response = await request('/api/merchant/bookings/501/decline', {
    method: 'PATCH',
    role: 'merchant',
  });

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    message: 'Booking declined.',
    status: 'cancelled',
  });
  const declineUpdate = db.calls.find(({ sql }) =>
    sql.includes("SET b.status = 'cancelled'"),
  );
  assert.ok(declineUpdate);
  assert.match(declineUpdate.sql, /v\.merchant_id = \?/);
  assert.match(declineUpdate.sql, /b\.status = 'pending'/);
});

test('merchant can permanently delete only their completed booking', async () => {
  const deleted = await request('/api/merchant/bookings/501', {
    method: 'DELETE',
    role: 'merchant',
  });

  assert.equal(deleted.status, 200);
  assert.deepEqual(await deleted.json(), {
    message: 'Completed booking permanently deleted.',
  });
  const deleteQuery = db.calls.find(({ sql }) =>
    sql.includes('DELETE b FROM bookings b'),
  );
  assert.ok(deleteQuery);
  assert.match(deleteQuery.sql, /v\.merchant_id = \?/);
  assert.match(deleteQuery.sql, /b\.status = 'finished'/);
  assert.deepEqual(deleteQuery.params, ['501', '88']);

  db.deleteAffected = false;
  const notCompleted = await request('/api/merchant/bookings/501', {
    method: 'DELETE',
    role: 'merchant',
  });
  assert.equal(notCompleted.status, 404);
  assert.deepEqual(await notCompleted.json(), {
    error: 'Completed booking not found.',
  });
});

test('customer can permanently delete only their own completed booking', async () => {
  const deleted = await request('/api/bookings/501', {
    method: 'DELETE',
    role: 'customer',
  });
  assert.equal(deleted.status, 200);
  assert.deepEqual(await deleted.json(), {
    message: 'Completed booking permanently deleted.',
  });
  const deleteQuery = db.calls.find(({ sql }) =>
    sql.includes('DELETE FROM bookings'),
  );
  assert.ok(deleteQuery);
  assert.match(deleteQuery.sql, /customer_id = \?/);
  assert.match(deleteQuery.sql, /status = 'finished'/);
  assert.deepEqual(deleteQuery.params, ['501', '42']);

  db.deleteAffected = false;
  const notCompleted = await request('/api/bookings/501', {
    method: 'DELETE',
    role: 'customer',
  });
  assert.equal(notCompleted.status, 404);
  assert.deepEqual(await notCompleted.json(), {
    error: 'Completed booking not found.',
  });
});

test('customer cancellation refunds online payments only at least six hours before start', async () => {
  const previousSecret = process.env.PAYMONGO_SECRET_KEY;
  const originalFetchImpl = global.fetch;
  process.env.PAYMONGO_SECRET_KEY = 'test-secret';
  const refundRequests = [];
  global.fetch = async (url, options) => {
    if (String(url) === 'https://api.paymongo.com/v1/refunds') {
      refundRequests.push({ url, options });
      return new Response(
        JSON.stringify({
          data: { id: 'ref_test_501', attributes: { status: 'succeeded' } },
        }),
        { status: 200, headers: { 'content-type': 'application/json' } },
      );
    }
    return originalFetchImpl(url, options);
  };
  try {
    db.cancellationBooking = {
      id: 501,
      ...bookingStartAfterHours(8),
      paymentMethod: 'online',
      paymentStatus: 'paid',
      paidAmount: 270,
      paymentReference: 'pay_test_501',
      checkoutSessionId: 'cs_test_501',
      status: 'approved',
    };
    const eligible = await request('/api/bookings/501/cancel', {
      method: 'PATCH',
      role: 'customer',
    });
    assert.equal(eligible.status, 200);
    assert.deepEqual(await eligible.json(), {
      message: 'Booking cancelled. The online payment refund was completed.',
      status: 'cancelled',
      paymentRefundStatus: 'succeeded',
    });
    assert.equal(refundRequests.length, 1);
    assert.deepEqual(JSON.parse(refundRequests[0].options.body), {
      data: {
        attributes: {
          amount: 27000,
          payment_id: 'pay_test_501',
          reason: 'others',
          notes: 'Customer cancelled booking 501.',
        },
      },
    });
    assert.equal(
      refundRequests[0].options.headers['Idempotency-Key'],
      'booking-cancellation-refund-501',
    );
    assert.equal(db.cancellationBooking.paymentStatus, 'paid');
    assert.equal(db.cancellationBooking.paidAmount, 270);

    db.cancellationBooking = {
      id: 502,
      ...bookingStartAfterHours(5),
      paymentMethod: 'online',
      paymentStatus: 'paid',
      paidAmount: 270,
      paymentReference: 'pay_test_502',
      status: 'approved',
    };
    const insideWindow = await request('/api/bookings/502/cancel', {
      method: 'PATCH',
      role: 'customer',
    });
    assert.equal(insideWindow.status, 200);
    assert.deepEqual(await insideWindow.json(), {
      message:
        'Booking cancelled. It is within 6 hours of the start time or has started, so the online payment was not refunded.',
      status: 'cancelled',
      paymentRefundStatus: 'not_eligible',
    });
    assert.equal(refundRequests.length, 1);
    assert.equal(db.cancellationBooking.paymentStatus, 'paid');
    assert.equal(db.cancellationBooking.paidAmount, 270);

    db.cancellationBooking = {
      id: 503,
      ...bookingStartAfterHours(24),
      paymentMethod: 'cash_on_arrival',
      paymentStatus: 'partial',
      paidAmount: 135,
      status: 'approved',
    };
    const cash = await request('/api/bookings/503/cancel', {
      method: 'PATCH',
      role: 'customer',
    });
    assert.equal(cash.status, 200);
    assert.equal((await cash.json()).paymentRefundStatus, 'manual_cash_return');
    assert.equal(refundRequests.length, 1);

    db.cancellationBooking = null;
    const completed = await request('/api/bookings/501/cancel', {
      method: 'PATCH',
      role: 'customer',
    });
    assert.equal(completed.status, 404);
    assert.deepEqual(await completed.json(), {
      error: 'Booking not found or can no longer be cancelled.',
    });
  } finally {
    global.fetch = originalFetchImpl;
    if (previousSecret === undefined) delete process.env.PAYMONGO_SECRET_KEY;
    else process.env.PAYMONGO_SECRET_KEY = previousSecret;
  }
});

test('merchant payment management records COA cash downpayment before balance', async () => {
  const downpayment = await request('/api/merchant/bookings/501/payment', {
    method: 'PATCH',
    role: 'merchant',
    body: { paymentStatus: 'partial' },
  });
  assert.equal(downpayment.status, 200);
  assert.deepEqual(await downpayment.json(), {
    message: 'Payment status updated.',
    paymentStatus: 'partial',
  });
  const downpaymentUpdate = db.calls.find(({ sql }) =>
    sql.includes("SET b.payment_status = 'partial'"),
  );
  assert.ok(downpaymentUpdate);
  assert.match(downpaymentUpdate.sql, /b\.payment_method = 'cash_on_arrival'/);
  assert.match(downpaymentUpdate.sql, /b\.paid_amount = b\.downpayment_amount/);
  assert.match(downpaymentUpdate.sql, /b\.payment_status = 'unpaid'/);

  const paid = await request('/api/merchant/bookings/501/payment', {
    method: 'PATCH',
    role: 'merchant',
    body: { paymentStatus: 'paid' },
  });
  assert.equal(paid.status, 200);
  assert.deepEqual(await paid.json(), {
    message: 'Payment status updated.',
    paymentStatus: 'paid',
  });
  const balanceUpdate = db.calls.find(({ sql }) =>
    sql.includes("SET b.payment_status = 'paid'"),
  );
  assert.ok(balanceUpdate);
  assert.match(balanceUpdate.sql, /b\.payment_status = 'partial'/);
  assert.match(balanceUpdate.sql, /b\.paid_amount = b\.total_amount/);

  const invalid = await request('/api/merchant/bookings/501/payment', {
    method: 'PATCH',
    role: 'merchant',
    body: { paymentStatus: 'unpaid' },
  });
  assert.equal(invalid.status, 400);
  assert.deepEqual(await invalid.json(), {
    error: 'Record the cash downpayment first, then the remaining balance.',
  });
});

test('merchant booking refresh automatically completes bookings at type-specific end dates', async () => {
  db.dueBookings = [
    {
      id: 501,
      customerId: 42,
      merchantId: 88,
      venueId: 7,
      venueName: 'Test Court',
      bookingDate: '2026-10-01',
      startTime: '09:00:00',
      durationHours: 2,
      sportType: 'Basketball',
    },
  ];

  const response = await request('/api/merchant/bookings', { role: 'merchant' });

  assert.equal(response.status, 200);
  const completionQuery = db.calls.find(({ sql }) =>
    sql.includes("WHERE b.status = 'approved'") &&
    sql.includes('CURRENT_DATE >= DATE_ADD(b.booking_date'),
  );
  assert.ok(completionQuery);
  assert.match(completionQuery.sql, /INTERVAL 1 MONTH/);
  assert.match(completionQuery.sql, /INTERVAL 1 YEAR/);
  assert.match(completionQuery.sql, /ROUND\(b\.duration_hours \* 60\)/);
  assert.match(completionQuery.sql, /f\.session_duration_minutes/);
  assert.equal(
    db.calls.filter(({ sql }) => sql.includes('INSERT INTO user_activity_logs')).length,
    2,
  );
});

test('merchant can finish approved bookings and gets not found for other states', async () => {
  const finished = await request('/api/merchant/bookings/501/finish', {
    method: 'PATCH',
    role: 'merchant',
  });
  assert.equal(finished.status, 200);
  assert.deepEqual(await finished.json(), {
    message: 'Booking marked finished.',
    status: 'finished',
  });

  db.transitionAffected = false;
  const missing = await request('/api/merchant/bookings/501/finish', {
    method: 'PATCH',
    role: 'merchant',
  });
  assert.equal(missing.status, 404);
  assert.deepEqual(await missing.json(), { error: 'Approved booking not found.' });
});

test('registration validates credentials and creates a pending account', async () => {
  const invalid = await request('/api/auth/register', {
    method: 'POST',
    body: { email: 'person@example.test', password: 'short' },
  });
  assert.equal(invalid.status, 400);

  const registered = await request('/api/auth/register', {
    method: 'POST',
    body: {
      email: ' Person@Example.Test ',
      password: 'correct-horse-battery',
      firstName: ' Taylor ',
      lastName: ' User ',
    },
  });
  assert.equal(registered.status, 201);
  const body = await registered.json();
  assert.equal(body.user.email, 'person@example.test');
  assert.equal(body.user.firstName, 'Taylor');
  assert.equal(body.user.status, 'pending');
  assert.equal(sentVerificationCodes.length, 1);
  assert.ok(db.calls.some(({ sql }) => sql.includes('INSERT INTO email_verification_tokens')));
});

test('email verification rejects a wrong code and activates the account for a match', async () => {
  db.verificationToken = {
    token_id: 13,
    token_hash: hashVerificationCode('123456'),
    id: 71,
    email: 'person@example.test',
    first_name: 'Taylor',
    last_name: 'User',
    role: 'customer',
  };
  const invalid = await request('/api/auth/verify-email', {
    method: 'POST',
    body: { email: 'person@example.test', code: '000000' },
  });
  assert.equal(invalid.status, 400);

  const verified = await request('/api/auth/verify-email', {
    method: 'POST',
    body: { email: 'person@example.test', code: '123456' },
  });
  assert.equal(verified.status, 200);
  const body = await verified.json();
  assert.equal(body.user.status, 'active');
  assert.equal(typeof body.token, 'string');
  assert.ok(db.calls.some(({ sql }) => sql.includes('UPDATE email_verification_tokens')));
});

test('password reset handles unknown accounts and accepts only a valid reset token', async () => {
  const missing = await request('/api/auth/forgot-password', {
    method: 'POST',
    body: { email: 'missing@example.test' },
  });
  assert.equal(missing.status, 200);
  const missingBody = await missing.json();
  assert.deepEqual(missingBody, {
    message: 'If an account exists for this email, a password reset code was sent.',
  });

  db.resetUser = { id: 71 };
  const requested = await request('/api/auth/forgot-password', {
    method: 'POST',
    body: { email: 'person@example.test' },
  });
  assert.equal(requested.status, 200);
  assert.deepEqual(await requested.json(), missingBody);
  assert.equal(sentResetCodes.length, 1);

  db.resetToken = {
    token_id: 29,
    token_hash: hashVerificationCode('654321'),
    user_id: 71,
  };
  const invalid = await request('/api/auth/reset-password', {
    method: 'POST',
    body: { email: 'person@example.test', code: '111111', password: 'new-password' },
  });
  assert.equal(invalid.status, 400);

  const reset = await request('/api/auth/reset-password', {
    method: 'POST',
    body: { email: 'person@example.test', code: '654321', password: 'new-password' },
  });
  assert.equal(reset.status, 200);
  assert.deepEqual(await reset.json(), {
    message: 'Your password has been changed. You can now sign in.',
  });
  assert.ok(db.calls.some(({ sql }) => sql.includes('UPDATE password_reset_tokens')));
});

test('password reset code verification requires a matching token', async () => {
  db.resetToken = { token_hash: hashVerificationCode('654321') };
  const invalid = await request('/api/auth/verify-password-reset-code', {
    method: 'POST',
    body: { email: 'person@example.test', code: '111111' },
  });
  assert.equal(invalid.status, 400);

  const valid = await request('/api/auth/verify-password-reset-code', {
    method: 'POST',
    body: { email: 'person@example.test', code: '654321' },
  });
  assert.equal(valid.status, 200);
  assert.deepEqual(await valid.json(), { message: 'Verification code accepted.' });
});

test('password recovery throttles repeated attempts by email', async () => {
  const email = `throttled.${Date.now()}@example.test`;
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const response = await request('/api/auth/verify-password-reset-code', {
      method: 'POST',
      body: { email, code: '111111' },
    });
    assert.equal(response.status, 400);
  }

  const limited = await request('/api/auth/verify-password-reset-code', {
    method: 'POST',
    body: { email, code: '111111' },
  });
  assert.equal(limited.status, 429);
  assert.ok(Number(limited.headers.get('retry-after')) > 0);
  assert.equal(limited.headers.get('ratelimit-remaining'), '0');
});

test('payment checkout validates method and reports missing configuration', async () => {
  const originalConfig = [
    'PAYMONGO_SECRET_KEY',
    'PAYMONGO_WEBHOOK_SECRET',
    'PAYMONGO_SUCCESS_URL',
    'PAYMONGO_CANCEL_URL',
  ].map((key) => [key, process.env[key]]);
  for (const [key] of originalConfig) delete process.env[key];
  let externalFetchCalled = false;
  const originalFetchImpl = global.fetch;
  global.fetch = async (url, ...args) => {
    if (String(url).startsWith('https://api.paymongo.com/')) {
      externalFetchCalled = true;
    }
    return originalFetchImpl(url, ...args);
  };
  try {
    const invalid = await request('/api/payments/paymongo/checkout', {
      method: 'POST',
      body: { bookingId: 501, paymentMethod: 'cash_on_arrival' },
    });
    assert.equal(invalid.status, 400);

    const unavailable = await request('/api/payments/paymongo/checkout', {
      method: 'POST',
      body: { bookingId: 501, paymentMethod: 'gcash' },
    });
    assert.equal(unavailable.status, 503);
    assert.match(
      (await unavailable.json()).error,
      /not fully configured/,
    );
    assert.equal(externalFetchCalled, false);
  } finally {
    global.fetch = originalFetchImpl;
    for (const [key, value] of originalConfig) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});

test('payment configuration endpoint reports readiness without exposing secrets', async () => {
  const originalConfig = [
    'PAYMONGO_SECRET_KEY',
    'PAYMONGO_WEBHOOK_SECRET',
    'PAYMONGO_SUCCESS_URL',
    'PAYMONGO_CANCEL_URL',
  ].map((key) => [key, process.env[key]]);
  try {
    for (const [key] of originalConfig) delete process.env[key];
    const unavailable = await request('/api/payments/paymongo/config');
    assert.equal(unavailable.status, 200);
    assert.deepEqual(await unavailable.json(), { onlinePaymentsEnabled: false });

    process.env.PAYMONGO_SECRET_KEY = 'test-secret';
    process.env.PAYMONGO_WEBHOOK_SECRET = 'test-webhook-secret';
    process.env.PAYMONGO_SUCCESS_URL = 'https://example.test/payment-success';
    process.env.PAYMONGO_CANCEL_URL = 'https://example.test/payment-cancelled';
    const ready = await request('/api/payments/paymongo/config');
    assert.equal(ready.status, 200);
    assert.deepEqual(await ready.json(), { onlinePaymentsEnabled: true });
  } finally {
    for (const [key, value] of originalConfig) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});

test('payment checkout creates a provider session for a customer booking', async () => {
  const originalConfig = [
    'PAYMONGO_SECRET_KEY',
    'PAYMONGO_WEBHOOK_SECRET',
    'PAYMONGO_SUCCESS_URL',
    'PAYMONGO_CANCEL_URL',
  ].map((key) => [key, process.env[key]]);
  const originalFetchImpl = global.fetch;
  process.env.PAYMONGO_SECRET_KEY = 'test-secret';
  process.env.PAYMONGO_WEBHOOK_SECRET = 'test-webhook-secret';
  process.env.PAYMONGO_SUCCESS_URL = 'https://example.test/payment-success';
  process.env.PAYMONGO_CANCEL_URL = 'https://example.test/payment-cancelled';
  let providerRequest;
  global.fetch = async (url, options) => {
    if (!String(url).startsWith('https://api.paymongo.com/')) {
      return originalFetchImpl(url, options);
    }
    providerRequest = { url, options };
    return {
      ok: true,
      json: async () => ({
        data: {
          id: 'cs_test_501',
          attributes: { checkout_url: 'https://checkout.example.test/session' },
        },
      }),
    };
  };
  try {
    const response = await request('/api/payments/paymongo/checkout', {
      method: 'POST',
      body: { bookingId: 501, paymentMethod: 'gcash' },
    });
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      checkoutUrl: 'https://checkout.example.test/session',
    });
    assert.equal(providerRequest.url, 'https://api.paymongo.com/v1/checkout_sessions');
    assert.equal(providerRequest.options.method, 'POST');
    const payload = JSON.parse(providerRequest.options.body);
    assert.equal(payload.data.attributes.line_items[0].amount, 27000);
    assert.deepEqual(payload.data.attributes.payment_method_types, ['gcash']);
    assert.deepEqual(payload.data.attributes.metadata, {
      booking_id: '501',
      transaction_id: 'TP-TXN-00000501',
      payment_type: 'full',
    });
    assert.equal(payload.data.attributes.reference_number, 'TP-TXN-00000501');
    assert.ok(db.calls.some(({ sql, params }) =>
      sql.includes('SET payment_checkout_session_id = ?') &&
      params[0] === 'cs_test_501',
    ));

    paymentBooking = {
      ...paymentBooking,
      paymentMethod: 'cash_on_arrival',
      paymentStatus: 'unpaid',
      paidAmount: 0,
    };
    const downpaymentResponse = await request(
      '/api/payments/paymongo/checkout',
      {
        method: 'POST',
        body: {
          bookingId: 501,
          paymentMethod: 'gcash',
          paymentType: 'downpayment',
        },
      },
    );
    assert.equal(downpaymentResponse.status, 400);
  } finally {
    global.fetch = originalFetchImpl;
    for (const [key, value] of originalConfig) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});

test('payment checkout reports provider and missing-booking failures', async () => {
  const originalConfig = [
    'PAYMONGO_SECRET_KEY',
    'PAYMONGO_WEBHOOK_SECRET',
    'PAYMONGO_SUCCESS_URL',
    'PAYMONGO_CANCEL_URL',
  ].map((key) => [key, process.env[key]]);
  const originalFetchImpl = global.fetch;
  process.env.PAYMONGO_SECRET_KEY = 'test-secret';
  process.env.PAYMONGO_WEBHOOK_SECRET = 'test-webhook-secret';
  process.env.PAYMONGO_SUCCESS_URL = 'https://example.test/payment-success';
  process.env.PAYMONGO_CANCEL_URL = 'https://example.test/payment-cancelled';
  global.fetch = async (url, options) => {
    if (!String(url).startsWith('https://api.paymongo.com/')) {
      return originalFetchImpl(url, options);
    }
    return {
      ok: false,
      json: async () => ({ errors: [{ detail: 'Payment provider rejected checkout.' }] }),
    };
  };
  try {
    const providerError = await request('/api/payments/paymongo/checkout', {
      method: 'POST',
      body: { bookingId: 501, paymentMethod: 'paymaya' },
    });
    assert.equal(providerError.status, 502);
    assert.deepEqual(await providerError.json(), {
      error: 'Payment provider rejected checkout.',
    });

    paymentBooking = null;
    const notFound = await request('/api/payments/paymongo/checkout', {
      method: 'POST',
      body: { bookingId: 999, paymentMethod: 'paymaya' },
    });
    assert.equal(notFound.status, 404);
  } finally {
    global.fetch = originalFetchImpl;
    for (const [key, value] of originalConfig) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});

test('verified PayMongo payment adds one pending-approval ticket to booking chat', async () => {
  const originalSecret = process.env.PAYMONGO_WEBHOOK_SECRET;
  const originalPaymongoSecret = process.env.PAYMONGO_SECRET_KEY;
  const originalFetchImpl = global.fetch;
  process.env.PAYMONGO_WEBHOOK_SECRET = 'test-webhook-secret';
  process.env.PAYMONGO_SECRET_KEY = 'test-secret';
  const refundRequests = [];
  global.fetch = async (url, options) => {
    if (String(url) === 'https://api.paymongo.com/v1/refunds') {
      refundRequests.push({ url, options });
      return new Response(
        JSON.stringify({
          data: { id: 'ref_test_late', attributes: { status: 'succeeded' } },
        }),
        { status: 200, headers: { 'content-type': 'application/json' } },
      );
    }
    return originalFetchImpl(url, options);
  };
  db.webhookBooking = {
    id: 501,
    customerId: 42,
    venueId: 7,
    bookingDate: '2026-10-01',
    startTime: '09:00:00',
    durationHours: 2,
    players: 6,
    totalAmount: 270,
    downpaymentAmount: 270,
    paidAmount: 0,
    paymentMethod: 'online',
    paymentStatus: 'unpaid',
    status: 'pending',
    venueName: 'Test Court',
    sportType: 'Basketball',
    businessType: 'Sports',
    merchantId: 88,
    paymentCheckoutSessionId: 'cs_test_501',
  };
  const payload = {
    data: {
      type: 'checkout_session.payment.paid',
      livemode: false,
      data: {
        id: 'cs_test_501',
        attributes: {
          reference_number: 'BOOKING-501',
          metadata: { booking_id: '501', payment_type: 'full' },
          payments: [
            {
              id: 'pay_test_501',
              attributes: { amount: 27000, currency: 'PHP', status: 'paid' },
            },
          ],
        },
      },
    },
  };
  const body = JSON.stringify(payload);
  const timestamp = '1790650000';
  const signature = crypto
    .createHmac('sha256', process.env.PAYMONGO_WEBHOOK_SECRET)
    .update(`${timestamp}.${body}`)
    .digest('hex');
  try {
    const response = await request('/api/payments/paymongo/webhook', {
      method: 'POST',
      headers: {
        'paymongo-signature': `t=${timestamp},te=${signature},li=`,
      },
      body: payload,
    });
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      received: true,
      bookingId: 501,
      transactionId: 'TP-TXN-00000501',
    });
    const ticketMessage = db.calls.find(({ sql }) =>
      sql.includes('INSERT INTO messages') && sql.includes('attachment_json'),
    );
    assert.ok(ticketMessage);
    assert.equal(ticketMessage.params[1], 88);
    const ticket = JSON.parse(ticketMessage.params[3]);
    assert.equal(ticket.type, 'booking_payment_ticket');
    assert.equal(ticket.transactionId, 'TP-TXN-00000501');
    assert.equal(ticket.businessType, 'Sports');
    assert.equal(ticket.status, 'payment_received');
    assert.equal(ticket.approvalStatus, 'pending');
    assert.equal(ticket.venueName, 'Test Court');
    assert.equal(ticket.sportType, 'Basketball');
    assert.equal(ticket.amount, 270);

    db.webhookBooking.paymentStatus = 'paid';
    db.webhookBooking.paidAmount = 270;
    const duplicate = await request('/api/payments/paymongo/webhook', {
      method: 'POST',
      headers: {
        'paymongo-signature': `t=${timestamp},te=${signature},li=`,
      },
      body: payload,
    });
    assert.deepEqual(await duplicate.json(), {
      received: true,
      duplicate: true,
      bookingId: 501,
      transactionId: 'TP-TXN-00000501',
    });
    assert.equal(
      db.calls.filter(({ sql }) =>
        sql.includes('INSERT INTO messages') && sql.includes('attachment_json'),
      ).length,
      1,
    );

    db.webhookBooking = {
      ...db.webhookBooking,
      paymentStatus: 'unpaid',
      paidAmount: 0,
      status: 'cancelled',
      paymentRefundStatus: 'pending',
      paymentCheckoutSessionId: 'cs_test_cancelled',
    };
    const cancelledPayload = {
      ...payload,
      data: {
        ...payload.data,
        data: {
          ...payload.data.data,
          id: 'cs_test_cancelled',
          attributes: {
            ...payload.data.data.attributes,
            payments: [
              {
                id: 'pay_test_cancelled',
                attributes: {
                  amount: 27000,
                  currency: 'PHP',
                  status: 'paid',
                },
              },
            ],
          },
        },
      },
    };
    const cancelledBody = JSON.stringify(cancelledPayload);
    const cancelledSignature = crypto
      .createHmac('sha256', process.env.PAYMONGO_WEBHOOK_SECRET)
      .update(`${timestamp}.${cancelledBody}`)
      .digest('hex');
    const latePayment = await request('/api/payments/paymongo/webhook', {
      method: 'POST',
      headers: {
        'paymongo-signature': `t=${timestamp},te=${cancelledSignature},li=`,
      },
      body: cancelledPayload,
    });
    assert.equal(latePayment.status, 200);
    assert.deepEqual(await latePayment.json(), {
      received: true,
      bookingId: 501,
      transactionId: 'TP-TXN-00000501',
      paymentRefundStatus: 'succeeded',
    });
    assert.equal(refundRequests.length, 1);
    assert.equal(db.webhookBooking.paymentRefundStatus, 'succeeded');
    assert.equal(db.webhookBooking.paymentRefundId, 'ref_test_late');
    db.webhookBooking.paymentStatus = 'paid';
    db.webhookBooking.paidAmount = 270;
    const duplicateLatePayment = await request('/api/payments/paymongo/webhook', {
      method: 'POST',
      headers: {
        'paymongo-signature': `t=${timestamp},te=${cancelledSignature},li=`,
      },
      body: cancelledPayload,
    });
    assert.deepEqual(await duplicateLatePayment.json(), {
      received: true,
      duplicate: true,
      bookingId: 501,
      transactionId: 'TP-TXN-00000501',
      paymentRefundStatus: 'succeeded',
    });
    assert.equal(refundRequests.length, 1);
    const cancelledTicketMessage = db.calls
      .filter(({ sql }) =>
        sql.includes('INSERT INTO messages') && sql.includes('attachment_json'),
      )
      .at(-1);
    assert.ok(cancelledTicketMessage);
    const cancelledTicket = JSON.parse(cancelledTicketMessage.params[3]);
    assert.equal(cancelledTicket.approvalStatus, 'cancelled');
    assert.match(cancelledTicketMessage.params[2], /refund is being processed separately/);

    db.webhookBooking = {
      ...db.webhookBooking,
      paymentMethod: 'cash_on_arrival',
      paymentStatus: 'unpaid',
      paidAmount: 0,
      downpaymentAmount: 135,
      paymentCheckoutSessionId: 'cs_test_coa_501',
    };
    const coaPayload = structuredClone(payload);
    coaPayload.data.data.id = 'cs_test_coa_501';
    coaPayload.data.data.attributes.metadata.payment_type = 'downpayment';
    coaPayload.data.data.attributes.payments[0].attributes.amount = 13500;
    const coaBody = JSON.stringify(coaPayload);
    const coaSignature = crypto
      .createHmac('sha256', process.env.PAYMONGO_WEBHOOK_SECRET)
      .update(`${timestamp}.${coaBody}`)
      .digest('hex');
    const coaResponse = await request('/api/payments/paymongo/webhook', {
      method: 'POST',
      headers: {
        'paymongo-signature': `t=${timestamp},te=${coaSignature},li=`,
      },
      body: coaPayload,
    });
    assert.equal(coaResponse.status, 409);
    assert.equal(
      db.calls.some(({ sql, params }) =>
        sql.includes('SET payment_status = ?, paid_amount = ?') &&
        params[0] === 'partial',
      ),
      false,
    );
  } finally {
    global.fetch = originalFetchImpl;
    if (originalPaymongoSecret === undefined) delete process.env.PAYMONGO_SECRET_KEY;
    else process.env.PAYMONGO_SECRET_KEY = originalPaymongoSecret;
    if (originalSecret === undefined) delete process.env.PAYMONGO_WEBHOOK_SECRET;
    else process.env.PAYMONGO_WEBHOOK_SECRET = originalSecret;
  }
});

test('PayMongo payment webhook rejects an invalid signature', async () => {
  const originalSecret = process.env.PAYMONGO_WEBHOOK_SECRET;
  process.env.PAYMONGO_WEBHOOK_SECRET = 'test-webhook-secret';
  try {
    const response = await request('/api/payments/paymongo/webhook', {
      method: 'POST',
      headers: { 'paymongo-signature': 't=1,te=invalid,li=' },
      body: { data: { type: 'checkout_session.payment.paid' } },
    });
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), {
      error: 'Invalid payment webhook signature.',
    });
  } finally {
    if (originalSecret === undefined) delete process.env.PAYMONGO_WEBHOOK_SECRET;
    else process.env.PAYMONGO_WEBHOOK_SECRET = originalSecret;
  }
});

test('venue reviews include each reviewer profile image URL', async () => {
  db.venueReviews = [{
    id: 31,
    businessId: 12,
    customerId: 42,
    firstName: 'Maya',
    lastName: 'Player',
    avatarUrl: 'https://images.example.test/maya.png',
    rating: 5,
    comment: 'Great court.',
  }];

  const response = await request('/api/news-feed/12/reviews');
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.reviews[0].avatarUrl, 'https://images.example.test/maya.png');
  assert.ok(db.calls.some(({ sql }) => sql.includes('u.avatar_url AS avatarUrl')));
});

test('JSON output escapes HTML-sensitive characters and prevents MIME sniffing', async () => {
  const originalText = '</script><img src=x onerror=alert(1)> &';
  db.venueReviews = [{
    id: 31,
    businessId: 12,
    customerId: 42,
    firstName: 'Maya',
    lastName: 'Player',
    avatarUrl: null,
    rating: 5,
    comment: originalText,
  }];

  const response = await request('/api/news-feed/12/reviews');
  const rawBody = await response.text();

  assert.equal(response.headers.get('content-type'), 'application/json; charset=utf-8');
  assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
  assert.ok(rawBody.includes('\\u003c/script\\u003e'));
  assert.ok(rawBody.includes('\\u003cimg'));
  assert.ok(rawBody.includes('\\u0026'));
  assert.equal(JSON.parse(rawBody).reviews[0].comment, originalText);
});
