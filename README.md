# STEAM Club

Member app for the St. Edward Association of Men: news, events, volunteer
sign-ups, meeting check-in (QR), points, and the member directory. Flutter +
Firebase (Auth, Firestore, Storage, Crashlytics). iOS first, Android next.

## How it works

- **Sign-in:** phone (SMS code) or email/password. New members are *pending*
  until an admin approves them. Members preloaded from the roster are stored as
  `users/imported_*` placeholders; when someone signs up with a matching
  **phone** (SMS-verified) they are merged into it (points, dues, member #,
  join date carry over) and approved automatically. Email sign-ups always wait
  for an admin (Firebase doesn't verify emails), who merges them from Home.
- **Roles:** `member` and `admin`. Admins approve members, post news/events,
  manage volunteer slots, and maintain roster fields (member #, points, dues).
- **Data:** Firestore (`users`, `events` + `volunteerSlots`, `news`,
  `users/{uid}/attendance`), Storage (`profile_photos`, `news_images`).
  Everything is guarded by `firestore.rules` / `storage.rules`.

## Run it

```
flutter pub get
flutter run                 # a connected iPhone / simulator / Android device
flutter analyze && flutter test
```

Firebase project: `steam-club-app` (config is checked in: `lib/firebase_options.dart`,
`ios/Runner/GoogleService-Info.plist`, `android/app/google-services.json`).

## Before changing security rules

```
cd tools/rules-tests && npm install && npm test
```

Runs the rules against the local emulators. Deploy with
`firebase deploy --only firestore:rules,storage` only when it passes.

## Shipping

See [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) (store submission,
Firebase console settings) and [docs/RUNBOOK.md](docs/RUNBOOK.md) (running the
club's data day to day). `tools/roster-check` is a read-only pre-launch check of
the roster.
