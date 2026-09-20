# STEAM Club — release checklist

Work top to bottom. ✅ = already done in the code; ☐ = something only you can do (consoles, accounts, decisions).

## 0. Before anything else

- ☐ **Pick the club support email** and put it in `lib/core/legal_links.dart` (`supportEmail`) and in the three `[club support email …]` spots in `public/*.html`. The app hides its "Contact the club" button until this is set.
- ☐ **Read the drafts in `public/`** (privacy, terms, support). They are plain-language drafts, not legal advice — have a club officer (or an attorney) read them, especially the children's-information section.
- ☐ Decide the public name. The code uses **STEAM Club** everywhere; the App Store name must be unique, so have a second choice ready (e.g. "STEAM Club – St. Edward").

## 1. Data safety (do this first — members' first sign-ups depend on it)

- ✅ Roster values (member #, points, dues, new-member badge) now carry over when a preloaded member signs up.
- ☐ Run the roster check (read-only): `cd tools/roster-check && npm install && npm run check`. Fix what it lists in the Firebase console — lowercase emails, `+1XXXXXXXXXX` phones, no duplicates.
- ☐ Any member who signed up **before** this fix may have lost roster values (the check lists them). Re-enter them from the roster sheet: Directory → member → Admin Tools → Member #, Roster points, Club points, Dues paid.
- ☐ Run the rules tests, then deploy rules (they are **not deployed yet** — the live Firestore/Storage rules are older than this repo's):
  ```
  cd tools/rules-tests && npm install && npm test        # expect: ALL PASSED
  cd ../.. && firebase deploy --only firestore:rules,storage,firestore:indexes
  ```
  **Order matters:** the new rules require the new app build (check-in needs a secret code in the QR; email sign-ups are pending). Ship the app build to testers **first**, then deploy the rules. Older builds' check-in will be refused after the deploy.
- ☐ Publish the legal pages: `firebase deploy --only hosting` → https://steam-club-app.web.app/privacy.html (also `terms.html`, `support.html`). Open all three on your phone.

## 2. Firebase console (project `steam-club-app`)

| ☐ | Where | Setting |
|---|-------|---------|
| ☐ | Authentication → Sign-in method | Email/Password **and** Phone both enabled |
| ☐ | Authentication → Settings → **SMS region policy** | Allow **United States** (and Canada if needed) only. Stops SMS-pumping fraud, the main way phone sign-in gets expensive |
| ☐ | Authentication → Sign-in method → Phone → **Phone numbers for testing** | Add a fictitious number + fixed code for App Review (below) |
| ☐ | Authentication → Settings → User actions | Leave "Email enumeration protection" on |
| ☐ | Project settings → Usage and billing | Confirm the plan; if on Blaze set a **budget alert** (e.g. $10 / $25) so a surprise shows up in email |
| ☐ | Firestore → Disaster recovery | Turn on **scheduled backups** (daily, 7-day retention) and/or point-in-time recovery |
| ☐ | Google Cloud console → APIs & Services → Credentials | Restrict each Firebase API key: iOS key → bundle ID `com.stedwardsteamclub.app`; Android key → package `com.stedwardsteamclub.app` + SHA-1; web key → your domains only |
| ☐ | Crashlytics | Open it once so it's enabled for the project |
| ☐ | Members | Make sure **at least two** people are admins |

**App Check** (blocks copies of the app from using your backend) is deliberately *not* switched on for launch. Turning it on needs a new app release, the Apple App Attest capability, and console registration, and enforcing it before every member has updated would lock people out. Plan it for a follow-up release.

## 3. iPhone build and TestFlight

- ✅ iPhone-only, portrait, privacy manifest, Crashlytics symbol upload, no unused push code.
- ☐ Xcode → open `ios/Runner.xcworkspace` → Signing & Capabilities: team `UGSW9JFYRB`, "Automatically manage signing".
- ☐ Bump the build number for every upload: `flutter build ipa --release --build-number <N> --export-options-plist=ios/ExportOptions.plist` (upload with Transporter or Xcode Organizer).
- ☐ In App Store Connect create the app record (bundle ID `com.stedwardsteamclub.app`), then TestFlight:
  1. **Internal** (you + 3–5 members): include one **preloaded roster member** and one **brand-new signup**.
  2. **External** (25–50 members, about a week): collect crashes in Crashlytics.
- Test list on a real phone: sign up with a roster **phone** → lands in the app already approved (an **email** sign-up waits for an admin, who merges it) with points/dues/member # intact; a brand-new signup → "You're almost in", admin approves from Home; admin opens the event's check-in QR and a member's scan gives exactly 1 point (a second scan is refused; a pending user can't check in); volunteer sign-up + reminder; edit profile + photo; share a news post to Messages; delete a **throwaway** account; large text size and dark mode; airplane mode shows a friendly message with **Try again**.

## 4. App Store Connect listing

- ☐ Name, subtitle, description, keywords, **category** (Lifestyle or Social Networking), copyright.
- ☐ **Privacy Policy URL** `https://steam-club-app.web.app/privacy.html` · **Support URL** `https://steam-club-app.web.app/support.html`.
- ☐ Screenshots: iPhone 6.9″ and 6.5″ (Home, News, Events, Volunteer, Directory, Profile). Use a demo account, not real members' data.
- ☐ Age rating questionnaire: no chat, no web browsing, no purchases, no ads. Profile photos and names are visible to other *approved members only* — answer accordingly.
- ☐ **App Privacy** ("nutrition labels"). Data **linked to the user**, used for **App Functionality**, **not used for tracking**: Name, Email Address, Phone Number, Photos (profile photo), Other User Content (children's names and grades), User ID. Data **not linked**: Crash Data (diagnostics). Tracking: **No**. (Matches `ios/Runner/PrivacyInfo.xcprivacy`.)
- ☐ Export compliance: already answered in the app (`ITSAppUsesNonExemptEncryption` = false).
- ☐ Release: choose **manual release** and **phased release for automatic updates**.

### App Review notes (paste into "Notes")

> STEAM Club is a private member app for the St. Edward Association of Men (a parish men's club). New accounts are approved by an admin, so we've provided an already-approved demo member.
>
> **Sign in with email and password:** `<demo email>` / `<demo password>`
> (Phone sign-in also works with the test number `<+1 555 …>`, code `<123456>`.)
>
> Account deletion: Profile tab → Delete Account (requires a sign-in within the last few minutes).
> Camera is used only for profile photos and scanning a meeting check-in QR code.

Create the demo login first:
1. Firebase console → Authentication → **Add user** (email + password). Copy its **User UID**.
2. Firestore → `users` → add a document with that UID as the ID and fields: `name` "App Review", `email` (same), `phone` "", `kids` (array, empty), `role` "member", `status` "approved", `createdAt` (timestamp), `remindersEnabled` true, `duesPaid` false, `isNewMember` false.
3. Optional: add a few fake members/events so screenshots aren't empty. Delete the demo account after approval if you like.

## 5. Android (right after iPhone)

- ✅ Firebase app registered for `com.stedwardsteamclub.app`, `google-services.json` updated, Crashlytics plugin added, `bundleRelease` refuses to build without your keystore, debug and release builds both compile.
- ☐ Add **SHA-1 and SHA-256** of your **upload key** *and* the **Play App Signing key** (Play Console → Setup → App signing) to the Android app in Firebase project settings — phone sign-in fails on release builds without them. Re-download `google-services.json` afterwards.
- ☐ Keep `android/key.properties` and the keystore backed up somewhere safe and **out of git** (already git-ignored). Losing the keystore means you can't update the app.
- ☐ `flutter build appbundle --release --build-number <N>` → upload to a Play Console **internal testing** track.
- ☐ Play Console: Data safety form (same answers as the privacy labels above), content rating, target audience (**adults**, not children), privacy policy URL, store listing.
- Heads-up: Flutter reports that the project's Android Gradle Plugin (8.11.1) and Kotlin (2.2.20) will soon fall out of support. Plan an upgrade after launch; it isn't blocking.

## 6. Day of launch

- ☐ Tag the release commit (`git tag v1.0.0 && git push --tags`) and note the build number.
- ☐ Tell members: how to sign in, that new members wait for approval, where Help is (Profile → Help & support).
- ☐ Watch for the first 48 hours: Crashlytics, Firestore usage, Authentication → Usage (SMS volume), and the pending-approvals list on Home.

## 7. Rollback / if something goes wrong

- Bad app build: stop phased release in App Store Connect (or halt the rollout in Play Console); ship a fixed build with a higher build number.
- Bad rules deploy: `git revert` the rules commit → `firebase deploy --only firestore:rules,storage`. Always run `npm test` in `tools/rules-tests` first.
- Bad data change: restore from the scheduled backup / point-in-time recovery (see `docs/RUNBOOK.md`).
- SMS bill spike: Authentication → Sign-in method → disable **Phone** (members can still use email), then investigate.
