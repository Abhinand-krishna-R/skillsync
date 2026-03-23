# SkillSync — No Cloud Functions (Spark Plan)

## What changed

Cloud Functions removed. All AI/logic now runs directly in Flutter.

| Was (Cloud Function) | Now (Flutter client) |
|---|---|
| `onUserCreate` trigger | `FirestoreService.setupNewUser()` called after sign up |
| `parseResume` Storage trigger | `ResumeService.pickAndParseResume()` + `GeminiService.extractSkillsFromText()` |
| `recalculateScore` Firestore trigger | `GeminiService.calculateScore()` called after skills change |
| `generateRoadmap` callable | `GeminiService.generateRoadmap()` called directly |
| `onModuleComplete` Firestore trigger | `FirestoreService.completeModule()` called on button tap |

## Files in this package

```
pubspec.yaml              ← cloud_functions removed, google_generative_ai added
lib/services/
  gemini_service.dart     ← all AI calls (Gemini 2.0 Flash)
  firestore_service.dart  ← all Firestore reads/writes
  resume_service.dart     ← file picker + text extraction
firestore.rules           ← deploy to Firebase Console
.env.example              ← copy to .env and add your Gemini key
```

## How to integrate

### 1. Replace pubspec.yaml
Copy `pubspec.yaml` from this package to your project root.

### 2. Add the 3 service files
Copy `lib/services/` into your project's `lib/services/`.

### 3. Add your Gemini key
```
# .env (in project root, same level as pubspec.yaml)
GEMINI_API_KEY=AIzaSy...your_key_here
```
Get key: https://aistudio.google.com/app/apikey

### 4. Update your auth screen — call setupNewUser after register
```dart
// In your registration success handler:
await FirestoreService().setupNewUser(
  uid: user.uid,
  email: user.email!,
  displayName: user.displayName,
);
```

### 5. Update your analyze screen — replace Cloud Function call
```dart
// OLD (Cloud Function):
// await FirebaseFunctions.instance.httpsCallable('generateRoadmap').call(...)

// NEW (direct Gemini call):
await FirestoreService().setTargetRoleAndGenerateRoadmap(
  role: 'Frontend Developer',
  requiredSkills: ['React', 'JavaScript', 'CSS'],
  userSkills: currentSkills,
);
```

### 6. Update your roadmap screen — replace module complete trigger
```dart
// OLD (wrote to Firestore and triggered Cloud Function):
// await moduleRef.update({'status': 'completed'});

// NEW (handles everything client-side):
await FirestoreService().completeModule(
  moduleId: module.id,
  moduleSkills: module.skills,
  moduleOrder: module.order,
  currentUserSkills: currentSkills,
  requiredSkills: requiredSkills,
);
```

### 7. Deploy Firestore rules
```bash
firebase deploy --only firestore
```

### 8. Run
```bash
flutter pub get
flutter run
```

## Delete the functions folder
You no longer need it. Remove it to keep things clean:
```bash
rm -rf functions/
```

## Firebase plan
Stay on **Spark (free)**. No upgrades needed.
Gemini API has its own free tier (60 requests/minute).
