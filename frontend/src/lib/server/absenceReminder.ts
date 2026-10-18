export const absenceReminderTemplate = 'aqura_absence_leave_request';

export function validAbsenceDate(value: unknown): value is string {
	if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
	const date = new Date(`${value}T12:00:00Z`);
	return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

export function reminderDate(date: string): string {
	return date.split('-').reverse().join('-');
}

// Keep these bodies identical to the two Meta template language versions.
export function absenceReminderBody(language: 'en' | 'ar', name: string, date: string): string {
	const formattedDate = reminderDate(date);
	return language === 'ar'
		? `مرحباً ${name}، تظهر سجلات الحضور في اكورا غيابك بتاريخ ${formattedDate}. يرجى تقديم طلب إجازة عبر اكورا لتجنب الخصم التلقائي من الراتب إذا كنت مستحقاً لإجازة مدفوعة الأجر.`
		: `Hello ${name}, Aqura attendance records show you as absent on ${formattedDate}. Please submit a leave request through Aqura to avoid automatic salary deduction if you are eligible for paid leave.`;
}
