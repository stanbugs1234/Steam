// Single shared Admin SDK app for all triggers. Cloud Functions reuses the
// module across invocations on a warm instance, so this only runs once per
// instance (not once per event) — keeps cold starts and quota usage down.
import { initializeApp, getApps } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

if (!getApps().length) {
  initializeApp();
}

export const db = getFirestore();
export const messaging = getMessaging();
