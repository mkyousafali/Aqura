import { describe, expect, it } from 'vitest';
import { absenceReminderBody, absenceReminderTemplate, reminderDate, validAbsenceDate } from './absenceReminder';

describe('absence leave request reminder', () => {
	it('uses the bilingual Meta template and day/month/year variable', () => {
		expect(absenceReminderTemplate).toBe('aqura_absence_leave_request');
		expect(reminderDate('2026-10-17')).toBe('17-10-2026');
	});

	it('rejects malformed and impossible dates', () => {
		for (const date of [null, '', '17/10/2026', '2026-02-30', '2026-13-01', '2026-10-17T00:00:00Z']) {
			expect(validAbsenceDate(date)).toBe(false);
		}
		expect(validAbsenceDate('2026-10-17')).toBe(true);
		expect(validAbsenceDate('2028-02-29')).toBe(true);
	});

	it('matches the approved-for-submission English wording without a link', () => {
		expect(absenceReminderBody('en', 'Sample Employee', '2026-10-17')).toBe(
			'Hello Sample Employee, Aqura attendance records show you as absent on 17-10-2026. Please submit a leave request through Aqura to avoid automatic salary deduction if you are eligible for paid leave.'
		);
	});

	it('matches the Arabic wording and agreed brand spelling without adding English', () => {
		expect(absenceReminderBody('ar', 'موظف تجريبي', '2026-10-17')).toBe(
			'مرحباً موظف تجريبي، تظهر سجلات الحضور في اكورا غيابك بتاريخ 17-10-2026. يرجى تقديم طلب إجازة عبر اكورا لتجنب الخصم التلقائي من الراتب إذا كنت مستحقاً لإجازة مدفوعة الأجر.'
		);
	});
});
