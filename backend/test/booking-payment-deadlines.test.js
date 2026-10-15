const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  createBookingPaymentDeadlineProcessor,
  paymentExpirationCandidatesSql,
} = require('../src/booking_payment_deadlines');

function createFakePool({ candidates = [], affectedRows = 1 } = {}) {
  const calls = [];
  const pool = {
    execute: async (sql, params = []) => {
      calls.push({ sql, params, kind: 'pool' });
      if (sql === paymentExpirationCandidatesSql) return [candidates, []];
      throw new Error(`Unexpected pool query: ${sql}`);
    },
    getConnection: async () => ({
      beginTransaction: async () => calls.push({ kind: 'begin' }),
      commit: async () => calls.push({ kind: 'commit' }),
      rollback: async () => calls.push({ kind: 'rollback' }),
      release: () => calls.push({ kind: 'release' }),
      execute: async (sql, params = []) => {
        calls.push({ sql, params, kind: 'connection' });
        if (sql.includes("SET status = 'cancelled'")) {
          return [{ affectedRows }, []];
        }
        if (sql.includes('SELECT id FROM conversations')) {
          return [[{ id: 91 }], []];
        }
        if (sql.includes('INSERT INTO messages')) return [{ insertId: 12 }, []];
        throw new Error(`Unexpected connection query: ${sql}`);
      },
    }),
  };
  return { pool, calls };
}

test('payment expiry is limited to approved bookings with an unpaid deadline', () => {
  assert.match(paymentExpirationCandidatesSql, /status = 'approved'/);
  assert.match(paymentExpirationCandidatesSql, /payment_method IN \('online', 'cash_on_arrival'\)/);
  assert.match(paymentExpirationCandidatesSql, /payment_status = 'unpaid'/);
  assert.match(paymentExpirationCandidatesSql, /payment_due_at <= CURRENT_TIMESTAMP/);
  assert.match(paymentExpirationCandidatesSql, /payment_expired_at IS NULL/);
});

test('expires an overdue booking once and notifies both customer and merchant', async () => {
  const { pool, calls } = createFakePool({
    candidates: [
      {
        id: 45,
        customerId: 42,
        merchantId: 88,
        venueId: 7,
        venueName: 'North Gym',
        totalAmount: 500,
        downpaymentAmount: 250,
        paymentMethod: 'online',
        paymentDueAt: '2026-10-15 10:00:00',
      },
    ],
  });
  const activities = [];
  const processDeadlines = createBookingPaymentDeadlineProcessor({
    pool,
    recordUserActivity: async (...args) => activities.push(args),
  });

  await processDeadlines();

  const expire = calls.find(({ sql }) =>
    sql?.includes("SET status = 'cancelled'"),
  );
  assert.ok(expire);
  assert.match(expire.sql, /payment_method IN \('online', 'cash_on_arrival'\)/);
  assert.match(expire.sql, /payment_status = 'unpaid'/);
  assert.match(expire.sql, /payment_due_at <= CURRENT_TIMESTAMP/);
  assert.match(expire.sql, /payment_expired_at IS NULL/);
  assert.doesNotMatch(expire.sql, /payment_refund_status/);
  const message = calls.find(({ sql }) => sql?.includes('INSERT INTO messages'));
  assert.ok(message);
  assert.equal(
    calls.filter(({ sql }) => sql?.includes('UPDATE messages')).length,
    0,
  );
  assert.equal(
    calls.filter(({ sql }) => sql?.includes('INSERT INTO messages')).length,
    1,
  );
  assert.match(
    message.params[2],
    /required amount was not paid within 15 minutes after approval/i,
  );
  assert.match(message.params[2], /TP-TXN-00000045/);
  assert.match(message.params[2], /BK-45/);
  assert.deepEqual(
    activities.map((activity) => [activity[1], activity[2]]),
    [
      [42, 'booking_payment_expired'],
      [88, 'booking_payment_expired'],
    ],
  );
  assert.ok(activities.every((activity) => activity[6].systemGenerated));
  assert.equal(calls.filter(({ kind }) => kind === 'commit').length, 1);
});

test('expired COA booking ticket shows its downpayment amount', async () => {
  const { pool, calls } = createFakePool({
    candidates: [
      {
        id: 47,
        customerId: 42,
        merchantId: 88,
        venueId: 7,
        venueName: 'North Gym',
        totalAmount: 500,
        downpaymentAmount: 250,
        paymentMethod: 'cash_on_arrival',
        paymentDueAt: '2026-10-15 10:00:00',
      },
    ],
  });
  const processDeadlines = createBookingPaymentDeadlineProcessor({
    pool,
    recordUserActivity: async () => {},
  });

  await processDeadlines();

  const ticket = calls.find(({ sql }) => sql?.includes('INSERT INTO messages'));
  assert.ok(ticket);
  const attachment = JSON.parse(ticket.params[3]);
  assert.equal(attachment.paymentMethod, 'cash_on_arrival');
  assert.equal(attachment.payableAmount, 250);
  assert.match(ticket.params[2], /required amount was not paid within 15 minutes/i);
});

test('does not notify when payment or cancellation wins the expiry race', async () => {
  const { pool, calls } = createFakePool({
    candidates: [
      {
        id: 46,
        customerId: 42,
        merchantId: 88,
        venueId: 7,
        venueName: 'North Gym',
        totalAmount: 500,
      },
    ],
    affectedRows: 0,
  });
  const activities = [];
  const processDeadlines = createBookingPaymentDeadlineProcessor({
    pool,
    recordUserActivity: async (...args) => activities.push(args),
  });

  await processDeadlines();

  assert.deepEqual(activities, []);
  assert.equal(calls.filter(({ kind }) => kind === 'rollback').length, 1);
  assert.equal(calls.filter(({ kind }) => kind === 'commit').length, 0);
  assert.equal(
    calls.filter(({ sql }) => sql?.includes('INSERT INTO messages')).length,
    0,
  );
});
