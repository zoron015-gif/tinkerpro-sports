# TinkerPro Sports

TinkerPro Sports is a Flutter app for discovering sports venues and booking
facilities. Customers can manage bookings, saved venues, reviews, and messages;
merchants can manage their business profiles, venues, bookings, and news posts.
The app uses Firebase for sign-in integrations and a Node.js/Express API backed
by MySQL for application data.

## Run locally

Prerequisites: Flutter and Dart versions compatible with `pubspec.yaml`, Node.js
20 or newer, and MySQL 8 or newer. Set up the API, database, and backend
environment variables using [backend/README.md](backend/README.md) first.

From the project root, fetch Flutter packages and start the app:

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<host-reachable-from-device>:3000
```

The API listens on port 3000 by default. The app's compiled-in API URL is
`http://192.168.1.50:3000`; override it with `API_BASE_URL` as above if your
computer's LAN address changes. For the Android emulator, the host machine is
usually reachable at `10.0.2.2`, so use
`http://10.0.2.2:3000`. A physical device needs the computer's reachable LAN
address, and both devices must be able to reach each other.

Firebase platform options are included in `lib/firebase_options.dart`. Google
sign-in also depends on the matching Firebase/OAuth configuration and backend
client ID; see the backend setup instructions.

## Architecture and quality checks

The Flutter client keeps its shared HTTP/authentication primitives in
`lib/auth_api.dart` and groups booking, venue, messaging, and saved-item API
operations in `lib/features/*/data/`. Authentication UI and session
orchestration live under `lib/features/auth/`, and startup injects the app
builder rather than importing the app shell back into the bootstrap module.
The Express API uses shared infrastructure and normalizers under
`backend/src/`; authentication and merchant news routes are registered from
dedicated modules under `backend/src/routes/`. The API server no longer runs
schema changes on startup: apply them explicitly with `npm run migrate` from
`backend` before starting or deploying the API. Applied schema migration
versions are recorded in MySQL, and DDL privileges should be kept separate
from the runtime API account where possible; see
[backend setup](backend/README.md).

Email/password credentials and password recovery are owned by the backend.
Firebase is used for Google identity sign-in and related profile integrations,
not as a parallel email/password store.

The dependency-scan GitHub Actions workflow checks Flutter analysis and the
focused Flutter API contract tests, the backend test suite and dependency
audit, and a MySQL integration test against MySQL 8.4. Run the same checks
locally with:

```sh
flutter analyze
flutter test test/auth_service_test.dart test/app_startup_test.dart test/messages_api_auth_test.dart test/news_feed_navigation_test.dart
cd backend
npm test
npm run test:integration
```

The full Flutter widget suite has known unrelated failures, so CI gates
analysis and focused authentication, startup, API, and news-feed interaction
tests instead. The MySQL integration test needs a dedicated test database
configuration; see the backend README. Other backend tests use isolated fakes
and need no MySQL.

## UI styling

Use the shared colors, spacing, radii, and text styles in
`lib/app_design_system.dart`. The application-wide Material theme is defined in
`lib/app_theme.dart`; reusable card and filter styles live in
`lib/app_card_styles.dart` and `lib/filter_panel_style.dart`.

## Match notifications

On Android and iOS, open **Profile > Upcoming match** and turn on **Match
notifications**. The operating system asks for notification permission when the
user enables the switch; Android may also request exact-alarm permission. The
switch can be turned off at any time, which cancels pending match alerts.
Approved bookings are scheduled in the device's local time zone and
resynchronized when the profile loads. Notifications are scheduled by the
operating system, so they can appear while the app is on another page or in the
background.
