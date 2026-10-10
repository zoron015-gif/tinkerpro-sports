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

test('migration 6 keeps one News Card per business and adds a unique business index', async () => {
  const poolCalls = [];
  const connectionCalls = [];
  const connection = {
    async execute(sql, params) {
      connectionCalls.push({ sql, params });
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [[
          { version: 1 },
          { version: 2 },
          { version: 3 },
          { version: 4 },
          { version: 5 },
        ], []];
      }
      return [[], []];
    },
    release() {},
  };
  const pool = {
    async execute(sql) {
      poolCalls.push(sql);
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  const duplicateCleanup = poolCalls.find((sql) =>
    sql.includes('DELETE duplicate FROM merchant_news duplicate'),
  );
  assert.ok(duplicateCleanup);
  assert.match(duplicateCleanup, /keeper\.status = 'published'/);
  assert.ok(poolCalls.some((sql) =>
    sql.includes('ADD UNIQUE INDEX uq_merchant_news_business (business_id)'),
  ));
  assert.ok(connectionCalls.some(({ sql, params }) =>
    sql.includes('INSERT INTO schema_migrations (version, name)') &&
    params[0] === 6 &&
    params[1] === 'single-news-card-per-business',
  ));
});

test('migration 7 adds persistent message deletion scopes', async () => {
  const poolCalls = [];
  const connectionCalls = [];
  const connection = {
    async execute(sql, params) {
      connectionCalls.push({ sql, params });
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [[
          { version: 1 },
          { version: 2 },
          { version: 3 },
          { version: 4 },
          { version: 5 },
          { version: 6 },
        ], []];
      }
      return [[], []];
    },
    release() {},
  };
  const pool = {
    async execute(sql, params) {
      poolCalls.push({ sql, params });
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  assert.ok(poolCalls.some(({ sql }) =>
    sql.includes('ALTER TABLE `messages` ADD COLUMN `removed_at`'),
  ));
  assert.ok(poolCalls.some(({ sql }) =>
    sql.includes('ALTER TABLE `messages` ADD COLUMN `removed_by`'),
  ));
  assert.ok(poolCalls.some(({ sql }) =>
    sql.includes('CREATE TABLE IF NOT EXISTS message_user_deletions'),
  ));
  assert.ok(connectionCalls.some(({ sql, params }) =>
    sql.includes('INSERT INTO schema_migrations (version, name)') &&
    params[0] === 7 &&
    params[1] === 'message-delete-scopes',
  ));
});

test('migration 8 adds customer review photo storage', async () => {
  const poolCalls = [];
  const connectionCalls = [];
  const connection = {
    async execute(sql, params) {
      connectionCalls.push({ sql, params });
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [[
          { version: 1 },
          { version: 2 },
          { version: 3 },
          { version: 4 },
          { version: 5 },
          { version: 6 },
          { version: 7 },
        ], []];
      }
      return [[], []];
    },
    release() {},
  };
  const pool = {
    async execute(sql, params) {
      poolCalls.push({ sql, params });
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  assert.ok(poolCalls.some(({ sql }) =>
    sql.includes('ALTER TABLE `venue_reviews` ADD COLUMN `image_data` LONGTEXT NULL'),
  ));
  assert.ok(connectionCalls.some(({ sql, params }) =>
    sql.includes('INSERT INTO schema_migrations (version, name)') &&
    params[0] === 8 &&
    params[1] === 'venue-review-customer-photo',
  ));
});
