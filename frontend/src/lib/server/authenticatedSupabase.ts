import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';

export class AuthenticationRequiredError extends Error {}

export function createAuthenticatedSupabase(request: Request) {
	const authorization = request.headers.get('authorization');
	if (!authorization?.startsWith('Bearer ')) {
		throw new AuthenticationRequiredError('Authenticated session is required');
	}

	const url = env.VITE_SUPABASE_URL || '';
	const anonKey = env.VITE_SUPABASE_ANON_KEY || '';
	if (!url || !anonKey) throw new Error('Supabase configuration is unavailable');

	return createClient(url, anonKey, {
		auth: { persistSession: false, autoRefreshToken: false },
		global: { headers: { Authorization: authorization } }
	});
}
