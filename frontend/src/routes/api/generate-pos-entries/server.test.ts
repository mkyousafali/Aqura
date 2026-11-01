import { describe, expect, it } from 'vitest';
import { POST } from './+server.js';
import { missingNonCashLedgerLinks } from '$lib/utils/posNonCashEntries';
import { buildPosClosingEntries } from '$lib/utils/posClosingEntries';

const generate = (totals: Record<string, unknown>, overrides = {}) => POST({ request: new Request('http://localhost/api/generate-pos-entries', {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({
    posNumber: 3, cashierName: 'Fixture Cashier', shiftDate: '2026-11-01', shiftId: 'fixture-shift',
    cashDiff: 0, cardDiff: 0, totalDiff: 0, totals, ...overrides
  }) }) } as any);

describe('POS non-cash sale MJVs', () => {
  it('produces all three entries locally without depending on the deployed preview API', async () => {
    const totals = { totalCashSales: 1126.45, vouchersTotal: 25, charitySalesTotal: 1000, loyaltyVouchersTotal: 101.45 };
    const local = buildPosClosingEntries({ posNumber: 3, cashierName: 'Fixture Cashier', shiftDate: '2026-11-01', shiftId: 'fixture-shift', cashDiff: 0, cardDiff: 0, totalDiff: 0, totals });
    const { result } = await (await generate(totals)).json();
    expect(local).toEqual(result);
    expect(local.entries.filter((entry: any) => entry.type === 'reclassification')).toHaveLength(3);
  });
  it('debits each category and credits Branch Cash for its exact amount', async () => {
    const response = await generate({ totalCashSales: 1126.45, vouchersTotal: 25, charitySalesTotal: 1000, loyaltyVouchersTotal: 101.45 });
    expect(response.status).toBe(200);
    const { result } = await response.json();
    const transfers = result.entries.filter((entry: any) => entry.type === 'reclassification');
    expect(transfers.map((entry: any) => [entry.debit_account, entry.debit_amount, entry.credit_account, entry.credit_amount])).toEqual([
      ['Purchase Vouchers', 25, 'Cash Account', 25], ['Charity Sales', 1000, 'Cash Account', 1000], ['Loyalty Redemption', 101.45, 'Cash Account', 101.45]
    ]);
    for (const entry of transfers) {
      expect(entry.form_name).toBe('MJV');
      expect(entry.narration).toContain('Fixture Cashier');
      expect(entry.narration).toContain('fixture-shift');
    }
    const cashNet = result.mjv_lines.filter((line: any) => line.ledger_account === 'Cash Account')
      .reduce((sum: number, line: any) => sum + line.debit - line.credit, 0);
    expect(cashNet).toBeCloseTo(0, 2);
    const debit = result.mjv_lines.reduce((sum: number, line: any) => sum + line.debit, 0);
    const credit = result.mjv_lines.reduce((sum: number, line: any) => sum + line.credit, 0);
    expect(debit).toBeCloseTo(credit, 2);
  });
  it('keeps physical cash and excludes zero categories', async () => {
    const { result } = await (await generate({ totalCashSales: 625, vouchersTotal: 25, charitySalesTotal: 100, loyaltyVouchersTotal: 0 })).json();
    expect(result.entries.filter((entry: any) => entry.type === 'reclassification')).toHaveLength(2);
    const cashNet = result.mjv_lines.filter((line: any) => line.ledger_account === 'Cash Account')
      .reduce((sum: number, line: any) => sum + line.debit - line.credit, 0);
    expect(cashNet).toBe(500);
  });
  it('preserves the existing receipt and shortage rules for older payloads', async () => {
    const { result } = await (await generate({ totalCashSales: 500 }, { cashDiff: -10, totalDiff: -10 })).json();
    expect(result.entries).toHaveLength(2);
    expect(result.entries[0].type).toBe('receipt');
    expect(result.entries[1]).toMatchObject({ debit_account: 'Employee Salary Account', debit_amount: 10 });
  });
  it('requires the relevant ledgers and Branch Cash only for nonzero categories', () => {
    expect(missingNonCashLedgerLinks({ vouchersTotal: 25, charitySalesTotal: 0 }, [])).toEqual(['Branch Cash Account', 'Purchase Vouchers']);
    expect(missingNonCashLedgerLinks({ vouchersTotal: 25 }, [
      { account_key: 'branch_cash', ledger_code: 'CS', ledger_name: 'Cash' },
      { account_key: 'purchase_vouchers', ledger_code: 'PV', ledger_name: 'Voucher Ledger' }
    ])).toEqual([]);
    expect(missingNonCashLedgerLinks({}, [])).toEqual([]);
    expect(() => missingNonCashLedgerLinks({ charitySalesTotal: -1 }, [])).toThrow('Invalid');
  });
});
