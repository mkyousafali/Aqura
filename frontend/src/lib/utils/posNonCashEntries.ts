import { money } from './money';

export const nonCashPostingAccounts = [
  { key: 'purchase_vouchers', label: 'Purchase Vouchers', totalKey: 'vouchersTotal' },
  { key: 'charity_sales', label: 'Charity Sales', totalKey: 'charitySalesTotal' },
  { key: 'loyalty_redemption', label: 'Loyalty Redemption', totalKey: 'loyaltyVouchersTotal' }
] as const;

function amountFor(totals: Record<string, unknown> | undefined, key: string): number {
  const value = Number(totals?.[key] ?? 0);
  if (!Number.isFinite(value) || value < 0) throw new Error(`Invalid ${key}: enter a non-negative amount`);
  return money(value);
}

export function buildNonCashEntries(totals: Record<string, unknown> | undefined, narrate: (text: string) => string) {
  return nonCashPostingAccounts.flatMap(account => {
    const amount = amountFor(totals, account.totalKey);
    if (!amount) return [];
    const description = `${account.label} transferred from branch cash`;
    return [{
      type: 'reclassification', category: account.key, form_name: 'MJV', description,
      narration: narrate(description), debit_account: account.label, debit_amount: amount,
      credit_account: 'Cash Account', credit_amount: amount
    }];
  });
}

export function missingNonCashLedgerLinks(totals: Record<string, unknown>, links: { account_key: string; ledger_code?: string; ledger_name?: string }[]) {
  const required = nonCashPostingAccounts.filter(account => amountFor(totals, account.totalKey) > 0);
  if (!required.length) return [];
  return [{ key: 'branch_cash', label: 'Branch Cash Account' }, ...required]
    .filter(account => !links.some(link => link.account_key === account.key && link.ledger_code && link.ledger_name))
    .map(account => account.label);
}
