// One-time import of member awards from the roster spreadsheet's award
// column (Good Buddy, President's Award, Hall of Fame, Rookie of the Year)
// into Firestore.
//
//   gcloud auth application-default login      (once)
//   cd tools/roster-import && npm install
//   node import.mjs <path-to-exported-csv>                 (dry run — prints the plan, writes nothing)
//   node import.mjs <path-to-exported-csv> --write          (commits)
//
// Matches each spreadsheet row to a Firestore user doc by Member # (not by
// name — two different members can share a name, e.g. two "Tony
// Catalanotto"s in this roster). Unions newly-parsed years into whatever a
// member already has rather than overwriting, so re-running this script (or
// running it after an admin has already granted an award in-app) never
// loses or duplicates data.
import { readFileSync } from 'node:fs';
import { parse } from 'csv-parse/sync';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const AWARD_FIELDS = {
  GB: 'goodBuddyYears',
  PA: 'presidentsAwardYears',
  HOF: 'hallOfFameYears',
  ROTY: 'rookieOfTheYearYears',
};

const csvPath = process.argv[2];
const write = process.argv.includes('--write');
if (!csvPath) {
  console.error('Usage: node import.mjs <path-to-exported-csv> [--write]');
  process.exit(1);
}

// A Member # sometimes carries the member's previous number in parens, e.g.
// "962 (954)" or "1048 (80)" — only the current (leading) number is the join
// key into Firestore.
function cleanMemberNumber(raw) {
  const value = (raw ?? '').trim();
  if (!value) return null;
  const match = value.match(/^([^\s(]+)/);
  return match ? match[1] : value;
}

// "GB - 2023, PA - 2024, HOF - 2026" -> [['GB','2023'] mapped fields...].
// Each matched year-text is kept verbatim (not parsed to a number), so an
// irregular value like "2006/10" imports as-is rather than being guessed at
// — fixable afterward from the admin screen.
function parseAwards(raw) {
  const text = (raw ?? '').trim();
  if (!text) return {};
  const result = {};
  for (const piece of text.split(',')) {
    const match = piece.trim().match(/^(GB|PA|HOF|ROTY)\s*-\s*(.+)$/i);
    if (!match) continue;
    const field = AWARD_FIELDS[match[1].toUpperCase()];
    const year = match[2].trim();
    (result[field] ??= []).push(year);
  }
  return result;
}

const rows = parse(readFileSync(csvPath, 'utf8'), { relax_column_count: true });
// Row 0: title, row 1: legend, row 2: column group labels, row 3: the real
// header. Data starts at row 4.
const byMemberNumber = new Map();
for (const row of rows.slice(4)) {
  const memberNumber = cleanMemberNumber(row[2]);
  const name = `${row[4] ?? ''} ${row[5] ?? ''}`.trim();
  const awards = parseAwards(row[12]);
  if (!memberNumber || Object.keys(awards).length === 0) continue;
  byMemberNumber.set(memberNumber, { name, awards });
}

console.log(`Parsed ${byMemberNumber.size} row(s) with at least one award.`);
if (!write) console.log('\n--- DRY RUN: pass --write to actually commit these changes ---\n');

initializeApp({ credential: applicationDefault(), projectId: 'steam-club-app' });
const db = getFirestore();
const usersRef = db.collection('users');

const unmatched = [];
let updated = 0;

for (const [memberNumber, { name, awards }] of byMemberNumber) {
  const snap = await usersRef.where('memberNumber', '==', memberNumber).get();
  if (snap.empty) {
    unmatched.push({ memberNumber, name });
    continue;
  }
  for (const doc of snap.docs) {
    const current = doc.data();
    const merged = {};
    for (const field of Object.values(AWARD_FIELDS)) {
      const existing = Array.isArray(current[field]) ? current[field] : [];
      const incoming = awards[field] ?? [];
      merged[field] = [...new Set([...existing, ...incoming])];
    }
    const changed = Object.values(AWARD_FIELDS).some(
      (field) => JSON.stringify(merged[field]) !== JSON.stringify(Array.isArray(current[field]) ? current[field] : []),
    );
    if (!changed) continue;

    console.log(`${write ? 'Writing' : 'Would write'} ${doc.id} (#${memberNumber} ${name}):`, merged);
    if (write) await doc.ref.set(merged, { merge: true });
    updated++;
  }
}

console.log(`\n${write ? 'Updated' : 'Would update'} ${updated} Firestore doc(s).`);
if (unmatched.length) {
  console.log(`\n${unmatched.length} row(s) had no matching Firestore doc by Member #:`);
  for (const { memberNumber, name } of unmatched) {
    console.log(`  #${memberNumber} ${name}`);
  }
}
