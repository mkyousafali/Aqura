import { beforeEach, describe, expect, it, vi } from 'vitest';

const db = vi.hoisted(() => ({ rpc: vi.fn() }));
vi.mock('$lib/server/breakRegisterAuth', () => ({
  databaseClient: () => db,
  requireBreakUser: vi.fn(),
  createSupabaseAuthSession: vi.fn(),
  setBreakSession: vi.fn(),
}));
vi.mock('$lib/server/employeeLoginOtp', () => ({
  issueEmployeeLoginOtp: vi.fn(),
  verifyEmployeeLoginOtp: vi.fn(),
}));

import { POST } from '../../routes/api/auth/employee-session/+server';
import { clearEmployeeLoginFailures } from './employeeLoginRateLimit';

const address = 'test-database-outage';
const login = () => POST({
  request: new Request('http://localhost/api/auth/employee-session', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ quickAccessCode: '123456' }),
  }),
  url: new URL('http://localhost/api/auth/employee-session'),
  cookies: {},
  getClientAddress: () => address,
} as any);

beforeEach(() => {
  clearEmployeeLoginFailures(address);
  db.rpc.mockReset();
});

describe('employee login failures', () => {
  it('does not lock out the client after database failures', async () => {
    db.rpc.mockResolvedValue({ data: null, error: new Error('Database unavailable') });
    const log = vi.spyOn(console, 'error').mockImplementation(() => {});
    try {
      for (let index = 0; index < 6; index++) {
        expect((await login()).status).toBe(503);
      }
      db.rpc.mockResolvedValue({ data: { success: false }, error: null });
      expect((await login()).status).toBe(401);
    } finally {
      log.mockRestore();
    }
  });

  it('still blocks after five incorrect codes', async () => {
    db.rpc.mockResolvedValue({ data: { success: false }, error: null });
    for (let index = 0; index < 5; index++) {
      expect((await login()).status).toBe(401);
    }
    expect((await login()).status).toBe(429);
  });
});
