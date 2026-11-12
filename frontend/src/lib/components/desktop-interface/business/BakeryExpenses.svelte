<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { _ as t, currentLocale } from '$lib/i18n';
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';
	import {
		bakeryDate,
		type BakeryExpenseBranch, type BakeryExpense, type BakeryExpensesResponse
	} from '$lib/types/bakery';

	import { BAKERY_COUNTER, type BusinessCounterProfile } from '$lib/types/businessCounter';

	export let profile: BusinessCounterProfile = BAKERY_COUNTER;
	export let windowId: string;
	const periods = ['today', 'yesterday', 'customDate', 'monthly'] as const;
	type Period = typeof periods[number];
	const today = bakeryDate();
	const currentYear = Number(today.slice(0, 4));
	const startYear = Number(profile.reportStartDate.slice(0, 4));
	const startMonth = Number(profile.reportStartDate.slice(5, 7));
	const years = Array.from({ length: Math.max(1, currentYear - startYear + 1) }, (_, index) => Math.max(currentYear, startYear) - index);
	let period: Period = 'today';
	let month = Number(today.slice(5, 7));
	let year = currentYear;
	let customDate = today;
	let selectedDate = today;
	let selectedBranch = '';
	let branches: BakeryExpenseBranch[] = [];
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
	$: visibleExpenses = expenses.filter(row => row.date >= profile.reportStartDate && (!selectedBranch || row.branchId === selectedBranch))
		.sort((a, b) => a.date.localeCompare(b.date) || a.branchId.localeCompare(b.branchId, undefined, { numeric: true }) || a.id.localeCompare(b.id, undefined, { numeric: true }));
	$: visibleBranches = branches.filter(branch => !selectedBranch || branch.id === selectedBranch);
	$: failedBranches = visibleBranches.filter(branch => branch.status !== 'loaded');
	$: hasLoadedBranch = visibleBranches.some(branch => branch.status === 'loaded');
	$: branchNames = new Map(branches.map(branch => [branch.id, $currentLocale === 'ar' ? branch.nameAr : branch.nameEn]));
	$: debits = visibleExpenses.reduce((total, row) => total + row.debit, 0);
	$: credits = visibleExpenses.reduce((total, row) => total + row.credit, 0);
	$: inputVatTotal = visibleExpenses.reduce((total, row) => total + (row.inputVat ?? 0), 0);
	$: money = new Intl.NumberFormat($currentLocale === 'ar' ? 'ar-SA' : 'en-SA', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

	function choosePeriod(value: Period) {
		if (value === 'yesterday' && bakeryDate(-1) < profile.reportStartDate) return;
		period = value;
		void loadExpenses();
	}

	async function loadExpenses() {
		year = Math.max(year, startYear);
		if (year === startYear) month = Math.max(month, startMonth);
		controller?.abort();
		const pending = new AbortController();
		controller = pending;
		const monthly = period === 'monthly';
		const requestedMonth = `${year}-${String(month).padStart(2, '0')}`;
		selectedDate = monthly ? `${requestedMonth}-01` : period === 'customDate' ? customDate : bakeryDate(period === 'yesterday' ? -1 : 0);
		loading = true;
		failed = false;
		expenses = [];
		branches = [];
		try {
			if (!selectedDate || (!monthly && selectedDate < profile.reportStartDate)) throw new Error('A date within the agreement is required');
			const params = new URLSearchParams(monthly ? { month: requestedMonth } : { date: selectedDate });
			const response = await authenticatedFetch(`/api/${profile.id}-expenses?${params}`, { signal: pending.signal });
			const result: BakeryExpensesResponse = await response.json();
			if (!response.ok || !result.success || !Array.isArray(result.branches) || !Array.isArray(result.expenses)) {
				throw new Error('Unable to load expenses');
			}
			if (pending.signal.aborted) return;
			expenses = result.expenses;
			branches = result.branches;
			if (!branches.some(branch => branch.id === selectedBranch)) selectedBranch = '';
		} catch {
			if (!pending.signal.aborted) failed = true;
		} finally {
			if (!pending.signal.aborted) loading = false;
		}
	}

	onMount(() => { void loadExpenses(); });
	onDestroy(() => controller?.abort());
</script>

<div class="expenses-view">
	<div class="toolbar">
		<div>
			<h2>{$t(`${profile.localeKey}.expenses`)}</h2>
			<p class="ledger-name">{$t(`${profile.localeKey}.expenseSource`)} · <bdi>{period === 'monthly' ? selectedMonth : selectedDate}</bdi></p>
		</div>
		<div class="controls">
			<label for={`${windowId}-bakery-expenses-branch`}>{$t(`${profile.localeKey}.branch`)}</label>
			<select id={`${windowId}-bakery-expenses-branch`} bind:value={selectedBranch} disabled={loading || failed}>
				<option value="">{$t(`${profile.localeKey}.allBranches`)}</option>
				{#each branches as branch (branch.id)}<option value={branch.id}>{branchNames.get(branch.id)}</option>{/each}
			</select>
			<button type="button" on:click={loadExpenses} disabled={loading}>{$t(`${profile.localeKey}.refresh`)}</button>
		</div>
	</div>
	<div class="period-controls" role="group" aria-label={$t(`${profile.localeKey}.expensesPeriod`)}>
		{#each periods as value}
			<button type="button" class:active={period === value} aria-pressed={period === value} disabled={value === 'yesterday' && bakeryDate(-1) < profile.reportStartDate} on:click={() => choosePeriod(value)}>{$t(`${profile.localeKey}.${value}`)}</button>
		{/each}
		{#if period === 'customDate'}
			<label for={`${windowId}-bakery-expenses-date`}>{$t(`${profile.localeKey}.date`)}</label>
			<input id={`${windowId}-bakery-expenses-date`} type="date" min={profile.reportStartDate} max="9998-12-31" bind:value={customDate} on:change={loadExpenses} />
		{:else if period === 'monthly'}
			<label for={`${windowId}-bakery-expenses-month`}>{$t(`${profile.localeKey}.month`)}</label>
			<select id={`${windowId}-bakery-expenses-month`} bind:value={month} on:change={(event) => { month = Number(event.currentTarget.value); void loadExpenses(); }}>
				{#each months as option (option.value)}<option value={option.value}>{option.label}</option>{/each}
			</select>
			<label for={`${windowId}-bakery-expenses-year`}>{$t(`${profile.localeKey}.year`)}</label>
			<select id={`${windowId}-bakery-expenses-year`} bind:value={year} on:change={(event) => { year = Number(event.currentTarget.value); void loadExpenses(); }}>
				{#each years as option (option)}<option value={option}>{option}</option>{/each}
			</select>
		{/if}
	</div>
	{#if loading}
		<p class="message" role="status">{$t(`${profile.localeKey}.loadingExpenses`)}</p>
	{:else if failed}
		<p class="message error" role="alert">{$t(`${profile.localeKey}.expensesLoadFailed`)}</p>
	{:else if branches.length === 0}
		<p class="message">{$t(`${profile.localeKey}.noBranches`)}</p>
	{:else}
		{#each failedBranches as branch (branch.id)}
			<p class="message error" role="alert">{branchNames.get(branch.id)}: {$t(`${profile.localeKey}.expensesBranchStatus.${branch.status}`)}</p>
		{/each}
		{#if hasLoadedBranch}
			<div class="summary">
				<div><span>{$t(`${profile.localeKey}.debits`)}</span><strong><bdi>{money.format(debits)}</bdi></strong></div>
				<div><span>{$t(`${profile.localeKey}.credits`)}</span><strong><bdi>{money.format(credits)}</bdi></strong></div>
				<div title={$t(`${profile.localeKey}.inputVatSource`)}><span>{$t(`${profile.localeKey}.inputVat`)}</span><strong><bdi>{money.format(inputVatTotal)}</bdi></strong></div>
				<div><span>{$t(`${profile.localeKey}.netExpenses`)}</span><strong><bdi>{money.format(debits - credits)}</bdi></strong></div>
			</div>
			<p class="note">{$t(`${profile.localeKey}.expensesNote`)}</p>
			{#if failedBranches.length > 0}<p class="partial">{$t(`${profile.localeKey}.partialSales`)}</p>{/if}
			{#if visibleExpenses.length === 0}
				<p class="message">{$t(`${profile.localeKey}.noExpenses`)}</p>
			{:else}
				<div class="table-scroll">
					<table>
						<thead><tr>
							<th scope="col" class="row-number">{$t(`${profile.localeKey}.rowNumber`)}</th>
							<th scope="col">{$t(`${profile.localeKey}.date`)}</th>
							<th scope="col">{$t(`${profile.localeKey}.branch`)}</th>
							<th scope="col">{$t(`${profile.localeKey}.voucher`)}</th>
							<th scope="col">{$t(`${profile.localeKey}.formName`)}</th>
							{#if profile.id === 'coffee-counter'}<th scope="col">{$t('coffeeCounter.vendorName')}</th>{/if}
							<th scope="col">{$t(`${profile.localeKey}.narration`)}</th>
							<th scope="col" class="number">{$t(`${profile.localeKey}.debits`)}</th>
							<th scope="col" class="number">{$t(`${profile.localeKey}.credits`)}</th>
							<th scope="col" class="number" title={$t(`${profile.localeKey}.inputVatSource`)}>{$t(`${profile.localeKey}.inputVat`)}</th>
							<th scope="col" class="number">{$t(`${profile.localeKey}.netExpenses`)}</th>
						</tr></thead>
						<tbody>
								{#each visibleExpenses as row, index (`${row.branchId}-${row.id}`)}
									<tr>
										<td class="row-number">{index + 1}</td>
										<td><bdi>{row.date}</bdi></td>
										<td>{branchNames.get(row.branchId)}</td>
										<td><bdi>{row.voucher || '—'}</bdi></td>
										<td><bdi>{row.formName && row.formName !== row.formType ? `${row.formName} (${row.formType})` : row.formType || '—'}</bdi></td>
										{#if profile.id === 'coffee-counter'}<td class="vendor"><bdi>{row.vendorName || '—'}</bdi></td>{/if}
										<td class="narration">{row.narration || '—'}</td>
										<td class="number"><bdi>{money.format(row.debit)}</bdi></td>
										<td class="number"><bdi>{money.format(row.credit)}</bdi></td>
										<td class="number" title={$t(row.inputVat == null ? `${profile.localeKey}.inputVatMissing` : `${profile.localeKey}.inputVatSource`)}><bdi>{row.inputVat == null ? '—' : money.format(row.inputVat)}</bdi></td>
										<td class="number"><bdi>{money.format(row.debit - row.credit)}</bdi></td>
									</tr>
								{/each}
						</tbody>
					</table>
				</div>
			{/if}
		{/if}
	{/if}
</div>

<style>
	.expenses-view { display: flex; flex-direction: column; height: 100%; min-height: 0; overflow: hidden; text-align: start; }
	.toolbar, .controls, .period-controls { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; flex-shrink: 0; }
	.toolbar { justify-content: space-between; margin-bottom: 16px; }
	h2 { margin: 0 0 6px; font-size: 20px; font-weight: 600; }
	.ledger-name { margin: 0; color: #64748b; font-size: 13px; }
	.controls, .period-controls { font-size: 13px; }
	.period-controls { margin-bottom: 16px; }
	select, input, button { padding: 9px 12px; border: 1px solid #cbd5e1; border-radius: 8px; background: #fff; color: #1e293b; font: inherit; }
	button { cursor: pointer; color: #047857; font-weight: 600; }
	button.active { background: #047857; border-color: #047857; color: #fff; }
	button:disabled { cursor: wait; opacity: 0.6; }
	select:focus-visible, input:focus-visible, button:focus-visible { outline: 2px solid #059669; outline-offset: 2px; }
	.summary { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; flex-shrink: 0; }
	.summary div { padding: 14px; border: 1px solid #e2e8f0; border-radius: 8px; background: #f8fafc; }
	.summary span { display: block; font-size: 12px; color: #64748b; }
	.summary strong { display: block; margin-top: 8px; font-size: 20px; font-variant-numeric: tabular-nums; overflow-wrap: anywhere; }
	.note, .partial { flex-shrink: 0; margin: 12px 0; font-size: 12px; color: #64748b; }
	.partial { color: #9a3412; }
	.message { flex-shrink: 0; margin: 12px 0; padding: 16px; border-radius: 8px; background: #f8fafc; color: #64748b; }
	.error { background: #fff7ed; color: #9a3412; }
	.table-scroll { flex: 1; min-height: 0; overflow: auto; border: 1px solid #e2e8f0; border-radius: 8px; }
	table { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13px; }
	th, td { padding: 12px; border-bottom: 1px solid #e2e8f0; text-align: start; }
	th:not(:last-child), td:not(:last-child) { border-inline-end: 1px solid #e2e8f0; }
	th { position: sticky; top: 0; z-index: 1; background: #f1f5f9; white-space: nowrap; }
	tbody tr:last-child td { border-bottom: 0; }
	tbody tr:hover { background: #f8fafc; }
	.row-number { width: 1%; text-align: center; white-space: nowrap; }
	.number { text-align: end; white-space: nowrap; font-variant-numeric: tabular-nums; }
	.narration { min-width: 200px; white-space: pre-wrap; }
	.vendor { min-width: 160px; }
	@media (max-width: 600px) {
		.summary { grid-template-columns: repeat(2, minmax(0, 1fr)); }
	}
</style>
