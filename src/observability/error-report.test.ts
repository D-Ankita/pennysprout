import {
  buildErrorReport,
  createErrorReporter,
  sanitizeStack,
  type ErrorReportContext,
} from './error-report';

const context: ErrorReportContext = {
  appVersion: '0.1.0',
  buildNumber: '1',
  environment: 'family',
  deviceInstallId: '30000000-0000-0000-0000-000000000001',
};

const OCCURRED_AT = new Date(Date.UTC(2026, 8, 30, 6, 30, 0));

describe('sanitizeStack', () => {
  it('keeps recognised frames and drops the message line', () => {
    const raw = [
      'TypeError: cannot spend 500 for gagan',
      '    at render (index.android.bundle:1:2345)',
      '    at anonymous (native)',
      '    at address at index.android.bundle:1:99',
    ].join('\n');

    expect(sanitizeStack(raw)).toBe(
      [
        '    at render (index.android.bundle:1:2345)',
        '    at anonymous (native)',
        '    at address at index.android.bundle:1:99',
      ].join('\n'),
    );
  });

  it('drops frames containing URLs or query strings', () => {
    expect(
      sanitizeStack('    at fn (http://10.0.2.2:8081/index.bundle?platform=android:10:2)'),
    ).toBeNull();
  });

  it.each([undefined, null, 42, '', 'plain message only'])('returns null for %p', (raw) => {
    expect(sanitizeStack(raw)).toBeNull();
  });

  it('limits the stack to 30 frames', () => {
    const raw = Array.from({ length: 40 }, (_, i) => `at f${i} (index.android.bundle:1:${i})`).join(
      '\n',
    );
    expect(sanitizeStack(raw)?.split('\n')).toHaveLength(30);
  });

  it('limits the stack to 4000 characters', () => {
    const name = 'a'.repeat(120);
    const path = 'b'.repeat(200);
    const raw = Array.from({ length: 30 }, () => `at ${name} (${path}:1:1)`).join('\n');
    const result = sanitizeStack(raw);
    expect(result).not.toBeNull();
    expect(result!.length).toBeLessThanOrEqual(4000);
  });
});

describe('buildErrorReport', () => {
  it('produces the allow-listed RPC parameters', () => {
    expect(
      buildErrorReport(
        {
          errorCode: 'RENDER_FAILED',
          route: '/(child)/wallet/[id]',
          occurredAt: OCCURRED_AT,
          stack: 'at render (index.android.bundle:1:2)',
        },
        context,
      ),
    ).toEqual({
      p_error_code: 'RENDER_FAILED',
      p_app_version: '0.1.0',
      p_build_number: '1',
      p_environment: 'family',
      p_platform: 'android',
      p_route: '/(child)/wallet/[id]',
      p_occurred_at: '2026-09-30T06:30:00.000Z',
      p_stack: 'at render (index.android.bundle:1:2)',
      p_device_install_id: context.deviceInstallId,
    });
  });

  it('replaces free-form codes and routes with safe placeholders', () => {
    const params = buildErrorReport(
      { errorCode: 'failed for gagan', route: 'wallet?amount=500', occurredAt: OCCURRED_AT },
      context,
    );
    expect(params.p_error_code).toBe('UNKNOWN_ERROR');
    expect(params.p_route).toBe('/unknown');
    expect(params.p_stack).toBeNull();
  });
});

describe('createErrorReporter', () => {
  const input = { errorCode: 'RENDER_FAILED', route: '/wallet', occurredAt: OCCURRED_AT };

  it('submits sanitized reports', async () => {
    const submit = jest.fn(async () => undefined);
    await createErrorReporter({ context, submit })(input);
    expect(submit).toHaveBeenCalledWith(expect.objectContaining({ p_error_code: 'RENDER_FAILED' }));
  });

  it('never rejects when submission fails', async () => {
    const submit = jest.fn(async () => {
      throw new Error('network down');
    });
    await expect(createErrorReporter({ context, submit })(input)).resolves.toBeUndefined();
  });

  it('drops reports beyond the hourly limit and resumes after an hour', async () => {
    let clock = 0;
    const submit = jest.fn(async () => undefined);
    const report = createErrorReporter({ context, submit, now: () => clock, maxPerHour: 2 });

    await report(input);
    await report(input);
    await report(input);
    expect(submit).toHaveBeenCalledTimes(2);

    clock = 60 * 60 * 1000;
    await report(input);
    expect(submit).toHaveBeenCalledTimes(3);
  });

  it('uses the default clock and limit', async () => {
    const submit = jest.fn(async () => undefined);
    const report = createErrorReporter({ context, submit });
    for (let i = 0; i < 12; i += 1) {
      await report(input);
    }
    expect(submit).toHaveBeenCalledTimes(10);
  });
});
