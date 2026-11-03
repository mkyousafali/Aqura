import { error as httpError } from '@sveltejs/kit';
import type { Cookies } from '@sveltejs/kit';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

export async function requireDirectOrderAccess(cookies: Cookies, kind: 'desktop' | 'mobile' = 'desktop') {
	let actor;
	try { actor = await requireBreakUser(cookies, kind); }
	catch { httpError(401, 'An active signed-in session is required.'); }
	const db = databaseClient();
	const { data: allowed, error } = await db.rpc('direct_order_server_has_access', { p_actor_user_id: actor.id, p_interface: kind });
	if (error) httpError(500, 'Unable to verify Direct Order access.');
	if (allowed !== true) httpError(403, 'Direct Order access required.');
	return { actor, db };
}
