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
`http://192.168.1.14:3000`; override it with `API_BASE_URL` as above if your
computer's LAN address changes. For the Android emulator, the host machine is
usually reachable at `10.0.2.2`, so use
`http://10.0.2.2:3000`. A physical device needs the computer's reachable LAN
address, and both devices must be able to reach each other.

Firebase platform options are included in `lib/firebase_options.dart`. Google
sign-in also depends on the matching Firebase/OAuth configuration and backend
client ID; see the backend setup instructions.

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
