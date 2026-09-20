// Read-only roster health check. Run it yourself, signed in as you:
//
//   gcloud auth application-default login      (once)
//   cd tools/roster-check && npm install && npm run check
//
// It never writes anything. It reports the problems that stop a preloaded
// member from being matched to their roster entry when they sign up, and the
// members who signed up before roster values were carried over.
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

initializeApp({ credential: applicationDefault(), projectId: 'steam-club-app' });
const db = getFirestore();

const E164_US = /^\+1\d{10}$/;
const snap = await db.collection('users').get();
const users = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
const placeholders = users.filter((u) => u.id.startsWith('imported_'));
const real = users.filter((u) => !u.id.startsWith('imported_'));

const problems = [];
const add = (who, issue) => problems.push({ who: `${who.name ?? '?'} (${who.id})`, issue });

for (const p of placeholders) {
  const email = p.email ?? '';
  if (email && email !== email.trim().toLowerCase()) add(p, `email "${email}" must be lowercase with no spaces or it will never match a sign-in`);
  const phone = p.phone ?? '';
  if (phone && !E164_US.test(phone)) add(p, `phone "${phone}" must look like +15045551234 to match phone sign-in`);
  if (!email && !phone) add(p, 'has neither email nor phone, so it can never be matched');
  if (p.status !== 'approved') add(p, `status is "${p.status}"; only approved placeholders can be claimed`);
}

const dupes = (key) => {
  const seen = new Map();
  for (const p of placeholders) {
    const v = (p[key] ?? '').toString().trim().toLowerCase();
    if (!v) continue;
    seen.set(v, [...(seen.get(v) ?? []), p]);
  }
  for (const [v, list] of seen) if (list.length > 1) for (const p of list) add(p, `${key} "${v}" is shared with ${list.length - 1} other roster entr${list.length === 2 ? 'y' : 'ies'}`);
};
dupes('email');
dupes('phone');

for (const u of real) {
  if (u.mergedFromId && u.memberNumber == null && u.yearlyPoints == null && u.clubPoints == null && !u.duesPaid) {
    add(u, `merged from ${u.mergedFromId} but has no member #, points or dues — roster values were probably lost; re-enter them from the roster sheet`);
  }
}

console.log(`Roster entries still unclaimed: ${placeholders.length}`);
console.log(`Real member accounts: ${real.length}`);
console.log(problems.length ? `\n${problems.length} thing(s) to fix:\n` : '\nNo problems found.');
for (const { who, issue } of problems) console.log(`- ${who}: ${issue}`);
