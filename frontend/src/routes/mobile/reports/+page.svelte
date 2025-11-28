<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import SalesReport from '$lib/components/admin/reports/SalesReport.svelte';
	import { localeData } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';

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

	onMount(() => {
		// Check if user has required role
		const userRole = $currentUser?.roleType;
		if (userRole !== 'Master Admin' && userRole !== 'Admin') {
			// Redirect to mobile home if not authorized
			goto('/mobile');
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
	{#if isAuthorized}
		<div class="page-header">
			<h1 class="page-title">
				<span class="page-icon">📊</span>
				{getTranslation('reports.salesReport') || 'Sales Report'}
			</h1>
			<p class="page-subtitle">{getTranslation('reports.dailySalesOverview') || 'Daily Sales Overview'}</p>
		</div>
		
		<div class="report-container">
			<SalesReport />
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
		min-height: 100vh;
		background: #f8f9fa;
		padding-bottom: 1rem;
	}

	.page-header {
		background: white;
		padding: 1.5rem 1rem;
		margin-bottom: 1rem;
		border-bottom: 1px solid #e5e7eb;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
	}

	.page-title {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 1.5rem;
		font-weight: 700;
		color: #1f2937;
		margin: 0 0 0.5rem 0;
	}

	.page-icon {
		font-size: 1.5rem;
	}

	.page-subtitle {
		color: #6b7280;
		font-size: 0.95rem;
		margin: 0;
		font-weight: 500;
	}

	.report-container {
		padding: 0 0.5rem;
	}

	.access-denied {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: 50vh;
		text-align: center;
		padding: 2rem;
	}

	.access-denied-icon {
		font-size: 4rem;
		margin-bottom: 1rem;
	}

	.access-denied h2 {
		color: #dc2626;
		font-size: 1.5rem;
		margin-bottom: 0.5rem;
	}

	.access-denied p {
		color: #6b7280;
		font-size: 1rem;
	}

	/* Make the desktop sales report responsive for mobile */
	:global(.sales-report-container) {
		flex-direction: column !important;
		gap: 1rem !important;
		padding: 0 !important;
	}

	:global(.sales-card) {
		max-width: none !important;
		width: 100% !important;
		margin: 0 !important;
		border-radius: 12px !important;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08) !important;
	}

	/* Optimize chart for mobile - minimal overrides */
	:global(.chart-container) {
		padding: 1rem 0.5rem !important;
		overflow-x: auto !important;
	}

	:global(.sale-item) {
		min-width: 70px !important;
	}

	:global(.bar-container) {
		min-height: 120px !important;
	}

	:global(.bar) {
		min-height: 30px !important;
	}

	:global(.date-label),
	:global(.amount-label),
	:global(.bills-label),
	:global(.basket-label),
	:global(.return-label) {
		font-size: 0.7rem !important;
	}

	:global(.monthly-averages) {
		gap: 0.5rem !important;
		display: flex !important;
		justify-content: center !important;
		margin-bottom: 1rem !important;
	}

	:global(.month-avg) {
		padding: 0.75rem !important;
		min-width: 120px !important;
		border-radius: 12px !important;
		color: white !important;
		text-align: center !important;
	}

	:global(.branch-monthly-badges) {
		display: flex !important;
		gap: 0.4rem !important;
		margin-bottom: 0.5rem !important;
		flex-wrap: wrap !important;
		justify-content: center !important;
	}

	:global(.mini-badge) {
		padding: 0.5rem 0.75rem !important;
		border-radius: 8px !important;
		font-size: 0.65rem !important;
		color: white !important;
		min-width: 70px !important;
	}

	:global(.refresh-btn) {
		padding: 0.4rem !important;
	}

	/* Mobile responsive adjustments */
	@media (max-width: 480px) {
		.page-header {
			padding: 1rem 0.75rem;
		}

		.page-title {
			font-size: 1.25rem;
		}

		.page-subtitle {
			font-size: 0.875rem;
		}

		.report-container {
			padding: 0 0.25rem;
		}

		:global(.sales-comparison) {
			gap: 0.5rem !important;
			padding: 0.75rem 0.25rem !important;
		}

		:global(.sale-item) {
			gap: 0.25rem !important;
		}

		:global(.bar-container) {
			max-width: 40px !important;
		}

		:global(.monthly-averages) {
			flex-direction: column !important;
		}

		:global(.month-avg) {
			min-width: 100px !important;
		}
	}
</style>