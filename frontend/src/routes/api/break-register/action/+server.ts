import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';
import { env } from '$env/dynamic/private';

async function analyzeBreak(breakId: string | undefined): Promise<void> {
	if (!breakId || !env.VITE_SUPABASE_URL || !env.VITE_SUPABASE_SERVICE_KEY) return;
	const response = await fetch(`${env.VITE_SUPABASE_URL}/functions/v1/analyze-breaks`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${env.VITE_SUPABASE_SERVICE_KEY}` },
		body: JSON.stringify({ breakId })
	});
	if (!response.ok) console.error('Break saved, but immediate analysis failed:', await response.text());
}

export const GET: RequestHandler = async ({ cookies }) => {
	try {
		const user = await requireBreakUser(cookies, 'mobile');
		const { data, error } = await databaseClient().rpc('get_active_break', { p_user_id: user.id });
		if (error) throw error;
		return json(data);
	} catch { return json({ error: 'Unable to load active break' }, { status: 401 }); }
};

export const POST: RequestHandler = async ({ cookies, request }) => {
	try {
		const user = await requireBreakUser(cookies, 'mobile');
		const body = await request.json();
		if (typeof body.securityCode !== 'string') return json({ error: 'Security code required' }, { status: 400 });
		const starting = body.action === 'start';
		if (!starting && body.action !== 'end') return json({ error: 'Invalid action' }, { status: 400 });
		if (starting && (!Number.isSafeInteger(body.reasonId) || body.reasonId <= 0)) return json({ error: 'Invalid reason' }, { status: 400 });
		const { data, error } = await databaseClient().rpc(starting ? 'start_break' : 'end_break', starting
			? { p_user_id: user.id, p_reason_id: body.reasonId, p_reason_note: typeof body.reasonNote === 'string' ? body.reasonNote : null, p_security_code: body.securityCode }
			: { p_user_id: user.id, p_security_code: body.securityCode });
		if (error) throw error;
		if (data?.success) await analyzeBreak(data.break_id);
		return json(data);
	} catch { return json({ error: 'Break action failed' }, { status: 401 }); }
};
