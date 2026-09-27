import { json } from "@sveltejs/kit";
import { generateOpenAIText } from '$lib/server/openaiText';

// Endpoint for the mobile "Scan Request" flow (Bank Reconciliation card in
// CloseBox.svelte). Takes a photo of a card-terminal (mada) reconciliation
// slip and asks OpenAI to extract exactly: Date, Time, Terminal ID, and
// Statement/Batch match number — nothing else. The mobile UI shows these as
// editable fields; nothing is written to the database here.
//
// Also supports mode: 'amount' — a second, per-payment-method pass (Mada,
// Visa, MasterCard, Google Pay, Other) where the mobile user photographs just
// that network's closing/TOTALS section and only the final amount is
// extracted, to auto-fill that one field.
//
// Uses the shared OpenAI table key and image/PDF helper, like /api/check-original-bill.

export async function POST({ request }) {
  try {
    const body = await request.json();
    const { imageBase64, mimeType, mode } = body;

    if (!imageBase64) {
      return json({ error: "No image provided" }, { status: 400 });
    }

    if (mode === 'amount') {
      return await extractAmount(imageBase64, mimeType);
    }

    const prompt = `You are extracting information from a photo of a card payment terminal (mada/POS) reconciliation/settlement slip. These slips have a well-known layout near the top:

Line 1: Date on the left, Time on the right (e.g. "19/06/2026" ..... "20:17:11").
Line 2: A code starting with "RYDB" on the left (this is NOT the terminal ID — ignore it), and a long numeric code on the right, directly under the Time — THIS long number on the right of line 2 is the Terminal ID.
Line 3: A line like "5411 552142 6.1.79.P635972" — the FIRST short number ("5411") is not needed, the SECOND number (e.g. "552142") is the Statement/Batch match number, and anything after that (e.g. version-looking text like "6.1.79.P635972") is not needed.

Extract exactly these fields:

1. Date — the date printed on line 1 (left side).
2. Date (normalized) — the same date, converted to ISO format YYYY-MM-DD. This business is in Saudi Arabia, so when the printed format is ambiguous (e.g. DD/MM vs MM/DD), assume DD/MM/YYYY.
3. Time — the time printed on line 1 (right side), in 24-hour HH:MM:SS format if seconds are shown, otherwise HH:MM.
4. Terminal ID — the long numeric code on line 2, positioned under the Time (right side). Do NOT use the "RYDB..." code on the left of that same line.
5. Statement/Batch match number — the second number on the "5411 ..." line (the one after "5411"), not the "5411" itself and not any version code that follows it.

If a field cannot be found, return an empty string for that field. Do not guess or invent values.`;

    const rawText = await generateOpenAIText({
      prompt,
      attachments: [{ mimeType: mimeType || 'image/jpeg', data: imageBase64 }],
      temperature: 0, maxTokens: 2000,
      schema: {
        type: 'object',
        additionalProperties: false,
        properties: {
          date: { type: 'string' },
          date_iso: { type: 'string' },
          time: { type: 'string' },
          terminal_id: { type: 'string' },
          statement_match_number: { type: 'string' }
        },
        required: ['date', 'date_iso', 'time', 'terminal_id', 'statement_match_number']
      }
    });

    let extracted;
    try {
      extracted = JSON.parse(rawText);
    } catch (e) {
      console.error('Failed to parse OpenAI JSON response:', rawText);
      throw new Error('AI response was not valid JSON');
    }

    return json({
      success: true,
      date: extracted.date_iso || extracted.date || '',
      time: extracted.time || '',
      terminalId: extracted.terminal_id || '',
      statementMatchNumber: extracted.statement_match_number || ''
    });
  } catch (error) {
    console.error("Error extracting scan request data:", error);
    return json(
      { error: error instanceof Error ? error.message : "Failed to extract scan data" },
      { status: 500 }
    );
  }
}

async function extractAmount(imageBase64, mimeType) {
  try {
    const prompt = `You are extracting a single amount from a photo of a card payment terminal (mada/POS/GCCNET/etc.) closing/settlement slip section (e.g. a "TOTALS" row, or a "P/ON" purchase total row, shown in SAR). Find the final total amount for this payment network on the slip and return just the plain numeric value (e.g. "639.02"), with no currency symbol, no commas, no letters. If several totals are shown, use the one on the "TOTALS" row (or the "P/ON"/purchase row if there is no separate TOTALS row). If it cannot be found, return an empty string.`;

    const rawText = await generateOpenAIText({
      prompt,
      attachments: [{ mimeType: mimeType || 'image/jpeg', data: imageBase64 }],
      temperature: 0, maxTokens: 2000,
      schema: {
        type: 'object',
        additionalProperties: false,
        properties: { amount: { type: 'string' } },
        required: ['amount']
      }
    });

    let extracted;
    try {
      extracted = JSON.parse(rawText);
    } catch (e) {
      console.error('Failed to parse OpenAI JSON response (amount mode):', rawText);
      throw new Error('AI response was not valid JSON');
    }

    return json({ success: true, amount: (extracted.amount || '').replace(/[^0-9.]/g, '') });
  } catch (error) {
    console.error("Error extracting amount:", error);
    return json(
      { error: error instanceof Error ? error.message : "Failed to extract amount" },
      { status: 500 }
    );
  }
}
