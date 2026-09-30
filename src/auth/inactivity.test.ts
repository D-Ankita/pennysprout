import {
  clearActivity,
  enforceInactivity,
  INACTIVITY_LIMIT_MS,
  isInactivityExpired,
  LAST_ACTIVITY_KEY,
  readLastActivity,
  recordActivity,
} from './inactivity';

const mockStore = new Map<string, string>();

jest.mock('expo-secure-store', () => ({
  getItemAsync: jest.fn(async (key: string) => mockStore.get(key) ?? null),
  setItemAsync: jest.fn(async (key: string, value: string) => {
    mockStore.set(key, value);
  }),
  deleteItemAsync: jest.fn(async (key: string) => {
    mockStore.delete(key);
  }),
}));

const NOW = Date.UTC(2026, 8, 30, 12, 0, 0);

describe('isInactivityExpired', () => {
  it('treats a missing record as expired', () => {
    expect(isInactivityExpired(null, NOW)).toBe(true);
  });

  it('keeps a session used just inside 30 days', () => {
    expect(isInactivityExpired(NOW - INACTIVITY_LIMIT_MS + 1, NOW)).toBe(false);
  });

  it('expires at exactly 30 inactive days', () => {
    expect(isInactivityExpired(NOW - INACTIVITY_LIMIT_MS, NOW)).toBe(true);
  });

  it('does not expire when the device clock moved backwards', () => {
    expect(isInactivityExpired(NOW + 60_000, NOW)).toBe(false);
  });
});

describe('secure-mockStore activity record', () => {
  beforeEach(() => {
    mockStore.clear();
  });

  it('records and reads the last activity time', async () => {
    await recordActivity(NOW + 0.7);
    expect(mockStore.get(LAST_ACTIVITY_KEY)).toBe(String(NOW));
    await expect(readLastActivity()).resolves.toBe(NOW);
  });

  it.each(['', 'abc', '-5', '1.5'])('ignores a corrupted value %p', async (value) => {
    mockStore.set(LAST_ACTIVITY_KEY, value);
    await expect(readLastActivity()).resolves.toBeNull();
  });

  it('clears the record', async () => {
    await recordActivity(NOW);
    await clearActivity();
    await expect(readLastActivity()).resolves.toBeNull();
  });
});

describe('enforceInactivity', () => {
  beforeEach(() => {
    mockStore.clear();
  });

  it('refreshes activity for a recently used device', async () => {
    const signOut = jest.fn(async () => undefined);
    await recordActivity(NOW - 1000);

    await expect(enforceInactivity(signOut, NOW)).resolves.toBe('active');
    expect(signOut).not.toHaveBeenCalled();
    await expect(readLastActivity()).resolves.toBe(NOW);
  });

  it('signs out immediately and clears the record after 30 inactive days', async () => {
    const signOut = jest.fn(async () => undefined);
    await recordActivity(NOW - INACTIVITY_LIMIT_MS);

    await expect(enforceInactivity(signOut, NOW)).resolves.toBe('expired');
    expect(signOut).toHaveBeenCalledTimes(1);
    await expect(readLastActivity()).resolves.toBeNull();
  });

  it('uses the current time by default', async () => {
    const signOut = jest.fn(async () => undefined);
    await recordActivity();

    await expect(enforceInactivity(signOut)).resolves.toBe('active');
  });
});
