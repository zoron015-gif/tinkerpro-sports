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

   Create a dedicated database account for the API instead of using `root`.
   Run the schema migrations separately from the API. Use a migration account
   for DDL and a restricted runtime account for normal API traffic. For example,
   after creating the schema as an administrator:

   ```sql
   CREATE USER 'tinkerpro_api'@'localhost' IDENTIFIED BY 'use-a-unique-password';
   GRANT SELECT, INSERT, UPDATE, DELETE
     ON tinkerpro_sports.* TO 'tinkerpro_api'@'localhost';
   CREATE USER 'tinkerpro_migrator'@'localhost' IDENTIFIED BY 'another-unique-password';
   GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, REFERENCES
     ON tinkerpro_sports.* TO 'tinkerpro_migrator'@'localhost';
   ```

   Restrict the MySQL host to the API host (use its LAN address or a narrowly
   scoped network rule when MySQL is remote). Do not grant global privileges,
   `GRANT OPTION`, or use the administrator account as `DB_USER`.
2. In `backend`, copy `.env.example` to `.env` and set the values for your
   environment. Set `DB_HOST`, `DB_USER`, and `DB_PASSWORD` to the dedicated
   runtime API account, and set a long, random `JWT_SECRET`; the API will not
   start without it.
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
5. Install dependencies and apply database changes before starting the API:

   ```sh
   cd backend
   npm install
   npm run migrate
   npm run dev
   ```

   Set `DB_USER` and `DB_PASSWORD` to the migration account when running
   `npm run migrate`, then restore the runtime account credentials before
   starting the API. Applied migration versions are recorded in
   `schema_migrations`; a database-scoped lock prevents two deploy processes
   from applying the same version simultaneously. The first version wraps the
   existing idempotent upgrades for databases created before version tracking.
   Future schema changes should be added as new ordered versions rather than
   editing an already-applied migration. The API itself does not execute schema
   DDL on startup.

   Account registration and sign-in requests are limited to 100 requests per
   client IP and 10 per normalized email every 15 minutes. Email verification and
   password recovery are limited to 8 requests per normalized email in the same
   window. Limited requests return HTTP 429 with `Retry-After` and `RateLimit-*`
   headers. These limits are held in each API process; deployments with multiple
   instances should also enforce equivalent limits at a shared API gateway.

   `npm run dev` starts Node.js watch mode (`node --watch src/server.js`). For a
   regular start, use `npm start` (`node src/server.js`); `node server.js` is
   also supported as a compatibility entry point when run from `backend`.
   Authentication and merchant news endpoints are registered by
   `src/routes/auth_routes.js` and `src/routes/merchant_news_routes.js`;
   remaining route groups are still registered from `src/server.js` and can
   be extracted incrementally.

The health endpoint is `GET http://localhost:3000/health`. It checks both the
API and its MySQL connection. `npm run migrate` ensures the merchant,
messaging, booking, profile, news, review, and other upgraded schema is present.
Every API response includes an `X-Request-Id` header. When reporting an
unexpected error, include that support reference so it can be matched to the
backend error log. Internal server errors return a generic message; sensitive
configuration details should be checked in the backend environment, not shared
in a client error report.
Malformed stored JSON-array fields are logged with the field name and returned
as empty arrays so corrupted values are diagnosable without exposing their
contents in logs.

The public `GET /api/businesses` catalog uses a bounded, in-memory read-through
cache with a 30-second TTL. Concurrent requests for the same uncached catalog
share one database read. Merchant business/profile and news changes, as well as
venue heart and review changes, invalidate the cached catalog. This cache is
per API process: multiple backend instances have separate caches, and changes
made outside the API can remain visible for up to 30 seconds.

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

`POST /api/bookings` requires an `Idempotency-Key` header containing 16–100
letters, digits, or `.`, `_`, `:`, and `-`. The app generates one key for each
booking attempt and reuses it when retrying that same attempt. Repeating the
same request with the same customer and key returns the original booking
response; reusing the key with different booking details returns HTTP 409.
Generate a new key for each intentional booking. The migration command adds
the required columns and unique customer/key index to existing databases.

## Request validation

Mutating `/api/` endpoints accept JSON objects; arrays, primitives, `null`,
malformed JSON, and oversized JSON bodies are rejected. Authentication checks
email syntax, role values, name lengths, and password size before database or
password-hash work. Business and merchant-profile writes validate field types,
lengths, numeric ranges, URL protocols, list sizes, and nested rate periods.
Booking, payment, attendance, review, conversation, and business identifiers
must be positive safe integers; booking amounts, ratings, statuses, and dates
are also checked before writes.

API JSON responses use Express JSON serialization with HTML-sensitive
characters (`<`, `>`, and `&`) escaped as Unicode sequences, and responses set
`X-Content-Type-Options: nosniff`. JSON clients decode these sequences back to
the original text. Do not HTML-escape values before storing or returning them:
render user content as plain text in Flutter, and apply context-specific HTML
encoding if a future browser or WebView surface renders it as markup.

## Database integration tests

The default `npm test` suite uses isolated database fakes and does not require
MySQL. CI also runs the integration test against an ephemeral MySQL 8.4 service;
that job sets `MYSQL_TEST_REQUIRED=1`, so missing test-database configuration
fails rather than silently skipping the test. To run it locally, configure a
MySQL account that can create and drop databases, then set `MYSQL_TEST_HOST`,
`MYSQL_TEST_USER`, and `MYSQL_TEST_DATABASE` (a dedicated name ending in
`_test`). Set
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

The backend is the password authority for email/password accounts: registration,
login, and password reset all use the backend account store. Firebase is used
for Google identity sign-in and profile integrations, not as a second
email/password credential store. A password reset therefore takes effect for
the next backend sign-in without requiring a separate Firebase password update.

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
These settings are stored as JSON in `fitness_business_details`; the migration
command adds the columns for existing databases, and merchant/public business
responses return both lists for editing and display.

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
