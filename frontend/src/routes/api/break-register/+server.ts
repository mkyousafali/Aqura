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
			let query = db.from('break_register').select('id,user_id,employee_id,employee_name_en,employee_name_ar,branch_id,reason_id,reason_note,start_time,end_time,duration_seconds,status')
				.order('start_time', { ascending: false }).limit(500);
			if (scope === 'own') query = query.eq('user_id', user.id);
			if (scopedBranch !== null) query = query.eq('branch_id', scopedBranch);
			if (from) query = query.gte('start_time', `${from}T00:00:00+03:00`);
			if (to) {
				const next = new Date(`${to}T00:00:00+03:00`);
				next.setUTCDate(next.getUTCDate() + 1);
				query = query.lt('start_time', next.toISOString());
			}
			if (status) query = query.eq('status', status);
			const { data: records, error } = await query;
			if (error) throw error;
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
			if (view === 'summary' && scope === 'branch') {
				const next = new Date(`${to}T00:00:00+03:00`);
				next.setUTCDate(next.getUTCDate() + 1);
				const records: any[] = [];
				for (let offset = 0; ; offset += 1000) {
					const { data: page, error } = await db.from('break_register')
						.select('user_id,employee_id,employee_name_en,employee_name_ar,duration_seconds,start_time')
						.eq('branch_id', scopedBranch).eq('status', 'closed')
						.gte('start_time', `${from}T00:00:00+03:00`).lt('start_time', next.toISOString())
						.order('start_time').range(offset, offset + 999);
					if (error) throw error;
					records.push(...(page || []));
					if (!page || page.length < 1000) break;
				}
				const byEmployee = new Map<string, any>();
				for (const record of records) {
					const date = new Date(new Date(record.start_time).getTime() + 3 * 3600000).toISOString().slice(0, 10);
					let entry = byEmployee.get(record.employee_id);
					if (!entry) {
						entry = { employee_id: record.employee_id, employee_name_en: record.employee_name_en,
							employee_name_ar: record.employee_name_ar, branch_id: scopedBranch, days: [], grand_total_seconds: 0 };
						byEmployee.set(record.employee_id, entry);
					}
					let day = entry.days.find((d: any) => d.date === date);
					if (!day) { day = { date, total_seconds: 0, break_count: 0 }; entry.days.push(day); }
					day.total_seconds += Number(record.duration_seconds) || 0;
					day.break_count++;
					entry.grand_total_seconds += Number(record.duration_seconds) || 0;
				}
				return json({ success: true, employees: [...byEmployee.values()] });
			}
			const rpc = view === 'summary' ? 'get_break_summary_all_employees' : 'get_break_schedule_status';
			const { data, error } = await db.rpc(rpc, { p_date_from: from, p_date_to: to, p_branch_id: scopedBranch });
			if (error || !data?.success) throw error || new Error(data?.error || 'Failed to load summary');
			if (scope === 'own') {
				const rowsKey = view === 'summary' ? 'employees' : 'rows';
				data[rowsKey] = (data[rowsKey] || []).filter((row: any) => row.employee_id === employee?.id);
			}
			return json(data);
		}
		return json({ error: 'Unknown view' }, { status: 400 });
	} catch (error) {
		const unauthorized = error instanceof Error && /session/i.test(error.message);
		return json({ error: unauthorized ? 'Break Register session required' : 'Break Register data unavailable' }, { status: unauthorized ? 401 : 500 });
	}
};
