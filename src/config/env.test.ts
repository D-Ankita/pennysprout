import { parseEnv, readBundledEnv, type RawEnv } from './env';

const PUBLISHABLE_KEY = 'sb_publishable_example';

function env(overrides: RawEnv = {}): RawEnv {
  return {
    EXPO_PUBLIC_APP_ENV: 'local',
    EXPO_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:54321',
    EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: PUBLISHABLE_KEY,
    ...overrides,
  };
}

function jwtWithRole(role: unknown): string {
  const encode = (value: object) =>
    btoa(JSON.stringify(value)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return `${encode({ alg: 'HS256' })}.${encode({ role })}.signature`;
}

function issuesOf(raw: RawEnv): string[] {
  const result = parseEnv(raw);
  if (result.ok) {
    throw new Error('expected validation to fail');
  }
  return result.issues;
}

describe('parseEnv', () => {
  it('accepts a local configuration', () => {
    expect(parseEnv(env())).toEqual({
      ok: true,
      config: {
        appEnv: 'local',
        supabaseUrl: 'http://127.0.0.1:54321',
        supabasePublishableKey: PUBLISHABLE_KEY,
      },
    });
  });

  it('accepts the Android emulator host for local development', () => {
    expect(parseEnv(env({ EXPO_PUBLIC_SUPABASE_URL: 'http://10.0.2.2:54321' })).ok).toBe(true);
  });

  it('accepts a hosted https URL for family', () => {
    const result = parseEnv(
      env({ EXPO_PUBLIC_APP_ENV: 'family', EXPO_PUBLIC_SUPABASE_URL: 'https://abc.supabase.co' }),
    );
    expect(result).toEqual({
      ok: true,
      config: {
        appEnv: 'family',
        supabaseUrl: 'https://abc.supabase.co',
        supabasePublishableKey: PUBLISHABLE_KEY,
      },
    });
  });

  it('fails when every variable is missing instead of falling back', () => {
    expect(issuesOf({})).toEqual([
      'EXPO_PUBLIC_APP_ENV must be local or family',
      'EXPO_PUBLIC_SUPABASE_URL must be an http(s) URL',
      'EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY is required',
    ]);
  });

  it.each(['development', 'staging', 'production', 'FAMILY'])(
    'rejects the environment name %s without aliases',
    (appEnv) => {
      expect(issuesOf(env({ EXPO_PUBLIC_APP_ENV: appEnv }))).toEqual([
        'EXPO_PUBLIC_APP_ENV must be local or family',
      ]);
    },
  );

  it.each(['not a url', 'ftp://example.com'])('rejects the URL %s', (url) => {
    expect(issuesOf(env({ EXPO_PUBLIC_SUPABASE_URL: url }))).toEqual([
      'EXPO_PUBLIC_SUPABASE_URL must be an http(s) URL',
    ]);
  });

  it('rejects a blank publishable key', () => {
    expect(issuesOf(env({ EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: '   ' }))).toEqual([
      'EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY is required',
    ]);
  });

  it('requires https for family', () => {
    expect(
      issuesOf(
        env({
          EXPO_PUBLIC_APP_ENV: 'family',
          EXPO_PUBLIC_SUPABASE_URL: 'http://abc.supabase.co',
        }),
      ),
    ).toEqual(['EXPO_PUBLIC_SUPABASE_URL must use https for family']);
  });

  it.each([
    'https://localhost:54321',
    'https://api.localhost',
    'https://mac.local',
    'https://127.0.0.1',
    'https://10.0.2.2:54321',
    'https://192.168.1.20',
    'https://172.16.0.1',
    'https://172.31.255.1',
    'https://0.0.0.0',
    'https://[::1]:54321',
  ])('prevents family from pointing at the local host %s', (url) => {
    expect(issuesOf(env({ EXPO_PUBLIC_APP_ENV: 'family', EXPO_PUBLIC_SUPABASE_URL: url }))).toEqual(
      ['EXPO_PUBLIC_SUPABASE_URL must not point at a local host for family'],
    );
  });

  it('does not treat public 172.x addresses as private', () => {
    const result = parseEnv(
      env({ EXPO_PUBLIC_APP_ENV: 'family', EXPO_PUBLIC_SUPABASE_URL: 'https://172.32.0.1' }),
    );
    expect(result.ok).toBe(true);
  });

  it.each([
    ['a secret API key', 'sb_secret_example'],
    ['a service-role JWT', jwtWithRole('service_role')],
  ])('rejects %s without echoing it', (_label, key) => {
    const issues = issuesOf(env({ EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: key }));
    expect(issues).toEqual([
      'EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY must be a publishable key, never a secret key',
    ]);
    expect(issues.join(' ')).not.toContain(key);
  });

  it.each([
    ['an anon JWT', jwtWithRole('anon')],
    ['a JWT without a role', jwtWithRole(undefined)],
    ['a JWT with a non-string role', jwtWithRole(7)],
    ['a JWT with an empty payload segment', 'header..signature'],
    ['a JWT with an undecodable payload', 'header.%%%.signature'],
    ['a JWT whose payload is not an object', `header.${btoa('"text"')}.signature`],
  ])('accepts %s as a publishable key', (_label, key) => {
    expect(parseEnv(env({ EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: key })).ok).toBe(true);
  });
});

describe('readBundledEnv', () => {
  const original = { ...process.env };

  afterEach(() => {
    process.env = { ...original };
  });

  it('reads only the public PennySprout variables', () => {
    process.env.EXPO_PUBLIC_APP_ENV = 'family';
    process.env.EXPO_PUBLIC_SUPABASE_URL = 'https://abc.supabase.co';
    process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY = PUBLISHABLE_KEY;
    process.env.SUPABASE_SERVICE_ROLE_KEY = 'must-not-be-read';

    expect(readBundledEnv()).toEqual({
      EXPO_PUBLIC_APP_ENV: 'family',
      EXPO_PUBLIC_SUPABASE_URL: 'https://abc.supabase.co',
      EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: PUBLISHABLE_KEY,
    });
  });
});
