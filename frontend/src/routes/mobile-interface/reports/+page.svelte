<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import MobileSalesReport from '$lib/components/mobile-interface/reports/MobileSalesReport.svelte';
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
		const isMasterOrAdmin = $currentUser?.isMasterAdmin || $currentUser?.isAdmin;
		if (!isMasterOrAdmin) {
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
	{#if isAuthorized}
		<div class="page-header">
			<h1 class="page-title">
				<span class="page-icon">📊</span>
				{getTranslation('reports.salesReport') || 'Sales Report'}
			</h1>
			<p class="page-subtitle">{getTranslation('reports.dailySalesOverview') || 'Daily Sales Overview'}</p>
		</div>
		
		<div class="report-container">
			<MobileSalesReport />
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
		padding: 1rem 1rem;
		margin-bottom: 0.5rem;
		border-bottom: 1px solid #e5e7eb;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
	}

	.page-title {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 1.25rem;
		font-weight: 700;
		color: #1f2937;
		margin: 0 0 0.25rem 0;
	}

	.page-icon {
		font-size: 1.25rem;
	}

	.page-subtitle {
		color: #6b7280;
		font-size: 0.875rem;
		margin: 0;
		font-weight: 500;
	}

	.report-container {
		padding: 0;
		width: 100%;
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

	@media (max-width: 480px) {
		.page-header {
			padding: 0.75rem 0.5rem;
		}

		.page-title {
			font-size: 1.1rem;
		}

		.page-subtitle {
			font-size: 0.8rem;
		}
	}
</style>
