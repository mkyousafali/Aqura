import { json } from "@sveltejs/kit";
import { env } from '$env/dynamic/private';

// Endpoint for the mobile "Scan Request" flow (Bank Reconciliation card in
// CloseBox.svelte). Takes a photo of a card-terminal (mada) reconciliation
// slip and asks Gemini to extract exactly: Date, Time, Terminal ID, and
// Statement/Batch match number — nothing else. The mobile UI shows these as
// editable fields; nothing is written to the database here.
//
// Also supports mode: 'amount' — a second, per-payment-method pass (Mada,
// Visa, MasterCard, Google Pay, Other) where the mobile user photographs just
// that network's closing/TOTALS section and only the final amount is
// extracted, to auto-fill that one field.
//
// Reuses the same system_api_keys ('google_gemini') lookup and inlineData
// image request shape as /api/check-original-bill.

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

export async function POST({ request }) {
  try {
    const GEMINI_KEY = await getGeminiKey();
    if (!GEMINI_KEY) {
      return json({ error: "Google AI API key not configured. Set it in API Keys Manager." }, { status: 500 });
    }

    const body = await request.json();
    const { imageBase64, mimeType, mode } = body;

    if (!imageBase64) {
      return json({ error: "No image provided" }, { status: 400 });
    }

    if (mode === 'amount') {
      return await extractAmount(GEMINI_KEY, imageBase64, mimeType);
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

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            role: 'user',
            parts: [
              { text: prompt },
              { inlineData: { mimeType: mimeType || 'image/jpeg', data: imageBase64 } }
            ]
          }],
          generationConfig: {
            temperature: 0,
            maxOutputTokens: 500,
            thinkingConfig: { thinkingBudget: 0 },
            responseMimeType: 'application/json',
            responseSchema: {
              type: 'OBJECT',
              properties: {
                date: { type: 'STRING' },
                date_iso: { type: 'STRING' },
                time: { type: 'STRING' },
                terminal_id: { type: 'STRING' },
                statement_match_number: { type: 'STRING' }
              },
              required: ['date', 'date_iso', 'time', 'terminal_id', 'statement_match_number']
            }
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

    if (!rawText.trim()) {
      console.error('Empty Gemini response. finishReason:', candidate?.finishReason);
      throw new Error(`AI returned an empty response (finishReason: ${candidate?.finishReason || 'unknown'})`);
    }

    let extracted;
    try {
      extracted = JSON.parse(rawText);
    } catch (e) {
      console.error('Failed to parse Gemini JSON response:', rawText);
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

async function extractAmount(GEMINI_KEY, imageBase64, mimeType) {
  try {
    const prompt = `You are extracting a single amount from a photo of a card payment terminal (mada/POS/GCCNET/etc.) closing/settlement slip section (e.g. a "TOTALS" row, or a "P/ON" purchase total row, shown in SAR). Find the final total amount for this payment network on the slip and return just the plain numeric value (e.g. "639.02"), with no currency symbol, no commas, no letters. If several totals are shown, use the one on the "TOTALS" row (or the "P/ON"/purchase row if there is no separate TOTALS row). If it cannot be found, return an empty string.`;

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            role: 'user',
            parts: [
              { text: prompt },
              { inlineData: { mimeType: mimeType || 'image/jpeg', data: imageBase64 } }
            ]
          }],
          generationConfig: {
            temperature: 0,
            maxOutputTokens: 200,
            thinkingConfig: { thinkingBudget: 0 },
            responseMimeType: 'application/json',
            responseSchema: {
              type: 'OBJECT',
              properties: { amount: { type: 'STRING' } },
              required: ['amount']
            }
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

    if (!rawText.trim()) {
      console.error('Empty Gemini response (amount mode). finishReason:', candidate?.finishReason);
      throw new Error(`AI returned an empty response (finishReason: ${candidate?.finishReason || 'unknown'})`);
    }

    let extracted;
    try {
      extracted = JSON.parse(rawText);
    } catch (e) {
      console.error('Failed to parse Gemini JSON response (amount mode):', rawText);
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
