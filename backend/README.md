# TinkerPro Sports backend

Node.js and Express API for the Flutter app's MySQL authentication flow.

## Setup

1. Install Node.js 20 or newer.
2. Create the database with `database/schema.sql` from the project root.
3. Copy `.env.example` to `.env` and set the MySQL credentials and a random `JWT_SECRET`.
4. Run `npm install`.
5. Start the API with `npm run dev` or `npm start`.

The API runs on `http://localhost:3000` by default.

## Endpoints

- `GET /health`
- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me` with `Authorization: Bearer <token>`

Google and Facebook login should exchange a provider token with a server-side provider SDK before inserting into `user_identities`. Do not trust a raw provider user ID supplied by an unverified client.
