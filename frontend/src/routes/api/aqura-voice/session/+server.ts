import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { aquraVoiceAuthError, requireAquraVoiceUser } from '$lib/server/aquraVoiceAuth';

export const GET: RequestHandler = async ({ request }) => {
	try {
		const { db, user } = await requireAquraVoiceUser(request);
		if (user.is_master_admin) return json({ success:true, user, unlimited:true });
		const today = new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Riyadh',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
		const [{ data: access }, { data: usage }] = await Promise.all([
			db.from('aqura_voice_access').select('daily_limit,subscription_expiry').eq('user_id',user.id).single(),
			db.from('aqura_voice_daily_usage').select('usage_count').eq('user_id',user.id).eq('usage_date',today).maybeSingle()
		]);
		return json({ success:true, user, unlimited:false, dailyLimit:access?.daily_limit, usedToday:usage?.usage_count||0, subscriptionExpiry:access?.subscription_expiry });
	} catch (error) { return aquraVoiceAuthError(error) || json({success:false,error:'Session check failed'},{status:500}); }
};
