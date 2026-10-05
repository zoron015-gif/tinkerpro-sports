const crypto = require('crypto');

function normalizeEmail(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function normalizeText(value, max = 255) {
  return typeof value === 'string' ? value.trim().slice(0, max) : '';
}

function isValidEmail(value) {
  return typeof value === 'string' &&
    value.length <= 254 &&
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function isNumericInput(value) {
  if (typeof value === 'number') return Number.isFinite(value);
  if (typeof value !== 'string' || value.trim() === '') return false;
  return Number.isFinite(Number(value));
}

function parseBusinessCoordinates(body) {
  const hasLatitude = Object.prototype.hasOwnProperty.call(body, 'latitude');
  const hasLongitude = Object.prototype.hasOwnProperty.call(body, 'longitude');
  if (!hasLatitude && !hasLongitude) {
    return { provided: false, valid: true, latitude: null, longitude: null };
  }
  const rawLatitude = body.latitude;
  const rawLongitude = body.longitude;
  if (
    (rawLatitude === null || rawLatitude === '') &&
    (rawLongitude === null || rawLongitude === '')
  ) {
    return { provided: true, valid: true, latitude: null, longitude: null };
  }
  if (!isNumericInput(rawLatitude) || !isNumericInput(rawLongitude)) {
    return { provided: true, valid: false, latitude: null, longitude: null };
  }
  const latitude = Number(rawLatitude);
  const longitude = Number(rawLongitude);
  const valid =
    Number.isFinite(latitude) &&
    latitude >= -90 &&
    latitude <= 90 &&
    Number.isFinite(longitude) &&
    longitude >= -180 &&
    longitude <= 180;
  return {
    provided: true,
    valid,
    latitude: valid ? latitude : null,
    longitude: valid ? longitude : null,
  };
}

function eventDetailsFromBody(body) {
  const list = (value) =>
    Array.isArray(value)
      ? value.filter((item) => typeof item === 'string').slice(0, 20)
      : [];
  const integer = (value) => {
    if (!isNumericInput(value)) return null;
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
  };
  return {
    eventTypes: list(body.eventTypes),
    attendanceMin: integer(body.attendanceMin),
    attendanceMax: integer(body.attendanceMax),
    accessibilityNeeds: list(body.accessibilityNeeds),
    parkingNeeds: list(body.parkingNeeds),
    securityNeeds: list(body.securityNeeds),
  };
}

function parseJsonArray(value, field = 'stored JSON array') {
  if (Array.isArray(value)) return value;
  if (value == null || (typeof value === 'string' && value.trim() === '')) {
    return [];
  }
  if (typeof value !== 'string') {
    console.error(`Invalid ${field}: expected a JSON array; using an empty array.`);
    return [];
  }
  try {
    const parsed = JSON.parse(value);
    if (Array.isArray(parsed)) return parsed;
    console.error(`Invalid ${field}: expected a JSON array; using an empty array.`);
    return [];
  } catch (error) {
    console.error(`Could not parse ${field}; using an empty array.`, error);
    return [];
  }
}

function isValidRole(role) {
  return role === 'customer' || role === 'merchant';
}

function publicUser(user) {
  return {
    id: user.id,
    email: user.email,
    firstName: user.first_name,
    lastName: user.last_name,
    phone: user.phone || null,
    avatarUrl: user.avatar_url || null,
    address: user.address || null,
    hobby: user.hobby || null,
    role: user.role,
    status: user.status,
  };
}

function publicMessageUser(user) {
  return {
    id: user.id,
    email: user.email,
    firstName: user.first_name,
    lastName: user.last_name,
    phone: user.phone || null,
    avatarUrl: user.avatar_url || null,
    role: user.role,
  };
}

function createVerificationCode() {
  return String(crypto.randomInt(100000, 1000000));
}

function hashVerificationCode(code) {
  return crypto.createHash('sha256').update(code).digest('hex');
}

function createBookingToken() {
  return crypto.randomBytes(18).toString('hex').toUpperCase();
}

function hashBookingToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

module.exports = {
  createBookingToken,
  createVerificationCode,
  eventDetailsFromBody,
  hashBookingToken,
  hashVerificationCode,
  isNumericInput,
  isValidEmail,
  isValidRole,
  normalizeEmail,
  normalizeText,
  parseBusinessCoordinates,
  parseJsonArray,
  publicMessageUser,
  publicUser,
};
