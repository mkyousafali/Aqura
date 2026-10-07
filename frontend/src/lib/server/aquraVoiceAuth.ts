import { databaseClient } from '$lib/server/breakRegisterAuth';

export async function requireAquraVoiceUser(request: Request) {
	const token = request.headers.get('authorization')?.replace(/^Bearer\s+/i, '').trim();
	if (!token) throw new Error('AUTH_REQUIRED');
	const db = databaseClient();
	const { data, error } = await db.auth.getUser(token);
	if (error || !data.user) throw new Error('AUTH_REQUIRED');
	const userId = data.user.app_metadata?.aqura_user_id;
	if (!userId) throw new Error('AUTH_REQUIRED');
	const { data: user } = await db.from('users').select('id,username,is_master_admin,status').eq('id', userId).single();
	if (!user || user.status !== 'active') throw new Error('ACCOUNT_INACTIVE');
	const { data: access } = await db.from('aqura_voice_access').select('is_enabled,subscription_expiry,daily_limit').eq('user_id', userId).maybeSingle();
	if (!access?.is_enabled) throw new Error('PERMISSION_DENIED');
	const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Riyadh', year:'numeric', month:'2-digit', day:'2-digit' }).format(new Date());
	if (access.subscription_expiry && access.subscription_expiry < today) throw new Error('SUBSCRIPTION_EXPIRED');
	return { db, user };
}

export function aquraVoiceAuthError(error: unknown): Response | null {
	const code = error instanceof Error ? error.message : '';
	const messages: Record<string,string> = {
		AUTH_REQUIRED: 'Aqura login required', ACCOUNT_INACTIVE: 'User account is inactive',
		PERMISSION_DENIED: "You don't have permission to use Aqura Voice",
		SUBSCRIPTION_EXPIRED: 'Your Aqura Voice subscription has expired'
	};
	return messages[code] ? Response.json({ success:false, error:messages[code] }, { status: code === 'AUTH_REQUIRED' ? 401 : 403 }) : null;
}
