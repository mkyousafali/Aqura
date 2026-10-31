import { describe, expect, it } from "vitest";
import {
  clearEmployeeLoginFailures,
  employeeLoginLimit,
  employeeLoginRateLimitPolicy,
  recordEmployeeLoginFailure,
} from "./employeeLoginRateLimit";

describe("employee login rate limiting", () => {
  it("keeps the full block when failures happen near the end of a window", () => {
    const key = `test-${crypto.randomUUID()}`;
    const now = 1_000_000;
    recordEmployeeLoginFailure(key, now);
    const blockedAt = now + employeeLoginRateLimitPolicy.windowMs - 1000;
    for (let index = 1; index < employeeLoginRateLimitPolicy.maxFailures; index++)
      recordEmployeeLoginFailure(key, blockedAt);
    expect(employeeLoginLimit(key, now + employeeLoginRateLimitPolicy.windowMs).allowed).toBe(false);
    expect(employeeLoginLimit(key, blockedAt + employeeLoginRateLimitPolicy.blockMs).allowed).toBe(true);
    clearEmployeeLoginFailures(key);
  });
  it("blocks a client after the configured number of failures", () => {
    const key = `test-${crypto.randomUUID()}`;
    const now = 1_000_000;
    for (
      let index = 0;
      index < employeeLoginRateLimitPolicy.maxFailures;
      index += 1
    )
      recordEmployeeLoginFailure(key, now + index);
    expect(
      employeeLoginLimit(key, now + employeeLoginRateLimitPolicy.maxFailures)
        .allowed,
    ).toBe(false);
    clearEmployeeLoginFailures(key);
  });

  it("clears failures after successful authentication", () => {
    const key = `test-${crypto.randomUUID()}`;
    recordEmployeeLoginFailure(key, 2_000_000);
    clearEmployeeLoginFailures(key);
    expect(employeeLoginLimit(key, 2_000_001).allowed).toBe(true);
  });
});
