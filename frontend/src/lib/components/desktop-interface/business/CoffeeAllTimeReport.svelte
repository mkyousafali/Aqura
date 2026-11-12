<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { _ as t, currentLocale } from '$lib/i18n';
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';
	import { COFFEE_COUNTER, COFFEE_PURCHASE_BRANCH_ID, COFFEE_INITIAL_CAPITAL, counterRentPercentage, type BusinessCounterProfile } from '$lib/types/businessCounter';
	import type { BakeryBranch, BakeryExpenseBranch } from '$lib/types/bakery';
	import type { CoffeeAllTimeSale, CoffeeAllTimeInputVat, CoffeeAllTimeResponse, CoffeeVendorPayments } from '$lib/types/coffeeAllTime';
	import type { CoffeeBranchStockValue } from '$lib/types/coffeeStock';
	import type { CoffeeOtherExpenseTotals } from '$lib/types/coffeeOtherExpenses';

	export let profile: BusinessCounterProfile = COFFEE_COUNTER;
	const isCoffee = profile.id === 'coffee-counter';
	export let windowId: string;
	export let rentPercentages: Record<string, number | undefined> = {};
	export let otherPaymentsRevision = 0;
	const rentStartDateLabel = (isCoffee ? profile.rentIncreaseDate : profile.reportStartDate)?.split('-').reverse().join('-') || '—';
	let branches: BakeryBranch[] = [];
	let inputVatBranch: BakeryBranch | null = null;
	let expenseBranches: BakeryExpenseBranch[] = [];
	let sales: CoffeeAllTimeSale[] = [];
	let purchaseVat: CoffeeAllTimeInputVat[] = [];
	let vendorPayments: CoffeeVendorPayments | null = null;
	let otherPaymentsTotal: number | null = null;
	let otherExpenseTotals: CoffeeOtherExpenseTotals | null = null;
	let stockValues: CoffeeBranchStockValue[] = [];
	let mounted = false;
	let lastOtherPaymentsRevision = otherPaymentsRevision;
	let otherPaymentReadVersion = 0;
	let otherPaymentController: AbortController | null = null;
	let asOfDate = '';
	let selectedBranch = '';
	let loading = true;
	let failed = false;
	let controller: AbortController | null = null;
	$: visibleBranches = branches.filter(branch => !selectedBranch || branch.id === selectedBranch);
	$: failedBranches = visibleBranches.filter(branch => branch.status !== 'loaded');
	$: salesReady = !loading && !failed && visibleBranches.length > 0 && failedBranches.length === 0;
	$: needsPurchaseVat = !isCoffee || !selectedBranch || selectedBranch === COFFEE_PURCHASE_BRANCH_ID;
	$: inputReady = isCoffee ? !needsPurchaseVat || inputVatBranch?.status === 'loaded'
		: visibleBranches.length > 0 && visibleBranches.every(branch => expenseBranches.some(expense => expense.id === branch.id && expense.status === 'loaded'));
	$: visibleSales = sales.filter(row => !selectedBranch || row.branchId === selectedBranch);
	$: visiblePurchaseVat = needsPurchaseVat ? purchaseVat.filter(row => !selectedBranch || (row.branchId || COFFEE_PURCHASE_BRANCH_ID) === selectedBranch) : [];
	$: paymentAmount = isCoffee && needsPurchaseVat ? vendorPayments?.total ?? null : 0;
	$: paymentReportDateLabel = (vendorPayments?.asOfDate || asOfDate).split('-').reverse().join('-');
	$: otherPaymentAmount = selectedBranch ? 0 : otherPaymentsTotal;
	$: scopedOtherExpenses = selectedBranch ? { sales: 0, operator: 0 } : otherExpenseTotals;
	$: visibleStockValues = stockValues.filter(item => !selectedBranch || item.branch.id === selectedBranch);
	$: stockComplete = !loading && !failed && visibleBranches.length > 0 && visibleBranches.every(branch =>
		visibleStockValues.some(item => item.branch.id === branch.id && item.branch.status === 'loaded' && item.value !== null));
	$: stockValue = stockComplete ? roundMoney(visibleStockValues.reduce((sum, item) => sum + (item.value ?? 0), 0)) : null;
	$: totals = buildTotals(visibleSales, visiblePurchaseVat, rentPercentages, selectedBranch, salesReady, inputReady, paymentAmount, otherPaymentAmount, scopedOtherExpenses);
	$: if (mounted && otherPaymentsRevision !== lastOtherPaymentsRevision) {
		lastOtherPaymentsRevision = otherPaymentsRevision;
		void loadOtherPaymentTotal();
	}
	$: money = new Intl.NumberFormat($currentLocale === 'ar' ? 'ar-SA' : 'en-SA', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

	function roundMoney(value: number) {
		return Math.sign(value) * Math.round((Math.abs(value) + Number.EPSILON) * 100) / 100;
	}

	function display(value: number | null) {
		return value === null ? '—' : money.format(value);
	}

	function buildTotals(records: CoffeeAllTimeSale[], inputRecords: CoffeeAllTimeInputVat[], rates: Record<string, number | undefined>, scope: string, ready: boolean, vatReady: boolean, payments: number | null, otherPayments: number | null, otherExpenses: CoffeeOtherExpenseTotals | null) {
		const days = new Map<string, { sales: number; outputVat: number }>();
		for (const record of records) {
			const day = days.get(record.date) || { sales: 0, outputVat: 0 };
			day.sales += record.salesIncludingVat;
			day.outputVat += record.outputVat;
			days.set(record.date, day);
		}
		let salesIncludingVat = 0, salesExcludingVat = 0, outputVat = 0, rent = 0, afterRent = 0;
		let validRent = true;
		for (const [date, day] of days) {
			// Follow Sales & Rent's daily rounding and shared percentage overrides.
			const gross = roundMoney(day.sales);
			const tax = roundMoney(day.outputVat);
			const beforeVat = roundMoney(gross - tax);
			const key = `${scope || 'all'}|${date}`;
			const rate = Object.prototype.hasOwnProperty.call(rates, key) ? rates[key] : counterRentPercentage(profile, date);
			salesIncludingVat += gross;
			salesExcludingVat += beforeVat;
			outputVat += tax;
			if (beforeVat === 0) continue;
			if (typeof rate !== 'number' || !Number.isFinite(rate) || rate < 0 || rate > 100) { validRent = false; continue; }
			const dailyRent = roundMoney(beforeVat * rate / 100);
			rent += dailyRent;
			afterRent += roundMoney(beforeVat - dailyRent);
		}
		const inputDays = new Map<string, number>();
		const expenseDays = new Map<string, number>();
		for (const record of inputRecords) {
			inputDays.set(record.date, (inputDays.get(record.date) ?? 0) + record.inputVat);
			expenseDays.set(record.date, (expenseDays.get(record.date) ?? 0) + record.expensesExcludingVat);
		}
		const inputVat = roundMoney([...inputDays.values()].reduce((sum, value) => sum + roundMoney(value), 0));
		// Match monthly Operators Profit: VAT is reimbursed in receivables and
		// included in expenses. Capital and payment settlements do not affect profit.
		const expenseAmount = [...expenseDays.entries()].reduce((sum, [date, value]) =>
			sum + roundMoney(value + roundMoney(inputDays.get(date) ?? 0)), 0);
		const expensesIncludingVat = vatReady && Number.isFinite(expenseAmount) ? roundMoney(expenseAmount) : null;
		const operatorReceivable = ready && validRent && vatReady ? roundMoney(afterRent + inputVat) : null;
		const operatorsProfit = operatorReceivable !== null && expensesIncludingVat !== null && otherExpenses !== null
			? roundMoney(operatorReceivable - expensesIncludingVat - otherExpenses.operator) : null;
		// Capital belongs to the counter as a whole and is added once, rather
		// than being repeated per day or assigned to an unspecified branch.
		const initialCapital = isCoffee && !scope ? COFFEE_INITIAL_CAPITAL : 0;
		const payableBeforePayments = ready && validRent && vatReady ? roundMoney(afterRent + inputVat + initialCapital) : null;
		return {
			salesIncludingVat: ready ? roundMoney(salesIncludingVat) : null,
			salesExcludingVat: ready ? roundMoney(salesExcludingVat) : null,
			outputVat: ready ? roundMoney(outputVat) : null,
			rent: ready && validRent ? roundMoney(rent) : null,
			inputVat: vatReady ? inputVat : null,
			initialCapital,
			payableBeforePayments,
			vendorPayments: payments,
			otherPayments,
			salesPaidExpenses: otherExpenses?.sales ?? null,
			operatorPaidExpenses: otherExpenses?.operator ?? null,
			expensesIncludingVat,
			operatorsProfit,
			netPayable: payableBeforePayments !== null && payments !== null && otherPayments !== null && otherExpenses !== null
				? roundMoney(payableBeforePayments - payments - otherPayments - otherExpenses.sales) : null,
			validRent
		};
	}

	function parseExpenseTotals(value: unknown): CoffeeOtherExpenseTotals | null {
		if (!value || typeof value !== 'object') return null;
		const amounts = value as CoffeeOtherExpenseTotals;
		return [amounts.sales, amounts.operator].every(amount => typeof amount === 'number' && Number.isFinite(amount) && amount >= 0)
			? { sales: amounts.sales, operator: amounts.operator } : null;
	}

	async function loadOtherPaymentTotal() {
		const version = ++otherPaymentReadVersion;
		otherPaymentController?.abort();
		const pending = new AbortController();
		otherPaymentController = pending;
		otherPaymentsTotal = null;
		otherExpenseTotals = null;
		try {
			async function readSummary(endpoint: string) {
				try {
					const response = await authenticatedFetch(endpoint, { signal: pending.signal });
					const result = await response.json();
					return response.ok && result.success ? result : null;
				} catch { return null; }
			}
			const [result, expenseResult] = await Promise.all([
				readSummary(`/api/${profile.id}-other-payments?summary=1`),
				readSummary(`/api/${profile.id}-other-expenses?summary=1`)
			]);
			if (pending.signal.aborted || version !== otherPaymentReadVersion) return;
			if (asOfDate && ((result && result.asOfDate !== asOfDate) || (expenseResult && expenseResult.asOfDate !== asOfDate))) { void loadReport(); return; }
			otherPaymentsTotal = typeof result?.total === 'number' && Number.isFinite(result.total) && result.total >= 0 ? result.total : null;
			otherExpenseTotals = parseExpenseTotals(expenseResult?.totals);
		} catch {
			if (!pending.signal.aborted && version === otherPaymentReadVersion) otherPaymentsTotal = null;
		}
	}

	async function loadReport() {
		const totalVersion = ++otherPaymentReadVersion;
		otherPaymentController?.abort();
		controller?.abort();
		const pending = new AbortController();
		controller = pending;
		loading = true;
		failed = false;
		branches = [];
		inputVatBranch = null;
		expenseBranches = [];
		sales = [];
		purchaseVat = [];
		vendorPayments = null;
		otherPaymentsTotal = null;
		otherExpenseTotals = null;
		stockValues = [];
		try {
			const response = await authenticatedFetch(`/api/${profile.id}-all-time`, { signal: pending.signal });
			const result: CoffeeAllTimeResponse = await response.json();
			if (!response.ok || !result.success || !Array.isArray(result.branches) || !Array.isArray(result.dailySales) ||
				!Array.isArray(result.dailyInputVat) || !Array.isArray(result.stockValues) || (isCoffee && (!result.inputVatBranch || !result.vendorPayments)) || (!isCoffee && !Array.isArray(result.expenseBranches))) throw new Error('Unable to load all-time report');
			if (pending.signal.aborted) return;
			branches = result.branches;
			inputVatBranch = result.inputVatBranch;
			expenseBranches = result.expenseBranches || [];
			sales = result.dailySales;
			purchaseVat = result.dailyInputVat;
			vendorPayments = result.vendorPayments;
			stockValues = result.stockValues;
			if (totalVersion === otherPaymentReadVersion) {
				otherPaymentsTotal = typeof result.otherPaymentsTotal === 'number' && Number.isFinite(result.otherPaymentsTotal) && result.otherPaymentsTotal >= 0 ? result.otherPaymentsTotal : null;
				otherExpenseTotals = parseExpenseTotals(result.otherExpenseTotals);
			}
			asOfDate = result.asOfDate;
			if (!branches.some(branch => branch.id === selectedBranch)) selectedBranch = '';
		} catch {
			if (!pending.signal.aborted) failed = true;
		} finally {
			if (!pending.signal.aborted) loading = false;
		}
	}

	onMount(() => { lastOtherPaymentsRevision = otherPaymentsRevision; mounted = true; void loadReport(); });
	onDestroy(() => { mounted = false; controller?.abort(); otherPaymentController?.abort(); });
</script>

<div class="all-time-report">
	<div class="toolbar">
		<div>
			<h2>{$t(`${profile.localeKey}.allTimeReport`)}</h2>
			<p>{$t(`${profile.localeKey}.allTime.through`)} <bdi>{asOfDate || '—'}</bdi></p>
		</div>
		<div class="controls">
			<label for={`${windowId}-all-time-branch`}>{$t(`${profile.localeKey}.branch`)}</label>
			<select id={`${windowId}-all-time-branch`} bind:value={selectedBranch} disabled={loading || failed}>
				<option value="">{$t(`${profile.localeKey}.allBranches`)}</option>
				{#each branches as branch (branch.id)}
					<option value={branch.id}>{$currentLocale === 'ar' ? branch.nameAr : branch.nameEn}</option>
				{/each}
			</select>
			<button type="button" on:click={loadReport} disabled={loading}>{$t(`${profile.localeKey}.refresh`)}</button>
		</div>
	</div>
	{#if loading}
		<p class="message" role="status">{$t(`${profile.localeKey}.allTime.loading`)}</p>
	{:else if failed}
		<p class="message error" role="alert">{$t(`${profile.localeKey}.allTime.failed`)}</p>
	{:else if branches.length === 0}
		<p class="message">{$t(`${profile.localeKey}.noBranches`)}</p>
	{:else}
		{#each failedBranches as branch (branch.id)}
			<p class="message error" role="alert">{$currentLocale === 'ar' ? branch.nameAr : branch.nameEn}: {$t(`${profile.localeKey}.salesBranchStatus.${branch.status}`)}</p>
		{/each}
		{#if !salesReady}<p class="message error">{$t(`${profile.localeKey}.allTime.incomplete`)}</p>{/if}
		{#if !inputReady}<p class="message error" role="alert">{$t(`${profile.localeKey}.allTime.inputVatFailed`)}</p>{/if}
		{#if paymentAmount === null}<p class="message error" role="alert">{$t(`${profile.localeKey}.allTime.paymentsFailed`)}</p>{/if}
		{#if otherPaymentAmount === null}<p class="message error" role="alert">{$t(`${profile.localeKey}.allTime.otherPaymentsFailed`)}</p>{/if}
		{#if scopedOtherExpenses === null}<p class="message error" role="alert">{$t(`${profile.localeKey}.otherExpensesReport.failed`)}</p>{/if}
		{#if !totals.validRent}<p class="message error">{$t(`${profile.localeKey}.rentReport.percentageHelp`)}</p>{/if}
		<div class="summary">
			<div><span>{$t(`${profile.localeKey}.rentReport.salesIncludingVat`)}</span><strong><bdi>{display(totals.salesIncludingVat)}</bdi></strong></div>
			<div><span>{$t(`${profile.localeKey}.rentReport.salesExcludingVat`)}</span><strong><bdi>{display(totals.salesExcludingVat)}</bdi></strong></div>
			<div>
				<span>{$t(`${profile.localeKey}.rentReport.rentAmount`)}</span>
				<small>{$t(`${profile.localeKey}.allTime.rentStartDate`)} <bdi>{rentStartDateLabel}</bdi></small>
				<strong><bdi>{display(totals.rent)}</bdi></strong>
			</div>
			{#if isCoffee}<div><span>{$t(`${profile.localeKey}.allTime.initialCapital`)}</span><strong><bdi>{display(totals.initialCapital)}</bdi></strong></div>{/if}
			<div>
				<span>{$t(`${profile.localeKey}.allTime.payableBeforePayments`)}</span>
				<strong><bdi>{display(totals.payableBeforePayments)}</bdi></strong>
				<small>{$t(`${profile.localeKey}.allTime.payableBeforePaymentsNote`)}</small>
			</div>
			{#if isCoffee}<div><span>{$t(`${profile.localeKey}.allTime.vendorPayments`)}</span><strong><bdi>{display(totals.vendorPayments)}</bdi></strong></div>{/if}
			<div><span>{$t(`${profile.localeKey}.otherPaymentsReport.total`)}</span><strong><bdi>{display(totals.otherPayments)}</bdi></strong></div>
			<div><span>{$t(`${profile.localeKey}.otherExpensesReport.salesTotal`)}</span><strong><bdi>{display(totals.salesPaidExpenses)}</bdi></strong></div>
			<div><span>{$t(`${profile.localeKey}.otherExpensesReport.operatorTotal`)}</span><strong><bdi>{display(totals.operatorPaidExpenses)}</bdi></strong></div>
			{#if !isCoffee}
				<div>
					<span>{$t('bakery.allTime.erpExpenses')}</span>
					<strong><bdi>{display(totals.expensesIncludingVat)}</bdi></strong>
					<small>{$t('bakery.allTime.erpExpensesNote')}</small>
				</div>
			{/if}
			<div><span>{$t(`${profile.localeKey}.allTime.payableAfterPayments`)}</span><strong><bdi>{display(totals.netPayable)}</bdi></strong></div>
			<div>
				<span>{$t(`${profile.localeKey}.allTime.operatorsProfit`)}</span>
				<strong class:loss={totals.operatorsProfit !== null && totals.operatorsProfit < 0}><bdi>{display(totals.operatorsProfit)}</bdi></strong>
				<small>{$t(`${profile.localeKey}.allTime.operatorsProfitNote`)}</small>
			</div>
			{#if isCoffee}<div>
				<span>{$t(`${profile.localeKey}.allTime.stockValue`)}</span>
				<strong><bdi>{display(stockValue)}</bdi></strong>
				<small>{$t(`${profile.localeKey}.allTime.stockBasis`)}</small>
			</div>{/if}
		</div>
		{#if isCoffee}<div class="stock-section">
			<h3>{$t(`${profile.localeKey}.allTime.stockByBranch`)}</h3>
			<table class="stock-breakdown">
				<thead><tr><th scope="col">{$t(`${profile.localeKey}.branch`)}</th><th scope="col" class="number">{$t(`${profile.localeKey}.allTime.stockValue`)}</th></tr></thead>
				<tbody>
					{#each visibleBranches as branch (branch.id)}
						{@const stock = visibleStockValues.find(item => item.branch.id === branch.id)}
						<tr>
							<th scope="row">{$currentLocale === 'ar' ? branch.nameAr : branch.nameEn}</th>
							<td class="number">
								<bdi>{display(stock?.value ?? null)}</bdi>
								{#if !stock || stock.branch.status !== 'loaded'}<small>{$t(`${profile.localeKey}.allTime.stockUnavailable`)}</small>
								{:else if stock.value === null}<small>{$t(`${profile.localeKey}.allTime.stockIncomplete`)}</small>{/if}
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
			{#if !stockComplete}<p class="note">{$t(`${profile.localeKey}.allTime.stockTotalIncomplete`)}</p>{/if}
		</div>{/if}
		<div class="vat-details">
			<p>{$t(`${profile.localeKey}.outputVat`)}: <strong><bdi>{display(totals.outputVat)}</bdi></strong></p>
			<p>{$t(`${profile.localeKey}.inputVat`)}: <strong><bdi>{display(totals.inputVat)}</bdi></strong></p>
			<p>{$t(`${profile.localeKey}.profitReport.expenses`)}: <strong><bdi>{display(totals.expensesIncludingVat)}</bdi></strong></p>
		</div>
		<p class="note">{$t(`${profile.localeKey}.allTime.note`)}</p>
		{#if isCoffee}<p class="note">{$t(`${profile.localeKey}.allTime.capitalNote`)}</p>{/if}
		{#if isCoffee}<p class="note">{$t(`${profile.localeKey}.allTime.paymentsNote`, { date: paymentReportDateLabel })}</p>{/if}
		<p class="note">{$t(`${profile.localeKey}.otherPaymentsReport.note`)}</p>
		<p class="note">{$t(`${profile.localeKey}.otherExpensesReport.note`)}</p>
		<p class="note">{$t(`${profile.localeKey}.allTime.formula`)}</p>
	{/if}
</div>

<style>
	.all-time-report { height: 100%; min-height: 0; overflow: auto; text-align: start; }
	.toolbar, .controls { display: flex; align-items: center; flex-wrap: wrap; gap: 12px; }
	.toolbar { justify-content: space-between; margin-bottom: 20px; }
	h2 { margin: 0 0 6px; font-size: 20px; font-weight: 600; }
	.toolbar p, .note { color: #64748b; font-size: 12px; }
	.toolbar p { margin: 0; }
	.controls { font-size: 13px; }
	select, button { padding: 9px 12px; border: 1px solid #cbd5e1; border-radius: 8px; background: white; color: #1e293b; font: inherit; }
	button { cursor: pointer; color: #047857; font-weight: 600; }
	button:disabled { cursor: wait; opacity: 0.6; }
	select:focus-visible, button:focus-visible { outline: 2px solid #059669; outline-offset: 2px; }
	.summary { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; }
	.summary div { padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px; background: #f8fafc; }
	.summary span { display: block; font-size: 12px; color: #64748b; }
	.summary small { display: block; margin-top: 6px; font-size: 12px; color: #64748b; }
	.summary strong { display: block; margin-top: 12px; font-size: 24px; font-variant-numeric: tabular-nums; overflow-wrap: anywhere; }
	.summary strong.loss { color: #dc2626; }
	.stock-section { margin-top: 20px; }
	.stock-section h3 { margin: 0 0 10px; font-size: 16px; font-weight: 600; }
	.stock-breakdown { width: 100%; border-collapse: separate; border-spacing: 0; border: 1px solid #e2e8f0; border-radius: 8px; font-size: 13px; }
	.stock-breakdown th, .stock-breakdown td { padding: 12px; text-align: start; border-bottom: 1px solid #e2e8f0; }
	.stock-breakdown thead th { position: sticky; top: 0; z-index: 1; background: #f1f5f9; }
	.stock-breakdown th:first-child { border-inline-end: 1px solid #e2e8f0; }
	.stock-breakdown tbody th { font-weight: 500; }
	.stock-breakdown tbody tr:last-child th, .stock-breakdown tbody tr:last-child td { border-bottom: 0; }
	.stock-breakdown .number { text-align: end; font-variant-numeric: tabular-nums; }
	.stock-breakdown small { display: block; margin-top: 4px; color: #9a3412; }
	.vat-details { display: flex; flex-wrap: wrap; gap: 12px 32px; margin-top: 16px; color: #64748b; font-size: 13px; }
	.vat-details p { margin: 0; }
	.message { padding: 16px; border-radius: 8px; background: #f8fafc; color: #64748b; }
	.error { background: #fff7ed; color: #9a3412; }
	@media (max-width: 750px) { .summary { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
	@media (max-width: 400px) { .summary { grid-template-columns: minmax(0, 1fr); } }
</style>
