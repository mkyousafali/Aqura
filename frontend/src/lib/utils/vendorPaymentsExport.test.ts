import { describe, expect, it } from 'vitest';
import { buildVendorPaymentsExport } from './vendorPaymentsExport';

const input = {
	vendors: [{ vendor_id: '001', vendor_name: 'Vendor مورد' }],
	branches: [{ id: 1, name_en: 'North' }, { id: 2, name_en: 'South' }],
	selectedBranchId: '',
	bills: [{ vendor_id: '001', branch_id: 1, final_bill_amount: 100 }, { vendor_id: '001', branch_id: '2', final_bill_amount: 200 }],
	expenses: [{ vendor_id: '001', branch_id: 2, amount: 25 }],
	overdueBills: [{ vendor_id: '001', branch_id: 1, final_bill_amount: 100 }],
	overdueExpenses: [],
	erp: [{ branch_id: 1, rows: [{ PartyCode: '001', TotalDebit: 0, TotalCredit: 100 }] }, { branch_id: 2, rows: [{ PartyCode: '001', TotalDebit: 25, TotalCredit: 0 }] }]
};

describe('vendor payments export', () => {
	it('includes branch breakdowns and overall totals, netting ERP directions', () => {
		const { headers, rows } = buildVendorPaymentsExport(input);
		const row = Object.fromEntries(headers.map((h, i) => [h, rows[0][i]]));
		expect(row['Vendor ID']).toBe('001');
		expect(row['North (1) - Total Unpaid']).toBe(100);
		expect(row['South (2) - Total Unpaid']).toBe(225);
		expect(row['Overall Total - Total Unpaid']).toBe(325);
		expect(row['Overall Total - Total Overdue']).toBe(100);
		expect(row['Overall Total - ERP Balance']).toBe(75);
		expect(row['Overall Total - ERP Direction']).toBe('Cr');
	});
	it('exports only the selected branch amounts and columns', () => {
		const { headers, rows } = buildVendorPaymentsExport({ ...input, selectedBranchId: '2' });
		expect(headers.some(h => /North|Overall/.test(h))).toBe(false);
		expect(rows[0].slice(3, 9)).toEqual([200, 25, 225, 0, 25, 'Dr']);
	});
	it('keeps unassigned amounts in the all-branch breakdown and exports every supplied vendor', () => {
		const result = buildVendorPaymentsExport({ ...input, vendors: Array.from({ length: 60 }, (_, i) => ({ vendor_id: String(i), vendor_name: `Vendor ${i}` })), expenses: [{ vendor_id: '0', branch_id: null, amount: 10 }] });
		expect(result.rows).toHaveLength(60);
		expect(result.rows[0][result.headers.indexOf('Unassigned - Total Unpaid')]).toBe(10);
		expect(result.rows[0][result.headers.indexOf('Overall Total - Total Unpaid')]).toBe(10);
	});
});
