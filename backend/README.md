# TinkerPro Sports backend

Node.js and Express API for the Flutter app's MySQL authentication flow.

## Setup

1. Install Node.js 20 or newer.
2. Create the database with `database/schema.sql` from the project root.
3. Copy `.env.example` to `.env` and set the MySQL credentials and a random `JWT_SECRET`.
   For the existing server database, use `DB_NAME=sports`, `DB_USER=root`,
   and your MySQL root password in `DB_PASSWORD`.
4. Set `SMTP_USER` to the Gmail address that sends mail and `SMTP_APP_PASSWORD` to its 16-character Google App Password.
5. Set `GOOGLE_CLIENT_ID` to the Firebase web OAuth client ID so Google ID tokens are accepted only for this app.
6. Run `npm install`.
7. Start the API with `npm run dev`, `npm start`, or `node server.js`.

The API runs on `http://localhost:3000` by default.

If MySQL reports `ER_ACCESS_DENIED_ERROR`, the `DB_USER` or `DB_PASSWORD` in
`backend/.env` does not match your MySQL account. Do not use your Gmail
password or Gmail app password for `DB_PASSWORD`; those are only for SMTP.

## Endpoints

- `GET /health`
- `POST /api/auth/register`
- `POST /api/auth/verify-email`
- `POST /api/auth/resend-verification`
- `POST /api/auth/login`
- `POST /api/auth/forgot-password`
- `POST /api/auth/verify-password-reset-code`
- `POST /api/auth/reset-password`
- `POST /api/auth/oauth/google`
- `GET /api/auth/me` with `Authorization: Bearer <token>`

Registration creates a pending account and sends a six-digit verification code by Gmail SMTP. The code expires after 10 minutes. Google login should exchange a provider token with a server-side provider SDK before inserting into `user_identities`. Do not trust a raw provider user ID supplied by an unverified client.

News endpoints:
- `GET /api/news/feed` returns published customer news with venue details and ratings.
- `GET/POST /api/merchant/news` and `PUT/DELETE /api/merchant/news/:id` manage merchant posts.
- `POST /api/reviews` accepts one review for each customer's completed booking.
