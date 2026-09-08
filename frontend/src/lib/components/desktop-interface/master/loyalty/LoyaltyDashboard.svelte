<script lang="ts">
	import { onMount } from 'svelte';
	import { _ as t } from '$lib/i18n';
	import { currentUser } from '$lib/utils/persistentAuth';

	let supabase: any = null;
	let loading = true;

	onMount(async () => {
		const mod = await import('$lib/utils/supabase');
		supabase = mod.supabase;
		loading = false;
	});
</script>

<div class="loyalty-dashboard">
	<div class="page-header">
		<h2 class="page-title">🏆 {$t('nav.loyaltyProgram') || 'Loyalty Program'} — Dashboard</h2>
	</div>

	{#if loading}
		<div class="loading-state">
			<div class="spinner"></div>
			<p>Loading...</p>
		</div>
	{:else}
		<div class="dashboard-grid">
			<div class="stat-card">
				<div class="stat-icon">👥</div>
				<div class="stat-label">Total Members</div>
				<div class="stat-value">—</div>
			</div>
			<div class="stat-card">
				<div class="stat-icon">⭐</div>
				<div class="stat-label">Points Issued</div>
				<div class="stat-value">—</div>
			</div>
			<div class="stat-card">
				<div class="stat-icon">🎁</div>
				<div class="stat-label">Rewards Redeemed</div>
				<div class="stat-value">—</div>
			</div>
			<div class="stat-card">
				<div class="stat-icon">📈</div>
				<div class="stat-label">Active This Month</div>
				<div class="stat-value">—</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.loyalty-dashboard {
		padding: 24px;
		color: #e2e8f0;
		min-height: 100%;
		background: #0f172a;
	}

	.page-header {
		margin-bottom: 28px;
		border-bottom: 1px solid #1e293b;
		padding-bottom: 16px;
	}

	.page-title {
		font-size: 1.4rem;
		font-weight: 600;
		color: #f1f5f9;
		margin: 0;
	}

	.loading-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 200px;
		gap: 12px;
		color: #94a3b8;
	}

	.spinner {
		width: 32px;
		height: 32px;
		border: 3px solid #1e293b;
		border-top-color: #3b82f6;
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	.dashboard-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
		gap: 16px;
	}

	.stat-card {
		background: #1e293b;
		border: 1px solid #334155;
		border-radius: 12px;
		padding: 20px;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
		text-align: center;
	}

	.stat-icon {
		font-size: 2rem;
	}

	.stat-label {
		font-size: 0.8rem;
		color: #94a3b8;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.stat-value {
		font-size: 1.6rem;
		font-weight: 700;
		color: #f1f5f9;
	}
</style>
