import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';

// Google Vision, Text-to-Speech and Routes proxy. AI text tools use /api/openai-text.
const SERVICE_CONFIG: Record<string, { keyName: string; url: string }> = {
	vision: { keyName: 'google', url: 'https://vision.googleapis.com/v1/images:annotate' },
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
