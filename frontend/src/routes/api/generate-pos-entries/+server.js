import { json } from "@sveltejs/kit";
import { buildPosClosingEntries } from '$lib/utils/posClosingEntries';

// Entry to Pass generation for a POS box closing (cash/bank reconciliation).
//
// This used to ask Gemini to both do the arithmetic AND pick the accounts for every entry, per a
// system-prompt-described deterministic policy. The policy IS fully deterministic (every account,
// direction and amount follows mechanically from cashDiff/cardDiff/totalDiff) — there is nothing
// here that actually needs a language model, and leaving it to one meant an occasional generation
// could just ignore the stated rule (observed: a net-excess adjustment posted through "POS Bank"
// instead of "POS Excess", silently losing the excess instead of recording it). So this now computes
// every entry directly in code — same policy, but it can't be gotten wrong on a given run.


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

    const result = buildPosClosingEntries({ posNumber, cashierName, shiftDate, shiftId, cashDiff, cardDiff, totalDiff, totals });
    return json({ success: true, result });
  } catch (error) {
    console.error("Error generating POS entries:", error);
    return json(
      { error: error instanceof Error ? error.message : "Failed to generate entries" },
      { status: 500 }
    );
  }
}
