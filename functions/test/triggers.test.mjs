// Trigger unit tests — run with `npm test` from functions/.
//
// These run fully offline: `firebase-functions-test`'s offline mode builds
// real Admin SDK DocumentSnapshot objects (correct `.exists`/`.data()`
// behavior) without a network call or emulator, and our trigger handlers
// take `db`/`messaging` as explicit parameters (see src/*.mjs) so tests
// substitute in-memory fakes instead of hitting live Firestore/FCM.
//
// Style matches tools/rules-tests: a flat script with a `check(name, fn)`
// helper, PASS/FAIL per line, non-zero exit code on any failure.
import assert from 'node:assert/strict';
import firebaseFunctionsTest from 'firebase-functions-test';
import { handleSlotWrite } from '../src/onSlotOpenedUp.mjs';
import { handleEventCreated, handleNewsCreated } from '../src/onAnnouncementCreated.mjs';
import { handlePendingSignup } from '../src/onPendingSignup.mjs';
import { handleApproved } from '../src/onApproved.mjs';
import { fakeDb, fakeMessaging } from './fakes.mjs';

const test = firebaseFunctionsTest();
const snap = (data, path) => test.firestore.makeDocumentSnapshot(data, path);

let failures = 0;
async function check(name, fn) {
  try {
    await fn();
    console.log('PASS', name);
  } catch (e) {
    failures++;
    console.log('FAIL', name, '-', String(e.message ?? e).slice(0, 200));
  }
}

// ---- onSlotOpenedUp --------------------------------------------------------

const slotPath = 'events/evt1/volunteerSlots/slot1';

await check('slot: full -> open sends a volunteer-openings notification', async () => {
  const db = fakeDb({ 'events/evt1': { title: 'Fall Cleanup' } });
  const messaging = fakeMessaging();
  const event = {
    data: {
      before: snap({ label: 'Setup', capacity: 2, signedUpUserIds: ['a', 'b'] }, slotPath),
      after: snap({ label: 'Setup', capacity: 2, signedUpUserIds: ['a'] }, slotPath),
    },
    params: { eventId: 'evt1', slotId: 'slot1' },
  };
  await handleSlotWrite(event, { db, messaging });
  assert.equal(messaging.sent.length, 1);
  const msg = messaging.sent[0];
  assert.equal(msg.topic, 'volunteer-openings');
  assert.equal(msg.notification.title, 'A volunteer spot opened up');
  assert.match(msg.notification.body, /Fall Cleanup/);
  assert.deepEqual(msg.data, { type: 'volunteer-opening', eventId: 'evt1', slotId: 'slot1' });
});

await check('slot: still full after write sends nothing', async () => {
  const db = fakeDb({ 'events/evt1': { title: 'Fall Cleanup' } });
  const messaging = fakeMessaging();
  const event = {
    data: {
      before: snap({ label: 'Setup', capacity: 2, signedUpUserIds: ['a', 'b'] }, slotPath),
      after: snap({ label: 'Setup', capacity: 2, signedUpUserIds: ['a', 'c'] }, slotPath),
    },
    params: { eventId: 'evt1', slotId: 'slot1' },
  };
  await handleSlotWrite(event, { db, messaging });
  assert.equal(messaging.sent.length, 0);
});

await check('slot: was not full (open -> more open) sends nothing', async () => {
  const db = fakeDb({ 'events/evt1': { title: 'Fall Cleanup' } });
  const messaging = fakeMessaging();
  const event = {
    data: {
      before: snap({ label: 'Setup', capacity: 5, signedUpUserIds: ['a'] }, slotPath),
      after: snap({ label: 'Setup', capacity: 5, signedUpUserIds: [] }, slotPath),
    },
    params: { eventId: 'evt1', slotId: 'slot1' },
  };
  await handleSlotWrite(event, { db, messaging });
  assert.equal(messaging.sent.length, 0);
});

await check('slot: creation (no before) sends nothing', async () => {
  const db = fakeDb({});
  const messaging = fakeMessaging();
  const event = {
    data: {
      before: snap({}, slotPath), // does not exist
      after: snap({ label: 'Setup', capacity: 2, signedUpUserIds: [] }, slotPath),
    },
    params: { eventId: 'evt1', slotId: 'slot1' },
  };
  await handleSlotWrite(event, { db, messaging });
  assert.equal(messaging.sent.length, 0);
});

await check('slot: deletion (no after) sends nothing', async () => {
  const db = fakeDb({});
  const messaging = fakeMessaging();
  const event = {
    data: {
      before: snap({ label: 'Setup', capacity: 2, signedUpUserIds: ['a', 'b'] }, slotPath),
      after: snap({}, slotPath), // does not exist
    },
    params: { eventId: 'evt1', slotId: 'slot1' },
  };
  await handleSlotWrite(event, { db, messaging });
  assert.equal(messaging.sent.length, 0);
});

// ---- onAnnouncementCreated --------------------------------------------------

await check('announcement: new event notifies the announcements topic', async () => {
  const messaging = fakeMessaging();
  const event = { data: snap({ title: 'Rocket Launch Day' }, 'events/evt2'), params: { eventId: 'evt2' } };
  await handleEventCreated(event, { messaging });
  assert.equal(messaging.sent.length, 1);
  assert.equal(messaging.sent[0].topic, 'announcements');
  assert.deepEqual(messaging.sent[0].data, { type: 'event', eventId: 'evt2' });
});

await check('announcement: new news post notifies the announcements topic', async () => {
  const messaging = fakeMessaging();
  const event = { data: snap({ title: 'Welcome back!' }, 'news/post1'), params: { postId: 'post1' } };
  await handleNewsCreated(event, { messaging });
  assert.equal(messaging.sent.length, 1);
  assert.equal(messaging.sent[0].topic, 'announcements');
  assert.deepEqual(messaging.sent[0].data, { type: 'news', postId: 'post1' });
});

// ---- onPendingSignup ---------------------------------------------------------

const userPath = 'users/u1';

await check('pending: brand-new sign-up (no before doc) alerts admins', async () => {
  const messaging = fakeMessaging();
  const event = {
    data: { before: snap({}, userPath), after: snap({ name: 'Alex', status: 'pending' }, userPath) },
    params: { uid: 'u1' },
  };
  await handlePendingSignup(event, { messaging });
  assert.equal(messaging.sent.length, 1);
  assert.equal(messaging.sent[0].topic, 'admin-alerts');
  assert.match(messaging.sent[0].notification.body, /Alex/);
});

await check('pending: transition from approved back to pending alerts admins', async () => {
  const messaging = fakeMessaging();
  const event = {
    data: {
      before: snap({ name: 'Alex', status: 'approved' }, userPath),
      after: snap({ name: 'Alex', status: 'pending' }, userPath),
    },
    params: { uid: 'u1' },
  };
  await handlePendingSignup(event, { messaging });
  assert.equal(messaging.sent.length, 1);
});

await check('pending: editing an already-pending profile sends nothing', async () => {
  const messaging = fakeMessaging();
  const event = {
    data: {
      before: snap({ name: 'Alex', status: 'pending' }, userPath),
      after: snap({ name: 'Alex Updated', status: 'pending' }, userPath),
    },
    params: { uid: 'u1' },
  };
  await handlePendingSignup(event, { messaging });
  assert.equal(messaging.sent.length, 0);
});

// ---- onApproved ---------------------------------------------------------------

await check('approved: pending -> approved multicasts to all fcm tokens', async () => {
  const db = fakeDb({
    'users/u1/fcmTokens/tok-good': { platform: 'ios' },
    'users/u1/fcmTokens/tok-stale': { platform: 'android' },
  });
  const messaging = fakeMessaging({
    multicastResponses: [
      { success: true },
      { success: false, error: { code: 'messaging/registration-token-not-registered' } },
    ],
  });
  const event = {
    data: {
      before: snap({ name: 'Alex', status: 'pending' }, userPath),
      after: snap({ name: 'Alex', status: 'approved' }, userPath),
    },
    params: { uid: 'u1' },
  };
  await handleApproved(event, { db, messaging });

  assert.equal(messaging.multicasts.length, 1);
  const call = messaging.multicasts[0];
  assert.deepEqual(new Set(call.tokens), new Set(['tok-good', 'tok-stale']));
  assert.equal(call.notification.title, "You're approved!");
  assert.deepEqual(call.data, { type: 'approved' });

  // The stale/unregistered token must be cleaned up; the good one kept.
  assert.deepEqual(db.deletedPaths, ['users/u1/fcmTokens/tok-stale']);
});

await check('approved: no fcm tokens on file sends nothing and deletes nothing', async () => {
  const db = fakeDb({});
  const messaging = fakeMessaging();
  const event = {
    data: {
      before: snap({ name: 'Alex', status: 'pending' }, userPath),
      after: snap({ name: 'Alex', status: 'approved' }, userPath),
    },
    params: { uid: 'u1' },
  };
  await handleApproved(event, { db, messaging });
  assert.equal(messaging.multicasts.length, 0);
  assert.deepEqual(db.deletedPaths, []);
});

await check('approved: already-approved user edited again sends nothing', async () => {
  const db = fakeDb({ 'users/u1/fcmTokens/tok-good': { platform: 'ios' } });
  const messaging = fakeMessaging();
  const event = {
    data: {
      before: snap({ name: 'Alex', status: 'approved' }, userPath),
      after: snap({ name: 'Alex Updated', status: 'approved' }, userPath),
    },
    params: { uid: 'u1' },
  };
  await handleApproved(event, { db, messaging });
  assert.equal(messaging.multicasts.length, 0);
});

await check('approved: brand-new user created already approved sends nothing (no prior "pending")', async () => {
  const db = fakeDb({ 'users/u1/fcmTokens/tok-good': { platform: 'ios' } });
  const messaging = fakeMessaging();
  const event = {
    data: { before: snap({}, userPath), after: snap({ name: 'Alex', status: 'approved' }, userPath) },
    params: { uid: 'u1' },
  };
  await handleApproved(event, { db, messaging });
  assert.equal(messaging.multicasts.length, 0);
});

test.cleanup();
console.log(failures ? `${failures} FAILED` : 'ALL PASSED');
process.exit(failures ? 1 : 0);
