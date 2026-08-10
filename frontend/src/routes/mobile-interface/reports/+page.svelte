<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	// Reuses the full desktop Sales Report (Quick / Detailed / Month Summary +
	// Excel export). The wrapper below adapts it to the mobile viewport.
	import SalesReport from '$lib/components/desktop-interface/master/finance/reports/SalesReport.svelte';
	import { localeData } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';
	import { supabase } from '$lib/utils/supabase';

	// Helper function to get translations
	function getTranslation(keyPath: string): string {
		const keys = keyPath.split('.');
		let value: any = $localeData.translations;
		for (const key of keys) {
			if (value && typeof value === 'object' && key in value) {
				value = value[key];
			} else {
				return keyPath; // Return key path if translation not found
			}
		}
		return typeof value === 'string' ? value : keyPath;
	}

	let isAuthorized = false;
	let checkingAccess = true;

	// Mirrors the desktop sidebar's isButtonAllowed('SALES_REPORT'): master admins
	// always pass, everyone else needs the SALES_REPORT button permission. The
	// mobile menu item uses the same rule, so the button and the page agree.
	async function hasSalesReportAccess(): Promise<boolean> {
		if ($currentUser?.isMasterAdmin) return true;
		if (!$currentUser?.id) return false;

		try {
			const { data: permissions, error } = await supabase
				.from('button_permissions')
				.select('button_id')
				.eq('user_id', $currentUser.id)
				.eq('is_enabled', true);

			if (error || !permissions?.length) return false;

			const { data: buttons, error: btnError } = await supabase
				.from('sidebar_buttons')
				.select('button_code')
				.in('id', permissions.map(p => p.button_id));

			if (btnError || !buttons) return false;

			return buttons.some(b => b.button_code === 'SALES_REPORT');
		} catch (err) {
			console.error('Error checking sales report permission:', err);
			return false;
		}
	}

	onMount(async () => {
		const allowed = await hasSalesReportAccess();
		checkingAccess = false;

		if (!allowed) {
			// Redirect to mobile home if not authorized
			goto('/mobile-interface');
			return;
		}

		isAuthorized = true;

		// Set page title dynamically
		if (typeof document !== 'undefined') {
			document.title = `${getTranslation('reports.salesReport')} - Aqura Mobile`;
		}
	});
</script>

<svelte:head>
	<title>{getTranslation('reports.salesReport')} - Aqura Mobile</title>
	<meta name="description" content="Sales Report - Mobile Dashboard" />
</svelte:head>

<div class="mobile-sales-report">
	{#if checkingAccess}
		<div class="access-denied"><p>{getTranslation('common.loading') || 'Loading…'}</p></div>
	{:else if isAuthorized}
		<div class="report-container">
			<SalesReport mobile={true} />
		</div>
	{:else}
		<div class="access-denied">
			<div class="access-denied-icon">🚫</div>
			<h2>{getTranslation('common.accessDenied') || 'Access Denied'}</h2>
			<p>{getTranslation('common.insufficientPermissions') || 'You do not have permission to access this page.'}</p>
		</div>
	{/if}
</div>

<style>
	.mobile-sales-report {
		min-height: 100%;
		background: #f8f9fa;
		padding-bottom: 0.5rem;
	}

	.report-container {
		padding: 0;
		width: 100%;
	}

	/*
	 * Mobile adaptation for the desktop Sales Report.
	 * The component assumes a fixed-height desktop window: it fills 100% height
	 * and manages its own scrolling. On mobile the page itself scrolls (see
	 * main.mobile-content in the layout), so the inner scroll containers are
	 * released and the multi-column layout collapses to a single column.
	 */
	.report-container :global(.report-wrapper) {
		height: auto;
		min-height: 0;
		overflow: visible;
	}

	.report-container :global(.sales-report-container),
	.report-container :global(.detail-section) {
		height: auto;
		overflow: visible;
		padding: 0.6rem;
		gap: 0.6rem;
	}

	/* Cards stack full width instead of sitting side by side */
	.report-container :global(.sales-report-container) {
		flex-direction: column;
		flex-wrap: nowrap;
	}

	.report-container :global(.sales-card) {
		max-width: 100%;
		width: 100%;
		padding: 0.6rem;
		border-radius: 12px;
		border-width: 1px;
	}

	/* Quick report cards. The column chart is replaced by MobileBarList when
	   mobile={true}, so only the card chrome needs tightening here. */
	.report-container :global(.sales-card .header) {
		margin-bottom: 0.5rem;
	}

	.report-container :global(.sales-card h3) {
		font-size: 0.82rem;
	}

	.report-container :global(.monthly-averages) {
		gap: 0.4rem;
		margin-bottom: 0.6rem;
	}

	.report-container :global(.month-avg) {
		padding: 0.5rem;
		border-radius: 8px;
	}

	.report-container :global(.month-value) {
		font-size: 0.8rem;
	}

	/* Mode tabs: three compact buttons that share the width on one row */
	.report-container :global(.mode-toggle) {
		padding: 0.5rem 0.5rem 0;
		gap: 0.3rem;
	}

	.report-container :global(.mode-btn) {
		flex: 1;
		min-width: 0;
		padding: 0.35rem 0.25rem;
		font-size: 0.65rem;
		border-width: 1px;
		border-radius: 6px;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	/* Filter bar actions shrink to match (export buttons are omitted on mobile) */
	.report-container :global(.run-btn) {
		padding: 0.35rem 0.6rem;
		font-size: 0.68rem;
	}

	.report-container :global(.filter-select),
	.report-container :global(.filter-label) {
		font-size: 0.68rem;
	}

	/* Tables keep their own horizontal scroll but drop the tall max-height,
	   which would otherwise create a scroll area inside a scrolling page */
	.report-container :global(.table-wrapper) {
		max-height: none;
	}

	.report-container :global(.detail-table) {
		font-size: 0.72rem;
	}

	.report-container :global(.filter-bar) {
		gap: 0.5rem;
	}

	.report-container :global(.summary-badge) {
		min-width: 120px;
		padding: 0.6rem 0.75rem;
	}

	.access-denied {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 50vh;
		text-align: center;
		padding: 1rem;
	}

	.access-denied-icon {
		font-size: 2rem;
		margin-bottom: 0.5rem;
	}

	.access-denied h2 {
		color: #dc2626;
		font-size: 1rem;
		margin-bottom: 0.3rem;
	}

	.access-denied p {
		color: #6b7280;
		font-size: 0.76rem;
	}

</style>
