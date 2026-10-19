import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';
import { creditVendorName, loadPayToCreditItems } from '$lib/utils/payToCreditItems';

function db() {
	return createClient(env.VITE_SUPABASE_URL || '', env.SUPABASE_SERVICE_ROLE_KEY || env.VITE_SUPABASE_SERVICE_KEY || '');
}

async function canUseBankPlanner(secureDb: ReturnType<typeof db>, actor: { id: string; isMasterAdmin: boolean }) {
	if (actor.isMasterAdmin) return true;
	const { data } = await secureDb.from('button_permissions').select('is_enabled')
		.eq('user_id', actor.id).eq('button_code', 'BANK_PAYMENT_PLANNER').eq('is_enabled', true).maybeSingle();
	return data?.is_enabled === true;
}

async function canManageAiTasks(secureDb: ReturnType<typeof db>, actor: { id: string; isMasterAdmin: boolean }) {
	if (actor.isMasterAdmin) return true;
	const { data } = await secureDb.from('button_permissions').select('is_enabled')
		.eq('user_id', actor.id).eq('button_code', 'AI_AGENT_TASKS').eq('is_enabled', true).maybeSingle();
	return data?.is_enabled === true;
}

async function canUseStatementsManager(secureDb: ReturnType<typeof db>, actor: { id: string; isMasterAdmin: boolean }) {
	if (actor.isMasterAdmin) return true;
	const { data } = await secureDb.from('button_permissions').select('is_enabled')
		.eq('user_id', actor.id).eq('button_code', 'STATEMENTS_MANAGER').eq('is_enabled', true).maybeSingle();
	return data?.is_enabled === true;
}

async function canPostReceivingPaymentTask(
	secureDb: ReturnType<typeof db>,
	actor: { id: string; isMasterAdmin: boolean },
	branchId: number
) {
	if (actor.isMasterAdmin) return true;
	const { data, error } = await secureDb.from('branch_default_positions')
		.select('entry_task_user_id').eq('branch_id', branchId).maybeSingle();
	if (error) throw error;
	return String(data?.entry_task_user_id || '') === actor.id;
}

export const GET: RequestHandler = async ({ cookies, url }) => {
	try {
		const user = await requireBreakUser(cookies, 'desktop');
		if (url.searchParams.get('manage_ai_tasks') === '1') {
			const secureDb = databaseClient();
			if (!await canManageAiTasks(secureDb, user)) return json({ success: false, error: 'AI Agent Tasks permission required' }, { status: 403 });
			const { data: tasks, error } = await secureDb.from('assistant_workflow_tasks').select('*')
				.in('status', ['pending', 'failed']).order('created_at', { ascending: false });
			if (error) throw error;
			const branchIds = [...new Set((tasks || []).map((task) => Number(task.branch_id)).filter(Number.isFinite))];
			const userIds = [...new Set((tasks || []).map((task) => String(task.assigned_to || '')).filter(Boolean))];
			const [{ data: branches }, { data: users }] = await Promise.all([
				branchIds.length ? secureDb.from('branches').select('id,name_en,location_en').in('id', branchIds) : Promise.resolve({ data: [] }),
				userIds.length ? secureDb.from('users').select('id,username').in('id', userIds) : Promise.resolve({ data: [] })
			]);
			const branchById = new Map((branches || []).map((branch) => [Number(branch.id), branch]));
			const userById = new Map((users || []).map((assignedUser) => [String(assignedUser.id), assignedUser.username]));
			return json({ success: true, tasks: (tasks || []).map((task) => ({
				...task,
				branch_name: branchById.get(Number(task.branch_id))?.location_en || branchById.get(Number(task.branch_id))?.name_en || `Branch ${task.branch_id}`,
				assigned_to_name: userById.get(String(task.assigned_to)) || String(task.assigned_to)
			})) });
		}
		const bankPlannerDate = url.searchParams.get('bank_planner_date');
		if (bankPlannerDate) {
			const secureDb = databaseClient();
			if (!await canUseBankPlanner(secureDb, user)) return json({ success: false, error: 'Bank Payment Planner permission required' }, { status: 403 });
			const { data: schedule } = await secureDb.from('bank_payment_planner_schedules').select('id').eq('schedule_date', bankPlannerDate).maybeSingle();
			if (!schedule) return json({ success: true, tasks: [] });
			const { data, error } = await secureDb.from('assistant_workflow_tasks')
				.select('id,task_type,status,payload,workflow_key')
				.eq('source_record_id', schedule.id).in('task_type', ['bank_planner_bp', 'bank_planner_jv']);
			if (error) throw error;
			return json({ success: true, tasks: data || [] });
		}
		if (url.searchParams.get('receiving_tasks') === '1') {
			const { data, error } = await db().from('assistant_workflow_tasks')
				.select('id,task_type,source_record_id,status,payload')
				.in('task_type', ['receiving_bank_payment', 'receiving_cash_payment']);
			if (error) throw error;
			return json({ success: true, tasks: (data || []).map((task) => ({
				id: task.id,
				task_type: task.task_type,
				status: task.status,
				source_record_id: task.source_record_id || task.payload?.receiving_record_id || null
			})) });
		}
		if (url.searchParams.get('statement_mjv_users') === '1') {
			const secureDb = databaseClient();
			if (!await canUseStatementsManager(secureDb, user)) return json({ success: false, error: 'Statements Manager permission required' }, { status: 403 });
			const term = String(url.searchParams.get('search') || '').trim();
			if (!term) return json({ success: true, users: [] });
			const pattern = `%${term.replace(/[%_]/g, '\\$&')}%`;
			const [english, arabic, employeeId] = await Promise.all([
				secureDb.from('hr_employee_master').select('user_id,id,name_en,name_ar').eq('is_removed', false).ilike('name_en', pattern).limit(25),
				secureDb.from('hr_employee_master').select('user_id,id,name_en,name_ar').eq('is_removed', false).ilike('name_ar', pattern).limit(25),
				secureDb.from('hr_employee_master').select('user_id,id,name_en,name_ar').eq('is_removed', false).ilike('id', pattern).limit(25)
			]);
			if (english.error || arabic.error || employeeId.error) throw english.error || arabic.error || employeeId.error;
			const employees = [...new Map([...(english.data || []), ...(arabic.data || []), ...(employeeId.data || [])].map((employee) => [employee.user_id, employee])).values()];
			if (!employees.length) return json({ success: true, users: [] });
			const { data: activeUsers, error } = await secureDb.from('users').select('id').eq('status', 'active').in('id', employees.map((employee) => employee.user_id));
			if (error) throw error;
			const activeIds = new Set((activeUsers || []).map((activeUser) => activeUser.id));
			return json({ success: true, users: employees.filter((employee) => activeIds.has(employee.user_id)).slice(0, 30) });
		}
		const { data, error } = await db().from('assistant_workflow_tasks').select('*').eq('assigned_to', user.id).in('status', ['pending', 'in_progress', 'failed']).order('created_at', { ascending: false });
		if (error) throw error;
		return json({ success: true, tasks: data || [] });
	} catch (error: any) {
		return json({ success: false, error: error.message || 'Desktop session required' }, { status: 401 });
	}
};

export const POST: RequestHandler = async ({ request, cookies }) => {
	try {
		const actor = await requireBreakUser(cookies, 'desktop');
		const body = await request.json();
		const branchId = Number(body.branch_id);
		const secureDb = databaseClient();

		if (body.task_type === 'statement_mjv') {
			if (!await canUseStatementsManager(secureDb, actor)) return json({ success: false, error: 'Statements Manager permission required' }, { status: 403 });
			const mjvId = String(body.statement_mjv_id || '');
			const { data: mjv, error: mjvError } = await secureDb.from('statement_mjvs').select('id,bank,bank_account_id,statement_date,status,mjv_type').eq('id', mjvId).maybeSingle();
			if (mjvError || !mjv) return json({ success: false, error: 'Saved statement MJV was not found' }, { status: 404 });
			if (mjv.status === 'completed') return json({ success: false, error: 'This statement MJV is already completed' }, { status: 409 });
			const { data: branches, error: branchesError } = await secureDb.from('statement_mjv_branches')
				.select('id,branch_id,branch_name,lines,task_id,task_status').eq('statement_mjv_id', mjv.id).order('branch_name');
			if (branchesError || !branches?.length) return json({ success: false, error: 'The saved MJV has no branch entries' }, { status: 400 });
			if (branches.every((branch) => branch.task_id)) return json({ success: false, error: 'Posting tasks have already been created' }, { status: 409 });
			const pendingBranches = branches.filter((branch) => !branch.task_id);
			const pendingBranchIds = pendingBranches.map((branch) => Number(branch.branch_id));
			const { data: defaults, error: defaultsError } = await secureDb.from('branch_default_positions')
				.select('branch_id,entry_task_user_id').in('branch_id', pendingBranchIds);
			if (defaultsError) throw defaultsError;
			const assigneeByBranch = new Map((defaults || []).map((row) => [Number(row.branch_id), String(row.entry_task_user_id || '')]));
			for (const branch of pendingBranches) {
				const assignedTo = assigneeByBranch.get(Number(branch.branch_id));
				if (!assignedTo) return json({ success: false, error: `No default Entry Task User is configured for ${branch.branch_name}` }, { status: 400 });
				const [{ data: employee }, { data: activeUser }] = await Promise.all([
					secureDb.from('hr_employee_master').select('user_id').eq('is_removed', false).eq('user_id', assignedTo).eq('current_branch_id', Number(branch.branch_id)).maybeSingle(),
					secureDb.from('users').select('id').eq('id', assignedTo).eq('status', 'active').maybeSingle()
				]);
				if (!employee || !activeUser) return json({ success: false, error: `The default Entry Task User for ${branch.branch_name} is not active in that branch` }, { status: 400 });
			}
			const bankName = mjv.bank === 'riyad' ? 'Riyad Bank' : 'Al Ahli Bank';
			const taskRows = pendingBranches.map((branch) => ({
				task_type: 'cash_closing_mjv', title: `${bankName} ${mjv.mjv_type === 'iqama-work-permit' ? 'Iqama & Work Permit' : mjv.mjv_type === 'electricity' ? 'Electricity' : mjv.mjv_type === 'mobily' ? 'Mobily' : mjv.mjv_type === 'stc' ? 'STC' : mjv.mjv_type === 'cash-withdrawal' ? 'Cash Withdrawal' : 'Statement'} MJV - ${mjv.statement_date}`,
				branch_id: Number(branch.branch_id), assigned_to: assigneeByBranch.get(Number(branch.branch_id)), created_by: actor.id,
				source_record_id: mjv.id, workflow_key: `statement-mjv:${mjv.id}:${branch.branch_id}`, status: 'pending',
				payload: { version: 1, statement_mjv_id: mjv.id, statement_bank_account_id: mjv.bank_account_id, statement_date: mjv.statement_date, posting_date: new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Riyadh' }).format(new Date()), branch_name: branch.branch_name, bank: mjv.bank, mjv_type: mjv.mjv_type, lines: branch.lines }
			}));
			const { data: tasks, error: taskError } = await secureDb.from('assistant_workflow_tasks').insert(taskRows).select();
			if (taskError) {
				if (taskError.code === '23505') return json({ success: false, error: 'One or more posting tasks already exist' }, { status: 409 });
				throw taskError;
			}
			for (const task of tasks || []) await secureDb.from('statement_mjv_branches').update({ task_id: task.id, task_status: task.status, updated_at: new Date().toISOString() })
				.eq('statement_mjv_id', mjv.id).eq('branch_id', task.branch_id);
			await secureDb.from('statement_mjvs').update({ status: 'tasks_posted', updated_at: new Date().toISOString() }).eq('id', mjv.id);
			return json({ success: true, tasks: tasks || [] });
		}

		if (body.task_type === 'bank_payment_planner') {
			if (!await canUseBankPlanner(secureDb, actor)) return json({ success: false, error: 'Bank Payment Planner permission required' }, { status: 403 });
			const scheduleDate = String(body.schedule_date || '');
			const vendorId = String(body.vendor_id || '').trim();
			const applicationBatchId = String(body.application_batch_id || '').trim();
			const entries = Array.isArray(body.entries) ? body.entries : [];
			if (!/^\d{4}-\d{2}-\d{2}$/.test(scheduleDate) || !vendorId || !applicationBatchId || !entries.length || entries.length > 25) {
				return json({ success: false, error: 'Invalid Bank Payment Planner task request' }, { status: 400 });
			}
			const { data: schedule, error: scheduleError } = await secureDb.from('bank_payment_planner_schedules')
				.select('id').eq('schedule_date', scheduleDate).maybeSingle();
			if (scheduleError || !schedule) return json({ success: false, error: 'The payment schedule was not found' }, { status: 404 });
			const { data: items, error: itemsError } = await secureDb.from('bank_payment_planner_schedule_items')
				.select('id,source_type,source_id,source_branch_id,vendor_id,vendor_name,branch_location,bill_number,amount,approval_status,paid_from_branch_id,bank_ledger_id,bank_ledger_name')
				.eq('schedule_id', schedule.id).eq('vendor_id', vendorId).eq('application_batch_id', applicationBatchId);
			if (itemsError) throw itemsError;
			if (!items?.length) return json({ success: false, error: 'The scheduled vendor was not found' }, { status: 404 });
			if (items.some((item) => String(item.approval_status || '').toLowerCase() !== 'approved')) {
				return json({ success: false, error: 'All scheduled records must be approved before posting tasks' }, { status: 400 });
			}
			const paidFromBranchId = Number(items[0].paid_from_branch_id);
			const bankLedgerId = Number(items[0].bank_ledger_id);
			const bankLedgerName = String(items[0].bank_ledger_name || '').trim();
			if (!Number.isFinite(paidFromBranchId) || !Number.isFinite(bankLedgerId) || !bankLedgerName
				|| items.some((item) => Number(item.paid_from_branch_id) !== paidFromBranchId || Number(item.bank_ledger_id) !== bankLedgerId)) {
				return json({ success: false, error: 'Select one paying branch and bank account before posting tasks' }, { status: 400 });
			}
			const scheduleAmount = items.reduce((total, item) => total + Number(item.amount || 0), 0);
			const bpEntries = entries.filter((entry: any) => entry.type === 'bp');
			if (bpEntries.length !== 1 || Number(bpEntries[0].postingBranchId) !== paidFromBranchId
				|| Math.abs(Number(bpEntries[0].amount) - scheduleAmount) > 0.005
				|| Number(bpEntries[0].creditLedger?.id) !== bankLedgerId
				|| String(bpEntries[0].creditLedger?.name || '').trim() !== bankLedgerName
				|| String(bpEntries[0].debitLedger?.code || '').trim() !== vendorId) {
				return json({ success: false, error: 'The planned BP no longer matches the saved schedule' }, { status: 400 });
			}
			const allowedBranches = new Set([paidFromBranchId, ...items.map((item) => Number(item.source_branch_id))]);
			for (const entry of entries) {
				const amount = Number(entry.amount);
				if (!['bp', 'jv'].includes(entry.type) || !allowedBranches.has(Number(entry.postingBranchId)) || !(amount > 0)
					|| !String(entry.debitLedger?.name || '').trim() || !String(entry.creditLedger?.name || '').trim()
					|| !String(entry.narration || '').trim() || !String(entry.entry || '').trim()) {
					return json({ success: false, error: 'One or more planned ERP entries are invalid' }, { status: 400 });
				}
			}
			const workflowKeys = entries.map((entry: any) => `bank-planner:${schedule.id}:${applicationBatchId}:${String(entry.entry).trim()}`);
			const { data: existing } = await secureDb.from('assistant_workflow_tasks').select('workflow_key').in('workflow_key', workflowKeys);
			if (existing?.length) return json({ success: false, error: 'Posting tasks already exist for this scheduled vendor' }, { status: 409 });

			const postingBranchIds = [...new Set(entries.map((entry: any) => Number(entry.postingBranchId)))];
			const { data: defaults, error: defaultsError } = await secureDb.from('branch_default_positions')
				.select('branch_id,entry_task_user_id').in('branch_id', postingBranchIds);
			if (defaultsError) throw defaultsError;
			const assigneeByBranch = new Map((defaults || []).map((row) => [Number(row.branch_id), row.entry_task_user_id]));
			for (const postingBranchId of postingBranchIds) {
				const assignedTo = assigneeByBranch.get(postingBranchId);
				if (!assignedTo) return json({ success: false, error: `No default Entry Task User is configured for branch ${postingBranchId}` }, { status: 400 });
				const { data: employee } = await secureDb.from('hr_employee_master').select('user_id')
					.eq('is_removed', false).eq('user_id', assignedTo).eq('current_branch_id', postingBranchId).maybeSingle();
				if (!employee) return json({ success: false, error: `The default Entry Task User is not active in branch ${postingBranchId}` }, { status: 400 });
			}
			const vendorName = String(items[0].vendor_name || vendorId);
			const billNumbers = items.map((item) => `${item.bill_number || `${item.source_type}-${item.source_id}`} (${item.branch_location || 'Unknown branch'})`).join(', ');
			const taskRows = entries.map((entry: any, index: number) => {
				const amount = Number(entry.amount).toFixed(2);
				const isBp = entry.type === 'bp';
				return {
					task_type: isBp ? 'bank_planner_bp' : 'bank_planner_jv',
					title: `${isBp ? 'Bank Payment' : 'Inter-branch JV'} - ${vendorName} - ${scheduleDate}`,
					branch_id: Number(entry.postingBranchId), assigned_to: assigneeByBranch.get(Number(entry.postingBranchId)),
					created_by: actor.id, source_record_id: schedule.id, workflow_key: workflowKeys[index], status: 'pending',
					payload: {
						schedule_date: scheduleDate, vendor_id: vendorId, vendor_name: vendorName,
						application_batch_id: applicationBatchId,
						entry: entry.entry, bill_number: billNumbers, amount, narration: String(entry.narration),
						...(isBp ? {
							bank_account_id: bankLedgerId, bank_account: bankLedgerName,
							ledger_code: String(entry.debitLedger.code), ledger_name: String(entry.debitLedger.name)
						} : {
							lines: [
								{ ledger_name: String(entry.debitLedger.name), amount, side: 'Debit', narration: String(entry.narration) },
								{ ledger_name: String(entry.creditLedger.name), amount, side: 'Credit', narration: String(entry.narration) }
							]
						})
					}
				};
			});
			const { data, error } = await secureDb.from('assistant_workflow_tasks').insert(taskRows).select();
			if (error) {
				if (error.code === '23505') return json({ success: false, error: 'Posting tasks already exist for this scheduled vendor' }, { status: 409 });
				throw error;
			}
			return json({ success: true, tasks: data || [] });
		}

		if (body.task_type === 'receiving_bank_payment') {
			if (body.pay_to_credit_transaction_id) {
				const transactionId = String(body.pay_to_credit_transaction_id);
				const selectedBillIds = Array.isArray(body.payment_schedule_ids) ? body.payment_schedule_ids.map(String) : [];
				const selectedExpenseIds = Array.isArray(body.expense_schedule_ids) ? body.expense_schedule_ids.map(String) : [];
				if (!selectedBillIds.length && !selectedExpenseIds.length) return json({ success: false, error: 'Select at least one unpaid bill or expense' }, { status: 400 });
				const { data: transaction, error: transactionError } = await secureDb.from('pos_scan_requests')
					.select('id,branch_id,request_type,request_label,extracted_amount,payment_account_type,status')
					.eq('id', transactionId).maybeSingle();
				if (transactionError || !transaction || transaction.request_type !== 'pay_to_credit_slip') return json({ success: false, error: 'Pay to Credit transaction was not found' }, { status: 404 });
				if (!await canPostReceivingPaymentTask(secureDb, actor, Number(transaction.branch_id))) {
					return json({ success: false, error: 'Only the branch Entry Task User or a Master Admin can post this payment task' }, { status: 403 });
				}
				const vendorName = creditVendorName(transaction.request_label);
				if (!vendorName) return json({ success: false, error: 'Vendor name is missing from this transaction' }, { status: 400 });
				const bills = await loadPayToCreditItems(secureDb, Number(transaction.branch_id), vendorName, {
					bills: selectedBillIds, expenses: selectedExpenseIds
				});
				if (bills.length !== selectedBillIds.length + selectedExpenseIds.length) return json({ success: false, error: 'One or more selected unpaid bills or expenses do not belong to this supplier and branch, or are no longer unpaid' }, { status: 400 });
				if (bills.some(item => item.approval_status !== 'approved')) return json({ success: false, error: 'Only approved bills and expenses can be posted' }, { status: 400 });
				if (bills.some(item => !Number.isFinite(item.final_bill_amount) || item.final_bill_amount <= 0)) return json({ success: false, error: 'One or more selected items have no valid unpaid amount' }, { status: 400 });
				const vendorNames = [vendorName];
				const amount = bills.reduce((total, bill) => total + Number(bill.final_bill_amount ?? bill.bill_amount ?? 0), 0);
				if (!(amount > 0)) return json({ success: false, error: 'The selected bills have no valid unpaid amount' }, { status: 400 });
				const paidAmount = Number(transaction.extracted_amount || 0);
				if (!(paidAmount > 0)) return json({ success: false, error: 'The Pay to Credit transaction has no valid paid amount' }, { status: 400 });
				if (amount > paidAmount + 0.005) return json({
					success: false,
					error: `Selected bills total (${amount.toFixed(2)} SAR) exceeds the Pay to Credit amount (${paidAmount.toFixed(2)} SAR)`
				}, { status: 400 });
				const { data: defaults } = await secureDb.from('branch_default_positions')
					.select('entry_task_user_id,bank_delivery_ledger_id,bank_delivery_ledger_name')
					.eq('branch_id', transaction.branch_id).maybeSingle();
				if (!defaults?.entry_task_user_id) return json({ success: false, error: 'No default Entry Task User is configured for this branch' }, { status: 400 });
				if (!defaults?.bank_delivery_ledger_name) return json({ success: false, error: 'No default Bank on Delivery account is configured for this branch' }, { status: 400 });
				const { data: assignee } = await secureDb.from('hr_employee_master').select('user_id')
					.eq('is_removed', false).eq('user_id', defaults.entry_task_user_id).eq('current_branch_id', transaction.branch_id).maybeSingle();
				if (!assignee) return json({ success: false, error: 'The default Entry Task User is not active in this branch' }, { status: 400 });
				const billNumbers = bills.map((bill) => bill.bill_number || '-');
				const payload = {
					pay_to_credit_transaction_id: transaction.id,
					payment_schedule_ids: selectedBillIds,
					expense_schedule_ids: selectedExpenseIds,
					bank_account_id: defaults.bank_delivery_ledger_id,
					bank_account: defaults.bank_delivery_ledger_name,
					ledger_name: vendorNames[0],
					amount: amount.toFixed(2),
					narration: `Pay to Credit - ${selectedExpenseIds.length ? 'bills/expenses' : 'bills'} ${billNumbers.join(', ')}`,
					bill_number: billNumbers.join(', '),
					received_by: actor.username || 'Aqura user'
				};
				const { data, error } = await secureDb.from('assistant_workflow_tasks').insert({
					task_type: 'receiving_bank_payment', title: `Bank Payment - Pay to Credit - ${billNumbers.join(', ')}`,
					branch_id: transaction.branch_id, assigned_to: defaults.entry_task_user_id, created_by: actor.id,
					source_record_id: transaction.id, payload, status: 'pending'
				}).select().single();
				if (error) {
					if (error.code === '23505') return json({ success: false, error: 'A Bank Payment task already exists for this Pay to Credit transaction' }, { status: 409 });
					throw error;
				}
				return json({ success: true, task: data });
			}
			if (!body.receiving_record_id) return json({ success: false, error: 'Receiving record is required' }, { status: 400 });
			const { data: record, error: recordError } = await secureDb.from('receiving_records')
				.select('id,branch_id,vendor_id,user_id,bill_number,final_bill_amount,bill_amount,payment_method,pr_excel_file_url,erp_check_result,original_bill_check_result')
				.eq('id', body.receiving_record_id).maybeSingle();
			if (recordError || !record) return json({ success: false, error: 'Receiving record was not found' }, { status: 404 });
			if (!await canPostReceivingPaymentTask(secureDb, actor, Number(record.branch_id))) {
				return json({ success: false, error: 'Only the branch Entry Task User or a Master Admin can post this payment task' }, { status: 403 });
			}
			if (String(record.payment_method || '').trim().toLowerCase() !== 'bank on delivery') return json({ success: false, error: 'Only Bank on Delivery records can create a Bank Payment task' }, { status: 400 });
			if (!record.pr_excel_file_url) return json({ success: false, error: 'PR Excel must be uploaded before posting a payment task' }, { status: 400 });
			if (record.original_bill_check_result?.status !== 'matched') return json({ success: false, error: 'The original bill check must be matched before posting a payment task' }, { status: 400 });
			if (record.erp_check_result?.status !== 'matched') return json({ success: false, error: 'The ERP check must be matched before posting a payment task' }, { status: 400 });

			const [{ data: defaults }, { data: vendor }, { data: receiver }, { data: slip }] = await Promise.all([
				secureDb.from('branch_default_positions').select('entry_task_user_id,bank_delivery_ledger_id,bank_delivery_ledger_name').eq('branch_id', record.branch_id).maybeSingle(),
				secureDb.from('vendors').select('vendor_name').eq('branch_id', record.branch_id).eq('erp_vendor_id', record.vendor_id).maybeSingle(),
				secureDb.from('users').select('username').eq('id', record.user_id).maybeSingle(),
				secureDb.from('receiving_record_bank_slips').select('check_result').eq('receiving_record_id', record.id).maybeSingle()
			]);
			if (slip?.check_result?.status !== 'matched') return json({ success: false, error: 'The bank slip must be checked and matched first' }, { status: 400 });
			if (!defaults?.entry_task_user_id) return json({ success: false, error: 'No default Entry Task User is configured for this branch' }, { status: 400 });
			if (!defaults?.bank_delivery_ledger_name) return json({ success: false, error: 'No default Bank on Delivery account is configured for this branch' }, { status: 400 });
			if (!vendor?.vendor_name) return json({ success: false, error: 'The vendor ledger name was not found' }, { status: 400 });

			const { data: employee } = await secureDb.from('hr_employee_master').select('name_en,name_ar').eq('user_id', record.user_id).maybeSingle();
			const receivedBy = employee?.name_en || employee?.name_ar || receiver?.username || 'Unknown user';
			const amount = Number(record.final_bill_amount ?? record.bill_amount ?? 0);
			if (!(amount > 0)) return json({ success: false, error: 'The receiving record has no valid final amount' }, { status: 400 });
			const { data: assignee } = await secureDb.from('hr_employee_master').select('user_id').eq('is_removed', false).eq('user_id', defaults.entry_task_user_id).eq('current_branch_id', record.branch_id).maybeSingle();
			if (!assignee) return json({ success: false, error: 'The default Entry Task User is not active in this branch' }, { status: 400 });

			const payload = {
				receiving_record_id: record.id, bank_account_id: defaults.bank_delivery_ledger_id,
				bank_account: defaults.bank_delivery_ledger_name, ledger_name: vendor.vendor_name,
				amount: amount.toFixed(2), narration: `Paid bill ${record.bill_number || '-'} received by ${receivedBy}`,
				bill_number: record.bill_number || '', received_by: receivedBy
			};
			const { data, error } = await secureDb.from('assistant_workflow_tasks').insert({
				task_type: 'receiving_bank_payment', title: `Bank Payment - Bill ${record.bill_number || '-'}`,
				branch_id: record.branch_id, assigned_to: defaults.entry_task_user_id, created_by: actor.id,
				source_record_id: record.id, payload, status: 'pending'
			}).select().single();
			if (error) {
				if (error.code === '23505') return json({ success: false, error: 'A Bank Payment task already exists for this receiving record' }, { status: 409 });
				throw error;
			}
			return json({ success: true, task: data });
		}

		if (body.task_type === 'receiving_cash_payment') {
			if (body.pay_to_credit_transaction_id) {
				const transactionId = String(body.pay_to_credit_transaction_id);
				const selectedBillIds = Array.isArray(body.payment_schedule_ids) ? body.payment_schedule_ids.map(String) : [];
				const selectedExpenseIds = Array.isArray(body.expense_schedule_ids) ? body.expense_schedule_ids.map(String) : [];
				if (!selectedBillIds.length && !selectedExpenseIds.length) return json({ success: false, error: 'Select at least one unpaid bill or expense' }, { status: 400 });
				const { data: transaction, error: transactionError } = await secureDb.from('pos_scan_requests')
					.select('id,branch_id,request_type,request_label,extracted_amount,payment_account_type')
					.eq('id', transactionId).maybeSingle();
				if (transactionError || !transaction || transaction.request_type !== 'pay_to_credit_slip') return json({ success: false, error: 'Pay to Credit transaction was not found' }, { status: 404 });
				if (!await canPostReceivingPaymentTask(secureDb, actor, Number(transaction.branch_id))) {
					return json({ success: false, error: 'Only the branch Entry Task User or a Master Admin can post this payment task' }, { status: 403 });
				}
				if (transaction.payment_account_type !== 'cash') return json({ success: false, error: 'This Pay to Credit transaction is not a cash payment' }, { status: 400 });
				const vendorName = creditVendorName(transaction.request_label);
				if (!vendorName) return json({ success: false, error: 'Vendor name is missing from this transaction' }, { status: 400 });
				const bills = await loadPayToCreditItems(secureDb, Number(transaction.branch_id), vendorName, {
					bills: selectedBillIds, expenses: selectedExpenseIds
				});
				if (bills.length !== selectedBillIds.length + selectedExpenseIds.length) return json({ success: false, error: 'One or more selected unpaid bills or expenses do not belong to this supplier and branch, or are no longer unpaid' }, { status: 400 });
				if (bills.some(item => item.approval_status !== 'approved')) return json({ success: false, error: 'Only approved bills and expenses can be posted' }, { status: 400 });
				if (bills.some(item => !Number.isFinite(item.final_bill_amount) || item.final_bill_amount <= 0)) return json({ success: false, error: 'One or more selected items have no valid unpaid amount' }, { status: 400 });
				const vendorNames = [vendorName];
				const amount = bills.reduce((total, bill) => total + Number(bill.final_bill_amount ?? bill.bill_amount ?? 0), 0);
				if (!(amount > 0)) return json({ success: false, error: 'The selected bills have no valid unpaid amount' }, { status: 400 });
				const paidAmount = Number(transaction.extracted_amount || 0);
				if (!(paidAmount > 0)) return json({ success: false, error: 'The Pay to Credit transaction has no valid paid amount' }, { status: 400 });
				if (amount > paidAmount + 0.005) return json({ success: false, error: `Selected bills total (${amount.toFixed(2)} SAR) exceeds the Pay to Credit amount (${paidAmount.toFixed(2)} SAR)` }, { status: 400 });
				const { data: defaults } = await secureDb.from('branch_default_positions')
					.select('entry_task_user_id').eq('branch_id', transaction.branch_id).maybeSingle();
				if (!defaults?.entry_task_user_id) return json({ success: false, error: 'No default Entry Task User is configured for this branch' }, { status: 400 });
				const { data: assignee } = await secureDb.from('hr_employee_master').select('user_id')
					.eq('is_removed', false).eq('user_id', defaults.entry_task_user_id).eq('current_branch_id', transaction.branch_id).maybeSingle();
				if (!assignee) return json({ success: false, error: 'The default Entry Task User is not active in this branch' }, { status: 400 });
				const billNumbers = bills.map((bill) => bill.bill_number || '-');
				const payload = {
					pay_to_credit_transaction_id: transaction.id,
					payment_schedule_ids: selectedBillIds,
					expense_schedule_ids: selectedExpenseIds,
					ledger_name: vendorNames[0], amount: amount.toFixed(2),
					narration: `Pay to Credit - ${selectedExpenseIds.length ? 'bills/expenses' : 'bills'} ${billNumbers.join(', ')}`,
					bill_number: billNumbers.join(', '), received_by: actor.username || 'Aqura user'
				};
				const { data, error } = await secureDb.from('assistant_workflow_tasks').insert({
					task_type: 'receiving_cash_payment', title: `Cash Payment - Pay to Credit - ${billNumbers.join(', ')}`,
					branch_id: transaction.branch_id, assigned_to: defaults.entry_task_user_id, created_by: actor.id,
					source_record_id: transaction.id, payload, status: 'pending'
				}).select().single();
				if (error) {
					if (error.code === '23505') return json({ success: false, error: 'A Cash Payment task already exists for this Pay to Credit transaction' }, { status: 409 });
					throw error;
				}
				return json({ success: true, task: data });
			}
			if (!body.receiving_record_id) return json({ success: false, error: 'Receiving record is required' }, { status: 400 });
			const { data: record, error: recordError } = await secureDb.from('receiving_records')
				.select('id,branch_id,vendor_id,user_id,bill_number,final_bill_amount,bill_amount,payment_method,pr_excel_file_url,erp_check_result,original_bill_check_result')
				.eq('id', body.receiving_record_id).maybeSingle();
			if (recordError || !record) return json({ success: false, error: 'Receiving record was not found' }, { status: 404 });
			if (!await canPostReceivingPaymentTask(secureDb, actor, Number(record.branch_id))) {
				return json({ success: false, error: 'Only the branch Entry Task User or a Master Admin can post this payment task' }, { status: 403 });
			}
			if (String(record.payment_method || '').trim().toLowerCase() !== 'cash on delivery') return json({ success: false, error: 'Only Cash on Delivery records can create a Cash Payment task' }, { status: 400 });
			if (!record.pr_excel_file_url) return json({ success: false, error: 'PR Excel must be uploaded before posting a payment task' }, { status: 400 });
			if (record.original_bill_check_result?.status !== 'matched') return json({ success: false, error: 'The original bill check must be matched before posting a payment task' }, { status: 400 });
			if (record.erp_check_result?.status !== 'matched') return json({ success: false, error: 'The ERP check must be matched before posting a payment task' }, { status: 400 });

			const [{ data: defaults }, { data: vendor }, { data: receiver }] = await Promise.all([
				secureDb.from('branch_default_positions').select('entry_task_user_id').eq('branch_id', record.branch_id).maybeSingle(),
				secureDb.from('vendors').select('vendor_name').eq('branch_id', record.branch_id).eq('erp_vendor_id', record.vendor_id).maybeSingle(),
				secureDb.from('users').select('username').eq('id', record.user_id).maybeSingle()
			]);
			if (!defaults?.entry_task_user_id) return json({ success: false, error: 'No default Entry Task User is configured for this branch' }, { status: 400 });
			if (!vendor?.vendor_name) return json({ success: false, error: 'The vendor ledger name was not found' }, { status: 400 });
			const { data: employee } = await secureDb.from('hr_employee_master').select('name_en,name_ar').eq('user_id', record.user_id).maybeSingle();
			const receivedBy = employee?.name_en || employee?.name_ar || receiver?.username || 'Unknown user';
			const amount = Number(record.final_bill_amount ?? record.bill_amount ?? 0);
			if (!(amount > 0)) return json({ success: false, error: 'The receiving record has no valid final amount' }, { status: 400 });
			const { data: assignee } = await secureDb.from('hr_employee_master').select('user_id').eq('is_removed', false).eq('user_id', defaults.entry_task_user_id).eq('current_branch_id', record.branch_id).maybeSingle();
			if (!assignee) return json({ success: false, error: 'The default Entry Task User is not active in this branch' }, { status: 400 });
			const payload = {
				receiving_record_id: record.id, ledger_name: vendor.vendor_name, amount: amount.toFixed(2),
				narration: `Paid bill ${record.bill_number || '-'} received by ${receivedBy}`,
				bill_number: record.bill_number || '', received_by: receivedBy
			};
			const { data, error } = await secureDb.from('assistant_workflow_tasks').insert({
				task_type: 'receiving_cash_payment', title: `Cash Payment - Bill ${record.bill_number || '-'}`,
				branch_id: record.branch_id, assigned_to: defaults.entry_task_user_id, created_by: actor.id,
				source_record_id: record.id, payload, status: 'pending'
			}).select().single();
			if (error) {
				if (error.code === '23505') return json({ success: false, error: 'A Cash Payment task already exists for this receiving record' }, { status: 409 });
				throw error;
			}
			return json({ success: true, task: data });
		}

		if (!Number.isFinite(branchId) || body.task_type !== 'cash_closing_mjv' || !Array.isArray(body.payload?.lines) || !body.payload.lines.length) {
			return json({ success: false, error: 'Invalid cash-closing MJV task' }, { status: 400 });
		}
		const { data: defaults, error: defaultsError } = await secureDb.from('branch_default_positions').select('entry_task_user_id').eq('branch_id', branchId).maybeSingle();
		if (defaultsError || !defaults?.entry_task_user_id) return json({ success: false, error: 'No default Entry Task User is configured for this branch' }, { status: 400 });
		const assignedTo = defaults.entry_task_user_id;
		const { data: assignee, error: assigneeError } = await secureDb.from('hr_employee_master').select('user_id').eq('is_removed', false).eq('user_id', assignedTo).eq('current_branch_id', branchId).maybeSingle();
		if (assigneeError || !assignee) return json({ success: false, error: 'The selected user is not active in this branch' }, { status: 403 });
		const { data, error } = await secureDb.from('assistant_workflow_tasks').insert({
			task_type: body.task_type,
			title: 'Cash Closing MJV',
			branch_id: branchId,
			assigned_to: assignedTo,
			created_by: actor.id,
			payload: body.payload,
			status: 'pending'
		}).select().single();
		if (error) throw error;
		return json({ success: true, task: data });
	} catch (error: any) {
		return json({ success: false, error: error.message || 'Task creation failed' }, { status: 400 });
	}
};

export const DELETE: RequestHandler = async ({ request, cookies }) => {
	try {
		const actor = await requireBreakUser(cookies, 'desktop');
		const secureDb = databaseClient();
		if (!await canManageAiTasks(secureDb, actor)) return json({ success: false, error: 'AI Agent Tasks permission required' }, { status: 403 });
		const body = await request.json();
		if (!body.id) return json({ success: false, error: 'Task ID is required' }, { status: 400 });
		const { data, error } = await secureDb.from('assistant_workflow_tasks').delete()
			.eq('id', body.id).in('status', ['pending', 'failed']).select('id').maybeSingle();
		if (error) throw error;
		if (!data) return json({ success: false, error: 'Only pending or failed AI tasks can be deleted' }, { status: 409 });
		return json({ success: true, id: data.id });
	} catch (error: any) {
		return json({ success: false, error: error.message || 'Task deletion failed' }, { status: 400 });
	}
};

export const PATCH: RequestHandler = async ({ request, cookies }) => {
	try {
		const user = await requireBreakUser(cookies, 'desktop');
		const body = await request.json();
		if (!body.id || !['pending', 'in_progress', 'completed', 'failed'].includes(body.status)) return json({ success: false, error: 'Invalid task update' }, { status: 400 });
		const updates: any = { status: body.status, result: body.result || null };
		if (body.status === 'in_progress') updates.started_at = new Date().toISOString();
		if (body.status === 'completed') updates.completed_at = new Date().toISOString();
		const { data, error } = await db().from('assistant_workflow_tasks').update(updates).eq('id', body.id).eq('assigned_to', user.id).select().single();
		if (error) throw error;
		return json({ success: true, task: data });
	} catch (error: any) {
		return json({ success: false, error: error.message || 'Task update failed' }, { status: 400 });
	}
};
