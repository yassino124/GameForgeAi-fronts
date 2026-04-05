export type LiveSession = {
  roomName: string;
  creatorIdentity: string;
  creatorName: string;
  creatorAvatarUrl?: string;
  gameTitle?: string;
  thumbUrl?: string;
  startedAt: number;
  tags?: string[];
};

type Store = {
  byRoom: Map<string, LiveSession>;
};

declare global {
  // eslint-disable-next-line no-var
  var __gfLiveSessionsStore: Store | undefined;
}

function getStore(): Store {
  if (!globalThis.__gfLiveSessionsStore) {
    globalThis.__gfLiveSessionsStore = { byRoom: new Map() };
  }
  return globalThis.__gfLiveSessionsStore;
}

export function upsertLiveSession(session: LiveSession) {
  const store = getStore();
  store.byRoom.set(session.roomName, session);
}

export function removeLiveSession(roomName: string) {
  const store = getStore();
  store.byRoom.delete(roomName);
}

export function listLiveSessions(): LiveSession[] {
  const store = getStore();
  return Array.from(store.byRoom.values()).sort((a, b) => b.startedAt - a.startedAt);
}

export function getLiveSession(roomName: string): LiveSession | null {
  const store = getStore();
  return store.byRoom.get(roomName) ?? null;
}
