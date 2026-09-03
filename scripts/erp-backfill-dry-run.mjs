#!/usr/bin/env node
/**
 * Read-only dry-run report for backfilling erp_counter_id / erp_counter_shift_id / erp_counter_name /
 * erp_shift_name / erp_shift_start_date / erp_shift_start_time / erp_branch_id on existing box_operations
 * rows that predate the ERP counter-check integration (CounterCheck.svelte / CloseBox.svelte).
 *
 * Matching approach (confirmed against real records before writing this script):
 *  1. For each box_operations row missing erp_counter_shift_id, look up (user_id, branch_id) in
 *     user_erp_credentials to get erp_user_id + erp_branch_id. Rows with no credential match are
 *     skipped entirely (not included in the report).
 *  2. Batch-query each branch's ERP tunnel for that user's CounterShift rows on the shift's date
 *     (one query per distinct erp_user_id + date, not per box_operations row).
 *  3. ERP OpenTime/ClosingTime are Saudi local time; box_operations.start_time/end_time are UTC,
 *     so add 3 hours to start_time/end_time before comparing.
 *  4. Pick the shift whose [OpenTime, ClosingTime] window contains the local start_time (ClosingTime
 *     defaults to "now" for still-open shifts). Tie-break by closest OpenTime.
 *  5. Confidence: high (window match + CounterName matches notes.pos_number), medium (window match,
 *     POS number mismatch - flags the exact "wrong POS selected" bug this feature was built to catch),
 *     low (no window match, fell back to closest OpenTime), unmatched (no shifts that day at all).
 *
 * This script makes NO writes — Supabase reads (box_operations, user_erp_credentials) and ERP reads
 * (CounterShift) only. Output is a CSV report for manual review before any real backfill.
 *
 * Run with: node scripts/erp-backfill-dry-run.mjs
 */

import { readFileSync, writeFileSync } from 'fs';
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

// aqura branch_id -> ERP tunnel. Branch 4 is local-only (192.168.0.3), not reachable from here — skipped.
const BRANCH_TUNNELS = {
	1: 'https://erp-branch1.urbanaqura.com',
	2: 'https://erp-branch2.urbanaqura.com',
	3: 'https://erp-branch3.urbanaqura.com'
};

const LOCAL_OFFSET_HOURS = 3; // ERP times are Saudi local (UTC+3); box_operations timestamps are UTC
const WINDOW_TOLERANCE_MIN = 10; // minutes of slack allowed on either side of [OpenTime, ClosingTime]

const sbHeaders = {
	apikey: SERVICE_KEY,
	Authorization: `Bearer ${SERVICE_KEY}`,
	'Content-Type': 'application/json'
};

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

async function sbGet(path) {
	const resp = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, { headers: sbHeaders });
	if (!resp.ok) throw new Error(`Supabase GET ${path} failed: ${resp.status} ${await resp.text()}`);
	return resp.json();
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
	// dateStr: "2026-09-02T00:00:00.000Z" (date only matters), timeStr: "1900-01-01T10:26:05.593Z" (time only matters)
	const dateMatch = String(dateStr).match(/(\d{4}-\d{2}-\d{2})/);
	const timeMatch = String(timeStr).match(/T(\d{2}):(\d{2}):(\d{2})/);
	if (!dateMatch || !timeMatch) return null;
	return new Date(`${dateMatch[1]}T${timeMatch[1]}:${timeMatch[2]}:${timeMatch[3]}Z`);
}

function minutesDiff(a, b) {
	return Math.round((a.getTime() - b.getTime()) / 60000);
}

async function main() {
	// --test-completed[=N]: sanity-check mode, only processes the last N box_operations rows that
	// have complete_details populated (fully closed by an accountant) instead of the full dataset.
	const testArg = process.argv.find(a => a.startsWith('--test-completed'));
	const testLimit = testArg ? Number(testArg.split('=')[1] || 5) : null;

	console.log(testLimit
		? `📥 Fetching last ${testLimit} completed box_operations rows (complete_details populated)...`
		: '📥 Fetching box_operations rows missing erp_counter_shift_id...');
	const branchFilter = Object.keys(BRANCH_TUNNELS).join(',');
	const rows = testLimit
		? await sbGet(
			`box_operations?select=id,box_number,branch_id,user_id,status,start_time,end_time,notes&complete_details=not.is.null&branch_id=in.(${branchFilter})&order=start_time.desc&limit=${testLimit}`
		)
		: await sbGetAllPaged(
			`box_operations?select=id,box_number,branch_id,user_id,status,start_time,end_time,notes&erp_counter_shift_id=is.null&branch_id=in.(${branchFilter})&order=branch_id,start_time`
		);
	console.log(`   Found ${rows.length} candidate rows (branches 1-3 only).`);

	console.log('📥 Fetching user_erp_credentials...');
	const creds = await sbGetAllPaged('user_erp_credentials?select=user_id,aqura_branch_id,erp_branch_id,erp_user_id,erp_username');
	const credMap = new Map();
	for (const c of creds) {
		credMap.set(`${c.user_id}:${c.aqura_branch_id}`, c);
	}
	console.log(`   Loaded ${creds.length} credential rows.`);

	// Filter to rows with a credential match; group remaining by erp_branch_id + erp_user_id + date
	// to batch one ERP query per user-per-day instead of one per box_operations row.
	const matchable = [];
	let skippedNoCred = 0;
	for (const row of rows) {
		const cred = credMap.get(`${row.user_id}:${row.branch_id}`);
		if (!cred) { skippedNoCred++; continue; }
		matchable.push({ row, cred });
	}
	console.log(`   ${matchable.length} rows have ERP credentials, ${skippedNoCred} skipped (no credential match).`);

	const groups = new Map(); // key: erpBranchId|erpUserId|date -> { erpBranchId, erpUserId, tunnelUrl, date, items: [] }
	for (const { row, cred } of matchable) {
		const tunnelUrl = BRANCH_TUNNELS[cred.aqura_branch_id];
		if (!tunnelUrl) continue;
		const dateStr = row.start_time.slice(0, 10);
		const key = `${cred.erp_branch_id}|${cred.erp_user_id}|${dateStr}`;
		if (!groups.has(key)) {
			groups.set(key, { erpBranchId: cred.erp_branch_id, erpUserId: cred.erp_user_id, tunnelUrl, date: dateStr, items: [] });
		}
		groups.get(key).items.push({ row, cred });
	}
	console.log(`📦 Grouped into ${groups.size} ERP queries (one per user+date).`);

	const report = [];
	let done = 0;
	for (const group of groups.values()) {
		done++;
		if (done % 25 === 0) console.log(`   ...${done}/${groups.size} ERP queries done`);

		let shifts = [];
		try {
			const sql = `
				SELECT cs.CounterShiftID, cs.CounterID, c.CounterName, cs.TransactionDate, cs.OpenTime, cs.ClosingTime, cs.OpenCloseStatus, cs.ShiftName
				FROM CounterShift cs
				LEFT JOIN Counter c ON cs.CounterID = c.CounterID AND cs.BranchID = c.BranchID
				WHERE cs.BranchID = ${group.erpBranchId} AND cs.OpenUserID = ${group.erpUserId}
				  AND CAST(cs.TransactionDate AS date) = '${group.date}'
				ORDER BY cs.OpenTime
			`;
			shifts = await erpQuery(group.tunnelUrl, sql);
		} catch (err) {
			for (const { row } of group.items) {
				report.push(rowToReport(row, null, 'error', null, err.message));
			}
			continue;
		}

		for (const { row } of group.items) {
			const localStart = toLocal(row.start_time);
			const localEnd = row.end_time ? toLocal(row.end_time) : null;

			let best = null;
			let bestDiff = Infinity;
			let windowMatch = null;

			for (const shift of shifts) {
				const openAt = parseErpTime(shift.TransactionDate, shift.OpenTime);
				const closeAt = shift.ClosingTime ? parseErpTime(shift.TransactionDate, shift.ClosingTime) : new Date();
				if (!openAt) continue;

				// Allow a small tolerance either side of the window — the app's own start_time/end_time
				// (when the cashier began/finished the box count) don't line up to the second with ERP's
				// OpenTime/ClosingTime (when they clicked open/close in the POS), just closely.
				const openAtTol = new Date(openAt.getTime() - WINDOW_TOLERANCE_MIN * 60000);
				const closeAtTol = new Date(closeAt.getTime() + WINDOW_TOLERANCE_MIN * 60000);

				if (openAtTol <= localStart && localStart <= closeAtTol) {
					windowMatch = shift;
					break;
				}
				const diff = Math.abs(minutesDiff(openAt, localStart));
				if (diff < bestDiff) {
					bestDiff = diff;
					best = shift;
				}
			}

			const matched = windowMatch || best;
			if (!matched) {
				report.push(rowToReport(row, null, 'unmatched', null));
				continue;
			}

			let notesPos = null;
			try { notesPos = row.notes ? JSON.parse(row.notes).pos_number : null; } catch { /* ignore */ }
			const counterNum = matched.CounterName ? (matched.CounterName.match(/\d+/) || [])[0] : null;
			const posMatches = notesPos != null && counterNum != null && Number(notesPos) === Number(counterNum);

			const confidence = windowMatch ? (posMatches ? 'high' : 'medium') : 'low';
			const openAt = parseErpTime(matched.TransactionDate, matched.OpenTime);
			const closeAt = matched.ClosingTime ? parseErpTime(matched.TransactionDate, matched.ClosingTime) : null;

			report.push({
				box_operation_id: row.id,
				branch_id: row.branch_id,
				box_number: row.box_number,
				status: row.status,
				notes_pos_number: notesPos,
				matched_shift_id: matched.CounterShiftID,
				matched_counter_name: matched.CounterName,
				matched_shift_name: matched.ShiftName,
				confidence,
				open_time_diff_min: openAt ? minutesDiff(openAt, localStart) : '',
				close_time_diff_min: closeAt && localEnd ? minutesDiff(closeAt, localEnd) : '',
				error: ''
			});
		}
	}

	function rowToReport(row, matched, confidence, diff, error = '') {
		return {
			box_operation_id: row.id,
			branch_id: row.branch_id,
			box_number: row.box_number,
			status: row.status,
			notes_pos_number: '',
			matched_shift_id: '',
			matched_counter_name: '',
			matched_shift_name: '',
			confidence,
			open_time_diff_min: '',
			close_time_diff_min: '',
			error
		};
	}

	const headers = Object.keys(report[0] || { box_operation_id: '', confidence: '' });
	const csv = [headers.join(','), ...report.map(r => headers.map(h => JSON.stringify(r[h] ?? '')).join(','))].join('\n');
	const outPath = join(__dirname, testLimit ? 'erp-backfill-dry-run-report.TEST.csv' : 'erp-backfill-dry-run-report.csv');
	writeFileSync(outPath, csv, 'utf-8');

	const byConfidence = report.reduce((acc, r) => { acc[r.confidence] = (acc[r.confidence] || 0) + 1; return acc; }, {});
	console.log('\n📊 Summary:');
	console.log(`   Total candidates: ${rows.length}`);
	console.log(`   Skipped (no ERP credential): ${skippedNoCred}`);
	console.log(`   Reported: ${report.length}`);
	console.log('   By confidence:', byConfidence);
	console.log(`\n✅ Report written to: ${outPath}`);
}

main().catch((err) => {
	console.error('❌ Fatal error:', err);
	process.exit(1);
});
