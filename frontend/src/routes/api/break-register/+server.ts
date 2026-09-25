import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

const datePattern = /^\d{4}-\d{2}-\d{2}$/;

export const GET: RequestHandler = async ({ cookies, url, request }) => {
	try {
		const user = await requireBreakUser(cookies, request.headers.get('x-aqura-interface') === 'mobile' ? 'mobile' : 'desktop');
		const db = databaseClient();
		const { data: permission, error: permissionError } = await db.from('break_register_permissions')
			.select('can_see_branch_breaks,can_see_all_breaks').eq('user_id', user.id).maybeSingle();
		if (permissionError) throw permissionError;
		const scope = user.isMasterAdmin || permission?.can_see_all_breaks ? 'all' : permission?.can_see_branch_breaks ? 'branch' : 'own';
		const { data: employee, error: employeeError } = await db.from('hr_employee_master')
			.select('id,current_branch_id').eq('user_id', user.id).maybeSingle();
		if (employeeError) throw employeeError;
		if (scope === 'branch' && !employee?.current_branch_id) return json({ error: 'No assigned branch' }, { status: 403 });
		const view = url.searchParams.get('view') || 'logs';
		if (view === 'dashboard') {
			const { data, error } = await db.rpc('get_mobile_dashboard_data', { p_user_id: user.id });
			if (error) throw error;
			return json(data);
		}
		const from = url.searchParams.get('from');
		const to = url.searchParams.get('to');
		const branchText = url.searchParams.get('branch');
		const branch = branchText ? Number(branchText) : null;
		const status = url.searchParams.get('status');
		if ((from && !datePattern.test(from)) || (to && !datePattern.test(to)) || (branchText && (!Number.isSafeInteger(branch) || branch! <= 0)) || (status && !['open', 'closed'].includes(status))) {
			return json({ error: 'Invalid filter' }, { status: 400 });
		}
		if (scope === 'branch' && branch !== null && branch !== employee.current_branch_id) return json({ error: 'Branch is outside your scope' }, { status: 403 });
		const scopedBranch = scope === 'branch' ? employee.current_branch_id : scope === 'all' ? branch : null;

		if (view === 'logs') {
			const records: any[] = [];
			for (let offset = 0; ; offset += 1000) {
				let query = db.from('hr_analysed_break_data').select('break_id,user_id,employee_id,employee_name_en,employee_name_ar,branch_id,reason_id,reason_note,start_time,end_time,duration_seconds,status,shift_date,shift_source,shift_start_time,shift_end_time,is_overnight,is_scheduled,schedule_exception')
					.order('start_time', { ascending: false }).range(offset, from && to ? offset + 999 : offset + 499);
				if (scope === 'own') query = query.eq('user_id', user.id);
				if (scopedBranch !== null) query = query.eq('branch_id', scopedBranch);
				if (from) query = query.gte('shift_date', from);
				if (to) query = query.lte('shift_date', to);
				if (status) query = query.eq('status', status);
				const { data: page, error } = await query;
				if (error) throw error;
				records.push(...(page || []).map(row => ({ ...row, id: row.break_id })));
				if (!from || !to || !page || page.length < 1000) break;
			}
			const [reasonsResult, branchesResult] = await Promise.all([
				db.from('break_reasons').select('id,name_en,name_ar'),
				db.from('branches').select('id,name_en,name_ar,location_en,location_ar')
			]);
			if (reasonsResult.error) throw reasonsResult.error;
			if (branchesResult.error) throw branchesResult.error;
			const reasons = new Map((reasonsResult.data || []).map(r => [r.id, r]));
			const branches = new Map((branchesResult.data || []).map(b => [b.id, b]));
			const breaks = (records || []).map(b => {
				const reason = reasons.get(b.reason_id);
				const branchRecord = branches.get(b.branch_id);
				return { ...b, reason_en: reason?.name_en, reason_ar: reason?.name_ar,
					branch_name_en: branchRecord?.name_en, branch_name_ar: branchRecord?.name_ar };
			});
			return json({ breaks, branches: scope === 'all' ? branchesResult.data : scope === 'branch' ? branchesResult.data?.filter(b => b.id === scopedBranch) : [], scope });
		}

		if (view === 'summary' || view === 'schedule') {
			if (!from || !to) return json({ error: 'Date range required' }, { status: 400 });
			if (view === 'summary') {
				const [{ data: scheduleData, error: scheduleError }, analyzedRecords, { data: summaryReasons, error: summaryReasonsError }, attendanceRecords, { data: employeeStatuses, error: employeeStatusesError }, { data: statusHistory, error: statusHistoryError }] = await Promise.all([
					db.rpc('get_break_schedule_status', { p_date_from: from, p_date_to: to, p_branch_id: scopedBranch }),
					(async () => {
						const records: any[] = [];
						for (let offset = 0; ; offset += 1000) {
							let query = db.from('hr_analysed_break_data')
								.select('break_id,user_id,employee_id,employee_name_en,employee_name_ar,branch_id,reason_id,reason_note,shift_date,start_time,end_time,duration_seconds,status,is_scheduled,schedule_exception')
								.eq('status', 'closed').gte('shift_date', from).lte('shift_date', to)
								.order('shift_date').range(offset, offset + 999);
							if (scope === 'own') query = query.eq('user_id', user.id);
							if (scopedBranch !== null) query = query.eq('branch_id', scopedBranch);
							const { data: page, error } = await query;
							if (error) throw error;
							records.push(...(page || []));
							if (!page || page.length < 1000) break;
						}
						return records;
					})(),
					db.from('break_reasons').select('id,name_en,name_ar'),
					(async () => {
						const records: any[] = [];
						for (let offset = 0; ; offset += 1000) {
							let query = db.from('hr_analysed_attendance_data')
								.select('employee_id,employee_name_en,employee_name_ar,branch_id,shift_date,status')
								.gte('shift_date', from).lte('shift_date', to).order('shift_date').range(offset, offset + 999);
							if (scope === 'own' && employee?.id) query = query.eq('employee_id', employee.id);
							if (scopedBranch !== null) query = query.eq('branch_id', String(scopedBranch));
							const { data: page, error } = await query;
							if (error) throw error;
							records.push(...(page || []));
							if (!page || page.length < 1000) break;
						}
						return records;
					})(),
					db.from('hr_employee_master_with_status').select('id,employment_status'),
					db.from('hr_employee_status_history')
						.select('employee_id,status,effective_from,effective_to')
						.eq('status', 'Vacation')
						.lte('effective_from', to)
						.or(`effective_to.is.null,effective_to.gte.${from}`)
				]);
				if (scheduleError || !scheduleData?.success) throw scheduleError || new Error(scheduleData?.error || 'Failed to load schedule');
				if (summaryReasonsError) throw summaryReasonsError;
				if (employeeStatusesError) throw employeeStatusesError;
				if (statusHistoryError) throw statusHistoryError;
				const hiddenEmployeeIds = new Set((employeeStatuses || [])
					.filter(row => row.employment_status === 'Remote Job' || row.employment_status === 'Resigned')
					.map(row => String(row.id)));
				const isVacationOnDate = (employeeId: string, date: string) => (statusHistory || []).some(period =>
					String(period.employee_id) === String(employeeId)
					&& period.effective_from <= date
					&& (!period.effective_to || period.effective_to >= date)
				);
				const visibleAttendanceRecords = attendanceRecords.filter((row: any) =>
					!hiddenEmployeeIds.has(String(row.employee_id))
					&& row.status !== 'Vacation'
					&& !isVacationOnDate(row.employee_id, row.shift_date)
				);
				const visibleBreakRecords = analyzedRecords.filter((row: any) =>
					!hiddenEmployeeIds.has(String(row.employee_id))
					&& !isVacationOnDate(row.employee_id, row.shift_date)
				);
				const reasonById = new Map((summaryReasons || []).map(reason => [reason.id, reason]));
				const attendanceByEmployeeDate = new Map(visibleAttendanceRecords.map((row: any) => [`${row.employee_id}__${row.shift_date}`, row]));
				const byEmployee = new Map<string, any>();
				const ensureEmployee = (record: any) => {
					let entry = byEmployee.get(String(record.employee_id));
					if (!entry) {
						entry = { employee_id: record.employee_id, employee_name_en: record.employee_name_en || record.name_en,
							employee_name_ar: record.employee_name_ar || record.name_ar, branch_id: record.branch_id,
							days: [], grand_total_seconds: 0 };
						byEmployee.set(String(record.employee_id), entry);
					}
					return entry;
				};
				for (const row of scheduleData.rows || []) {
					if (hiddenEmployeeIds.has(String(row.employee_id)) || isVacationOnDate(row.employee_id, row.shift_date) || !row.scheduled || (scope === 'own' && String(row.employee_id) !== String(employee?.id))) continue;
					const entry = ensureEmployee(row);
					if (!entry.days.some((day: any) => day.date === row.shift_date)) {
						const attendance = attendanceByEmployeeDate.get(`${row.employee_id}__${row.shift_date}`);
						entry.days.push({ date: row.shift_date, total_seconds: 0, break_count: 0, breaks: [], attendance_status: attendance?.status || null });
					}
				}
				for (const attendance of visibleAttendanceRecords) {
					const entry = ensureEmployee(attendance);
					if (!entry.days.some((day: any) => day.date === attendance.shift_date)) {
						entry.days.push({ date: attendance.shift_date, total_seconds: 0, break_count: 0, breaks: [], attendance_status: attendance.status });
					}
				}
				for (const record of visibleBreakRecords) {
					const entry = ensureEmployee(record);
					let day = entry.days.find((item: any) => item.date === record.shift_date);
					if (!day) {
						const attendance = attendanceByEmployeeDate.get(`${record.employee_id}__${record.shift_date}`);
						day = { date: record.shift_date, total_seconds: 0, break_count: 0, breaks: [], attendance_status: attendance?.status || null };
						entry.days.push(day);
					}
					day.total_seconds += Number(record.duration_seconds) || 0;
					day.break_count++;
					const reason = reasonById.get(record.reason_id);
					day.breaks.push({
						id: record.break_id, reason_en: reason?.name_en, reason_ar: reason?.name_ar,
						reason_note: record.reason_note, start_time: record.start_time, end_time: record.end_time,
						duration_seconds: Number(record.duration_seconds) || 0, status: record.status,
						is_scheduled: record.is_scheduled, schedule_exception: record.schedule_exception
					});
					entry.grand_total_seconds += Number(record.duration_seconds) || 0;
				}
				for (const entry of byEmployee.values()) entry.days.sort((a: any, b: any) => a.date.localeCompare(b.date));
				const { data: availableBranches, error: branchesError } = await db.from('branches').select('id,name_en,name_ar,location_en,location_ar');
				if (branchesError) throw branchesError;
				return json({ success: true, date_from: from, date_to: to, employees: [...byEmployee.values()],
					branches: scope === 'all' ? availableBranches : scope === 'branch' ? availableBranches?.filter(b => b.id === scopedBranch) : [], scope });
			}
			const rpc = 'get_break_schedule_status';
			const { data, error } = await db.rpc(rpc, { p_date_from: from, p_date_to: to, p_branch_id: scopedBranch });
			if (error || !data?.success) throw error || new Error(data?.error || 'Failed to load summary');
			if (scope === 'own') {
				data.rows = (data.rows || []).filter((row: any) => row.employee_id === employee?.id);
			}
			return json(data);
		}
		return json({ error: 'Unknown view' }, { status: 400 });
	} catch (error) {
		console.error('Break Register API error:', error);
		const unauthorized = error instanceof Error && /session/i.test(error.message);
		return json({ error: unauthorized ? 'Break Register session required' : 'Break Register data unavailable' }, { status: unauthorized ? 401 : 500 });
	}
};
