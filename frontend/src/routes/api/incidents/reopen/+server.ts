import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';

export const POST: RequestHandler = async ({ request }) => {
	try {
		const { incidentId, actorUserId, sessionToken } = await request.json();
		if (!incidentId || !actorUserId || !sessionToken) {
			return json({ success: false, error: 'A valid incident and user session are required' }, { status: 400 });
		}

		const supabaseUrl = env.VITE_SUPABASE_URL || '';
		const serviceKey = env.VITE_SUPABASE_SERVICE_KEY || '';
		if (!supabaseUrl || !serviceKey) {
			return json({ success: false, error: 'Server database configuration is unavailable' }, { status: 500 });
		}

		const supabase = createClient(supabaseUrl, serviceKey, {
			auth: { persistSession: false, autoRefreshToken: false }
		});
		const { data, error } = await supabase.rpc('reopen_incident_cascade', {
			p_incident_id: String(incidentId),
			p_actor_user_id: actorUserId,
			p_session_token: sessionToken
		});

		if (error) {
			const unauthorized = error.code === '42501';
			return json({ success: false, error: error.message }, { status: unauthorized ? 403 : 500 });
		}

		return json({ success: true, result: data });
	} catch (error: any) {
		return json({ success: false, error: error?.message || 'Internal server error' }, { status: 500 });
	}
};
