#!/usr/bin/env node
/**
 * One-time (test-batch capable) backfill: runs the AI "Check" on the Original Bill document
 * (Gemini extraction + match judgment) for receiving_records rows that have a bill uploaded but
 * no original_bill_check_result yet, and persists the verdict — same shape/logic as
 * /api/check-original-bill and persistBillCheckResult() in ReceivingRecords.svelte.
 *
 * Safe to re-run: only picks rows where original_bill_check_result IS NULL, so already-checked
 * rows (including ones checked interactively via the Check button) are never re-spent on.
 *
 * Usage:
 *   node scripts/backfill-original-bill-check-results.js                 # all eligible rows
 *   node scripts/backfill-original-bill-check-results.js --limit=5       # only first N eligible rows
 *   node scripts/backfill-original-bill-check-results.js --today         # only rows created today
 *   node scripts/backfill-original-bill-check-results.js --today --limit=5
 */

import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

function loadEnv(envPath) {
  const out = {};
  for (const line of readFileSync(envPath, 'utf-8').split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const idx = trimmed.indexOf('=');
    if (idx === -1) continue;
    out[trimmed.slice(0, idx).trim()] = trimmed.slice(idx + 1).trim();
  }
  return out;
}

const args = process.argv.slice(2);
const LIMIT = (() => {
  const a = args.find((a) => a.startsWith('--limit='));
  return a ? parseInt(a.split('=')[1], 10) : null;
})();
const TODAY_ONLY = args.includes('--today');
const CONCURRENCY = (() => {
  const a = args.find((a) => a.startsWith('--concurrency='));
  return a ? Math.max(1, parseInt(a.split('=')[1], 10)) : 4;
})();

const env = loadEnv(join(__dirname, '..', 'frontend', '.env'));
const SUPABASE_URL = env.VITE_SUPABASE_URL;
const SERVICE_KEY = env.VITE_SUPABASE_SERVICE_KEY;

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('❌ Missing VITE_SUPABASE_URL / VITE_SUPABASE_SERVICE_KEY in frontend/.env');
  process.exit(1);
}

const sbHeaders = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  'Content-Type': 'application/json'
};

async function sbGet(path) {
  const resp = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, { headers: sbHeaders });
  if (!resp.ok) throw new Error(`Supabase GET ${path} failed: ${resp.status} ${await resp.text()}`);
  return resp.json();
}

async function sbGetAllPaged(basePath, pageSize = 1000) {
  const all = [];
  let offset = 0;
  for (;;) {
    const sep = basePath.includes('?') ? '&' : '?';
    const page = await sbGet(`${basePath}${sep}limit=${pageSize}&offset=${offset}`);
    all.push(...page);
    if (page.length < pageSize) break;
    offset += pageSize;
  }
  return all;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Runs `items` through `worker` with at most `concurrency` in flight at once, preserving
// nothing about order (each item is independent — writes go straight to the DB per record).
async function runPool(items, concurrency, worker) {
  let next = 0;
  async function runner() {
    while (next < items.length) {
      const i = next++;
      await worker(items[i], i);
    }
  }
  await Promise.all(Array.from({ length: Math.min(concurrency, items.length) }, runner));
}

async function sbPatch(path, body) {
  const resp = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method: 'PATCH',
    headers: { ...sbHeaders, Prefer: 'return=minimal' },
    body: JSON.stringify(body)
  });
  if (!resp.ok) throw new Error(`Supabase PATCH ${path} failed: ${resp.status} ${await resp.text()}`);
}

async function getGeminiKey() {
  const rows = await sbGet(`system_api_keys?service_name=eq.google_gemini&is_active=eq.true&select=api_key&limit=1`);
  return rows?.[0]?.api_key || null;
}

// Mirrors guessMimeType() in frontend/src/routes/api/check-original-bill/+server.js
function guessMimeType(url, contentType) {
  const ct = (contentType || '').split(';')[0].trim().toLowerCase();
  if (ct && ct !== 'application/octet-stream' && ct !== 'binary/octet-stream') return ct;
  const lower = (url || '').toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  return 'application/pdf';
}

// Mirrors the prompt in frontend/src/routes/api/check-original-bill/+server.js exactly, so
// backfilled results are consistent with what the interactive Check button would produce.
//
// Bill Date is deliberately NOT judged by the AI (see checkOneBill below for why) — the AI's
// only job for it is extraction + ISO normalization; the actual match is a plain string
// comparison in code.
function buildPrompt(localVendorName, localVendorVat, localBillAmount, localBillDate) {
  const hasLocalValues = localVendorName != null || localVendorVat != null || localBillAmount != null || localBillDate != null;
  return `You are extracting information from a vendor bill/invoice document image or PDF. Read the document carefully and extract exactly these fields, as printed on the document:

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
}

async function checkOneBill(geminiKey, record, vendorNameByKey) {
  const localVendorName = vendorNameByKey.get(`${record.vendor_id}_${record.branch_id}`)?.vendor_name || null;
  const localVendorVat = vendorNameByKey.get(`${record.vendor_id}_${record.branch_id}`)?.vat_number || null;
  const localBillAmount = parseFloat(record.final_bill_amount ?? record.bill_amount ?? 0) || 0;
  // Raw ISO (YYYY-MM-DD, as stored) — compared against the AI's own ISO-normalized read of the
  // document with plain string equality (see below), not an AI judgment call.
  const localBillDate = record.bill_date || null;

  const fileRes = await fetch(record.original_bill_url);
  if (!fileRes.ok) throw new Error(`Failed to download bill document (HTTP ${fileRes.status})`);
  const contentType = fileRes.headers.get('content-type') || '';
  const mimeType = guessMimeType(record.original_bill_url, contentType);
  const buffer = Buffer.from(await fileRes.arrayBuffer());
  const base64Data = buffer.toString('base64');

  const prompt = buildPrompt(localVendorName, localVendorVat, localBillAmount, localBillDate);

  const geminiBody = JSON.stringify({
    contents: [{ role: 'user', parts: [{ text: prompt }, { inlineData: { mimeType, data: base64Data } }] }],
    generationConfig: {
      temperature: 0,
      maxOutputTokens: 2000,
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
          vendor_name_matches: { type: 'BOOLEAN' },
          vendor_vat_matches: { type: 'BOOLEAN' },
          bill_amount_matches: { type: 'BOOLEAN' }
        },
        required: ['vendor_name', 'vendor_vat_number', 'bill_amount_including_vat', 'bill_date', 'bill_date_iso', 'vendor_name_matches', 'vendor_vat_matches', 'bill_amount_matches']
      }
    }
  });

  // Rate limits (429) and transient server errors (5xx) are expected over a run this size —
  // retry with backoff instead of failing the record outright.
  let geminiRes;
  for (let attempt = 0; ; attempt++) {
    geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: geminiBody }
    );
    if (geminiRes.ok) break;
    const retryable = geminiRes.status === 429 || geminiRes.status >= 500;
    if (!retryable || attempt >= 4) {
      throw new Error(`Gemini API error ${geminiRes.status}: ${await geminiRes.text()}`);
    }
    const backoffMs = Math.min(30000, 1000 * 2 ** attempt) + Math.floor(Math.random() * 500);
    await sleep(backoffMs);
  }

  const geminiData = await geminiRes.json();
  const candidate = geminiData.candidates?.[0];
  const rawText = candidate?.content?.parts?.[0]?.text || '';
  if (!rawText.trim()) throw new Error(`AI returned an empty response (finishReason: ${candidate?.finishReason || 'unknown'})`);

  const extracted = JSON.parse(rawText);

  const vendorNameMatches = typeof extracted.vendor_name_matches === 'boolean' ? extracted.vendor_name_matches : null;
  const vendorVatMatches = typeof extracted.vendor_vat_matches === 'boolean' ? extracted.vendor_vat_matches : null;
  const vendorMatches = vendorVatMatches === null ? vendorNameMatches : vendorVatMatches;
  const billAmountMatches = typeof extracted.bill_amount_matches === 'boolean' ? extracted.bill_amount_matches : null;

  // Deterministic date comparison — see the comment above buildPrompt(). A plain string
  // comparison between two normalized ISO dates can't misjudge equal dates as different the
  // way asking the AI to "judge" it directly could (and did, in testing).
  const billDateIso = (extracted.bill_date_iso || '').trim();
  const billDateMatches = (billDateIso && localBillDate)
    ? billDateIso === String(localBillDate).trim()
    : null;

  const status = (vendorMatches === true && billAmountMatches === true && billDateMatches === true) ? 'matched' : 'mismatch';

  return {
    vendorName: extracted.vendor_name || '',
    vendorVatNumber: extracted.vendor_vat_number || '',
    billAmountIncludingVat: extracted.bill_amount_including_vat || '',
    billDate: extracted.bill_date || '',
    billDateIso,
    vendorNameMatches, vendorVatMatches, vendorMatches, billAmountMatches, billDateMatches,
    manuallyVerified: false, manuallyVerifiedBy: null, manuallyVerifiedAt: null,
    status,
    checkedAt: new Date().toISOString()
  };
}

async function main() {
  console.log('📥 Loading Gemini key, eligible records, and vendors...');
  const geminiKey = await getGeminiKey();
  if (!geminiKey) throw new Error('No active google_gemini key found in system_api_keys');

  let filter = `original_bill_url=not.is.null&original_bill_check_result=is.null`;
  if (TODAY_ONLY) {
    const today = new Date().toISOString().slice(0, 10);
    filter += `&created_at=gte.${today}`;
    console.log(`📅 Filtering to records created on/after ${today} (today only)`);
  }
  const path = `receiving_records?select=id,bill_number,vendor_id,branch_id,bill_date,bill_amount,final_bill_amount,original_bill_url,created_at&${filter}&order=created_at.desc`;

  const [records, vendors] = await Promise.all([
    LIMIT ? sbGet(`${path}&limit=${LIMIT}`) : sbGetAllPaged(path),
    sbGetAllPaged(`vendors?select=erp_vendor_id,branch_id,vendor_name,vat_number`)
  ]);

  const vendorNameByKey = new Map(vendors.map((v) => [`${v.erp_vendor_id}_${v.branch_id}`, v]));

  console.log(`📊 ${records.length} record(s) selected for this run${LIMIT ? ` (limit=${LIMIT})` : ''} — concurrency=${CONCURRENCY}`);
  if (records.length === 0) {
    console.log('Nothing to do.');
    return;
  }

  const summary = { matched: 0, mismatch: 0, failed: 0 };
  let done = 0;
  const startedAt = Date.now();

  await runPool(records, CONCURRENCY, async (record) => {
    try {
      const result = await checkOneBill(geminiKey, record, vendorNameByKey);
      await sbPatch(`receiving_records?id=eq.${record.id}`, { original_bill_check_result: result });
      summary[result.status]++;
      console.log(`${result.status === 'matched' ? '✅' : '⚠️ '} ${record.bill_number || record.id} — vendor:${result.vendorMatches} vat:${result.vendorVatMatches} amount:${result.billAmountMatches} date:${result.billDateMatches}`);
    } catch (err) {
      summary.failed++;
      console.log(`❌ ${record.bill_number || record.id} — ${err.message}`);
    } finally {
      done++;
      if (done % 50 === 0 || done === records.length) {
        const elapsedMin = ((Date.now() - startedAt) / 60000).toFixed(1);
        const rate = done / ((Date.now() - startedAt) / 60000);
        const etaMin = rate > 0 ? ((records.length - done) / rate).toFixed(0) : '?';
        console.log(`\n⏱  Progress: ${done}/${records.length} (matched:${summary.matched} mismatch:${summary.mismatch} failed:${summary.failed}) — ${elapsedMin}min elapsed, ~${etaMin}min remaining\n`);
      }
    }
  });

  console.log('\n📋 Final summary:');
  console.log(`   Matched:  ${summary.matched}`);
  console.log(`   Mismatch: ${summary.mismatch}`);
  console.log(`   Failed:   ${summary.failed}`);
}

main().catch((err) => {
  console.error('❌ Backfill failed:', err);
  process.exit(1);
});
