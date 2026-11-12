<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { _ as t, currentLocale } from '$lib/i18n';
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';
	import type { BakeryBranch } from '$lib/types/bakery';
	import type { CoffeeSupplier, CoffeeSuppliersResponse } from '$lib/types/coffeeSuppliers';

	export let windowId: string;
	let suppliers: CoffeeSupplier[] = [];
	let branches: BakeryBranch[] = [];
	let asOfDate = '';
	let search = '';
	let loading = true;
	let failed = false;
	let controller: AbortController | null = null;
	$: query = search.trim().toLocaleLowerCase($currentLocale);
	$: visibleSuppliers = suppliers.filter(supplier => !query || `${supplier.name} ${supplier.ledgerCode}`.toLocaleLowerCase($currentLocale).includes(query));
	$: failedBranches = branches.filter(branch => branch.status !== 'loaded');
	$: complete = branches.length > 0 && failedBranches.length === 0;
	$: total = complete ? visibleSuppliers.reduce((sum, supplier) => sum + (supplier.balance ?? 0), 0) : null;
	$: money = new Intl.NumberFormat($currentLocale === 'ar' ? 'ar-SA' : 'en-SA', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

	function balanceLabel(value: number | null) {
		if (value === null) return '—';
		const suffix = Math.abs(value) < 0.005 ? '' : $t(value > 0 ? 'coffeeCounter.supplierLedgerReport.dr' : 'coffeeCounter.supplierLedgerReport.cr');
		return `${money.format(Math.abs(value))}${suffix ? ` ${suffix}` : ''}`;
	}

	async function loadSuppliers() {
		controller?.abort();
		const pending = new AbortController();
		controller = pending;
		loading = true;
		failed = false;
		suppliers = [];
		branches = [];
		try {
			const response = await authenticatedFetch('/api/coffee-counter-suppliers', { signal: pending.signal });
			const result: CoffeeSuppliersResponse = await response.json();
			if (!response.ok || !result.success || !Array.isArray(result.suppliers) || !Array.isArray(result.branches)) throw new Error('Unable to load suppliers');
			if (pending.signal.aborted) return;
			suppliers = result.suppliers;
			branches = result.branches;
			asOfDate = result.asOfDate;
		} catch {
			if (!pending.signal.aborted) failed = true;
		} finally {
			if (!pending.signal.aborted) loading = false;
		}
	}

	onMount(() => { void loadSuppliers(); });
	onDestroy(() => controller?.abort());
</script>

<div class="supplier-ledger">
	<div class="toolbar">
		<div>
			<h2>{$t('coffeeCounter.supplierLedger')}</h2>
			<p>{$t('coffeeCounter.supplierLedgerReport.asOf')} <bdi>{asOfDate || '—'}</bdi></p>
		</div>
		<div class="controls">
			<label for={`${windowId}-supplier-search`}>{$t('coffeeCounter.supplierLedgerReport.search')}</label>
			<input id={`${windowId}-supplier-search`} type="search" bind:value={search} />
			<button type="button" on:click={loadSuppliers} disabled={loading}>{$t('coffeeCounter.refresh')}</button>
		</div>
	</div>
	<p class="note">{$t('coffeeCounter.supplierLedgerReport.note')}</p>
	{#if loading}
		<p class="message" role="status">{$t('coffeeCounter.supplierLedgerReport.loading')}</p>
	{:else if failed}
		<p class="message error" role="alert">{$t('coffeeCounter.supplierLedgerReport.failed')}</p>
	{:else if branches.length === 0}
		<p class="message">{$t('coffeeCounter.noBranches')}</p>
	{:else}
		{#each failedBranches as branch (branch.id)}
			<p class="message error" role="alert">{$currentLocale === 'ar' ? branch.nameAr : branch.nameEn}: {$t('coffeeCounter.supplierLedgerReport.branchFailed')}</p>
		{/each}
		{#if visibleSuppliers.length === 0}
			{#if complete}<p class="message">{$t('coffeeCounter.supplierLedgerReport.empty')}</p>{/if}
		{:else}
			<div class="table-scroll">
				<table>
					<thead><tr>
						<th scope="col" class="row-number">{$t('coffeeCounter.rowNumber')}</th>
						<th scope="col">{$t('coffeeCounter.vendorName')}</th>
						<th scope="col">{$t('coffeeCounter.supplierLedgerReport.code')}</th>
						<th scope="col" class="number">{$t('coffeeCounter.supplierLedgerReport.balance')}</th>
					</tr></thead>
					<tbody>
						{#each visibleSuppliers as supplier, index (supplier.key)}
							<tr>
								<td class="row-number">{index + 1}</td>
								<th scope="row"><bdi>{supplier.name || '—'}</bdi></th>
								<td><bdi>{supplier.ledgerCode || '—'}</bdi></td>
								<td class="number"><bdi>{balanceLabel(supplier.balance)}</bdi></td>
							</tr>
						{/each}
					</tbody>
					<tfoot><tr>
						<th scope="row" colspan="3">{$t('coffeeCounter.supplierLedgerReport.total')}</th>
						<td class="number"><bdi>{balanceLabel(total)}</bdi></td>
					</tr></tfoot>
				</table>
			</div>
		{/if}
	{/if}
</div>

<style>
	.supplier-ledger { display: flex; flex-direction: column; height: 100%; min-height: 0; overflow: hidden; }
	.toolbar, .controls { display: flex; align-items: center; flex-wrap: wrap; gap: 12px; flex-shrink: 0; }
	.toolbar { justify-content: space-between; }
	h2 { margin: 0 0 6px; font-size: 20px; font-weight: 600; }
	.toolbar p, .note { margin: 8px 0; color: #64748b; font-size: 12px; flex-shrink: 0; }
	.controls { font-size: 13px; }
	input, button { padding: 9px 12px; border: 1px solid #cbd5e1; border-radius: 8px; background: white; color: #1e293b; font: inherit; }
	button { cursor: pointer; color: #047857; font-weight: 600; }
	button:disabled { cursor: wait; opacity: 0.6; }
	input:focus-visible, button:focus-visible { outline: 2px solid #059669; outline-offset: 2px; }
	.message { padding: 16px; background: #f8fafc; border-radius: 8px; color: #64748b; flex-shrink: 0; }
	.error { background: #fff7ed; color: #9a3412; padding: 12px; border-radius: 8px; }
	.table-scroll { flex: 1; min-height: 0; overflow: auto; border: 1px solid #e2e8f0; border-radius: 8px; margin-top: 8px; }
	table { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13px; }
	th, td { padding: 12px; text-align: start; border-bottom: 1px solid #e2e8f0; }
	th:not(:last-child), td:not(:last-child) { border-inline-end: 1px solid #e2e8f0; }
	thead th { position: sticky; top: 0; z-index: 2; background: #f1f5f9; white-space: nowrap; }
	tbody th { font-weight: 500; }
	tfoot th, tfoot td { position: sticky; bottom: 0; background: #ecfdf5; font-weight: 600; z-index: 1; }
	.row-number { width: 1%; text-align: center; white-space: nowrap; }
	.number { text-align: end; white-space: nowrap; font-variant-numeric: tabular-nums; }
</style>
