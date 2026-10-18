import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';
import { absenceReminderTemplate, absenceReminderBody, reminderDate, validAbsenceDate } from '$lib/server/absenceReminder';

const graphUrl = 'https://graph.facebook.com/v22.0';
const fail = (code: string, status = 400) => json({ success: false, code }, { status });

export const POST: RequestHandler = async ({ cookies, request, url }) => {
	// This is a cookie-authenticated, same-origin desktop action. Recipients,
	// language, template and message text are never supplied by the browser.
	if (request.headers.get('origin') !== url.origin) return fail('ACCESS_DENIED', 403);
	let actor;
	try {
		actor = await requireBreakUser(cookies, 'desktop');
	} catch {
		return fail('AUTH_REQUIRED', 401);
	}
	const db = databaseClient();
	let deliveryId: string | null = null;
	let providerAttempted = false;
	try {
		if (!actor.isMasterAdmin) {
			const permission = await db.from('button_permissions').select('is_enabled')
				.eq('user_id', actor.id).eq('button_code', 'FINGERPRINT_DASHBOARD').eq('is_enabled', true).maybeSingle();
			if (permission.error || !permission.data) return fail('ACCESS_DENIED', 403);
		}
		const body = await request.json().catch(() => ({}));
		const employeeId = typeof body.employeeId === 'string' ? body.employeeId.trim() : '';
		const date = body.date;
		if (!employeeId || employeeId.length > 100 || !validAbsenceDate(date)) return fail('INVALID_REQUEST');
		const today = new Intl.DateTimeFormat('en-CA', {
			timeZone: 'Asia/Riyadh', year: 'numeric', month: '2-digit', day: '2-digit'
		}).format(new Date());
		// Today's shift might still be in progress. Reminders are for past days.
		if (date >= today) return fail('PAST_DATES_ONLY');

		const employee = await db.from('hr_employee_master_with_status')
			.select('id,user_id,name_en,name_ar,whatsapp_number,employment_status').eq('id', employeeId).maybeSingle();
		if (employee.error) throw employee.error;
		if (!employee.data?.user_id) return fail('EMPLOYEE_UNAVAILABLE');
		const contact = employee.data;
		const [attendance, leave, history, user] = await Promise.all([
			db.from('hr_analysed_attendance_data').select('status,worked_minutes,check_in_time,check_out_time')
				.eq('employee_id', employeeId).eq('shift_date', date),
			db.from('day_off').select('id').eq('employee_id', employeeId).eq('day_off_date', date).limit(1),
			db.from('hr_employee_status_history').select('status,effective_from,effective_to')
				.eq('employee_id', employeeId).order('effective_from', { ascending: false }),
			db.from('users').select('default_language,status,locked_at').eq('id', contact.user_id).maybeSingle()
		]);
		for (const result of [attendance, leave, history, user]) if (result.error) throw result.error;
		const historicalStatus = history.data?.find((row) =>
			(!row.effective_from || row.effective_from <= date) && (!row.effective_to || row.effective_to >= date));
		if ((historicalStatus?.status || contact.employment_status) !== 'Job (With Finger)' || leave.data?.length ||
			attendance.data?.some((row) => row.status !== 'Absent' || Number(row.worked_minutes) > 0 || row.check_in_time || row.check_out_time)) {
			return fail('NOT_ABSENT', 409);
		}
		if (!user.data || user.data.status !== 'active' || user.data.locked_at) return fail('EMPLOYEE_UNAVAILABLE');
		const language = user.data.default_language;
		if (language !== 'en' && language !== 'ar') return fail('LANGUAGE_NOT_SET');
		let phone = String(contact.whatsapp_number || '').replace(/\D/g, '');
		if (phone.startsWith('00')) phone = phone.slice(2);
		if (/^05\d{8}$/.test(phone)) phone = `966${phone.slice(1)}`;
		else if (/^5\d{8}$/.test(phone)) phone = `966${phone}`;
		if (!/^[1-9]\d{7,14}$/.test(phone)) return fail('WHATSAPP_NUMBER_MISSING');
		const authorized = await db.rpc('is_internal_whatsapp_authorized_phone', { p_phone: phone });
		if (authorized.error) throw authorized.error;
		if (!authorized.data) return fail('EMPLOYEE_UNAVAILABLE');
		const accountResult = await db.rpc('get_internal_whatsapp_account');
		if (accountResult.error) throw accountResult.error;
		const account = Array.isArray(accountResult.data) ? accountResult.data[0] : accountResult.data;
		if (!account?.is_active || !account.access_token || !account.phone_number_id || !account.waba_id) return fail('WHATSAPP_NOT_CONFIGURED', 503);

		// Query Meta live so review/pause/rejection never falls back to another
		// language or to free text. A pending template creates no delivery claim.
		const templatesUrl = new URL(`${graphUrl}/${encodeURIComponent(account.waba_id)}/message_templates`);
		templatesUrl.search = new URLSearchParams({ name: absenceReminderTemplate, fields: 'name,language,status', limit: '100' }).toString();
		const templateResponse = await fetch(templatesUrl, {
			headers: { Authorization: `Bearer ${account.access_token}` }, signal: AbortSignal.timeout(15_000)
		});
		if (!templateResponse.ok) return fail('TEMPLATE_STATUS_UNAVAILABLE', 502);
		const templates = await templateResponse.json();
		if (!templates.data?.some((template: any) => template.name === absenceReminderTemplate && template.language === language && template.status === 'APPROVED')) {
			return fail('TEMPLATE_NOT_APPROVED', 409);
		}

		const claim = await db.from('attendance_absence_reminders').insert({
			employee_id: employeeId, absence_date: date, requested_by: actor.id, template_language: language
		}).select('id').single();
		if (claim.error?.code === '23505') {
			const previous = await db.from('attendance_absence_reminders').select('id,status')
				.eq('employee_id', employeeId).eq('absence_date', date).single();
			if (previous.error) throw previous.error;
			if (previous.data.status === 'sent') return json({ success: true, alreadySent: true });
			if (previous.data.status !== 'failed') return fail('DELIVERY_IN_PROGRESS', 409);
			// Only an explicit provider rejection is safe to retry. Timeouts stay
			// unknown, since WhatsApp could have accepted the original request.
			const retry = await db.from('attendance_absence_reminders').update({ status: 'sending', requested_by: actor.id, template_language: language })
				.eq('id', previous.data.id).eq('status', 'failed').select('id').maybeSingle();
			if (retry.error) throw retry.error;
			if (!retry.data) return fail('DELIVERY_IN_PROGRESS', 409);
			deliveryId = retry.data.id;
		} else {
			if (claim.error) throw claim.error;
			deliveryId = claim.data.id;
		}

		const name = (language === 'ar' ? contact.name_ar || contact.name_en : contact.name_en || contact.name_ar) || employeeId;
		const content = absenceReminderBody(language, name, date);
		providerAttempted = true;
		const response = await fetch(`${graphUrl}/${encodeURIComponent(account.phone_number_id)}/messages`, {
			method: 'POST', headers: { Authorization: `Bearer ${account.access_token}`, 'Content-Type': 'application/json' },
			signal: AbortSignal.timeout(20_000),
			body: JSON.stringify({
				messaging_product: 'whatsapp', to: phone, type: 'template',
				template: { name: absenceReminderTemplate, language: { code: language }, components: [{ type: 'body', parameters: [
					{ type: 'text', text: name }, { type: 'text', text: reminderDate(date) }
				] }] }
			})
		});
		if (!response.ok) {
			await db.from('attendance_absence_reminders').update({ status: 'failed' }).eq('id', deliveryId);
			return fail('WHATSAPP_SEND_FAILED', 502);
		}
		const result = await response.json();
		const messageId = result.messages?.[0]?.id;
		if (!messageId) throw new Error('WhatsApp response missing message ID');
		const now = new Date().toISOString();
		const saved = await db.from('attendance_absence_reminders').update({ status: 'sent', whatsapp_message_id: messageId, sent_at: now }).eq('id', deliveryId);
		if (saved.error) throw saved.error;

		// Preserve the outbound message in the internal live chat as well.
		try {
			let conversation = await db.from('wa_conversations').select('id').eq('wa_account_id', account.id)
				.eq('customer_phone', `+${phone}`).order('created_at', { ascending: false }).limit(1).maybeSingle();
			if (conversation.error) throw conversation.error;
			if (!conversation.data) {
				conversation = await db.from('wa_conversations').insert({
					wa_account_id: account.id, customer_phone: `+${phone}`, customer_name: name,
					status: 'active', handled_by: 'bot', is_bot_handling: true, bot_type: 'ai',
					last_message_at: now, last_message_preview: content.slice(0, 100), unread_count: 0
				}).select('id').single();
				if (conversation.error) throw conversation.error;
			}
			if (!conversation.data) throw new Error('Missing conversation');
			const chat = await db.from('wa_messages').upsert({
				conversation_id: conversation.data.id, wa_account_id: account.id, direction: 'outbound', message_type: 'template',
				content, template_name: absenceReminderTemplate, template_language: language, whatsapp_message_id: messageId,
				status: 'sent', sent_by: 'system', created_at: now,
				metadata: { source: 'attendance_absence_reminder', reminder_id: deliveryId, requested_by: actor.id, employee_id: employeeId, absence_date: date }
			}, { onConflict: 'whatsapp_message_id', ignoreDuplicates: true });
			if (chat.error) throw chat.error;
			const updated = await db.from('wa_conversations').update({ last_message_at: now, last_message_preview: content.slice(0, 100) }).eq('id', conversation.data.id);
			if (updated.error) throw updated.error;
			const log = await db.from('whatsapp_message_log').insert({
				phone_number: `+${phone}`, message_type: 'attendance_absence_reminder', template_name: absenceReminderTemplate,
				template_language: language, whatsapp_message_id: messageId, status: 'sent', customer_name: name
			});
			if (log.error) throw log.error;
		} catch {
			// Never ask the user to resend a message already accepted by Meta.
			console.error('[absence-reminder] Sent; live chat logging failed', deliveryId);
			return json({ success: true, loggingWarning: true });
		}
		return json({ success: true });
	} catch {
		if (deliveryId) {
			await db.from('attendance_absence_reminders').update({ status: providerAttempted ? 'unknown' : 'failed' }).eq('id', deliveryId);
		}
		console.error('[absence-reminder] Request failed', deliveryId || 'before delivery');
		return fail(providerAttempted ? 'DELIVERY_STATUS_UNKNOWN' : 'REQUEST_FAILED', 502);
	}
};
