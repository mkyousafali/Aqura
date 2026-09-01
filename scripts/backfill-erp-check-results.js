#!/usr/bin/env node
/**
 * One-time backfill: runs the ERP Check (vendor ID + amount ±1 match against each branch's
 * live SQL Server, over its Cloudflare tunnel) for every receiving_records row that has an
 * erp_purchase_invoice_reference entered, and persists the verdict into erp_check_result (jsonb).
 *
 * Mirrors the exact matching logic used interactively in
 * frontend/src/lib/components/desktop-interface/master/operations/receiving/ReceivingRecords.svelte
 * (checkErpInvoice), but batches per-branch voucher lookups and writes via the
 * bulk_update_erp_check_result RPC instead of one row at a time.
 *
 * Run with: node scripts/backfill-erp-check-results.js
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

const env = loadEnv(join(__dirname, '..', 'frontend', '.env'));
const SUPABASE_URL = env.VITE_SUPABASE_URL;
const SERVICE_KEY = env.VITE_SUPABASE_SERVICE_KEY;
const BRIDGE_API_SECRET = 'aqura-erp-bridge-2026';
const AMOUNT_TOLERANCE = 1;
const VOUCHER_CHUNK_SIZE = 250; // per-branch IN(...) batch size for the ERP query
const UPDATE_CHUNK_SIZE = 500; // rows per bulk_update_erp_check_result RPC call

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

async function sbRpc(fn, body) {
  const resp = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: sbHeaders,
    body: JSON.stringify(body)
  });
  if (!resp.ok) throw new Error(`Supabase RPC ${fn} failed: ${resp.status} ${await resp.text()}`);
  return resp.json();
}

async function erpQuery(tunnelUrl, sql) {
  const resp = await fetch(`${tunnelUrl.replace(/\/+$/, '')}/query`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-api-secret': BRIDGE_API_SECRET },
    body: JSON.stringify({ sql }),
    signal: AbortSignal.timeout(60000)
  });
  const data = await resp.json();
  if (!data.success) throw new Error(data.error || 'Bridge query failed');
  return data.recordset || [];
}

function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

// Vendor IDs can legitimately diverge (duplicate/renamed ERP ledgers for the same real vendor,
// e.g. "HADI MADKHALI" vs "HADI MADKHALI(SAMTAH)") while still being the same business — so the
// vendor match decision compares NAMES (parenthetical suffixes stripped, tokenized) instead of IDs.
function normalizeVendorNameTokens(name) {
  if (!name) return [];
  return name
    .toString()
    .toLowerCase()
    .replace(/\([^)]*\)/g, ' ')
    .replace(/[^\p{L}\p{N}\s]/gu, ' ')
    .split(/\s+/)
    .filter((t) => t.length >= 2);
}

function vendorNamesMatch(nameA, nameB) {
  const tokensA = new Set(normalizeVendorNameTokens(nameA));
  const tokensB = new Set(normalizeVendorNameTokens(nameB));
  if (tokensA.size === 0 || tokensB.size === 0) return false;
  let overlap = 0;
  for (const t of tokensA) if (tokensB.has(t)) overlap++;
  return overlap / Math.min(tokensA.size, tokensB.size) >= 0.8;
}

async function main() {
  console.log('📥 Loading ERP connections, receiving records, and vendor names...');
  const [erpConnections, records, vendors] = await Promise.all([
    sbGet(`erp_connections?select=branch_id,tunnel_url,erp_branch_id&is_active=eq.true`),
    sbGetAllPaged(
      `receiving_records?select=id,branch_id,vendor_id,bill_amount,final_bill_amount,erp_purchase_invoice_reference&erp_purchase_invoice_reference=not.is.null`
    ),
    sbGetAllPaged(`vendors?select=erp_vendor_id,branch_id,vendor_name`)
  ]);

  const vendorNameByKey = new Map(vendors.map((v) => [`${v.erp_vendor_id}_${v.branch_id}`, v.vendor_name]));
  const connByBranch = new Map(erpConnections.filter((c) => c.tunnel_url).map((c) => [String(c.branch_id), c]));
  const eligible = records.filter((r) => (r.erp_purchase_invoice_reference || '').toString().trim() !== '');
  console.log(`📊 ${eligible.length} records have an ERP reference entered (of ${records.length} fetched)`);

  const recordsByBranch = new Map();
  for (const r of eligible) {
    const key = String(r.branch_id);
    if (!recordsByBranch.has(key)) recordsByBranch.set(key, []);
    recordsByBranch.get(key).push(r);
  }

  const updates = []; // { id, result }
  const summary = { matched: 0, mismatch: 0, not_found: 0, error: 0, matchedById: 0, matchedByName: 0 };

  for (const [branchId, branchRecords] of recordsByBranch) {
    const conn = connByBranch.get(branchId);
    const checkedAt = new Date().toISOString();

    if (!conn) {
      console.log(`⚠️  Branch ${branchId}: no active ERP tunnel configured — ${branchRecords.length} records marked error`);
      for (const r of branchRecords) {
        updates.push({ id: r.id, result: { status: 'error', error: 'No ERP tunnel configured for this branch', checkedAt } });
        summary.error++;
      }
      continue;
    }

    // Single batched lookup per branch (chunked) instead of one ERP round trip per record.
    const voucherNumbers = [...new Set(branchRecords.map((r) => r.erp_purchase_invoice_reference.toString().trim()))];
    // VoucherNumber is NOT guaranteed unique per branch (each counter/terminal keeps its own
    // sequence, and VAT vs non-VAT-form entries can independently reuse the same number) — so every
    // matching row is kept here, and each is tried per record instead of pre-picking just one.
    const voucherMap = new Map(); // VoucherNumber -> array of candidate rows

    for (const batch of chunk(voucherNumbers, VOUCHER_CHUNK_SIZE)) {
      const inList = batch.map((v) => `'${v.replace(/'/g, "''")}'`).join(',');
      const sql = `SELECT m.VoucherNumber, m.GrandTotal, m.PartyName, m.TransactionDate, m.VoucherForm, l.LedgerCode AS VendorId FROM InvTransactionMaster m LEFT JOIN AccLedgers l ON l.LedgerID = m.LedgerID AND l.BranchID = m.BranchID WHERE m.VoucherType='PI' AND m.BranchID=${conn.erp_branch_id} AND m.IsActive=1 AND CAST(m.VoucherNumber AS VARCHAR(50)) IN (${inList})`;
      let rows;
      try {
        rows = await erpQuery(conn.tunnel_url, sql);
      } catch (err) {
        console.log(`❌ Branch ${branchId}: bridge query failed for a batch of ${batch.length} vouchers — ${err.message}`);
        continue;
      }
      for (const row of rows) {
        const key = String(row.VoucherNumber).trim();
        if (!voucherMap.has(key)) voucherMap.set(key, []);
        voucherMap.get(key).push(row);
      }
    }

    for (const r of branchRecords) {
      const ref = r.erp_purchase_invoice_reference.toString().trim();
      const candidateRows = voucherMap.get(ref);
      if (!candidateRows || candidateRows.length === 0) {
        updates.push({ id: r.id, result: { status: 'not_found', checkedAt } });
        summary.not_found++;
        continue;
      }

      const localVendorId = String(r.vendor_id ?? '').trim();
      const billAmount = parseFloat(r.bill_amount ?? 0) || 0;
      const finalAmount = parseFloat(r.final_bill_amount ?? r.bill_amount ?? 0) || 0;
      const localVendorName = vendorNameByKey.get(`${r.vendor_id}_${r.branch_id}`) || null;

      const candidates = candidateRows.map((row) => {
        const erpVendorId = String(row.VendorId ?? '').trim();
        const erpAmount = parseFloat(row.GrandTotal) || 0;
        const diffFromBill = erpAmount - billAmount;
        const diffFromFinal = erpAmount - finalAmount;
        const matchesBill = Math.abs(diffFromBill) <= AMOUNT_TOLERANCE;
        const matchesFinal = Math.abs(diffFromFinal) <= AMOUNT_TOLERANCE;
        const amountMatches = matchesBill || matchesFinal;
        const useBill = Math.abs(diffFromBill) <= Math.abs(diffFromFinal);
        const amountDiff = useBill ? diffFromBill : diffFromFinal;
        const amountSource = useBill ? 'Bill' : 'Final';
        // Step 1: exact vendor ID match. Step 2 (fallback, only when IDs differ): vendor NAME match.
        const vendorIdMatches = erpVendorId !== '' && erpVendorId === localVendorId;
        const vendorNameMatches = !vendorIdMatches && vendorNamesMatch(localVendorName, row.PartyName);
        const vendorMatches = vendorIdMatches || vendorNameMatches;
        const vendorMatchedVia = vendorIdMatches ? 'id' : (vendorNameMatches ? 'name' : null);
        // VoucherForm is blank for non-VAT entries and 'VAT' for VAT-form invoices.
        const vatStatus = (row.VoucherForm || '').trim().toUpperCase() === 'VAT' ? 'VAT' : 'No VAT';
        return {
          status: vendorMatches && amountMatches ? 'matched' : 'mismatch',
          grandTotal: erpAmount, amountDiff, amountSource, erpVendorId, localVendorId,
          vendorMatches, vendorIdMatches, vendorNameMatches, vendorMatchedVia, amountMatches,
          partyName: row.PartyName, localVendorName, vatStatus
        };
      });

      // Prefer a fully-matched candidate; otherwise report whichever is closest on amount.
      const best = candidates.find((c) => c.status === 'matched') ||
        candidates.reduce((a, b) => (Math.abs(b.amountDiff) < Math.abs(a.amountDiff) ? b : a));
      const status = best.status;

      updates.push({
        id: r.id,
        result: { ...best, candidateCount: candidateRows.length, checkedAt }
      });
      summary[status]++;
      if (status === 'matched') {
        if (best.vendorMatchedVia === 'name') summary.matchedByName++;
        else summary.matchedById++;
      }
    }

    console.log(`✅ Branch ${branchId}: checked ${branchRecords.length} records via ${voucherNumbers.length} distinct vouchers`);
  }

  console.log(`💾 Writing ${updates.length} erp_check_result updates in batches of ${UPDATE_CHUNK_SIZE}...`);
  let written = 0;
  for (const batch of chunk(updates, UPDATE_CHUNK_SIZE)) {
    const count = await sbRpc('bulk_update_erp_check_result', { p_updates: batch });
    written += count;
  }

  console.log('\n📋 Summary:');
  console.log(`   Matched:    ${summary.matched} (by ID: ${summary.matchedById}, by name fallback: ${summary.matchedByName})`);
  console.log(`   Mismatch:   ${summary.mismatch}`);
  console.log(`   Not found:  ${summary.not_found}`);
  console.log(`   Error:      ${summary.error}`);
  console.log(`   Rows written: ${written} / ${updates.length}`);
}

main().catch((err) => {
  console.error('❌ Backfill failed:', err);
  process.exit(1);
});
