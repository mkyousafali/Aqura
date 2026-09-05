import { json } from "@sveltejs/kit";

// Entry to Pass generation for a POS box closing (cash/bank reconciliation).
//
// This used to ask Gemini to both do the arithmetic AND pick the accounts for every entry, per a
// system-prompt-described deterministic policy. The policy IS fully deterministic (every account,
// direction and amount follows mechanically from cashDiff/cardDiff/totalDiff) — there is nothing
// here that actually needs a language model, and leaving it to one meant an occasional generation
// could just ignore the stated rule (observed: a net-excess adjustment posted through "POS Bank"
// instead of "POS Excess", silently losing the excess instead of recording it). So this now computes
// every entry directly in code — same policy, but it can't be gotten wrong on a given run.

function round2(n) {
  const v = Number(n);
  if (!Number.isFinite(v)) return 0;
  return Math.round((v + Number.EPSILON) * 100) / 100;
}

function buildEntries({ posNumber, cashierName, shiftDate, shiftId, cashDiff, cardDiff, totalDiff, totals }) {
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
    form_name: 'CP',
    description: receiptDescription,
    narration: narrate(receiptDescription),
    debit_account: 'Cash Account',
    debit_amount: totalCashSales,
    credit_account: posCashAccount,
    credit_amount: totalCashSales
  });

  // STEP 1 — Transfer: fold POS Bank's entire remaining diff into POS Cash, one JV, whichever
  // direction zeroes POS Bank (skip if the card diff is negligible).
  const cd = round2(cardDiff);
  let bankInvolved = false;
  if (Math.abs(cd) > 0.01) {
    bankInvolved = true;
    if (cd < 0) {
      // Bank short — pull the shortfall out of POS Cash into POS Bank.
      const description = 'Transfer card shortfall to POS Cash';
      entries.push({
        type: 'transfer',
        form_name: 'JV',
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
        form_name: 'JV',
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
        form_name: 'JV',
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
          form_name: 'JV',
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
          form_name: 'JV',
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

  return {
    diagnosis,
    entries,
    final_balances: { pos_cash: 0, pos_bank: 0 },
    employee_charged: employeeCharged,
    employee_charge_amount: round2(employeeChargeAmount),
    notes
  };
}

export async function POST({ request }) {
  try {
    const body = await request.json();
    const {
      posNumber, cashierName, shiftDate, shiftId,
      cashDiff, cardDiff, totalDiff, totals
    } = body || {};

    if (
      typeof cashDiff !== 'number' || typeof cardDiff !== 'number' || typeof totalDiff !== 'number'
    ) {
      return json({ error: "cashDiff, cardDiff and totalDiff (numbers) are required" }, { status: 400 });
    }

    const result = buildEntries({ posNumber, cashierName, shiftDate, shiftId, cashDiff, cardDiff, totalDiff, totals });
    return json({ success: true, result });
  } catch (error) {
    console.error("Error generating POS entries:", error);
    return json(
      { error: error instanceof Error ? error.message : "Failed to generate entries" },
      { status: 500 }
    );
  }
}
