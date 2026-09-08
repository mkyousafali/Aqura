import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';

/**
 * Google AI/Maps API Proxy (AQ-SEC-005 remediation).
 *
 * Several pages used to fetch a real Google API key (service_name='google' or
 * 'google_gemini' in system_api_keys) straight into the browser and call Google's
 * Vision/Gemini/Text-to-Speech/Routes APIs directly with it. That means every visitor's
 * browser could see - and reuse - a real, billable Google credential.
 *
 * This is the only place that now reads those keys. Callers send
 * { service: 'vision' | 'gemini' | 'tts' | 'routes', body, fieldMask? } and get back
 * exactly what Google returned - the request/response shape callers already handle is
 * unchanged, only the transport (and the key) moved server-side.
 */

const SERVICE_CONFIG: Record<string, { keyName: string; url: string }> = {
	vision: { keyName: 'google', url: 'https://vision.googleapis.com/v1/images:annotate' },
	gemini: {
		keyName: 'google_gemini',
		url: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'
	},
	tts: { keyName: 'google', url: 'https://texttospeech.googleapis.com/v1/text:synthesize' },
	routes: { keyName: 'google', url: 'https://routes.googleapis.com/directions/v2:computeRoutes' }
};

export const POST: RequestHandler = async ({ request }) => {
	try {
		const { service, body, fieldMask } = await request.json();

		const config = SERVICE_CONFIG[service];
		if (!config) {
			return json({ success: false, error: `Unknown service '${service}'` }, { status: 400 });
		}

		const supabaseUrl = env.VITE_SUPABASE_URL || '';
		const supabaseKey = env.VITE_SUPABASE_SERVICE_KEY || env.VITE_SUPABASE_ANON_KEY || '';
		const supabase = createClient(supabaseUrl, supabaseKey);

		const { data, error } = await supabase
			.from('system_api_keys')
			.select('api_key')
			.eq('service_name', config.keyName)
			.eq('is_active', true)
			.single();

		if (error || !data?.api_key) {
			return json({ success: false, error: `No active API key configured for '${config.keyName}'` }, { status: 404 });
		}
		const apiKey = data.api_key;

		const controller = new AbortController();
		const timeout = setTimeout(() => controller.abort(), 30000);

		let googleResponse: Response;
		try {
			if (service === 'routes') {
				// Routes API takes the key as a header, not a query param, and needs a field mask.
				googleResponse = await fetch(config.url, {
					method: 'POST',
					headers: {
						'Content-Type': 'application/json',
						'X-Goog-Api-Key': apiKey,
						'X-Goog-FieldMask': fieldMask || 'routes.localizedValues'
					},
					body: JSON.stringify(body),
					signal: controller.signal
				});
			} else {
				googleResponse = await fetch(`${config.url}?key=${apiKey}`, {
					method: 'POST',
					headers: { 'Content-Type': 'application/json' },
					body: JSON.stringify(body),
					signal: controller.signal
				});
			}
		} finally {
			clearTimeout(timeout);
		}

		const contentType = googleResponse.headers.get('content-type') || 'application/json';
		const bodyText = await googleResponse.text();

		return new Response(bodyText, {
			status: googleResponse.status,
			headers: { 'Content-Type': contentType }
		});
	} catch (error: any) {
		return json({ success: false, error: error.message || 'Internal server error' }, { status: 500 });
	}
};
