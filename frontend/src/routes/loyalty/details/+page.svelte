<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { _, currentLocale, switchLocale } from '$lib/i18n';

	let cardNumber = $page.url.searchParams.get('cardNumber') || '';
	let cardDataArray: any[] = [];
	let locale = 'en';

	async function loadCardData() {
		try {
			const { supabase } = await import('$lib/utils/supabase');
			
			// Fetch all branches for this card
			const { data: branchDataArray, error: cardError } = await supabase
				.from('privilege_cards_branch')
				.select('*')
				.eq('card_number', cardNumber);

			if (cardError) {
				console.error('Error loading card data:', cardError);
				return;
			}

			if (!branchDataArray || branchDataArray.length === 0) {
				console.error('No card data found');
				return;
			}

			// Process each branch to get branch names
			const processedData = await Promise.all(branchDataArray.map(async (cardDataResult) => {
				if (cardDataResult && cardDataResult.branch_id) {
					// The privilege_cards_branch.branch_id is actually the erp_branch_id
					// So we need to find the erp_connections record with this erp_branch_id
					const { data: erpData, error: erpError } = await supabase
						.from('erp_connections')
						.select('branch_id')
						.eq('erp_branch_id', cardDataResult.branch_id)
						.maybeSingle();

					if (erpData && erpData.branch_id) {
						// Always fetch from branches table to get the language-specific name
						const { data: branchData, error: branchError } = await supabase
							.from('branches')
							.select('name_en, name_ar')
							.eq('id', erpData.branch_id)
							.maybeSingle();

						if (branchData) {
							// Select the name based on current locale
							const branchName = locale === 'ar' ? branchData.name_ar : branchData.name_en;
							if (branchName) {
								cardDataResult.branch_name = branchName;
							}
						}
					}
				}
				return cardDataResult;
			}));

			console.log('📦 Final card data:', processedData);
			cardDataArray = processedData;
		} catch (error) {
			console.error('Error:', error);
		}
	}

	$: if (cardNumber && locale) {
		loadCardData();
	}

	$: locale = $currentLocale;

	function convertToLocaleNumbers(value: string): string {
		if (locale === 'ar') {
			const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
			return value.replace(/\d/g, (digit) => arabicDigits[parseInt(digit)]);
		}
		return value;
	}

	function formatCardNumber(cardNum: string): string {
		// Format card number with spacing: 0500 4915 49
		return cardNum.replace(/(\d{4})/g, '$1 ').trim();
	}

	function maskCardNumber(cardNum: string): string {
		// Show only last 4 digits, mask the rest with stars
		// e.g., 0500491549 -> **** **** 49
		if (cardNum.length <= 4) return cardNum;
		const lastFour = cardNum.slice(-4);
		const masked = '*'.repeat(cardNum.length - 4) + lastFour;
		return formatCardNumber(masked);
	}
</script>

<svelte:head>
	<title>Loyalty Member Details - Aqura Management System</title>
	<meta name="description" content="Loyalty Member Details" />
</svelte:head>

<div class="loyalty-details-page">
	<div class="loyalty-header">
		<button type="button" class="back-btn" on:click={() => goto('/login/')} title="Back">
			<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M19 12H5M12 19l-7-7 7-7"/>
			</svg>
		</button>
		<h1>{$_('customer.login.loyaltyDetails') || 'Loyalty Member Details'}</h1>
		<button 
			type="button" 
			class="language-btn" 
			on:click={() => switchLocale($currentLocale === 'en' ? 'ar' : 'en')}
			title="Toggle Language"
		>
			{$currentLocale === 'en' ? 'العربية' : 'English'}
		</button>
	</div>

	{#if cardDataArray && cardDataArray.length > 0}
		<div class="card-container">
			<!-- Card Header (Shared) -->
			<div class="loyalty-card">
				<div class="card-header">
					<div class="card-title">
						<h2>{$_('customer.login.loyaltyCard') || 'Loyalty Card'}</h2>
						<p class="card-status active">{$_('customer.login.activeCard') || 'Active'}</p>
						{#if cardDataArray.length > 1}
							<p class="multi-location-badge">{$_('customer.login.multipleLocations') || 'Card registered in multiple locations'}</p>
						{/if}
					</div>
					<div class="card-icons">
						<div class="app-logo">
							<img src="/icons/logo.png" alt="Aqura Logo" />
						</div>
						<div class="card-logo">
							<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<rect x="2" y="7" width="20" height="14" rx="2" ry="2"/>
								<path d="M16 15a2 2 0 1 1 4 0"/>
								<path d="M2 10h20"/>
							</svg>
						</div>
					</div>
				</div>

				<div class="card-body">
					<!-- Card Number (Show Once) -->
					<div class="card-number-section">
						<span class="label">{$_('customer.login.cardNumber') || 'Card Number'}</span>
						<span class="card-number font-mono">{convertToLocaleNumbers(maskCardNumber(cardDataArray[0].card_number))}</span>
					</div>
				</div>
			</div>

			<!-- Branch Details (One Card per Branch) -->
			{#each cardDataArray as cardData (cardData.id)}
				<div class="loyalty-card">
					<div class="card-header">
						<div class="card-title">
							<h2>{$_('customer.login.branchDetails') || 'Branch Details'}</h2>
							{#if cardData.branch_name}
								<p class="branch-title">{cardData.branch_name}</p>
							{/if}
						</div>
					</div>

					<div class="card-body">
						<!-- Main Balance Focus -->
						<div class="balance-section">
							<div class="balance-content">
								<span class="balance-label">{$_('customer.login.availableBalance') || 'Available Balance'}</span>
								<span class="balance-amount">{convertToLocaleNumbers(String(cardData.card_balance || 0))}</span>
								<span class="points-label">{$_('customer.login.points') || 'Points'}</span>
							</div>
						</div>

						<!-- Mini Stat Cards Grid -->
						<div class="stats-grid">
							<div class="stat-card">
								<span class="stat-label">{$_('customer.login.totalRedemptions') || 'Total Redemptions'}</span>
								<span class="stat-value">{convertToLocaleNumbers(String(cardData.total_redemptions || 0))}</span>
							</div>
							<div class="stat-card">
								<span class="stat-label">{$_('customer.login.redemptionCount') || 'Redemption Count'}</span>
								<span class="stat-value">{convertToLocaleNumbers(String(cardData.redemption_count || 0))}</span>
							</div>
							<div class="stat-card">
								<span class="stat-label">{$_('customer.login.lastSyncAt') || 'Last Updated'}</span>
								<span class="stat-value-small">{cardData.last_sync_at ? new Date(cardData.last_sync_at).toLocaleString(locale === 'ar' ? 'ar-SA' : 'en-US') : 'N/A'}</span>
							</div>
						</div>
					</div>

					<div class="card-footer">
						<p>{$_('customer.login.loyaltyCardFooter') || 'Thank you for being a valued member'}</p>
					</div>
				</div>
			{/each}
		</div>
	{:else}
		<div class="loading">
			<p>{$_('common.loading') || 'Loading...'}</p>
		</div>
	{/if}
</div>

<style>
	:global(html[dir='rtl']) .loyalty-header,
	:global(html[dir='rtl']) .card-header,
	:global(html[dir='rtl']) .stats-grid {
		direction: rtl;
		text-align: right;
	}

	.loyalty-details-page {
		min-height: 100vh;
		background: linear-gradient(135deg, #F5F7FA 0%, #FFFFFF 100%);
		padding: 1rem;
		padding-top: 2rem;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}

	.loyalty-header {
		display: flex;
		align-items: center;
		gap: 1rem;
		background: white;
		padding: 1.5rem;
		border-radius: 16px;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
		position: relative;
		z-index: 10;
	}

	.back-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 40px;
		height: 40px;
		min-width: 40px;
		padding: 0;
		background: #F3F4F6;
		border: 1px solid #E5E7EB;
		color: #374151;
		border-radius: 10px;
		cursor: pointer;
		transition: all 0.2s ease;
		pointer-events: auto;
		z-index: 10;
		flex-shrink: 0;
		touch-action: manipulation;
	}

	.back-btn:hover {
		background: #E5E7EB;
		border-color: #D1D5DB;
		transform: translateY(-1px);
	}

	.back-btn:active {
		transform: translateY(0);
		background: #D1D5DB;
	}

	.language-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0.625rem 1.25rem;
		background: linear-gradient(135deg, #FF8C00 0%, #FFB347 100%);
		border: none;
		color: white;
		border-radius: 24px;
		cursor: pointer;
		transition: all 0.2s ease;
		pointer-events: auto;
		z-index: 10;
		flex-shrink: 0;
		font-size: 0.875rem;
		font-weight: 600;
		min-height: 40px;
		touch-action: manipulation;
		box-shadow: 0 2px 4px rgba(255, 140, 0, 0.3);
	}

	.language-btn:hover {
		transform: translateY(-2px);
		box-shadow: 0 4px 12px rgba(255, 140, 0, 0.4);
	}

	.language-btn:active {
		transform: translateY(0);
	}

	.loyalty-header h1 {
		flex: 1;
		margin: 0;
		font-size: 1.5rem;
		font-weight: 700;
		color: #1F2937;
		text-align: center;
	}

	.card-container {
		max-width: 600px;
		margin: 0 auto;
		width: 100%;
		animation: fadeIn 0.4s ease-out;
	}

	@keyframes fadeIn {
		from {
			opacity: 0;
			transform: translateY(10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.loyalty-card {
		background: white;
		border-radius: 18px;
		overflow: hidden;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
		color: #1F2937;
		display: flex;
		flex-direction: column;
		border: 1px solid #E5E7EB;
	}

	.card-header {
		padding: 1.75rem;
		display: flex;
		align-items: center;
		gap: 1.25rem;
		background: linear-gradient(135deg, #F9FAFB 0%, #F3F4F6 100%);
		border-bottom: 1px solid #E5E7EB;
	}

	.card-logo {
		width: 80px;
		height: 60px;
		background: linear-gradient(135deg, #FF8C00 0%, #FFB347 100%);
		border-radius: 12px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		color: white;
		box-shadow: 0 2px 8px rgba(255, 140, 0, 0.2);
	}

	.card-logo svg {
		stroke: white;
		width: 40px;
		height: 40px;
	}

	.card-icons {
		display: flex;
		align-items: center;
		gap: 1rem;
		flex-shrink: 0;
	}

	.app-logo {
		width: 64px;
		height: 48px;
		background: white;
		border-radius: 8px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		padding: 6px;
		border: 1px solid #E5E7EB;
	}

	.app-logo img {
		width: 100%;
		height: 100%;
		object-fit: contain;
	}

	.card-title h2 {
		margin: 0;
		font-size: 1.125rem;
		font-weight: 700;
		color: #1F2937;
	}

	.card-title {
		flex: 1;
	}

	.card-status {
		margin: 0.25rem 0 0 0;
		font-size: 0.8125rem;
		color: #6B7280;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.card-status.active {
		color: #10B981;
	}

	.multi-location-badge {
		margin: 0.5rem 0 0 0;
		font-size: 0.75rem;
		color: #FF8C00;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		padding: 0.375rem 0.75rem;
		background: rgba(255, 140, 0, 0.1);
		border-radius: 6px;
		display: inline-block;
		width: fit-content;
	}

	.card-body {
		padding: 2rem;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
		flex: 1;
	}

	/* Card Number Section */
	.card-number-section {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.card-number {
		font-size: 1.25rem;
		font-weight: 600;
		letter-spacing: 0.15em;
		color: #1F2937;
	}

	/* Branch Section */
	.branch-section {
		padding: 0.75rem;
		background: #F9FAFB;
		border-radius: 8px;
		text-align: center;
		border: 1px solid #E5E7EB;
	}

	.branch-name {
		font-size: 0.9375rem;
		font-weight: 600;
		color: #4B5563;
	}

	/* Balance Section - Main Focus */
	.balance-section {
		background: linear-gradient(135deg, #FFF9F0 0%, #FFFAF5 100%);
		padding: 2rem;
		border-radius: 16px;
		border: 2px solid #FFE5CC;
		text-align: center;
		animation: slideDown 0.5s ease-out 0.1s backwards;
	}

	@keyframes slideDown {
		from {
			opacity: 0;
			transform: translateY(-10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.balance-content {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.balance-label {
		font-size: 0.875rem;
		color: #6B7280;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.balance-amount {
		font-size: 3rem;
		font-weight: 800;
		background: linear-gradient(135deg, #FF8C00 0%, #FFB347 100%);
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
		line-height: 1;
	}

	.points-label {
		font-size: 0.9375rem;
		color: #FF8C00;
		font-weight: 600;
	}

	/* Stats Grid - 3 Column */
	.stats-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 1rem;
	}

	.stat-card {
		background: #F9FAFB;
		padding: 1.25rem;
		border-radius: 12px;
		border: 1px solid #E5E7EB;
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
		text-align: center;
		transition: all 0.2s ease;
		animation: slideUp 0.5s ease-out backwards;
		animation-delay: var(--delay, 0.2s);
	}

	@keyframes slideUp {
		from {
			opacity: 0;
			transform: translateY(10px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}

	.stat-card:nth-child(1) {
		--delay: 0.15s;
	}

	.stat-card:nth-child(2) {
		--delay: 0.2s;
	}

	.stat-card:nth-child(3) {
		--delay: 0.25s;
	}

	.stat-card:hover {
		border-color: #FF8C00;
		box-shadow: 0 2px 8px rgba(255, 140, 0, 0.1);
		transform: translateY(-2px);
	}

	.stat-label {
		font-size: 0.75rem;
		color: #6B7280;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.4px;
	}

	.stat-value {
		font-size: 1.5rem;
		font-weight: 700;
		color: #FF8C00;
	}

	.stat-value-small {
		font-size: 0.8125rem;
		color: #1F2937;
		font-weight: 600;
	}

	/* Activity Section */
	.activity-section {
		padding: 1.25rem;
		background: #F9FAFB;
		border-radius: 12px;
		border: 1px solid #E5E7EB;
	}

	.activity-label {
		display: block;
		font-size: 0.875rem;
		color: #6B7280;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.4px;
		margin-bottom: 0.75rem;
	}

	.activity-empty {
		margin: 0;
		font-size: 0.875rem;
		color: #9CA3AF;
		text-align: center;
		padding: 1rem;
		opacity: 0.7;
	}

	/* Card Footer */
	.card-footer {
		padding: 1.5rem;
		text-align: center;
		background: #F9FAFB;
		border-top: 1px solid #E5E7EB;
		font-size: 0.875rem;
		color: #6B7280;
	}

	.card-footer p {
		margin: 0;
		font-weight: 500;
		line-height: 1.5;
	}

	/* Loading State */
	.loading {
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: 400px;
		color: #6B7280;
		font-size: 1.125rem;
	}

	/* Mobile Responsive */
	@media (max-width: 768px) {
		.loyalty-details-page {
			padding: 0.75rem;
			padding-top: 1rem;
			gap: 1rem;
		}

		.loyalty-header {
			padding: 1rem;
			gap: 0.75rem;
		}

		.loyalty-header h1 {
			font-size: 1.25rem;
		}

		.card-header {
			padding: 1.25rem;
			gap: 1rem;
		}

		.card-logo {
			width: 56px;
			height: 42px;
		}

		.card-body {
			padding: 1.5rem;
			gap: 1.25rem;
		}

		.balance-amount {
			font-size: 2.25rem;
		}

		.stats-grid {
			grid-template-columns: repeat(3, 1fr);
			gap: 0.75rem;
		}

		.stat-card {
			padding: 1rem;
		}

		.stat-label {
			font-size: 0.7rem;
		}

		.stat-value {
			font-size: 1.25rem;
		}

		.card-footer {
			padding: 1.25rem;
			font-size: 0.8125rem;
		}
	}

	/* Touch Feedback */
	@media (hover: none) {
		.back-btn:active,
		.language-btn:active,
		.stat-card:active {
			opacity: 0.8;
		}
	}
</style>
