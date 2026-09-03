#!/usr/bin/env node
/**
 * REAL backfill (writes to box_operations) for erp_counter_id / erp_counter_shift_id /
 * erp_counter_name / erp_shift_name / erp_shift_start_date / erp_shift_start_time / erp_branch_id.
 *
 * Scope is intentionally restricted to rows where complete_details IS NOT NULL (i.e. only boxes
 * that were fully closed/completed by an accountant) — NOT the open/pending_close rows. Matching
 * logic and tolerance are identical to, and validated against, scripts/erp-backfill-dry-run.mjs
 * (5/5 high-confidence on the same completed rows before this script was written).
 *
 * Only writes rows that come out "high" confidence (window match + CounterName matches
 * notes.pos_number). medium/low/unmatched rows are left untouched and printed for manual review.
 * Pass --include-closed to also write "medium" confidence rows (window match, but pos_number
 * didn't confirm) when the matched ERP shift itself is already Closed there — "low" confidence
 * (no real window overlap) and unmatched rows are still never written.
 *
 * Run with: node scripts/erp-backfill-write.mjs --limit=5
 * (omit --limit to process every completed row still missing erp_counter_shift_id)
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

if (!SUPABASE_URL || !SERVICE_KEY) {
	console.error('❌ Missing VITE_SUPABASE_URL / VITE_SUPABASE_SERVICE_KEY in frontend/.env');
	process.exit(1);
}

const BRANCH_TUNNELS = {
	1: 'https://erp-branch1.urbanaqura.com',
	2: 'https://erp-branch2.urbanaqura.com',
	3: 'https://erp-branch3.urbanaqura.com'
};

const LOCAL_OFFSET_HOURS = 3;
const WINDOW_TOLERANCE_MIN = 10;

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
		const resp = await fetch(`${SUPABASE_URL}/rest/v1/${basePath}${sep}limit=${pageSize}&offset=${offset}`, {
			headers: sbHeaders
		});
		if (!resp.ok) throw new Error(`Supabase GET ${basePath} failed: ${resp.status} ${await resp.text()}`);
		const page = await resp.json();
		all.push(...page);
		if (page.length < pageSize) break;
		offset += pageSize;
	}
	return all;
}

async function sbPatch(id, body) {
	const resp = await fetch(`${SUPABASE_URL}/rest/v1/box_operations?id=eq.${id}`, {
		method: 'PATCH',
		headers: { ...sbHeaders, Prefer: 'return=minimal' },
		body: JSON.stringify(body)
	});
	if (!resp.ok) throw new Error(`Supabase PATCH box_operations(${id}) failed: ${resp.status} ${await resp.text()}`);
}

async function erpQuery(tunnelUrl, sql) {
	const resp = await fetch(`${tunnelUrl}/query`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json', 'x-api-secret': BRIDGE_API_SECRET },
		body: JSON.stringify({ sql })
	});
	if (!resp.ok) throw new Error(`ERP query failed (${tunnelUrl}): ${resp.status} ${await resp.text()}`);
	const result = await resp.json();
	return result.recordset || result || [];
}

function toLocal(utcIsoString) {
	const d = new Date(utcIsoString);
	return new Date(d.getTime() + LOCAL_OFFSET_HOURS * 3600 * 1000);
}

function parseErpTime(dateStr, timeStr) {
	const dateMatch = String(dateStr).match(/(\d{4}-\d{2}-\d{2})/);
	const timeMatch = String(timeStr).match(/T(\d{2}):(\d{2}):(\d{2})/);
	if (!dateMatch || !timeMatch) return null;
	return new Date(`${dateMatch[1]}T${timeMatch[1]}:${timeMatch[2]}:${timeMatch[3]}Z`);
}

function minutesDiff(a, b) {
	return Math.round((a.getTime() - b.getTime()) / 60000);
}

// Extract cash/card/total figures from a box_operations row's complete_details (fallback closing_details)
// to compare against the ERP-derived figures — same fields CloseBox.svelte itself compares against live.
function rowTotals(row) {
	const d = row.complete_details || row.closing_details || {};
	return {
		totalCashSales: Number(d.total_cash_sales) || 0,
		bankTotal: Number(d.bank_total) || 0,
		totalSales: Number(d.total_sales) || 0,
		closingTotal: Number(d.closing_total) || 0
	};
}

function formatErpDateTime(dateStr, timeStr) {
	if (!dateStr || !timeStr) return '';
	const timeMatch = String(timeStr).match(/T(\d{2}):(\d{2}):(\d{2})/);
	const dateMatch = String(dateStr).match(/(\d{4}-\d{2}-\d{2})/);
	if (!timeMatch || !dateMatch) return '';
	let hours = parseInt(timeMatch[1], 10);
	const ampm = hours >= 12 ? 'PM' : 'AM';
	hours = hours > 12 ? hours - 12 : (hours === 0 ? 12 : hours);
	return `${dateMatch[1]} ${hours}:${timeMatch[2]}:${timeMatch[3]} ${ampm}`;
}

// Fetch the SI/SR-only sales breakdown for one specific shift, same query CloseBox.svelte runs live.
async function fetchSalesBreakdown(tunnelUrl, erpBranchId, shiftId) {
	const sql = `
		SELECT l.LedgerID, SUM(d.Debit) - SUM(d.Credit) AS NetAmount
		FROM AccTransactionDetails d
		INNER JOIN AccTransactionMaster m ON d.AccTransactionMasterID = m.AccTransactionMasterID AND d.BranchID = m.BranchID
		INNER JOIN AccLedgers l ON l.LedgerID = d.LedgerID AND l.BranchID = d.BranchID
		WHERE m.BranchID = ${erpBranchId} AND d.BranchID = ${erpBranchId} AND l.BranchID = ${erpBranchId}
		  AND m.CounterShiftID = ${shiftId} AND d.LedgerID IN (40, 41, 42, 43, 21)
		  AND m.VoucherType IN ('SI','SR') AND m.IsActive = 1
		GROUP BY l.LedgerID
	`;
	const rows = await erpQuery(tunnelUrl, sql);
	let cashSales = 0, cardSales = 0;
	for (const r of rows) {
		if (r.LedgerID === 21) cardSales = Number(r.NetAmount) || 0;
		else cashSales += Number(r.NetAmount) || 0;
	}
	return { cashSales, cardSales, totalSales: cashSales + cardSales };
}

// Builds the same erp_closing_details shape CloseBox.svelte saves live at Close time.
async function buildClosingColumns(tunnelUrl, erpBranchId, shift, row) {
	const sales = await fetchSalesBreakdown(tunnelUrl, erpBranchId, shift.CounterShiftID);
	const totals = rowTotals(row);
	const closingCashPhysical = Number(shift.CloseCashPhysical) || 0;
	const rawStatus = shift.OpenCloseStatus || '';
	const counterStatus = rawStatus === 'O' ? 'Open' : rawStatus === 'C' ? 'Closed' : 'Unknown';
	const closedAt = rawStatus === 'C' ? formatErpDateTime(shift.TransactionDate, shift.ClosingTime) : '';
	return {
		erp_opening_cash_physical: shift.OpenCashPhysical != null ? Number(shift.OpenCashPhysical) : null,
		erp_opening_cash_system: shift.OpeningCashBySystem != null ? Number(shift.OpeningCashBySystem) : null,
		erp_closing_details: {
			erp_cash_sales: sales.cashSales,
			erp_card_sales: sales.cardSales,
			erp_total_sales: sales.totalSales,
			erp_closing_cash_physical: closingCashPhysical,
			counter_status: counterStatus,
			counter_status_raw: rawStatus,
			closed_at: closedAt,
			cash_sales_matched: Math.abs(sales.cashSales - totals.totalCashSales) < 0.01,
			card_sales_matched: Math.abs(sales.cardSales - totals.bankTotal) < 0.01,
			total_sales_matched: Math.abs(sales.totalSales - totals.totalSales) < 0.01,
			closing_cash_matched: Math.abs(closingCashPhysical - totals.closingTotal) < 0.01,
			fetched_at: new Date().toISOString(),
			backfilled: true
		}
	};
}

async function main() {
	const limitArg = process.argv.find(a => a.startsWith('--limit'));
	const limit = limitArg ? Number(limitArg.split('=')[1]) : null;
	const repairMode = process.argv.includes('--repair-missing');
	// Second-pass mode: also accept a "medium" match (window match, but notes.pos_number didn't
	// confirm the counter) as long as the matched ERP shift is already Closed there — a closed
	// shift can't be re-picked by a different cashier later, so the window match alone is trustworthy.
	// True "low" confidence (no real window overlap, just closest-time fallback) is still never written.
	const includeClosed = process.argv.includes('--include-closed');

	const branchFilter = Object.keys(BRANCH_TUNNELS).join(',');

	if (repairMode) {
		// Rows already matched (erp_counter_shift_id set) but missing the opening-cash/closing-details
		// columns added after the first backfill pass — repair using the shift ID already stored, no
		// need to re-run the user/date matching logic.
		console.log(limit
			? `📥 Fetching last ${limit} completed rows needing opening-cash/closing-details repair...`
			: '📥 Fetching ALL completed rows needing opening-cash/closing-details repair...');
		const basePath = `box_operations?select=id,branch_id,erp_branch_id,erp_counter_shift_id,complete_details,closing_details` +
			`&complete_details=not.is.null&erp_counter_shift_id=not.is.null&erp_opening_cash_physical=is.null&branch_id=in.(${branchFilter})&order=start_time.desc`;
		const rows = limit ? await sbGet(`${basePath}&limit=${limit}`) : await sbGetAllPaged(basePath);
		console.log(`   Found ${rows.length} candidate rows.`);
		if (rows.length === 0) { console.log('Nothing to do.'); return; }

		let written = 0;
		const skippedRows = [];
		for (const row of rows) {
			const tunnelUrl = BRANCH_TUNNELS[row.branch_id];
			if (!tunnelUrl) { skippedRows.push({ id: row.id, reason: 'no tunnel for branch' }); continue; }
			try {
				const shiftSql = `
					SELECT cs.CounterShiftID, cs.TransactionDate, cs.ClosingTime, cs.OpenCloseStatus,
					       cs.OpenCashPhysical, cs.OpeningCashBySystem, cs.CloseCashPhysical
					FROM CounterShift cs
					WHERE cs.BranchID = ${row.erp_branch_id} AND cs.CounterShiftID = ${row.erp_counter_shift_id}
				`;
	const shiftRows = await erpQuery(tunnelUrl, shiftSql);
				const shift = shiftRows[0];
				if (!shift) { skippedRows.push({ id: row.id, reason: 'shift not found in ERP anymore' }); continue; }
				const patch = await buildClosingColumns(tunnelUrl, row.erp_branch_id, shift, row);
				await sbPatch(row.id, patch);
				written++;
				console.log(`✅ ${row.id} -> opening cash ${patch.erp_opening_cash_physical}, closing details filled`);
			} catch (err) {
				skippedRows.push({ id: row.id, reason: err.message });
			}
		}
		console.log(`\n📊 Summary: ${written} written, ${skippedRows.length} skipped.`);
		for (const s of skippedRows) console.log(`   ${s.id}: ${s.reason}`);
		return;
	}

	console.log(limit
		? `📥 Fetching last ${limit} completed box_operations rows missing erp_counter_shift_id...`
		: '📥 Fetching ALL completed box_operations rows missing erp_counter_shift_id...');
	// Hard requirement: only ever touch rows with complete_details populated (fully closed by accountant).
	const basePath = `box_operations?select=id,box_number,branch_id,user_id,status,start_time,end_time,notes,complete_details,closing_details` +
		`&complete_details=not.is.null&erp_counter_shift_id=is.null&branch_id=in.(${branchFilter})&order=start_time.desc`;
	const rows = limit ? await sbGet(`${basePath}&limit=${limit}`) : await sbGetAllPaged(basePath);
	console.log(`   Found ${rows.length} candidate rows.`);

	if (rows.length === 0) { console.log('Nothing to do.'); return; }

	console.log('📥 Fetching user_erp_credentials...');
	const creds = await sbGetAllPaged('user_erp_credentials?select=user_id,aqura_branch_id,erp_branch_id,erp_user_id,erp_username');
	const credMap = new Map();
	for (const c of creds) credMap.set(`${c.user_id}:${c.aqura_branch_id}`, c);

	const matchable = [];
	let skippedNoCred = 0;
	for (const row of rows) {
		const cred = credMap.get(`${row.user_id}:${row.branch_id}`);
		if (!cred) { skippedNoCred++; continue; }
		matchable.push({ row, cred });
	}
	console.log(`   ${matchable.length} rows have ERP credentials, ${skippedNoCred} skipped (no credential match).`);

	const groups = new Map();
	for (const { row, cred } of matchable) {
		const tunnelUrl = BRANCH_TUNNELS[cred.aqura_branch_id];
		if (!tunnelUrl) continue;
		const dateStr = row.start_time.slice(0, 10);
		const key = `${cred.erp_branch_id}|${cred.erp_user_id}|${dateStr}`;
		if (!groups.has(key)) groups.set(key, { erpBranchId: cred.erp_branch_id, erpUserId: cred.erp_user_id, tunnelUrl, date: dateStr, items: [] });
		groups.get(key).items.push({ row, cred });
	}
	console.log(`📦 Grouped into ${groups.size} ERP queries.`);

	let written = 0;
	const skippedRows = [];

	for (const group of groups.values()) {
		let shifts = [];
		try {
			const sql = `
				SELECT cs.CounterShiftID, cs.CounterID, c.CounterName, cs.TransactionDate, cs.OpenTime, cs.ClosingTime, cs.ShiftName,
				       cs.OpenCloseStatus, cs.OpenCashPhysical, cs.OpeningCashBySystem, cs.CloseCashPhysical
				FROM CounterShift cs
				LEFT JOIN Counter c ON cs.CounterID = c.CounterID AND cs.BranchID = c.BranchID
				WHERE cs.BranchID = ${group.erpBranchId} AND cs.OpenUserID = ${group.erpUserId}
				  AND CAST(cs.TransactionDate AS date) = '${group.date}'
				ORDER BY cs.OpenTime
			`;
			shifts = await erpQuery(group.tunnelUrl, sql);
		} catch (err) {
			for (const { row } of group.items) skippedRows.push({ id: row.id, reason: `erp query error: ${err.message}` });
			continue;
		}

		for (const { row, cred } of group.items) {
			const localStart = toLocal(row.start_time);

			let best = null, bestDiff = Infinity, windowMatch = null;
			for (const shift of shifts) {
				const openAt = parseErpTime(shift.TransactionDate, shift.OpenTime);
				const closeAt = shift.ClosingTime ? parseErpTime(shift.TransactionDate, shift.ClosingTime) : new Date();
				if (!openAt) continue;
				const openAtTol = new Date(openAt.getTime() - WINDOW_TOLERANCE_MIN * 60000);
				const closeAtTol = new Date(closeAt.getTime() + WINDOW_TOLERANCE_MIN * 60000);
				if (openAtTol <= localStart && localStart <= closeAtTol) { windowMatch = shift; break; }
				const diff = Math.abs(minutesDiff(openAt, localStart));
				if (diff < bestDiff) { bestDiff = diff; best = shift; }
			}

			const matched = windowMatch || best;
			if (!matched) { skippedRows.push({ id: row.id, reason: 'unmatched (no ERP shifts that day)' }); continue; }

			let notesPos = null;
			try { notesPos = row.notes ? JSON.parse(row.notes).pos_number : null; } catch { /* ignore */ }
			const counterNum = matched.CounterName ? (matched.CounterName.match(/\d+/) || [])[0] : null;
			const posMatches = notesPos != null && counterNum != null && Number(notesPos) === Number(counterNum);
			const shiftClosed = String(matched.OpenCloseStatus).toUpperCase() === 'C';
			const confidence = windowMatch ? (posMatches ? 'high' : 'medium') : 'low';

			const eligible = confidence === 'high' || (includeClosed && confidence === 'medium' && shiftClosed);
			if (!eligible) {
				skippedRows.push({ id: row.id, reason: `confidence=${confidence}, shift_status=${matched.OpenCloseStatus}, notes_pos=${notesPos}, matched_counter=${matched.CounterName}` });
				continue;
			}

			const shiftStartTimeMatch = String(matched.OpenTime).match(/T(\d{2}:\d{2}:\d{2}(?:\.\d+)?)/);
			const closingColumns = await buildClosingColumns(group.tunnelUrl, group.erpBranchId, matched, row);
			await sbPatch(row.id, {
				erp_counter_id: matched.CounterID ?? null,
				erp_counter_shift_id: matched.CounterShiftID ?? null,
				erp_counter_name: matched.CounterName ?? null,
				erp_shift_name: matched.ShiftName ?? null,
				erp_shift_start_date: String(matched.TransactionDate).slice(0, 10),
				erp_shift_start_time: shiftStartTimeMatch ? shiftStartTimeMatch[1] : null,
				erp_branch_id: group.erpBranchId,
				...closingColumns
			});
			written++;
			console.log(`✅ ${row.id} -> shift ${matched.CounterShiftID} (${matched.CounterName})`);
		}
	}

	console.log(`\n📊 Summary: ${written} written, ${skippedRows.length} skipped (no write).`);
	if (skippedRows.length) {
		console.log('Skipped rows (left untouched):');
		for (const s of skippedRows) console.log(`   ${s.id}: ${s.reason}`);
	}
}

main().catch((err) => { console.error('❌ Fatal error:', err); process.exit(1); });
