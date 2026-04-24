/**
 * Server-side endpoint for AI Marketing.
 *
 *   GET  /api/ai-marketing/test-connection            → verify Service Account auth + Vertex AI reachability
 *   POST /api/ai-marketing/test-connection { prompt } → quick Gemini round-trip
 *
 * Uses GOOGLE_PROJECT_ID / GOOGLE_CLIENT_EMAIL / GOOGLE_PRIVATE_KEY / GOOGLE_LOCATION
 * from environment variables (server-only — never exposed to the browser).
 */
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { env } from '$env/dynamic/private';
import crypto from 'node:crypto';

let cachedToken: { value: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
	if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) return cachedToken.value;

	const clientEmail = env.GOOGLE_CLIENT_EMAIL;
	const privateKeyRaw = env.GOOGLE_PRIVATE_KEY;
	if (!clientEmail || !privateKeyRaw) {
		throw new Error('Missing GOOGLE_CLIENT_EMAIL or GOOGLE_PRIVATE_KEY in environment');
	}
	const privateKey = privateKeyRaw.replace(/\\n/g, '\n');

	const b64url = (buf: Buffer | string) =>
		Buffer.from(buf as any).toString('base64').replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');

	const now = Math.floor(Date.now() / 1000);
	const header = { alg: 'RS256', typ: 'JWT' };
	const payload = {
		iss: clientEmail,
		scope: 'https://www.googleapis.com/auth/cloud-platform',
		aud: 'https://oauth2.googleapis.com/token',
		iat: now,
		exp: now + 3600
	};
	const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
	const signer = crypto.createSign('RSA-SHA256');
	signer.update(signingInput);
	signer.end();
	const sig = signer.sign(privateKey);
	const jwt = `${signingInput}.${b64url(sig)}`;

	const res = await fetch('https://oauth2.googleapis.com/token', {
		method: 'POST',
		headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
		body: new URLSearchParams({
			grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
			assertion: jwt
		})
	});
	const body = await res.json();
	if (!res.ok || !body.access_token) {
		throw new Error(`Token exchange failed: ${JSON.stringify(body)}`);
	}
	cachedToken = {
		value: body.access_token,
		expiresAt: Date.now() + (body.expires_in ?? 3600) * 1000
	};
	return cachedToken.value;
}

export const GET: RequestHandler = async () => {
	const projectId = env.GOOGLE_PROJECT_ID;
	const location = env.GOOGLE_LOCATION || 'europe-west4';
	const clientEmail = env.GOOGLE_CLIENT_EMAIL;

	const config = {
		projectConfigured: Boolean(projectId),
		emailConfigured: Boolean(clientEmail),
		privateKeyConfigured: Boolean(env.GOOGLE_PRIVATE_KEY),
		projectId,
		clientEmail,
		location
	};

	if (!projectId || !clientEmail || !env.GOOGLE_PRIVATE_KEY) {
		return json(
			{ ok: false, stage: 'config', message: 'Missing GOOGLE_PROJECT_ID / GOOGLE_CLIENT_EMAIL / GOOGLE_PRIVATE_KEY in environment', config },
			{ status: 400 }
		);
	}

	try {
		const token = await getAccessToken();
		return json({
			ok: true,
			stage: 'auth',
			message: 'Service account authenticated successfully',
			tokenLength: token.length,
			config
		});
	} catch (err: any) {
		return json({ ok: false, stage: 'auth', message: err?.message ?? String(err), config }, { status: 500 });
	}
};

export const POST: RequestHandler = async ({ request }) => {
	const projectId = env.GOOGLE_PROJECT_ID;
	const location = env.GOOGLE_LOCATION || 'europe-west4';

	let body: any = {};
	try {
		body = await request.json();
	} catch {
		body = {};
	}
	const prompt = (body?.prompt as string) || 'Reply with exactly: Aqura AI Marketing connection OK';
	const model = (body?.model as string) || 'gemini-2.5-flash';

	if (!projectId) {
		return json({ ok: false, message: 'Missing GOOGLE_PROJECT_ID' }, { status: 400 });
	}

	let accessToken: string;
	try {
		accessToken = await getAccessToken();
	} catch (err: any) {
		return json({ ok: false, stage: 'auth', message: err?.message ?? String(err) }, { status: 500 });
	}

	const url = `https://${location}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${location}/publishers/google/models/${model}:generateContent`;
	const started = Date.now();
	let geminiRes: Response;
	try {
		geminiRes = await fetch(url, {
			method: 'POST',
			headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
			body: JSON.stringify({
				contents: [{ role: 'user', parts: [{ text: prompt }] }],
				generationConfig: { maxOutputTokens: 100, temperature: 0.2 }
			})
		});
	} catch (err: any) {
		return json({ ok: false, stage: 'gemini', message: `Network error: ${err?.message ?? err}` }, { status: 502 });
	}

	const elapsedMs = Date.now() - started;
	let respBody: any;
	try {
		respBody = await geminiRes.json();
	} catch {
		return json({ ok: false, stage: 'gemini', message: `Non-JSON response (status ${geminiRes.status})`, elapsedMs }, { status: 502 });
	}

	if (!geminiRes.ok) {
		return json(
			{ ok: false, stage: 'gemini', message: respBody?.error?.message ?? `Gemini call failed (${geminiRes.status})`, raw: respBody, elapsedMs },
			{ status: geminiRes.status }
		);
	}

	const text =
		respBody?.candidates?.[0]?.content?.parts?.map((p: any) => p?.text ?? '').join('') || '';

	return json({
		ok: true,
		stage: 'gemini',
		model,
		location,
		elapsedMs,
		reply: text.trim(),
		usage: respBody?.usageMetadata ?? null
	});
};
