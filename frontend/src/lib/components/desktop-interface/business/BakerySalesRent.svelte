<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { _ as t, currentLocale } from '$lib/i18n';
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';
	import { bakeryDate, type BakeryBranch, type BakeryDailySale, type BakeryMonthlySalesResponse, type BakeryExpenseBranch, type BakeryExpense, type BakeryExpensesResponse } from '$lib/types/bakery';

	import { BAKERY_COUNTER, counterReportDates, counterRentPercentage, type BusinessCounterProfile } from '$lib/types/businessCounter';
	import type { CoffeeOtherExpense } from '$lib/types/coffeeOtherExpenses';
	import type { CoffeeOtherPayment } from '$lib/types/coffeeOtherPayments';

	export let profile: BusinessCounterProfile = BAKERY_COUNTER;
	export let windowId: string;
	export let view: 'rent' | 'profit' = 'rent';
	export let rentPercentages: Record<string, number | undefined> = {};
	export let manualEntriesRevision = 0;
	let manualExpenses: CoffeeOtherExpense[] = [];
	let manualReady = false;
	let withdrawals: CoffeeOtherPayment[] = [];
	let withdrawalsReady = false;
	let manualLoading = false;
	let manualController: AbortController | null = null;
	let mounted = false;
	let lastManualRevision = manualEntriesRevision;
	const today = bakeryDate();
	let salesAsOfDate = today;
	const currentYear = Number(today.slice(0, 4));
	const startYear = Number(profile.reportStartDate.slice(0, 4));
	const startMonth = Number(profile.reportStartDate.slice(5, 7));
	const years = Array.from({ length: Math.max(1, currentYear - startYear + 1) }, (_, index) => Math.max(currentYear, startYear) - index);
	let month = Number(today.slice(5, 7));
	let year = currentYear;
	let selectedBranch = '';
	let branches: BakeryBranch[] = [];
	let expenseBranches: BakeryExpenseBranch[] = [];
	let sales: BakeryDailySale[] = [];
	let expenses: BakeryExpense[] = [];
	let loading = true;
	let failed = false;
	let controller: AbortController | null = null;
	$: selectedMonth = `${year}-${String(month).padStart(2, '0')}`;
	$: months = Array.from({ length: 12 }, (_, index) => ({
		value: index + 1,
		label: new Intl.DateTimeFormat($currentLocale === 'ar' ? 'ar-SA' : 'en-GB', {
			month: 'long', calendar: 'gregory', timeZone: 'UTC'
		}).format(new Date(Date.UTC(2000, index, 1)))
	})).filter(option => year > startYear || option.value >= startMonth);
	$: visibleSales = sales.filter(row => row.date >= profile.reportStartDate && (!selectedBranch || row.branchId === selectedBranch));
	$: visibleExpenses = expenses.filter(row => row.date >= profile.reportStartDate && (!selectedBranch || row.branchId === selectedBranch));
	$: visibleBranches = branches.filter(branch => !selectedBranch || branch.id === selectedBranch);
	$: failedBranches = visibleBranches.filter(branch => branch.status !== 'loaded');
	$: failedExpenseBranches = expenseBranches.filter(branch => (!selectedBranch || branch.id === selectedBranch) && branch.status !== 'loaded');
	$: hasLoadedBranch = visibleBranches.some(branch => branch.status === 'loaded');
	$: complete = !loading && !failed && visibleBranches.length > 0 && failedBranches.length === 0;
	$: inputComplete = !loading && !failed && visibleBranches.length > 0 && visibleBranches.every(branch => expenseBranches.some(expenseBranch => expenseBranch.id === branch.id && expenseBranch.status === 'loaded'));
	$: branchNames = new Map(branches.map(branch => [branch.id, $currentLocale === 'ar' ? branch.nameAr : branch.nameEn]));
	$: manualNeeded = !selectedBranch;
	$: rows = buildRows(selectedMonth, visibleSales, visibleExpenses, rentPercentages, selectedBranch, complete, inputComplete,
		manualNeeded ? manualExpenses : [], !manualNeeded || manualReady, manualNeeded ? withdrawals : [], !manualNeeded || withdrawalsReady);
	$: if (mounted && manualEntriesRevision !== lastManualRevision) {
		lastManualRevision = manualEntriesRevision;
		void loadManualExpenses();
	}
	$: salesIncludingVat = roundMoney(rows.reduce((total, row) => total + row.salesIncludingVat, 0));
	$: outputVat = roundMoney(rows.reduce((total, row) => total + row.outputVat, 0));
	$: salesExcludingVat = roundMoney(rows.reduce((total, row) => total + row.salesExcludingVat, 0));
	$: rentTotal = rows.every(row => row.rentAmount !== null) ? roundMoney(rows.reduce((total, row) => total + (row.rentAmount ?? 0), 0)) : null;
	$: payableTotal = rows.every(row => row.remainingPayable !== null) ? roundMoney(rows.reduce((total, row) => total + (row.remainingPayable ?? 0), 0)) : null;
	$: inputVatTotal = inputComplete ? roundMoney(rows.reduce((total, row) => total + (row.inputVat ?? 0), 0)) : null;
	$: netPayableTotal = rows.every(row => row.netPayable !== null) ? roundMoney(rows.reduce((total, row) => total + (row.netPayable ?? 0), 0)) : null;
	$: operatorReceivableTotal = rows.every(row => row.operatorReceivable !== null) ? roundMoney(rows.reduce((total, row) => total + (row.operatorReceivable ?? 0), 0)) : null;
	$: salesOtherExpensesTotal = rows.every(row => row.salesOtherExpense !== null) ? roundMoney(rows.reduce((total, row) => total + (row.salesOtherExpense ?? 0), 0)) : null;
	$: withdrawalTotal = rows.every(row => row.withdrawalAmount !== null) ? roundMoney(rows.reduce((total, row) => total + (row.withdrawalAmount ?? 0), 0)) : null;
	$: expensesTotal = rows.every(row => row.expensesIncludingVat !== null) ? roundMoney(rows.reduce((total, row) => total + (row.expensesIncludingVat ?? 0), 0)) : null;
	$: profitTotal = rows.every(row => row.operatorProfit !== null) ? roundMoney(rows.reduce((total, row) => total + (row.operatorProfit ?? 0), 0)) : null;
	$: averageSalesDays = rows.filter(row => row.date <= salesAsOfDate);
	$: averageDailySales = complete && averageSalesDays.length > 0
		? roundMoney(averageSalesDays.reduce((total, row) => total + row.salesIncludingVat, 0) / averageSalesDays.length) : null;
	$: money = new Intl.NumberFormat($currentLocale === 'ar' ? 'ar-SA' : 'en-SA', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

	function roundMoney(value: number) {
		return Math.sign(value) * Math.round((Math.abs(value) + Number.EPSILON) * 100) / 100;
	}

	function rateKey(scope: string, date: string) {
		return `${scope || 'all'}|${date}`;
	}

	function validPercentage(value: number | undefined): value is number {
		return typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 100;
	}

	function setPercentage(date: string, event: Event) {
		const value = (event.currentTarget as HTMLInputElement).valueAsNumber;
		rentPercentages = { ...rentPercentages, [rateKey(selectedBranch, date)]: Number.isNaN(value) ? undefined : value };
	}

	function buildRows(monthValue: string, records: BakeryDailySale[], expenseRecords: BakeryExpense[], percentages: Record<string, number | undefined>, scope: string, ready: boolean, inputReady: boolean, otherRecords: CoffeeOtherExpense[], otherReady: boolean, withdrawalRecords: CoffeeOtherPayment[], withdrawalReady: boolean) {
		const amounts = new Map<string, { sales: number; vat: number }>();
		const inputAmounts = new Map<string, number>();
		const expenseAmounts = new Map<string, number>();
		const otherAmounts = new Map<string, { sales: number; operator: number }>();
		const withdrawalAmounts = new Map<string, number>();
		for (const record of withdrawalRecords) withdrawalAmounts.set(record.paymentDate, (withdrawalAmounts.get(record.paymentDate) ?? 0) + record.amount);
		for (const record of otherRecords) {
			const amounts = otherAmounts.get(record.paymentDate) || { sales: 0, operator: 0 };
			amounts[record.paidFrom] += record.amount;
			otherAmounts.set(record.paymentDate, amounts);
		}
		for (const record of expenseRecords) {
			inputAmounts.set(record.date, (inputAmounts.get(record.date) ?? 0) + (record.inputVat ?? 0));
			expenseAmounts.set(record.date, (expenseAmounts.get(record.date) ?? 0) + record.debit - record.credit);
		}
		for (const record of records) {
			const total = amounts.get(record.date) || { sales: 0, vat: 0 };
			total.sales += record.salesAmount - record.returnAmount;
			total.vat += record.outputVat;
			amounts.set(record.date, total);
		}
		return counterReportDates(monthValue, profile.reportStartDate).map(date => {
			const total = amounts.get(date) || { sales: 0, vat: 0 };
			const salesIncludingVat = roundMoney(total.sales);
			const outputVat = roundMoney(total.vat);
			const salesExcludingVat = roundMoney(salesIncludingVat - outputVat);
			const key = rateKey(scope, date);
			const percentage = Object.prototype.hasOwnProperty.call(percentages, key)
				? percentages[key] : counterRentPercentage(profile, date);
			const valid = validPercentage(percentage);
			const rentAmount = !ready ? null : salesExcludingVat === 0 ? 0 : validPercentage(percentage) ? roundMoney(salesExcludingVat * percentage / 100) : null;
			const remainingPayable = rentAmount === null ? null : roundMoney(salesExcludingVat - rentAmount);
			const inputVat = inputReady ? roundMoney(inputAmounts.get(date) ?? 0) : null;
			const operatorReceivable = remainingPayable === null || inputVat === null ? null : roundMoney(remainingPayable + inputVat);
			const salesOtherExpense = otherReady ? roundMoney(otherAmounts.get(date)?.sales ?? 0) : null;
			const operatorOtherExpense = otherReady ? roundMoney(otherAmounts.get(date)?.operator ?? 0) : null;
			const withdrawalAmount = withdrawalReady ? roundMoney(withdrawalAmounts.get(date) ?? 0) : null;
			const netPayable = operatorReceivable === null || salesOtherExpense === null || withdrawalAmount === null ? null : roundMoney(operatorReceivable - salesOtherExpense - withdrawalAmount);
			// Receivables reimburse input VAT, so deduct expenses on the same basis.
			const expensesIncludingVat = inputVat === null || operatorOtherExpense === null ? null : roundMoney((expenseAmounts.get(date) ?? 0) + inputVat + operatorOtherExpense);
			return { date, salesIncludingVat, outputVat, salesExcludingVat, percentage,
				invalid: percentage !== undefined && !valid, rentAmount, remainingPayable, inputVat,
				netPayable, operatorReceivable, salesOtherExpense, withdrawalAmount, expensesIncludingVat,
				operatorProfit: operatorReceivable === null || expensesIncludingVat === null ? null : roundMoney(operatorReceivable - expensesIncludingVat) };
		});
	}

	async function loadManualExpenses() {
		manualController?.abort();
		const pending = new AbortController();
		manualController = pending;
		manualReady = false;
		withdrawalsReady = false;
		manualLoading = true;
		manualExpenses = [];
		withdrawals = [];
		const monthValue = `${year}-${String(month).padStart(2, '0')}`;
		try {
			async function readEntries(kind: 'expenses' | 'payments') {
				try {
					const response = await authenticatedFetch(`/api/${profile.id}-other-${kind}?month=${encodeURIComponent(monthValue)}`, { signal: pending.signal });
					const result = await response.json();
					return response.ok && result.success && Array.isArray(result.payments) ? result.payments : null;
				} catch { return null; }
			}
			const [expenseEntries, withdrawalEntries] = await Promise.all([readEntries('expenses'), readEntries('payments')]);
			if (pending.signal.aborted) return;
			manualExpenses = expenseEntries || [];
			withdrawals = withdrawalEntries || [];
			manualReady = expenseEntries !== null;
			withdrawalsReady = withdrawalEntries !== null;
		} catch {
			if (!pending.signal.aborted) manualReady = false;
		} finally {
			if (!pending.signal.aborted) manualLoading = false;
		}
	}

	async function loadSales() {
		salesAsOfDate = bakeryDate();
		year = Math.max(year, startYear);
		if (year === startYear) month = Math.max(month, startMonth);
		const requestedMonth = `${year}-${String(month).padStart(2, '0')}`;
		void loadManualExpenses();
		controller?.abort();
		const pending = new AbortController();
		controller = pending;
		loading = true;
		failed = false;
		sales = [];
		expenses = [];
		branches = [];
		expenseBranches = [];
		try {
			const [response, expenseResponse] = await Promise.all([
				authenticatedFetch(`/api/${profile.id}-sales?month=${encodeURIComponent(requestedMonth)}`, { signal: pending.signal }),
				authenticatedFetch(`/api/${profile.id}-expenses?month=${encodeURIComponent(requestedMonth)}`, { signal: pending.signal })
			]);
			const [result, expenseResult]: [BakeryMonthlySalesResponse, BakeryExpensesResponse] = await Promise.all([response.json(), expenseResponse.json()]);
			if (!response.ok || !expenseResponse.ok || !result.success || !expenseResult.success ||
				!Array.isArray(result.dailySales) || !Array.isArray(result.branches) ||
				!Array.isArray(expenseResult.expenses) || !Array.isArray(expenseResult.branches)) throw new Error('Unable to load sales and input VAT');
			if (pending.signal.aborted) return;
			sales = result.dailySales;
			branches = result.branches;
			expenses = expenseResult.expenses;
			expenseBranches = expenseResult.branches;
			if (!branches.some(branch => branch.id === selectedBranch)) selectedBranch = '';
		} catch {
			if (!pending.signal.aborted) failed = true;
		} finally {
			if (!pending.signal.aborted) loading = false;
		}
	}

	onMount(() => { lastManualRevision = manualEntriesRevision; mounted = true; void loadSales(); });
	onDestroy(() => { mounted = false; controller?.abort(); manualController?.abort(); });
</script>

<div class="sales-rent">
	<div class="heading">
		<h3>{$t(view === 'profit' ? `${profile.localeKey}.operations.operatorsProfit` : `${profile.localeKey}.operations.salesAndRent`)}</h3>
		<p>{$t(`${profile.localeKey}.salesScope`)} · <bdi>{selectedMonth}</bdi></p>
	</div>
	<div class="filters">
		<label for={`${windowId}-rent-month`}>{$t(`${profile.localeKey}.month`)}</label>
		<select id={`${windowId}-rent-month`} bind:value={month} on:change={(event) => { month = Number(event.currentTarget.value); void loadSales(); }}>
			{#each months as option (option.value)}<option value={option.value}>{option.label}</option>{/each}
		</select>
		<label for={`${windowId}-rent-year`}>{$t(`${profile.localeKey}.year`)}</label>
		<select id={`${windowId}-rent-year`} bind:value={year} on:change={(event) => { year = Number(event.currentTarget.value); void loadSales(); }}>
			{#each years as value (value)}<option {value}>{value}</option>{/each}
		</select>
		<label for={`${windowId}-rent-branch`}>{$t(`${profile.localeKey}.branch`)}</label>
		<select id={`${windowId}-rent-branch`} bind:value={selectedBranch} disabled={loading || failed}>
			<option value="">{$t(`${profile.localeKey}.allBranches`)}</option>
			{#each branches as branch (branch.id)}<option value={branch.id}>{branchNames.get(branch.id)}</option>{/each}
		</select>
		<button type="button" on:click={loadSales} disabled={loading}>{$t(`${profile.localeKey}.refresh`)}</button>
	</div>
	{#if loading}
		<p class="message" role="status">{$t(`${profile.localeKey}.rentReport.loading`)}</p>
	{:else if failed}
		<p class="message error" role="alert">{$t(`${profile.localeKey}.rentReport.loadFailed`)}</p>
	{:else if branches.length === 0}
		<p class="message">{$t(`${profile.localeKey}.noBranches`)}</p>
	{:else}
		{#each failedBranches as branch (branch.id)}
			<p class="message error" role="alert">{branchNames.get(branch.id)}: {$t(`${profile.localeKey}.salesBranchStatus.${branch.status}`)}</p>
		{/each}
		{#each failedExpenseBranches as branch (branch.id)}
			<p class="message error" role="alert">{branchNames.get(branch.id) || ($currentLocale === 'ar' ? branch.nameAr : branch.nameEn)} · {$t(`${profile.localeKey}.expenses`)}: {$t(`${profile.localeKey}.expensesBranchStatus.${branch.status}`)}</p>
		{/each}
		{#if hasLoadedBranch}
			{#if !complete}<p class="message error">{$t(`${profile.localeKey}.rentReport.incomplete`)}</p>{/if}
			{#if !inputComplete}<p class="message error">{$t(`${profile.localeKey}.rentReport.inputVatIncomplete`)}</p>{/if}
			{#if manualNeeded && manualLoading}<p class="message">{$t(`${profile.localeKey}.otherExpensesReport.loading`)}</p>{/if}
			{#if manualNeeded && !manualLoading && !manualReady}<p class="message error">{$t(`${profile.localeKey}.otherExpensesReport.failed`)}</p>{/if}
			{#if manualNeeded && !manualLoading && !withdrawalsReady}<p class="message error">{$t(`${profile.localeKey}.otherPaymentsReport.failed`)}</p>{/if}
			<div class="summary" class:profit-summary={view === 'profit'}>
				{#if view === 'profit'}
					<div><span>{$t(`${profile.localeKey}.profitReport.receivable`)}</span><strong><bdi>{operatorReceivableTotal === null ? '—' : money.format(operatorReceivableTotal)}</bdi></strong></div>
					<div><span>{$t(`${profile.localeKey}.profitReport.expenses`)}</span><strong><bdi>{expensesTotal === null ? '—' : money.format(expensesTotal)}</bdi></strong></div>
					<div><span>{$t(`${profile.localeKey}.profitReport.profit`)}</span><strong class:loss={profitTotal !== null && profitTotal < 0}><bdi>{profitTotal === null ? '—' : money.format(profitTotal)}</bdi></strong></div>
					<div title={$t(`${profile.localeKey}.profitReport.averageSalesFormula`)}><span>{$t(`${profile.localeKey}.profitReport.averageSales`)}</span><strong><bdi>{averageDailySales === null ? '—' : money.format(averageDailySales)}</bdi></strong></div>
				{:else}
				<div><span>{$t(`${profile.localeKey}.rentReport.salesIncludingVat`)}</span><strong><bdi>{money.format(salesIncludingVat)}</bdi></strong></div>
				<div><span>{$t(`${profile.localeKey}.outputVat`)}</span><strong><bdi>{money.format(outputVat)}</bdi></strong></div>
				<div><span>{$t(`${profile.localeKey}.rentReport.salesExcludingVat`)}</span><strong><bdi>{money.format(salesExcludingVat)}</bdi></strong></div>
				<div><span>{$t(`${profile.localeKey}.inputVat`)}</span><strong><bdi>{inputVatTotal === null ? '—' : money.format(inputVatTotal)}</bdi></strong></div>
				{/if}
			</div>
			<p class="note">{$t(view === 'profit' ? `${profile.localeKey}.profitReport.note` : `${profile.localeKey}.rentReport.salesNote`)}</p>
			<p class="note">{$t(`${profile.localeKey}.rentReport.schedule`)}</p>
			<p class="note">{$t(`${profile.localeKey}.otherExpensesReport.monthlyNote`)}</p>
			{#if view === 'rent'}<p id={`${windowId}-rent-percentage-help`} class="note">{$t(`${profile.localeKey}.rentReport.dailyPercentageHelp`)}</p>{/if}
			<div class="table-scroll">
				<table>
					<thead><tr>
						<th scope="col">{$t(`${profile.localeKey}.date`)}</th>
						{#if view === 'profit'}
							<th scope="col" class="number">{$t(`${profile.localeKey}.profitReport.receivable`)}</th>
							<th scope="col" class="number">{$t(`${profile.localeKey}.profitReport.expenses`)}</th>
							<th scope="col" class="number">{$t(`${profile.localeKey}.profitReport.profit`)}</th>
						{:else}
						<th scope="col" class="number">{$t(`${profile.localeKey}.rentReport.salesIncludingVat`)}</th>
						<th scope="col" class="number">{$t(`${profile.localeKey}.outputVat`)}</th>
						<th scope="col" class="number">{$t(`${profile.localeKey}.rentReport.salesExcludingVat`)}</th>
						<th scope="col">{$t(`${profile.localeKey}.rentReport.percentage`)}</th>
						<th scope="col" class="number">{$t(`${profile.localeKey}.rentReport.rentAmount`)}</th>
						<th scope="col" class="number">{$t(`${profile.localeKey}.rentReport.salesAfterRent`)}</th>
						<th scope="col" class="number" title={$t(`${profile.localeKey}.inputVatSource`)}>{$t(`${profile.localeKey}.inputVat`)}</th>
						<th scope="col" class="number">{$t(`${profile.localeKey}.otherPaymentsReport.total`)}</th>
						<th scope="col" class="number">{$t(`${profile.localeKey}.otherExpensesReport.salesTotal`)}</th>
						<th scope="col" class="number">{$t(`${profile.localeKey}.rentReport.netPayable`)}</th>
						{/if}
					</tr></thead>
					<tbody>
						{#each rows as row (row.date)}
							<tr>
								<td><bdi>{row.date}</bdi></td>
								{#if view === 'profit'}
									<td class="number"><bdi>{row.operatorReceivable === null ? '—' : money.format(row.operatorReceivable)}</bdi></td>
									<td class="number"><bdi>{row.expensesIncludingVat === null ? '—' : money.format(row.expensesIncludingVat)}</bdi></td>
									<td class="number" class:loss={row.operatorProfit !== null && row.operatorProfit < 0}><bdi>{row.operatorProfit === null ? '—' : money.format(row.operatorProfit)}</bdi></td>
								{:else}
								<td class="number"><bdi>{money.format(row.salesIncludingVat)}</bdi></td>
								<td class="number"><bdi>{money.format(row.outputVat)}</bdi></td>
								<td class="number"><bdi>{money.format(row.salesExcludingVat)}</bdi></td>
								<td><input type="number" min="0" max="100" step="0.01" value={row.percentage ?? ''}
									on:input={(event) => setPercentage(row.date, event)} aria-invalid={row.invalid}
									aria-label={$t(`${profile.localeKey}.rentReport.percentageForDate`, { date: row.date })}
									aria-describedby={`${windowId}-rent-percentage-help`} disabled={!complete}
									placeholder="%" /></td>
								<td class="number"><bdi>{row.rentAmount === null ? '—' : money.format(row.rentAmount)}</bdi></td>
								<td class="number"><bdi>{row.remainingPayable === null ? '—' : money.format(row.remainingPayable)}</bdi></td>
								<td class="number"><bdi>{row.inputVat === null ? '—' : money.format(row.inputVat)}</bdi></td>
								<td class="number"><bdi>{row.withdrawalAmount === null ? '—' : money.format(row.withdrawalAmount)}</bdi></td>
								<td class="number"><bdi>{row.salesOtherExpense === null ? '—' : money.format(row.salesOtherExpense)}</bdi></td>
								<td class="number"><bdi>{row.netPayable === null ? '—' : money.format(row.netPayable)}</bdi></td>
								{/if}
							</tr>
						{/each}
					</tbody>
					<tfoot><tr>
						<th scope="row">{$t(`${profile.localeKey}.rentReport.total`)}</th>
						{#if view === 'profit'}
							<td class="number"><bdi>{operatorReceivableTotal === null ? '—' : money.format(operatorReceivableTotal)}</bdi></td>
							<td class="number"><bdi>{expensesTotal === null ? '—' : money.format(expensesTotal)}</bdi></td>
							<td class="number" class:loss={profitTotal !== null && profitTotal < 0}><bdi>{profitTotal === null ? '—' : money.format(profitTotal)}</bdi></td>
						{:else}
						<td class="number"><bdi>{money.format(salesIncludingVat)}</bdi></td>
						<td class="number"><bdi>{money.format(outputVat)}</bdi></td>
						<td class="number"><bdi>{money.format(salesExcludingVat)}</bdi></td>
						<td>—</td>
						<td class="number"><bdi>{rentTotal === null ? '—' : money.format(rentTotal)}</bdi></td>
						<td class="number"><bdi>{payableTotal === null ? '—' : money.format(payableTotal)}</bdi></td>
						<td class="number"><bdi>{inputVatTotal === null ? '—' : money.format(inputVatTotal)}</bdi></td>
						<td class="number"><bdi>{withdrawalTotal === null ? '—' : money.format(withdrawalTotal)}</bdi></td>
						<td class="number"><bdi>{salesOtherExpensesTotal === null ? '—' : money.format(salesOtherExpensesTotal)}</bdi></td>
						<td class="number"><bdi>{netPayableTotal === null ? '—' : money.format(netPayableTotal)}</bdi></td>
						{/if}
					</tr></tfoot>
				</table>
			</div>
			<p class="note">{$t(view === 'profit' ? `${profile.localeKey}.profitReport.formula` : `${profile.localeKey}.rentReport.formulas`)}</p>
		{/if}
	{/if}
</div>

<style>
	.sales-rent { display: flex; flex-direction: column; height: 100%; min-height: 0; overflow: hidden; text-align: start; }
	.heading, .filters, .summary, .note, .message { flex-shrink: 0; }
	h3 { margin: 0 0 6px; font-size: 20px; font-weight: 600; }
	.heading p { margin: 0 0 20px; color: #64748b; font-size: 13px; }
	.filters { display: flex; align-items: center; flex-wrap: wrap; gap: 12px; margin-bottom: 16px; font-size: 13px; }
	select, input, button { padding: 9px 12px; border: 1px solid #cbd5e1; border-radius: 8px; background: #fff; color: #1e293b; font: inherit; }
	button { color: #047857; cursor: pointer; font-weight: 600; }
	button:disabled { opacity: 0.6; cursor: wait; }
	input { width: 95px; box-sizing: border-box; }
	input[aria-invalid="true"] { border-color: #b91c1c; background: #fef2f2; }
	select:focus-visible, input:focus-visible, button:focus-visible { outline: 2px solid #059669; outline-offset: 2px; }
	.summary { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; }
	.summary.profit-summary { grid-template-columns: repeat(4, minmax(0, 1fr)); }
	.summary div { padding: 18px; border: 1px solid #e2e8f0; border-radius: 8px; background: #f8fafc; }
	.summary span { display: block; font-size: 13px; color: #64748b; }
	.summary strong { display: block; margin-top: 10px; font-size: 24px; font-variant-numeric: tabular-nums; overflow-wrap: anywhere; }
	.note { margin: 8px 0; color: #64748b; font-size: 12px; }
	.table-scroll { flex: 1; min-height: 0; overflow: auto; border: 1px solid #e2e8f0; border-radius: 8px; }
	table { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13px; }
	th, td { padding: 10px 12px; border-bottom: 1px solid #e2e8f0; text-align: start; }
	th:not(:last-child), td:not(:last-child) { border-inline-end: 1px solid #e2e8f0; }
	thead th { position: sticky; top: 0; z-index: 1; background: #f1f5f9; white-space: nowrap; }
	tfoot th, tfoot td { position: sticky; bottom: 0; background: #ecfdf5; font-weight: 600; border-top: 1px solid #a7f3d0; border-bottom: 0; }
	tbody tr:hover { background: #f8fafc; }
	.number { text-align: end; white-space: nowrap; font-variant-numeric: tabular-nums; }
	.message { margin: 12px 0; padding: 16px; border-radius: 8px; background: #f8fafc; color: #64748b; }
	.error { background: #fff7ed; color: #9a3412; }
	.loss { color: #b91c1c; }
	@media (max-width: 600px) { .summary, .summary.profit-summary { grid-template-columns: 1fr; } }
</style>
