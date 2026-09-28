// events/{eventId}/volunteerSlots/{slotId} — notify everyone subscribed to
// the "volunteer-openings" topic when a slot goes from full back to open
// (e.g. someone drops out), so it's first come, first served.
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { db, messaging } from './lib/admin.mjs';

const TOPIC = 'volunteer-openings';

const isFull = (data) => (data?.signedUpUserIds?.length ?? 0) >= (data?.capacity ?? 0);
const isOpen = (data) => (data?.signedUpUserIds?.length ?? 0) < (data?.capacity ?? 0);

/**
 * Pure trigger logic, decoupled from the Admin SDK so it can be unit tested
 * with fake `db`/`messaging` implementations. `event` only needs to look
 * like a Firestore onDocumentWritten CloudEvent: `{ data: { before, after }, params }`.
 */
export async function handleSlotWrite(event, { db, messaging }) {
  const before = event.data?.before;
  const after = event.data?.after;

  // Skip slot creation (no before) and slot deletion (no after) — this
  // trigger only cares about a slot transitioning from full to open.
  if (!before?.exists || !after?.exists) return null;

  const beforeData = before.data();
  const afterData = after.data();

  if (!isFull(beforeData) || !isOpen(afterData)) return null;

  const { eventId, slotId } = event.params;
  const eventSnap = await db.doc(`events/${eventId}`).get();
  const eventTitle = eventSnap.exists ? eventSnap.data()?.title : null;
  const label = eventTitle || 'An event';

  return messaging.send({
    topic: TOPIC,
    notification: {
      title: 'A volunteer spot opened up',
      body: `${label} has an open volunteer spot — first come, first served.`,
    },
    data: { type: 'volunteer-opening', eventId, slotId },
  });
}

export const onSlotOpenedUp = onDocumentWritten(
  'events/{eventId}/volunteerSlots/{slotId}',
  async (event) => {
    try {
      return await handleSlotWrite(event, { db, messaging });
    } catch (err) {
      logger.error('onSlotOpenedUp failed', { eventId: event.params?.eventId, slotId: event.params?.slotId, err });
      throw err;
    }
  }
);
