import { describe, expect, it, vi } from 'vitest';
import {
	handleQuotedAttendanceReply, resolveQuotedAttendance, resolveAttendanceReplyDate
} from '../../../../database/edge-functions/whatsapp-webhook/attendanceReply';

function fixture() {
	const employee = { id: 'EMP46', name_en: 'Aslam', name_ar: 'أسلم' };
	const tables: Record<string, any[]> = {
		wa_messages: [{ conversation_id: 'my-chat', whatsapp_message_id: 'alert-id', direction: 'outbound', metadata: null }],
		attendance_no_show_deliveries: [{ provider_message_id: 'alert-id', channel: 'whatsapp',
			attendance_no_show_alerts: { employee_id: employee.id, shift_date: '2026-10-17' } }]
	};
	const calls: any[] = [];
	const supabase = { from: vi.fn((table: string) => {
		const filters: [string, unknown][] = [];
		const query = {
			select: vi.fn(() => query),
			eq: vi.fn((column: string, value: unknown) => { filters.push([column, value]); return query; }),
			maybeSingle: vi.fn(async () => {
				calls.push({ table, filters });
				return { data: tables[table]?.find(row => filters.every(([column, value]) => row[column] === value)) || null, error: null };
			})
		};
		return query;
	}) };
	const request = { conversationId: 'my-chat', quotedMessageId: 'alert-id', content: 'Is he came?',
		semanticIntent: { intent: 'employee_attendance', employee_name: '', requested_date: 'unspecified' } as any };
	const services = {
		getPermitted: vi.fn(async () => ({ employees: [employee] })),
		nameMatches: vi.fn((name: string, row: any) => name.toLowerCase().includes(row.name_en.toLowerCase())),
		resolveDate: (requested: string, content: string, original: string) =>
			resolveAttendanceReplyDate(requested, content, original, '2026-10-18'),
		clearState: vi.fn(async () => {}), report: vi.fn(async () => {}),
		denied: vi.fn(async () => {}), failed: vi.fn(async () => {})
	};
	return { supabase, tables, calls, employee, request, services };
}

describe('quoted attendance replies', () => {
	it('resolves already-sent alerts and reports the original employee/day directly', async () => {
		const f = fixture();
		expect(await handleQuotedAttendanceReply(f.supabase, f.request, f.services)).toBe(true);
		expect(f.services.report).toHaveBeenCalledWith(f.employee, '2026-10-17', 'attendance');
		expect(f.services.clearState).toHaveBeenCalledOnce();
		expect(f.calls[0].filters).toEqual([
			['conversation_id', 'my-chat'], ['whatsapp_message_id', 'alert-id'], ['direction', 'outbound']
		]);
		expect(f.calls[1].filters).toContainEqual(['channel', 'whatsapp']);
	});

	it('supports replies to the new attendance reports via saved metadata', async () => {
		const f = fixture();
		f.tables.wa_messages[0].metadata = { attendance_context: { employee_id: 'EMP46', shift_date: '2026-10-16' } };
		expect(await handleQuotedAttendanceReply(f.supabase, f.request, f.services)).toBe(true);
		expect(f.services.report).toHaveBeenCalledWith(f.employee, '2026-10-16', 'attendance');
		expect(f.calls).toHaveLength(1);
	});

	it.each(['other-chat', 'inbound', 'unrelated-id'])('ignores a reference outside this outbound conversation: %s', async value => {
		const f = fixture();
		if (value === 'other-chat') f.tables.wa_messages[0].conversation_id = value;
		if (value === 'inbound') f.tables.wa_messages[0].direction = value;
		if (value === 'unrelated-id') f.request.quotedMessageId = value;
		expect(await handleQuotedAttendanceReply(f.supabase, f.request, f.services)).toBe(false);
		expect(f.services.report).not.toHaveBeenCalled();
	});

	it('never guesses the employee from the alert text when no source mapping exists', async () => {
		const f = fixture();
		f.tables.attendance_no_show_deliveries = [];
		f.tables.wa_messages[0].content = 'Employee: Aslam\nDate: 17-10-2026';
		expect(await resolveQuotedAttendance(f.supabase, 'my-chat', 'alert-id')).toBeNull();
	});

	it.each([null, { employees: [] }])('rechecks revoked/branch permissions before reporting', async permission => {
		const f = fixture();
		f.services.getPermitted.mockResolvedValue(permission as any);
		expect(await handleQuotedAttendanceReply(f.supabase, f.request, f.services)).toBe(true);
		expect(f.services.denied).toHaveBeenCalledOnce();
		expect(f.services.report).not.toHaveBeenCalled();
	});

	it.each(['he', 'هو', ''])('uses the quoted employee for semantic pronoun %s', async employee_name => {
		const f = fixture();
		f.request.semanticIntent = { intent: 'employee_attendance', employee_name, requested_date: 'unspecified' };
		expect(await handleQuotedAttendanceReply(f.supabase, f.request, f.services)).toBe(true);
		expect(f.services.report).toHaveBeenCalledWith(f.employee, '2026-10-17', 'attendance');
	});

	it('does not override a different explicitly named employee', async () => {
		const f = fixture();
		f.request.semanticIntent = { intent: 'employee_attendance', employee_name: 'Amal', requested_date: 'today' };
		expect(await handleQuotedAttendanceReply(f.supabase, f.request, f.services)).toBe(false);
		expect(f.services.report).not.toHaveBeenCalled();
	});

	it('does not start any lookup when AI classification is unavailable', async () => {
		const f = fixture();
		f.request.semanticIntent = null;
		f.request.content = 'Has Amal arrived?';
		f.services.getPermitted.mockResolvedValue({ employees: [f.employee, { id: 'EMP89', name_en: 'Amal', name_ar: 'أمل' }] });
		expect(await handleQuotedAttendanceReply(f.supabase, f.request, f.services)).toBe(false);
		expect(f.services.report).not.toHaveBeenCalled();
	});

	it('rejects an invalid source alert date rather than reporting a different day', async () => {
		const f = fixture();
		f.tables.attendance_no_show_deliveries[0].attendance_no_show_alerts.shift_date = '2026-02-31';
		expect(await handleQuotedAttendanceReply(f.supabase, f.request, f.services)).toBe(false);
		expect(f.services.report).not.toHaveBeenCalled();
	});

	it('supports an explicit shift request and date override', async () => {
		const f = fixture();
		f.request.semanticIntent = { intent: 'employee_shift', employee_name: 'Aslam', requested_date: 'today' };
		expect(await handleQuotedAttendanceReply(f.supabase, f.request, f.services)).toBe(true);
		expect(f.services.report).toHaveBeenCalledWith(f.employee, '2026-10-18', 'shift');
	});

	it.each(['Thanks', 'شكراً'])('does not treat acknowledgement %s as a new attendance lookup', async content => {
		const f = fixture();
		f.request.content = content;
		f.request.semanticIntent = { intent: 'conversation', employee_name: '', requested_date: 'unspecified' };
		expect(await handleQuotedAttendanceReply(f.supabase, f.request, f.services)).toBe(false);
		expect(f.supabase.from).not.toHaveBeenCalled();
	});

	it('leaves non-attendance intents and unquoted messages on the normal path', async () => {
		const f = fixture();
		f.request.semanticIntent = { intent: 'sales_report', employee_name: '', requested_date: 'today' };
		expect(await handleQuotedAttendanceReply(f.supabase, f.request, f.services)).toBe(false);
		f.request.semanticIntent = null;
		f.request.quotedMessageId = '';
		expect(await handleQuotedAttendanceReply(f.supabase, f.request, f.services)).toBe(false);
		expect(f.supabase.from).not.toHaveBeenCalled();
	});

	it('handles an AI-selected Arabic follow-up with the quoted context', async () => {
		const f = fixture();
		f.request.content = 'هو وصل الحين؟';
		expect(await handleQuotedAttendanceReply(f.supabase, f.request, f.services)).toBe(true);
		expect(f.services.report).toHaveBeenCalledWith(f.employee, '2026-10-17', 'attendance');
	});

	it('returns a safe failure response instead of inventing attendance on database errors', async () => {
		const f = fixture();
		f.supabase.from.mockImplementation(() => { throw new Error('offline'); });
		expect(await handleQuotedAttendanceReply(f.supabase, f.request, f.services)).toBe(true);
		expect(f.services.failed).toHaveBeenCalledOnce();
		expect(f.services.report).not.toHaveBeenCalled();
	});
});

describe('quoted attendance date selection', () => {
	it.each([
		['unspecified', 'Is he came?', '2026-10-17'],
		['unspecified', 'Has he arrived today?', '2026-10-18'],
		['unspecified', 'وصل أمس؟', '2026-10-17'],
		['tomorrow', 'shift?', '2026-10-19'],
		['unspecified', 'arrived 16/10/2026?', '2026-10-16'],
		['unspecified', 'حضر ١٦-١٠-٢٠٢٦؟', '2026-10-16'],
		['2026-10-15', 'arrived?', '2026-10-15'],
		['31-02-2026', 'arrived?', null]
	])('resolves %s / %s correctly', (requested, content, expected) => {
		expect(resolveAttendanceReplyDate(requested, content, '2026-10-17', '2026-10-18')).toBe(expected);
	});
});
