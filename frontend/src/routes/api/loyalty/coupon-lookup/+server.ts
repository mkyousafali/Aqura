import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

const headers = { 'Cache-Control': 'no-store' };

export const POST: RequestHandler = async ({ cookies, request, url }) => {
  const origin = request.headers.get('origin');
  if (origin && origin !== url.origin) return json({ error: 'Invalid origin' }, { status: 403, headers });
  try { await requireBreakUser(cookies, 'cashier'); }
  catch { return json({ error: 'Cashier session required' }, { status: 401, headers }); }

  let code: string;
  try {
    const body = await request.json();
    code = typeof body?.couponCode === 'string' ? body.couponCode.trim().toUpperCase() : '';
    if (!/^LYL-[A-Z0-9]{8}$/.test(code)) return json({ error: 'Invalid coupon code' }, { status: 400, headers });
  } catch { return json({ error: 'Invalid request' }, { status: 400, headers }); }

  try {
    // Lookup never consumes a coupon; closing consumes it atomically in the database.
    const { data, error } = await databaseClient().from('loyalty_redemptions')
      .select('id,coupon_code,coupon_value').eq('coupon_code', code).eq('status', 'confirmed').maybeSingle();
    if (error) throw error;
    if (!data) return json({ error: 'Confirmed coupon not found' }, { status: 404, headers });
    const { data: used, error: useError } = await databaseClient().from('loyalty_coupon_uses')
      .select('redemption_id').eq('redemption_id', data.id).maybeSingle();
    if (useError) throw useError;
    if (used) return json({ error: 'This loyalty coupon has already been used' }, { status: 409, headers });
    const amount = Number(data.coupon_value);
    if (!Number.isFinite(amount) || amount <= 0) throw new Error('Invalid coupon value');
    return json({ couponCode: data.coupon_code, amount }, { headers });
  } catch { return json({ error: 'Coupon lookup unavailable' }, { status: 503, headers }); }
};
