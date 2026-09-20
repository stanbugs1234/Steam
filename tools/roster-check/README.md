# Roster check (read-only)

Finds roster problems before members start signing up. It only reads.

```
gcloud auth application-default login   # once, as yourself
cd tools/roster-check
npm install
npm run check
```

Fix what it reports in the Firebase console (roster entries) or in the app
(Member → Admin Tools → Member #, Roster points, Club points).
