import { json } from "@sveltejs/kit";
import { env } from '$env/dynamic/private';

// Same pattern as /api/transform-text, /api/generate-warning, etc.
// (reused verbatim — this is how the Live Chat window's Gemini calls fetch their key)
async function getGeminiKey() {
  try {
    const supabaseUrl = env.VITE_SUPABASE_URL || '';
    const supabaseKey = env.VITE_SUPABASE_ANON_KEY || '';
    if (!supabaseUrl || !supabaseKey) {
      console.error('Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY in env');
      return null;
    }
    const res = await fetch(
      `${supabaseUrl}/rest/v1/system_api_keys?service_name=eq.google_gemini&is_active=eq.true&select=api_key&limit=1`,
      { headers: { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` } }
    );
    const rows = await res.json();
    return rows?.[0]?.api_key || null;
  } catch (e) {
    console.error('Failed to fetch Gemini key:', e);
    return null;
  }
}

const SYSTEM_PROMPT = `You are a senior retail accountant generating the closing "Entry to Pass" journal entries for a POS box closing (cash/bank reconciliation).

ACCOUNTS AVAILABLE:
- "Cash Account" — the branch's actual cash-in-hand/safe account
- "POS {n} (Cash)" — the physical cash suspense ledger for this POS number
- "POS Bank" — the card/bank settlement suspense ledger
- "POS Excess" — contra account for a genuine, unexplained excess
- "POS Short" — contra account for a small genuine shortage (<= 5 SAR)
- "Employee Salary Account" — contra account for a shortage greater than 5 SAR (deducted from the cashier's salary)

BACKGROUND (already posted elsewhere — do NOT generate these entries, just for context):
- A Sales entry already debited "POS {n} (Cash)" for (systemCashSales - systemReturn), and debited "POS Bank" for systemCardSales, both credited to Sales.
- For the purpose of THIS calculation only, assume "POS Bank" already carries a remaining balance of -cardDiff (i.e. the card settlement figure bankTotal has been applied) — so do NOT generate a "Bank Receipt" entry here, it is not part of this close-out.
- IMPORTANT — this is an assumption for the math only, not a real-world fact: "POS Bank" is a suspense/clearing account. It is only ACTUALLY reconciled to zero once the accountant posts a separate real entry transferring the settled amount from "POS Bank" to the real Bank Account, matched against the ORIGINAL BANK STATEMENT. That step happens outside this Entry to Pass close-out and is not something you generate. Your "notes" field MUST state this caveat explicitly whenever POS Bank is involved (i.e. do not claim POS Bank has actually been settled/reconciled — say it will only be reconciled once that bank-statement-matched transfer entry is passed).

VOUCHER TYPES — every entry you generate must carry the correct "form_name" (the voucher type code used in the ERP):
- Cash Receipt → "CP"
- Transfer (contra between POS Cash and POS Bank) → "JV"
- Adjustment (excess/short/salary posting) → "JV"

NARRATION — every entry's "narration" must explicitly mention the cashier name, the POS number, the shift date, and the shift ID given to you in the input (e.g. "Cash collected from POS 4 - Cashier: <name> - Shift: <date> - Shift ID: <id>"). Omit the "Shift ID" part only if none was given.

INPUTS YOU RECEIVE:
- totalCashSales — the actual physical cash counted/collected at closing
- bankTotal — the actual card/bank settlement total at closing
- cashDiff = totalCashSales - (systemCashSales - systemReturn)   [+ = cash excess, - = cash shortage]
- cardDiff = bankTotal - systemCardSales                          [+ = bank excess, - = bank shortage]
- totalDiff = cashDiff + cardDiff
- cashierName, posNumber, shiftDate, shiftId — for the narration text

All three diffs were recomputed from the raw closing counts / bank fields / system sales fields — treat them as ground truth, not as unverified stored numbers.

ENTRIES YOU MUST GENERATE (in this order):

STEP 0 — Receipt entry (always include, every time, regardless of diffs):
  Cash Receipt (form_name "CP"): Dr "Cash Account" / Cr "POS {n} (Cash)", amount = totalCashSales — moves the actual counted cash out of the POS register into the branch cash account.
  After this entry, "POS {n} (Cash)" carries a remaining balance of -cashDiff (a debit balance of |cashDiff| when short, a credit balance of |cashDiff| when excess). "POS Bank" already carries a remaining balance of -cardDiff per the BACKGROUND note above — no entry needed to produce that.

STEP 1 — Transfer (ALWAYS do this, one single rule, no case-splitting on signs):
   Every shortage or excess — whether it originated on the cash side or the card side — is ultimately the SAME cashier's accountability, so ALWAYS fold POS Bank's entire remaining diff into POS Cash first, via ONE transfer entry (form_name "JV") moving |cardDiff| between "POS {n} (Cash)" and "POS Bank" in whichever direction fully zeroes POS Bank's own remaining balance (Dr the account that needs to increase, Cr the account that needs to decrease — i.e. if cardDiff is negative/short, Dr "POS {n} (Cash)" / Cr "POS Bank"; if cardDiff is positive/excess, Dr "POS Bank" / Cr "POS {n} (Cash)").
   - Skip this entry only if |cardDiff| <= 0.01.
   - After this entry, "POS Bank" is fully zeroed, and "POS {n} (Cash)" now carries the ENTIRE combined remaining balance of -totalDiff (where totalDiff = cashDiff + cardDiff).

STEP 2 — Single net adjustment (ALWAYS against "POS {n} (Cash)" only, using totalDiff — never split into a separate Cash-only-diff entry and a separate Bank-only-diff entry):
   - totalDiff > 0 (net excess): Dr "POS {n} (Cash)" / Cr "POS Excess", amount = |totalDiff|
   - totalDiff < 0 (net short): amount = |totalDiff|; if amount > 5 → Dr "Employee Salary Account" / Cr "POS {n} (Cash)", else → Dr "POS Short" / Cr "POS {n} (Cash)"
   - totalDiff == 0: no adjustment entry needed
   Because this is now a SINGLE entry driven by the combined totalDiff, the >5 threshold is automatically applied to the true combined variance — there is no way for a shortage to be split across two ledgers to dodge employee accountability.
   - Example: cashDiff = -44.25, cardDiff = -3.93 → Bank is short, so Step 1 is Dr "POS {n} (Cash)" 3.93 / Cr "POS Bank" 3.93 (zeroes Bank). Then totalDiff = -48.18, |48.18| > 5, so Step 2 is ONE entry: Dr "Employee Salary Account" 48.18 / Cr "POS {n} (Cash)" 48.18.

GOAL: after Step 0 (receipt) + Step 1 (transfer) + Step 2 (single net adjustment) are posted, "POS {n} (Cash)" and "POS Bank" must both net to exactly zero UNDER THE ASSUMPTION above that POS Bank's card settlement has already applied. Verify this arithmetic yourself before answering. Remember: real-world POS Bank only actually reaches zero once its own transfer-to-Bank-Account entry is posted against the real bank statement — say so in "notes".

"employee_charged" is true only when Step 2's entry debits "Employee Salary Account", and "employee_charge_amount" is that single entry's amount (= |totalDiff|).

Respond with ONLY a JSON object (no markdown fences, no prose) matching this exact shape:
{
  "diagnosis": "net_short" | "net_excess" | "balanced",
  "entries": [
    { "type": "receipt" | "transfer" | "adjustment", "form_name": "CP" | "JV", "description": string, "narration": string, "debit_account": string, "debit_amount": number, "credit_account": string, "credit_amount": number }
  ],
  "final_balances": { "pos_cash": number, "pos_bank": number },
  "employee_charged": boolean,
  "employee_charge_amount": number,
  "notes": string
}`;

export async function POST({ request }) {
  try {
    const GEMINI_KEY = await getGeminiKey();
    if (!GEMINI_KEY) {
      return json(
        { error: "Google AI API key not configured. Set it in API Keys Manager." },
        { status: 500 }
      );
    }

    const body = await request.json();
    const {
      posNumber, branchName, cashierName, boxNumber, shiftDate, shiftId,
      cashDiff, cardDiff, totalDiff,
      totals, bank, system, erp
    } = body || {};

    if (
      typeof cashDiff !== 'number' || typeof cardDiff !== 'number' || typeof totalDiff !== 'number'
    ) {
      return json({ error: "cashDiff, cardDiff and totalDiff (numbers) are required" }, { status: 400 });
    }

    const userPrompt = `POS number: ${posNumber ?? 'N/A'}
Branch: ${branchName ?? 'N/A'}
Cashier: ${cashierName ?? 'N/A'}
Box number: ${boxNumber ?? 'N/A'}
Shift date: ${shiftDate ?? 'N/A'}
Shift ID: ${shiftId ?? 'N/A'}

Step 0 receipt amount (use this exact amount for the mandatory Cash Receipt entry):
- totalCashSales = ${totals?.totalCashSales ?? 'N/A'}
- bankTotal (context only — no manual Bank Receipt entry, see BACKGROUND) = ${bank?.total ?? 'N/A'}

Recomputed differences (from raw fields):
- cashDiff = ${cashDiff}
- cardDiff = ${cardDiff}
- totalDiff = ${totalDiff}

Supporting raw figures (context only, already folded into the diffs above):
- totals: ${JSON.stringify(totals ?? {})}
- bank: ${JSON.stringify(bank ?? {})}
- system: ${JSON.stringify(system ?? {})}
- erp_closing_details (source-of-truth ERP check, for your notes only — does not change the entries): ${JSON.stringify(erp ?? {})}

Generate the correct Entry to Pass journal entries per the policy, and verify POS Cash and POS Bank both end at zero.`;

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
          contents: [{ role: 'user', parts: [{ text: userPrompt }] }],
          generationConfig: {
            temperature: 0.1,
            maxOutputTokens: 4000,
            responseMimeType: 'application/json',
            // gemini-2.5-flash "thinks" by default, and those thinking tokens count against
            // maxOutputTokens — without disabling it, the budget can be consumed before any
            // visible JSON is produced, leaving an empty/truncated response. Disable it here
            // since this is a deterministic, low-temperature structured-output task.
            thinkingConfig: { thinkingBudget: 0 }
          }
        })
      }
    );

    if (!geminiRes.ok) {
      const errText = await geminiRes.text();
      throw new Error(`Gemini API error ${geminiRes.status}: ${errText}`);
    }

    const geminiData = await geminiRes.json();
    const candidate = geminiData.candidates?.[0];
    const rawText = candidate?.content?.parts?.[0]?.text || '';
    const finishReason = candidate?.finishReason;

    if (!rawText) {
      console.error('Empty Gemini response. finishReason:', finishReason, 'full response:', JSON.stringify(geminiData));
      return json(
        { error: `Gemini returned no content (finishReason: ${finishReason || 'unknown'})`, raw: geminiData },
        { status: 502 }
      );
    }

    let parsed;
    try {
      parsed = JSON.parse(rawText);
    } catch (e) {
      console.error('Failed to parse Gemini JSON output. finishReason:', finishReason, 'raw text:', rawText);
      return json({ error: `Gemini returned non-JSON output (finishReason: ${finishReason || 'unknown'})`, raw: rawText }, { status: 502 });
    }

    return json({ success: true, result: parsed });
  } catch (error) {
    console.error("Error generating POS entries:", error);
    return json(
      { error: error instanceof Error ? error.message : "Failed to generate entries" },
      { status: 500 }
    );
  }
}
