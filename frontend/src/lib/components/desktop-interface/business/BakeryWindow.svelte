<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t, currentLocale } from '$lib/i18n';
	import { iconUrlMap, loadIcons } from '$lib/stores/iconStore';
	import { windowManager } from '$lib/stores/windowManager';
	import BusinessCounterSettings from './BusinessCounterSettings.svelte';
	import BakeryProducts from './BakeryProducts.svelte';
	import BakerySales from './BakerySales.svelte';
	import BakeryExpenses from './BakeryExpenses.svelte';
	import BakerySalesRent from './BakerySalesRent.svelte';
	import BakeryVat from './BakeryVat.svelte';
	import CoffeeSupplierLedger from './CoffeeSupplierLedger.svelte';
	import CoffeeAllTimeReport from './CoffeeAllTimeReport.svelte';
	import CoffeeOtherPayments from './CoffeeOtherPayments.svelte';

	import { BAKERY_COUNTER, type BusinessCounterProfile } from '$lib/types/businessCounter';

	export let profile: BusinessCounterProfile = BAKERY_COUNTER;
	export let windowId: string;

	$: counterLogo = $iconUrlMap[`${profile.id}-logo`];
	onMount(() => {
		// Logo changes update the window chrome independently of its render cycle.
		const unsubscribe = iconUrlMap.subscribe(logos => {
			windowManager.updateWindowIcon(windowId, logos[`${profile.id}-logo`] || profile.icon);
		});
		void loadIcons();
		return unsubscribe;
	});

	type BakeryTab = 'sales' | 'products' | 'expenses' | 'supplierLedger' | 'operationsReport' | 'allTimeReport' | 'otherPayments' | 'otherExpenses' | 'settings';
	const tabs: BakeryTab[] = profile.id === 'coffee-counter'
		? ['sales', 'products', 'expenses', 'supplierLedger', 'operationsReport', 'allTimeReport', 'otherPayments', 'otherExpenses', 'settings']
		: ['sales', 'products', 'expenses', 'operationsReport', 'allTimeReport', 'otherPayments', 'otherExpenses', 'settings'];
	let activeTab: BakeryTab = 'sales';
	const operationsTabs = ['salesAndRent', 'vat', 'operatorsProfit'] as const;
	type OperationsTab = typeof operationsTabs[number];
	let activeOperationsTab: OperationsTab = 'salesAndRent';
	let salesRentOpened = false;
	let vatOpened = false;
	let operatorsProfitOpened = false;
	let rentPercentages: Record<string, number | undefined> = {};
	let productsOpened = false;
	let expensesOpened = false;
	let suppliersOpened = false;
	let allTimeOpened = false;
	let otherPaymentsOpened = false;
	let otherExpensesOpened = false;
	let otherPaymentsRevision = 0;
	$: if (activeTab === 'products') productsOpened = true;
	$: if (activeTab === 'expenses') expensesOpened = true;
	$: if (activeTab === 'supplierLedger') suppliersOpened = true;
	$: if (activeTab === 'allTimeReport') allTimeOpened = true;
	$: if (activeTab === 'otherPayments') otherPaymentsOpened = true;
	$: if (activeTab === 'otherExpenses') otherExpensesOpened = true;
	$: if (activeTab === 'operationsReport' && activeOperationsTab === 'salesAndRent') salesRentOpened = true;
	$: if (activeTab === 'operationsReport' && activeOperationsTab === 'vat') vatOpened = true;
	$: if (activeTab === 'operationsReport' && activeOperationsTab === 'operatorsProfit') operatorsProfitOpened = true;

	function handleTabKeydown(event: KeyboardEvent, tab: BakeryTab) {
		let nextIndex = tabs.indexOf(tab);
		const direction = $currentLocale === 'ar' ? -1 : 1;
		if (event.key === 'ArrowRight') nextIndex += direction;
		else if (event.key === 'ArrowLeft') nextIndex -= direction;
		else if (event.key === 'Home') nextIndex = 0;
		else if (event.key === 'End') nextIndex = tabs.length - 1;
		else return;

		event.preventDefault();
		activeTab = tabs[(nextIndex + tabs.length) % tabs.length];
		document.getElementById(`${windowId}-bakery-tab-${activeTab}`)?.focus();
	}

	function handleOperationsTabKeydown(event: KeyboardEvent, tab: OperationsTab) {
		let nextIndex = operationsTabs.indexOf(tab);
		const direction = $currentLocale === 'ar' ? -1 : 1;
		if (event.key === 'ArrowRight') nextIndex += direction;
		else if (event.key === 'ArrowLeft') nextIndex -= direction;
		else if (event.key === 'Home') nextIndex = 0;
		else if (event.key === 'End') nextIndex = operationsTabs.length - 1;
		else return;

		event.preventDefault();
		activeOperationsTab = operationsTabs[(nextIndex + operationsTabs.length) % operationsTabs.length];
		document.getElementById(`${windowId}-bakery-operations-tab-${activeOperationsTab}`)?.focus();
	}
</script>

<div class="bakery-window" dir={$currentLocale === 'ar' ? 'rtl' : 'ltr'}>
	<header>
		<h1>{#if counterLogo}<img class="counter-logo" src={counterLogo} alt="" />{:else}<span aria-hidden="true">{profile.icon}</span>{/if} {$t(profile.titleKey)}</h1>
	</header>
	<div class="tabs" role="tablist" aria-label={$t(profile.titleKey)}>
		{#each tabs as tab}
			<button
				type="button"
				role="tab"
				id={`${windowId}-bakery-tab-${tab}`}
				class:active={activeTab === tab}
				aria-selected={activeTab === tab}
				aria-controls={`${windowId}-bakery-panel-${tab}`}
				tabindex={activeTab === tab ? 0 : -1}
				on:click={() => activeTab = tab}
				on:keydown={(event) => handleTabKeydown(event, tab)}
			>
				{$t(`${profile.localeKey}.${tab}`)}
			</button>
		{/each}
	</div>
	<div class="content">
		{#each tabs as tab}
			<section
				class="report-panel"
				id={`${windowId}-bakery-panel-${tab}`}
				role="tabpanel"
				aria-labelledby={`${windowId}-bakery-tab-${tab}`}
				hidden={activeTab !== tab}
				tabindex="0"
			>
				{#if tab === 'settings'}
					{#if activeTab === 'settings'}<BusinessCounterSettings {windowId} {profile} />{/if}
				{:else if tab === 'products'}
					{#if productsOpened}<BakeryProducts {profile} {windowId} />{/if}
				{:else if tab === 'expenses'}
					{#if expensesOpened}<BakeryExpenses {profile} {windowId} />{/if}
				{:else if tab === 'supplierLedger'}
					{#if suppliersOpened}<CoffeeSupplierLedger {windowId} />{/if}
				{:else if tab === 'allTimeReport'}
					{#if allTimeOpened}<CoffeeAllTimeReport {profile} {windowId} {rentPercentages} {otherPaymentsRevision} />{/if}
				{:else if tab === 'otherPayments'}
					{#if otherPaymentsOpened}<CoffeeOtherPayments {profile} {windowId} on:saved={() => otherPaymentsRevision += 1} />{/if}
				{:else if tab === 'otherExpenses'}
					{#if otherExpensesOpened}<CoffeeOtherPayments {profile} windowId={`${windowId}-expenses`} mode="expense" on:saved={() => otherPaymentsRevision += 1} />{/if}
				{:else if tab === 'operationsReport'}
					<div class="operations-report">
						<h2 class="operations-heading">{$t(`${profile.localeKey}.operationsReport`)}</h2>
						<div class="tabs operations-tabs" role="tablist" aria-label={$t(`${profile.localeKey}.operationsReport`)}>
							{#each operationsTabs as subtab}
								<button
									type="button"
									role="tab"
									id={`${windowId}-bakery-operations-tab-${subtab}`}
									class:active={activeOperationsTab === subtab}
									aria-selected={activeOperationsTab === subtab}
									aria-controls={`${windowId}-bakery-operations-panel-${subtab}`}
									tabindex={activeOperationsTab === subtab ? 0 : -1}
									on:click={() => activeOperationsTab = subtab}
									on:keydown={(event) => handleOperationsTabKeydown(event, subtab)}
								>
									{$t(`${profile.localeKey}.operations.${subtab}`)}
								</button>
							{/each}
						</div>
						<div class="operations-panels">
							{#each operationsTabs as subtab}
								<div
									class="operations-panel-content"
									role="tabpanel"
									id={`${windowId}-bakery-operations-panel-${subtab}`}
									aria-labelledby={`${windowId}-bakery-operations-tab-${subtab}`}
									hidden={activeOperationsTab !== subtab}
									tabindex="0"
								>
									{#if subtab === 'salesAndRent'}
										{#if salesRentOpened}<BakerySalesRent {profile} {windowId} manualEntriesRevision={otherPaymentsRevision} bind:rentPercentages />{/if}
									{:else if subtab === 'vat'}
										{#if vatOpened}<BakeryVat {profile} {windowId} />{/if}
									{:else}
										{#if operatorsProfitOpened}<BakerySalesRent {profile} windowId={`${windowId}-operators-profit`} view="profit" manualEntriesRevision={otherPaymentsRevision} bind:rentPercentages />{/if}
									{/if}
								</div>
							{/each}
						</div>
					</div>
				{:else}
					<BakerySales {profile} {windowId} />
				{/if}
			</section>
		{/each}
	</div>
</div>

<style>
	.bakery-window {
		display: flex;
		flex-direction: column;
		height: 100%;
		min-height: 0;
		background: #f8fafc;
		color: #1e293b;
	}

	header {
		flex-shrink: 0;
		padding: 24px 24px 16px;
	}

	h1 {
		display: flex;
		align-items: center;
		gap: 10px;
		margin: 0;
		font-size: 24px;
		font-weight: 700;
	}
	.counter-logo { width: 40px; height: 40px; object-fit: contain; }

	.tabs {
		display: flex;
		flex-shrink: 0;
		overflow-x: auto;
		gap: 8px;
		padding: 0 24px;
		border-bottom: 1px solid #e2e8f0;
	}

	.tabs button {
		flex-shrink: 0;
		padding: 12px 20px;
		border: 0;
		border-bottom: 3px solid transparent;
		background: transparent;
		color: #64748b;
		font: inherit;
		font-weight: 600;
		cursor: pointer;
	}

	.tabs button:hover,
	.tabs button.active {
		border-bottom-color: #059669;
		color: #047857;
	}

	button:focus-visible,
	section:focus-visible,
	.operations-panel-content:focus-visible {
		outline: 2px solid #059669;
		outline-offset: -2px;
	}

	.content {
		flex: 1;
		min-height: 0;
		overflow: hidden;
		padding: 24px;
	}

	section {
		padding: 48px 24px;
		border: 1px solid #e2e8f0;
		border-radius: 12px;
		background: #fff;
		text-align: center;
	}

	.report-panel {
		box-sizing: border-box;
		height: 100%;
		min-height: 0;
		overflow: hidden;
		padding: 20px;
		text-align: start;
	}

	.operations-report {
		display: flex;
		flex-direction: column;
		height: 100%;
		min-height: 0;
	}

	.operations-heading {
		margin: 0 0 16px;
		font-size: 20px;
		font-weight: 600;
	}

	.operations-tabs {
		padding: 0;
	}

	.operations-panels {
		flex: 1;
		min-height: 0;
		overflow: hidden;
		padding-top: 20px;
	}

	.operations-panel-content { height: 100%; min-height: 0; }
</style>
