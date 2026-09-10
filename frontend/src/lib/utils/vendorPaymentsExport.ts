type PaymentRow = { vendor_id: unknown; branch_id: unknown; final_bill_amount?: number; amount?: number };
type ExportInput = {
	vendors: { vendor_id: string; vendor_name: string }[];
	branches: { id: number; name_en: string; location_en?: string }[];
	selectedBranchId: string;
	bills: PaymentRow[];
	expenses: PaymentRow[];
	overdueBills: PaymentRow[];
	overdueExpenses: PaymentRow[];
	erp: { branch_id: number | null; rows: { PartyCode: unknown; TotalDebit: unknown; TotalCredit: unknown }[] }[];
};

export function buildVendorPaymentsExport(input: ExportInput) {
	const branchKey = (id: unknown) => id == null || id === '' ? 'unassigned' : String(id);
	const branchIds = input.selectedBranchId ? [input.selectedBranchId] : [...new Set([
		...input.branches.map(b => String(b.id)),
		...[...input.bills, ...input.expenses, ...input.overdueBills, ...input.overdueExpenses, ...input.erp].map(r => branchKey(r.branch_id))
	])];
	type Amounts = { bills: number; expenses: number; overdue: number; erp: number; hasErp: boolean };
	const totals = new Map<string, Map<string, Amounts>>();
	function get(vendor: unknown, branch: unknown) {
		const key = branchKey(branch);
		if (input.selectedBranchId && key !== input.selectedBranchId) return;
		const id = String(vendor);
		if (!totals.has(id)) totals.set(id, new Map());
		const branches = totals.get(id)!;
		if (!branches.has(key)) branches.set(key, { bills: 0, expenses: 0, overdue: 0, erp: 0, hasErp: false });
		return branches.get(key)!;
	}
	for (const [rows, field, amount] of [
		[input.bills, 'bills', 'final_bill_amount'], [input.expenses, 'expenses', 'amount'],
		[input.overdueBills, 'overdue', 'final_bill_amount'], [input.overdueExpenses, 'overdue', 'amount']
	] as const) {
		for (const row of rows) {
			if (!row.vendor_id) continue;
			const values = get(row.vendor_id, row.branch_id);
			if (values) values[field] += Number(row[amount]) || 0;
		}
	}
	for (const branch of input.erp) for (const row of branch.rows) {
		const values = get(row.PartyCode, branch.branch_id);
		if (values) {
			values.erp += (Number(row.TotalDebit) || 0) - (Number(row.TotalCredit) || 0);
			values.hasErp = true;
		}
	}
	const groups = branchIds.map(id => {
		const branch = input.branches.find(b => String(b.id) === id);
		return { id, name: branch ? `${branch.name_en}${branch.location_en ? ` - ${branch.location_en}` : ''} (${id})` : id === 'unassigned' ? 'Unassigned' : `Branch ${id}` };
	});
	if (!input.selectedBranchId) groups.push({ id: 'overall', name: 'Overall Total' });
	const metrics = ['Bills Unpaid', 'Expenses Unpaid', 'Total Unpaid', 'Total Overdue', 'ERP Balance', 'ERP Direction', 'Match'];
	const headers = ['#', 'Vendor Name', 'Vendor ID', ...groups.flatMap(g => metrics.map(m => `${g.name} - ${m}`))];
	const round = (n: number) => Math.round((n + Number.EPSILON) * 100) / 100;
	const rows = input.vendors.map((vendor, index) => {
		const byBranch = totals.get(vendor.vendor_id);
		return [index + 1, vendor.vendor_name, vendor.vendor_id, ...groups.flatMap(group => {
			const values = group.id === 'overall' ? [...(byBranch?.values() || [])] : [byBranch?.get(group.id)].filter((v): v is Amounts => !!v);
			const sum = values.reduce((a, b) => ({ bills: a.bills + b.bills, expenses: a.expenses + b.expenses, overdue: a.overdue + b.overdue, erp: a.erp + b.erp, hasErp: a.hasErp || b.hasErp }), { bills: 0, expenses: 0, overdue: 0, erp: 0, hasErp: false });
			const unpaid = sum.bills + sum.expenses;
			return [round(sum.bills), round(sum.expenses), round(unpaid), round(sum.overdue), sum.hasErp ? round(Math.abs(sum.erp)) : '', sum.hasErp ? (sum.erp > 0 ? 'Dr' : sum.erp < 0 ? 'Cr' : 'Nil') : '', sum.hasErp ? (Math.abs(Math.abs(sum.erp) - unpaid) < 1 ? 'Yes' : 'No') : ''];
		})];
	});
	// Keep each category together, with branch breakdowns beneath its own heading.
	const sections = [
		{ title: 'Vendor Details', color: '334155', columns: [0, 1, 2] },
		{ title: 'Bills', color: '2563EB', metrics: [0] },
		{ title: 'Expenses', color: 'D97706', metrics: [1] },
		{ title: 'Totals', color: '059669', metrics: [2, 3] },
		{ title: 'ERP', color: '4F46E5', metrics: [4, 5, 6] }
	].map(section => ({
		title: section.title,
		color: section.color,
		columns: section.columns ?? groups.flatMap((_, groupIndex) =>
			section.metrics!.map(metric => 3 + groupIndex * metrics.length + metric))
	}));
	const columnOrder = sections.flatMap(section => section.columns);
	let startColumn = 0;
	const sectionRanges = sections.map(section => {
		const start = startColumn;
		startColumn += section.columns.length;
		return { title: section.title, color: section.color, start, end: startColumn - 1 };
	});
	return {
		headers: columnOrder.map(column => headers[column]),
		rows: rows.map(row => columnOrder.map(column => row[column])),
		sections: sectionRanges
	};
}
