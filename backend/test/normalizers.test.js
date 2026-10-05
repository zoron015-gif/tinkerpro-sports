const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
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
} = require('../src/normalizers');

test('normalizes email and bounded text safely', () => {
  assert.equal(normalizeEmail('  Player@Example.COM  '), 'player@example.com');
  assert.equal(normalizeEmail(null), '');
  assert.equal(normalizeText('  Court  ', 4), 'Cour');
  assert.equal(normalizeText(42), '');
});

test('validates email and numeric input without accepting coercible types', () => {
  assert.equal(isValidEmail('player@example.test'), true);
  assert.equal(isValidEmail('player@localhost'), false);
  assert.equal(isValidEmail(' player@example.test'), false);
  assert.equal(isValidEmail('x'.repeat(250) + '@example.test'), false);
  assert.equal(isNumericInput(12), true);
  assert.equal(isNumericInput('12.5'), true);
  assert.equal(isNumericInput(''), false);
  assert.equal(isNumericInput('   '), false);
  assert.equal(isNumericInput(true), false);
  assert.equal(isNumericInput(null), false);
  assert.equal(isNumericInput(Infinity), false);
});

test('parses business coordinates only when a complete valid pair is provided', () => {
  assert.deepEqual(parseBusinessCoordinates({}), {
    provided: false,
    valid: true,
    latitude: null,
    longitude: null,
  });
  assert.deepEqual(parseBusinessCoordinates({ latitude: '', longitude: null }), {
    provided: true,
    valid: true,
    latitude: null,
    longitude: null,
  });
  assert.deepEqual(
    parseBusinessCoordinates({ latitude: '10.3', longitude: '123.8' }),
    { provided: true, valid: true, latitude: 10.3, longitude: 123.8 },
  );
  assert.deepEqual(parseBusinessCoordinates({ latitude: 91, longitude: 0 }), {
    provided: true,
    valid: false,
    latitude: null,
    longitude: null,
  });
  assert.deepEqual(parseBusinessCoordinates({ latitude: false, longitude: 0 }), {
    provided: true,
    valid: false,
    latitude: null,
    longitude: null,
  });
});

test('filters event details and caps each list at 20 values', () => {
  const details = eventDetailsFromBody({
    eventTypes: [...Array.from({ length: 21 }, (_, index) => `type-${index}`), 2],
    attendanceMin: '25',
    attendanceMax: '25.5',
    accessibilityNeeds: ['Ramp', false],
    parkingNeeds: 'onsite',
    securityNeeds: ['Security'],
  });

  assert.equal(details.eventTypes.length, 20);
  assert.equal(details.eventTypes.at(-1), 'type-19');
  assert.equal(details.attendanceMin, 25);
  assert.equal(details.attendanceMax, null);
  assert.deepEqual(details.accessibilityNeeds, ['Ramp']);
  assert.deepEqual(details.parkingNeeds, []);
  assert.deepEqual(details.securityNeeds, ['Security']);
});

test('parses JSON arrays and treats absent values as empty', () => {
  const existing = ['Tennis'];
  assert.equal(parseJsonArray(existing), existing);
  assert.deepEqual(parseJsonArray('["Tennis","Basketball"]'), [
    'Tennis',
    'Basketball',
  ]);
  assert.deepEqual(parseJsonArray('   '), []);
  assert.deepEqual(parseJsonArray(null), []);
});

test('reports malformed stored arrays without logging their contents', (t) => {
  const errors = [];
  t.mock.method(console, 'error', (...args) => errors.push(args));

  assert.deepEqual(parseJsonArray('{invalid-secret-data', 'venue.tags'), []);
  assert.deepEqual(parseJsonArray('{"private":"value"}', 'booking.amenities'), []);
  assert.deepEqual(parseJsonArray(42, 'venue.imageUrls'), []);

  assert.equal(errors.length, 3);
  assert.match(errors[0][0], /venue\.tags/);
  assert.match(errors[0][0], /Could not parse/);
  assert.equal(errors[1].length, 1);
  assert.match(errors[1][0], /booking\.amenities/);
  assert.equal(errors[2].length, 1);
  assert.match(errors[2][0], /venue\.imageUrls/);
  assert.equal(
    errors.flat().some((value) => String(value).includes('invalid-secret-data')),
    false,
  );
});

test('accepts only supported account roles and shapes public users', () => {
  assert.equal(isValidRole('customer'), true);
  assert.equal(isValidRole('merchant'), true);
  assert.equal(isValidRole('admin'), false);
  assert.equal(isValidRole(null), false);

  const user = {
    id: 5,
    email: 'player@example.test',
    first_name: 'Sam',
    last_name: 'Player',
    phone: '',
    avatar_url: null,
    address: '',
    hobby: null,
    role: 'customer',
    status: 'active',
  };
  assert.deepEqual(publicUser(user), {
    id: 5,
    email: 'player@example.test',
    firstName: 'Sam',
    lastName: 'Player',
    phone: null,
    avatarUrl: null,
    address: null,
    hobby: null,
    role: 'customer',
    status: 'active',
  });
  const messageUser = publicMessageUser(user);
  assert.equal(messageUser.role, 'customer');
  assert.equal('status' in messageUser, false);
});

test('creates and hashes verification codes and booking tokens', () => {
  const verificationCode = createVerificationCode();
  assert.match(verificationCode, /^\d{6}$/);
  assert.equal(hashVerificationCode('123456').length, 64);
  assert.equal(hashVerificationCode('123456'), hashVerificationCode('123456'));

  const bookingToken = createBookingToken();
  assert.match(bookingToken, /^[A-F0-9]{36}$/);
  assert.equal(hashBookingToken('TOKEN').length, 64);
  assert.equal(hashBookingToken('TOKEN'), hashBookingToken('TOKEN'));
});
