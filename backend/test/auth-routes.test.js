const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');
const Module = require('node:module');
const path = require('node:path');
const express = require('express');
const jwt = require('jsonwebtoken');

const serverFile = path.join(__dirname, '..', 'src', 'server.js');
const originalLoad = Module._load;
const originalListen = express.application.listen;
let server;
let accessToken;
let originalJwtSecret;

before(async () => {
  originalJwtSecret = process.env.JWT_SECRET;
  process.env.JWT_SECRET = 'backend-test-only-secret';

  const fakePool = {
    execute: async () => [[], []],
    query: async () => [[], []],
  };
  let resolveListening;
  const listening = new Promise((resolve) => {
    resolveListening = resolve;
  });

  Module._load = function (request, parent, isMain) {
    if (request === 'dotenv' && parent.filename === serverFile) {
      return { config: () => ({}) };
    }
    if (request === './db' && parent.filename === serverFile) {
      return fakePool;
    }
    return originalLoad.call(this, request, parent, isMain);
  };
  express.application.listen = function () {
    server = originalListen.call(this, 0, () => resolveListening());
    return server;
  };

  try {
    require(serverFile);
    await listening;
  } finally {
    Module._load = originalLoad;
    express.application.listen = originalListen;
  }

  accessToken = jwt.sign({
    sub: '42',
    email: 'customer@example.test',
    role: 'customer',
  }, process.env.JWT_SECRET);
});

after(async () => {
  if (server) {
    await new Promise((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
  if (originalJwtSecret === undefined) delete process.env.JWT_SECRET;
  else process.env.JWT_SECRET = originalJwtSecret;
});

test('protected routes reject requests without a bearer token', async () => {
  const response = await fetch(
    `http://127.0.0.1:${server.address().port}/api/auth/me`,
  );

  assert.equal(response.status, 401);
  const body = await response.json();
  assert.equal(typeof body.error, 'string');
  assert.ok(body.error.length > 0);
});

test('merchant routes reject a valid token for an account without active merchant access', async () => {
  const response = await fetch(
    `http://127.0.0.1:${server.address().port}/api/merchant/news`,
    { headers: { authorization: `Bearer ${accessToken}` } },
  );

  assert.equal(response.status, 403);
  assert.deepEqual(await response.json(), {
    error: 'Only active merchant accounts can access this endpoint.',
  });
});
