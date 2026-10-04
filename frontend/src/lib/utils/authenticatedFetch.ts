import { supabase } from '$lib/utils/supabase';

export async function authenticatedFetch(
	input: RequestInfo | URL,
	init: RequestInit = {}
): Promise<Response> {
	const { data: { session }, error } = await supabase.auth.getSession();
	if (error || !session?.access_token) {
		throw error || new Error('Authenticated session is required');
	}

	const headers = new Headers(init.headers);
	headers.set('Authorization', `Bearer ${session.access_token}`);
	return fetch(input, { ...init, headers });
}
