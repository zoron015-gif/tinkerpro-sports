# TinkerPro Sports backend

Node.js 20+ and Express API for the Flutter app. It handles account and profile
operations, venue and booking data, merchant tools, messaging, news, and
reviews, using MySQL.

## Setup

1. Install MySQL 8 or newer and create the project schema from the repository
   root. The actual schema file is `database/sports.sql`; it creates and selects
   the `tinkerpro_sports` database:

   ```sh
   mysql -u root -p < database/sports.sql
   ```

   Use a MySQL account that can access this database for the API.
2. In `backend`, copy `.env.example` to `.env` and set the values for your
   environment. Set `DB_HOST`, `DB_USER`, and `DB_PASSWORD` to match your MySQL
   server, and set a long, random `JWT_SECRET`; the API will not start without
   it.
3. For email verification and password reset, configure `SMTP_USER` as the
   sending Gmail address and `SMTP_APP_PASSWORD` as its Google App Password.
   This is separate from `DB_PASSWORD`.
4. Set `GOOGLE_CLIENT_ID` to the web OAuth client ID used by the app's Firebase
   Google sign-in configuration. Configure `PORT` only if you do not want the
   default port 3000. The example also includes optional PayMongo checkout
   settings; provide valid credentials and return URLs if using that integration.
   To issue a payment ticket, configure a PayMongo webhook for
   `POST /api/payments/paymongo/webhook`, subscribe to
   `checkout_session.payment.paid`, and set `PAYMONGO_WEBHOOK_SECRET` to that
   webhook's signing secret. The signed webhook is the source of truth; the
   checkout redirect alone does not mark a booking paid. After payment, the
   booking pass appears in Messages as pending venue approval. Venue approval
   issues the separate entry ticket and access code.
5. Install dependencies and start the API:

   ```

Account registration and sign-in requests are limited to 100 requests per
client IP and 10 per normalized email every 15 minutes. Email verification and
password recovery are limited to 8 requests per normalized email in the same
window. Limited requests return HTTP 429 with `Retry-After` and `RateLimit-*`
headers. These limits are held in each API process; deployments with multiple
instances should also enforce equivalent limits at a shared API gateway.sh
   cd backend
   npm install
   npm run dev
   ```

   `npm run dev` starts `nodemon src/server.js`. For a regular start, use
   `npm start` (`node src/server.js`); `node server.js` is also supported as a
   compatibility entry point when run from `backend`.

The health endpoint is `GET http://localhost:3000/health`. It checks both the
API and its MySQL connection. On startup, the API also ensures some merchant,
messaging, booking, profile, news, and review tables exist.
Malformed stored JSON-array fields are logged with the field name and returned
as empty arrays so corrupted values are diagnosable without exposing their
contents in logs.

If MySQL reports `ER_ACCESS_DENIED_ERROR`, check `DB_USER` and `DB_PASSWORD`
against your MySQL account. Do not use your Gmail password or Gmail App
Password for `DB_PASSWORD`.

## Endpoints

Authenticated endpoints require `Authorization: Bearer <token>`.

- `GET /health`
- Authentication: `POST /api/auth/register`, `/api/auth/verify-email`,
  `/api/auth/resend-verification`, `/api/auth/login`,
  `/api/auth/forgot-password`, `/api/auth/verify-password-reset-code`,
  `/api/auth/reset-password`, and `/api/auth/oauth/google`
- Profiles: `GET /api/auth/me`, `PUT /api/auth/profile`,
  `GET /api/merchant/profile`, and `PUT /api/merchant/profile`
- Venues and merchant tools: `GET /api/businesses`,
  `GET/POST /api/merchant/businesses`, `PUT /api/merchant/businesses/:id`,
  and `DELETE /api/merchant/businesses/:id`
- Bookings: `GET /api/bookings/availability`, `POST /api/bookings`,
  `GET /api/bookings`, and `GET /api/merchant/bookings`
- Messages: `/api/messages/owner`, `/api/messages/contacts`,
  `/api/messages/conversations`, and `/api/messages/blocks/:userId`
- News: `GET /api/news/feed` returns published customer news with venue details
  and ratings. `GET/POST /api/merchant/news` and
  `PUT/DELETE /api/merchant/news/:id` manage merchant posts.
- Reviews: `POST /api/reviews` accepts one review for each customer's completed
  booking.

## Database integration tests

The default `npm test` suite uses isolated database fakes and does not require
MySQL. To run the opt-in integration test, configure a MySQL account that can
create and drop databases, then set `MYSQL_TEST_HOST`, `MYSQL_TEST_USER`, and
`MYSQL_TEST_DATABASE` (a dedicated name ending in `_test`). Set
`MYSQL_TEST_PASSWORD` and `MYSQL_TEST_PORT` if needed and run:

```sh
npm run test:integration
```

The test creates a uniquely named temporary database derived from the
`MYSQL_TEST_DATABASE` prefix, applies `database/sports.sql`, starts the API
against that database, verifies Fitness booking/pricing and conflict checks,
approves a booking, and confirms the issued ticket is persisted in Messages.
It drops only the temporary database it created.

Registration creates a pending account and sends a six-digit verification code
by Gmail SMTP. The code expires after 10 minutes.

Sports venues can configure a shared `slotCount` and a `sportsSlots` list. Each
sport entry contains `sportType`, `pricePerHour`, `fullStudio`, and `slotCount`.
A full-studio sport blocks every slot; a small-slot sport blocks only its
selected `slotNumber`, while any overlapping full-studio booking blocks all
small slots. Optional `includedPlayers` and `additionalPlayerFee` values are
configured independently for each sport. Booking prices and extra-player fees
are taken from the saved sport configuration, not from the customer request,
and overlapping bookings are checked under a venue row lock. Existing venues
without a sports-slot configuration keep their single, full-studio behavior.

Fitness & Wellness businesses can configure multiple `fitnessCategories`, each
with separate `sessionPrice`, `monthlyPrice`, and `yearlyPrice` values plus an
optional yearly discount (`freeMonths` or `percentage`). Optional
`fitnessCoaches` store each coach's name, monthly price, and profile image URL.
These settings are stored as JSON in `fitness_business_details`; startup adds
the columns for existing databases, and merchant/public business responses
return both lists for editing and display.

Customers can book a configured Fitness category with a session, monthly, or
yearly plan and choose a first-visit date/time. The first visit reserves a
one-hour venue interval; overlapping pending or approved bookings are rejected.
Plan prices and coach fees are recalculated from the saved merchant
configuration when the booking is created. A yearly `freeMonths` offer
subtracts the category's monthly price for each free month from its yearly
price; a yearly percentage offer discounts the yearly price. A selected
coach's monthly fee is charged once for session/monthly plans and 12 times for
a yearly plan. The selected term is charged once at checkout (no automatic
renewal), and Fitness bookings store their category, term, coach, and price
breakdown on the booking record.
