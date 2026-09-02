import { json } from "@sveltejs/kit";
import { env } from '$env/dynamic/private';

// Endpoint for the "Check" button on Receiving Records' Original Bill column.
// Sends the bill document (PDF or image) to Gemini, which extracts Vendor Name,
// Vendor VAT Number, Bill Amount including VAT, and Bill Date, and also judges
// whether each one matches the corresponding value already on file (passed in
// by the caller) — the AI does the matching itself rather than a naive
// string/number compare, since vendor names in particular can legitimately be
// worded differently between the ERP/system record and what's printed on the
// bill (legal suffix, abbreviation, transliteration, etc.) while still
// referring to the same vendor.
//
// Vendor verification rule (computed here, not left to the AI's own combined
// judgment, so it's applied consistently): the VAT number is the authoritative
// identifier —
//   - VAT matches AND name matches            -> vendor matched, no flag.
//   - VAT matches BUT name does not match      -> vendor matched, but the name
//                                                 mismatch is flagged for review.
//   - VAT does not match                       -> vendor not matched, regardless
//                                                 of the name.
//
// Bill Date match is likewise computed here, not left to the AI's own "is this
// the same date" judgment — that turned out unreliable in practice (the model
// would sometimes say "2026-08-22" vs "22/08/2026" don't match, despite being
// the same calendar date, because it's a probabilistic judgment call, not a
// deterministic comparison). Instead the AI's only job for the date is
// extraction: read the printed date AND normalize it to ISO (YYYY-MM-DD); the
// actual equality check against the system's date is then a plain string
// comparison in code, which can't misjudge two equal ISO strings as different.
//
// Nothing is written back to the database here — this only returns the AI's
// read of the document plus its match verdicts for display.

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

// The storage response's content-type is the most reliable source; the URL extension
// is only a fallback for buckets that don't set it correctly.
function guessMimeType(url, contentType) {
  const ct = (contentType || '').split(';')[0].trim().toLowerCase();
  if (ct && ct !== 'application/octet-stream' && ct !== 'binary/octet-stream') return ct;
  const lower = (url || '').toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  return 'application/pdf';
}

export async function POST({ request }) {
  try {
    console.log("Check Original Bill API accessed...");

    const GEMINI_KEY = await getGeminiKey();
    if (!GEMINI_KEY) {
      return json(
        { error: "Google AI API key not configured. Set it in API Keys Manager." },
        { status: 500 }
      );
    }

    const body = await request.json();
    const { url, localVendorName, localVendorVat, localBillAmount, localBillDate } = body;

    if (!url) {
      return json({ error: "No document URL provided" }, { status: 400 });
    }

    console.log("Fetching original bill document:", url);
    const fileRes = await fetch(url);
    if (!fileRes.ok) {
      throw new Error(`Failed to download the original bill document (HTTP ${fileRes.status})`);
    }
    const contentType = fileRes.headers.get('content-type') || '';
    const mimeType = guessMimeType(url, contentType);
    const buffer = Buffer.from(await fileRes.arrayBuffer());
    const base64Data = buffer.toString('base64');

    const hasLocalValues = localVendorName != null || localVendorVat != null || localBillAmount != null || localBillDate != null;

    const prompt = `You are extracting information from a vendor bill/invoice document image or PDF. Read the document carefully and extract exactly these fields, as printed on the document:

1. Vendor Name — the name of the supplier/vendor who issued the bill (not the buyer/receiver).
2. Vendor VAT Number — the supplier/vendor's VAT registration number / Tax Registration Number (TRN) as printed on the bill (not the buyer's). Extract just the number/code itself, without labels like "VAT No:" or "TRN:".
3. Bill Amount including VAT — the final grand total amount payable, including VAT/tax, exactly as shown on the document. Keep the currency symbol/code if one is shown.
4. Bill Date (as printed) — the invoice/bill date exactly as printed on the document, in its original format.
5. Bill Date (normalized) — the same date, converted to ISO format YYYY-MM-DD. This business is in Saudi Arabia, so when the printed format is ambiguous (e.g. a two-digit-slash date like 05/08/2026 that could be DD/MM or MM/DD), assume DD/MM/YYYY. If the day component is clearly greater than 12, that confirms DD/MM/YYYY regardless. If the date cannot be confidently determined, return an empty string.

Do not calculate, convert, translate, or guess for fields 1-4 — extract them exactly as they appear on the document. If a field cannot be found, return an empty string for that field.
${hasLocalValues ? `
You are also given the values already on file in our system for this same bill:
- System Vendor Name: ${JSON.stringify(localVendorName ?? '')}
- System Vendor VAT Number: ${JSON.stringify(localVendorVat ?? '')}
- System Bill Amount (incl. VAT): ${JSON.stringify(localBillAmount ?? '')}

For the vendor name, VAT number, and amount, judge for yourself whether the value on the document matches the system value, and return that as a boolean. Use real-world judgment, not exact string equality (the bill date is compared separately, deterministically — don't judge it yourself):
- Vendor Name: company names are often worded differently between systems and printed bills (legal suffixes like LLC/Co./W.L.L./Trading Co., abbreviations, transliteration, minor punctuation, "and" vs "&", extra/missing words like "The"). Mark it as matching (true) if they clearly refer to the same business, even if not identical text. Only mark it false if they appear to be genuinely different vendors.
- Vendor VAT Number: unlike the name, this is an exact identifier — mark it as matching (true) only if the digits/code are the same once spaces, dashes, and label prefixes are ignored. Any actual digit difference means false.
- Bill Amount: mark it as matching (true) if the numeric value is the same once currency symbols/formatting/thousands separators are ignored, allowing a negligible rounding difference (under 0.05). Otherwise false.` : ''}`;

    console.log("Sending original bill document to Gemini...");

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
              { inlineData: { mimeType, data: base64Data } }
            ]
          }],
          generationConfig: {
            temperature: 0,
            maxOutputTokens: 2000,
            // Gemini 2.5 Flash "thinks" before answering by default, and that
            // thinking eats into maxOutputTokens — with a small budget it can
            // burn the whole thing reasoning about the match judgment and
            // leave nothing for the actual JSON, which then fails to parse.
            // This is a plain extraction+judgment task, no need for it.
            thinkingConfig: { thinkingBudget: 0 },
            responseMimeType: 'application/json',
            responseSchema: {
              type: 'OBJECT',
              properties: {
                vendor_name: { type: 'STRING' },
                vendor_vat_number: { type: 'STRING' },
                bill_amount_including_vat: { type: 'STRING' },
                bill_date: { type: 'STRING' },
                bill_date_iso: { type: 'STRING' },
                ...(hasLocalValues ? {
                  vendor_name_matches: { type: 'BOOLEAN' },
                  vendor_vat_matches: { type: 'BOOLEAN' },
                  bill_amount_matches: { type: 'BOOLEAN' }
                } : {})
              },
              required: hasLocalValues
                ? ['vendor_name', 'vendor_vat_number', 'bill_amount_including_vat', 'bill_date', 'bill_date_iso', 'vendor_name_matches', 'vendor_vat_matches', 'bill_amount_matches']
                : ['vendor_name', 'vendor_vat_number', 'bill_amount_including_vat', 'bill_date', 'bill_date_iso']
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
      console.error('Empty Gemini response. finishReason:', candidate?.finishReason, 'full response:', JSON.stringify(geminiData));
      throw new Error(`AI returned an empty response (finishReason: ${candidate?.finishReason || 'unknown'})`);
    }

    let extracted;
    try {
      extracted = JSON.parse(rawText);
    } catch (e) {
      console.error('Failed to parse Gemini JSON response:', rawText);
      throw new Error('AI response was not valid JSON');
    }

    console.log("Extracted from original bill:", extracted);

    const vendorNameMatches = typeof extracted.vendor_name_matches === 'boolean' ? extracted.vendor_name_matches : null;
    const vendorVatMatches = typeof extracted.vendor_vat_matches === 'boolean' ? extracted.vendor_vat_matches : null;
    // VAT number is the authoritative vendor identifier: VAT match alone is enough to
    // consider the vendor matched (name wording can legitimately differ); VAT mismatch
    // means the vendor is not matched even if the name happens to look similar.
    const vendorMatches = vendorVatMatches === null ? vendorNameMatches : vendorVatMatches;

    // Deterministic date comparison — see the comment at the top of this file. localBillDate
    // is expected as an ISO YYYY-MM-DD string (that's what receiving_records.bill_date already
    // is); a plain string comparison between two normalized ISO dates can't misjudge equal
    // dates as different the way asking the AI to "judge" it could.
    const billDateIso = (extracted.bill_date_iso || '').trim();
    const billDateMatches = (billDateIso && localBillDate)
      ? billDateIso === String(localBillDate).trim()
      : null;

    return json({
      success: true,
      vendorName: extracted.vendor_name || '',
      vendorVatNumber: extracted.vendor_vat_number || '',
      billAmountIncludingVat: extracted.bill_amount_including_vat || '',
      billDate: extracted.bill_date || '',
      billDateIso,
      vendorNameMatches,
      vendorVatMatches,
      vendorMatches,
      billAmountMatches: typeof extracted.bill_amount_matches === 'boolean' ? extracted.bill_amount_matches : null,
      billDateMatches
    });

  } catch (error) {
    console.error("Error checking original bill:", error);
    return json(
      {
        error: error instanceof Error ? error.message : "Failed to check original bill",
      },
      { status: 500 }
    );
  }
}
