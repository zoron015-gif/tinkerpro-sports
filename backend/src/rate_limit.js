function createRateLimiter({
  windowMs,
  maxRequests,
  keyGenerator,
  message = 'Too many requests. Please try again later.',
}) {
  const buckets = new Map();

  return (req, res, next) => {
    const now = Date.now();
    const key = keyGenerator(req);
    let bucket = buckets.get(key);

    if (!bucket || bucket.resetAt <= now) {
      if (buckets.size >= 10000) {
        for (const [key, entry] of buckets) {
          if (entry.resetAt <= now) buckets.delete(key);
        }
        if (buckets.size >= 10000) {
          return res.status(503).json({
            error: 'Request throttling is temporarily unavailable.',
          });
        }
      }
      bucket = { count: 0, resetAt: now + windowMs };
      buckets.set(key, bucket);
    }

    bucket.count += 1;
    const remaining = Math.max(0, maxRequests - bucket.count);
    const retryAfterSeconds = Math.max(
      1,
      Math.ceil((bucket.resetAt - now) / 1000),
    );
    res.set({
      'RateLimit-Limit': String(maxRequests),
      'RateLimit-Remaining': String(remaining),
      'RateLimit-Reset': String(Math.ceil(bucket.resetAt / 1000)),
    });

    if (bucket.count > maxRequests) {
      res.set('Retry-After', String(retryAfterSeconds));
      return res.status(429).json({ error: message });
    }
    return next();
  };
}

module.exports = { createRateLimiter };
