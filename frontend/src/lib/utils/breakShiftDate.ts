export type ShiftSlot = {
	employee_id: string;
	version_id: number;
	weekday?: number;
	date_from: string;
	date_to: string | null;
	shift_start_time: string;
	shift_end_time: string;
	shift_end_buffer?: number | null;
	is_shift_overlapping_next_day?: boolean | null;
};

export type ShiftSchedules = {
	regular: ShiftSlot[];
	weekday: ShiftSlot[];
	dateWise: ShiftSlot[];
};

export function addDays(date: string, days: number): string {
	const value = new Date(`${date}T12:00:00Z`);
	value.setUTCDate(value.getUTCDate() + days);
	return value.toISOString().slice(0, 10);
}

function minutes(time: string): number {
	const [hour, minute] = time.split(':').map(Number);
	return hour * 60 + minute;
}

function time12(time: string): string {
	const [hour, minute] = time.split(':').map(Number);
	const displayHour = hour % 12 || 12;
	return `${displayHour}:${String(minute).padStart(2, '0')} ${hour < 12 ? 'AM' : 'PM'}`;
}

function effective(slot: ShiftSlot, date: string): boolean {
	return slot.date_from <= date && (!slot.date_to || slot.date_to >= date);
}

function shiftSlotsForDate(employeeId: string, date: string, schedules: ShiftSchedules): ShiftSlot[] {
	const matching = (slot: ShiftSlot) => slot.employee_id === employeeId && effective(slot, date);
	const latestVersion = (slots: ShiftSlot[]): ShiftSlot[] => {
		if (!slots.length) return [];
		const latest = slots.reduce((current, slot) =>
			slot.date_from > current.date_from || (slot.date_from === current.date_from && slot.version_id > current.version_id)
				? slot : current
		);
		return slots.filter(slot => slot.version_id === latest.version_id);
	};
	const dateWise = latestVersion(schedules.dateWise.filter(matching));
	if (dateWise.length) return dateWise;
	const weekday = new Date(`${date}T12:00:00Z`).getUTCDay();
	const weekdaySlots = latestVersion(schedules.weekday.filter(slot => matching(slot) && slot.weekday === weekday));
	if (weekdaySlots.length) return weekdaySlots;
	return latestVersion(schedules.regular.filter(matching));
}

export function shiftTimeLabel(employeeId: string, date: string, schedules: ShiftSchedules): string {
	const slots = shiftSlotsForDate(employeeId, date, schedules);
	if (!slots.length) return '—';
	return slots.map(slot => {
		const start = time12(slot.shift_start_time);
		const end = time12(slot.shift_end_time);
		const overnight = slot.is_shift_overlapping_next_day || minutes(slot.shift_end_time) < minutes(slot.shift_start_time);
		return `${start}–${end}${overnight ? ' (+1)' : ''}`;
	}).join(' / ');
}

const riyadhFormatter = new Intl.DateTimeFormat('en-US', {
	timeZone: 'Asia/Riyadh', year: 'numeric', month: '2-digit', day: '2-digit',
	hour: '2-digit', minute: '2-digit', hourCycle: 'h23'
});

/** Assign a break to the date its scheduled shift began. */
export function breakShiftDate(employeeId: string, startTime: string, schedules: ShiftSchedules): string {
	const parts = Object.fromEntries(riyadhFormatter.formatToParts(new Date(startTime)).map(p => [p.type, p.value]));
	const localDate = `${parts.year}-${parts.month}-${parts.day}`;
	const localMinute = Number(parts.hour) * 60 + Number(parts.minute);
	const previousDate = addDays(localDate, -1);
	const previousSlots = shiftSlotsForDate(employeeId, previousDate, schedules);
	if (previousSlots.some(slot => {
		const overnight = slot.is_shift_overlapping_next_day || minutes(slot.shift_end_time) < minutes(slot.shift_start_time);
		return overnight && localMinute <= minutes(slot.shift_end_time) + (Number(slot.shift_end_buffer) || 0) * 60;
	})) return previousDate;
	return localDate;
}
