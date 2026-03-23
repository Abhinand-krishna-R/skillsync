# SkillSync — Firebase Setup Guide

Complete step-by-step instructions to connect the app to Firebase.

---

## 1. Create Firebase Project

1. Go to [https://console.firebase.google.com](https://console.firebase.google.com)
2. Click **Add project** → name it `skillsync`
3. Enable **Google Analytics** (recommended)
4. Wait for provisioning to complete

---

## 2. Add Apps to Firebase

### Android
1. In Firebase Console → Project Overview → **Add app** → Android
2. Package name: `com.skillsync.app`
3. Download `google-services.json`
4. Place it at: `android/app/google-services.json`

### iOS
1. In Firebase Console → **Add app** → iOS
2. Bundle ID: `com.skillsync.app`
3. Download `GoogleService-Info.plist`
4. Open Xcode → drag file into `ios/Runner/` (check "Copy if needed")

---

## 3. Run FlutterFire Configure

This auto-generates `lib/firebase_options.dart` for all platforms:

```bash
# Install FlutterFire CLI if not already installed
dart pub global activate flutterfire_cli

# In your Flutter project root
flutterfire configure --project=skillsync-XXXXX
```

This creates `lib/firebase_options.dart` — do NOT commit this file with real keys
if your repo is public (add to .gitignore).

---

## 4. Enable Firebase Services

### Authentication
1. Firebase Console → **Authentication** → Get started
2. Sign-in methods → Enable **Email/Password**
3. (Optional) Enable **Google** sign-in

### Firestore
1. Firebase Console → **Firestore Database** → Create database
2. Start in **Production mode**
3. Choose region closest to your users (e.g., `asia-south1` for India)
4. After creation, go to **Rules** tab and paste the contents of `firestore.rules`

### Storage
1. Firebase Console → **Storage** → Get started
2. Start in **Production mode**
3. After creation, go to **Rules** tab and paste the contents of `storage.rules`

---

## 5. Deploy Firestore Rules & Indexes

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Initialize (in project root)
firebase use --add   # select your project

# Deploy rules and indexes
firebase deploy --only firestore:rules,firestore:indexes,storage
```

---

## 6. Get Gemini API Key

1. Go to [https://aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey)
2. Create a new API key for your Firebase project
3. Copy the key — you'll need it for Cloud Functions

---

## 7. Deploy Cloud Functions

```bash
cd functions

# Install dependencies
npm install

# Set Gemini API key as Firebase config
firebase functions:config:set gemini.key="YOUR_GEMINI_API_KEY_HERE"

# Build TypeScript
npm run build

# Deploy all functions
cd ..
firebase deploy --only functions
```

### What each function does:
| Function | Trigger | Purpose |
|---|---|---|
| `onUserCreate` | Auth: new user | Seeds Firestore user document + default modules |
| `parseResume` | Storage: file upload | Calls Gemini to extract skills from PDF/DOCX |
| `recalculateScore` | Firestore: skills write | Computes readiness score vs target role |
| `onModuleComplete` | Firestore: module status→done | Applies skill boosts, unlocks next module |
| `generateRoadmap` | Callable (from app) | Calls Gemini to create personalised 5-module plan |

---

## 8. Firestore Data Structure

```
users/
  {uid}/
    name: "Abhinand"
    email: "user@email.com"
    score: 72                        ← written by recalculateScore function
    targetRoleSlug: "flutter_developer"
    targetRoleLabel: "Flutter Developer"
    suggestedRoleSlug: "flutter_developer"
    matchedSkills: ["Flutter", "Dart"]   ← written by recalculateScore
    weakSkills: ["Firebase"]
    missingSkills: ["Testing", "CI/CD"]
    resumeUrl: "https://..."
    createdAt: Timestamp
    updatedAt: Timestamp

    skills/
      {skillId}/
        name: "Flutter"
        level: 82
        category: "Mobile"
        source: "resume"            ← "resume" | "manual" | "module"
        addedAt: Timestamp

    modules/
      m1/
        title: "Figma Fundamentals"
        hours: 6
        order: 0
        tags: ["UI", "Design"]
        status: "done"              ← "locked" | "active" | "done"
        progress: 100
        skillBoost: { "Figma": 25, "UI Design": 15 }

    notifications/
      {notifId}/
        icon: "award"
        colorValue: 4283887616
        title: "Module complete!"
        message: "Figma Fundamentals done."
        read: false
        createdAt: Timestamp
```

---

## 9. Android Build Config

Ensure your `android/app/build.gradle` has:

```groovy
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
        multiDexEnabled true
    }
}
```

And `android/build.gradle`:
```groovy
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.1'
    }
}
```

---

## 10. Run the App

```bash
# Get Flutter dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build release APK
flutter build apk --release
```

---

## Local Development with Emulators

Use Firebase Emulator Suite for development without hitting production:

```bash
firebase emulators:start
```

Add this to `main.dart` (remove before production):
```dart
// Connect to emulators in debug mode
if (kDebugMode) {
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
}
```

---

## Environment Variables

Never commit real API keys. Use:
- Firebase project: `firebase functions:config:set gemini.key="KEY"`
- For CI/CD: use GitHub Actions secrets

---

## Troubleshooting

| Issue | Fix |
|---|---|
| `firebase_options.dart` not found | Run `flutterfire configure` |
| Functions not triggering | Check Firebase Console → Functions logs |
| Gemini API errors | Verify key is set: `firebase functions:config:get` |
| Firestore permission denied | Check rules are deployed and user is authenticated |
| Resume not parsing | Check Storage rules allow file upload, check Functions logs |
