import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, Timestamp, serverTimestamp } from 'firebase/firestore';
import { ref, uploadBytes, deleteObject } from 'firebase/storage';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const env = await initializeTestEnvironment({
  projectId: 'demo-steam-rules',
  firestore: { rules: readFileSync(`${root}/firestore.rules`, 'utf8'), host: '127.0.0.1', port: 8080 },
  storage: { rules: readFileSync(`${root}/storage.rules`, 'utf8'), host: '127.0.0.1', port: 9199 },
});

const minutes = (n) => Timestamp.fromDate(new Date(Date.now() + n * 60_000));
const joined = Timestamp.fromDate(new Date('2019-03-10T12:00:00Z'));
const ROSTER = { memberNumber: '77', yearlyPoints: 12, clubPoints: 30, duesPaid: true, isNewMember: false };

await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  const base = { email: 'm@x.com', phone: '5045551234', kids: [], status: 'approved', role: 'member', yearlyPoints: 3, duesPaid: false, memberNumber: '12', remindersEnabled: true, photoUrl: null, createdAt: Timestamp.now() };
  await setDoc(doc(db, 'users/member1'), { ...base, name: 'Member One' });
  await setDoc(doc(db, 'users/member2'), { ...base, name: 'Member Two' });
  await setDoc(doc(db, 'users/admin1'), { ...base, name: 'Admin', role: 'admin' });
  await setDoc(doc(db, 'users/imported_5_Pat'), { ...base, ...ROSTER, name: 'Pat', email: 'pat@x.com', phone: '+15045550001', createdAt: joined });
  await setDoc(doc(db, 'events/open'), { title: 'Monthly Meeting', description: '', location: '', startTime: minutes(-10), endTime: minutes(50), needsVolunteers: false, checkInEnabled: true, checkedInUserIds: [] });
  await setDoc(doc(db, 'events/closed'), { title: 'Not Yet', description: '', location: '', startTime: minutes(-10), endTime: minutes(50), needsVolunteers: false, checkInEnabled: false, checkedInUserIds: [] });
  await setDoc(doc(db, 'events/old'), { title: 'Last Year', description: '', location: '', startTime: minutes(-60 * 24 * 300), endTime: minutes(-60 * 24 * 300 + 60), needsVolunteers: false, checkInEnabled: true, checkedInUserIds: [] });
});

let failures = 0;
async function check(name, promise) {
  try { await promise; console.log('PASS', name); } catch (e) { failures++; console.log('FAIL', name, '-', String(e.message).slice(0, 140)); }
}

const member = env.authenticatedContext('member1');
const admin = env.authenticatedContext('admin1');
const mdb = member.firestore();
const adb = admin.firestore();

// ---- users: self-updates -------------------------------------------------
await check('member edits own name', assertSucceeds(updateDoc(doc(mdb, 'users/member1'), { name: 'New Name' })));
await check('member edits name+phone+kids+photoUrl null+reminders', assertSucceeds(updateDoc(doc(mdb, 'users/member1'), { name: 'N2', phone: '5045559999', kids: [{ name: 'K', grade: '1st Grade' }], photoUrl: null, remindersEnabled: false })));
await check('member cannot edit yearlyPoints', assertFails(updateDoc(doc(mdb, 'users/member1'), { yearlyPoints: 999 })));
await check('member cannot edit clubPoints', assertFails(updateDoc(doc(mdb, 'users/member1'), { clubPoints: 999 })));
await check('member cannot set duesPaid', assertFails(updateDoc(doc(mdb, 'users/member1'), { duesPaid: true })));
await check('member cannot set memberNumber', assertFails(updateDoc(doc(mdb, 'users/member1'), { memberNumber: '1' })));
await check('member cannot make self admin', assertFails(updateDoc(doc(mdb, 'users/member1'), { role: 'admin' })));
await check('member cannot change status', assertFails(updateDoc(doc(mdb, 'users/member1'), { status: 'pending' })));
await check('member cannot edit another member', assertFails(updateDoc(doc(mdb, 'users/member2'), { name: 'Hax' })));
await check('admin sets member duesPaid + points', assertSucceeds(updateDoc(doc(adb, 'users/member2'), { duesPaid: true, yearlyPoints: 10, memberNumber: '9' })));
await check('member cannot delete another member', assertFails(deleteDoc(doc(mdb, 'users/member2'))));

// ---- users: signup (create) ---------------------------------------------
const plain = (extra = {}) => ({ name: 'New Person', email: 'n@x.com', phone: '+15045557777', kids: [], photoUrl: null, role: 'member', status: 'pending', createdAt: serverTimestamp(), mergedFromId: null, remindersEnabled: true, duesPaid: false, isNewMember: false, memberNumber: null, clubPoints: null, yearlyPoints: null, ...extra });
const signup = (uid, claims = {}) => env.authenticatedContext(uid, claims).firestore();

await check('pending signup with default fields', assertSucceeds(setDoc(doc(signup('s1'), 'users/s1'), plain())));
await check('pending signup cannot set yearlyPoints', assertFails(setDoc(doc(signup('s2'), 'users/s2'), plain({ yearlyPoints: 999 }))));
await check('pending signup cannot set clubPoints', assertFails(setDoc(doc(signup('s3'), 'users/s3'), plain({ clubPoints: 5 }))));
await check('pending signup cannot set duesPaid', assertFails(setDoc(doc(signup('s4'), 'users/s4'), plain({ duesPaid: true }))));
await check('pending signup cannot set memberNumber', assertFails(setDoc(doc(signup('s5'), 'users/s5'), plain({ memberNumber: '1' }))));
await check('pending signup cannot backdate createdAt', assertFails(setDoc(doc(signup('s6'), 'users/s6'), plain({ createdAt: joined }))));
await check('pending signup cannot add unknown fields', assertFails(setDoc(doc(signup('s7'), 'users/s7'), plain({ isAdmin: true }))));
await check('pending signup cannot be admin', assertFails(setDoc(doc(signup('s8'), 'users/s8'), plain({ role: 'admin' }))));
await check('pending signup cannot claim a placeholder', assertFails(setDoc(doc(signup('s9'), 'users/s9'), plain({ mergedFromId: 'imported_5_Pat' }))));
await check('cannot create a doc for someone else', assertFails(setDoc(doc(signup('s10'), 'users/someoneelse'), plain())));

const merge = (extra = {}) => plain({ status: 'approved', mergedFromId: 'imported_5_Pat', createdAt: joined, ...ROSTER, ...extra });
await check('phone merge carries the roster values', assertSucceeds(setDoc(doc(signup('m1', { phone_number: '+15045550001' }), 'users/m1'), merge())));
await check('phone merge cannot inflate points', assertFails(setDoc(doc(signup('m2', { phone_number: '+15045550001' }), 'users/m2'), merge({ yearlyPoints: 999 }))));
await check('phone merge cannot invent dues paid when roster says unpaid', assertFails(setDoc(doc(signup('m3', { phone_number: '+15045550001' }), 'users/m3'), merge({ duesPaid: true, memberNumber: '999' }))));
await check('phone merge with someone elses phone fails', assertFails(setDoc(doc(signup('m4', { phone_number: '+15045559999' }), 'users/m4'), merge())));
await check('phone merge omitting roster fields (older app build) still works', assertSucceeds(setDoc(doc(signup('m5', { phone_number: '+15045550001' }), 'users/m5'), merge({ memberNumber: null, yearlyPoints: null, clubPoints: null, duesPaid: false, createdAt: serverTimestamp() }))));
await check('email merge carries the roster values', assertSucceeds(setDoc(doc(signup('m6', { email: 'pat@x.com' }), 'users/m6'), merge())));
await check('email merge cannot inflate points', assertFails(setDoc(doc(signup('m7', { email: 'pat@x.com' }), 'users/m7'), merge({ clubPoints: 1000 }))));
await check('merge cannot grant admin', assertFails(setDoc(doc(signup('m8', { phone_number: '+15045550001' }), 'users/m8'), merge({ role: 'admin' }))));

await check('admin can delete a member (unchanged)', assertSucceeds(deleteDoc(doc(adb, 'users/imported_5_Pat'))));

// ---- attendance (check-in) ----------------------------------------------
const openEvent = { eventTitle: 'Monthly Meeting', points: 1, checkedInAt: serverTimestamp() };
const attendance = (eventId, data) => setDoc(doc(mdb, `users/member1/attendance/${eventId}`), data);
let start;
await env.withSecurityRulesDisabled(async (ctx) => { start = (await getDoc(doc(ctx.firestore(), 'events/open'))).data().startTime; });

await check('check-in for an open event', assertSucceeds(attendance('open', { ...openEvent, eventStartTime: start })));
await check('a second check-in for the same event is refused', assertFails(attendance('open', { ...openEvent, eventStartTime: start })));
await check('cannot write more than one point', assertFails(setDoc(doc(env.authenticatedContext('member2').firestore(), 'users/member2/attendance/open'), { ...openEvent, points: 1000, eventStartTime: start })));
await check('cannot use a different title', assertFails(setDoc(doc(env.authenticatedContext('member2').firestore(), 'users/member2/attendance/open'), { ...openEvent, eventTitle: 'Made Up', eventStartTime: start })));
await check('cannot add extra fields', assertFails(setDoc(doc(env.authenticatedContext('member2').firestore(), 'users/member2/attendance/open'), { ...openEvent, eventStartTime: start, bonus: 5 })));
await check('cannot check in when check-in is off', assertFails(setDoc(doc(env.authenticatedContext('member2').firestore(), 'users/member2/attendance/closed'), { eventTitle: 'Not Yet', points: 1, checkedInAt: serverTimestamp(), eventStartTime: start })));
await check('cannot check in to an event long past', assertFails(setDoc(doc(env.authenticatedContext('member2').firestore(), 'users/member2/attendance/old'), { eventTitle: 'Last Year', points: 1, checkedInAt: serverTimestamp(), eventStartTime: minutes(-60 * 24 * 300) })));
await check('cannot check in someone else', assertFails(setDoc(doc(mdb, 'users/member2/attendance/open'), { ...openEvent, eventStartTime: start })));

// ---- storage -------------------------------------------------------------
const mst = member.storage();
const bytes = new Uint8Array([1, 2, 3]);
await check('storage: owner uploads own photo', assertSucceeds(uploadBytes(ref(mst, 'profile_photos/member1.jpg'), bytes, { contentType: 'image/jpeg' })));
await check('storage: cannot upload someone elses', assertFails(uploadBytes(ref(mst, 'profile_photos/member2.jpg'), bytes, { contentType: 'image/jpeg' })));
await check('storage: cannot delete someone elses', assertFails(deleteObject(ref(mst, 'profile_photos/member2.jpg'))));
await check('storage: owner deletes own photo', assertSucceeds(deleteObject(ref(mst, 'profile_photos/member1.jpg'))));

// ---- self-delete (last: removes the doc) --------------------------------
await check('member deletes own account doc', assertSucceeds(deleteDoc(doc(mdb, 'users/member1'))));

await env.cleanup();
console.log(failures ? `${failures} FAILED` : 'ALL PASSED');
process.exit(failures ? 1 : 0);
