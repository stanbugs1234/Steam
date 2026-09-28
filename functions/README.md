# Cloud Functions — push notifications

Plain JavaScript (ESM, `"type": "module"`), no TypeScript, no bundler — same
style as `tools/roster-check` and `tools/rules-tests`. 2nd-gen Cloud
Functions (`firebase-functions/v2`), Node 22 runtime.

## Layout

- `index.mjs` — deploy entry point; re-exports every trigger.
- `src/lib/admin.mjs` — single shared Admin SDK app (`db`, `messaging`).
- `src/onSlotOpenedUp.mjs` — `events/{eventId}/volunteerSlots/{slotId}` onWritten:
  notifies topic `volunteer-openings` when a slot goes from full back to open.
- `src/onAnnouncementCreated.mjs` — `events/{eventId}` and `news/{postId}` onCreated:
  both notify topic `announcements`.
- `src/onPendingSignup.mjs` — `users/{uid}` onWritten: notifies topic
  `admin-alerts` the moment a user newly becomes `status: 'pending'`.
- `src/onApproved.mjs` — `users/{uid}` onWritten: on the `pending` -> `approved`
  transition, sends a personal `sendEachForMulticast()` to every token in
  `users/{uid}/fcmTokens`, then deletes any token that comes back
  unregistered/invalid.

Each trigger file exports both the raw Cloud Function (for deploy) and a
plain `handleXxx(event, { db, messaging })` function containing the actual
logic, decoupled from the Admin SDK singleton. That's what the tests exercise.

## Tests

```
cd functions
npm install     # first time only
npm test
```

Runs fully offline — no emulator, no credentials, no network calls.
`firebase-functions-test`'s offline mode builds real Admin SDK
`DocumentSnapshot` objects (so `.exists`/`.data()` behave exactly like
production), and `test/fakes.mjs` provides in-memory `db`/`messaging`
stand-ins that the pure `handleXxx` functions are called with directly.
Covers, per trigger: the transition that should fire, the closest
neighboring transitions that should NOT fire, and (for `onApproved`) the
stale-token cleanup path. See `test/triggers.test.mjs`.

## Integration notes (for firebase.json)

- Source directory: `functions/` (this directory), `main: index.mjs`.
- Module system: ESM (`"type": "module"` in `functions/package.json`),
  plain `.mjs` files, no build step — codebase field should point straight
  here (no `predeploy` build command needed).
- Runtime: Node 22 (`engines.node: "22"` in `package.json`), matches
  `firebase-admin@^13.10.0` (which needs `node >= 18`) and
  `firebase-functions@^7.4.0`.
- Topics used (must exist as FCM topics — clients subscribe to these, no
  server-side topic creation needed): `volunteer-openings`, `announcements`,
  `admin-alerts`.
- Reads/writes `users/{uid}/fcmTokens/{token}` via the Admin SDK only
  (bypasses `firestore.rules`).
