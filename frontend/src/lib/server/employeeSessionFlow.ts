import type { Cookies } from '@sveltejs/kit';
import { createSupabaseAuthSession, databaseClient, setBreakSession } from '$lib/server/breakRegisterAuth';
import { issueEmployeeLoginOtp, verifyEmployeeLoginOtp, type EmployeeInterface } from '$lib/server/employeeLoginOtp';

export type LoginFlowResult = {
	status: number;
	body: Record<string, unknown>;
};

function otpFailure(data: any): LoginFlowResult {
	const messages: Record<string, string> = {
		invalid_otp_format: 'Enter a valid 6-digit OTP.',
		invalid_otp: 'Incorrect OTP.',
		otp_expired: 'OTP expired. Request a new code.',
		otp_not_found: 'OTP request is no longer valid. Start again.',
		account_deactivated: 'Account deactivated after three incorrect OTP attempts. Contact an administrator.',
		resend_cooldown: 'Please wait before requesting another OTP.',
		delivery_limit: 'OTP request limit reached. Try again after 30 minutes.',
		delivery_failed: 'OTP delivery failed. Contact an administrator.'
	};
	const status = data?.error === 'account_deactivated' ? 403 : data?.error === 'delivery_limit' || data?.error === 'resend_cooldown' ? 429 : 400;
	return { status, body: { success: false, error: data?.error || 'otp_failed', message: messages[data?.error] || data?.message || 'OTP verification failed.', attemptsRemaining: data?.attempts_remaining, retryAfterSeconds: data?.retry_after_seconds } };
}

async function userFromAccessCode(code: string): Promise<{ id: string } | null> {
	if (!/^[0-9]{6}$/.test(code)) return null;
	const { data, error } = await databaseClient().rpc('verify_quick_access_code', { p_code: code });
	return !error && data?.success && data.user?.id ? { id: data.user.id } : null;
}

async function challengeUser(challengeId: string, interfaceType: EmployeeInterface): Promise<string | null> {
	const { data, error } = await databaseClient().from('employee_login_otp_requests').select('user_id')
		.eq('id', challengeId).eq('interface_type', interfaceType).maybeSingle();
	return error ? null : data?.user_id || null;
}

async function validateUser(userId: string, interfaceType: EmployeeInterface) {
	const db = databaseClient();
	const [{ data: details, error: detailsError }, { data: base, error: baseError }, { data: permission, error: permissionError }] = await Promise.all([
		db.from('user_management_view').select('id,username,is_master_admin,is_admin,employee_name,branch_name,employee_id,branch_id,default_language,status').eq('id', userId).single(),
		db.from('users').select('id,user_type,avatar,status').eq('id', userId).single(),
		db.from('interface_permissions').select('desktop_enabled,mobile_enabled,cashier_enabled').eq('user_id', userId).maybeSingle()
	]);
	if (detailsError || baseError) throw detailsError || baseError;
	if (!details || !base || details.status !== 'active' || base.status !== 'active') return { error: 'User account is inactive' };
	if (permissionError) throw permissionError;
	if (permission?.[`${interfaceType}_enabled`] === false) return { error: `${interfaceType.charAt(0).toUpperCase() + interfaceType.slice(1)} interface access is disabled` };
	return { details, base };
}

export async function runEmployeeSessionFlow(options: {
	interfaceType: 'desktop' | 'mobile';
	body: any;
	cookies: Cookies;
	secure: boolean;
}): Promise<LoginFlowResult> {
	const { interfaceType, body, cookies, secure } = options;
	let userId: string | null = null;
	let otpPassed = false;

	if (body.action === 'verifyOtp') {
		const result = await verifyEmployeeLoginOtp(String(body.challengeId || ''), String(body.otp || '').trim(), interfaceType);
		if (!result?.success) return otpFailure(result);
		userId = result.user_id;
		otpPassed = true;
	} else if (body.action === 'resendOtp') {
		userId = await challengeUser(String(body.challengeId || ''), interfaceType);
		if (!userId) return otpFailure({ error: 'otp_not_found' });
	} else {
		const verified = await userFromAccessCode(String(body.quickAccessCode || '').trim());
		if (!verified || (body.expectedUserId && String(body.expectedUserId) !== verified.id)) {
			return { status: 401, body: { success: false, error: 'Invalid access code' } };
		}
		userId = verified.id;
	}

	const checked = await validateUser(userId, interfaceType);
	if ('error' in checked) return { status: 403, body: { success: false, error: checked.error } };

	if (!otpPassed) {
		const issued = await issueEmployeeLoginOtp(userId, interfaceType);
		if (!issued?.success) return otpFailure(issued);
		if (issued.otp_required !== false) return { status: 200, body: issued };
	}

	const authSession = await createSupabaseAuthSession(userId);
	setBreakSession(cookies, userId, secure, interfaceType);
	return {
		status: 200,
		body: {
			success: true,
			user: {
				id: checked.details.id, username: checked.details.username,
				is_master_admin: checked.details.is_master_admin === true,
				is_admin: checked.details.is_admin === true, user_type: checked.base.user_type
			},
			userDetails: { ...checked.details, user_type: checked.base.user_type, avatar: checked.base.avatar },
			authSession
		}
	};
}
