const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  createBookingApprovalDeadlineProcessor,
  expirationCandidatesSql,
  reminderCandidatesSql,
} = require('../src/booking_approval_deadlines');

function createFakePool({
  reminders = [],
  expirations = [],
  reminderAffectedRows = 1,
  expirationAffectedRows = 1,
} = {}) {
  const calls = [];
  const pool = {
    execute: async (sql, params = []) => {
      calls.push({ sql, params, kind: 'pool' });
      if (sql.includes('approval_reminded_at IS NULL')) {
        return [reminders, []];
      }
      if (sql.includes('INTERVAL 15 MINUTE')) {
        return [expirations, []];
      }
      throw new Error(`Unexpected pool query: ${sql}`);
    },
    getConnection: async () => ({
      beginTransaction: async () => calls.push({ kind: 'begin' }),
      commit: async () => calls.push({ kind: 'commit' }),
      rollback: async () => calls.push({ kind: 'rollback' }),
      release: () => calls.push({ kind: 'release' }),
      execute: async (sql, params = []) => {
        calls.push({ sql, params, kind: 'connection' });
        if (sql.includes('SET approval_reminded_at = CURRENT_TIMESTAMP')) {
          return [{ affectedRows: reminderAffectedRows }, []];
        }
        if (sql.includes("SET status = 'cancelled'")) {
          return [{ affectedRows: expirationAffectedRows }, []];
        }
        if (sql.includes("JSON_SET") && sql.includes("'$.status', 'expired'")) {
          return [{ affectedRows: 1 }, []];
        }
        throw new Error(`Unexpected connection query: ${sql}`);
      },
    }),
  };
  return { pool, calls };
}

test('approval reminder and expiry apply to every pending booking', () => {
  assert.match(reminderCandidatesSql, /status = 'pending'/);
  assert.match(reminderCandidatesSql, /INTERVAL 10 MINUTE/);
  assert.match(expirationCandidatesSql, /status = 'pending'/);
  assert.match(expirationCandidatesSql, /INTERVAL 15 MINUTE/);
  assert.doesNotMatch(
    `${reminderCandidatesSql}\n${expirationCandidatesSql}`,
    /payment_method|payment_status|paid_amount/,
  );
});

test('reminds eligible merchants after 10 minutes once per booking', async () => {
  const { pool, calls } = createFakePool({
    reminders: [
      {
        id: 31,
        customerId: 42,
        merchantId: 88,
        venueId: 7,
        venueName: 'North Gym',
        sportType: 'Basketball',
      },
    ],
  });
  const activities = [];
  const processDeadlines = createBookingApprovalDeadlineProcessor({
    pool,
    recordUserActivity: async (...args) => activities.push(args),
  });

  await processDeadlines();

  const claim = calls.find(({ sql }) =>
    sql?.includes('SET approval_reminded_at = CURRENT_TIMESTAMP'),
  );
  assert.ok(claim);
  assert.match(claim.sql, /approval_reminded_at IS NULL/);
  assert.match(claim.sql, /INTERVAL 10 MINUTE/);
  assert.equal(claim.params[0], 31);
  assert.equal(activities.length, 1);
  assert.equal(activities[0][1], 88);
  assert.equal(activities[0][2], 'booking_approval_reminder');
  assert.equal(activities[0][6].systemGenerated, true);
  assert.equal(
    calls.filter(({ kind }) => kind === 'commit').length,
    1,
  );
});

test('expires every overdue request and records both users without changing payment', async () => {
  const { pool, calls } = createFakePool({
    expirations: [
      {
        id: 32,
        customerId: 42,
        merchantId: 88,
        venueId: 7,
        venueName: 'North Gym',
        sportType: 'Basketball',
        paymentMethod: 'online',
        paymentStatus: 'paid',
        paidAmount: 500,
      },
    ],
  });
  const activities = [];
  const processDeadlines = createBookingApprovalDeadlineProcessor({
    pool,
    recordUserActivity: async (...args) => activities.push(args),
  });

  await processDeadlines();

  const cancel = calls.find(({ sql }) =>
    sql?.includes("SET status = 'cancelled'"),
  );
  assert.ok(cancel);
  assert.match(cancel.sql, /status = 'pending'/);
  assert.match(cancel.sql, /INTERVAL 15 MINUTE/);
  assert.doesNotMatch(cancel.sql, /payment_method|payment_status|paid_amount/);
  assert.ok(
    calls.some(({ sql }) =>
      sql?.includes("JSON_SET") && sql.includes("'$.status', 'expired'"),
    ),
  );
  assert.deepEqual(
    activities.map((activity) => [activity[1], activity[2]]),
    [
      [42, 'booking_auto_cancelled'],
      [88, 'booking_auto_cancelled'],
    ],
  );
  const updatedColumns = cancel.sql.split('WHERE')[0];
  assert.doesNotMatch(
    updatedColumns,
    /payment_status|paid_amount|payment_refund_status/,
    'automatic cancellation must not modify payment records',
  );
});

test('does not notify or cancel when another request already changed the booking', async () => {
  const { pool, calls } = createFakePool({
    reminders: [
      {
        id: 33,
        customerId: 42,
        merchantId: 88,
        venueId: 7,
        venueName: 'North Gym',
        sportType: 'Basketball',
      },
    ],
    expirations: [
      {
        id: 34,
        customerId: 42,
        merchantId: 88,
        venueId: 7,
        venueName: 'North Gym',
        sportType: 'Basketball',
      },
    ],
    reminderAffectedRows: 0,
    expirationAffectedRows: 0,
  });
  const activities = [];
  const processDeadlines = createBookingApprovalDeadlineProcessor({
    pool,
    recordUserActivity: async (...args) => activities.push(args),
  });

  await processDeadlines();

  assert.deepEqual(activities, []);
  assert.equal(calls.filter(({ kind }) => kind === 'rollback').length, 2);
  assert.equal(calls.filter(({ kind }) => kind === 'commit').length, 0);
});
