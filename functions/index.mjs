// Entry point for Cloud Functions deploy — re-exports every trigger.
// Firebase discovers exported functions by walking this module's exports,
// so each trigger must be re-exported by name here.
export { onSlotOpenedUp } from './src/onSlotOpenedUp.mjs';
export { onEventAnnouncementCreated, onNewsAnnouncementCreated } from './src/onAnnouncementCreated.mjs';
export { onPendingSignup } from './src/onPendingSignup.mjs';
export { onApproved } from './src/onApproved.mjs';
