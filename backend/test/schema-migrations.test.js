const assert = require('node:assert/strict');
const { test } = require('node:test');
const { runSchemaMigrations } = require('../src/schema_migrations');

test('applied schema versions are skipped while the migration lock is released', async () => {
  const calls = [];
  let released = false;
  const connection = {
    async execute(sql) {
      calls.push(sql);
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [[{ version: 1 }], []];
      }
      return [[], []];
    },
    release() {
      released = true;
    },
  };
  const pool = {
    async execute(sql) {
      calls.push(sql);
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  assert.ok(calls.some((sql) => sql.includes('CREATE TABLE IF NOT EXISTS schema_migrations')));
  assert.ok(calls.some((sql) => sql.includes('SELECT version FROM schema_migrations')));
  assert.equal(calls.some((sql) => sql.includes('CREATE TABLE IF NOT EXISTS merchant_businesses')), false);
  assert.ok(calls.some((sql) => sql.includes('CREATE TABLE IF NOT EXISTS booking_check_ins')));
  assert.ok(calls.some((sql) => sql.includes('RELEASE_LOCK')));
  assert.equal(released, true);
});

test('migration lock contention aborts before running schema upgrades', async () => {
  const calls = [];
  let released = false;
  const connection = {
    async execute(sql) {
      calls.push(sql);
      return [[{ acquired: 0 }], []];
    },
    release() {
      released = true;
    },
  };
  const pool = {
    async execute(sql) {
      calls.push(sql);
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await assert.rejects(
    runSchemaMigrations(pool),
    /Could not acquire the database migration lock/,
  );

  assert.equal(calls.some((sql) => sql.includes('CREATE TABLE IF NOT EXISTS merchant_businesses')), false);
  assert.equal(released, true);
});

test('ensures older databases add the missing fitness coach duration column before continuing', async () => {
  const calls = [];
  const connection = {
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [[{ version: 1 }], []];
      }
      return [[], []];
    },
    release() {},
  };
  const pool = {
    async execute(sql) {
      calls.push({ sql });
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  assert.ok(calls.some(({ sql }) => sql.includes('ALTER TABLE `bookings` ADD COLUMN `fitness_coach_duration_months`')));
  assert.ok(calls.some(({ sql }) =>
    sql.includes("SET paid_amount = total_amount") &&
    sql.includes("payment_status = 'paid'"),
  ));
  assert.ok(calls.some(({ sql }) =>
    sql.includes("ENUM('unpaid', 'partial', 'paid', 'not_required')"),
  ));
  assert.ok(calls.some(({ sql }) => sql.includes('INSERT INTO schema_migrations (version, name)')));
});
