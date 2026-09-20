# Security-rules tests

Runs `firestore.rules` and `storage.rules` against the local Firebase emulators
(nothing touches production). Run before **every** rules deploy:

```
cd tools/rules-tests
npm install     # first time only
npm test
```

Needs Java (for the Firestore emulator) and the Firebase CLI.
