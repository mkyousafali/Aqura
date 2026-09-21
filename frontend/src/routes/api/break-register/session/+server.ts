import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { clearBreakSession, databaseClient, setBreakSession, switchBreakSession } from '$lib/server/breakRegisterAuth';

export const POST: RequestHandler = async ({ request, cookies, url }) => {
	try {
		const body = await request.json();
		const kind = body.interfaceType === 'mobile' ? 'mobile' : 'desktop';
		const db = databaseClient();
		let userId: string | undefined;
		if (typeof body.quickAccessCode === 'string' && /^[0-9]{6}$/.test(body.quickAccessCode)) {
			const { data, error } = await db.rpc('verify_quick_access_code', { p_code: body.quickAccessCode });
			if (!error && data?.success) userId = data.user?.id;
		} else if (typeof body.accessToken === 'string') {
			const { data, error } = await db.auth.getUser(body.accessToken);
			if (!error) userId = data.user?.id;
		}
		if (!userId) return json({ error: 'Authentication failed' }, { status: 401 });
		const { data: user } = await db.from('users').select('status').eq('id', userId).single();
		if (user?.status !== 'active') return json({ error: 'User is inactive' }, { status: 403 });
		const { data: interfacePermission, error: permissionError } = await db.from('interface_permissions')
			.select('desktop_enabled,mobile_enabled').eq('user_id', userId).maybeSingle();
		if (permissionError) throw permissionError;
		if (interfacePermission && interfacePermission[`${kind}_enabled`] === false) {
			return json({ error: 'Interface access denied' }, { status: 403 });
		}
		setBreakSession(cookies, userId, url.protocol === 'https:', kind);
		return json({ success: true });
	} catch {
		return json({ error: 'Authentication failed' }, { status: 401 });
	}
};

export const DELETE: RequestHandler = async ({ cookies, request }) => {
	clearBreakSession(cookies, request.headers.get('x-aqura-interface') === 'mobile' ? 'mobile' : 'desktop');
	return json({ success: true });
};

export const PUT: RequestHandler = async ({ cookies, request, url }) => {
	const body = await request.json().catch(() => ({}));
	if (typeof body.userId !== 'string') return json({ error: 'User required' }, { status: 400 });
	if (!switchBreakSession(cookies, body.userId, url.protocol === 'https:', 'desktop')) return json({ error: 'No verified session for this user' }, { status: 403 });
	return json({ success: true });
};
