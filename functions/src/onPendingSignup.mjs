// users/{uid} — alert admins the moment a user newly becomes pending, i.e.
// a brand-new sign-up. Must NOT re-fire on every subsequent edit a
// still-pending user makes to their own profile (name/phone/etc).
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { messaging } from './lib/admin.mjs';

const TOPIC = 'admin-alerts';

export async function handlePendingSignup(event, { messaging }) {
  const before = event.data?.before;
  const after = event.data?.after;

  if (!after?.exists) return null; // deleted — nothing to alert about
  const afterData = after.data();
  if (afterData.status !== 'pending') return null;

  const wasAlreadyPending = Boolean(before?.exists) && before.data().status === 'pending';
  if (wasAlreadyPending) return null;

  const { uid } = event.params;
  return messaging.send({
    topic: TOPIC,
    notification: {
      title: 'New sign-up needs review',
      body: `${afterData.name || 'Someone'} just signed up.`,
    },
    data: { type: 'pending', uid },
  });
}

export const onPendingSignup = onDocumentWritten('users/{uid}', async (event) => {
  try {
    return await handlePendingSignup(event, { messaging });
  } catch (err) {
    logger.error('onPendingSignup failed', { uid: event.params?.uid, err });
    throw err;
  }
});
