import { createHmac, timingSafeEqual } from 'node:crypto';
import { env } from '$env/dynamic/private';
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

const tokenLifetimeMs = 10 * 365 * 24 * 60 * 60 * 1000;

function signingSecret() {
	if (!env.JWT_SECRET) throw new Error('Kiosk device signing is not configured');
	return env.JWT_SECRET;
}

function signDevice(deviceId: string) {
	const payload = Buffer.from(JSON.stringify({ deviceId, expires: Date.now() + tokenLifetimeMs })).toString('base64url');
	const signature = createHmac('sha256', signingSecret()).update(`kiosk:${payload}`).digest('base64url');
	return `${payload}.${signature}`;
}

function verifyDevice(deviceId: string, token: string) {
	const [payload, signature] = token.split('.');
	if (!payload || !signature) return false;
	const expected = createHmac('sha256', signingSecret()).update(`kiosk:${payload}`).digest();
	const actual = Buffer.from(signature, 'base64url');
	if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) return false;
	try {
		const decoded = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
		return decoded.deviceId === deviceId && Number.isFinite(decoded.expires) && decoded.expires > Date.now();
	} catch {
		return false;
	}
}

export const POST: RequestHandler = async ({ request, cookies }) => {
	try {
		const user = await requireBreakUser(cookies, 'desktop');
		if (!user.isAdmin && !user.isMasterAdmin) throw new Error('Administrator access required');
		const body = await request.json().catch(() => ({}));
		const deviceId = String(body.deviceId || '').trim();
		if (!/^[a-zA-Z0-9_-]{12,100}$/.test(deviceId)) throw new Error('Invalid kiosk device ID');
		return json({ success: true, deviceToken: signDevice(deviceId) });
	} catch (error) {
		return json({ success: false, error: error instanceof Error ? error.message : 'Kiosk setup failed' }, { status: 403 });
	}
};

export const GET: RequestHandler = async ({ request }) => {
	try {
		const deviceId = request.headers.get('x-aqura-device-id') || '';
		const token = request.headers.get('x-aqura-device-token') || '';
		if (!verifyDevice(deviceId, token)) throw new Error('Kiosk device authorization failed');
		const result = await databaseClient().rpc('get_break_security_code');
		if (result.error) throw result.error;
		if (!result.data?.code) throw new Error('Security code unavailable');
		return json({ success: true, code: result.data.code, ttl: result.data.ttl || 10 });
	} catch (error) {
		return json({ success: false, error: error instanceof Error ? error.message : 'Kiosk request failed' }, { status: 403 });
	}
};
