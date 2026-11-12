<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { _ as t, currentLocale } from '$lib/i18n';
	import { authenticatedFetch } from '$lib/utils/authenticatedFetch';
	import { type BakeryBranch, type BakeryProduct, type BakeryProductsResponse } from '$lib/types/bakery';

	import { BAKERY_COUNTER, type BusinessCounterProfile } from '$lib/types/businessCounter';

	export let profile: BusinessCounterProfile = BAKERY_COUNTER;
	export let windowId: string;
	let branches: BakeryBranch[] = [];
	let products: BakeryProduct[] = [];
	let selectedBranch = '';
	let loading = true;
	let failed = false;
	let controller: AbortController | null = null;
	$: visibleProducts = products.filter(product => !selectedBranch || product.branchId === selectedBranch);
	$: failedBranches = branches.filter(branch => branch.status !== 'loaded' && (!selectedBranch || branch.id === selectedBranch));
	$: branchNames = new Map(branches.map(branch => [branch.id, $currentLocale === 'ar' ? branch.nameAr : branch.nameEn]));
	$: priceFormatter = new Intl.NumberFormat($currentLocale === 'ar' ? 'ar-SA' : 'en-SA', {
		minimumFractionDigits: 2,
		maximumFractionDigits: 2
	});
	$: profitFormatter = new Intl.NumberFormat($currentLocale === 'ar' ? 'ar-SA' : 'en-SA', {
		style: 'percent',
		minimumFractionDigits: 2,
		maximumFractionDigits: 2
	});

	function getProfitMargin(product: BakeryProduct): number | null {
		if (product.salesPrice == null || product.cost == null || product.salesPrice <= 0) return null;
		const salesExcludingVat = product.salesPrice / 1.15;
		// ERP cost is before VAT; only the displayed cost has 15% added.
		const costExcludingVat = product.cost;
		const margin = (salesExcludingVat - costExcludingVat) / salesExcludingVat;
		return Number.isFinite(margin) ? margin : null;
	}

	async function loadProducts() {
		controller?.abort();
		const pending = new AbortController();
		controller = pending;
		loading = true;
		failed = false;
		products = [];
		branches = [];
		try {
			const response = await authenticatedFetch(`/api/${profile.id}-products`, { signal: pending.signal });
			const result: BakeryProductsResponse = await response.json();
			if (!response.ok || !result.success || !Array.isArray(result.products) || !Array.isArray(result.branches)) {
				throw new Error('Unable to load bakery products');
			}
			if (pending.signal.aborted) return;
			products = result.products;
			branches = result.branches;
			if (!branches.some(branch => branch.id === selectedBranch)) selectedBranch = '';
		} catch {
			if (!pending.signal.aborted) failed = true;
		} finally {
			if (!pending.signal.aborted) loading = false;
		}
	}

	onMount(() => { void loadProducts(); });
	onDestroy(() => controller?.abort());
</script>

<div class="products-view">
	<div class="toolbar">
		<div>
			<h2>{$t(`${profile.localeKey}.products`)}</h2>
			<p class="group-name">{profile.productGroup}</p>
		</div>
		<div class="controls">
			<label for={`${windowId}-bakery-branch`}>{$t(`${profile.localeKey}.branch`)}</label>
			<select id={`${windowId}-bakery-branch`} bind:value={selectedBranch} disabled={loading || failed}>
				<option value="">{$t(`${profile.localeKey}.allBranches`)}</option>
				{#each branches as branch (branch.id)}
					<option value={branch.id}>{branchNames.get(branch.id)}</option>
				{/each}
			</select>
			<button type="button" on:click={loadProducts} disabled={loading}>{$t(`${profile.localeKey}.refresh`)}</button>
		</div>
	</div>
	{#if loading}
		<p class="message" role="status">{$t(`${profile.localeKey}.loading`)}</p>
	{:else if failed}
		<p class="message error" role="alert">{$t(`${profile.localeKey}.loadFailed`)}</p>
	{:else if branches.length === 0}
		<p class="message">{$t(`${profile.localeKey}.noBranches`)}</p>
	{:else}
		{#each failedBranches as branch (branch.id)}
			<p class="message error" role="alert">{branchNames.get(branch.id)}: {$t(`${profile.localeKey}.branchStatus.${branch.status}`)}</p>
		{/each}
		<p class="count">{$t(`${profile.localeKey}.productCount`, { count: visibleProducts.length })}</p>
		{#if visibleProducts.length === 0}
			{#if failedBranches.length === 0}
				<p class="message">{$t(`${profile.localeKey}.noProducts`)}</p>
			{/if}
		{:else}
			<div class="table-scroll">
				<table>
					<thead>
						<tr>
							<th scope="col" class="row-number">{$t(`${profile.localeKey}.rowNumber`)}</th>
							<th scope="col">{$t(`${profile.localeKey}.branch`)}</th>
							<th scope="col">{$t(`${profile.localeKey}.barcode`)}</th>
							<th scope="col">{$t(`${profile.localeKey}.nameEn`)}</th>
							<th scope="col">{$t(`${profile.localeKey}.nameAr`)}</th>
							<th scope="col">{$t(`${profile.localeKey}.unit`)}</th>
							<th scope="col" class="price">{$t(`${profile.localeKey}.salesPrice`)}</th>
							<th scope="col" class="price">{$t(`${profile.localeKey}.costInclVat`)}</th>
							<th scope="col" class="price" title={$t(`${profile.localeKey}.profitFormula`)}>{$t(`${profile.localeKey}.profitPercent`)}</th>
						</tr>
					</thead>
					<tbody>
						{#each visibleProducts as product, index (`${product.branchId}-${product.productId}`)}
							{@const profitMargin = getProfitMargin(product)}
							<tr>
								<td class="row-number">{index + 1}</td>
								<td>{branchNames.get(product.branchId)}</td>
								<td class="barcode"><bdi>{product.barcode || '—'}</bdi></td>
								<td dir="ltr">{product.nameEn || '—'}</td>
								<td dir="rtl">{product.nameAr || '—'}</td>
								<td>{product.unitName || '—'}</td>
								<td class="price"><bdi>{product.salesPrice == null ? '—' : priceFormatter.format(product.salesPrice)}</bdi></td>
								<td class="price"><bdi>{product.cost == null ? '—' : priceFormatter.format(product.cost * 1.15)}</bdi></td>
								<td class="price"><bdi>{profitMargin == null ? '—' : profitFormatter.format(profitMargin)}</bdi></td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{/if}
	{/if}
</div>

<style>
	.products-view { display: flex; flex-direction: column; height: 100%; min-height: 0; overflow: hidden; text-align: start; }
	.toolbar, .controls { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
	.toolbar { flex-shrink: 0; justify-content: space-between; margin-bottom: 20px; }
	h2 { margin: 0 0 6px; font-size: 20px; font-weight: 600; }
	.group-name { margin: 0; color: #64748b; font-size: 13px; }
	.controls { font-size: 13px; }
	select, button { padding: 9px 12px; border: 1px solid #cbd5e1; border-radius: 8px; background: #fff; color: #1e293b; font: inherit; }
	button { cursor: pointer; color: #047857; font-weight: 600; }
	button:disabled { cursor: wait; opacity: 0.6; }
	select:focus-visible, button:focus-visible { outline: 2px solid #059669; outline-offset: 2px; }
	.message { flex-shrink: 0; margin: 12px 0; padding: 20px; background: #f8fafc; border-radius: 8px; color: #64748b; }
	.error { background: #fff7ed; color: #9a3412; }
	.count { flex-shrink: 0; margin: 0 0 12px; font-size: 13px; color: #64748b; }
	.table-scroll { flex: 1; min-height: 0; overflow: auto; border: 1px solid #e2e8f0; border-radius: 8px; }
	table { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13px; }
	th, td { padding: 12px; border-bottom: 1px solid #e2e8f0; text-align: start; }
	th:not(:last-child), td:not(:last-child) { border-inline-end: 1px solid #e2e8f0; }
	th { position: sticky; top: 0; z-index: 1; background: #f1f5f9; font-weight: 600; white-space: nowrap; }
	tbody tr:last-child td { border-bottom: 0; }
	tbody tr:hover { background: #f8fafc; }
	.barcode { font-family: monospace; white-space: nowrap; }
	.row-number { width: 1%; text-align: center; white-space: nowrap; font-variant-numeric: tabular-nums; }
	.price { text-align: end; white-space: nowrap; font-variant-numeric: tabular-nums; }
</style>
