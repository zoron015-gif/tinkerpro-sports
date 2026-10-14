function createCorsOriginPolicy({
  environment = process.env.NODE_ENV,
  clientOrigin = process.env.CLIENT_ORIGIN,
} = {}) {
  const allowedOrigins = (clientOrigin || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  const isProduction = environment === 'production';

  if (isProduction && allowedOrigins.length === 0) {
    throw new Error(
      'CLIENT_ORIGIN must contain at least one allowed origin in production.',
    );
  }

  return (origin, callback) => {
    if (
      origin === undefined ||
      allowedOrigins.includes(origin) ||
      (!isProduction && allowedOrigins.length === 0)
    ) {
      return callback(null, true);
    }
    return callback(null, false);
  };
}

module.exports = { createCorsOriginPolicy };
