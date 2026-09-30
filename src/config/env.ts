import { z } from 'zod';

export const APP_ENVIRONMENTS = ['local', 'family'] as const;
export type AppEnvironment = (typeof APP_ENVIRONMENTS)[number];

export type AppConfig = {
  appEnv: AppEnvironment;
  supabaseUrl: string;
  supabasePublishableKey: string;
};

export type RawEnv = Record<string, string | undefined>;

export type EnvResult = { ok: true; config: AppConfig } | { ok: false; issues: string[] };

const LOCAL_HOST_PATTERNS = [
  /^localhost$/,
  /\.localhost$/,
  /\.local$/,
  /^127\./,
  /^10\./,
  /^192\.168\./,
  /^172\.(1[6-9]|2\d|3[01])\./,
  /^0\.0\.0\.0$/,
  /^\[::1\]$/,
];

function isLocalHost(hostname: string): boolean {
  return LOCAL_HOST_PATTERNS.some((pattern) => pattern.test(hostname));
}

function parseUrl(value: string): URL | null {
  try {
    return new URL(value);
  } catch {
    return null;
  }
}

function decodeJwtRole(token: string): string | null {
  const segments = token.split('.');
  if (segments.length !== 3 || !segments[1]) {
    return null;
  }
  try {
    const base64 = segments[1].replace(/-/g, '+').replace(/_/g, '/');
    const payload: unknown = JSON.parse(atob(base64));
    if (typeof payload === 'object' && payload !== null && 'role' in payload) {
      return typeof payload.role === 'string' ? payload.role : null;
    }
    return null;
  } catch {
    return null;
  }
}

const envSchema = z
  .object({
    EXPO_PUBLIC_APP_ENV: z.enum(APP_ENVIRONMENTS, {
      error: 'EXPO_PUBLIC_APP_ENV must be local or family',
    }),
    EXPO_PUBLIC_SUPABASE_URL: z.url({
      protocol: /^https?$/,
      error: 'EXPO_PUBLIC_SUPABASE_URL must be an http(s) URL',
    }),
    EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: z
      .string({ error: 'EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY is required' })
      .trim()
      .min(1, 'EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY is required'),
  })
  .superRefine((env, ctx) => {
    // Zod still runs this refinement when a field has a non-fatal format issue.
    const url = parseUrl(env.EXPO_PUBLIC_SUPABASE_URL);
    if (url && env.EXPO_PUBLIC_APP_ENV === 'family') {
      if (url.protocol !== 'https:') {
        ctx.addIssue({
          code: 'custom',
          path: ['EXPO_PUBLIC_SUPABASE_URL'],
          message: 'EXPO_PUBLIC_SUPABASE_URL must use https for family',
        });
      }
      if (isLocalHost(url.hostname)) {
        ctx.addIssue({
          code: 'custom',
          path: ['EXPO_PUBLIC_SUPABASE_URL'],
          message: 'EXPO_PUBLIC_SUPABASE_URL must not point at a local host for family',
        });
      }
    }

    const key = env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
    if (key.startsWith('sb_secret_') || decodeJwtRole(key) === 'service_role') {
      ctx.addIssue({
        code: 'custom',
        path: ['EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY'],
        message:
          'EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY must be a publishable key, never a secret key',
      });
    }
  });

/**
 * Validates raw environment values. Messages name variables but never echo their values.
 * There are no defaults: a missing value fails rather than falling back to another environment.
 */
export function parseEnv(raw: RawEnv): EnvResult {
  const result = envSchema.safeParse(raw);
  if (!result.success) {
    return { ok: false, issues: result.error.issues.map((issue) => issue.message) };
  }
  return {
    ok: true,
    config: {
      appEnv: result.data.EXPO_PUBLIC_APP_ENV,
      supabaseUrl: result.data.EXPO_PUBLIC_SUPABASE_URL,
      supabasePublishableKey: result.data.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    },
  };
}

/**
 * Reads the bundled environment. Expo inlines EXPO_PUBLIC_* values only for static
 * `process.env.NAME` references, so each variable is referenced explicitly.
 */
export function readBundledEnv(): RawEnv {
  return {
    EXPO_PUBLIC_APP_ENV: process.env.EXPO_PUBLIC_APP_ENV,
    EXPO_PUBLIC_SUPABASE_URL: process.env.EXPO_PUBLIC_SUPABASE_URL,
    EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  };
}
