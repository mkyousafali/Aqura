import { buildNonCashEntries } from './posNonCashEntries';

// Shared deterministic calculation for the desktop preview and API.
function round2(n) {
  const v = Number(n);
  if (!Number.isFinite(v)) return 0;
  return Math.round((v + Number.EPSILON) * 100) / 100;
}

export function buildPosClosingEntries({ posNumber, cashierName, shiftDate, shiftId, cashDiff, cardDiff, totalDiff, totals }) {
  const posLabel = (posNumber === 0 || posNumber) ? posNumber : '';
  const posCashAccount = `POS ${posLabel} (Cash)`.replace(/\s+/g, ' ').trim();
  const cashierLabel = cashierName || 'N/A';
  const shiftLabel = shiftDate || 'N/A';
  const shiftIdSuffix = shiftId ? ` - Shift ID: ${shiftId}` : '';
  const narrate = (desc) => `${desc} - Cashier: ${cashierLabel} - Shift: ${shiftLabel}${shiftIdSuffix}`;

  const entries = [];

  // STEP 0 — Cash Receipt (always, regardless of diffs): moves the actual counted cash out of the
  // POS register into the branch cash account.
  const totalCashSales = round2(totals?.totalCashSales ?? 0);
  const receiptDescription = `Cash collected from POS ${posLabel}`;
  entries.push({
    type: 'receipt',
    form_name: 'MJV',
    description: receiptDescription,
    narration: narrate(receiptDescription),
    debit_account: 'Cash Account',
    debit_amount: totalCashSales,
    credit_account: posCashAccount,
    credit_amount: totalCashSales
  });

  // The receipt includes voucher/charity/loyalty sales. Move those portions out
  // of Branch Cash into their linked ledgers; do not treat them as physical cash.
  entries.push(...buildNonCashEntries(totals, narrate));

  // STEP 1 — Transfer: fold POS Bank's entire remaining diff into POS Cash, one JV, whichever
  // direction zeroes POS Bank (skip if the card diff is negligible).
  const cd = round2(cardDiff);
  let bankInvolved = false;
  // cd is already rounded to two decimals. Every non-zero halalah must be
  // transferred; otherwise an exact 0.01 card difference is still included in
  // totalDiff below but POS Bank is never cleared.
  if (cd !== 0) {
    bankInvolved = true;
    if (cd < 0) {
      // Bank short — pull the shortfall out of POS Cash into POS Bank.
      const description = 'Transfer card shortfall to POS Cash';
      entries.push({
        type: 'transfer',
        form_name: 'MJV',
        description,
        narration: narrate(description),
        debit_account: posCashAccount,
        debit_amount: Math.abs(cd),
        credit_account: 'POS Bank',
        credit_amount: Math.abs(cd)
      });
    } else {
      // Bank excess — push the excess out of POS Cash into POS Bank.
      const description = 'Transfer card excess to POS Bank';
      entries.push({
        type: 'transfer',
        form_name: 'MJV',
        description,
        narration: narrate(description),
        debit_account: 'POS Bank',
        debit_amount: Math.abs(cd),
        credit_account: posCashAccount,
        credit_amount: Math.abs(cd)
      });
    }
  }

  // STEP 2 — Single net adjustment against POS Cash only, driven by the combined totalDiff.
  const td = round2(totalDiff);
  let employeeCharged = false;
  let employeeChargeAmount = 0;
  if (Math.abs(td) > 0.01) {
    if (td > 0) {
      const description = 'Adjust for net excess';
      entries.push({
        type: 'adjustment',
        form_name: 'MJV',
        description,
        narration: narrate(description),
        debit_account: posCashAccount,
        debit_amount: Math.abs(td),
        credit_account: 'POS Excess',
        credit_amount: Math.abs(td)
      });
    } else {
      const amount = Math.abs(td);
      if (amount > 5) {
        employeeCharged = true;
        employeeChargeAmount = amount;
        const description = "Deduct shortage from cashier's salary";
        entries.push({
          type: 'adjustment',
          form_name: 'MJV',
          description,
          narration: narrate(description),
          debit_account: 'Employee Salary Account',
          debit_amount: amount,
          credit_account: posCashAccount,
          credit_amount: amount
        });
      } else {
        const description = 'Adjust for net shortage';
        entries.push({
          type: 'adjustment',
          form_name: 'MJV',
          description,
          narration: narrate(description),
          debit_account: 'POS Short',
          debit_amount: amount,
          credit_account: posCashAccount,
          credit_amount: amount
        });
      }
    }
  }

  const diagnosis = Math.abs(td) <= 0.01 ? 'balanced' : (td > 0 ? 'net_excess' : 'net_short');

  // "POS Bank" is a suspense/clearing account — it's only actually reconciled to zero once the
  // accountant posts a separate real entry transferring the settled amount from "POS Bank" to the
  // real Bank Account, matched against the original bank statement. That step is outside this
  // close-out, so say so whenever a transfer touched POS Bank.
  const notes = bankInvolved
    ? 'POS Bank is a suspense/clearing account. It will only be reconciled to zero once the accountant posts a separate real entry transferring the settled amount from "POS Bank" to the real Bank Account, matched against the original bank statement. This "Entry to Pass" close-out does not perform that final bank reconciliation.'
    : 'No card-side transfer was needed — POS Bank was already balanced for this shift.';

  const mjvLines = entries.flatMap((entry) => [
    {
      ledger_account: entry.debit_account,
      debit: entry.debit_amount,
      credit: 0,
      narration: entry.narration
    },
    {
      ledger_account: entry.credit_account,
      debit: 0,
      credit: entry.credit_amount,
      narration: entry.narration
    }
  ]);

  return {
    diagnosis,
    form_name: 'MJV',
    entries,
    mjv_lines: mjvLines,
    final_balances: { pos_cash: 0, pos_bank: 0 },
    employee_charged: employeeCharged,
    employee_charge_amount: round2(employeeChargeAmount),
    notes
  };
}
