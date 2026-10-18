import { afterEach, beforeEach, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
	user: vi.fn(), from: vi.fn(), rpc: vi.fn(), fetch: vi.fn(),
	rows: {} as Record<string, any>, writes: [] as Array<{ table: string; operation: string; value: any }>,
	duplicate: false
}));
vi.mock('$lib/server/breakRegisterAuth', () => ({
	requireBreakUser: mocks.user,
	databaseClient: () => ({ from: mocks.from, rpc: mocks.rpc })
}));
import { POST } from './+server';

const call = (body: any = {}, origin = 'https://aqura.test') => POST({
	cookies: {}, url: new URL('https://aqura.test/api/attendance-absence-reminder'),
	request: new Request('https://aqura.test/api/attendance-absence-reminder', {
		method: 'POST', headers: { Origin: origin, 'Content-Type': 'application/json' },
		body: JSON.stringify({ employeeId: 'EMP_TEST', date: '2020-10-17', ...body })
	})
} as any);

beforeEach(() => {
	vi.clearAllMocks();
	mocks.duplicate = false;
	mocks.writes = [];
	mocks.rows = {
		button_permissions: { is_enabled: true },
		hr_employee_master_with_status: { id: 'EMP_TEST', user_id: 'user-test', name_en: 'Sample Employee', name_ar: 'موظف تجريبي', whatsapp_number: '0500000000', employment_status: 'Job (With Finger)' },
		hr_analysed_attendance_data: [{ status: 'Absent', worked_minutes: 0 }],
		day_off: [], hr_employee_status_history: [],
		users: { status: 'active', locked_at: null, default_language: 'en' },
		attendance_absence_reminders: { id: 'reminder-test', status: 'sent' },
		wa_conversations: { id: 'conversation-test' }
	};
	mocks.user.mockResolvedValue({ id: 'manager-test', isMasterAdmin: false });
	mocks.rpc.mockImplementation(async (name: string) => ({ data: name === 'get_internal_whatsapp_account'
		? [{ id: 'internal-account', is_active: true, phone_number_id: 'internal-phone', waba_id: 'test-waba', access_token: 'test-token' }]
		: true, error: null }));
	mocks.from.mockImplementation((table: string) => {
		let operation = 'select';
		const result = () => table === 'attendance_absence_reminders' && operation === 'insert' && mocks.duplicate
			? { data: null, error: { code: '23505' } }
			: { data: Object.hasOwn(mocks.rows, table) ? mocks.rows[table] : { id: 'test-id' }, error: null };
		const chain: any = {};
		for (const method of ['select', 'eq', 'order', 'limit']) chain[method] = () => chain;
		for (const method of ['insert', 'update', 'upsert']) chain[method] = (value: any) => {
			operation = method;
			mocks.writes.push({ table, operation, value });
			return chain;
		};
		chain.maybeSingle = chain.single = async () => result();
		chain.then = (resolve: any, reject: any) => Promise.resolve(result()).then(resolve, reject);
		return chain;
	});
	mocks.fetch.mockImplementation(async (_url: any, options: any) => new Response(JSON.stringify(options?.method === 'POST'
		? { messages: [{ id: 'wamid.test' }] }
		: { data: ['en', 'ar'].map(language => ({ name: 'aqura_absence_leave_request', language, status: 'APPROVED' })) }
	), { status: 200 }));
	vi.stubGlobal('fetch', mocks.fetch);
});
afterEach(() => vi.unstubAllGlobals());

it('rejects cross-origin and unauthenticated requests without sending', async () => {
	expect((await call({}, 'https://other.test')).status).toBe(403);
	mocks.user.mockRejectedValueOnce(new Error('No session'));
	expect((await call()).status).toBe(401);
	expect(mocks.fetch).not.toHaveBeenCalled();
});

it('requires the dashboard permission even for an ordinary admin', async () => {
	mocks.user.mockResolvedValue({ id: 'manager-test', isMasterAdmin: false, isAdmin: true });
	mocks.rows.button_permissions = null;
	const result = await call();
	expect(result.status).toBe(403);
	expect(mocks.fetch).not.toHaveBeenCalled();
});

it.each(['Worked', 'Not Scheduled', 'Official Holiday', 'Pending Approval'])('does not send for %s', async status => {
	mocks.rows.hr_analysed_attendance_data = [{ status }];
	expect((await (await call()).json()).code).toBe('NOT_ABSENT');
	expect(mocks.fetch).not.toHaveBeenCalled();
});

it('respects historical remote days and existing leave applications', async () => {
	mocks.rows.hr_employee_status_history = [{ status: 'Remote Job', effective_from: null, effective_to: null }];
	expect((await (await call()).json()).code).toBe('NOT_ABSENT');
	mocks.rows.hr_employee_status_history = [];
	mocks.rows.day_off = [{ id: 'leave-test' }];
	expect((await (await call()).json()).code).toBe('NOT_ABSENT');
	expect(mocks.fetch).not.toHaveBeenCalled();
});

it('never sends while the matching language template is in review', async () => {
	mocks.fetch.mockResolvedValueOnce(new Response(JSON.stringify({ data: [
		{ name: 'aqura_absence_leave_request', language: 'en', status: 'PENDING' },
		{ name: 'aqura_absence_leave_request', language: 'ar', status: 'APPROVED' }
	] })));
	expect((await (await call()).json()).code).toBe('TEMPLATE_NOT_APPROVED');
	expect(mocks.fetch).toHaveBeenCalledTimes(1);
	expect(mocks.writes).toEqual([]);
});

it.each(['en', 'ar'])('sends only stored %s through internal WhatsApp, ignoring browser-supplied recipients', async language => {
	mocks.rows.users.default_language = language;
	expect((await (await call({ phone_number: '+15555555555', language: 'other' })).json()).success).toBe(true);
	const send = mocks.fetch.mock.calls.find(([, options]) => options.method === 'POST');
	expect(send?.[0]).toContain('/internal-phone/messages');
	const payload = JSON.parse(send?.[1].body);
	expect(payload.to).toBe('966500000000');
	expect(payload.template.language.code).toBe(language);
	expect(payload.template.components[0].parameters[0].text).toBe(language === 'ar' ? 'موظف تجريبي' : 'Sample Employee');
	expect(mocks.writes.some(write => write.table === 'wa_messages' && write.value.wa_account_id === 'internal-account')).toBe(true);
});

it('does not guess the notification language', async () => {
	mocks.rows.users.default_language = null;
	expect((await (await call()).json()).code).toBe('LANGUAGE_NOT_SET');
	expect(mocks.fetch).not.toHaveBeenCalled();
});

it('treats missing analysis as absent, consistent with the dashboard', async () => {
	mocks.rows.hr_analysed_attendance_data = [];
	expect((await (await call()).json()).success).toBe(true);
});

it('does not resend an already-sent reminder', async () => {
	mocks.duplicate = true;
	expect((await (await call()).json()).alreadySent).toBe(true);
	expect(mocks.fetch.mock.calls.filter(([, options]) => options.method === 'POST')).toHaveLength(0);
});

it('holds ambiguous deliveries rather than making them automatically retryable', async () => {
	mocks.fetch.mockImplementationOnce(async () => new Response(JSON.stringify({ data: [
		{ name: 'aqura_absence_leave_request', language: 'en', status: 'APPROVED' }
	] }))).mockRejectedValueOnce(new Error('Timeout'));
	expect((await (await call()).json()).code).toBe('DELIVERY_STATUS_UNKNOWN');
	expect(mocks.writes).toContainEqual({ table: 'attendance_absence_reminders', operation: 'update', value: { status: 'unknown' } });
});
