const WINDOW_MS = 15 * 60 * 1000;
const BLOCK_MS = 15 * 60 * 1000;
const MAX_FAILURES = 5;

type AttemptState = {
  failures: number;
  windowStartedAt: number;
  blockedUntil: number;
};
const attempts = new Map<string, AttemptState>();

function currentState(key: string, now: number): AttemptState {
  const existing = attempts.get(key);
  if (!existing || now - existing.windowStartedAt >= WINDOW_MS) {
    const fresh = { failures: 0, windowStartedAt: now, blockedUntil: 0 };
    attempts.set(key, fresh);
    return fresh;
  }
  return existing;
}

export function employeeLoginLimit(
  key: string,
  now = Date.now(),
): { allowed: boolean; retryAfterSeconds: number } {
  const state = currentState(key, now);
  if (state.blockedUntil > now) {
    return {
      allowed: false,
      retryAfterSeconds: Math.max(
        1,
        Math.ceil((state.blockedUntil - now) / 1000),
      ),
    };
  }
  return { allowed: true, retryAfterSeconds: 0 };
}

export function recordEmployeeLoginFailure(
  key: string,
  now = Date.now(),
): void {
  const state = currentState(key, now);
  state.failures += 1;
  if (state.failures >= MAX_FAILURES) state.blockedUntil = now + BLOCK_MS;
  attempts.set(key, state);
}

export function clearEmployeeLoginFailures(key: string): void {
  attempts.delete(key);
}

export const employeeLoginRateLimitPolicy = {
  windowMs: WINDOW_MS,
  blockMs: BLOCK_MS,
  maxFailures: MAX_FAILURES,
} as const;
