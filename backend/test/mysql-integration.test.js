const assert = require('node:assert/strict');
const { readFile } = require('node:fs/promises');
const path = require('node:path');
const { spawn } = require('node:child_process');
const net = require('node:net');
const { setTimeout: delay } = require('node:timers/promises');
const { test } = require('node:test');
const jwt = require('jsonwebtoken');
const mysql = require('mysql2/promise');

const configured =
  process.env.MYSQL_TEST_DATABASE &&
  process.env.MYSQL_TEST_HOST &&
  process.env.MYSQL_TEST_USER;

test(
  'MySQL schema supports Fitness booking, conflict detection, and merchant approval',
  { skip: !configured },
  async (t) => {
    const databasePrefix = process.env.MYSQL_TEST_DATABASE;
    assert.match(
      databasePrefix,
      /^[A-Za-z0-9_]+_test$/,
      'MYSQL_TEST_DATABASE must be a dedicated database name ending in _test',
    );
    const databaseName =
      `${databasePrefix.slice(0, 35)}_${process.pid}_${Date.now()}`.slice(0, 64);
    const jwtSecret = `mysql-integration-${process.pid}-${Date.now()}`;
    const mysqlOptions = {
      host: process.env.MYSQL_TEST_HOST,
      port: Number(process.env.MYSQL_TEST_PORT || 3306),
      user: process.env.MYSQL_TEST_USER,
      password: process.env.MYSQL_TEST_PASSWORD || '',
      multipleStatements: true,
    };
    const admin = await mysql.createConnection(mysqlOptions);
    let db;
    let serverProcess;
    let serverStderr = '';
    let databaseCreated = false;

    t.after(async () => {
      if (serverProcess && serverProcess.exitCode === null) {
        serverProcess.kill();
        await Promise.race([
          new Promise((resolve) => serverProcess.once('exit', resolve)),
          delay(5000),
        ]);
      }
      await db?.end();
      if (databaseCreated) {
        await admin.query(`DROP DATABASE \`${databaseName}\``);
      }
      await admin.end();
    });

    await admin.query(`CREATE DATABASE \`${databaseName}\``);
    databaseCreated = true;
    const schemaFile = path.join(__dirname, '..', '..', 'database', 'sports.sql');
    const schema = (await readFile(schemaFile, 'utf8')).replaceAll(
      'tinkerpro_sports',
      databaseName,
    );
    await admin.query(schema);
    db = await mysql.createConnection({
      ...mysqlOptions,
      database: databaseName,
      multipleStatements: false,
    });

    const port = await _freePort();
    const backendDirectory = path.join(__dirname, '..');
    serverProcess = spawn(process.execPath, ['src/server.js'], {
      cwd: backendDirectory,
      env: {
        ...process.env,
        DB_HOST: mysqlOptions.host,
        DB_PORT: String(mysqlOptions.port),
        DB_NAME: databaseName,
        DB_USER: mysqlOptions.user,
        DB_PASSWORD: mysqlOptions.password,
        JWT_SECRET: jwtSecret,
        PORT: String(port),
      },
      stdio: ['ignore', 'ignore', 'pipe'],
    });
    serverProcess.stderr.setEncoding('utf8');
    serverProcess.stderr.on('data', (chunk) => {
      serverStderr = `${serverStderr}${chunk}`.slice(-4000);
    });

    await _waitForServer(port, serverProcess, () => serverStderr);
    const suffix = `${process.pid}.${Date.now()}`;
    const [merchantResult] = await db.execute(
      `INSERT INTO users (email, role, status, email_verified_at)
       VALUES (?, 'merchant', 'active', CURRENT_TIMESTAMP)`,
      [`merchant.${suffix}@example.test`],
    );
    const [customerResult] = await db.execute(
      `INSERT INTO users (email, role, status, email_verified_at)
       VALUES (?, 'customer', 'active', CURRENT_TIMESTAMP)`,
      [`customer.${suffix}@example.test`],
    );
    const [venueResult] = await db.execute(
      `INSERT INTO merchant_businesses
         (merchant_id, business_type, name, category, address, facility_type,
          price_per_hour, opening_hours, availability)
       VALUES (?, 'Fitness & Wellness', 'Integration Studio', 'Yoga',
               '1 Test Road', 'Studio', 0, 'Open daily', 'Any')`,
      [merchantResult.insertId],
    );
    await db.execute(
      `INSERT INTO fitness_business_details
         (business_id, fitness_categories_json, fitness_coaches_json)
       VALUES (?, ?, ?)`,
      [
        venueResult.insertId,
        JSON.stringify([
          {
            category: 'Yoga',
            sessionPrice: 500,
            monthlyPrice: 1200,
            yearlyPrice: 12000,
            yearlyDiscountType: 'none',
            yearlyDiscountValue: null,
          },
        ]),
        JSON.stringify([{ name: 'Coach One', monthlyPrice: 300 }]),
      ],
    );

    const customerToken = jwt.sign(
      {
        sub: String(customerResult.insertId),
        email: `customer.${suffix}@example.test`,
        role: 'customer',
      },
      jwtSecret,
    );
    const merchantToken = jwt.sign(
      {
        sub: String(merchantResult.insertId),
        email: `merchant.${suffix}@example.test`,
        role: 'merchant',
      },
      jwtSecret,
    );
    const bookingRequest = {
      venueId: venueResult.insertId,
      date: '2035-06-12',
      startTime: '09:00:00',
      durationHours: 1,
      players: 1,
      paymentMethod: 'cash_on_arrival',
      sportType: 'Yoga',
      fitnessPlanType: 'monthly',
      fitnessCoachName: 'Coach One',
    };
    const createdResponse = await _request(port, '/api/bookings', {
      method: 'POST',
      token: customerToken,
      body: bookingRequest,
    });
    assert.equal(createdResponse.status, 201);
    const created = await createdResponse.json();
    assert.equal(created.booking.total, 1500);
    const bookingId = created.booking.id;

    const conflictResponse = await _request(port, '/api/bookings', {
      method: 'POST',
      token: customerToken,
      body: bookingRequest,
    });
    assert.equal(conflictResponse.status, 409);

    const approvalResponse = await _request(
      port,
      `/api/merchant/bookings/${bookingId}/approve`,
      { method: 'PATCH', token: merchantToken },
    );
    assert.equal(approvalResponse.status, 200);
    const approval = await approvalResponse.json();
    assert.equal(approval.status, 'approved');
    assert.ok(approval.ticketCode);

    const [bookings] = await db.execute(
      'SELECT status, ticket_token_hash FROM bookings WHERE id = ?',
      [bookingId],
    );
    assert.equal(bookings[0].status, 'approved');
    assert.ok(bookings[0].ticket_token_hash);

    const [messages] = await db.execute(
      `SELECT attachment_json FROM messages
       WHERE conversation_id = (SELECT id FROM conversations WHERE title = ?)
       ORDER BY id DESC LIMIT 1`,
      [`Booking ${bookingId}`],
    );
    const ticket = JSON.parse(messages[0].attachment_json);
    assert.equal(ticket.type, 'booking_ticket');
    assert.equal(ticket.status, 'approved');
    assert.equal(ticket.ticketCode, approval.ticketCode);
    assert.equal(ticket.fitnessCategory, 'Yoga');
    assert.equal(ticket.fitnessCoachName, 'Coach One');
  },
);

async function _freePort() {
  const listener = net.createServer();
  await new Promise((resolve, reject) => {
    listener.once('error', reject);
    listener.listen(0, '127.0.0.1', resolve);
  });
  const address = listener.address();
  await new Promise((resolve, reject) => {
    listener.close((error) => (error ? reject(error) : resolve()));
  });
  return address.port;
}

async function _waitForServer(port, process, getStderr) {
  const deadline = Date.now() + 30_000;
  let lastError;
  while (Date.now() < deadline) {
    if (process.exitCode !== null) {
      throw new Error(`Backend exited before becoming ready: ${getStderr()}`);
    }
    try {
      const response = await fetch(`http://127.0.0.1:${port}/health`, {
        signal: AbortSignal.timeout(1000),
      });
      if (response.ok) return;
      lastError = new Error(`Health endpoint returned ${response.status}.`);
    } catch (error) {
      lastError = error;
    }
    await delay(200);
  }
  throw new Error(
    `Backend did not become ready: ${lastError}; ${getStderr()}`,
  );
}

async function _request(port, route, { method = 'GET', token, body } = {}) {
  return fetch(`http://127.0.0.1:${port}${route}`, {
    method,
    headers: {
      ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(body ? { 'content-type': 'application/json' } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
}
