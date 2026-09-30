const assert = require('node:assert/strict');
const { test } = require('node:test');
const { createRateLimiter } = require('../src/rate_limit');

function makeResponse() {
  return {
    headers: {},
    statusCode: 200,
    body: null,
    set(name, value) {
      if (typeof name === 'object') Object.assign(this.headers, name);
      else this.headers[name] = value;
      return this;
    },
    status(statusCode) {
      this.statusCode = statusCode;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}

test('rate limiter blocks excess requests and isolates keys', () => {
  const limiter = createRateLimiter({
    windowMs: 60_000,
    maxRequests: 2,
    keyGenerator: (req) => req.ip,
  });
  const request = { ip: '192.0.2.1' };
  let nextCalls = 0;
  const next = () => {
    nextCalls += 1;
  };

  const first = makeResponse();
  limiter(request, first, next);
  assert.equal(first.statusCode, 200);
  assert.equal(first.headers['RateLimit-Remaining'], '1');

  const second = makeResponse();
  limiter(request, second, next);
  assert.equal(second.statusCode, 200);
  assert.equal(second.headers['RateLimit-Remaining'], '0');

  const blocked = makeResponse();
  limiter(request, blocked, next);
  assert.equal(blocked.statusCode, 429);
  assert.equal(blocked.headers['Retry-After'], '60');
  assert.match(blocked.body.error, /Too many requests/);
  assert.equal(nextCalls, 2);

  const otherKey = makeResponse();
  limiter({ ip: '192.0.2.2' }, otherKey, next);
  assert.equal(otherKey.statusCode, 200);
});

test('expired rate-limit windows allow requests again', (t) => {
  const originalNow = Date.now;
  let now = 1_000_000;
  Date.now = () => now;
  t.after(() => {
    Date.now = originalNow;
  });

  const limiter = createRateLimiter({
    windowMs: 1000,
    maxRequests: 1,
    keyGenerator: (req) => req.ip,
  });
  const request = { ip: '192.0.2.1' };
  const first = makeResponse();
  limiter(request, first, () => {});
  assert.equal(first.statusCode, 200);

  const blocked = makeResponse();
  limiter(request, blocked, () => {});
  assert.equal(blocked.statusCode, 429);

  now += 1000;
  const afterWindow = makeResponse();
  limiter(request, afterWindow, () => {});
  assert.equal(afterWindow.statusCode, 200);
});
