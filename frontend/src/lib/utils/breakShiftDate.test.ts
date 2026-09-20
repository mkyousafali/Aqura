import { describe, expect, it } from 'vitest';
import { breakShiftDate, shiftTimeLabel, type ShiftSchedules } from './breakShiftDate';

const regular = {
	employee_id: 'EMP1', version_id: 1, date_from: '2026-01-01', date_to: null,
	shift_start_time: '20:00:00', shift_end_time: '04:00:00',
	shift_end_buffer: 3, is_shift_overlapping_next_day: true
};

describe('break shift date', () => {
	it('assigns an after-midnight break to the overnight shift start date', () => {
		const schedules: ShiftSchedules = { regular: [regular], weekday: [], dateWise: [] };
		expect(breakShiftDate('EMP1', '2026-09-18T22:30:00Z', schedules)).toBe('2026-09-18');
		expect(breakShiftDate('EMP1', '2026-09-19T05:00:00Z', schedules)).toBe('2026-09-19');
	});

	it('uses the weekday special shift before a regular overnight shift', () => {
		const schedules: ShiftSchedules = {
			regular: [regular],
			weekday: [{ ...regular, version_id: 2, weekday: 5, shift_start_time: '13:00:00', shift_end_time: '20:00:00', is_shift_overlapping_next_day: false }],
			dateWise: []
		};
		expect(breakShiftDate('EMP1', '2026-09-18T22:30:00Z', schedules)).toBe('2026-09-19');
	});

	it('uses the date-specific overnight shift before the weekday shift', () => {
		const schedules: ShiftSchedules = {
			regular: [regular],
			weekday: [{ ...regular, version_id: 2, weekday: 5, shift_start_time: '13:00:00', shift_end_time: '20:00:00', is_shift_overlapping_next_day: false }],
			dateWise: [{ ...regular, version_id: 3, date_from: '2026-09-18', date_to: '2026-09-18' }]
		};
		expect(breakShiftDate('EMP1', '2026-09-18T22:30:00Z', schedules)).toBe('2026-09-18');
		expect(shiftTimeLabel('EMP1', '2026-09-18', schedules)).toBe('8:00 PM–4:00 AM (+1)');
	});

	it('shows the weekday shift time for its date', () => {
		const schedules: ShiftSchedules = {
			regular: [regular],
			weekday: [{ ...regular, version_id: 2, weekday: 5, shift_start_time: '13:00:00', shift_end_time: '20:00:00', is_shift_overlapping_next_day: false }],
			dateWise: []
		};
		expect(shiftTimeLabel('EMP1', '2026-09-18', schedules)).toBe('1:00 PM–8:00 PM');
	});

	it('uses only the latest effective weekday version while retaining its slots', () => {
		const old = { ...regular, version_id: 31, weekday: 5, date_from: '2026-07-24', date_to: '2026-09-24', shift_start_time: '13:00:00', shift_end_time: '20:00:00', is_shift_overlapping_next_day: false };
		const current = { ...regular, version_id: 86, weekday: 5, date_from: '2026-08-25', shift_start_time: '16:00:00', shift_end_time: '00:00:00' };
		const schedules: ShiftSchedules = { regular: [regular], weekday: [old, current], dateWise: [] };
		expect(shiftTimeLabel('EMP1', '2026-09-18', schedules)).toBe('4:00 PM–12:00 AM (+1)');
	});
});
