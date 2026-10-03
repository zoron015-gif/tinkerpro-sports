class ReadCache {
  constructor({ maxEntries = 100, now = Date.now } = {}) {
    this.maxEntries = maxEntries;
    this.now = now;
    this.entries = new Map();
    this.inFlight = new Map();
    this.generations = new Map();
  }

  async getOrLoad(key, ttlMs, loader) {
    const cached = this.entries.get(key);
    if (cached && cached.expiresAt > this.now()) {
      this.entries.delete(key);
      this.entries.set(key, cached);
      return structuredClone(cached.value);
    }
    if (cached) this.entries.delete(key);

    const pending = this.inFlight.get(key);
    if (pending) return structuredClone(await pending.promise);

    const generation = this.generations.get(key) ?? 0;
    const promise = Promise.resolve().then(loader);
    const flight = { promise, generation };
    this.inFlight.set(key, flight);

    try {
      const value = await promise;
      if (
        ttlMs > 0 &&
        (this.generations.get(key) ?? 0) === generation &&
        this.inFlight.get(key) === flight
      ) {
        this.entries.set(key, {
          value: structuredClone(value),
          expiresAt: this.now() + ttlMs,
        });
        while (this.entries.size > this.maxEntries) {
          this.entries.delete(this.entries.keys().next().value);
        }
      }
      return structuredClone(value);
    } finally {
      if (this.inFlight.get(key) === flight) this.inFlight.delete(key);
    }
  }

  invalidate(key) {
    this.generations.set(key, (this.generations.get(key) ?? 0) + 1);
    this.entries.delete(key);
    this.inFlight.delete(key);
  }

  clear() {
    this.entries.clear();
    this.inFlight.clear();
    this.generations.clear();
  }
}

module.exports = new ReadCache();
module.exports.ReadCache = ReadCache;
