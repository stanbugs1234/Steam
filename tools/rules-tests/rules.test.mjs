import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc, query, where, limit, collection, collectionGroup, writeBatch,
  Timestamp, serverTimestamp,
} from 'firebase/firestore';
import { ref, uploadBytes, deleteObject, getBytes, listAll } from 'firebase/storage';
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
const SECRET = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
const bytes = new Uint8Array([1, 2, 3]);
const OWN_PHOTO_URL = 'https://firebasestorage.googleapis.com/v0/b/steam-club-app.firebasestorage.app/o/profile_photos%2Fmember1.jpg?alt=media&token=abc';

await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  const base = { email: 'm@x.com', phone: '5045551234', kids: [], status: 'approved', role: 'member', yearlyPoints: 3, duesPaid: false, memberNumber: '12', remindersEnabled: true, photoUrl: null, createdAt: Timestamp.now() };
  await setDoc(doc(db, 'users/member1'), { ...base, name: 'Member One' });
  await setDoc(doc(db, 'users/member2'), { ...base, name: 'Member Two' });
  await setDoc(doc(db, 'users/admin1'), { ...base, name: 'Admin', role: 'admin' });
  await setDoc(doc(db, 'users/pending1'), { ...base, name: 'Pending', status: 'pending' });
  await setDoc(doc(db, 'users/imported_5_Pat'), { ...base, ...ROSTER, name: 'Pat', email: 'pat@x.com', phone: '+15045550001', createdAt: joined });
  await setDoc(doc(db, 'users/imported_6_Sam'), { ...base, ...ROSTER, name: 'Sam', email: 'sam@x.com', phone: '+15045550002', createdAt: joined });
  await setDoc(doc(db, 'users/imported_7_Kim'), { ...base, ...ROSTER, name: 'Kim', email: 'kim@x.com', phone: '+15045550003', createdAt: joined });

  const ev = (extra) => ({ title: 'Monthly Meeting', description: '', location: '', startTime: minutes(-10), endTime: minutes(50), needsVolunteers: false, checkInEnabled: true, ...extra });
  await setDoc(doc(db, 'events/open'), ev({ needsVolunteers: true }));
  await setDoc(doc(db, 'events/closed'), ev({ title: 'Not Yet', checkInEnabled: false }));
  await setDoc(doc(db, 'events/old'), ev({ title: 'Last Year', startTime: minutes(-60 * 24 * 300), endTime: minutes(-60 * 24 * 300 + 60) }));
  await setDoc(doc(db, 'events/ended'), ev({ title: 'Ended', needsVolunteers: true, startTime: minutes(-180), endTime: minutes(-120) }));
  for (const id of ['open', 'closed', 'old', 'ended']) {
    await setDoc(doc(db, `events/${id}/private/checkin`), { code: SECRET });
  }
  await setDoc(doc(db, 'events/open/volunteerSlots/s1'), { label: 'Setup', capacity: 5, signedUpUserIds: [] });
  await setDoc(doc(db, 'events/ended/volunteerSlots/s1'), { label: 'Setup', capacity: 5, signedUpUserIds: [] });
  await setDoc(doc(db, 'events/ended/volunteerSlots/s2'), { label: 'Cleanup', capacity: 5, signedUpUserIds: ['member1'] });

  // Storage objects to read/delete.
  const st = ctx.storage();
  await uploadBytes(ref(st, 'profile_photos/member2.jpg'), bytes, { contentType: 'image/jpeg' });
  await uploadBytes(ref(st, 'news_images/post1.jpg'), bytes, { contentType: 'image/jpeg' });
});

let failures = 0;
async function check(name, promise) {
  try { await promise; console.log('PASS', name); } catch (e) { failures++; console.log('FAIL', name, '-', String(e.message).slice(0, 140)); }
}

const member = env.authenticatedContext('member1');
const admin = env.authenticatedContext('admin1');
const pending = env.authenticatedContext('pending1');
const mdb = member.firestore();
const adb = admin.firestore();
const pdb = pending.firestore();

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

// ---- users: field validation (one bad value must not break everyone) ------
await check('validation: name must be a string', assertFails(updateDoc(doc(mdb, 'users/member1'), { name: 5 })));
await check('validation: name too long', assertFails(updateDoc(doc(mdb, 'users/member1'), { name: 'x'.repeat(101) })));
await check('validation: kids must be a list', assertFails(updateDoc(doc(mdb, 'users/member1'), { kids: 'lots' })));
await check('validation: kids list capped', assertFails(updateDoc(doc(mdb, 'users/member1'), { kids: Array.from({ length: 13 }, () => ({ name: 'K', grade: '1' })) })));
await check('validation: remindersEnabled must be a bool', assertFails(updateDoc(doc(mdb, 'users/member1'), { remindersEnabled: 'yes' })));
await check('validation: photoUrl must be our Storage bucket', assertFails(updateDoc(doc(mdb, 'users/member1'), { photoUrl: 'https://tracker.example.com/pixel.png' })));
await check('validation: our own Storage photoUrl is fine', assertSucceeds(updateDoc(doc(mdb, 'users/member1'), { photoUrl: OWN_PHOTO_URL })));

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
await check('signup: name must be a string', assertFails(setDoc(doc(signup('s11'), 'users/s11'), plain({ name: 42 }))));
await check('signup: arbitrary photoUrl refused', assertFails(setDoc(doc(signup('s12'), 'users/s12'), plain({ photoUrl: 'https://tracker.example.com/p.png' }))));

const merge = (extra = {}) => plain({ status: 'approved', mergedFromId: 'imported_5_Pat', createdAt: joined, ...ROSTER, ...extra });
await check('phone merge carries the roster values', assertSucceeds(setDoc(doc(signup('m1', { phone_number: '+15045550001' }), 'users/m1'), merge())));
await check('phone merge cannot inflate points', assertFails(setDoc(doc(signup('m2', { phone_number: '+15045550001' }), 'users/m2'), merge({ yearlyPoints: 999 }))));
await check('phone merge cannot invent dues paid when roster says unpaid', assertFails(setDoc(doc(signup('m3', { phone_number: '+15045550001' }), 'users/m3'), merge({ duesPaid: true, memberNumber: '999' }))));
await check('phone merge with someone elses phone fails', assertFails(setDoc(doc(signup('m4', { phone_number: '+15045559999' }), 'users/m4'), merge())));
await check('phone merge omitting roster fields (older app build) still works', assertSucceeds(setDoc(doc(signup('m5', { phone_number: '+15045550001' }), 'users/m5'), merge({ memberNumber: null, yearlyPoints: null, clubPoints: null, duesPaid: false, createdAt: serverTimestamp() }))));
await check('merge cannot grant admin', assertFails(setDoc(doc(signup('m8', { phone_number: '+15045550001' }), 'users/m8'), merge({ role: 'admin' }))));

// Email accounts are never trusted to claim a roster record (the address may
// not be verified) — an admin merges them instead.
await check('email merge is refused (matching email, roster values)', assertFails(setDoc(doc(signup('m6', { email: 'pat@x.com' }), 'users/m6'), merge())));
await check('email merge is refused even with email_verified', assertFails(setDoc(doc(signup('m7', { email: 'pat@x.com', email_verified: true }), 'users/m7'), merge())));
await check('email account cannot read a placeholder by matching email', assertFails(getDoc(doc(signup('e1', { email: 'sam@x.com' }), 'users/imported_6_Sam'))));
await check('email account cannot delete a placeholder by matching email', assertFails(deleteDoc(doc(signup('e2', { email: 'sam@x.com' }), 'users/imported_6_Sam'))));

// A phone-verified signup finds its roster placeholder with a *query*, not a
// direct get — make sure the rules allow the query the app actually runs.
const phoneLookup = (uid, phone) => getDocs(query(
  collection(signup(uid, { phone_number: phone }), 'users'),
  where('phone', '==', phone),
  where('status', '==', 'approved'),
  limit(1),
));
await check('phone signup can query its placeholder by verified phone', assertSucceeds(phoneLookup('q1', '+15045550002')));
await check('phone signup can read the placeholder doc directly', assertSucceeds(getDoc(doc(signup('q2', { phone_number: '+15045550002' }), 'users/imported_6_Sam'))));
await check('phone signup cannot read someone elses placeholder', assertFails(getDoc(doc(signup('q3', { phone_number: '+15045550002' }), 'users/imported_7_Kim'))));
await check('phone merge + placeholder delete as one atomic batch', (async () => {
  const db = signup('m9', { phone_number: '+15045550003' });
  const batch = writeBatch(db);
  batch.set(doc(db, 'users/m9'), plain({ status: 'approved', mergedFromId: 'imported_7_Kim', createdAt: joined, ...ROSTER }));
  batch.delete(doc(db, 'users/imported_7_Kim'));
  await assertSucceeds(batch.commit());
})());


// Who can read which profiles.
await check('approved member reads another approved member', assertSucceeds(getDoc(doc(mdb, 'users/member2'))));
await check('pending user cannot read an approved member', assertFails(getDoc(doc(pdb, 'users/member2'))));
await check('pending user can read their own doc', assertSucceeds(getDoc(doc(pdb, 'users/pending1'))));

await check('admin can delete a member (unchanged)', assertSucceeds(deleteDoc(doc(adb, 'users/imported_5_Pat'))));

// ---- events: only admins write; the check-in secret is admin-only ---------
await check('member cannot start check-in themselves', assertFails(updateDoc(doc(mdb, 'events/closed'), { checkInEnabled: true })));
await check('member cannot edit an event', assertFails(updateDoc(doc(mdb, 'events/open'), { title: 'Hacked' })));
await check('member cannot write a checkedInUserIds array', assertFails(updateDoc(doc(mdb, 'events/open'), { checkedInUserIds: ['member1'] })));
await check('admin can start check-in', assertSucceeds(updateDoc(doc(adb, 'events/closed'), { checkInEnabled: true })));
await check('admin can read the check-in secret', assertSucceeds(getDoc(doc(adb, 'events/open/private/checkin'))));
await check('member cannot read the check-in secret', assertFails(getDoc(doc(mdb, 'events/open/private/checkin'))));
await check('member cannot write the check-in secret', assertFails(setDoc(doc(mdb, 'events/open/private/checkin'), { code: 'mine' })));
await check('admin can create a check-in secret', assertSucceeds(setDoc(doc(adb, 'events/closed/private/checkin'), { code: SECRET })));
await check('approved member can read events', assertSucceeds(getDoc(doc(mdb, 'events/open'))));
await check('pending user cannot read events', assertFails(getDoc(doc(pdb, 'events/open'))));

// ---- attendance (check-in) ----------------------------------------------
let start;
await env.withSecurityRulesDisabled(async (ctx) => { start = (await getDoc(doc(ctx.firestore(), 'events/open'))).data().startTime; });
const checkin = (eventId, extra = {}) => ({ eventId, eventTitle: 'Monthly Meeting', eventStartTime: start, points: 1, checkedInAt: serverTimestamp(), code: SECRET, ...extra });
const m2db = env.authenticatedContext('member2').firestore();
const attendance = (db, uid, eventId, data) => setDoc(doc(db, `users/${uid}/attendance/${eventId}`), data);

await check('check-in with the right code', assertSucceeds(attendance(mdb, 'member1', 'open', checkin('open'))));
await check('a second check-in for the same event is refused', assertFails(attendance(mdb, 'member1', 'open', checkin('open'))));
await check('cannot check in with the wrong code', assertFails(attendance(m2db, 'member2', 'open', checkin('open', { code: 'guess' }))));
await check('cannot check in without a code', assertFails(attendance(m2db, 'member2', 'open', (({ code, ...rest }) => rest)(checkin('open')))));
await check('cannot check in without eventId', assertFails(attendance(m2db, 'member2', 'open', (({ eventId, ...rest }) => rest)(checkin('open')))));
await check('cannot claim a different eventId', assertFails(attendance(m2db, 'member2', 'open', checkin('closed'))));
await check('cannot write more than one point', assertFails(attendance(m2db, 'member2', 'open', checkin('open', { points: 1000 }))));
await check('cannot use a different title', assertFails(attendance(m2db, 'member2', 'open', checkin('open', { eventTitle: 'Made Up' }))));
await check('cannot add extra fields', assertFails(attendance(m2db, 'member2', 'open', checkin('open', { bonus: 5 }))));
await check('cannot check in when check-in is off', assertFails(attendance(m2db, 'member2', 'closed', checkin('closed', { eventTitle: 'Not Yet' }))));
await check('cannot check in to an event long past', assertFails(attendance(m2db, 'member2', 'old', checkin('old', { eventTitle: 'Last Year', eventStartTime: minutes(-60 * 24 * 300) }))));
await check('cannot check in someone else', assertFails(attendance(mdb, 'member2', 'open', checkin('open'))));
await check('a pending user cannot check in even with the code', assertFails(attendance(pdb, 'pending1', 'open', checkin('open'))));
await check('admin can count check-ins across members', assertSucceeds(getDocs(query(collectionGroup(adb, 'attendance'), where('eventId', '==', 'open')))));
await check('member cannot run the check-in count query', assertFails(getDocs(query(collectionGroup(mdb, 'attendance'), where('eventId', '==', 'open')))));
await check('member cannot read another members attendance', assertFails(getDoc(doc(m2db, 'users/member1/attendance/open'))));
await check('member can delete their own attendance (account deletion)', assertSucceeds(deleteDoc(doc(mdb, 'users/member1/attendance/open'))));
await check('member cannot delete someone elses attendance', assertFails(deleteDoc(doc(m2db, 'users/member1/attendance/open'))));

// ---- volunteer slots -----------------------------------------------------
const slot = (db, ev, id) => doc(db, `events/${ev}/volunteerSlots/${id}`);
await check('member signs up for a slot on a running event', assertSucceeds(updateDoc(slot(mdb, 'open', 's1'), { signedUpUserIds: ['member1'] })));
await check('member cannot sign up after the event has ended', assertFails(updateDoc(slot(m2db, 'ended', 's1'), { signedUpUserIds: ['member2'] })));
await check('member can still leave a slot on an ended event', assertSucceeds(updateDoc(slot(mdb, 'ended', 's2'), { signedUpUserIds: [] })));
await check('member cannot sign someone else up', assertFails(updateDoc(slot(m2db, 'open', 's1'), { signedUpUserIds: ['member1', 'member1x'] })));
await check('pending user cannot sign up', assertFails(updateDoc(slot(pdb, 'open', 's1'), { signedUpUserIds: ['member1', 'pending1'] })));

// ---- events: atomic create / delete (what the admin screens do) -----------
await check('admin creates an event and its slot in one batch', (async () => {
  const batch = writeBatch(adb);
  batch.set(doc(adb, 'events/new1'), { title: 'New', description: '', location: '', startTime: minutes(60), endTime: minutes(120), needsVolunteers: true, checkInEnabled: false, createdBy: 'admin1', createdAt: serverTimestamp() });
  batch.set(doc(adb, 'events/new1/volunteerSlots/s1'), { label: 'Volunteers', capacity: 4, signedUpUserIds: [] });
  await assertSucceeds(batch.commit());
})());
await check('admin deletes an event with its slots and secret in one batch', (async () => {
  const batch = writeBatch(adb);
  batch.delete(doc(adb, 'events/new1/volunteerSlots/s1'));
  batch.delete(doc(adb, 'events/new1/private/checkin'));
  batch.delete(doc(adb, 'events/new1'));
  await assertSucceeds(batch.commit());
})());
await check('member cannot create an event', assertFails(setDoc(doc(mdb, 'events/hack'), { title: 'x', startTime: minutes(1), endTime: minutes(2) })));
await check('member cannot delete an event', assertFails(deleteDoc(doc(mdb, 'events/open'))));

// ---- storage -------------------------------------------------------------
const mst = member.storage();
const pst = pending.storage();
const ast = admin.storage();
await check('storage: owner uploads own photo', assertSucceeds(uploadBytes(ref(mst, 'profile_photos/member1.jpg'), bytes, { contentType: 'image/jpeg' })));
await check('storage: cannot upload someone elses', assertFails(uploadBytes(ref(mst, 'profile_photos/member2.jpg'), bytes, { contentType: 'image/jpeg' })));
await check('storage: SVG is refused', assertFails(uploadBytes(ref(mst, 'profile_photos/member1.jpg'), bytes, { contentType: 'image/svg+xml' })));
await check('storage: PNG is accepted', assertSucceeds(uploadBytes(ref(mst, 'profile_photos/member1.jpg'), bytes, { contentType: 'image/png' })));
await check('storage: approved member reads another members photo', assertSucceeds(getBytes(ref(mst, 'profile_photos/member2.jpg'))));
await check('storage: pending user cannot read another members photo', assertFails(getBytes(ref(pst, 'profile_photos/member2.jpg'))));
await check('storage: pending user cannot list photos', assertFails(listAll(ref(pst, 'profile_photos'))));
await check('storage: signed-out cannot read a photo', assertFails(getBytes(ref(env.unauthenticatedContext().storage(), 'profile_photos/member2.jpg'))));
await check('storage: pending user can upload their own photo', assertSucceeds(uploadBytes(ref(pst, 'profile_photos/pending1.jpg'), bytes, { contentType: 'image/jpeg' })));
await check('storage: pending user can read their own photo', assertSucceeds(getBytes(ref(pst, 'profile_photos/pending1.jpg'))));
await check('storage: cannot delete someone elses', assertFails(deleteObject(ref(mst, 'profile_photos/member2.jpg'))));
await check('storage: owner deletes own photo', assertSucceeds(deleteObject(ref(mst, 'profile_photos/member1.jpg'))));
await check('storage: admin deletes a members photo', assertSucceeds(deleteObject(ref(ast, 'profile_photos/member2.jpg'))));
await check('storage: approved member reads news image', assertSucceeds(getBytes(ref(mst, 'news_images/post1.jpg'))));
await check('storage: pending user cannot read news image', assertFails(getBytes(ref(pst, 'news_images/post1.jpg'))));
await check('storage: member cannot upload news image', assertFails(uploadBytes(ref(mst, 'news_images/post2.jpg'), bytes, { contentType: 'image/jpeg' })));
await check('storage: admin uploads news image', assertSucceeds(uploadBytes(ref(ast, 'news_images/post2.jpg'), bytes, { contentType: 'image/jpeg' })));
await check('storage: admin deletes news image', assertSucceeds(deleteObject(ref(ast, 'news_images/post2.jpg'))));
await check('storage: member cannot delete news image', assertFails(deleteObject(ref(mst, 'news_images/post1.jpg'))));

// ---- self-delete (last: removes the doc) --------------------------------
await check('member deletes own account doc', assertSucceeds(deleteDoc(doc(mdb, 'users/member1'))));

await env.cleanup();
console.log(failures ? `${failures} FAILED` : 'ALL PASSED');
process.exit(failures ? 1 : 0);
