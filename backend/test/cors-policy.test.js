const assert = require('node:assert/strict');
const { test } = require('node:test');
const { createCorsOriginPolicy } = require('../src/cors_policy');

function checkOrigin(policy, origin) {
  let result;
  policy(origin, (error, allowed) => {
    assert.ifError(error);
    result = allowed;
  });
  return result;
}

test('production CORS requires an explicit allowed origin', () => {
  assert.throws(
    () =>
      createCorsOriginPolicy({
        environment: 'production',
        clientOrigin: '',
      }),
    /CLIENT_ORIGIN must contain at least one allowed origin in production/,
  );
});

test('production CORS allows only configured origins', () => {
  const policy = createCorsOriginPolicy({
    environment: 'production',
    clientOrigin: 'https://app.example.com, https://admin.example.com',
  });

  assert.equal(checkOrigin(policy, 'https://app.example.com'), true);
  assert.equal(checkOrigin(policy, 'https://admin.example.com'), true);
  assert.equal(checkOrigin(policy, 'https://untrusted.example.com'), false);
  assert.equal(checkOrigin(policy, undefined), true);
});

test('local development without configured origins remains LAN-friendly', () => {
  const policy = createCorsOriginPolicy({
    environment: 'development',
    clientOrigin: '',
  });

  assert.equal(checkOrigin(policy, 'http://localhost:8080'), true);
  assert.equal(checkOrigin(policy, 'http://192.168.1.25:8080'), true);
});

test('configured local origins are enforced without requiring production setup', () => {
  const policy = createCorsOriginPolicy({
    environment: 'development',
    clientOrigin: 'http://localhost:8080',
  });

  assert.equal(checkOrigin(policy, 'http://localhost:8080'), true);
  assert.equal(checkOrigin(policy, 'http://192.168.1.25:8080'), false);
});
