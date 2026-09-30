import type { AppEnvironment } from '@/config/env';

// Client side of the free Supabase crash-reporting contract (report_client_error).
// Only sanitized, allow-listed fields leave the device. The server validates again.

export const ERROR_CODE_PATTERN = /^[A-Z][A-Z0-9_]{1,63}$/;
export const ROUTE_PATTERN = /^\/[A-Za-z0-9_/()[\].-]{0,199}$/;
const FRAME_PATTERNS = [
  /^ {0,8}at [A-Za-z0-9_$.<>?[\] ]{1,120} \((native|(address at )?[A-Za-z0-9_./-]{1,200}:[0-9]{1,7}:[0-9]{1,7})\)$/,
  /^ {0,8}at (address at )?[A-Za-z0-9_./-]{1,200}:[0-9]{1,7}:[0-9]{1,7}$/,
];
const MAX_STACK_LINES = 30;
const MAX_STACK_CHARS = 4000;

export type ErrorReportInput = {
  errorCode: string;
  /** Route template such as `/(child)/wallet/[id]`, never a URL with values. */
  route: string;
  occurredAt: Date;
  stack?: unknown;
};

export type ErrorReportContext = {
  appVersion: string;
  buildNumber: string;
  environment: AppEnvironment;
  deviceInstallId: string;
};

export type ErrorReportParams = {
  p_error_code: string;
  p_app_version: string;
  p_build_number: string;
  p_environment: AppEnvironment;
  p_platform: 'android';
  p_route: string;
  p_occurred_at: string;
  p_stack: string | null;
  p_device_install_id: string;
};

/**
 * Keeps only recognised stack-frame lines. Error messages and any other text,
 * which may contain user input or values, are dropped. Returns null when no
 * frame can be kept safely.
 */
export function sanitizeStack(raw: unknown): string | null {
  if (typeof raw !== 'string') {
    return null;
  }
  const frames: string[] = [];
  let length = 0;
  for (const line of raw.split('\n')) {
    const frame = line.replace(/^\s+/, '    ').trimEnd();
    if (!FRAME_PATTERNS.some((pattern) => pattern.test(frame))) {
      continue;
    }
    const added = frame.length + (frames.length > 0 ? 1 : 0);
    if (frames.length >= MAX_STACK_LINES || length + added > MAX_STACK_CHARS) {
      break;
    }
    frames.push(frame);
    length += added;
  }
  return frames.length > 0 ? frames.join('\n') : null;
}

export function buildErrorReport(
  input: ErrorReportInput,
  context: ErrorReportContext,
): ErrorReportParams {
  return {
    p_error_code: ERROR_CODE_PATTERN.test(input.errorCode) ? input.errorCode : 'UNKNOWN_ERROR',
    p_app_version: context.appVersion,
    p_build_number: context.buildNumber,
    p_environment: context.environment,
    p_platform: 'android',
    p_route: ROUTE_PATTERN.test(input.route) ? input.route : '/unknown',
    p_occurred_at: input.occurredAt.toISOString(),
    p_stack: sanitizeStack(input.stack),
    p_device_install_id: context.deviceInstallId,
  };
}

export type ErrorReporterOptions = {
  context: ErrorReportContext;
  submit: (params: ErrorReportParams) => Promise<unknown>;
  now?: () => number;
  maxPerHour?: number;
};

/**
 * Returns a fire-and-forget reporter. It never throws or rejects, so a failed
 * report cannot change product behaviour. The server enforces the same limit.
 */
export function createErrorReporter({
  context,
  submit,
  now = Date.now,
  maxPerHour = 10,
}: ErrorReporterOptions): (input: ErrorReportInput) => Promise<void> {
  let sentAt: number[] = [];
  return async (input) => {
    try {
      const current = now();
      sentAt = sentAt.filter((time) => current - time < 60 * 60 * 1000);
      if (sentAt.length >= maxPerHour) {
        return;
      }
      sentAt.push(current);
      await submit(buildErrorReport(input, context));
    } catch {
      // Reporting failures are intentionally ignored.
    }
  };
}
