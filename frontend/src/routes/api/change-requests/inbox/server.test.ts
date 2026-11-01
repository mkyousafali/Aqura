import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({ actor: vi.fn(), rpc: vi.fn(), branch: vi.fn(), from: vi.fn(), pending: [] as any[] }));
vi.mock('$lib/server/breakRegisterAuth', () => ({
  databaseClient: () => ({ rpc: mocks.rpc, from: mocks.from }), requireBreakUser: mocks.actor
}));
vi.mock('$lib/server/cashierChangeBranch', () => ({ cashierInBranch: mocks.branch }));
import { GET } from './+server';

const inbox = (token?: string, user = 'cashier', branch = '2') => GET({
  cookies: {}, url: new URL(`http://localhost/api/change-requests/inbox?branchId=${branch}`),
  request: new Request('http://localhost/api/change-requests/inbox', { headers: {
    'x-cashier-user-id': user, ...(token ? { 'x-cashier-session-token': token } : {})
  } })
} as any);

beforeEach(() => {
  vi.resetAllMocks(); mocks.pending = [];
  mocks.actor.mockResolvedValue({ id: 'cashier' });
  mocks.rpc.mockResolvedValue({ data: { valid: true }, error: null });
  mocks.branch.mockResolvedValue(true);
  mocks.from.mockImplementation((table: string) => {
    const result = { data: table === 'aqura_change_requests' ? mocks.pending : [], error: null };
    const query: any = { then: (resolve: any, reject: any) => Promise.resolve(result).then(resolve, reject) };
    for (const method of ['select', 'eq', 'in', 'order', 'limit']) query[method] = vi.fn(() => query);
    return query;
  });
});

describe('counter-closing pending change request check', () => {
  it('accepts the signed-in browser cashier without a Windows token', async () => {
    const response = await inbox();
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual([]);
    expect(mocks.actor).toHaveBeenCalledWith({}, 'cashier');
    expect(mocks.rpc).not.toHaveBeenCalled();
    expect(mocks.branch).toHaveBeenCalledWith(expect.anything(), 'cashier', 2);
  });
  it('rejects a missing or expired browser session', async () => {
    mocks.actor.mockRejectedValue(new Error('Expired'));
    expect((await inbox()).status).toBe(401);
    expect(mocks.from).not.toHaveBeenCalled();
  });
  it('rejects a browser session for another cashier', async () => {
    mocks.actor.mockResolvedValue({ id: 'another-user' });
    expect((await inbox()).status).toBe(403);
    expect(mocks.from).not.toHaveBeenCalled();
  });
  it('rejects a mismatched branch for either authentication path', async () => {
    mocks.branch.mockResolvedValue(false);
    expect((await inbox()).status).toBe(403);
    expect((await inbox('valid-device-token')).status).toBe(403);
    expect(mocks.from).not.toHaveBeenCalled();
  });
  it('preserves Windows device-session validation', async () => {
    expect((await inbox('valid-device-token')).status).toBe(200);
    expect(mocks.rpc).toHaveBeenCalledWith('heartbeat_cashier_session', { p_user_id: 'cashier', p_session_token: 'valid-device-token' });
    expect(mocks.actor).not.toHaveBeenCalled();
  });
  it('never uses a browser cookie to bypass an invalid Windows token', async () => {
    mocks.rpc.mockResolvedValue({ data: { valid: false }, error: null });
    expect((await inbox('expired-device-token')).status).toBe(401);
    expect(mocks.actor).not.toHaveBeenCalled();
    expect(mocks.from).not.toHaveBeenCalled();
  });
  it('still returns pending requests so closing remains blocked until they are resolved', async () => {
    mocks.pending = [{ id: 'pending-id', request_number: 'CR-1', requested_to_user_id: 'safe-box', status: 'Pending' }];
    const response = await inbox();
    expect(response.status).toBe(200);
    expect((await response.json())[0]).toMatchObject({ request_number: 'CR-1', status: 'Pending' });
  });
  it('rejects missing cashier identity or invalid branch before querying', async () => {
    expect((await inbox(undefined, '')).status).toBe(400);
    expect((await inbox(undefined, 'cashier', '0')).status).toBe(400);
    expect(mocks.from).not.toHaveBeenCalled();
  });
});
