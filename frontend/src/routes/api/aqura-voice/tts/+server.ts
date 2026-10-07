import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { aquraVoiceAuthError, requireAquraVoiceUser } from '$lib/server/aquraVoiceAuth';

export const POST: RequestHandler = async ({ request }) => {
	try {
		const { db } = await requireAquraVoiceUser(request);
		const body = await request.json();
		const text = typeof body?.text === 'string' ? body.text.trim() : '';
		const languageCode = typeof body?.languageCode === 'string' ? body.languageCode.trim() : '';
		if (!text || text.length > 5000 || !/^[A-Za-z]{2,3}(?:-[A-Za-z]{2,4})?$/.test(languageCode)) {
			return json({ success: false, error: 'Invalid speech request' }, { status: 400 });
		}
		const { data: key } = await db.from('system_api_keys').select('api_key')
			.eq('service_name', 'google').eq('is_active', true).maybeSingle();
		if (!key?.api_key) return json({ success: false, error: 'Google API key is not configured' }, { status: 503 });
		const response = await fetch(`https://texttospeech.googleapis.com/v1/text:synthesize?key=${key.api_key}`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				input: { text },
				voice: { languageCode, ssmlGender: 'NEUTRAL' },
				audioConfig: { audioEncoding: 'MP3' }
			}),
			signal: AbortSignal.timeout(60000)
		});
		const result = await response.json();
		if (!response.ok) throw new Error(result?.error?.message || 'Speech generation failed');
		return json({ success: true, audioContent: result.audioContent });
	} catch (error) {
		const auth = aquraVoiceAuthError(error);
		return auth || json({ success: false, error: error instanceof Error ? error.message : 'Speech generation failed' }, { status: 500 });
	}
};
