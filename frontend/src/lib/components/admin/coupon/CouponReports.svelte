<script lang="ts">
	import { onMount } from 'svelte';
	import { t } from '$lib/i18n';
	import { getAllCampaigns, getCampaignStatistics } from '$lib/services/couponService';
	import type { CouponCampaign } from '$lib/types/coupon';

	interface CampaignStats {
		total_eligible_customers: number;
		total_claims: number;
		remaining_claims: number;
		total_stock_limit: number;
		total_stock_remaining: number;
		products: ProductStats[];
	}

	interface ProductStats {
		product_id: string;
		product_name_en: string;
		product_name_ar: string;
		stock_limit: number;
		stock_remaining: number;
		claims_count: number;
	}

	let campaigns: CouponCampaign[] = [];
	let selectedCampaignId = '';
	let stats: CampaignStats | null = null;
	let loading = false;
	let loadingCampaigns = true;

	onMount(async () => {
		await loadCampaigns();
	});

	async function loadCampaigns() {
		try {
			loadingCampaigns = true;
			campaigns = await getAllCampaigns();
		} catch (error) {
			console.error('Error loading campaigns:', error);
		} finally {
			loadingCampaigns = false;
		}
	}

	async function handleCampaignChange() {
		if (!selectedCampaignId) {
			stats = null;
			return;
		}

		try {
			loading = true;
			stats = await getCampaignStatistics(selectedCampaignId);
		} catch (error) {
			console.error('Error loading statistics:', error);
			stats = null;
		} finally {
			loading = false;
		}
	}

	function getClaimRate(): number {
		if (!stats || stats.total_eligible_customers === 0) return 0;
		return (stats.total_claims / stats.total_eligible_customers) * 100;
	}

	function getStockUsage(): number {
		if (!stats || stats.total_stock_limit === 0) return 0;
		return ((stats.total_stock_limit - stats.total_stock_remaining) / stats.total_stock_limit) * 100;
	}

	function getProductClaimRate(product: ProductStats): number {
		if (product.stock_limit === 0) return 0;
		return (product.claims_count / product.stock_limit) * 100;
	}

	function exportToCSV() {
		if (!stats) return;

		const campaign = campaigns.find(c => c.id === selectedCampaignId);
		const csvRows = [
			['Campaign Statistics Report'],
			['Campaign', campaign?.name_en || 'N/A'],
			['Date', new Date().toLocaleDateString()],
			[''],
			['Overview'],
			['Total Eligible Customers', stats.total_eligible_customers],
			['Total Claims', stats.total_claims],
			['Remaining Claims', stats.remaining_claims],
			['Claim Rate', `${getClaimRate().toFixed(1)}%`],
			[''],
			['Product Performance'],
			['Product Name (EN)', 'Product Name (AR)', 'Stock Limit', 'Stock Remaining', 'Claims', 'Claim Rate'],
			...stats.products.map(p => [
				p.product_name_en,
				p.product_name_ar,
				p.stock_limit,
				p.stock_remaining,
				p.claims_count,
				`${getProductClaimRate(p).toFixed(1)}%`
			])
		];

		const csvContent = csvRows.map(row => row.join(',')).join('\n');
		const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
		const link = document.createElement('a');
		link.href = URL.createObjectURL(blob);
		link.download = `campaign-report-${Date.now()}.csv`;
		link.click();
	}
</script>

<div class="coupon-reports">
	<div class="reports-header">
		<h2>📊 {t('coupon.reportsStats') || 'Reports & Statistics'}</h2>
		<p class="subtitle">{t('coupon.reportsDescription') || 'View campaign analytics and performance metrics'}</p>
	</div>

	<!-- Campaign Selector -->
	<div class="controls">
		<div class="form-group">
			<label for="campaign-select">
				{t('coupon.selectCampaign') || 'Select Campaign'}
			</label>
			{#if loadingCampaigns}
				<select disabled>
					<option>{t('common.loading') || 'Loading...'}</option>
				</select>
			{:else}
				<select 
					id="campaign-select"
					bind:value={selectedCampaignId} 
					on:change={handleCampaignChange}
				>
					<option value="">{t('coupon.chooseCampaign') || 'Choose a campaign...'}</option>
					{#each campaigns as campaign}
						<option value={campaign.id}>
							{campaign.name_en} ({campaign.campaign_code})
						</option>
					{/each}
				</select>
			{/if}
		</div>

		{#if stats}
			<button class="btn-export" on:click={exportToCSV}>
				📥 {t('common.export') || 'Export CSV'}
			</button>
		{/if}
	</div>

	<!-- Loading State -->
	{#if loading}
		<div class="loading-state">
			<div class="spinner"></div>
			<p>{t('common.loading') || 'Loading statistics...'}</p>
		</div>
	{/if}

	<!-- Empty State -->
	{#if !selectedCampaignId && !loading}
		<div class="empty-state">
			<div class="icon">📊</div>
			<p>{t('coupon.selectCampaignToViewReports') || 'Select a campaign to view its statistics and performance'}</p>
		</div>
	{/if}

	<!-- Statistics Display -->
	{#if stats && !loading}
		<!-- Overview Cards -->
		<div class="stats-grid">
			<div class="stat-card customers">
				<div class="stat-icon">👥</div>
				<div class="stat-content">
					<div class="stat-value">{stats.total_eligible_customers.toLocaleString()}</div>
					<div class="stat-label">{t('coupon.eligibleCustomers') || 'Eligible Customers'}</div>
				</div>
			</div>

			<div class="stat-card claims">
				<div class="stat-icon">🎟️</div>
				<div class="stat-content">
					<div class="stat-value">{stats.total_claims.toLocaleString()}</div>
					<div class="stat-label">{t('coupon.totalClaims') || 'Total Claims'}</div>
				</div>
			</div>

			<div class="stat-card remaining">
				<div class="stat-icon">⏳</div>
				<div class="stat-content">
					<div class="stat-value">{stats.remaining_claims.toLocaleString()}</div>
					<div class="stat-label">{t('coupon.remainingClaims') || 'Remaining Claims'}</div>
				</div>
			</div>

			<div class="stat-card rate">
				<div class="stat-icon">📈</div>
				<div class="stat-content">
					<div class="stat-value">{getClaimRate().toFixed(1)}%</div>
					<div class="stat-label">{t('coupon.claimRate') || 'Claim Rate'}</div>
				</div>
			</div>
		</div>

		<!-- Progress Bars -->
		<div class="progress-section">
			<div class="progress-card">
				<h3>{t('coupon.claimProgress') || 'Claim Progress'}</h3>
				<div class="progress-bar">
					<div class="progress-fill" style="width: {getClaimRate()}%"></div>
				</div>
				<div class="progress-text">
					{stats.total_claims} / {stats.total_eligible_customers} 
					{t('coupon.customers') || 'customers'} ({getClaimRate().toFixed(1)}%)
				</div>
			</div>

			<div class="progress-card">
				<h3>{t('coupon.stockUsage') || 'Stock Usage'}</h3>
				<div class="progress-bar">
					<div class="progress-fill stock" style="width: {getStockUsage()}%"></div>
				</div>
				<div class="progress-text">
					{stats.total_stock_limit - stats.total_stock_remaining} / {stats.total_stock_limit} 
					{t('coupon.products') || 'products'} ({getStockUsage().toFixed(1)}%)
				</div>
			</div>
		</div>

		<!-- Product Performance Table -->
		<div class="products-section">
			<h3>{t('coupon.productPerformance') || 'Product Performance'}</h3>
			
			{#if stats.products && stats.products.length > 0}
				<div class="table-responsive">
					<table class="products-table">
						<thead>
							<tr>
								<th>{t('coupon.productNameEnglish') || 'Product (EN)'}</th>
								<th>{t('coupon.productNameArabic') || 'Product (AR)'}</th>
								<th>{t('coupon.stockLimit') || 'Stock Limit'}</th>
								<th>{t('coupon.stockRemaining') || 'Remaining'}</th>
								<th>{t('coupon.totalClaims') || 'Claims'}</th>
								<th>{t('coupon.claimRate') || 'Claim Rate'}</th>
								<th>{t('common.progress') || 'Progress'}</th>
							</tr>
						</thead>
						<tbody>
							{#each stats.products as product}
								<tr>
									<td>{product.product_name_en}</td>
									<td class="rtl">{product.product_name_ar}</td>
									<td>{product.stock_limit.toLocaleString()}</td>
									<td>{product.stock_remaining.toLocaleString()}</td>
									<td>{product.claims_count.toLocaleString()}</td>
									<td>{getProductClaimRate(product).toFixed(1)}%</td>
									<td>
										<div class="mini-progress">
											<div 
												class="mini-progress-fill" 
												style="width: {getProductClaimRate(product)}%"
											></div>
										</div>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{:else}
				<div class="empty-products">
					<p>{t('coupon.noProducts') || 'No products in this campaign'}</p>
				</div>
			{/if}
		</div>
	{/if}
</div>

<style>
	.coupon-reports {
		padding: 2rem;
		max-width: 1400px;
		margin: 0 auto;
	}

	.reports-header {
		margin-bottom: 2rem;
	}

	.reports-header h2 {
		font-size: 1.75rem;
		color: #1a1a1a;
		margin-bottom: 0.5rem;
	}

	.subtitle {
		color: #666;
		font-size: 0.95rem;
	}

	.controls {
		display: flex;
		gap: 1rem;
		align-items: flex-end;
		margin-bottom: 2rem;
		padding: 1.5rem;
		background: white;
		border-radius: 8px;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.form-group {
		flex: 1;
	}

	.form-group label {
		display: block;
		font-weight: 500;
		margin-bottom: 0.5rem;
		color: #333;
	}

	.form-group select {
		width: 100%;
		padding: 0.75rem;
		border: 1px solid #ddd;
		border-radius: 6px;
		font-size: 1rem;
		background: white;
	}

	.form-group select:disabled {
		background: #f5f5f5;
		cursor: not-allowed;
	}

	.btn-export {
		background: #4CAF50;
		color: white;
		border: none;
		padding: 0.75rem 1.5rem;
		border-radius: 6px;
		font-size: 0.95rem;
		cursor: pointer;
		transition: background 0.3s ease;
		white-space: nowrap;
	}

	.btn-export:hover {
		background: #45a049;
	}

	.loading-state {
		text-align: center;
		padding: 4rem 2rem;
	}

	.spinner {
		width: 50px;
		height: 50px;
		border: 4px solid #f3f3f3;
		border-top: 4px solid #9C27B0;
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
		padding: 4rem 2rem;
		background: white;
		border-radius: 8px;
		box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
	}

	.empty-state .icon {
		font-size: 4rem;
		margin-bottom: 1rem;
		opacity: 0.5;
	}

	.empty-state p {
		color: #666;
		font-size: 1.1rem;
	}

	.stats-grid {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
		gap: 1.5rem;
		margin-bottom: 2rem;
	}

	.stat-card {
		background: white;
		border-radius: 8px;
		padding: 1.5rem;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		display: flex;
		align-items: center;
		gap: 1rem;
	}

	.stat-card.customers {
		border-left: 4px solid #2196F3;
	}

	.stat-card.claims {
		border-left: 4px solid #4CAF50;
	}

	.stat-card.remaining {
		border-left: 4px solid #FF9800;
	}

	.stat-card.rate {
		border-left: 4px solid #9C27B0;
	}

	.stat-icon {
		font-size: 2.5rem;
	}

	.stat-content {
		flex: 1;
	}

	.stat-value {
		font-size: 2rem;
		font-weight: bold;
		color: #1a1a1a;
	}

	.stat-label {
		font-size: 0.9rem;
		color: #666;
		margin-top: 0.25rem;
	}

	.progress-section {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
		gap: 1.5rem;
		margin-bottom: 2rem;
	}

	.progress-card {
		background: white;
		border-radius: 8px;
		padding: 1.5rem;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.progress-card h3 {
		font-size: 1.1rem;
		margin-bottom: 1rem;
		color: #1a1a1a;
	}

	.progress-bar {
		height: 24px;
		background: #f0f0f0;
		border-radius: 12px;
		overflow: hidden;
		margin-bottom: 0.5rem;
	}

	.progress-fill {
		height: 100%;
		background: linear-gradient(90deg, #4CAF50, #45a049);
		transition: width 0.5s ease;
		border-radius: 12px;
	}

	.progress-fill.stock {
		background: linear-gradient(90deg, #FF9800, #F57C00);
	}

	.progress-text {
		font-size: 0.9rem;
		color: #666;
		text-align: center;
	}

	.products-section {
		background: white;
		border-radius: 8px;
		padding: 1.5rem;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
	}

	.products-section h3 {
		font-size: 1.25rem;
		margin-bottom: 1.5rem;
		color: #1a1a1a;
	}

	.table-responsive {
		overflow-x: auto;
	}

	.products-table {
		width: 100%;
		border-collapse: collapse;
	}

	.products-table thead {
		background: #f9f9f9;
	}

	.products-table th {
		padding: 1rem;
		text-align: left;
		font-weight: 600;
		color: #333;
		border-bottom: 2px solid #e0e0e0;
		white-space: nowrap;
	}

	.products-table td {
		padding: 1rem;
		border-bottom: 1px solid #f0f0f0;
	}

	.products-table tbody tr:hover {
		background: #f9f9f9;
	}

	.rtl {
		direction: rtl;
		text-align: right;
	}

	.mini-progress {
		width: 100px;
		height: 8px;
		background: #f0f0f0;
		border-radius: 4px;
		overflow: hidden;
	}

	.mini-progress-fill {
		height: 100%;
		background: #4CAF50;
		transition: width 0.3s ease;
		border-radius: 4px;
	}

	.empty-products {
		text-align: center;
		padding: 3rem;
		color: #666;
	}
</style>
