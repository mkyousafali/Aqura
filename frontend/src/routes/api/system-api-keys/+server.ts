import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';

/**
 * system_api_keys admin CRUD (AQ-SEC-005 remediation).
 *
 * The ApiKeysManager settings screen used to read/write this table straight from the
 * browser with the public anon key. Since system_api_keys holds real, billable
 * third-party credentials (OpenAI, Google, ...) and its RLS policy allowed anyone to
 * read it directly via the public REST API (confirmed - not hypothetical), the table
 * is being locked down to server-only access. This is now the only thing that reads
 * or writes it; the browser only ever sees this endpoint's JSON.
 */
function getSupabase() {
	const supabaseUrl = env.VITE_SUPABASE_URL || '';
	const supabaseKey = env.VITE_SUPABASE_SERVICE_KEY || '';
	return createClient(supabaseUrl, supabaseKey);
}

export const GET: RequestHandler = async () => {
	try {
		const { data, error } = await getSupabase()
			.from('system_api_keys')
			.select('*')
			.order('service_name');
		if (error) return json({ success: false, error: error.message }, { status: 500 });
		return json({ success: true, keys: data || [] });
	} catch (error: any) {
		return json({ success: false, error: error.message || 'Internal server error' }, { status: 500 });
	}
};

export const POST: RequestHandler = async ({ request }) => {
	try {
		const { action, ...params } = await request.json();
		const supabase = getSupabase();

		if (action === 'update') {
			const { id, api_key, description, is_active } = params;
			if (!id) return json({ success: false, error: 'id is required' }, { status: 400 });
			const { error } = await supabase
				.from('system_api_keys')
				.update({ api_key, description, is_active })
				.eq('id', id);
			if (error) return json({ success: false, error: error.message }, { status: 500 });
			return json({ success: true });
		}

		if (action === 'toggle') {
			const { id, is_active } = params;
			if (!id) return json({ success: false, error: 'id is required' }, { status: 400 });
			const { error } = await supabase.from('system_api_keys').update({ is_active }).eq('id', id);
			if (error) return json({ success: false, error: error.message }, { status: 500 });
			return json({ success: true });
		}

		if (action === 'insert') {
			const { service_name, api_key, description } = params;
			if (!service_name?.trim() || !api_key?.trim()) {
				return json({ success: false, error: 'service_name and api_key are required' }, { status: 400 });
			}
			const { error } = await supabase.from('system_api_keys').insert({ service_name, api_key, description });
			if (error) return json({ success: false, error: error.message }, { status: 500 });
			return json({ success: true });
		}

		if (action === 'delete') {
			const { id } = params;
			if (!id) return json({ success: false, error: 'id is required' }, { status: 400 });
			const { error } = await supabase.from('system_api_keys').delete().eq('id', id);
			if (error) return json({ success: false, error: error.message }, { status: 500 });
			return json({ success: true });
		}

		return json({ success: false, error: `Unknown action '${action}'` }, { status: 400 });
	} catch (error: any) {
		return json({ success: false, error: error.message || 'Internal server error' }, { status: 500 });
	}
};
