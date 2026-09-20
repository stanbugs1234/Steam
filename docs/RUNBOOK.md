# STEAM Club — running the app day to day

For the club's admins. Anything technical is at the bottom.

## Approving new members
- **Home** shows every pending request for admins. Tap the check mark to approve or the X to deny.
- If the request matches someone already on the roster you'll see a red banner with **Merge & Approve** — use it, not plain Approve, so their roster points/dues/member # come along and no duplicate is created.
- Preloaded roster members who sign up with the phone or email on file are approved automatically.

## Fixing a member's info
Directory → tap the member → **Admin Tools**:
- Admin access, Member since (join date), Dues paid, New member badge
- **Member #**, **Roster points** (counts toward their total on Home/Profile), **Club points** (cumulative, shown under Membership)
- A member can edit only their own name, phone, photo, children and reminders. Everything else is admin-only.

## Meetings and points
- Anyone can open the event and tap the QR icon to start check-in (available from 30 minutes before to 2 hours after the event). Members scan it from **Home → Check In** for +1 point.
- To correct a mistake, adjust **Roster points** on the member.

## Volunteering
- Add an event, switch on "Volunteers needed", then add slots (Events → event → slots). Members sign up from the event page or the **Volunteer** tab; they get a reminder the day before.

## Duplicates / a member has two accounts
Keep the one they actually sign in with. Copy any missing values onto it (Admin Tools above), then delete the other in the Firebase console (Firestore → `users`). Never delete an account someone signs in with unless they've asked, or they lose their login.

## Roster entries not yet claimed
`users/imported_*` documents are members who haven't signed up yet. Before launch, run the check in `tools/roster-check` so emails are lowercase and phones look like `+15045551234`, otherwise those members won't be matched.

## Yearly points
"Roster points" are entered by admins; there is no automatic yearly reset. When a new year starts, update them from the roster sheet.

---

## For whoever maintains the app
- **Run / test:** `flutter run`, `flutter analyze && flutter test`. Security rules: `cd tools/rules-tests && npm test`.
- **Deploy rules:** `firebase deploy --only firestore:rules,storage` (only after the rules tests pass). Web pages: `firebase deploy --only hosting`.
- **Backups:** Firebase console → Firestore → Disaster recovery. To restore, create a new database from a backup (or read a point-in-time snapshot) and copy the documents you need back — never restore over the live database without exporting it first.
- **Crashes:** Firebase console → Crashlytics.
- **Costs:** Authentication → Usage (SMS), Firestore → Usage. Budget alerts are set in Google Cloud Billing.
- **Making someone an admin:** Directory → member → Admin Tools → Admin access. Keep at least two admins.
- **Release process:** see `docs/RELEASE_CHECKLIST.md`.
