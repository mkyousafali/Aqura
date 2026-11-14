<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { _ as t, currentLocale } from '$lib/i18n';
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';
	import { tFor } from '$lib/i18n';
	import { iconUrlMap, error as iconError, loadIcons } from '$lib/stores/iconStore';
	import type { CounterPdfPeriod, CounterPdfReport } from '$lib/utils/businessCounterReportPdf';
	import type { CoffeeOtherPayment } from '$lib/types/coffeeOtherPayments';
	import type { CoffeeOtherExpense } from '$lib/types/coffeeOtherExpenses';
	import { COFFEE_COUNTER, COFFEE_PURCHASE_BRANCH_ID, COFFEE_INITIAL_CAPITAL, counterRentPercentage, type BusinessCounterProfile } from '$lib/types/businessCounter';
	import { bakeryDate, type BakeryBranch, type BakeryExpenseBranch } from '$lib/types/bakery';
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
	let today = bakeryDate();
	let throughDate = today;
	let followCurrentDate = true;
	let dateError = '';
	let selectedBranch = '';
	let loading = true;
	let failed = false;
	let controller: AbortController | null = null;
	let loadedAt = '';
	let downloading = false;
	let showReportLanguages = false;
	let downloadError = '';
	let downloadController: AbortController | null = null;
	$: canDownload = salesReady && inputReady && !dateError && asOfDate === throughDate && asOfDate >= profile.reportStartDate && totals.netPayable !== null && totals.operatorsProfit !== null;
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

	async function downloadReport(locale: 'en' | 'ar') {
		if (!canDownload || downloading) return;
		if (followCurrentDate && throughDate !== bakeryDate()) {
			today = bakeryDate();
			throughDate = today;
			showReportLanguages = false;
			downloadError = $t('businessReportPdf.changed');
			void loadReport();
			return;
		}
		showReportLanguages = false;
		downloading = true;
		downloadError = '';
		const pending = new AbortController();
		downloadController = pending;
		// Freeze the displayed financial snapshot before any asynchronous work.
		const snapshotTotals = { ...totals };
		const reportDate = asOfDate;
		const snapshotLoadedAt = loadedAt;
		const scope = selectedBranch;
		const records = [...visibleSales];
		const inputRecords = [...visiblePurchaseVat];
		const rates = { ...rentPercentages };
		const reportBranches = [...visibleBranches];
		const stocks = [...visibleStockValues];
		const reportStockValue = stockValue;
		const payments = vendorPayments ? { ...vendorPayments } : null;
		try {
			await loadIcons(true);
			if ($iconError) throw new Error('Logo unavailable');
			const logoUrl = $iconUrlMap[`${profile.id}-logo`];
			async function readEntries(kind: 'payments' | 'expenses') {
				const response = await authenticatedFetch(`/api/${profile.id}-other-${kind}?through=${encodeURIComponent(reportDate)}`, { signal: pending.signal });
				const result = await response.json();
				if (!response.ok || !result.success || result.asOfDate !== reportDate || !Array.isArray(result.payments)) throw new Error('snapshotChanged');
				if (!result.payments.every((row: CoffeeOtherExpense) => typeof row.amount === 'number' && Number.isFinite(row.amount) && row.amount > 0 &&
					typeof row.narration === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(row.paymentDate) && row.paymentDate <= reportDate &&
					row.paymentDate >= profile.reportStartDate && (kind !== 'expenses' || ['sales', 'operator'].includes(row.paidFrom)))) throw new Error('Incomplete entries');
				return result.payments.sort((a: CoffeeOtherPayment, b: CoffeeOtherPayment) => a.paymentDate.localeCompare(b.paymentDate) || a.id.localeCompare(b.id));
			}
			const [withdrawals, otherExpenses]: [CoffeeOtherPayment[], CoffeeOtherExpense[]] = scope ? [[], []] : await Promise.all([readEntries('payments'), readEntries('expenses')]);
			const sum = (rows: CoffeeOtherPayment[]) => rows.reduce((value, row) => value + Math.round(row.amount * 100), 0);
			if (sum(withdrawals) !== Math.round((snapshotTotals.otherPayments ?? 0) * 100) ||
				sum(otherExpenses.filter(row => row.paidFrom === 'sales')) !== Math.round((snapshotTotals.salesPaidExpenses ?? 0) * 100) ||
				sum(otherExpenses.filter(row => row.paidFrom === 'operator')) !== Math.round((snapshotTotals.operatorPaidExpenses ?? 0) * 100)) throw new Error('snapshotChanged');
			const dates = [...new Set([...records.map(row => row.date), ...inputRecords.map(row => row.date), ...withdrawals.map(row => row.paymentDate), ...otherExpenses.map(row => row.paymentDate)])].sort();
			const daily = dates.map(date => {
				const expenses = otherExpenses.filter(row => row.paymentDate === date);
				const dailyTotals = buildTotals(records.filter(row => row.date === date), inputRecords.filter(row => row.date === date), rates, scope, true, true, 0, 0,
					{ sales: sum(expenses.filter(row => row.paidFrom === 'sales')) / 100, operator: sum(expenses.filter(row => row.paidFrom === 'operator')) / 100 });
				const key = `${scope || 'all'}|${date}`;
				const rate = Object.prototype.hasOwnProperty.call(rates, key) ? rates[key] : counterRentPercentage(profile, date);
				return { date, percentage: typeof rate === 'number' && Number.isFinite(rate) && rate >= 0 && rate <= 100 ? rate : null,
					salesIncludingVat: dailyTotals.salesIncludingVat!, salesExcludingVat: dailyTotals.salesExcludingVat!, rent: dailyTotals.rent!,
					inputVat: dailyTotals.inputVat!, expensesIncludingVat: dailyTotals.expensesIncludingVat!,
					receivable: roundMoney(dailyTotals.payableBeforePayments! - dailyTotals.initialCapital), profit: dailyTotals.operatorsProfit! };
			});
			const months = new Map<string, CounterPdfPeriod>();
			for (const row of daily) {
				const month = row.date.slice(0, 7);
				const current = months.get(month) || { date: month, percentage: null, salesIncludingVat: 0, salesExcludingVat: 0, rent: 0, inputVat: 0, expensesIncludingVat: 0, receivable: 0, profit: 0 };
				for (const key of ['salesIncludingVat', 'salesExcludingVat', 'rent', 'inputVat', 'expensesIncludingVat', 'receivable', 'profit'] as const) current[key] = roundMoney(current[key] + row[key]);
				months.set(month, current);
			}
			const report: CounterPdfReport = {
				profile, locale, logoUrl, totals: snapshotTotals,
				startDate: isCoffee ? [dates[0], ...(!scope || scope === COFFEE_PURCHASE_BRANCH_ID ? [payments?.firstPaymentDate] : [])].filter((date): date is string => !!date).sort()[0] || reportDate : profile.reportStartDate, asOfDate: reportDate,
				loadedAt: snapshotLoadedAt, generatedAt: new Date().toISOString(), combined: !scope,
				scope: scope ? (locale === 'ar' ? reportBranches[0].nameAr : reportBranches[0].nameEn) : tFor(locale, `${profile.localeKey}.allBranches`),
				daily, monthly: [...months.values()], withdrawals, otherExpenses,
				branches: reportBranches.map(branch => {
					const rows = records.filter(row => row.branchId === branch.id);
					const branchTotals = buildTotals(rows, [], {}, branch.id, true, true, 0, 0, { sales: 0, operator: 0 });
					return { name: locale === 'ar' ? branch.nameAr : branch.nameEn, sales: branchTotals.salesIncludingVat!,
						salesExcludingVat: branchTotals.salesExcludingVat!, outputVat: branchTotals.outputVat!,
						stock: stocks.find(item => item.branch.id === branch.id && item.branch.status === 'loaded')?.value ?? null };
				}),
				stockValue: reportStockValue, cashAndBank: isCoffee && (!scope || scope === COFFEE_PURCHASE_BRANCH_ID) ? payments?.cashAndBankAmount ?? null : 0,
				journalPayments: isCoffee && (!scope || scope === COFFEE_PURCHASE_BRANCH_ID) ? payments?.journalAmount ?? null : 0
			};
			const { downloadBusinessCounterReportPdf } = await import('$lib/utils/businessCounterReportPdf');
			await downloadBusinessCounterReportPdf(report, pending.signal);
		} catch (error) {
			if (!pending.signal.aborted) downloadError = $t(error instanceof Error && error.message === 'snapshotChanged' ? 'businessReportPdf.changed' : 'businessReportPdf.failed');
		} finally {
			if (!pending.signal.aborted) downloading = false;
		}
	}

	async function loadOtherPaymentTotal() {
		if (loading) return;
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
				readSummary(`/api/${profile.id}-other-payments?summary=1&through=${encodeURIComponent(asOfDate || throughDate)}`),
				readSummary(`/api/${profile.id}-other-expenses?summary=1&through=${encodeURIComponent(asOfDate || throughDate)}`)
			]);
			if (pending.signal.aborted || version !== otherPaymentReadVersion) return;
			if (asOfDate && ((result && result.asOfDate !== asOfDate) || (expenseResult && expenseResult.asOfDate !== asOfDate))) { void loadReport(); return; }
			otherPaymentsTotal = typeof result?.total === 'number' && Number.isFinite(result.total) && result.total >= 0 ? result.total : null;
			otherExpenseTotals = parseExpenseTotals(expenseResult?.totals);
		} catch {
			if (!pending.signal.aborted && version === otherPaymentReadVersion) otherPaymentsTotal = null;
		}
	}

	function changeReportDate(event: Event) {
		throughDate = (event.currentTarget as HTMLInputElement).value;
		followCurrentDate = throughDate === bakeryDate();
		void loadReport();
	}

	async function loadReport() {
		if (followCurrentDate) {
			today = bakeryDate();
			throughDate = today;
		}
		const requestedDate = throughDate;
		const parsedDate = new Date(`${requestedDate}T00:00:00Z`);
		if (!/^\d{4}-\d{2}-\d{2}$/.test(requestedDate) || requestedDate < profile.reportStartDate || requestedDate > bakeryDate() ||
			!Number.isFinite(parsedDate.getTime()) || parsedDate.toISOString().slice(0, 10) !== requestedDate) {
			dateError = $t('businessReportPdf.invalidThroughDate', { date: profile.reportStartDate });
			return;
		}
		dateError = '';
		downloadError = '';
		showReportLanguages = false;
		const entriesRevision = otherPaymentsRevision;
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
			const response = await authenticatedFetch(`/api/${profile.id}-all-time?through=${encodeURIComponent(requestedDate)}`, { signal: pending.signal });
			const result: CoffeeAllTimeResponse = await response.json();
			if (!response.ok || !result.success || result.asOfDate !== requestedDate || !Array.isArray(result.branches) || !Array.isArray(result.dailySales) ||
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
			loadedAt = new Date().toISOString();
			if (!branches.some(branch => branch.id === selectedBranch)) selectedBranch = '';
		} catch {
			if (!pending.signal.aborted) failed = true;
		} finally {
			if (!pending.signal.aborted) {
				loading = false;
				if (!failed && entriesRevision !== otherPaymentsRevision) void loadOtherPaymentTotal();
			}
		}
	}

	onMount(() => {
		today = bakeryDate();
		throughDate = today;
		lastOtherPaymentsRevision = otherPaymentsRevision;
		mounted = true;
		void loadReport();
		const rollover = setInterval(() => {
			today = bakeryDate();
			if (followCurrentDate && throughDate !== today && !loading && !downloading) {
				throughDate = today;
				void loadReport();
			}
		}, 60000);
		return () => clearInterval(rollover);
	});
	onDestroy(() => { mounted = false; controller?.abort(); otherPaymentController?.abort(); downloadController?.abort(); });
</script>

<div class="all-time-report">
	<div class="toolbar">
		<div>
			<h2>{$t(`${profile.localeKey}.allTimeReport`)}</h2>
			<p>{$t(`${profile.localeKey}.allTime.through`)} <bdi>{asOfDate || '—'}</bdi></p>
		</div>
		<div class="controls">
			<label for={`${windowId}-all-time-through`}>{$t('businessReportPdf.upToDate')}</label>
			<input id={`${windowId}-all-time-through`} type="date" min={profile.reportStartDate} max={today}
				bind:value={throughDate} on:change={changeReportDate} required disabled={loading || downloading}
				aria-invalid={!!dateError} aria-describedby={dateError ? `${windowId}-all-time-date-error` : undefined} />
			<label for={`${windowId}-all-time-branch`}>{$t(`${profile.localeKey}.branch`)}</label>
			<select id={`${windowId}-all-time-branch`} bind:value={selectedBranch} disabled={loading || failed || downloading}>
				<option value="">{$t(`${profile.localeKey}.allBranches`)}</option>
				{#each branches as branch (branch.id)}
					<option value={branch.id}>{$currentLocale === 'ar' ? branch.nameAr : branch.nameEn}</option>
				{/each}
			</select>
			<button type="button" on:click={loadReport} disabled={loading || downloading}>{$t(`${profile.localeKey}.refresh`)}</button>
			<button type="button" on:click={() => showReportLanguages = !showReportLanguages} disabled={!canDownload || downloading}
				aria-expanded={showReportLanguages} aria-controls={`${windowId}-report-languages`}>
				{$t(downloading ? 'businessReportPdf.downloading' : 'businessReportPdf.download')}
			</button>
		</div>
	</div>
	{#if dateError}<p id={`${windowId}-all-time-date-error`} class="message error" role="alert">{dateError}</p>{/if}
	{#if showReportLanguages}
		<div id={`${windowId}-report-languages`} class="report-languages" role="group" aria-label={$t('businessReportPdf.chooseLanguage')}>
			<strong>{$t('businessReportPdf.chooseLanguage')}</strong>
			<button type="button" lang="en" on:click={() => downloadReport('en')}>English</button>
			<button type="button" lang="ar" dir="rtl" on:click={() => downloadReport('ar')}>العربية</button>
			<button type="button" on:click={() => showReportLanguages = false}>{$t('businessReportPdf.cancel')}</button>
		</div>
	{/if}
	{#if downloadError}<p class="message error" role="alert">{downloadError}</p>{/if}
	{#if loading}
		<p class="message" role="status">{$t(`${profile.localeKey}.allTime.loading`)}</p>
	{:else if failed}
		<p class="message error" role="alert">{$t(`${profile.localeKey}.allTime.failed`)}</p>
	{:else if branches.length === 0}
		<p class="message">{$t(`${profile.localeKey}.noBranches`)}</p>
	{:else if asOfDate < profile.reportStartDate}
		<p class="message">{$t('businessReportPdf.noCompletedPeriod', { date: profile.reportStartDate })}</p>
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
	.report-languages { display: flex; flex-wrap: wrap; align-items: center; gap: 12px; padding: 16px; margin-bottom: 16px; border: 1px solid #b5d8cb; border-radius: 8px; background: #f0f8f4; }
	select, input, button { padding: 9px 12px; border: 1px solid #cbd5e1; border-radius: 8px; background: white; color: #1e293b; font: inherit; }
	button { cursor: pointer; color: #047857; font-weight: 600; }
	button:disabled { cursor: wait; opacity: 0.6; }
	select:focus-visible, input:focus-visible, button:focus-visible { outline: 2px solid #059669; outline-offset: 2px; }
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
