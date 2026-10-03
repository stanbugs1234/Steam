# Roster award import (writes)

One-time import of member awards (Good Buddy, President's Award, Hall of Fame,
Rookie of the Year) from the roster spreadsheet's award column into Firestore.
Matches by Member #, not name. Safe to re-run — it unions newly-parsed years
into whatever a member already has rather than overwriting.

```
gcloud auth application-default login   # once, as yourself
cd tools/roster-import
npm install
node import.mjs path/to/exported-roster.csv            # dry run — prints the plan
node import.mjs path/to/exported-roster.csv --write     # commits
```

A row whose Member # matches no Firestore doc is printed at the end, not
written — fix it by hand (Member → Admin Tools) or re-run after the roster
import that creates that member's doc in the first place.

To grant an award for a new year going forward, no script is needed — an
admin can do it from the app (Member → Admin Tools → Good Buddy Award /
President's Award / Hall of Fame / Rookie of the Year).
