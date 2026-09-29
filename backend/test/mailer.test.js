const assert = require('node:assert/strict');
const { test } = require('node:test');
const nodemailer = require('nodemailer');
const {
  sendPasswordResetCode,
  sendVerificationCode,
} = require('../src/mailer');

test('verification and password-reset emails use the configured secure transport', async (t) => {
  const originalUser = process.env.SMTP_USER;
  const originalPassword = process.env.SMTP_APP_PASSWORD;
  process.env.SMTP_USER = 'mailer@example.test';
  process.env.SMTP_APP_PASSWORD = 'test app password';
  t.after(() => {
    if (originalUser === undefined) delete process.env.SMTP_USER;
    else process.env.SMTP_USER = originalUser;
    if (originalPassword === undefined) delete process.env.SMTP_APP_PASSWORD;
    else process.env.SMTP_APP_PASSWORD = originalPassword;
  });

  const transports = [];
  const emails = [];
  t.mock.method(nodemailer, 'createTransport', (options) => {
    transports.push(options);
    return { sendMail: async (message) => emails.push(message) };
  });

  await sendVerificationCode('new@example.test', '123456');
  await sendPasswordResetCode('reset@example.test', '654321');

  assert.equal(transports.length, 2);
  for (const transport of transports) {
    assert.equal(transport.host, 'smtp.gmail.com');
    assert.equal(transport.port, 465);
    assert.equal(transport.secure, true);
    assert.deepEqual(transport.auth, {
      user: 'mailer@example.test',
      pass: 'testapppassword',
    });
  }

  assert.equal(emails[0].to, 'new@example.test');
  assert.match(emails[0].text, /verification code is 123456/);
  assert.match(emails[0].text, /expires in 10 minutes/);
  assert.equal(emails[1].to, 'reset@example.test');
  assert.match(emails[1].subject, /PASSWORD RESET CODE/);
  assert.match(emails[1].text, /not a registration code/i);
  assert.match(emails[1].text, /654321/);
});

test('email sending reports missing SMTP configuration without sending', async (t) => {
  const originalUser = process.env.SMTP_USER;
  const originalPassword = process.env.SMTP_APP_PASSWORD;
  delete process.env.SMTP_USER;
  delete process.env.SMTP_APP_PASSWORD;
  t.after(() => {
    if (originalUser === undefined) delete process.env.SMTP_USER;
    else process.env.SMTP_USER = originalUser;
    if (originalPassword === undefined) delete process.env.SMTP_APP_PASSWORD;
    else process.env.SMTP_APP_PASSWORD = originalPassword;
  });

  await assert.rejects(
    sendVerificationCode('new@example.test', '123456'),
    /Missing SMTP configuration: SMTP_USER, SMTP_APP_PASSWORD/,
  );
});
