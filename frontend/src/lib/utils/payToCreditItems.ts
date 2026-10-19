export type CreditSelection = { bills: string[]; expenses: string[] };

export function creditVendorName(label: unknown): string {
	return String(label || '').replace(/^Pay to Credit[\s\u00b7\u00c2]*/i, '').trim();
}

const normalize = (name: unknown) => String(name || '').trim().replace(/\s+/g, ' ').toLowerCase();
const literalPattern = (name: string) => name.replace(/[\\%_]/g, '\\$&');

export function creditItem(row: any, type: 'Bill' | 'Expense', approvalStatus?: string) {
	const amount = Number(type === 'Bill' ? row.final_bill_amount ?? row.bill_amount ?? 0 : row.amount ?? 0);
	return {
		...row, id: `${type}:${row.id}`, source_id: String(row.id), source_type: type,
		final_bill_amount: amount, bill_amount: amount,
		approval_status: approvalStatus ?? row.approval_status,
		bill_number: row.bill_number || row.requisition_number || row.description || ''
	};
}

export function creditSelection(items: any[], keys: string[]): CreditSelection {
	const chosen = new Set(keys);
	return {
		bills: items.filter(item => chosen.has(item.id) && item.source_type === 'Bill').map(item => item.source_id),
		expenses: items.filter(item => chosen.has(item.id) && item.source_type === 'Expense').map(item => item.source_id)
	};
}

async function rows(query: () => any) {
	const result: any[] = [];
	for (let offset = 0; ; offset += 1000) {
		const { data, error } = await query().range(offset, offset + 999);
		if (error) throw error;
		result.push(...(data || []));
		if (!data || data.length < 1000) return result;
	}
}

/** Keep supplier, branch, unpaid and approval handling identical in the UI and task API. */
export async function loadPayToCreditItems(client: any, branchId: number, vendorName: string, selection?: CreditSelection) {
	if (!vendorName.trim()) throw new Error('Vendor name is missing from this transaction.');
	const { data: vendors, error: vendorError } = await client.from('vendors')
		.select('erp_vendor_id').eq('branch_id', branchId).ilike('vendor_name', literalPattern(vendorName));
	if (vendorError) throw vendorError;
	const vendorIds = new Set<string>((vendors || []).filter((vendor: any) => vendor.erp_vendor_id != null)
		.map((vendor: any) => String(vendor.erp_vendor_id)));
	const expenseQuery = () => {
		let query = client.from('expense_scheduler').select('*')
			.eq('branch_id', branchId).eq('is_paid', false).order('id');
		if (selection) query = query.in('id', selection.expenses);
		return query;
	};
	const supplierExpenseRows = async () => {
		if (selection && !selection.expenses.length) return [];
		const [linked, legacy] = await Promise.all([
			vendorIds.size ? rows(() => expenseQuery().in('vendor_id', [...vendorIds])) : [],
			rows(() => expenseQuery().is('vendor_id', null))
		]);
		return [...linked, ...legacy];
	};
	const [bills, expenses] = await Promise.all([
		selection && !selection.bills.length ? [] : rows(() => {
			let query = client.from('vendor_payment_schedule_with_vendor').select('*')
				.eq('branch_id', branchId).eq('is_paid', false)
				.ilike('vendor_name', literalPattern(vendorName)).order('id');
			if (selection) query = query.in('id', selection.bills);
			return query;
		}),
		supplierExpenseRows()
	]);
	const supplierExpenses = expenses.filter(expense => expense.vendor_id != null
		? vendorIds.has(String(expense.vendor_id)) : normalize(expense.vendor_name) === normalize(vendorName));
	const requisitionIds = [...new Set(supplierExpenses.map(expense => expense.requisition_id).filter(id => id != null))];
	const statuses = new Map<string, string>();
	for (let offset = 0; offset < requisitionIds.length; offset += 100) {
		const { data, error } = await client.from('expense_requisitions').select('id,status')
			.in('id', requisitionIds.slice(offset, offset + 100));
		if (error) throw error;
		for (const requisition of data || []) statuses.set(String(requisition.id), requisition.status);
	}
	return [
		...bills.map(bill => creditItem(bill, 'Bill')),
		...supplierExpenses.map(expense => {
			const status = expense.requisition_id == null ? 'approved' : statuses.get(String(expense.requisition_id));
			return creditItem(expense, 'Expense', status === 'completed' ? 'approved' : status || 'unknown');
		})
	].sort((a, b) => String(a.due_date || '9999').localeCompare(String(b.due_date || '9999')) || a.id.localeCompare(b.id));
}
