import * as SecureStore from 'expo-secure-store';

// Client half of the 30-day inactivity rule. The server-side app session
// (supabase/migrations/0002) is authoritative; this signs out immediately
// on the device without waiting for a rejected request.
export const INACTIVITY_LIMIT_MS = 30 * 24 * 60 * 60 * 1000;
export const LAST_ACTIVITY_KEY = 'pennysprout.lastActivityAt';

export type InactivityResult = 'active' | 'expired';

/**
 * A missing record means activity was never recorded for the stored session,
 * so it is treated as expired. A timestamp in the future (device clock moved
 * back) is not treated as expiry; the server check still applies.
 */
export function isInactivityExpired(lastActivityAt: number | null, now: number): boolean {
  if (lastActivityAt === null) {
    return true;
  }
  return now - lastActivityAt >= INACTIVITY_LIMIT_MS;
}

export async function readLastActivity(): Promise<number | null> {
  const stored = await SecureStore.getItemAsync(LAST_ACTIVITY_KEY);
  if (stored === null || !/^\d{1,15}$/.test(stored)) {
    return null;
  }
  return Number(stored);
}

export async function recordActivity(now: number = Date.now()): Promise<void> {
  await SecureStore.setItemAsync(LAST_ACTIVITY_KEY, String(Math.trunc(now)));
}

export async function clearActivity(): Promise<void> {
  await SecureStore.deleteItemAsync(LAST_ACTIVITY_KEY);
}

/** Signs out when the device has been inactive for 30 days; otherwise records activity. */
export async function enforceInactivity(
  signOut: () => Promise<void>,
  now: number = Date.now(),
): Promise<InactivityResult> {
  if (isInactivityExpired(await readLastActivity(), now)) {
    await clearActivity();
    await signOut();
    return 'expired';
  }
  await recordActivity(now);
  return 'active';
}
