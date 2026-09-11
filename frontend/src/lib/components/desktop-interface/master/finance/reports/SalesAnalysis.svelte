<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/utils/supabase';
	import { _ as t, currentLocale } from '$lib/i18n';

	// ── Sales Analysis ───────────────────────────────────────────────────────
	// Live, read-only drill-down into one branch's ERP for one day: net sales,
	// gross profit, and (on demand) an item-level GP% breakdown.
	//
	// All ERP access goes through /api/erp-bridge-proxy (CLAUDE.md Pattern 1) —
	// this component only ever sends { branchId: <aqura branch_id>, sql }; the
	// tunnel URL and bridge secret are looked up server-side and never reach
	// the browser. Every SQL string built here is a SELECT only.
	//
	// GP definition used throughout: the ERP stamps a per-line TotalProfit
	// (NetAmount minus that line's costed amount) at billing time, which we
	// trust for the day-level summary. For the item table specifically, the
	// user asked for Cost = the item's *current* Last Purchase Rate
	// (ProductBatches.LastPurchaseRate) rather than the line's stamped
	// CostPerItem — deliberately, since CostPerItem can be wrong when a
	// branch has mis-entered a case cost into a per-unit field (verified this
	// happening on real data — see the investigation earlier in this thread).

	$: isArabic = $currentLocale === 'ar';
	const ui = (en: string, ar: string) => (isArabic ? ar : en);
	// Show only the item name matching the current app language — never both at
	// once. Falls back to whichever name exists if the preferred one is blank.
	const displayName = (row: { productName: string; productNameAr: string }) =>
		(isArabic ? row.productNameAr || row.productName : row.productName || row.productNameAr) || '—';

	interface Branch { branch_id: number; branch_name: string }
	interface DaySummary {
		netSales: number;
		grossSales: number;
		returnAmount: number;
		netGP: number;
		salesBills: number;
		returnBills: number;
		totalDiscount: number;
		distinctItems: number;
	}
	interface ItemRow {
		billNo: string;
		voucherType: string;
		barcode: string;
		productName: string;
		productNameAr: string;
		unitName: string;
		soldQty: number;
		unitConversionQty: number; // how many base units this sold unit represents
		soldRate: number;
		lastPurchaseRate: number | null; // raw, as quoted in its own incoming-stock unit
		costSource: string | null; // PI / GRN / BTI / MFR — which voucher type the rate came from
		cost: number | null; // lastPurchaseRate converted onto the sold unit, VAT-inclusive (matches Sold Rate's basis)
		vatPercent: number;
		gpAmount: number | null;
		gpPercent: number | null;
		lastPurchaseDate: string | null;
	}

	let branches: Branch[] = [];
	let selectedBranchId: number | null = null;

	const now = new Date();
	let selectedYear = now.getFullYear();
	let selectedMonth = now.getMonth() + 1; // 1-12
	let selectedDay = now.getDate();

	const YEARS = Array.from({ length: 6 }, (_, i) => now.getFullYear() - i);
	const MONTHS = [
		{ n: 1, en: 'January', ar: 'يناير' }, { n: 2, en: 'February', ar: 'فبراير' },
		{ n: 3, en: 'March', ar: 'مارس' }, { n: 4, en: 'April', ar: 'أبريل' },
		{ n: 5, en: 'May', ar: 'مايو' }, { n: 6, en: 'June', ar: 'يونيو' },
		{ n: 7, en: 'July', ar: 'يوليو' }, { n: 8, en: 'August', ar: 'أغسطس' },
		{ n: 9, en: 'September', ar: 'سبتمبر' }, { n: 10, en: 'October', ar: 'أكتوبر' },
		{ n: 11, en: 'November', ar: 'نوفمبر' }, { n: 12, en: 'December', ar: 'ديسمبر' }
	];
	$: daysInSelectedMonth = new Date(selectedYear, selectedMonth, 0).getDate();
	$: DAYS = Array.from({ length: daysInSelectedMonth }, (_, i) => i + 1);
	$: if (selectedDay > daysInSelectedMonth) selectedDay = daysInSelectedMonth;

	let loadingBranches = true;
	let loadingSummary = false;
	let summaryError = '';
	let hasRunAnalysis = false;

	let selectedDaySummary: DaySummary | null = null;
	let previousDaySummary: DaySummary | null = null;
	let selectedDateStr = '';
	let previousDateStr = '';

	type GpFilterMode = 'less' | 'more' | 'zeroCost';
	let gpFilterMode: GpFilterMode = 'less';
	let gpFilterValue = '';
	let loadingItems = false;
	let itemsError = '';
	let itemRows: ItemRow[] = [];
	let hasAnalyzedItems = false;
	// Bill lines sold that day with no usable incoming-stock record (checked PI/GRN/BTI/MFR) —
	// always shown, flagged, never excluded, independent of the active GP% filter.
	let noCostRows: ItemRow[] = [];

	const pad2 = (n: number) => String(n).padStart(2, '0');
	function toDateStr(y: number, m: number, d: number) {
		return `${y}-${pad2(m)}-${pad2(d)}`;
	}
	function previousCalendarDay(y: number, m: number, d: number) {
		const dt = new Date(Date.UTC(y, m - 1, d));
		dt.setUTCDate(dt.getUTCDate() - 1);
		return { y: dt.getUTCFullYear(), m: dt.getUTCMonth() + 1, d: dt.getUTCDate() };
	}

	const fmtMoney = (n: number | null | undefined) =>
		new Intl.NumberFormat(isArabic ? 'ar-SA-u-nu-arab' : 'en-SA', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(n ?? 0);
	const fmtPct = (n: number | null | undefined) =>
		n === null || n === undefined || !isFinite(n) ? '—' : `${n.toFixed(2)}%`;
	const fmtDate = (iso: string | null) => {
		if (!iso) return '—';
		const d = new Date(iso);
		if (isNaN(d.getTime())) return iso;
		return d.toISOString().slice(0, 10);
	};

	onMount(loadBranches);

	async function loadBranches() {
		loadingBranches = true;
		try {
			const { data, error } = await supabase
				.from('erp_connections')
				.select('branch_id, branch_name')
				.eq('is_active', true)
				.order('branch_id', { ascending: true });
			if (error) throw error;
			branches = (data || []).filter((b: any) => b.branch_id != null);
			if (branches.length && selectedBranchId === null) selectedBranchId = branches[0].branch_id;
		} catch (err: any) {
			summaryError = err.message || ui('Failed to load branches', 'تعذر تحميل الفروع');
		} finally {
			loadingBranches = false;
		}
	}

	async function queryBridge(sql: string): Promise<any> {
		const res = await fetch('/api/erp-bridge-proxy', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ branchId: selectedBranchId, sql })
		});
		const body = await res.json().catch(() => ({}));
		if (!res.ok || body?.success === false) {
			throw new Error(body?.error || `ERP query failed (HTTP ${res.status})`);
		}
		return body;
	}

	function daySummarySql(dateStr: string) {
		return `
			SELECT
				SUM(CASE WHEN VoucherType='SI' THEN GrandTotal ELSE 0 END) AS GrossSales,
				SUM(CASE WHEN VoucherType='SR' THEN GrandTotal ELSE 0 END) AS ReturnAmount,
				SUM(CASE WHEN VoucherType='SI' THEN GrandTotal ELSE -GrandTotal END) AS NetSales,
				SUM(TotalProfit) AS NetGP,
				SUM(CASE WHEN VoucherType='SI' THEN 1 ELSE 0 END) AS SalesBills,
				SUM(CASE WHEN VoucherType='SR' THEN 1 ELSE 0 END) AS ReturnBills,
				SUM(CASE WHEN VoucherType='SI' THEN TotalDiscount ELSE 0 END) AS TotalDiscount
			FROM InvTransactionMaster
			WHERE CAST(TransactionDate AS DATE) = '${dateStr}' AND VoucherType IN ('SI','SR') AND IsActive = 1
		`;
	}

	function distinctItemsSql(dateStr: string) {
		return `
			SELECT COUNT(DISTINCT pb.ProductID) AS DistinctItems
			FROM InvTransactionDetails d
			INNER JOIN InvTransactionMaster m ON d.InvTransactionMasterID = m.InvTransactionMasterID AND d.BranchID = m.BranchID
			INNER JOIN ProductBatches pb ON d.ProductBatchID = pb.ProductBatchID
			WHERE CAST(m.TransactionDate AS DATE) = '${dateStr}' AND m.VoucherType = 'SI' AND m.IsActive = 1
		`;
	}

	function toDaySummary(row: any, distinctItems: number): DaySummary {
		return {
			netSales: Number(row?.NetSales) || 0,
			grossSales: Number(row?.GrossSales) || 0,
			returnAmount: Number(row?.ReturnAmount) || 0,
			netGP: Number(row?.NetGP) || 0,
			salesBills: Number(row?.SalesBills) || 0,
			returnBills: Number(row?.ReturnBills) || 0,
			totalDiscount: Number(row?.TotalDiscount) || 0,
			distinctItems
		};
	}

	async function runAnalysis() {
		if (!selectedBranchId) {
			summaryError = ui('Choose a branch first', 'اختر الفرع أولاً');
			return;
		}
		summaryError = '';
		loadingSummary = true;
		hasRunAnalysis = false;
		itemRows = [];
		hasAnalyzedItems = false;
		itemsError = '';
		noCostRows = [];
		try {
			selectedDateStr = toDateStr(selectedYear, selectedMonth, selectedDay);
			const prev = previousCalendarDay(selectedYear, selectedMonth, selectedDay);
			previousDateStr = toDateStr(prev.y, prev.m, prev.d);

			const [selRes, prevRes, distinctRes] = await Promise.all([
				queryBridge(daySummarySql(selectedDateStr)),
				queryBridge(daySummarySql(previousDateStr)),
				queryBridge(distinctItemsSql(selectedDateStr))
			]);

			selectedDaySummary = toDaySummary(selRes?.recordset?.[0], Number(distinctRes?.recordset?.[0]?.DistinctItems) || 0);
			previousDaySummary = toDaySummary(prevRes?.recordset?.[0], 0);
			hasRunAnalysis = true;
		} catch (err: any) {
			summaryError = err.message || ui('Analysis failed', 'فشل التحليل');
		} finally {
			loadingSummary = false;
		}
	}

	$: selectedGpPct = selectedDaySummary && selectedDaySummary.netSales
		? (selectedDaySummary.netGP / selectedDaySummary.netSales) * 100
		: null;
	$: previousGpPct = previousDaySummary && previousDaySummary.netSales
		? (previousDaySummary.netGP / previousDaySummary.netSales) * 100
		: null;
	$: salesChangePct = previousDaySummary && previousDaySummary.netSales
		? ((selectedDaySummary!.netSales - previousDaySummary.netSales) / previousDaySummary.netSales) * 100
		: null;
	$: avgBasket = selectedDaySummary && selectedDaySummary.salesBills
		? selectedDaySummary.netSales / selectedDaySummary.salesBills
		: 0;

	function setGpFilter(which: GpFilterMode) {
		gpFilterMode = which;
	}

	// Unit-aware, per-bill item query.
	//
	// Two problems had to be fixed here, both found by tracing real rows:
	//
	// 1. An item's Last Purchase Rate is quoted in whatever unit that purchase
	//    invoice actually used (a carton, a box of N, a single piece) — and the
	//    item can be *sold* in a different unit. So both sides must be converted
	//    to a common basis using the item's own conversion factor, from
	//    ProductUnits.MultiFactor where defined, falling back to
	//    ProductBatches.Unit2Qty/Unit3Qty.
	//
	// 2. Naively picking "the most recent Purchase Invoice line" to find which
	//    unit Last Purchase Rate is in is NOT reliable: verified on real data
	//    (barcode 6281018140887, "NADA FULL CREAM MILK 185 ML") that a branch's
	//    purchase history can contain a PI in a unit that isn't part of that
	//    item's documented packaging at all (no ProductUnits row, doesn't match
	//    Unit2/Unit3) — picking it produced a "cost" 18x too high and a nonsense
	//    -780% GP%. Fix: only ever pick an incoming-stock line whose unit we can
	//    actually resolve a conversion factor for; skip past undocumented-unit
	//    ones to the next one we can trust.
	//
	// 3. "Last Purchase Rate" isn't only found on Purchase Invoices. Checked
	//    every voucher type this ERP uses and confirmed which ones represent
	//    stock genuinely, confirmedly entering the branch, each with its own
	//    real per-unit rate: PI (Purchase Invoice), GRN (Goods Receipt Note),
	//    BTI (Branch Transfer In), MFR (Manufacture/production Receipt — the
	//    relevant one for prepared/bakery items). Deliberately excludes the
	//    "@"-prefixed types (@PO, @GRN, @BTO, @ST, @GRR) — those are drafts /
	//    pending records in this ERP (each pairs with a confirmed non-@
	//    counterpart with a similar row count), not confirmed stock movements,
	//    and PO/BTO/PR/GRR/DMG/EX/SH/SUB/SVI are either not stock-in at all or
	//    too ambiguous to trust without guessing.
	//
	// 4. BTI ("Branch Transfer In") is kept as a source, but demoted below
	//    Standard Purchase Price — verified on real data (barcode
	//    6281055001424, "HARVEST COCONUT WATER 330ML") that BTI.UnitPrice can
	//    disagree with the branch's own trusted cost fields (StdPurchasePrice,
	//    LastPurchaseRate, and the POS's own live CostPerItem all agreed at
	//    1.5 for that item) and even with itself across transfers over time
	//    (3.33 → 3.75 → 5.00/piece) while the item had zero Purchase Invoices
	//    ever — evidence BTI.UnitPrice can be an inter-branch transfer/billing
	//    price rather than a genuine acquisition cost. So PI/GRN/MFR are
	//    queried and trusted first (lpMain below); BTI is only used (lpBti) as
	//    a last resort when neither PI/GRN/MFR nor StdPurchasePrice exist.
	//
	// Full cost priority applied by the caller: PI/GRN/MFR → StdPurchasePrice
	// → BTI → none ("No Incoming Stock Record Found", never excluded).
	//
	// Reports one row per sold bill line (not aggregated across the day) so
	// Bill Number is meaningful and every number here is traceable back to one
	// specific transaction.
	function itemsSql(dateStr: string) {
		// NOTE: the ERP bridge only accepts statements that literally start with
		// SELECT — a leading WITH (CTE) gets rejected with 403 "Only SELECT
		// queries are allowed" (confirmed against the live bridge). Use a plain
		// derived subquery instead of a CTE for that reason.
		const knownUnitCheck = (unitIdExpr: string) => `
			(${unitIdExpr} IN (pb.PackingUnitID, pb.DefPurchaseUnitID, pb.DefSalesUnitID, pb.DefReportUnitID, pb.Unit2ID, pb.Unit3ID)
			 OR EXISTS (SELECT 1 FROM ProductUnits pu3 WHERE pu3.ProductBatchID = d.ProductBatchID AND pu3.UnitID = ${unitIdExpr}))
		`;
		const factorExpr = (multiFactorCol: string, unitIdExpr: string) => `
			COALESCE(${multiFactorCol},
				CASE WHEN ${unitIdExpr} IN (pb.PackingUnitID, pb.DefPurchaseUnitID, pb.DefSalesUnitID, pb.DefReportUnitID) THEN 1
				     WHEN ${unitIdExpr} = pb.Unit2ID THEN pb.Unit2Qty
				     WHEN ${unitIdExpr} = pb.Unit3ID THEN pb.Unit3Qty
				     END)
		`;
		return `
			SELECT
				m.VoucherPrefix, m.VoucherNumber, m.VoucherType,
				ISNULL(NULLIF(pb.MannualBarcode,''), CAST(pb.AutoBarcode AS varchar(50))) AS Barcode,
				p.ProductName,
				p.ItemNameinSecondLanguage AS ProductNameAr,
				d.UnitID AS SoldUnitID,
				uSold.UnitName AS SoldUnitName,
				${factorExpr('puSold.MultiFactor', 'd.UnitID')} AS SoldUnitFactor,
				lp.PurchaseUnitID,
				${factorExpr('puPurch.MultiFactor', 'lp.PurchaseUnitID')} AS PurchaseUnitFactor,
				lp.LastPurchaseRate,
				lp.LastPurchaseDate,
				lp.SourceVoucherType,
				lpBti.PurchaseUnitID AS BtiUnitID,
				${factorExpr('puBti.MultiFactor', 'lpBti.PurchaseUnitID')} AS BtiUnitFactor,
				lpBti.LastPurchaseRate AS BtiRate,
				lpBti.LastPurchaseDate AS BtiDate,
				pb.StdPurchasePrice,
				d.VatPercentage AS VatPercent,
				d.Quantity AS Qty,
				d.NetAmount AS NetAmount
			FROM InvTransactionDetails d
			INNER JOIN InvTransactionMaster m ON d.InvTransactionMasterID = m.InvTransactionMasterID AND d.BranchID = m.BranchID
			INNER JOIN ProductBatches pb ON d.ProductBatchID = pb.ProductBatchID
			INNER JOIN Products p ON pb.ProductID = p.ProductID
			LEFT JOIN UnitOfMeasures uSold ON uSold.UnitID = d.UnitID
			LEFT JOIN ProductUnits puSold ON puSold.ProductBatchID = d.ProductBatchID AND puSold.UnitID = d.UnitID
			OUTER APPLY (
				SELECT TOP 1 d2.UnitID AS PurchaseUnitID, d2.UnitPrice AS LastPurchaseRate,
				       m2.TransactionDate AS LastPurchaseDate, m2.VoucherType AS SourceVoucherType
				FROM InvTransactionDetails d2
				INNER JOIN InvTransactionMaster m2 ON d2.InvTransactionMasterID = m2.InvTransactionMasterID AND d2.BranchID = m2.BranchID
				WHERE d2.ProductBatchID = d.ProductBatchID AND m2.VoucherType IN ('PI','GRN','MFR') AND m2.IsActive = 1
				  AND ${knownUnitCheck('d2.UnitID')}
				ORDER BY m2.TransactionDate DESC, d2.InvTransactionDetailID DESC
			) lp
			LEFT JOIN ProductUnits puPurch ON puPurch.ProductBatchID = d.ProductBatchID AND puPurch.UnitID = lp.PurchaseUnitID
			OUTER APPLY (
				SELECT TOP 1 d3.UnitID AS PurchaseUnitID, d3.UnitPrice AS LastPurchaseRate, m3.TransactionDate AS LastPurchaseDate
				FROM InvTransactionDetails d3
				INNER JOIN InvTransactionMaster m3 ON d3.InvTransactionMasterID = m3.InvTransactionMasterID AND d3.BranchID = m3.BranchID
				WHERE d3.ProductBatchID = d.ProductBatchID AND m3.VoucherType = 'BTI' AND m3.IsActive = 1
				  AND ${knownUnitCheck('d3.UnitID')}
				ORDER BY m3.TransactionDate DESC, d3.InvTransactionDetailID DESC
			) lpBti
			LEFT JOIN ProductUnits puBti ON puBti.ProductBatchID = d.ProductBatchID AND puBti.UnitID = lpBti.PurchaseUnitID
			WHERE CAST(m.TransactionDate AS DATE) = '${dateStr}' AND m.VoucherType IN ('SI','SR') AND m.IsActive = 1
		`;
	}

	async function analyzeItems() {
		itemsError = '';
		if (!hasRunAnalysis || !selectedDateStr) {
			itemsError = ui('Run Analysis first', 'قم بتشغيل التحليل أولاً');
			return;
		}
		let threshold = NaN;
		if (gpFilterMode !== 'zeroCost') {
			threshold = parseFloat(gpFilterValue);
			if (isNaN(threshold)) {
				itemsError = ui('Enter a GP% value', 'أدخل نسبة الربح');
				return;
			}
		}

		loadingItems = true;
		try {
			const result = await queryBridge(itemsSql(selectedDateStr));
			const rows: ItemRow[] = (result?.recordset || [])
				.map((r: any) => {
					const soldQty = Number(r.Qty) || 0;
					const netAmount = Number(r.NetAmount) || 0; // NetAmount is VAT-inclusive (verified: matches RateWithTax, not UnitPrice)
					const soldRate = soldQty !== 0 ? netAmount / soldQty : 0; // as-sold rate, VAT-inclusive — shown as-is in the Sold Rate column
					const vatPercent = Number(r.VatPercent) || 0;
					// Per instruction: Sold Rate is displayed VAT-inclusive, so Cost must
					// be compared on the same VAT-inclusive basis — gross the (VAT-
					// exclusive) purchase-side cost up by the line's own VAT% rather than
					// stripping VAT out of the sold rate.
					const toInclVat = (exclVatAmount: number) => exclVatAmount * (1 + vatPercent / 100);

					// Convert a cost quoted in whatever unit its source used onto the
					// unit this bill line was actually sold in, using each item's own
					// conversion factor. A null factor means that unit isn't
					// documented for this item at all — treat as "can't verify", not
					// "no conversion needed" (defaulting a missing factor to 1 is
					// exactly what produced a false -780% GP% on a real item).
					const soldUnitFactor = r.SoldUnitFactor === null || r.SoldUnitFactor === undefined
						? null : Number(r.SoldUnitFactor);
					const toSoldUnitCost = (rate: any, sourceFactor: any) => {
						const r2 = rate === null || rate === undefined ? null : Number(rate);
						const f2 = sourceFactor === null || sourceFactor === undefined ? null : Number(sourceFactor);
						if (r2 === null || f2 === null || f2 === 0 || soldUnitFactor === null) return null;
						return (r2 * soldUnitFactor) / f2;
					};

					// Cost priority: PI/GRN/MFR (genuine purchase/production documents)
					// → Standard Purchase Price → BTI (branch transfer) → none.
					// BTI is deliberately last, not first: verified on real data that
					// BTI.UnitPrice can be an inter-branch transfer/billing rate that
					// disagrees with the branch's own trusted cost fields, whereas
					// StdPurchasePrice consistently matched the POS's own live
					// CostPerItem wherever checked. See itemsSql for the full trace.
					const rawPurchaseRate = r.LastPurchaseRate === null || r.LastPurchaseRate === undefined
						? null : Number(r.LastPurchaseRate);
					let cost = toSoldUnitCost(r.LastPurchaseRate, r.PurchaseUnitFactor);
					let costSource = cost !== null ? r.SourceVoucherType || null : null;

					if (cost === null) {
						const stdPurchasePrice = r.StdPurchasePrice === null || r.StdPurchasePrice === undefined
							? null : Number(r.StdPurchasePrice);
						// StdPurchasePrice is quoted in the item's base unit (factor 1 in
						// this item's own conversion scheme), so it still needs converting.
						if (stdPurchasePrice !== null && stdPurchasePrice > 0 && soldUnitFactor !== null) {
							cost = stdPurchasePrice * soldUnitFactor;
							costSource = 'StdPurchasePrice';
						}
					}

					if (cost === null) {
						cost = toSoldUnitCost(r.BtiRate, r.BtiUnitFactor);
						if (cost !== null) costSource = 'BTI';
					}

					// "Last Purchase Rate" and its date should reflect whichever
					// source actually supplied the cost, not always PI/GRN/MFR.
					let displayRate = rawPurchaseRate;
					let displayDate = r.LastPurchaseDate || null;
					if (costSource === 'StdPurchasePrice') {
						displayRate = r.StdPurchasePrice === null || r.StdPurchasePrice === undefined ? null : Number(r.StdPurchasePrice);
						displayDate = null; // StdPurchasePrice has no associated transaction date
					} else if (costSource === 'BTI') {
						displayRate = r.BtiRate === null || r.BtiRate === undefined ? null : Number(r.BtiRate);
						displayDate = r.BtiDate || null;
					}

					// The Cost column/GP calc use the VAT-inclusive cost; costSource,
					// displayRate/displayDate above stay tied to the raw (exclusive)
					// source rate for traceability of where the number came from.
					const costInclVat = cost !== null ? toInclVat(cost) : null;
					const gpAmount = costInclVat !== null ? soldRate - costInclVat : null;
					const gpPercent = costInclVat !== null && soldRate !== 0 ? ((soldRate - costInclVat) / soldRate) * 100 : null;

					const billNo = [r.VoucherPrefix, r.VoucherNumber].filter(Boolean).join('');
					return {
						billNo: billNo || '—',
						voucherType: r.VoucherType || '',
						barcode: r.Barcode || '—',
						productName: r.ProductName || '',
						productNameAr: r.ProductNameAr || '',
						unitName: r.SoldUnitName || String(r.SoldUnitID ?? '—'),
						soldQty,
						unitConversionQty: soldUnitFactor ?? 1,
						soldRate,
						lastPurchaseRate: displayRate,
						costSource,
						cost: costInclVat, // VAT-inclusive, to match the VAT-inclusive Sold Rate
						vatPercent,
						gpAmount,
						gpPercent,
						lastPurchaseDate: displayDate
					};
				})
				.filter((r: ItemRow) => r.soldQty !== 0);

			// "No incoming stock record" (cost === null) means we checked every
			// confirmed incoming-stock source (PI/GRN/BTI/MFR, in a unit we could
			// convert) and found nothing — not that we're excluding the item.
			// Per instruction, these are ALWAYS shown, independent of which GP%
			// filter is active, clearly flagged rather than dropped.
			noCostRows = rows
				.filter((r: ItemRow) => r.cost === null)
				.sort((a: ItemRow, b: ItemRow) => (b.soldQty * b.soldRate) - (a.soldQty * a.soldRate));

			const withCost = rows.filter((r: ItemRow) => r.cost !== null);

			if (gpFilterMode === 'zeroCost') {
				itemRows = withCost
					.filter((r: ItemRow) => r.cost === 0)
					.sort((a: ItemRow, b: ItemRow) => (b.soldQty * b.soldRate) - (a.soldQty * a.soldRate));
			} else {
				itemRows = withCost
					.filter((r: ItemRow) => r.gpPercent !== null)
					.filter((r: ItemRow) => (gpFilterMode === 'less' ? r.gpPercent! < threshold : r.gpPercent! > threshold))
					.sort((a: ItemRow, b: ItemRow) => (gpFilterMode === 'less' ? a.gpPercent! - b.gpPercent! : b.gpPercent! - a.gpPercent!));
			}
			hasAnalyzedItems = true;
		} catch (err: any) {
			itemsError = err.message || ui('Item analysis failed', 'فشل تحليل الأصناف');
		} finally {
			loadingItems = false;
		}
	}
</script>

<div class="sa-container" dir={isArabic ? 'rtl' : 'ltr'}>
	<div class="sa-filterbar">
		<div class="sa-field">
			<label>{ui('Branch', 'الفرع')}</label>
			<select bind:value={selectedBranchId} disabled={loadingBranches}>
				{#each branches as b (b.branch_id)}
					<option value={b.branch_id}>{b.branch_name}</option>
				{/each}
			</select>
		</div>
		<div class="sa-field">
			<label>{ui('Year', 'السنة')}</label>
			<select bind:value={selectedYear}>
				{#each YEARS as y}<option value={y}>{y}</option>{/each}
			</select>
		</div>
		<div class="sa-field">
			<label>{ui('Month', 'الشهر')}</label>
			<select bind:value={selectedMonth}>
				{#each MONTHS as m}<option value={m.n}>{ui(m.en, m.ar)}</option>{/each}
			</select>
		</div>
		<div class="sa-field">
			<label>{ui('Day', 'اليوم')}</label>
			<select bind:value={selectedDay}>
				{#each DAYS as d}<option value={d}>{d}</option>{/each}
			</select>
		</div>
		<button class="sa-btn sa-btn-primary" on:click={runAnalysis} disabled={loadingSummary || loadingBranches}>
			{loadingSummary ? ui('Running…', 'جاري التشغيل…') : ui('Run Analysis', 'تشغيل التحليل')}
		</button>
	</div>

	{#if summaryError}
		<div class="sa-error">{summaryError}</div>
	{/if}

	{#if hasRunAnalysis && selectedDaySummary && previousDaySummary}
		<div class="sa-summary-grid">
			<div class="sa-card">
				<div class="sa-card-label">{ui('Sales — Selected Day', 'المبيعات — اليوم المحدد')}</div>
				<div class="sa-card-value">{fmtMoney(selectedDaySummary.netSales)}</div>
				<div class="sa-card-sub">{selectedDateStr}</div>
			</div>
			<div class="sa-card sa-card-muted">
				<div class="sa-card-label">{ui('Sales — Previous Day', 'المبيعات — اليوم السابق')}</div>
				<div class="sa-card-value">{fmtMoney(previousDaySummary.netSales)}</div>
				<div class="sa-card-sub">{previousDateStr}</div>
			</div>
			<div class="sa-card sa-card-accent">
				<div class="sa-card-label">{ui('GP Amount — Selected Day', 'الربح الإجمالي — اليوم المحدد')}</div>
				<div class="sa-card-value">{fmtMoney(selectedDaySummary.netGP)}</div>
			</div>
			<div class="sa-card sa-card-muted">
				<div class="sa-card-label">{ui('GP Amount — Previous Day', 'الربح الإجمالي — اليوم السابق')}</div>
				<div class="sa-card-value">{fmtMoney(previousDaySummary.netGP)}</div>
			</div>
			<div class="sa-card sa-card-accent">
				<div class="sa-card-label">{ui('GP% — Selected Day', 'نسبة الربح — اليوم المحدد')}</div>
				<div class="sa-card-value">{fmtPct(selectedGpPct)}</div>
			</div>
			<div class="sa-card sa-card-muted">
				<div class="sa-card-label">{ui('GP% — Previous Day', 'نسبة الربح — اليوم السابق')}</div>
				<div class="sa-card-value">{fmtPct(previousGpPct)}</div>
			</div>

			<div class="sa-card sa-card-small">
				<div class="sa-card-label">{ui('Sales Bills', 'عدد الفواتير')}</div>
				<div class="sa-card-value-sm">{selectedDaySummary.salesBills.toLocaleString()}</div>
			</div>
			<div class="sa-card sa-card-small">
				<div class="sa-card-label">{ui('Avg Basket', 'متوسط الفاتورة')}</div>
				<div class="sa-card-value-sm">{fmtMoney(avgBasket)}</div>
			</div>
			<div class="sa-card sa-card-small">
				<div class="sa-card-label">{ui('Returns', 'المرتجعات')}</div>
				<div class="sa-card-value-sm">{fmtMoney(selectedDaySummary.returnAmount)} ({selectedDaySummary.returnBills})</div>
			</div>
			<div class="sa-card sa-card-small">
				<div class="sa-card-label">{ui('Discount', 'الخصم')}</div>
				<div class="sa-card-value-sm">{fmtMoney(selectedDaySummary.totalDiscount)}</div>
			</div>
			<div class="sa-card sa-card-small">
				<div class="sa-card-label">{ui('Distinct Items Sold', 'عدد الأصناف المباعة')}</div>
				<div class="sa-card-value-sm">{selectedDaySummary.distinctItems.toLocaleString()}</div>
			</div>
			<div class="sa-card sa-card-small">
				<div class="sa-card-label">{ui('Sales vs Previous Day', 'التغير عن اليوم السابق')}</div>
				<div class="sa-card-value-sm" class:sa-positive={salesChangePct !== null && salesChangePct >= 0} class:sa-negative={salesChangePct !== null && salesChangePct < 0}>
					{salesChangePct === null ? '—' : `${salesChangePct >= 0 ? '+' : ''}${salesChangePct.toFixed(1)}%`}
				</div>
			</div>
		</div>

		<div class="sa-gp-filter">
			<label class="sa-checkbox">
				<input type="checkbox" checked={gpFilterMode === 'less'} on:change={() => setGpFilter('less')} />
				{ui('Less Than', 'أقل من')}
			</label>
			<label class="sa-checkbox">
				<input type="checkbox" checked={gpFilterMode === 'more'} on:change={() => setGpFilter('more')} />
				{ui('More Than', 'أكثر من')}
			</label>
			<label class="sa-checkbox">
				<input type="checkbox" checked={gpFilterMode === 'zeroCost'} on:change={() => setGpFilter('zeroCost')} />
				{ui('0 Cost', 'تكلفة صفر')}
			</label>
			<input
				class="sa-gp-input"
				type="number"
				step="0.01"
				placeholder={ui('GP %', 'نسبة الربح %')}
				bind:value={gpFilterValue}
				disabled={gpFilterMode === 'zeroCost'}
			/>
			<button class="sa-btn sa-btn-secondary" on:click={analyzeItems} disabled={loadingItems}>
				{loadingItems ? ui('Analyzing…', 'جاري التحليل…') : ui('Analyze', 'تحليل')}
			</button>
		</div>

		{#if itemsError}
			<div class="sa-error">{itemsError}</div>
		{/if}

		{#if hasAnalyzedItems}
			<div class="sa-table-wrap">
				<div class="sa-table-meta">
					{ui('Matching bill lines', 'سطور الفواتير المطابقة')}: <strong>{itemRows.length}</strong>
				</div>
				{#if itemRows.length === 0}
					<div class="sa-empty">{ui('No bill lines matched this filter.', 'لا توجد سطور فواتير مطابقة لهذا الفلتر.')}</div>
				{:else}
				<div class="sa-table-scroll">
				<table class="sa-table">
					<thead>
						<tr>
							<th>{ui('Bill No', 'رقم الفاتورة')}</th>
							<th>{ui('Type', 'النوع')}</th>
							<th>{ui('Barcode', 'الباركود')}</th>
							<th>{ui('Item Name', 'اسم الصنف')}</th>
							<th>{ui('Unit', 'الوحدة')}</th>
							<th class="num">{ui('Sold Qty', 'الكمية المباعة')}</th>
							<th class="num">{ui('Unit Conv. Qty', 'كمية تحويل الوحدة')}</th>
							<th class="num">{ui('Sold Rate', 'سعر البيع')}</th>
							<th class="num">{ui('Last Purchase Rate', 'سعر آخر شراء')}</th>
							<th>{ui('Cost Source', 'مصدر التكلفة')}</th>
							<th class="num">{ui('Cost', 'التكلفة')}</th>
							<th class="num">{ui('VAT %', 'ضريبة القيمة المضافة %')}</th>
							<th class="num">{ui('GP Amount', 'مبلغ الربح')}</th>
							<th class="num">{ui('GP %', 'نسبة الربح')}</th>
							<th>{ui('Last Purchase Date', 'تاريخ آخر شراء')}</th>
						</tr>
					</thead>
					<tbody>
						{#each itemRows as row}
							<tr>
								<td>{row.billNo}</td>
								<td>{row.voucherType}</td>
								<td>{row.barcode}</td>
								<td dir={isArabic ? 'rtl' : 'ltr'}>{displayName(row)}</td>
								<td>{row.unitName}</td>
								<td class="num">{row.soldQty}</td>
								<td class="num">{row.unitConversionQty}</td>
								<td class="num">{fmtMoney(row.soldRate)}</td>
								<td class="num">{row.lastPurchaseRate === null ? '—' : fmtMoney(row.lastPurchaseRate)}</td>
								<td>{row.costSource || '—'}</td>
								<td class="num">{row.cost === null ? '—' : fmtMoney(row.cost)}</td>
								<td class="num">{row.vatPercent.toFixed(2)}%</td>
								<td class="num" class:sa-negative={row.gpAmount !== null && row.gpAmount < 0}>{row.gpAmount === null ? '—' : fmtMoney(row.gpAmount)}</td>
								<td class="num" class:sa-negative={row.gpPercent !== null && row.gpPercent < 0}>{fmtPct(row.gpPercent)}</td>
								<td>{fmtDate(row.lastPurchaseDate)}</td>
							</tr>
						{/each}
					</tbody>
				</table>
				</div>
				{/if}
			</div>

			<!-- Always shown, regardless of the active GP% filter: bill lines where no
			     confirmed incoming-stock record (PI/GRN/BTI/MFR) could be found in a
			     unit we can convert. Never excluded from the report, per instruction. -->
			{#if noCostRows.length > 0}
				<div class="sa-table-wrap sa-nocost-wrap">
					<div class="sa-table-meta">
						⚠ {ui('No Incoming Stock Record Found', 'لم يتم العثور على سجل توريد للمخزون')}: <strong>{noCostRows.length}</strong>
						<span class="sa-table-meta-note">
							— {ui('sold that day with no PI / GRN / BTI / MFR record in a convertible unit', 'مباعة في ذلك اليوم دون سجل شراء أو تحويل أو تصنيع بوحدة قابلة للتحويل')}
						</span>
					</div>
					<div class="sa-table-scroll">
					<table class="sa-table">
						<thead>
							<tr>
								<th>{ui('Bill No', 'رقم الفاتورة')}</th>
								<th>{ui('Type', 'النوع')}</th>
								<th>{ui('Barcode', 'الباركود')}</th>
								<th>{ui('Item Name', 'اسم الصنف')}</th>
								<th>{ui('Unit', 'الوحدة')}</th>
								<th class="num">{ui('Sold Qty', 'الكمية المباعة')}</th>
								<th class="num">{ui('Sold Rate', 'سعر البيع')}</th>
								<th class="num">{ui('VAT %', 'ضريبة القيمة المضافة %')}</th>
								<th>{ui('Cost / GP', 'التكلفة / الربح')}</th>
							</tr>
						</thead>
						<tbody>
							{#each noCostRows as row}
								<tr>
									<td>{row.billNo}</td>
									<td>{row.voucherType}</td>
									<td>{row.barcode}</td>
									<td dir={isArabic ? 'rtl' : 'ltr'}>{displayName(row)}</td>
									<td>{row.unitName}</td>
									<td class="num">{row.soldQty}</td>
									<td class="num">{fmtMoney(row.soldRate)}</td>
									<td class="num">{row.vatPercent.toFixed(2)}%</td>
									<td class="sa-nocost-label">{ui('No Incoming Stock Record Found', 'لم يتم العثور على سجل توريد للمخزون')}</td>
								</tr>
							{/each}
						</tbody>
					</table>
					</div>
				</div>
			{/if}
		{/if}
	{:else if !loadingSummary && !summaryError}
		<div class="sa-placeholder">{ui('Choose a branch and date, then press Run Analysis.', 'اختر الفرع والتاريخ ثم اضغط تشغيل التحليل.')}</div>
	{/if}
</div>

<style>
	.sa-container {
		padding: 1rem;
		width: 100%;
		height: 100%;
		background: #f3f4f6;
		overflow-y: auto;
		box-sizing: border-box;
	}

	.sa-filterbar {
		display: flex;
		flex-wrap: wrap;
		align-items: flex-end;
		gap: 0.75rem;
		background: white;
		border-radius: 12px;
		padding: 1rem;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
		margin-bottom: 1rem;
	}

	.sa-field {
		display: flex;
		flex-direction: column;
		gap: 0.25rem;
		min-width: 140px;
	}

	.sa-field label {
		font-size: 0.75rem;
		font-weight: 600;
		color: #6b7280;
		text-transform: uppercase;
	}

	.sa-field select,
	.sa-gp-input {
		padding: 0.5rem 0.6rem;
		border: 1px solid #d1d5db;
		border-radius: 8px;
		font-size: 0.9rem;
		background: white;
	}

	.sa-btn {
		padding: 0.6rem 1.2rem;
		border: none;
		border-radius: 8px;
		font-weight: 600;
		cursor: pointer;
		font-size: 0.9rem;
	}
	.sa-btn:disabled { opacity: 0.6; cursor: not-allowed; }

	.sa-btn-primary { background: #10b981; color: white; }
	.sa-btn-primary:hover:not(:disabled) { background: #059669; }

	.sa-btn-secondary { background: #4f46e5; color: white; }
	.sa-btn-secondary:hover:not(:disabled) { background: #4338ca; }

	.sa-error {
		background: #fef2f2;
		color: #b91c1c;
		border: 1px solid #fecaca;
		padding: 0.75rem 1rem;
		border-radius: 8px;
		margin-bottom: 1rem;
		font-size: 0.9rem;
	}

	.sa-placeholder {
		text-align: center;
		color: #9ca3af;
		padding: 3rem 1rem;
		font-size: 0.95rem;
	}

	.sa-summary-grid {
		display: grid;
		grid-template-columns: repeat(6, minmax(140px, 1fr));
		gap: 0.75rem;
		margin-bottom: 1rem;
	}
	@media (max-width: 1100px) {
		.sa-summary-grid { grid-template-columns: repeat(3, minmax(140px, 1fr)); }
	}
	@media (max-width: 600px) {
		.sa-summary-grid { grid-template-columns: repeat(2, minmax(120px, 1fr)); }
	}

	.sa-card {
		background: white;
		border-radius: 12px;
		padding: 0.9rem 1rem;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
		border: 2px solid #10b981;
	}
	.sa-card-muted { border-color: #d1d5db; }
	.sa-card-accent { border-color: #6366f1; }
	.sa-card-small { padding: 0.6rem 0.8rem; }

	.sa-card-label {
		font-size: 0.68rem;
		font-weight: 700;
		text-transform: uppercase;
		color: #6b7280;
		margin-bottom: 0.35rem;
	}
	.sa-card-value { font-size: 1.25rem; font-weight: 800; color: #111827; }
	.sa-card-value-sm { font-size: 1rem; font-weight: 700; color: #111827; }
	.sa-card-sub { font-size: 0.7rem; color: #9ca3af; margin-top: 0.25rem; }

	.sa-positive { color: #059669 !important; }
	.sa-negative { color: #dc2626 !important; }

	.sa-gp-filter {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: 1rem;
		background: white;
		border-radius: 12px;
		padding: 1rem;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
		margin-bottom: 1rem;
	}

	.sa-checkbox {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		font-size: 0.9rem;
		font-weight: 600;
		color: #374151;
		cursor: pointer;
	}

	.sa-gp-input { width: 140px; }
	.sa-gp-input:disabled { background: #f3f4f6; color: #9ca3af; }

	.sa-table-wrap {
		background: white;
		border-radius: 12px;
		padding: 1rem;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
	}

	.sa-table-meta {
		font-size: 0.85rem;
		color: #6b7280;
		margin-bottom: 0.6rem;
	}

	.sa-table-meta-note {
		color: #b45309;
	}

	.sa-nocost-wrap {
		margin-top: 1rem;
		border: 1px solid #fbbf24;
	}

	.sa-nocost-label {
		color: #b45309;
		font-weight: 600;
		white-space: nowrap;
	}

	.sa-empty {
		text-align: center;
		color: #9ca3af;
		padding: 2rem;
	}

	.sa-table-scroll {
		overflow-x: auto;
	}

	.sa-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.85rem;
	}
	.sa-table th, .sa-table td {
		padding: 0.5rem 0.6rem;
		border-bottom: 1px solid #e5e7eb;
		text-align: start;
		white-space: nowrap;
	}
	.sa-table th {
		background: #f9fafb;
		font-weight: 700;
		color: #374151;
		position: sticky;
		top: 0;
	}
	.sa-table td.num, .sa-table th.num { text-align: end; }
	.sa-table tbody tr:hover { background: #f9fafb; }
</style>
