import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { databaseClient, requireBreakUser } from '$lib/server/breakRegisterAuth';

function db() {
	return createClient(env.VITE_SUPABASE_URL || '', env.SUPABASE_SERVICE_ROLE_KEY || env.VITE_SUPABASE_SERVICE_KEY || '');
}

export const GET: RequestHandler = async ({ cookies, url }) => {
	try {
		const user = await requireBreakUser(cookies, 'desktop');
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

		if (body.task_type === 'receiving_bank_payment') {
			if (body.pay_to_credit_transaction_id) {
				const transactionId = String(body.pay_to_credit_transaction_id);
				const selectedBillIds = Array.isArray(body.payment_schedule_ids) ? body.payment_schedule_ids.map(String) : [];
				if (!selectedBillIds.length) return json({ success: false, error: 'Select at least one unpaid vendor bill' }, { status: 400 });
				const { data: transaction, error: transactionError } = await secureDb.from('pos_scan_requests')
					.select('id,branch_id,request_type,request_label,extracted_amount,payment_account_type,status')
					.eq('id', transactionId).maybeSingle();
				if (transactionError || !transaction || transaction.request_type !== 'pay_to_credit_slip') return json({ success: false, error: 'Pay to Credit transaction was not found' }, { status: 404 });
				const { data: bills, error: billsError } = await secureDb.from('vendor_payment_schedule')
					.select('id,bill_number,vendor_name,final_bill_amount,bill_amount,is_paid,branch_id')
					.in('id', selectedBillIds)
					.eq('branch_id', transaction.branch_id)
					.eq('is_paid', false);
				if (billsError) throw billsError;
				if (!bills || bills.length !== selectedBillIds.length) return json({ success: false, error: 'One or more selected unpaid bills could not be found' }, { status: 400 });
				const vendorNames = [...new Set(bills.map((bill) => String(bill.vendor_name || '').trim()).filter(Boolean))];
				if (vendorNames.length !== 1) return json({ success: false, error: 'All selected bills must belong to the same vendor' }, { status: 400 });
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
					bank_account_id: defaults.bank_delivery_ledger_id,
					bank_account: defaults.bank_delivery_ledger_name,
					ledger_name: vendorNames[0],
					amount: amount.toFixed(2),
					narration: `Pay to Credit - bills ${billNumbers.join(', ')}`,
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
				if (!selectedBillIds.length) return json({ success: false, error: 'Select at least one unpaid vendor bill' }, { status: 400 });
				const { data: transaction, error: transactionError } = await secureDb.from('pos_scan_requests')
					.select('id,branch_id,request_type,extracted_amount,payment_account_type')
					.eq('id', transactionId).maybeSingle();
				if (transactionError || !transaction || transaction.request_type !== 'pay_to_credit_slip') return json({ success: false, error: 'Pay to Credit transaction was not found' }, { status: 404 });
				if (transaction.payment_account_type !== 'cash') return json({ success: false, error: 'This Pay to Credit transaction is not a cash payment' }, { status: 400 });
				const { data: bills, error: billsError } = await secureDb.from('vendor_payment_schedule')
					.select('id,bill_number,vendor_name,final_bill_amount,bill_amount,is_paid,branch_id')
					.in('id', selectedBillIds).eq('branch_id', transaction.branch_id).eq('is_paid', false);
				if (billsError) throw billsError;
				if (!bills || bills.length !== selectedBillIds.length) return json({ success: false, error: 'One or more selected unpaid bills could not be found' }, { status: 400 });
				const vendorNames = [...new Set(bills.map((bill) => String(bill.vendor_name || '').trim()).filter(Boolean))];
				if (vendorNames.length !== 1) return json({ success: false, error: 'All selected bills must belong to the same vendor' }, { status: 400 });
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
					ledger_name: vendorNames[0], amount: amount.toFixed(2),
					narration: `Pay to Credit - bills ${billNumbers.join(', ')}`,
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

export const PATCH: RequestHandler = async ({ request, cookies }) => {
	try {
		const user = await requireBreakUser(cookies, 'desktop');
		const body = await request.json();
		if (!body.id || !['in_progress', 'completed', 'failed'].includes(body.status)) return json({ success: false, error: 'Invalid task update' }, { status: 400 });
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
