import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';

/**
 * Returns the Google Maps JavaScript API key (AQ-SEC-005 remediation).
 *
 * Deliberately different from the other Google services here: the Maps JavaScript API
 * has to run in the browser to render an interactive map, so this key reaching the
 * client is expected and is Google's own design for this key type (secured by HTTP
 * referrer restriction in Google Cloud Console, not secrecy) — unlike the Vision/
 * Gemini/TTS/Routes keys, which never need to leave the server and are proxied instead.
 *
 * The point of routing this through a server endpoint isn't to hide the key (it's
 * shown to the browser either way) — it's so this one narrow endpoint is the only
 * thing reading system_api_keys for this purpose, instead of the browser querying
 * that table (and every other key in it) directly.
 */
export const GET: RequestHandler = async () => {
	try {
		const supabaseUrl = env.VITE_SUPABASE_URL || '';
		const supabaseKey = env.VITE_SUPABASE_SERVICE_KEY || '';
		const supabase = createClient(supabaseUrl, supabaseKey);

		const { data, error } = await supabase
			.from('system_api_keys')
			.select('api_key')
			.eq('service_name', 'google')
			.eq('is_active', true)
			.single();

		if (error || !data?.api_key) {
			return json({ success: false, error: 'No active Google Maps key configured' }, { status: 404 });
		}
		return json({ success: true, apiKey: data.api_key });
	} catch (error: any) {
		return json({ success: false, error: error.message || 'Internal server error' }, { status: 500 });
	}
};
