<script lang="ts">
	import { onMount } from 'svelte';
	import { t } from '$lib/i18n';
	import { getAllCampaigns } from '$lib/services/couponService';
	import type { CouponCampaign } from '$lib/types/coupon';

	let campaigns: CouponCampaign[] = [];
	let activeCampaigns: CouponCampaign[] = [];
	let loading = true;

	onMount(async () => {
		await loadCampaigns();
	});

	async function loadCampaigns() {
		try {
			loading = true;
			campaigns = await getAllCampaigns();
			activeCampaigns = campaigns.filter(c => c.is_active);
		} catch (error) {
			console.error('Error loading campaigns:', error);
		} finally {
			loading = false;
		}
	}
</script>

<div class="coupon-dashboard">
	<div class="dashboard-header">
		<h1>🎁 {t('coupon.title') || 'Coupon Management System'}</h1>
		<p class="subtitle">{t('coupon.subtitle') || 'Manage promotional campaigns and gift coupons'}</p>
		<p class="info-text">All features are now accessible from the Promo section in the sidebar</p>
	</div>

	<!-- Active Campaigns Overview -->
	<div class="overview-section">
		<h2>{t('coupon.activeCampaigns') || 'Active Campaigns'}</h2>
		
		{#if loading}
			<div class="loading">
				<div class="spinner"></div>
				<p>{t('common.loading') || 'Loading...'}</p>
			</div>
		{:else if activeCampaigns.length === 0}
			<div class="empty-state">
				<p>🎯 {t('coupon.noActiveCampaigns') || 'No active campaigns'}</p>
				<button class="btn-primary" on:click={openCampaignManager}>
					{t('coupon.createFirst') || 'Create Your First Campaign'}
				</button>
			</div>
		{:else}
			<div class="campaigns-grid">
				{#each activeCampaigns as campaign}
					<div class="campaign-card">
					<div class="campaign-header">
						<h3>{campaign.name_en || campaign.campaign_name}</h3>
						<span class="campaign-code">{campaign.campaign_code}</span>
					</div>
					<div class="campaign-dates">
						<span>📅 {new Date(campaign.start_date || campaign.validity_start_date).toLocaleDateString('en-GB', { day: '2-digit', month: '2-digit', year: 'numeric' })}</span>
						<span>→</span>
						<span>{new Date(campaign.end_date || campaign.validity_end_date).toLocaleDateString('en-GB', { day: '2-digit', month: '2-digit', year: 'numeric' })}</span>
					</div>
					{#if campaign.description}
							<p class="campaign-desc">{campaign.description}</p>
						{/if}
					</div>
				{/each}
			</div>
		{/if}
	</div>
</div>

<style>
	.coupon-dashboard {
		padding: 2rem;
		max-width: 1400px;
		margin: 0 auto;
	}

	.dashboard-header {
		text-align: center;
		margin-bottom: 3rem;
	}

	.dashboard-header h1 {
		font-size: 2rem;
		color: #1a1a1a;
		margin-bottom: 0.5rem;
	}

	.subtitle {
		color: #666;
		font-size: 1rem;
	}

	.info-text {
		color: #2196F3;
		font-size: 0.9rem;
		margin-top: 0.5rem;
		font-weight: 500;
	}

	.overview-section {
		margin-top: 2rem;
		background: white;
		border-radius: 12px;
		padding: 2rem;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.overview-section h2 {
		font-size: 1.5rem;
		margin-bottom: 1.5rem;
		color: #1a1a1a;
	}

	.loading {
		text-align: center;
		padding: 3rem;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid #f3f3f3;
		border-top: 4px solid #4CAF50;
		border-radius: 50%;
		animation: spin 1s linear infinite;
		margin: 0 auto 1rem;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.empty-state {
		text-align: center;
		padding: 3rem;
	}

	.empty-state p {
		font-size: 1.1rem;
		color: #666;
		margin-bottom: 1.5rem;
	}

	.btn-primary {
		background: #4CAF50;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 8px;
		font-size: 1rem;
		cursor: pointer;
		transition: background 0.3s ease;
	}

	.btn-primary:hover {
		background: #45a049;
	}

	.campaigns-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: 1.5rem;
	}

	.campaign-card {
		background: #f9f9f9;
		border: 1px solid #e0e0e0;
		border-radius: 8px;
		padding: 1.5rem;
	}

	.campaign-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 1rem;
	}

	.campaign-header h3 {
		font-size: 1.1rem;
		color: #1a1a1a;
		margin: 0;
	}

	.campaign-code {
		background: #4CAF50;
		color: white;
		padding: 0.25rem 0.75rem;
		border-radius: 4px;
		font-size: 0.85rem;
		font-weight: bold;
	}

	.campaign-dates {
		display: flex;
		gap: 0.5rem;
		align-items: center;
		color: #666;
		font-size: 0.9rem;
		margin-bottom: 0.75rem;
	}

	.campaign-desc {
		color: #666;
		font-size: 0.9rem;
		line-height: 1.4;
		margin: 0;
	}
</style>
