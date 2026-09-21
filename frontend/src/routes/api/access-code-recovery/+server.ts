import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient } from '$lib/server/breakRegisterAuth';

export const POST: RequestHandler = async ({ request }) => {
  try {
    const body = await request.json();
    if (typeof body.email !== 'string' || typeof body.whatsapp !== 'string' ||
        typeof body.otp !== 'string' || typeof body.newCode !== 'string' ||
        !/^\d{6}$/.test(body.otp) || !/^\d{6}$/.test(body.newCode)) {
      return json({ success: false, message: 'Invalid recovery details' }, { status: 400 });
    }
    const { data, error } = await databaseClient().rpc('verify_otp_and_change_access_code', {
      p_email: body.email, p_whatsapp: body.whatsapp, p_otp: body.otp, p_new_code: body.newCode
    });
    if (error) throw error;
    return json(data);
  } catch {
    return json({ success: false, message: 'Access code recovery failed' }, { status: 500 });
  }
};
