import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

async function authorize(cookies: Parameters<typeof requireBreakUser>[0]) {
	const actor = await requireBreakUser(cookies, 'desktop');
	if (actor.isMasterAdmin) return actor;
	const { data, error } = await databaseClient().from('button_permissions').select('is_enabled')
		.eq('user_id', actor.id).eq('button_code', 'OTP_LOGIN_CONTROL').eq('is_enabled', true).maybeSingle();
	if (error || !data) throw new Error('OTP Login Control permission required');
	return actor;
}

export const GET: RequestHandler = async ({ cookies }) => {
	try {
		await authorize(cookies);
		const { data, error } = await databaseClient().from('employee_login_otp_settings')
			.select('interface_type,delivery_mode,updated_at').order('interface_type');
		if (error) throw error;
		return json({ success: true, settings: data || [] });
	} catch (error) {
		return json({ success: false, error: error instanceof Error ? error.message : 'Access denied' }, { status: 403 });
	}
};

export const PUT: RequestHandler = async ({ cookies, request }) => {
	try {
		const actor = await authorize(cookies);
		const body = await request.json();
		if (!['cashier', 'mobile', 'desktop'].includes(body.interfaceType) || !['disabled', 'email', 'whatsapp', 'both'].includes(body.deliveryMode)) {
			return json({ success: false, error: 'Invalid OTP setting' }, { status: 400 });
		}
		const { data, error } = await databaseClient().from('employee_login_otp_settings').upsert({
			interface_type: body.interfaceType, delivery_mode: body.deliveryMode,
			updated_at: new Date().toISOString(), updated_by: actor.id
		}).select('interface_type,delivery_mode,updated_at').single();
		if (error) throw error;
		return json({ success: true, setting: data });
	} catch (error) {
		return json({ success: false, error: error instanceof Error ? error.message : 'Update failed' }, { status: 403 });
	}
};
