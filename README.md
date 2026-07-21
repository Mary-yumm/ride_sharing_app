# Ride Sharing App

A cross-platform Flutter ride-sharing application using Firebase, Google Maps, geolocation, and push notifications. The app includes a mobile client (Android), web support, and a small Cloud Functions backend under `functions/`.

**Features**
- Real-time location and matching (Geofire/Geolocation)
- Google Maps integration and Places lookup
- Firebase Authentication, Realtime Database / Firestore, and Cloud Messaging
- Background location and notifications
- Example serverless logic in [functions/index.js](functions/index.js)

**Prerequisites**
- Flutter SDK (stable)
- Android SDK (for Android builds) and/or Xcode (for iOS builds)
- Node.js + npm (for `functions/`)
- Firebase CLI (optional for deploying functions)

**Quick Start**

1. Clone the repo and install Dart/Flutter dependencies:

```bash
git clone <repository-url>
cd ride_sharing_app
flutter pub get
```

2. Configure Firebase (create a Firebase project and add Android/iOS/web apps). Place platform config files as directed by Firebase docs (`google-services.json` for Android, `GoogleService-Info.plist` for iOS).

3. Run the app locally:

```bash
# debug on a connected device or emulator
flutter run

# build for Android
flutter build apk

# build for web
flutter build web
```

5. (Optional) Run Cloud Functions locally:

```bash
cd functions
npm install
firebase emulators:start --only functions
```



---
