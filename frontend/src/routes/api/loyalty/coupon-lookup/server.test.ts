import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({ user: vi.fn(), from: vi.fn(), result: vi.fn(), used: vi.fn(), eq: vi.fn() }));
vi.mock('$lib/server/breakRegisterAuth', () => ({ requireBreakUser: mocks.user, databaseClient: () => ({ from: mocks.from }) }));
import { POST } from './+server';

const lookup = (code: string, origin = 'http://localhost') => POST({
  cookies: {}, url: new URL('http://localhost/api/loyalty/coupon-lookup'),
  request: new Request('http://localhost/api/loyalty/coupon-lookup', { method: 'POST', headers: { Origin: origin, 'Content-Type': 'application/json' }, body: JSON.stringify({ couponCode: code }) })
} as any);

beforeEach(() => {
  vi.resetAllMocks();
  mocks.user.mockResolvedValue({ id: 'cashier' });
  const query = { select: vi.fn().mockReturnThis(), eq: mocks.eq, maybeSingle: mocks.result };
  mocks.eq.mockReturnValue(query);
  mocks.from.mockImplementation((table: string) => table === 'loyalty_coupon_uses' ? { select: () => ({ eq: () => ({ maybeSingle: mocks.used }) }) } : query);
  mocks.used.mockResolvedValue({ data: null, error: null });
  mocks.result.mockResolvedValue({ data: { id: 'redemption-id', coupon_code: 'LYL-ABC12345', coupon_value: '101.45' }, error: null });
});

describe('loyalty coupon amount lookup', () => {
  it('returns only the confirmed coupon code and amount, normalizing input', async () => {
    const response = await lookup(' lyl-abc12345 ');
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ couponCode: 'LYL-ABC12345', amount: 101.45 });
    expect(mocks.eq).toHaveBeenCalledWith('coupon_code', 'LYL-ABC12345');
    expect(mocks.eq).toHaveBeenCalledWith('status', 'confirmed');
    expect(response.headers.get('cache-control')).toBe('no-store');
  });
  it('rejects a coupon already accepted at counter closing', async () => {
    mocks.used.mockResolvedValue({ data: { redemption_id: 'redemption-id' }, error: null });
    const response = await lookup('LYL-ABC12345');
    expect(response.status).toBe(409);
    expect((await response.json()).error).toContain('already been used');
  });
  it('does not allow lookup when use tracking is unavailable', async () => {
    mocks.used.mockResolvedValue({ data: null, error: { message: 'unavailable' } });
    expect((await lookup('LYL-ABC12345')).status).toBe(503);
  });
  it('requires a cashier session before accessing coupon records', async () => {
    mocks.user.mockRejectedValue(new Error('No session'));
    expect((await lookup('LYL-ABC12345')).status).toBe(401);
    expect(mocks.from).not.toHaveBeenCalled();
  });
  it('rejects invalid coupon numbers and cross-origin requests', async () => {
    expect((await lookup('invalid')).status).toBe(400);
    expect((await lookup('LYL-ABC12345', 'https://other.test')).status).toBe(403);
    expect(mocks.from).not.toHaveBeenCalled();
  });
  it('does not return pending, expired or missing coupons', async () => {
    mocks.result.mockResolvedValue({ data: null, error: null });
    expect((await lookup('LYL-ABC12345')).status).toBe(404);
  });
  it('fails safely when the database or coupon amount is invalid', async () => {
    mocks.result.mockResolvedValue({ data: null, error: { message: 'private details' } });
    const response = await lookup('LYL-ABC12345');
    expect(response.status).toBe(503);
    expect(JSON.stringify(await response.json())).not.toContain('private details');
    mocks.result.mockResolvedValue({ data: { coupon_value: 'invalid' }, error: null });
    expect((await lookup('LYL-ABC12345')).status).toBe(503);
  });
});
