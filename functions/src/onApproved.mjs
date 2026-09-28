// users/{uid} — personal notification sent the moment an admin approves a
// pending member. Unlike the topic sends elsewhere, this is a per-token
// multicast, so we also get per-token delivery errors back and use them to
// self-clean stale/unregistered FCM tokens from users/{uid}/fcmTokens.
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { db, messaging } from './lib/admin.mjs';

const UNREGISTERED_ERROR_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

const isUnregistered = (error) => UNREGISTERED_ERROR_CODES.has(error?.code);

export async function handleApproved(event, { db, messaging }) {
  const before = event.data?.before;
  const after = event.data?.after;

  if (!before?.exists || !after?.exists) return null;

  const beforeData = before.data();
  const afterData = after.data();
  if (beforeData.status !== 'pending' || afterData.status !== 'approved') return null;

  const { uid } = event.params;
  const tokensSnap = await db.collection(`users/${uid}/fcmTokens`).get();
  const tokens = tokensSnap.docs.map((d) => d.id);
  if (tokens.length === 0) return null;

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: {
      title: "You're approved!",
      body: 'Welcome to the club — you now have full access.',
    },
    data: { type: 'approved' },
  });

  const staleDeletes = [];
  response.responses.forEach((result, i) => {
    if (!result.success && isUnregistered(result.error)) {
      staleDeletes.push(db.doc(`users/${uid}/fcmTokens/${tokens[i]}`).delete());
    }
  });
  if (staleDeletes.length) await Promise.all(staleDeletes);

  return response;
}

export const onApproved = onDocumentWritten('users/{uid}', async (event) => {
  try {
    return await handleApproved(event, { db, messaging });
  } catch (err) {
    logger.error('onApproved failed', { uid: event.params?.uid, err });
    throw err;
  }
});
