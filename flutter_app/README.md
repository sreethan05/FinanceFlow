# FinanceFlow Flutter app

Flutter mobile client for the FinanceFlow API in the repository root. It includes email/password sign in and registration, a live cash-flow overview, recent transactions, transaction creation, monthly budgets, savings goals, and persistent authenticated sessions. Financial records and calculations stay in the PostgreSQL-backed API.

## Requirements

- Flutter 3.47 or newer (Dart 3.13+)
- Android Studio / Android SDK for Android, or Xcode on macOS for iOS
- The FinanceFlow API and PostgreSQL database running from the repository root

## Run on an Android emulator

Start the backend first from the repository root:

```powershell
npm install
npm run db:generate
npm run db:migrate
npm run dev
```

Then, from `flutter_app`, run:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

The Android debug manifest permits HTTP only for local development. Release builds disable cleartext network traffic; production API traffic must use HTTPS.

Build an installable Android debug APK with:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`. This debug build targets an Android emulator. For a physical phone, replace `10.0.2.2` with the laptop's LAN IP and rebuild after starting the backend on `0.0.0.0`. A release build needs a production HTTPS API URL and your own Android signing key.

`10.0.2.2` is the Android emulator's host-machine address. For a physical phone, start the backend bound to your network interface (for example `npx next dev --webpack --hostname 0.0.0.0`), set `API_BASE_URL` to the computer's LAN address (for example `http://192.168.1.20:3000`), and make sure the phone and computer share a network. For iOS Simulator, use `http://127.0.0.1:3000`.

The app uses the existing Auth.js credentials flow and keeps its session cookie in the platform application support directory. The API must be reachable over HTTPS in production. Avoid sending financial credentials over an untrusted network.

## Quality checks

```powershell
flutter analyze
flutter test
```

The backend remains in the repository root. See the root README for database configuration, API services, and server deployment notes.
