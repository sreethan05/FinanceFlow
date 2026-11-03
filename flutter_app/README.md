# FinanceFlow Flutter app

Flutter mobile client for the FinanceFlow API in the repository root. It includes email/password sign in and registration, a live cash-flow overview, recent transactions, transaction creation, monthly budgets, savings goals, and persistent authenticated sessions. Financial records and calculations stay in the PostgreSQL-backed API.

## Requirements

- Flutter stable with Dart 3.4 or newer
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

Then, in `flutter_app`, generate the platform folders once and run:

```powershell
flutter create --org com.financeflow --project-name financeflow --platforms=android,ios .
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

For local Android development over plain HTTP, add `android:usesCleartextTraffic="true"` to the generated `<application>` element in `android/app/src/main/AndroidManifest.xml`. Keep this setting limited to local development; production API traffic must use HTTPS.

`10.0.2.2` is the Android emulator's host-machine address. For a physical phone, start the backend bound to your network interface (for example `npx next dev --webpack --hostname 0.0.0.0`), set `API_BASE_URL` to the computer's LAN address (for example `http://192.168.1.20:3000`), and make sure the phone and computer share a network. For iOS Simulator, use `http://127.0.0.1:3000`.

The app uses the existing Auth.js credentials flow and keeps its session cookie in the platform application support directory. The API must be reachable over HTTPS in production. Avoid sending financial credentials over an untrusted network.

## Quality checks

```powershell
flutter analyze
flutter test
```

The backend remains in the repository root. See the root README for database configuration, API services, and server deployment notes.
