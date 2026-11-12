<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { _ as t, currentLocale } from '$lib/i18n';
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';
	import { bakeryDate, type BakeryBranch, type BakeryExpenseBranch, type BakeryDailySale, type BakeryExpense, type BakeryMonthlySalesResponse, type BakeryExpensesResponse } from '$lib/types/bakery';

	import { BAKERY_COUNTER, counterReportDates, type BusinessCounterProfile } from '$lib/types/businessCounter';

	export let profile: BusinessCounterProfile = BAKERY_COUNTER;
	export let windowId: string;
	type VatBranch = {
		id: string; nameEn: string; nameAr: string;
		salesStatus: BakeryBranch['status'] | 'missing';
		expensesStatus: BakeryExpenseBranch['status'] | 'missing';
	};
	const today = bakeryDate();
	const currentYear = Number(today.slice(0, 4));
	const startYear = Number(profile.reportStartDate.slice(0, 4));
	const startMonth = Number(profile.reportStartDate.slice(5, 7));
	const years = Array.from({ length: Math.max(1, currentYear - startYear + 1) }, (_, index) => Math.max(currentYear, startYear) - index);
	let month = Number(today.slice(5, 7));
	let year = currentYear;
	let selectedBranch = '';
	let branches: VatBranch[] = [];
	let sales: BakeryDailySale[] = [];
	let expenses: BakeryExpense[] = [];
	let loading = true;
	let failed = false;
	let controller: AbortController | null = null;
	$: selectedMonth = `${year}-${String(month).padStart(2, '0')}`;
	$: months = Array.from({ length: 12 }, (_, index) => ({ value: index + 1,
		label: new Intl.DateTimeFormat($currentLocale === 'ar' ? 'ar-SA' : 'en-GB', {
			month: 'long', calendar: 'gregory', timeZone: 'UTC'
		}).format(new Date(Date.UTC(2000, index, 1))) })).filter(option => year > startYear || option.value >= startMonth);
	$: visibleBranches = branches.filter(branch => !selectedBranch || branch.id === selectedBranch);
	$: visibleSales = sales.filter(row => row.date >= profile.reportStartDate && (!selectedBranch || row.branchId === selectedBranch));
	$: visibleExpenses = expenses.filter(row => row.date >= profile.reportStartDate && (!selectedBranch || row.branchId === selectedBranch));
	$: outputComplete = visibleBranches.length > 0 && visibleBranches.every(branch => branch.salesStatus === 'loaded');
	$: inputComplete = visibleBranches.length > 0 && visibleBranches.every(branch => branch.expensesStatus === 'loaded');
	$: hasLoadedSource = visibleBranches.some(branch => branch.salesStatus === 'loaded' || branch.expensesStatus === 'loaded');
	$: branchNames = new Map(branches.map(branch => [branch.id, $currentLocale === 'ar' ? branch.nameAr : branch.nameEn]));
	$: rows = buildRows(selectedMonth, visibleSales, visibleExpenses, outputComplete, inputComplete);
	$: outputTotal = outputComplete ? roundMoney(rows.reduce((sum, row) => sum + (row.outputVat ?? 0), 0)) : null;
	$: inputTotal = inputComplete ? roundMoney(rows.reduce((sum, row) => sum + (row.inputVat ?? 0), 0)) : null;
	$: payableTotal = outputTotal === null || inputTotal === null ? null : roundMoney(outputTotal - inputTotal);
	$: money = new Intl.NumberFormat($currentLocale === 'ar' ? 'ar-SA' : 'en-SA', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

	function roundMoney(value: number) {
		return Math.sign(value) * Math.round((Math.abs(value) + Number.EPSILON) * 100) / 100;
	}

	function mergeBranches(salesBranches: BakeryBranch[], expenseBranches: BakeryExpenseBranch[]): VatBranch[] {
		const combined = new Map<string, VatBranch>();
		for (const branch of salesBranches) combined.set(branch.id, { id: branch.id, nameEn: branch.nameEn, nameAr: branch.nameAr, salesStatus: branch.status, expensesStatus: 'missing' });
		for (const branch of expenseBranches) {
			const existing = combined.get(branch.id);
			combined.set(branch.id, { id: branch.id, nameEn: branch.nameEn, nameAr: branch.nameAr,
				salesStatus: existing?.salesStatus || 'missing', expensesStatus: branch.status });
		}
		return [...combined.values()].sort((a, b) => a.id.localeCompare(b.id, undefined, { numeric: true }));
	}

	function buildRows(monthValue: string, salesRecords: BakeryDailySale[], expenseRecords: BakeryExpense[], salesReady: boolean, expensesReady: boolean) {
		const totals = new Map<string, { output: number; input: number }>();
		for (const record of salesRecords) {
			const total = totals.get(record.date) || { output: 0, input: 0 };
			total.output += record.outputVat;
			totals.set(record.date, total);
		}
		for (const record of expenseRecords) {
			const total = totals.get(record.date) || { output: 0, input: 0 };
			total.input += record.inputVat ?? 0;
			totals.set(record.date, total);
		}
		return counterReportDates(monthValue, profile.reportStartDate).map(date => {
			const total = totals.get(date) || { output: 0, input: 0 };
			const outputVat = salesReady ? roundMoney(total.output) : null;
			const inputVat = expensesReady ? roundMoney(total.input) : null;
			return { date, outputVat, inputVat, payable: outputVat === null || inputVat === null ? null : roundMoney(outputVat - inputVat) };
		});
	}

	async function loadVat() {
		year = Math.max(year, startYear);
		if (year === startYear) month = Math.max(month, startMonth);
		const requestedMonth = `${year}-${String(month).padStart(2, '0')}`;
		controller?.abort();
		const pending = new AbortController();
		controller = pending;
		loading = true;
		failed = false;
		branches = [];
		sales = [];
		expenses = [];
		try {
			const [salesResponse, expensesResponse] = await Promise.all([
				authenticatedFetch(`/api/${profile.id}-sales?month=${encodeURIComponent(requestedMonth)}`, { signal: pending.signal }),
				authenticatedFetch(`/api/${profile.id}-expenses?month=${encodeURIComponent(requestedMonth)}`, { signal: pending.signal })
			]);
			const [salesResult, expensesResult]: [BakeryMonthlySalesResponse, BakeryExpensesResponse] = await Promise.all([salesResponse.json(), expensesResponse.json()]);
			if (!salesResponse.ok || !expensesResponse.ok || !salesResult.success || !expensesResult.success ||
				!Array.isArray(salesResult.dailySales) || !Array.isArray(expensesResult.expenses) ||
				!Array.isArray(salesResult.branches) || !Array.isArray(expensesResult.branches)) throw new Error('Unable to load VAT');
			if (pending.signal.aborted) return;
			sales = salesResult.dailySales;
			expenses = expensesResult.expenses;
			branches = mergeBranches(salesResult.branches, expensesResult.branches);
			if (!branches.some(branch => branch.id === selectedBranch)) selectedBranch = '';
		} catch {
			if (!pending.signal.aborted) failed = true;
		} finally {
			if (!pending.signal.aborted) loading = false;
		}
	}

	onMount(() => { void loadVat(); });
	onDestroy(() => controller?.abort());
</script>

<div class="vat-view">
	<div class="heading">
		<h3>{$t(`${profile.localeKey}.operations.vat`)}</h3>
		<p>{$t(`${profile.localeKey}.salesScope`)} · <bdi>{selectedMonth}</bdi></p>
	</div>
	<div class="filters">
		<label for={`${windowId}-vat-month`}>{$t(`${profile.localeKey}.month`)}</label>
		<select id={`${windowId}-vat-month`} bind:value={month} on:change={(event) => { month = Number(event.currentTarget.value); void loadVat(); }}>
			{#each months as option (option.value)}<option value={option.value}>{option.label}</option>{/each}
		</select>
		<label for={`${windowId}-vat-year`}>{$t(`${profile.localeKey}.year`)}</label>
		<select id={`${windowId}-vat-year`} bind:value={year} on:change={(event) => { year = Number(event.currentTarget.value); void loadVat(); }}>
			{#each years as value (value)}<option {value}>{value}</option>{/each}
		</select>
		<label for={`${windowId}-vat-branch`}>{$t(`${profile.localeKey}.branch`)}</label>
		<select id={`${windowId}-vat-branch`} bind:value={selectedBranch} disabled={loading || failed}>
			<option value="">{$t(`${profile.localeKey}.allBranches`)}</option>
			{#each branches as branch (branch.id)}<option value={branch.id}>{branchNames.get(branch.id)}</option>{/each}
		</select>
		<button type="button" on:click={loadVat} disabled={loading}>{$t(`${profile.localeKey}.refresh`)}</button>
	</div>
	{#if loading}
		<p class="message" role="status">{$t(`${profile.localeKey}.vatReport.loading`)}</p>
	{:else if failed}
		<p class="message error" role="alert">{$t(`${profile.localeKey}.vatReport.failed`)}</p>
	{:else if branches.length === 0}
		<p class="message">{$t(`${profile.localeKey}.noBranches`)}</p>
	{:else}
		{#each visibleBranches as branch (branch.id)}
			{#if branch.salesStatus !== 'loaded'}
				<p class="message error" role="alert">{branchNames.get(branch.id)} · {$t(`${profile.localeKey}.sales`)}: {$t(branch.salesStatus === 'missing' ? `${profile.localeKey}.vatReport.sourceMissing` : `${profile.localeKey}.salesBranchStatus.${branch.salesStatus}`)}</p>
			{/if}
			{#if branch.expensesStatus !== 'loaded'}
				<p class="message error" role="alert">{branchNames.get(branch.id)} · {$t(`${profile.localeKey}.expenses`)}: {$t(branch.expensesStatus === 'missing' ? `${profile.localeKey}.vatReport.sourceMissing` : `${profile.localeKey}.expensesBranchStatus.${branch.expensesStatus}`)}</p>
			{/if}
		{/each}
		{#if hasLoadedSource}
			<div class="summary">
				<div><span>{$t(`${profile.localeKey}.outputVat`)}</span><strong><bdi>{outputTotal === null ? '—' : money.format(outputTotal)}</bdi></strong></div>
				<div><span>{$t(`${profile.localeKey}.vatReport.inputVatOperators`)}</span><strong><bdi>{inputTotal === null ? '—' : money.format(inputTotal)}</bdi></strong></div>
				<div><span>{$t(`${profile.localeKey}.vatReport.payable`)}</span><strong><bdi>{payableTotal === null ? '—' : money.format(payableTotal)}</bdi></strong></div>
			</div>
			<p class="note">{$t(`${profile.localeKey}.vatReport.formula`)}</p>
			{#if !outputComplete || !inputComplete}<p class="message error">{$t(`${profile.localeKey}.vatReport.incomplete`)}</p>{/if}
			<div class="table-scroll">
				<table>
					<thead><tr>
						<th scope="col">{$t(`${profile.localeKey}.date`)}</th>
						<th scope="col" class="number">{$t(`${profile.localeKey}.outputVat`)}</th>
						<th scope="col" class="number">{$t(`${profile.localeKey}.vatReport.inputVatOperators`)}</th>
						<th scope="col" class="number">{$t(`${profile.localeKey}.vatReport.payable`)}</th>
					</tr></thead>
					<tbody>
						{#each rows as row (row.date)}
							<tr>
								<td><bdi>{row.date}</bdi></td>
								<td class="number"><bdi>{row.outputVat === null ? '—' : money.format(row.outputVat)}</bdi></td>
								<td class="number"><bdi>{row.inputVat === null ? '—' : money.format(row.inputVat)}</bdi></td>
								<td class="number"><bdi>{row.payable === null ? '—' : money.format(row.payable)}</bdi></td>
							</tr>
						{/each}
					</tbody>
					<tfoot><tr>
						<th scope="row">{$t(`${profile.localeKey}.rentReport.total`)}</th>
						<td class="number"><bdi>{outputTotal === null ? '—' : money.format(outputTotal)}</bdi></td>
						<td class="number"><bdi>{inputTotal === null ? '—' : money.format(inputTotal)}</bdi></td>
						<td class="number"><bdi>{payableTotal === null ? '—' : money.format(payableTotal)}</bdi></td>
					</tr></tfoot>
				</table>
			</div>
		{/if}
	{/if}
</div>

<style>
	.vat-view { display: flex; flex-direction: column; height: 100%; min-height: 0; overflow: hidden; text-align: start; }
	.heading, .filters, .summary, .note, .message { flex-shrink: 0; }
	h3 { margin: 0 0 6px; font-size: 20px; font-weight: 600; }
	.heading p { margin: 0 0 20px; color: #64748b; font-size: 13px; }
	.filters { display: flex; align-items: center; flex-wrap: wrap; gap: 12px; margin-bottom: 16px; font-size: 13px; }
	select, button { padding: 9px 12px; border: 1px solid #cbd5e1; border-radius: 8px; background: #fff; color: #1e293b; font: inherit; }
	button { color: #047857; cursor: pointer; font-weight: 600; }
	button:disabled { opacity: 0.6; cursor: wait; }
	select:focus-visible, button:focus-visible { outline: 2px solid #059669; outline-offset: 2px; }
	.summary { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; }
	.summary div { padding: 18px; border: 1px solid #e2e8f0; border-radius: 8px; background: #f8fafc; }
	.summary span { display: block; font-size: 13px; color: #64748b; }
	.summary strong { display: block; margin-top: 10px; font-size: 24px; font-variant-numeric: tabular-nums; overflow-wrap: anywhere; }
	.note { margin: 12px 0; color: #64748b; font-size: 12px; }
	.message { margin: 12px 0; padding: 16px; border-radius: 8px; background: #f8fafc; color: #64748b; }
	.error { background: #fff7ed; color: #9a3412; }
	.table-scroll { flex: 1; min-height: 0; overflow: auto; border: 1px solid #e2e8f0; border-radius: 8px; }
	table { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13px; }
	th, td { padding: 12px; border-bottom: 1px solid #e2e8f0; text-align: start; }
	th:not(:last-child), td:not(:last-child) { border-inline-end: 1px solid #e2e8f0; }
	thead th { position: sticky; top: 0; z-index: 1; background: #f1f5f9; white-space: nowrap; }
	tfoot th, tfoot td { position: sticky; bottom: 0; background: #ecfdf5; font-weight: 600; border-top: 1px solid #a7f3d0; border-bottom: 0; }
	tbody tr:hover { background: #f8fafc; }
	.number { text-align: end; white-space: nowrap; font-variant-numeric: tabular-nums; }
	@media (max-width: 600px) { .summary { grid-template-columns: 1fr; } }
</style>
