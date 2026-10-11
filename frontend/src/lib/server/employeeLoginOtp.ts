import { databaseClient } from '$lib/server/breakRegisterAuth';

export type EmployeeInterface = 'cashier' | 'mobile' | 'desktop';

type DeliveryResult = {
	delivered: boolean;
	attempted: boolean;
	error?: string;
};

function maskEmail(value: string): string {
	const [name, domain] = value.split('@');
	if (!name || !domain) return '***';
	return `${name.slice(0, 1)}***@${domain}`;
}

function maskPhone(value: string): string {
	const digits = value.replace(/\D/g, '');
	return digits.length >= 4 ? `***${digits.slice(-4)}` : '***';
}

async function queueOtpEmail(recipient: string, otp: string, interfaceType: EmployeeInterface): Promise<void> {
	const db = databaseClient();
	let accountQuery = await db.from('email_accounts').select('id,email_address,from_name')
		.eq('is_active', true).eq('send_enabled', true).eq('default_for_otp', true).limit(1).maybeSingle();
	if (!accountQuery.data) {
		accountQuery = await db.from('email_accounts').select('id,email_address,from_name')
			.eq('is_active', true).eq('send_enabled', true).limit(1).maybeSingle();
	}
	if (accountQuery.error) throw accountQuery.error;
	if (!accountQuery.data) throw new Error('No OTP email account is configured');
	const account = accountQuery.data;
	const label = interfaceType.charAt(0).toUpperCase() + interfaceType.slice(1);
	const message = await db.from('email_messages').insert({
		email_account_id: account.id,
		direction: 'outgoing',
		status: 'queued',
		subject: `Aqura ${label} Login Verification Code`,
		text_body: `Your Aqura ${label} login verification code is ${otp}. It expires in 2 minutes. Do not share this code.`,
		html_body: `<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:30px;color:#0f172a"><h2>Aqura ${label} Login</h2><p>Your verification code is:</p><div style="font-size:36px;font-weight:700;letter-spacing:8px;color:#2563eb;margin:18px 0">${otp}</div><p>This code expires in 2 minutes. Do not share it.</p><hr style="border:0;border-top:1px solid #e2e8f0;margin:24px 0"><div dir="rtl" style="text-align:right"><h2>تسجيل الدخول إلى أكورا</h2><p>رمز التحقق الخاص بك:</p><div dir="ltr" style="font-size:36px;font-weight:700;letter-spacing:8px;color:#2563eb;margin:18px 0">${otp}</div><p>تنتهي صلاحية الرمز خلال دقيقتين. لا تشارك هذا الرمز.</p></div></div>`,
		priority: 'critical',
		from_address: account.email_address,
		from_name: account.from_name || 'Aqura',
		source_type: 'otp'
	}).select('id').single();
	if (message.error) throw message.error;
	const recipientInsert = await db.from('email_message_recipients').insert({
		email_message_id: message.data.id,
		recipient_type: 'to',
		email_address: recipient
	});
	if (recipientInsert.error) throw recipientInsert.error;
	const queued = await db.from('email_queue').insert({
		queue_type: 'normal', priority: 1, email_account_id: account.id,
		email_message_id: message.data.id, status: 'pending', available_at: new Date().toISOString(), maximum_attempts: 3
	}).select('id').single();
	if (queued.error) throw queued.error;
	const delivery = await db.functions.invoke('email-send', { body: { queue_id: queued.data.id } });
	if (delivery.error || delivery.data?.success === false) {
		throw new Error(delivery.error?.message || delivery.data?.error || 'Email OTP delivery failed');
	}
	await db.from('email_messages').update({
		text_body: '[redacted after delivery]', html_body: '<p>[redacted after delivery]</p>', body_preview: '[redacted after delivery]'
	}).eq('id', message.data.id);
}

async function deliverEmail(email: string | null, otp: string, interfaceType: EmployeeInterface): Promise<DeliveryResult> {
	if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return { attempted: false, delivered: false, error: 'missing_email' };
	try {
		await queueOtpEmail(email, otp, interfaceType);
		return { attempted: true, delivered: true };
	} catch (error) {
		return { attempted: true, delivered: false, error: error instanceof Error ? error.message : 'email_failed' };
	}
}

async function deliverWhatsapp(phone: string | null, otp: string): Promise<DeliveryResult> {
	const digits = String(phone || '').replace(/\D/g, '');
	if (!/^9665\d{8}$/.test(digits)) return { attempted: false, delivered: false, error: 'missing_whatsapp' };
	try {
		const db = databaseClient();
		const result = await db.functions.invoke('send-whatsapp', { body: {
			action: 'send_employee_login_otp', phone_number: `+${digits}`, access_code: otp, language: 'en'
		} });
		if (result.error || result.data?.success === false) throw new Error(result.error?.message || result.data?.error || 'WhatsApp OTP delivery failed');
		return { attempted: true, delivered: true };
	} catch (error) {
		return { attempted: true, delivered: false, error: error instanceof Error ? error.message : 'whatsapp_failed' };
	}
}

export async function issueEmployeeLoginOtp(userId: string, interfaceType: EmployeeInterface) {
	const db = databaseClient();
	const { data, error } = await db.rpc('prepare_employee_login_otp', {
		p_user_id: userId, p_interface_type: interfaceType
	});
	if (error) throw error;
	if (!data?.success || data.otp_required === false) return data;

	const useEmail = data.delivery_mode === 'email' || data.delivery_mode === 'both';
	const useWhatsapp = data.delivery_mode === 'whatsapp' || data.delivery_mode === 'both';
	const [email, whatsapp] = await Promise.all([
		useEmail ? deliverEmail(data.email, data.otp, interfaceType) : Promise.resolve({ attempted: false, delivered: false }),
		useWhatsapp ? deliverWhatsapp(data.whatsapp_number, data.otp) : Promise.resolve({ attempted: false, delivered: false })
	]);
	const completion = await db.rpc('complete_employee_login_otp_delivery', {
		p_request_id: data.request_id,
		p_email_attempted: email.attempted,
		p_email_delivered: email.delivered,
		p_whatsapp_attempted: whatsapp.attempted,
		p_whatsapp_delivered: whatsapp.delivered
	});
	if (completion.error) throw completion.error;
	if (!completion.data?.success) {
		return { success: false, error: 'delivery_failed', message: 'OTP delivery failed. Contact an administrator.' };
	}
	const destinations: string[] = [];
	if (email.delivered) destinations.push(maskEmail(data.email));
	if (whatsapp.delivered) destinations.push(maskPhone(data.whatsapp_number));
	return {
		success: true,
		otpRequired: true,
		challengeId: data.request_id,
		expiresInSeconds: 120,
		resendAfterSeconds: 30,
		deliveriesRemaining: data.deliveries_remaining,
		destinations
	};
}

export async function verifyEmployeeLoginOtp(challengeId: string, otp: string, interfaceType: EmployeeInterface) {
	if (!/^[0-9]{6}$/.test(otp)) return { success: false, error: 'invalid_otp_format' };
	const db = databaseClient();
	const { data, error } = await db.rpc('verify_employee_login_otp', {
		p_request_id: challengeId, p_interface_type: interfaceType, p_otp: otp
	});
	if (error) throw error;
	return data;
}
