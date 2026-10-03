const assert = require('node:assert/strict');
const { test } = require('node:test');
const { ReadCache } = require('../src/read_cache');

test('reuses values until the TTL expires and returns independent copies', async () => {
  let now = 0;
  const cache = new ReadCache({ now: () => now });
  let loads = 0;
  const loader = async () => {
    loads++;
    return { businesses: [{ name: 'Court' }] };
  };

  const first = await cache.getOrLoad('catalog', 100, loader);
  first.businesses[0].name = 'Mutated by caller';
  const second = await cache.getOrLoad('catalog', 100, loader);

  assert.equal(second.businesses[0].name, 'Court');
  assert.equal(loads, 1);

  now = 101;
  await cache.getOrLoad('catalog', 100, loader);
  assert.equal(loads, 2);
});

test('coalesces concurrent loads for the same key', async () => {
  const cache = new ReadCache();
  let loads = 0;
  let resolveLoad;
  const loader = () => {
    loads++;
    return new Promise((resolve) => {
      resolveLoad = resolve;
    });
  };

  const first = cache.getOrLoad('catalog', 1000, loader);
  const second = cache.getOrLoad('catalog', 1000, loader);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(loads, 1);

  resolveLoad([{ name: 'Court' }]);
  assert.deepEqual(await first, [{ name: 'Court' }]);
  assert.deepEqual(await second, [{ name: 'Court' }]);
});

test('does not repopulate an invalidated entry from an in-flight load', async () => {
  const cache = new ReadCache();
  let resolveLoad;
  const pending = cache.getOrLoad(
    'catalog',
    1000,
    () => new Promise((resolve) => {
      resolveLoad = resolve;
    }),
  );
  await new Promise((resolve) => setImmediate(resolve));
  cache.invalidate('catalog');
  let loads = 0;
  let resolveRefresh;
  const refresh = cache.getOrLoad('catalog', 1000, () => {
    loads++;
    return new Promise((resolve) => {
      resolveRefresh = resolve;
    });
  });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(loads, 1);
  resolveRefresh([{ name: 'Fresh Court' }]);
  assert.deepEqual(await refresh, [{ name: 'Fresh Court' }]);
  resolveLoad([{ name: 'Stale Court' }]);
  await pending;

  const refreshed = await cache.getOrLoad('catalog', 1000, async () => {
    loads++;
    return [{ name: 'Unexpected reload' }];
  });
  assert.deepEqual(refreshed, [{ name: 'Fresh Court' }]);
  assert.equal(loads, 1);
});
