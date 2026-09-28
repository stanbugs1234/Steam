// Fan out a topic notification whenever a new event or news post is
// created. onDocumentCreated only fires once, at creation, so there's no
// risk of re-notifying on later edits.
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { messaging } from './lib/admin.mjs';

const TOPIC = 'announcements';

export async function handleEventCreated(event, { messaging }) {
  const snap = event.data;
  if (!snap?.exists) return null;
  const { eventId } = event.params;
  const title = snap.data()?.title || 'A new event';

  return messaging.send({
    topic: TOPIC,
    notification: { title: 'New event', body: title },
    data: { type: 'event', eventId },
  });
}

export async function handleNewsCreated(event, { messaging }) {
  const snap = event.data;
  if (!snap?.exists) return null;
  const { postId } = event.params;
  const title = snap.data()?.title || 'A new post';

  return messaging.send({
    topic: TOPIC,
    notification: { title: 'New from the club', body: title },
    data: { type: 'news', postId },
  });
}

export const onEventAnnouncementCreated = onDocumentCreated('events/{eventId}', async (event) => {
  try {
    return await handleEventCreated(event, { messaging });
  } catch (err) {
    logger.error('onEventAnnouncementCreated failed', { eventId: event.params?.eventId, err });
    throw err;
  }
});

export const onNewsAnnouncementCreated = onDocumentCreated('news/{postId}', async (event) => {
  try {
    return await handleNewsCreated(event, { messaging });
  } catch (err) {
    logger.error('onNewsAnnouncementCreated failed', { postId: event.params?.postId, err });
    throw err;
  }
});
