// Minimal fakes for the slice of the Admin SDK our trigger handlers touch.
// Handlers take `db`/`messaging` as explicit dependencies (see src/*.mjs),
// so tests never need a live project, credentials, or the emulator suite.

/** In-memory Firestore stand-in: `docs` is a plain `{ 'path/to/doc': data }` map. */
export function fakeDb(docs = {}) {
  const deletedPaths = [];

  const docRef = (path) => ({
    path,
    get: async () => ({
      exists: Object.prototype.hasOwnProperty.call(docs, path),
      data: () => docs[path],
    }),
    delete: async () => {
      delete docs[path];
      deletedPaths.push(path);
    },
  });

  return {
    deletedPaths,
    doc: (path) => docRef(path),
    collection: (path) => ({
      get: async () => {
        const prefix = `${path}/`;
        const ids = Object.keys(docs)
          .filter((p) => p.startsWith(prefix) && !p.slice(prefix.length).includes('/'))
          .map((p) => p.slice(prefix.length));
        return { docs: ids.map((id) => ({ id, data: () => docs[`${prefix}${id}`] })) };
      },
    }),
  };
}

/** Records every message handed to send()/sendEachForMulticast() for assertions. */
export function fakeMessaging({ multicastResponses } = {}) {
  const sent = [];
  const multicasts = [];
  return {
    sent,
    multicasts,
    send: async (message) => {
      sent.push(message);
      return `fake-message-${sent.length}`;
    },
    sendEachForMulticast: async (message) => {
      multicasts.push(message);
      const responses =
        multicastResponses ?? message.tokens.map(() => ({ success: true }));
      return {
        responses,
        successCount: responses.filter((r) => r.success).length,
        failureCount: responses.filter((r) => !r.success).length,
      };
    },
  };
}

/** A DocumentSnapshot-shaped stand-in, matching what a real onWritten/onCreated event carries. */
export function snap(data) {
  return { exists: data !== undefined, data: () => data };
}
